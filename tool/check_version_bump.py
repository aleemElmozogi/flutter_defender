#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


VERSION_RE = re.compile(r"^version:[ \t]*['\"]?([^'\"\r\n]+)['\"]?[ \t]*$", re.MULTILINE)
PODSPEC_VERSION_RE = re.compile(
    r"^\s*s\.version\s*=\s*['\"]([^'\"]+)['\"]", re.MULTILINE
)
CHANGELOG_RELEASE_RE = re.compile(r"^## \[(?!Unreleased\])([^\]]+)\]", re.MULTILINE)
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


def read_matching_version(path: Path, pattern: re.Pattern[str], label: str) -> str:
    match = pattern.search(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"Could not find {label} version in {path}.")
    return match.group(1).strip()


def check_current_metadata(pubspec_path: str) -> str:
    pubspec = Path(pubspec_path)
    root = pubspec.parent
    pubspec_version = read_version(str(pubspec))
    podspec_version = read_matching_version(
        root / "ios" / "flutter_defender.podspec",
        PODSPEC_VERSION_RE,
        "podspec",
    )
    changelog_version = read_matching_version(
        root / "CHANGELOG.md",
        CHANGELOG_RELEASE_RE,
        "latest released changelog",
    )
    versions = {
        "pubspec.yaml": pubspec_version,
        "ios/flutter_defender.podspec": podspec_version,
        "CHANGELOG.md": changelog_version,
    }
    if len(set(versions.values())) != 1:
        details = ", ".join(f"{name}={version}" for name, version in versions.items())
        raise ValueError(f"Release metadata versions do not match: {details}.")
    return pubspec_version


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
    if len(sys.argv) == 3 and sys.argv[1] == "--check-current":
        try:
            version = check_current_metadata(sys.argv[2])
        except (OSError, ValueError) as error:
            print(f"Release metadata check failed: {error}", file=sys.stderr)
            return 1
        print(f"Release metadata verified at {version}")
        return 0

    if len(sys.argv) != 3:
        print(
            "Usage: check_version_bump.py <previous-pubspec> <current-pubspec>\n"
            "   or: check_version_bump.py --check-current <pubspec>"
        )
        return 2

    try:
        previous_raw = read_version(sys.argv[1])
        current_raw = check_current_metadata(sys.argv[2])
        previous = parse(previous_raw)
        current = parse(current_raw)
    except (OSError, ValueError) as error:
        print(f"Version check failed: {error}", file=sys.stderr)
        return 1

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
