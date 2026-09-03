# Development and release workflow

## Local checks

```bash
flutter analyze
flutter test
c++ -std=c++17 -Wall -Wextra -Werror -I src/native/include src/native/src/crypto/defender_crypto.cpp test/native/defender_crypto_test.cpp -o /tmp/flutter_defender_crypto_test && /tmp/flutter_defender_crypto_test
./tool/generate_pigeon.sh --check
flutter pub publish --dry-run

cd example
flutter build apk --release
flutter build ios --simulator --debug --no-pub
flutter test
```

## Generated platform channels

`pigeons/defender_messages.dart` is the readable source of truth for the typed
Flutter/native channel. Its Dart, Kotlin, and Swift outputs are intentionally
committed because package consumers compile them directly and do not run Pigeon
during their app build.

After changing the Pigeon schema, regenerate all outputs with:

```bash
./tool/generate_pigeon.sh
```

Do not edit `DefenderMessages.g.*` by hand. CI runs the same command with
`--check` and rejects generated files that do not match the schema and pinned
Pigeon version.

## Release automation

- Pull requests run package and example analysis and tests.
- CI verifies that `pubspec.yaml`, the podspec, and latest changelog entry use
  the same version.
- Pushes to `main` or `master` verify that the version is higher than the
  previous branch tip, then create the matching tag—for example `v0.7.0`.
- A tag runs the complete analyze and test gate, validates the tag against
  `pubspec.yaml`, runs the publish dry run, and publishes to pub.dev.

Pub.dev automated publishing only accepts the configured GitHub Actions tag
workflow. Configure the package for automated publishing and protect the
`pub.dev` GitHub Actions environment.

GitHub does not trigger another workflow when a workflow pushes a tag using the
default `GITHUB_TOKEN`. Add a fine-grained repository secret named
`RELEASE_TAG_TOKEN` with `Contents: Read and write`; the release-tag workflow
uses it only to push the release tag that starts the publishing workflow.
