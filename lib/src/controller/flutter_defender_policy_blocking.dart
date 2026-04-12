part of '../../flutter_defender.dart';

extension _FlutterDefenderPolicyBlocking on FlutterDefender {
  void _recomputeBlockingState() {
    if (_activeGuards.isEmpty) {
      _clearBlockingState();
      return;
    }
    if (_runtime.emulatorBlocked) {
      _showBlocking(
        FlutterDefenderMessageId.emulatorReleaseBlocked,
        DefenderBlockingSource.emulator,
      );
      return;
    }
    if (_runtime.screenCaptureActive) {
      _showBlocking(
        FlutterDefenderMessageId.screenCaptureBlocked,
        DefenderBlockingSource.screenCapture,
      );
      return;
    }
    if (_config.enableForegroundCheck && !_runtime.isForeground) {
      _showBlocking(
        FlutterDefenderMessageId.foregroundRequired,
        DefenderBlockingSource.foreground,
      );
      return;
    }
    if (_runtime.overlayViolationActive) {
      _showBlocking(
        FlutterDefenderMessageId.overlaysBlocked,
        DefenderBlockingSource.overlay,
      );
      return;
    }
    if (_runtime.hasPersistentBlockingSource) {
      _clearBlockingState();
    }
  }

  void _showBlocking(
    FlutterDefenderMessageId messageId,
    DefenderBlockingSource source,
  ) {
    _runtime.cancelTimers();
    _runtime.blockingSource = source;
    _runtime.blockingMessageId.value = messageId;
  }

  void _showTemporaryBlocking(FlutterDefenderMessageId messageId) {
    if (_runtime.hasPersistentBlockingSource) {
      return;
    }
    _runtime.cancelTimers();
    _runtime.blockingSource = DefenderBlockingSource.screenshot;
    _runtime.blockingMessageId.value = messageId;
    _runtime.temporaryBlockingTimer = Timer(const Duration(seconds: 2), () {
      if (_runtime.blockingSource == DefenderBlockingSource.screenshot) {
        _clearBlockingState();
        _notifyListeners();
      }
    });
  }

  void _clearBlockingState() {
    _runtime.cancelTimers();
    _runtime.blockingSource = null;
    _runtime.blockingMessageId.value = null;
  }
}
