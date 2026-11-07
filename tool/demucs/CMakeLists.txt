# MSVC build of demucs.cpp's multi-threaded CLI for Noor (Windows).
# Upstream's CMakeLists targets GCC on Linux (-Ofast -march=native, OpenBLAS);
# -march=native would also tie the binary to this machine's CPU.
cmake_minimum_required(VERSION 3.20)
project(noor_demucs C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static C++ runtime: no dependency on the user's VC++ redistributable version.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(DEMUCS_SRC "${DEMUCS_SOURCE_DIR}" CACHE PATH "demucs.cpp checkout")

# AVX2 runs on x64 CPUs from 2013 on and keeps Eigen's vectorised speed.
add_compile_options(/O2 /arch:AVX2 /openmp /bigobj /EHsc /utf-8 /W1)
add_compile_definitions(NDEBUG _USE_MATH_DEFINES NOMINMAX _CRT_SECURE_NO_WARNINGS)

set(LIBNYQUIST_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
add_subdirectory(${DEMUCS_SRC}/vendor/libnyquist libnyquist)

file(GLOB DEMUCS_SOURCES ${DEMUCS_SRC}/src/*.cpp)
add_library(demucs_lib STATIC ${DEMUCS_SOURCES})
target_include_directories(demucs_lib PUBLIC
  ${DEMUCS_SRC}/vendor/eigen
  ${DEMUCS_SRC}/src)

add_executable(demucs_mt ${DEMUCS_SRC}/cli-apps/demucs_mt.cpp)
target_include_directories(demucs_mt PRIVATE ${DEMUCS_SRC}/vendor/libnyquist/include)
target_link_libraries(demucs_mt demucs_lib libnyquist)
