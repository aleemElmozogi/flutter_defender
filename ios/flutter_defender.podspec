#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_defender.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_defender'
  s.version          = '0.5.0'
  s.summary          = 'Secure-screen protection for Flutter apps.'
  s.description      = <<-DESC
Secure-screen protection for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/aleemElmozogi/flutter_defender'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Aleem Elmozogi' => 'abddo.55242@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../src/native/**/*.{h,cpp}'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../src/native/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -fvisibility=hidden'
  }
  s.swift_version = '5.0'

  s.resource_bundles = {'flutter_defender_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
