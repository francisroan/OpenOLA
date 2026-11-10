import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import '../generated/wifican.pbgrpc.dart' as rpc;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';
import 'can.dart';
import 'uds.dart';

class MutualTlsCredentials extends ChannelCredentials {
  MutualTlsCredentials(this.context)
    : super.secure(authority: 'ola.scooter.diag');
  final SecurityContext context;
  @override
  SecurityContext get securityContext => context;
  static Future<MutualTlsCredentials> load() async {
    final context = SecurityContext(withTrustedRoots: false);
    final root = await rootBundle.loadString('assets/certs/ola_diag_root.crt');
    if (Platform.isIOS) {
      final der = base64Decode(
        root.replaceAll(RegExp(r'-----[^-]+-----|\s'), ''),
      );
      context.setTrustedCertificatesBytes(der);
      context.usePrivateKeyBytes(
        (await rootBundle.load(
          'assets/certs/ecos-ios.p12',
        )).buffer.asUint8List(),
      );
    } else {
      context.setTrustedCertificatesBytes(utf8.encode(root));
      context.useCertificateChainBytes(
        (await rootBundle.load('assets/certs/ecos.crt')).buffer.asUint8List(),
      );
      context.usePrivateKeyBytes(
        (await rootBundle.load('assets/certs/ecos.key')).buffer.asUint8List(),
      );
    }
    context.setAlpnProtocols(['h2'], false);
    return MutualTlsCredentials(context);
  }
}

class WifiCan implements CanLink {
  static const _androidNetwork = MethodChannel('in.crossfire.openola/network');

  /// Interface names that are never the scooter's network (mobile data, VPN
  /// tunnels, loopback, USB tethering to a computer).
  static final _skipInterface = RegExp(
    r'^(lo|rmnet|ccmni|tun|ppp|dummy|vgate|rndis|usb|v4-|clat)',
    caseSensitive: false,
  );

  /// The /24 hosts to probe for each usable private IPv4 interface address,
  /// excluding the phone's own addresses. Pure function so it can be tested.
  static List<String> subnetHosts(
    Iterable<({String name, String address})> interfaces,
  ) {
    final own = {for (final i in interfaces) i.address};
    final out = <String>[];
    final seenBases = <String>{};
    for (final iface in interfaces) {
      if (_skipInterface.hasMatch(iface.name)) continue;
      final parts = iface.address.split('.');
      if (parts.length != 4) continue;
      final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
      final private =
          a == 10 ||
          (a == 192 && b == 168) ||
          (a == 172 && b != null && b >= 16 && b <= 31);
      if (!private) continue;
      final base = parts.take(3).join('.');
      if (!seenBases.add(base)) continue;
      for (var host = 1; host <= 254; host++) {
        final candidate = '$base.$host';
        if (!own.contains(candidate)) out.add(candidate);
      }
    }
    return out;
  }

  /// Returns the hosts that accept a TCP connection on [port], probing all of
  /// them concurrently with a short timeout.
  static Future<List<String>> probeHosts(
    List<String> hosts,
    int port, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    final open = <String>[];
    await Future.wait([
      for (final host in hosts)
        Socket.connect(
              host.startsWith('[') && host.endsWith(']')
                  ? host.substring(1, host.length - 1)
                  : host,
              port,
              timeout: timeout,
            )
            .then((socket) {
              open.add(host);
              socket.destroy();
            })
            .catchError((Object _) {}),
    ]);
    open.sort((a, b) {
      int last(String v) => int.tryParse(v.split('.').last) ?? 0;
      return last(a).compareTo(last(b));
    });
    return open;
  }

  /// Finds Gen1 (IPv4) head units: the scooter's own hotspot or a scooter that
  /// joined this phone's hotspot or the same Wi-Fi. Scans the /24 of every
  /// usable local interface for the diagnostics port.
  static Future<List<String>> discoverIpv4Hosts({
    int port = 50005,
    bool phoneHotspot = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    await bindNetwork(phoneHotspot: phoneHotspot);
    final interfaces = <({String name, String address})>[];
    for (final iface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    )) {
      for (final address in iface.addresses) {
        interfaces.add((name: iface.name, address: address.address));
      }
    }
    return probeHosts(subnetHosts(interfaces), port);
  }

