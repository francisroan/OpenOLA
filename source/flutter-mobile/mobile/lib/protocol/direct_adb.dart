import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DirectAdb {
  static const _channel = MethodChannel('in.crossfire.openola/adb');
  static const _network = MethodChannel('in.crossfire.openola/network');

  /// Byte-accurate transfer progress from the native ADB sync streams.
  /// `op` is `install` (phone → head unit) or `pull` (head unit → phone).
  static final progress = StreamController<TransferEvent>.broadcast();
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final a = Map<Object?, Object?>.from(call.arguments as Map);
      progress.add(
        TransferEvent(
          a['op'] as String,
          (a['sent'] as num).toInt(),
          (a['total'] as num).toInt(),
          (a['index'] as num).toInt(),
          (a['count'] as num).toInt(),
        ),
      );
    });
  }

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> connect(
    String host,
    int port, {
    bool phoneHotspot = false,
  }) async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    await _network.invokeMethod<bool>('bindProcessToWifi', {
      'phoneHotspot': phoneHotspot,
    });
    return await _channel.invokeMethod<String>('connect', {
          'host': _normalizeHost(host),
          'port': port,
        }) ??
        'Connected';
  }

  static Future<String> shell(String command) async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    return await _channel.invokeMethod<String>('shell', {'command': command}) ??
        '';
  }

  static Future<String> publicKey() async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    return await _channel.invokeMethod<String>('publicKey') ?? '';
  }

  /// Pushes each file to the head unit (reporting real byte progress on
  /// [progress]) and installs them in one package-manager session.
  static Future<String> installFiles(List<String> paths) async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    _ensureHandler();
    return await _channel.invokeMethod<String>('installFiles', {
          'paths': paths,
        }) ??
        '';
  }

  /// Pulls [remote] from the head unit to the phone-local file [local].
  static Future<String> pull(String remote, String local, int total) async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    _ensureHandler();
    return await _channel.invokeMethod<String>('pull', {
          'remote': remote,
          'local': local,
          'total': total,
        }) ??
        '';
  }

  static Future<String> install(String path) async {
    if (!supported) throw UnsupportedError('Direct ADB requires Android');
    return await _channel.invokeMethod<String>('install', {'path': path}) ??
        'Success';
  }

  static Future<void> disconnect() async {
    if (!supported) return;
    await _channel.invokeMethod<void>('disconnect');
  }

  static String _normalizeHost(String host) {
    final trimmed = host.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}

class TransferEvent {
  const TransferEvent(this.op, this.sent, this.total, this.index, this.count);
  final String op;
  final int sent, total, index, count;
}
