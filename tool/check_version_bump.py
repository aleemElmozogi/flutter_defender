#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


VERSION_RE = re.compile(r"^version:[ \t]*['\"]?([^'\"\r\n]+)['\"]?[ \t]*$", re.MULTILINE)
SEMVER_RE = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


@dataclass(frozen=True)
class Version:
    major: int
    minor: int
    patch: int
    prerelease: tuple[tuple[int, object], ...]


def read_version(path: str) -> str:
    text = Path(path).read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if not match:
        raise ValueError(f"Could not find a version field in {path}.")
    return match.group(1).strip()


def parse(version: str) -> Version:
    match = SEMVER_RE.fullmatch(version)
    if not match:
        raise ValueError(
            f"Unsupported version format '{version}'. Expected semantic versioning."
        )

    prerelease = match.group(4)
    identifiers: list[tuple[int, object]] = []
    if prerelease:
        for identifier in prerelease.split("."):
            if identifier.isdigit():
                identifiers.append((0, int(identifier)))
            else:
                identifiers.append((1, identifier))

    return Version(
        major=int(match.group(1)),
        minor=int(match.group(2)),
        patch=int(match.group(3)),
        prerelease=tuple(identifiers),
    )


def compare(left: Version, right: Version) -> int:
    left_core = (left.major, left.minor, left.patch)
    right_core = (right.major, right.minor, right.patch)
    if left_core != right_core:
        return 1 if left_core > right_core else -1

    if not left.prerelease and not right.prerelease:
        return 0
    if not left.prerelease:
        return 1
    if not right.prerelease:
        return -1

    for left_id, right_id in zip(left.prerelease, right.prerelease):
        if left_id == right_id:
            continue
        return 1 if left_id > right_id else -1

    if len(left.prerelease) == len(right.prerelease):
        return 0
    return 1 if len(left.prerelease) > len(right.prerelease) else -1


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: check_version_bump.py <previous-pubspec> <current-pubspec>")
        return 2

    previous_raw = read_version(sys.argv[1])
    current_raw = read_version(sys.argv[2])
    previous = parse(previous_raw)
    current = parse(current_raw)

    if compare(current, previous) <= 0:
        print(
            "Version check failed: "
            f"current version {current_raw} must be greater than previous version {previous_raw}.",
            file=sys.stderr,
        )
        return 1

    print(f"Version bump verified: {previous_raw} -> {current_raw}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