  /// Selects the local network route (Wi-Fi, or the phone's own hotspot) the
  /// scooter is reached over.
  static Future<bool> bindNetwork({bool phoneHotspot = false}) async {
    try {
      final ok =
          await _androidNetwork
              .invokeMethod<bool>('bindProcessToWifi', {
                'phoneHotspot': phoneHotspot,
              })
              .timeout(const Duration(seconds: 8)) ??
          false;
      if (!ok) {
        throw StateError('Android could not select a local network route.');
      }
      return ok;
    } on TimeoutException {
      throw StateError(
        'Timed out selecting the local network. Connect the scooter to this phone\'s hotspot or join the same Wi-Fi, then retry.',
      );
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Could not select the scooter network.',
      );
    }
  }

  /// Returns local IPv6 gateway/neighbour candidates for Gen2/3 head units.
  /// Link-local literals are bracketed and include their interface scope.
  static Future<List<String>> discoverIpv6Hosts({
    int port = 50005,
    bool verifyPort = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    final hosts =
        await _androidNetwork.invokeListMethod<String>('discoverIpv6Hosts') ??
        const <String>[];
    final candidates = hosts
        .map((host) => host.trim())
        .where((host) => host.isNotEmpty && host.contains(':'))
        .toSet()
        .toList(growable: false);
    // A neighbour or gateway is only a candidate. The connection screen probes
    // it before trying gRPC; callers that only need discovery can keep the raw
    // list (including test and read-only inspection paths).
    return verifyPort ? probeHosts(candidates, port) : candidates;
  }

  ClientChannel? _channel;
  rpc.WifiCanRpcClient? _client;
  String? _host;
  int? _port;
  rpc.WifiCanRpcClient get client =>
      _client ?? (throw StateError('Not connected'));
  StreamSubscription<rpc.CANPacket>? _stream;
  final _queues = <int, Queue<List<int>>>{};
  final _waiting = <int, Completer<List<int>>>{};
  void Function(CanPacket)? onFrame;
  void Function(Object)? onStreamError;
  String? streamMode;
  bool _boundToWifi = false;
  Future<void> connect(
    String host,
    int port,
    bool secure, {
    bool phoneHotspot = false,
  }) async {
    _host = host;
    _port = port;
    if (Platform.isAndroid) {
      try {
        _boundToWifi =
            await _androidNetwork
                .invokeMethod<bool>('bindProcessToWifi', {
                  'phoneHotspot': phoneHotspot,
                })
                .timeout(const Duration(seconds: 8)) ??
            false;
        if (!_boundToWifi) {
          throw StateError('Android could not select a local network route.');
        }
      } on TimeoutException {
        throw StateError(
          'Timed out selecting the local network. Connect the scooter to this phone\'s hotspot or join the same Wi-Fi, then retry.',
        );
      } on PlatformException catch (error) {
        throw StateError(
          error.message ?? 'Could not select the scooter network.',
        );
      }
    }
    // Gen2/3 (E2) units firewall the diagnostics port on IPv4 and answer only
    // over IPv6, so accept a bracketed or bare IPv6 literal (optionally scoped,
    // e.g. [fe80::1%wlan0]). Strip brackets for the socket; the process is
    // already bound to the Wi-Fi network, so a link-local route resolves there.
    final bracketed = host.startsWith('[') && host.endsWith(']');
    final socketHost = bracketed ? host.substring(1, host.length - 1) : host;
    final isIpv6 = socketHost.contains(':');
    // Creating a gRPC channel is lazy. Require a reachable diagnostic socket
    // here so a discovered IPv6 neighbour cannot appear "connected" merely
    // because its address was returned by Android.
    final probe = await Socket.connect(
      socketHost,
      port,
      timeout: const Duration(seconds: 2),
    );
    probe.destroy();
    final credentials = secure
        ? await MutualTlsCredentials.load()
        : ChannelCredentials.insecure(
            authority: isIpv6 ? '[$socketHost]' : socketHost,
          );
    _channel = ClientChannel(
      socketHost,
      port: port,
      options: ChannelOptions(credentials: credentials),
    );
    _client = rpc.WifiCanRpcClient(_channel!);
  }

  /// Reopens a secure channel without TLS for legacy S1 units.
  Future<void> reconnectInsecure({bool phoneHotspot = false}) async {
    final host = _host;
    final port = _port;
    if (host == null || port == null) throw StateError('Not connected');
    await close();
    await connect(host, port, false, phoneHotspot: phoneHotspot);
  }

  static bool isTlsHandshakeError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('handshakeexception') ||
        text.contains('handshake error') ||
        text.contains('tls handshake');
  }

  Future<void> init(List<int> ids) async {
    final response = await client.init(
      rpc.Register(canIds: ids),
      options: CallOptions(timeout: const Duration(seconds: 15)),
    );
    _success(response);
  }

  Future<void> reader({bool dump = false}) async {
    await _stream?.cancel();
    final stream = dump
        ? client.canDumpStream(Empty())
        : client.readCanStream(Empty());
    streamMode = dump ? 'dump' : 'diag';
    _stream = stream.listen(
      (packet) {
        CanPacket frame;
        try {
          frame = CanPacket.decode(packet.canFrame);
        } on FormatException {
          return;
        }
        final waiter = _waiting.remove(frame.id);
        if (waiter != null) {
          waiter.complete(frame.data);
        } else {
          final queue = _queues.putIfAbsent(frame.id, Queue.new);
          if (queue.length >= 2048) queue.removeFirst();
          queue.add(frame.data);
        }
        onFrame?.call(frame);
      },
      onError: (Object error) {
        streamMode = null;
        onStreamError?.call(error);
      },
      onDone: () {
        streamMode = null;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> write(int id, List<int> data) async {
    final response = await client.writeCanFrame(
      rpc.CANPacket(canFrame: CanPacket.encode(id, data)),
      options: CallOptions(timeout: const Duration(seconds: 15)),
    );
    _success(response);
  }

  @override
  void clearQueue(int id) => _queues[id]?.clear();
  @override
  Future<List<int>> receive(int id, Duration timeout) async {
    final queue = _queues[id];
    if (queue != null && queue.isNotEmpty) return queue.removeFirst();
    if (_waiting.containsKey(id)) {
      throw StateError('Concurrent receive for CAN ID $id');
    }
    final waiter = Completer<List<int>>();
    _waiting[id] = waiter;
    try {
      return await waiter.future.timeout(timeout);
    } finally {
      if (identical(_waiting[id], waiter)) _waiting.remove(id);
    }
  }

  void _success(rpc.Response response) {
    if (response.status != rpc.RespStatus.RESP_SUCCESS) {
      throw StateError('Scooter rejected RPC: ${response.statusMsg}');
    }
  }

  Future<String> mode() async => (await client.getVehicleOperationMode(
    Empty(),
    options: CallOptions(timeout: const Duration(seconds: 10)),
  )).curMode.name.replaceFirst('VEHICLE_OP_STATE_', '');
  Future<void> setMode(bool service) async => _success(
    await client.setVehicleOperationMode(
      rpc.VehicleOperationMode(
        curMode: service
            ? rpc.VehicleOperationState.VEHICLE_OP_STATE_SERVICE
            : rpc.VehicleOperationState.VEHICLE_OP_STATE_CUST,
      ),
      options: CallOptions(timeout: const Duration(seconds: 15)),
    ),
  );
  Future<String> firmware() async => (await client.getSwVersion(
    Empty(),
    options: CallOptions(timeout: const Duration(seconds: 10)),
  )).statusMsg;
  Future<String> identifiers() async => (await client.getVehicleIdentifiers(
    Empty(),
    options: CallOptions(timeout: const Duration(seconds: 10)),
  )).manifestJson;

  /// Read the opaque ECOS/Dyno configuration strings exposed by the vehicle
  /// daemon. These values are deliberately returned unchanged; their encoding
  /// is not yet recovered and must not be rewritten by the app.
  Future<rpc.EcosDynoFlags> ecosDynoFlags() async => client.getEcosDynoFlags(
        Empty(),
        options: CallOptions(timeout: const Duration(seconds: 15)),
      );

  /// Round-trip the exact Dyno value just read from the scooter. This is a
  /// no-op probe and refuses a caller-provided replacement payload.
  Future<rpc.Response> roundTripDynoFlag(String currentValue) async {
    if (currentValue.isEmpty) {
      throw ArgumentError('Cannot round-trip an empty Dyno flag');
    }
    final before = await ecosDynoFlags();
    if (before.dyno != currentValue) {
      throw StateError('Dyno flag changed since it was read; no write sent');
    }
    return client.setDynoFlag(
      rpc.DynoFlag(flag: currentValue),
      options: CallOptions(timeout: const Duration(seconds: 15)),
    );
  }

  /// Ask the daemon to re-apply its provisioned TechPack configuration.
  ///
  /// This is the recovered official daemon entry point, not a fabricated
  /// entitlement payload. The daemon may reject it or re-apply cloud state.
  Future<rpc.ConfigUpdateResp> techPackUpdateProbe({String type = 'techpack'}) {
    const allowed = {'techpack', 'ecos', 'dyno'};
    if (!allowed.contains(type)) {
      throw ArgumentError('Unsupported TechPack probe type: $type');
    }
    return client.techPackUpdate(
      rpc.ConfigType(type: type),
      options: CallOptions(timeout: const Duration(seconds: 30)),
    );
  }

  /// Read-only check of the scooter's diagnostic certificate status. Safe
  /// (does NOT generate or install certs). Returns the scooter's status text.
  Future<String> validateCerts() async {
    final r = await client.validateCerts(
      Empty(),
      options: CallOptions(timeout: const Duration(seconds: 15)),
    );
    if (r.status != rpc.RespStatus.RESP_SUCCESS) {
      throw StateError(r.statusMsg.isEmpty ? 'Validation failed' : r.statusMsg);
    }
    return r.statusMsg.isEmpty ? 'Diagnostic identity valid' : r.statusMsg;
  }

  // --- Software update (OTA) over gRPC. Brick-capable; every caller must gate
  // on Developer Mode + Service mode + an explicit confirmation. swStatus is the
  // only read-only one. ---

  /// Read-only: current OTA state (NONE/IDLE/UPLOAD…/INSTALLING…/SUCCESS/FAILED).
  Future<String> swStatus() async {
    final s = await client.swUpdateCheckStatus(
      Empty(),
      options: CallOptions(timeout: const Duration(seconds: 10)),
    );
    final name = s.status.name.replaceFirst('SW_UPDATE_STATE_', '');
    return s.statusMsg.isEmpty ? name : '$name · ${s.statusMsg}';
  }

  Future<void> swClearCache() async {
    final r = await client.swUpdateFileClearCache(
      Empty(),
      options: CallOptions(timeout: const Duration(seconds: 20)),
    );
    if (r.status != rpc.RespStatus.RESP_SUCCESS) {
      throw StateError(
        r.statusMsg.isEmpty ? 'Clear cache rejected' : r.statusMsg,
      );
    }
  }

  Future<void> swSendMeta(String name, int size, String csum) async {
    final r = await client.swUpdateFileTransferMeta(
      rpc.SwUpdateFileMetadataReq(name: name, size: size, csum: csum),
      options: CallOptions(timeout: const Duration(seconds: 25)),
    );
    if (r.status != rpc.RespStatus.RESP_SUCCESS) {
      throw StateError(r.statusMsg.isEmpty ? 'Metadata rejected' : r.statusMsg);
    }
  }

  Future<String> swTransfer(
    List<int> bytes, {
    int chunkSize = 64 * 1024,
    void Function(int sent)? onProgress,
  }) async {
    Stream<rpc.SwUpdateFileChunk> chunks() async* {
      var sent = 0;
      while (sent < bytes.length) {
        final end = sent + chunkSize < bytes.length
            ? sent + chunkSize
            : bytes.length;
        yield rpc.SwUpdateFileChunk(chunk: bytes.sublist(sent, end));
        sent = end;
        onProgress?.call(sent);
      }
    }

    final resp = await client.swUpdateFileTransfer(
      chunks(),
      options: CallOptions(timeout: const Duration(minutes: 5)),
    );
    return resp.toString();
  }

  /// Runs a shell command on the head unit as root (uid 0) via
  /// ExecuteADBCommand and returns its output. Shell exit codes are not
  /// surfaced as errors — the output (stdout/stderr) comes back in status_msg.
  Future<String> adb(
    String cmd, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final r = await client.executeADBCommand(
      rpc.Command(cmdMsg: cmd),
      options: CallOptions(timeout: timeout),
    );
    return r.statusMsg;
  }

  /// [target] is a component name: ALL, AOSP, BCM, BLE, BMS, HU or MCU.
  Future<void> swTrigger(String target) async {
    final t = rpc.SwUpdateTrigger.values.firstWhere(
      (v) => v.name == 'SW_UPDATE_TRIGGER_$target',
      orElse: () => throw ArgumentError('Unknown update target: $target'),
    );
    final r = await client.swUpdateTriggerUpgrade(
      rpc.SwUpdateTriggerCmd(trigger: t),
      options: CallOptions(timeout: const Duration(seconds: 25)),
    );
    if (r.status != rpc.RespStatus.RESP_SUCCESS) {
      throw StateError(r.statusMsg.isEmpty ? 'Trigger rejected' : r.statusMsg);
    }
  }

  Future<String> remoteTest(int command, bool start) async {
    final req = rpc.RmtCmdReq(cmdId: rpc.RmtCmdList.valueOf(command));
    final value = start ? 1 : 2;
    switch (command) {
      case 1:
        req.subCmdLcd = rpc.RmtSubCmdLcd.valueOf(value)!;
      case 2:
        req.subCmdGps = rpc.RmtSubCmdGps.valueOf(value)!;
      case 3:
        req.subCmdBt = rpc.RmtSubCmdBt.valueOf(value)!;
      case 4:
        req.subCmdBle = rpc.RmtSubCmdBle.valueOf(value)!;
      case 5:
        req.subCmdWifi = rpc.RmtSubCmdWifi.valueOf(value)!;
      case 6:
        req.subCmdSpkr = rpc.RmtSubCmdSpkr.valueOf(value)!;
      case 7:
        req.subCmdMic = rpc.RmtSubCmdMic.valueOf(value)!;
      case 8:
        req.subCmdMcuCal = rpc.RmtSubCmdMcuCal.valueOf(value)!;
      case 12:
        req.subCmdEsim = rpc.RmtSubCmdEsim.valueOf(value)!;
      default:
        throw ArgumentError('Unsupported self-test $command');
    }
    final response = await client.remoteRunTestCmd(
      req,
      options: CallOptions(timeout: const Duration(seconds: 20)),
    );
    if (response.respStatus != rpc.RmtCmdRespStatus.RMT_CMD_RESP_SUCCESS) {
      throw StateError('Test rejected: ${response.respStr}');
    }
    return response.respStr;
  }

  Future<String> restartHeadUnit() async {
    final response = await client.runSystemTestCmd(
      rpc.SystemTestCmd(cmdId: rpc.SystemCmdList.SYS_CMD_SOM),
      options: CallOptions(timeout: const Duration(seconds: 5)),
    );
    if (response.respStatus != rpc.RmtCmdRespStatus.RMT_CMD_RESP_SUCCESS) {
      throw StateError('Restart rejected: ${response.respStr}');
    }
    return response.respStr;
  }

  Future<void> close() async {
    await _stream?.cancel();
    _stream = null;
    streamMode = null;
    for (final waiter in _waiting.values) {
      if (!waiter.isCompleted) waiter.completeError(StateError('Disconnected'));
    }
    _waiting.clear();
    _queues.clear();
    // The production diagnostic client only cancels its dump stream and closes
    // the channel. Deinit changes the scooter-side CAN registration despite
    // this client never having called Init for passive monitoring.
    try {
      await _channel?.terminate();
    } finally {
      _channel = null;
      _client = null;
      _host = null;
      _port = null;
      if (_boundToWifi && Platform.isAndroid) {
        try {
          await _androidNetwork.invokeMethod<bool>('restoreDefaultNetwork');
        } catch (_) {
          /* best-effort restoration if Android is already shutting down */
        }
        _boundToWifi = false;
      }
    }
  }
}
