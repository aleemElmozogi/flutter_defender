part of '../../flutter_defender.dart';

extension _FlutterDefenderGuardManagement on FlutterDefender {
  Future<void> registerGuard({
    required Object token,
    required FlutterDefenderGuardType type,
    required VoidCallback popRoute,
  }) async {
    await (_initFuture ??
        Future<void>.error(
          StateError(
            'FlutterDefender.init() must complete before guarded screens are used.',
          ),
        ));

    _activeGuards[token] = _GuardBinding(type: type, popRoute: popRoute);
    await _syncProtection();

    if (type == FlutterDefenderGuardType.otp &&
        _runtime.pendingColdStartOtpPop) {
      _runtime.pendingColdStartOtpPop = false;
      _notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final _GuardBinding? binding = _activeGuards[token];
        if (binding != null && binding.type == FlutterDefenderGuardType.otp) {
          binding.popRoute();
        }
      });
    }
  }

  Future<void> unregisterGuard(Object token) async {
    _activeGuards.remove(token);
    if (_activeGuards.isEmpty) {
      _runtime.overlayViolationActive = false;
      _clearBlockingState();
    }
    await _syncProtection();
  }

  pigeon.DefenderGuardKind get _currentGuardKind {
    for (final _GuardBinding binding
        in _activeGuards.values.toList().reversed) {
      if (binding.type == FlutterDefenderGuardType.otp) {
        return pigeon.DefenderGuardKind.otp;
      }
    }
    return _activeGuards.isEmpty
        ? pigeon.DefenderGuardKind.none
        : pigeon.DefenderGuardKind.sensitive;
  }

  void _popLatestOtpGuard() {
    for (final _GuardBinding binding
        in _activeGuards.values.toList().reversed) {
      if (binding.type == FlutterDefenderGuardType.otp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          binding.popRoute();
        });
        break;
      }
    }
  }
}
