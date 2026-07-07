// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_defender",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-defender", targets: ["flutter_defender"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_defender",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "flutter_defender_native"
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-u", "_fd_is_debugger_attached",
                    "-u", "_fd_is_rooted_or_jailbroken",
                    "-u", "_fd_is_emulator",
                    "-u", "_fd_is_tampered",
                    "-u", "_fd_hmac_sha256_hex",
                    "-u", "_fd_free_string"
                ])
            ]
        ),
        .target(
            name: "flutter_defender_native",
            path: "Sources/flutter_defender_native",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("Native/include")
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
