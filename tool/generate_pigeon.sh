#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"

cd "$repository_root"
dart run pigeon --input pigeons/defender_messages.dart
dart format lib/src/platform/pigeon/defender_messages.g.dart

# Pigeon currently emits a few trailing spaces in Kotlin output. Normalize
# those so generated files also satisfy the repository whitespace check.
perl -pi -e 's/[ \t]+$//' \
  android/src/main/kotlin/aleem/flutter/defender/DefenderMessages.g.kt

if [[ "${1:-}" == "--check" ]]; then
  git diff --exit-code -- \
    lib/src/platform/pigeon/defender_messages.g.dart \
    android/src/main/kotlin/aleem/flutter/defender/DefenderMessages.g.kt \
    ios/flutter_defender/Sources/flutter_defender/DefenderMessages.g.swift
fi
