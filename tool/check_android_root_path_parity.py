#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path


STRING_RE = re.compile(r'"(/[^"]+)"')


def extract_paths(path: Path, start: str, end: str) -> set[str]:
    text = path.read_text(encoding="utf-8")
    try:
        block = text.split(start, 1)[1].split(end, 1)[0]
    except IndexError as error:
        raise ValueError(f"Could not locate root-path list in {path}.") from error
    return set(STRING_RE.findall(block))


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    kotlin_paths = extract_paths(
        root
        / "android/src/main/kotlin/aleem/flutter/defender/AdvancedSecurityDetector.kt",
        "val knownPaths = listOf(",
        ")",
    )
    cpp_paths = extract_paths(
        root / "src/native/src/platform/android/defender_android.cpp",
        "kRootPaths = {",
        "};",
    )
    if kotlin_paths != cpp_paths:
        print("Android root indicator paths are out of sync.", file=sys.stderr)
        for path in sorted(kotlin_paths - cpp_paths):
            print(f"Kotlin only: {path}", file=sys.stderr)
        for path in sorted(cpp_paths - kotlin_paths):
            print(f"C++ only: {path}", file=sys.stderr)
        return 1
    print(f"Android root indicator parity verified ({len(kotlin_paths)} paths)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
