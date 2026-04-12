import 'dart:async';

import 'package:flutter/material.dart';

import 'flutter_defender_message_id.dart';

enum DefenderBlockingSource {
  emulator,
  overlay,
  screenCapture,
  screenshot,
  foreground,
}

class FlutterDefenderRuntimeState {
  final ValueNotifier<FlutterDefenderMessageId?> blockingMessageId =
      ValueNotifier<FlutterDefenderMessageId?>(null);
  OverlayEntry? blockingEntry;
  Timer? overlayMonitorTimer;
  Timer? temporaryBlockingTimer;
  DateTime? pausedAt;
  DefenderBlockingSource? blockingSource;
  bool initialized = false;
  bool isRouteSensitive = false;
  bool isRouteRefreshScheduled = false;
  bool screenCaptureActive = false;
  bool emulatorBlocked = false;

  /// Whether the app considers the user logged in; drives PIN/session
  /// background timeout without relying on route names.
  bool isAuthenticated = false;

  bool get hasPersistentBlockingSource =>
      blockingSource == DefenderBlockingSource.overlay ||
      blockingSource == DefenderBlockingSource.screenCapture ||
      blockingSource == DefenderBlockingSource.foreground;

  void cancelTimers() {
    overlayMonitorTimer?.cancel();
    overlayMonitorTimer = null;
    temporaryBlockingTimer?.cancel();
    temporaryBlockingTimer = null;
  }

  void removeBlockingEntry() {
    blockingEntry?.remove();
    blockingEntry = null;
  }

  void resetBlockingState() {
    blockingSource = null;
    removeBlockingEntry();
  }

  void reset() {
    cancelTimers();
    resetBlockingState();
    pausedAt = null;
    initialized = false;
    isRouteSensitive = false;
    isRouteRefreshScheduled = false;
    screenCaptureActive = false;
    emulatorBlocked = false;
    isAuthenticated = false;
    blockingMessageId.value = null;
  }
}
