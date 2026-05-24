import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class NativeDefenderSignals {
  const NativeDefenderSignals({
    required this.available,
    required this.rootedOrJailbroken,
    required this.debuggerAttached,
    required this.emulator,
    required this.tamperingDetected,
  });

  const NativeDefenderSignals.unavailable()
    : available = false,
      rootedOrJailbroken = false,
      debuggerAttached = false,
      emulator = false,
      tamperingDetected = false;

  final bool available;
  final bool rootedOrJailbroken;
  final bool debuggerAttached;
  final bool emulator;
  final bool tamperingDetected;
}

class FlutterDefenderNative {
  FlutterDefenderNative._();

  static final FlutterDefenderNative instance = FlutterDefenderNative._();

  DynamicLibrary? _library;
  bool _loadAttempted = false;

  _NativeBool? _isRootedOrJailbroken;
  _NativeBool? _isDebuggerAttached;
  _NativeBool? _isEmulator;
  _NativeBool? _isTampered;
  _NativeHmacSha256Hex? _hmacSha256Hex;
  _NativeFreeString? _freeString;

  bool get isAvailable => _loadLibrary() != null;

  bool detectEmulator() {
    if (!isAvailable) {
      return false;
    }
    return _safeBool(_isEmulator);
  }

  NativeDefenderSignals collectSignals() {
    if (!isAvailable) {
      return const NativeDefenderSignals.unavailable();
    }
    return NativeDefenderSignals(
      available: true,
      rootedOrJailbroken: _safeBool(_isRootedOrJailbroken),
      debuggerAttached: _safeBool(_isDebuggerAttached),
      emulator: _safeBool(_isEmulator),
      tamperingDetected: _safeBool(_isTampered),
    );
  }

  String? signHmacSha256Hex({
    required Uint8List payload,
    required Uint8List key,
  }) {
    final hmac = _hmacSha256Hex;
    final free = _freeString;
    if (!isAvailable || hmac == null || free == null || key.isEmpty) {
      return null;
    }

    final payloadPtr = calloc<Uint8>(payload.length);
    final keyPtr = calloc<Uint8>(key.length);
    try {
      payloadPtr.asTypedList(payload.length).setAll(0, payload);
      keyPtr.asTypedList(key.length).setAll(0, key);
      final digestPtr = hmac(payloadPtr, payload.length, keyPtr, key.length);
      if (digestPtr == nullptr) {
        return null;
      }
      try {
        return digestPtr.cast<Utf8>().toDartString();
      } finally {
        free(digestPtr);
      }
    } finally {
      calloc.free(payloadPtr);
      calloc.free(keyPtr);
    }
  }

  DynamicLibrary? _loadLibrary() {
    if (_loadAttempted) {
      return _library;
    }
    _loadAttempted = true;
    try {
      if (Platform.isAndroid) {
        _library = DynamicLibrary.open('libflutter_defender.so');
      } else if (Platform.isIOS) {
        _library = DynamicLibrary.process();
      } else {
        _library = null;
      }
      final library = _library;
      if (library == null) {
        return null;
      }
      _isRootedOrJailbroken = library.lookupFunction<_NativeBoolC, _NativeBool>(
        'fd_is_rooted_or_jailbroken',
      );
      _isDebuggerAttached = library.lookupFunction<_NativeBoolC, _NativeBool>(
        'fd_is_debugger_attached',
      );
      _isEmulator = library.lookupFunction<_NativeBoolC, _NativeBool>(
        'fd_is_emulator',
      );
      _isTampered = library.lookupFunction<_NativeBoolC, _NativeBool>(
        'fd_is_tampered',
      );
      _hmacSha256Hex = library
          .lookupFunction<_NativeHmacSha256HexC, _NativeHmacSha256Hex>(
            'fd_hmac_sha256_hex',
          );
      _freeString = library
          .lookupFunction<_NativeFreeStringC, _NativeFreeString>(
            'fd_free_string',
          );
    } catch (_) {
      _library = null;
    }
    return _library;
  }

  bool _safeBool(_NativeBool? callback) {
    if (callback == null) {
      return false;
    }
    try {
      return callback() != 0;
    } catch (_) {
      return false;
    }
  }
}

typedef _NativeBoolC = Int32 Function();
typedef _NativeBool = int Function();

typedef _NativeHmacSha256HexC =
    Pointer<Char> Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32);
typedef _NativeHmacSha256Hex =
    Pointer<Char> Function(Pointer<Uint8>, int, Pointer<Uint8>, int);

typedef _NativeFreeStringC = Void Function(Pointer<Char>);
typedef _NativeFreeString = void Function(Pointer<Char>);
