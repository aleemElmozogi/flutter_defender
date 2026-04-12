import 'dart:async';

import 'package:flutter/foundation.dart';

import 'flutter_defender_message_id.dart';

enum DefenderBlockingSource {
  emulator,
  overlay,
  screenCapture,
  screenshot,
  foreground,
}

enum FlutterDefenderGuardType {
  sensitive,
  otp,
}

class FlutterDefenderRuntimeState {
  final ValueNotifier<FlutterDefenderMessageId?> blockingMessageId =
      ValueNotifier<FlutterDefenderMessageId?>(null);

  bool initialized = false;
  bool initInFlight = false;
  bool isForeground = true;
  bool screenCaptureActive = false;
  bool emulatorBlocked = false;
  bool overlayViolationActive = false;
  bool isAuthenticated = false;
  bool protectionReady = false;
  bool pendingColdStartOtpPop = false;
  bool logoutTriggeredForCurrentBackground = false;
  int? pausedAtMs;
  Timer? temporaryBlockingTimer;
  DefenderBlockingSource? blockingSource;

  bool get hasPersistentBlockingSource =>
      blockingSource == DefenderBlockingSource.emulator ||
      blockingSource == DefenderBlockingSource.overlay ||
      blockingSource == DefenderBlockingSource.screenCapture ||
      blockingSource == DefenderBlockingSource.foreground;

  bool get shouldConcealGuardedContent =>
      !protectionReady || pendingColdStartOtpPop || hasPersistentBlockingSource;

  void cancelTimers() {
    temporaryBlockingTimer?.cancel();
    temporaryBlockingTimer = null;
  }

  void reset() {
    cancelTimers();
    initialized = false;
    initInFlight = false;
    isForeground = true;
    screenCaptureActive = false;
    emulatorBlocked = false;
    overlayViolationActive = false;
    isAuthenticated = false;
    protectionReady = false;
    pendingColdStartOtpPop = false;
    logoutTriggeredForCurrentBackground = false;
    pausedAtMs = null;
    blockingSource = null;
    blockingMessageId.value = null;
  }
}
