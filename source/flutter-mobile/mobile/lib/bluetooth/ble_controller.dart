import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_protocol.dart';
import '../release_policy.dart';

class ScooterBle extends ChangeNotifier {
  static const _native = MethodChannel('in.crossfire.openola/network');
  late final radio = FlutterReactiveBle();
  final devices = <String, DiscoveredDevice>{};
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _notifications;
  final _frames = StreamController<List<int>>.broadcast();
  final protocol = BleProtocol();
  BleAssembler _assembler = BleAssembler();
  QualifiedCharacteristic? _write;
  List<int>? _key;
  bool scanning = false, busy = false, ready = false, disposed = false;
  String message = '', selectedName = '';
  final steps = <String>[];
  int _notifyChunks = 0;
  void _step(String text) {
    final t = DateTime.now();
    steps.add(
      '${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')} $text',
    );
    if (steps.length > 40) steps.removeAt(0);
  }

  int? soc, range;
  bool? locked;
  Timer? _keepalive;
  Future<void>? _keepaliveInFlight;
  final _seenTypes = <int>{};
  DateTime? receivedAt;
  void emit() {
    if (!disposed) notifyListeners();
  }

  static bool looksLikeScooter(DiscoveredDevice d) =>
      d.name.toUpperCase().contains('OLA') ||
      d.name.toUpperCase().contains('S1') ||
      d.serviceUuids.any(
        (u) => u.toString().toLowerCase().startsWith('6e400001'),
      );

  /// Likely scooters first, then strongest signal; unnamed devices are kept.
  List<DiscoveredDevice> get sortedDevices {
    final list = devices.values.toList();
    list.sort((a, b) {
      final la = looksLikeScooter(a) ? 0 : 1, lb = looksLikeScooter(b) ? 0 : 1;
      return la != lb ? la.compareTo(lb) : b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  Future<void> scan() async {
    if (busy) return;
    try {
      final permissions = Platform.isAndroid
          ? [
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
              Permission.locationWhenInUse,
            ]
          : <
              Permission
            >[]; // CoreBluetooth requests iOS permission through the BLE plugin.
      final results = await permissions.request();
      if (results.values.any((p) => p.isPermanentlyDenied)) {
        throw StateError(
          'Bluetooth permission denied. Enable it in system settings.',
        );
      }
      // Bluetooth off → ask Android to turn it on (system dialog), then wait
      // briefly for the radio to come up before scanning.
      if (Platform.isAndroid && radio.status == BleStatus.poweredOff) {
        message = 'Turn on Bluetooth to scan';
        emit();
        try {
          await _native.invokeMethod('enableBluetooth');
          await radio.statusStream
              .firstWhere((s) => s != BleStatus.poweredOff)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          /* user declined or timed out; handled below */
        }
        if (radio.status == BleStatus.poweredOff) {
          message = 'Turn on Bluetooth to continue';
          emit();
          try {
            await _native.invokeMethod('enableBluetooth');
            await radio.statusStream
                .firstWhere((s) => s == BleStatus.ready)
                .timeout(const Duration(seconds: 20));
          } catch (_) {
            throw StateError(
              'Bluetooth is off. Allow the prompt (or turn it on), then tap '
              'Find my scooter again.',
            );
          }
        }
      }
      await _scan?.cancel();
      devices.clear();
      scanning = true;
      message = 'Looking for nearby scooters';
      emit();
      _scan = radio
          .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
          .listen(
            (device) {
              // The old app listed every BLE device and let the user pick; a
              // name/service filter hides scooters that advertise without a name
              // or service UUID. Keep everything; sort likely scooters first.
              devices[device.id] = device;
              emit();
            },
            onError: (Object e) {
              final off = e.toString().toLowerCase().contains('disabled');
              message = off
                  ? 'Bluetooth is off. Allow the prompt, then tap Find my scooter again.'
                  : 'Scan failed: $e';
              scanning = false;
              emit();
              if (off) {
                unawaited(
                  _native.invokeMethod('enableBluetooth').catchError((_) {}),
                );
              }
            },
          );
    } catch (e) {
      message = e.toString();
      scanning = false;
      emit();
    }
  }

  Future<void> stopScan() async {
    await _scan?.cancel();
    _scan = null;
    scanning = false;
    emit();
  }

  /// While Android shows its pairing dialog the bond is "bonding" (11). Every
  /// GATT step fails during that time, so wait (up to 90 s) for the user.
  Future<void> _waitWhileBonding(String id) async {
    if (!Platform.isAndroid) return;
    final end = DateTime.now().add(const Duration(seconds: 90));
    var announced = false;
    while (await _bondState(id) == 11 && DateTime.now().isBefore(end)) {
      if (!announced) {
        announced = true;
        message = 'Confirm the pairing request on this phone';
        _step('bonding in progress — waiting for the pairing dialog');
        emit();
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (announced) _step('bond state now ${await _bondState(id)}');
  }

  Future<int> _bondState(String id) async {
    try {
      return await _native.invokeMethod<int>('bleBondState', {'address': id}) ??
          10;
    } catch (_) {
      return 10;
    }
  }

  /// Pairs and authenticates with a scooter, following the old app's proven
  /// ColorOS sequence: cancel classic discovery, connect and let encrypted
  /// access trigger Just Works bonding, and only if that fails force a bond
  /// (second try) or clear a stale one (last try), retrying up to four times.
  Future<void> connect(DiscoveredDevice device) async {
    if (!blePairingAvailable) {
      message = 'Bluetooth pairing is unavailable in this build';
      emit();
      return;
    }
    if (busy) return;
    busy = true;
    message = 'Pairing ${device.name.isEmpty ? device.id : device.name}';
    emit();
    try {
      await stopScan();
      if (Platform.isAndroid) {
        try {
          await _native.invokeMethod('bleCancelDiscovery');
        } catch (_) {}
      }
      Object? last;
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          if (attempt > 0) {
            message = 'Pairing… retry $attempt of 3';
            _step('retry $attempt: ${last.toString().split('\n').first}');
            emit();
            await Future<void>.delayed(const Duration(milliseconds: 700));
          }
          if (Platform.isAndroid) {
            // Classic GUI order: bond with the module FIRST (Just Works), and only
            // then connect and authenticate. Connecting first leaves the module
            // answering nothing until the link is encrypted.
            final bond = await _bondState(device.id);
            _step('bond state $bond');
            if (attempt <= 1 && bond != 12) {
              message = 'Confirm the pairing request on this phone';
              emit();
              await _close();
              final ok = await _native.invokeMethod<bool>('bleCreateBond', {
                'address': device.id,
              });
              _step('bond requested: ${ok == true ? 'bonded' : 'not bonded'}');
              await Future<void>.delayed(const Duration(milliseconds: 800));
            } else if (attempt == 3 && bond == 12) {
              message = 'Clearing an old pairing and trying again';
              emit();
              await _close();
              await _native.invokeMethod<bool>('bleRemoveBond', {
                'address': device.id,
              });
              await Future<void>.delayed(const Duration(milliseconds: 800));
              await _native.invokeMethod<bool>('bleCreateBond', {
                'address': device.id,
              });
              await Future<void>.delayed(const Duration(milliseconds: 800));
            }
          }
          _step('attempt ${attempt + 1}: connecting');
          await _connectOnce(device);
          _step('authenticated');
          return;
        } catch (e) {
          last = e;
          await _close();
        }
      }
      throw last ?? StateError('Could not pair with the scooter');
    } catch (e) {
      message = 'Pairing failed: $e';
      await _close();
    } finally {
      busy = false;
      emit();
    }
  }

  Future<void> _connectOnce(DiscoveredDevice device) async {
    {
      await _close();
      _assembler = BleAssembler();
      final connected = Completer<void>();
      _connection = radio
          .connectToDevice(
            id: device.id,
            connectionTimeout: const Duration(seconds: 15),
          )
          .listen(
            (state) {
              if (state.connectionState == DeviceConnectionState.connected &&
                  !connected.isCompleted) {
                connected.complete();
              }
              if (state.connectionState == DeviceConnectionState.disconnected) {
                _step('GATT disconnected');
                ready = false;
                _key = null;
                message = 'Bluetooth disconnected';
                if (!connected.isCompleted) {
                  connected.completeError(StateError(message));
                }
                emit();
              }
            },
            onError: (Object e) {
              if (!connected.isCompleted) connected.completeError(e);
              message = '$e';
              ready = false;
              emit();
            },
          );
      await connected.future.timeout(const Duration(seconds: 15));
      // Android usually keeps BONDING (pairing) for a moment after the connection
      // state reports "connected". Calling discoverServices during bonding fails
      // with "Bonding is in progress — wait for bonding to be finished before
      // executing more operations". Retry with a short backoff so discovery runs
      // once bonding completes (this was the real cause of "pairing failed").
      for (var attempt = 0; ; attempt++) {
        try {
          await radio.discoverAllServices(device.id);
          break;
        } catch (e) {
          final transient =
              e.toString().toLowerCase().contains('bonding') ||
              e.toString().toLowerCase().contains('discovery');
          if (attempt >= 10 || !transient) rethrow;
          message = 'Pairing… waiting for bonding to finish';
          _step(
            'discover failed (${e.toString().split('\n').first}); waiting for bond',
          );
          emit();
          await _waitWhileBonding(device.id);
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
      }
      final services = await radio.getDiscoveredServices(device.id);
      // Match case-insensitively — some stacks report UUIDs upper-cased, which
      // made the old lower-case startsWith miss the service and crash with a
      // cryptic "No element" (surfacing as a failed pairing). Give a clear
      // message when a device genuinely lacks the Nordic UART service.
      final service = services.firstWhere(
        (s) => s.id.toString().toLowerCase().startsWith('6e400001'),
        orElse: () => throw StateError(
          'Connected, but no OpenOLA UART service (6e400001) on this device. '
          'It may not be a compatible scooter — the Wi-Fi link still works.',
        ),
      );
      final tx = service.characteristics
          .firstWhere(
            (c) => c.id.toString().toLowerCase().startsWith('6e400003'),
            orElse: () => throw StateError('OpenOLA TX characteristic missing'),
          )
          .id;
      final rx = service.characteristics
          .firstWhere(
            (c) => c.id.toString().toLowerCase().startsWith('6e400002'),
            orElse: () => throw StateError('OpenOLA RX characteristic missing'),
          )
          .id;
      _write = QualifiedCharacteristic(
        characteristicId: tx,
        serviceId: service.id,
        deviceId: device.id,
      );
      _notifyChunks = 0;
      _seenTypes.clear();
      void subscribe() {
        _notifications?.cancel();
        _notifications = radio
            .subscribeToCharacteristic(
              QualifiedCharacteristic(
                characteristicId: rx,
                serviceId: service.id,
                deviceId: device.id,
              ),
            )
            .listen(
              (chunk) {
                _notifyChunks++;
                if (_notifyChunks <= 10) {
                  _step(
                    'rx ${chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
                  );
                }
                for (final frame in _assembler.feed(chunk)) {
                  _frames.add(_decoded(frame));
                }
              },
              onError: (Object e) {
                ready = false;
                message = 'Notification error: $e';
                emit();
              },
            );
      }

      subscribe();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _waitWhileBonding(device.id);
      // Same sequence as the proven old app: up to four seed requests, the
      // second without response, re-enabling notifications before the second and
      // fourth. A silent module usually means notifications were not on yet.
      List<int> seed = const [];
      for (var attempt = 0; attempt < 4 && seed.length != 8; attempt++) {
        _assembler = BleAssembler();
        _step('seed request ${attempt + 1}/4 (notify chunks: $_notifyChunks)');
        try {
          seed = (await _exchange(
            protocol.plain(48),
            0x70,
            timeout: const Duration(seconds: 5),
            noResponse: attempt == 1,
          )).take(8).toList();
        } catch (error) {
          _step(
            'no seed (${error.toString().split(':').first}); chunks: $_notifyChunks',
          );
        }
        if (seed.length != 8 && (attempt == 0 || attempt == 2)) {
          _step('re-enabling notifications');
          subscribe();
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
      if (seed.length != 8) {
        throw StateError(
          'No seed reply from the scooter module (notification chunks received: '
          '$_notifyChunks). Close the official Ola app and any other Bluetooth '
          'client, then try again.',
        );
      }
      final key = BleProtocol.seedKey(seed);
      _key = BleProtocol.sessionKey(seed, key);
      final ack = await _exchange(protocol.plain(49, key), 0x71);
      if (ack.isEmpty || ack[0] != 1) {
        throw StateError('Scooter did not authorize this session');
      }
      _step('authorized by the scooter');
      // The scooter often answers TEST_AES with an encrypted frame (or none), so
      // the old clients only wait briefly and carry on. Failing here used to
      // clear the pairing and drop an already-authorised session.
      try {
        await _exchange(
          protocol.encrypted(_key!, 50, 'D_ALIVE'.codeUnits),
          0x72,
          timeout: const Duration(milliseconds: 700),
        );
      } catch (error) {
        _step('no AES ack (continuing): ${error.toString().split(':').first}');
      }
      selectedName = device.name;
      ready = true;
      _startKeepalive();
      message =
          'Authenticated. Pairing and commands still require hardware testing.';
    }
  }

  /// Frames with a random IV are AES-CTR encrypted (type byte included). They
  /// are decrypted here into the same shape as a plain frame, so replies such
  /// as the TEST_AES ack (0x72) and the status frame (0x07) are recognised.
  List<int> _decoded(List<int> frame) {
    final key = _key;
    if (key == null || (frame[6] == 1 && frame[7] == 2) || frame.length < 12) {
      return frame;
    }
    final plain = BleProtocol.crypt(key, frame.sublist(8, frame.length - 3), [
      frame[6],
      frame[7],
    ]);
    if (plain.isEmpty) return frame;
    final type = plain[0], data = plain.sublist(1);
    if (type == 0x07 && data.length >= 5) {
      // ScooterAliveResponse: data[3] = state of charge %, data[4] = range km.
      if (data[3] <= 100) {
        soc = data[3];
        range = data[4];
        receivedAt = DateTime.now();
        if (_seenTypes.add(type)) _step('rx alive status');
        emit();
      }
    } else if (_seenTypes.add(type)) {
      _step(
        'rx type 0x${type.toRadixString(16)} '
        '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );
    }
    return [...frame.sublist(0, 8), type, ...data, 1, 0, 0];
  }

  /// The module drops an idle session, so ping with TEST_AES every few
  /// seconds while connected (what the classic GUI does).
  void _startKeepalive() {
    _keepalive?.cancel();
    _keepalive = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      final key = _key;
      if (!ready || key == null || busy || _keepaliveInFlight != null) return;
      try {
        final send = _send(protocol.encrypted(key, 50, 'D_ALIVE'.codeUnits));
        _keepaliveInFlight = send;
        await send;
      } catch (_) {
      } finally {
        _keepaliveInFlight = null;
      }
    });
  }

  Future<List<int>> _reply(int type, Duration timeout) async {
    final frame = await _frames.stream
        .firstWhere((f) => f[8] == type)
        .timeout(timeout);
    return frame.sublist(9, frame.length - 3);
  }

  Future<List<int>> _exchange(
    List<int> frame,
    int reply, {
    Duration timeout = const Duration(seconds: 5),
    bool noResponse = false,
  }) async {
    final response = _reply(reply, timeout);
    final results = await Future.wait<List<int>>([
      response,
      _send(frame, noResponse: noResponse).then((_) => <int>[]),
    ]);
    return results.first;
  }

  Future<void> _send(List<int> frame, {bool noResponse = false}) async {
    final characteristic =
        _write ?? (throw StateError('Bluetooth disconnected'));
    for (var i = 0; i < frame.length; i += 20) {
      final chunk = frame.skip(i).take(20).toList();
      if (noResponse) {
        await radio.writeCharacteristicWithoutResponse(
          characteristic,
          value: chunk,
        ).timeout(const Duration(seconds: 4));
      } else {
        await radio.writeCharacteristicWithResponse(
          characteristic,
          value: chunk,
        ).timeout(const Duration(seconds: 4));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> command(int command, String label) async {
    if (!blePairingAvailable) {
      message = 'Bluetooth commands are unavailable in this build';
      emit();
      return;
    }
    if (busy || !ready) return;
    final notificationsBefore = _notifyChunks;
    final elapsed = Stopwatch()..start();
    busy = true;
    _keepalive?.cancel();
    _keepalive = null;
    emit();
    try {
      await _keepaliveInFlight?.timeout(const Duration(seconds: 4));
      if (!ready || _key == null) {
        throw StateError('Bluetooth disconnected before command');
      }
      _step('sending $label');
      await _send(protocol.encrypted(_key!, 1, [command]));
      if (!ready) throw StateError('Bluetooth disconnected after command');
      _step(
        'command transmitted in ${elapsed.elapsedMilliseconds} ms; '
        '${_notifyChunks - notificationsBefore} notifications during send',
      );
      message =
          '$label sent; verify the scooter. Status reflects received broadcasts.';
    } catch (e) {
      _step('command failed: $e');
      ready = false;
      message = '$label failed: $e';
    } finally {
      busy = false;
      if (ready) _startKeepalive();
      emit();
    }
  }

  Future<void> _close() async {
    _keepalive?.cancel();
    _keepalive = null;
    try {
      await _keepaliveInFlight;
    } catch (_) {}
    ready = false;
    _key = null;
    _write = null;
    await _notifications?.cancel();
    await _connection?.cancel();
    _notifications = null;
    _connection = null;
  }

  Future<void> disconnect() async {
    await stopScan();
    await _close();
    soc = null;
    range = null;
    locked = null;
    receivedAt = null;
    emit();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_scan?.cancel());
    unawaited(_close());
    unawaited(_frames.close());
    super.dispose();
  }
}
