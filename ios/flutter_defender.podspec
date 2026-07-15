#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_defender.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_defender'
  s.version          = '0.5.1'
  s.summary          = 'Secure-screen protection for Flutter apps.'
  s.description      = <<-DESC
A Flutter security plugin for guarded screens, lifecycle-aware concealment,
runtime risk signals, secure storage helpers, and native request signing.
                       DESC
  s.homepage         = 'https://github.com/aleemElmozogi/flutter_defender'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'Aleem Elmozogi' => 'abddo.55242@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_defender/Sources/flutter_defender/**/*.swift',
                   'flutter_defender/Sources/flutter_defender_native/**/*.h',
                   'flutter_defender/Sources/flutter_defender_native/Native/src/**/*.cpp'
  s.public_header_files = []
  s.private_header_files = 'flutter_defender/Sources/flutter_defender_native/Native/**/*.h',
                           'flutter_defender/Sources/flutter_defender_native/include/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/flutter_defender/Sources/flutter_defender_native/Native/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -fvisibility=hidden'
  }
  s.swift_version = '5.0'

  s.resource_bundles = {'flutter_defender_privacy' => ['flutter_defender/Sources/flutter_defender/PrivacyInfo.xcprivacy']}
end
