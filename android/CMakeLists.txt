cmake_minimum_required(VERSION 3.22.1)

project(flutter_defender LANGUAGES CXX)

add_library(flutter_defender SHARED
    ../src/native/src/ffi/defender_core.cpp
    ../src/native/src/crypto/defender_crypto.cpp
    ../src/native/src/platform/defender_platform.cpp
    ../src/native/src/platform/android/defender_android.cpp)

target_compile_features(flutter_defender PRIVATE cxx_std_17)

target_include_directories(flutter_defender PRIVATE
    ../src/native/include)

target_compile_options(flutter_defender PRIVATE
    -fvisibility=hidden
    -Wall
    -Wextra
    -Wno-unused-parameter)

target_link_options(flutter_defender PRIVATE
    "-Wl,-z,max-page-size=16384")
