#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INTEGRATION_TIMEOUT_SECONDS="${INTEGRATION_TIMEOUT_SECONDS:-900}"

run_with_timeout() {
  local seconds="$1"
  shift

  "$@" &
  local cmd_pid=$!
  local elapsed=0

  while kill -0 "$cmd_pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$seconds" ]]; then
      echo "ERROR: command timed out after ${seconds}s: $*"
      kill -TERM "$cmd_pid" 2>/dev/null || true
      wait "$cmd_pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$cmd_pid"
}

echo "==> flutter pub get"
flutter pub get

echo "==> flutter test (example)"
flutter test --no-pub

ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-}"
IOS_DEVICE_ID="${IOS_DEVICE_ID:-}"
RUN_ANDROID_INTEGRATION="${RUN_ANDROID_INTEGRATION:-1}"
RUN_IOS_INTEGRATION="${RUN_IOS_INTEGRATION:-1}"

if [[ "$RUN_ANDROID_INTEGRATION" == "1" && -z "$ANDROID_DEVICE_ID" ]]; then
  ANDROID_DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi

if [[ "$RUN_IOS_INTEGRATION" == "1" && -z "$IOS_DEVICE_ID" ]]; then
  IOS_DEVICE_ID="$(
    xcrun simctl list devices booted |
      sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p' |
      head -n 1
  )"
fi

if [[ "$RUN_ANDROID_INTEGRATION" == "1" && -z "$ANDROID_DEVICE_ID" ]]; then
  echo "ERROR: no Android emulator/device found. Start one and rerun."
  exit 1
fi

if [[ "$RUN_IOS_INTEGRATION" == "1" && -z "$IOS_DEVICE_ID" ]]; then
  echo "ERROR: no iOS simulator found. Start one and rerun."
  exit 1
fi

if [[ "$RUN_ANDROID_INTEGRATION" == "1" ]]; then
  echo "==> integration test on Android ($ANDROID_DEVICE_ID)"
  run_with_timeout \
    "$INTEGRATION_TIMEOUT_SECONDS" \
    flutter test integration_test --no-pub -d "$ANDROID_DEVICE_ID"
else
  echo "==> skipping Android integration test (RUN_ANDROID_INTEGRATION=0)"
fi

if [[ "$RUN_IOS_INTEGRATION" == "1" ]]; then
  echo "==> ensuring iOS simulator booted ($IOS_DEVICE_ID)"
  xcrun simctl bootstatus "$IOS_DEVICE_ID" -b

  echo "==> integration test on iOS ($IOS_DEVICE_ID)"
  if ! run_with_timeout \
    "$INTEGRATION_TIMEOUT_SECONDS" \
    flutter test integration_test --no-pub -d "$IOS_DEVICE_ID"; then
    echo "ERROR: iOS integration test failed."
    echo "If Xcode reports a missing iOS platform SDK, install it from:"
    echo "Xcode > Settings > Components"
    exit 1
  fi
else
  echo "==> skipping iOS integration test (RUN_IOS_INTEGRATION=0)"
fi

echo "==> all tests passed"
