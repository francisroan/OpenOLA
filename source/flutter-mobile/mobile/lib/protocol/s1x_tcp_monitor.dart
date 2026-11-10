import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'can.dart';
import 's1x_tcp_frame.dart';
import 'wifi_can.dart';

/// Passive S1X Plus Phase 2 socket monitor. It never sends data to the scooter.
class S1xTcpMonitor {
  static const _network = MethodChannel('in.crossfire.openola/network');
  final _framer = S1xTcpFramer();
  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  bool _boundToWifi = false;
  bool get active => _socket != null;
  void Function(CanPacket)? onFrame;
  void Function(Object)? onError;

  Future<void> connect(
    String host,
    int port, {
    bool phoneHotspot = false,
    bool bindNetwork = true,
  }) async {
    if (_socket != null) throw StateError('S1X TCP monitor already connected');
    if (bindNetwork && Platform.isAndroid) {
      _boundToWifi = await WifiCan.bindNetwork(phoneHotspot: phoneHotspot);
      if (!_boundToWifi) {
        throw StateError('Android could not select the scooter network.');
      }
    }
    final socketHost = host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;
    try {
      final socket = await Socket.connect(
        socketHost,
        port,
        timeout: const Duration(seconds: 4),
      );
      _socket = socket;
      _subscription = socket.listen(
        (chunk) {
          try {
            for (final frame in _framer.add(chunk)) {
              // The official signal parser accepts ten bytes at offset 8.
              // OpenOLA's CAN decoders consume the first eight CAN data bytes.
              onFrame?.call(CanPacket(frame.canId, frame.data.sublist(0, 8)));
            }
          } on FormatException catch (error) {
            _framer.clear();
            onError?.call(error);
          }
        },
        onError: (Object error) {
          _socket = null;
          onError?.call(error);
        },
        onDone: () {
          _socket = null;
          onError?.call(StateError('S1X TCP socket closed'));
        },
        cancelOnError: true,
      );
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _framer.clear();
    if (_boundToWifi && Platform.isAndroid) {
      try {
        await _network.invokeMethod<bool>('restoreDefaultNetwork');
      } catch (_) {
        // The socket is already closed; a missing platform channel is harmless.
      }
    }
    _boundToWifi = false;
  }
}
