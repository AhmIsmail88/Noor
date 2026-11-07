# Builds Noor's music separation engine for Windows and installs it next to
# the app: engines\demucs\{demucs.exe, vcomp140.dll, htdemucs-4s-f16.bin}.
# Steps already done are skipped. Needs git, Python 3.12, and Visual Studio
# 2022 Build Tools (the same ones Flutter uses).
#
# The model is converted here from Meta's official Demucs weights (MIT),
# not downloaded pre-converted. Details: docs/MUSIC_SEPARATION.md.
param([ValidateSet('Debug','Release')][string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'build\demucs'
$src = Join-Path $work 'src'
$commit = '4edae497a114de1ccb17ac9b4a2b8fc0144714d7'  # tested version
$here = Join-Path $PSScriptRoot 'demucs'
New-Item -ItemType Directory -Force -Path $work | Out-Null

# 1. demucs.cpp at the tested commit, with the Windows patch.
if (!(Test-Path (Join-Path $src '.git'))) {
    git clone --recurse-submodules https://github.com/sevagh/demucs.cpp $src
    git -C $src checkout $commit
    git -C $src submodule update --init --recursive
}
git -C $src diff --quiet -- cli-apps/demucs_mt.cpp
if ($LASTEXITCODE -eq 0) {  # not patched yet
    git -C $src apply (Join-Path $here 'demucs_mt-windows.patch')
}

# 2. Build the multi-threaded CLI with MSVC (see tool/demucs/CMakeLists.txt).
$vs = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$cmake = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
$out = Join-Path $work 'msvc-build'
$exe = Join-Path $out 'Release\demucs_mt.exe'
if (!(Test-Path $exe)) {
    & $cmake -S $here -B $out -G 'Visual Studio 17 2022' -A x64 "-DDEMUCS_SOURCE_DIR=$src"
    & $cmake --build $out --config Release --target demucs_mt --parallel 8
    if (!(Test-Path $exe)) { throw 'demucs build failed' }
}

# 3. Convert Meta's htdemucs weights (downloaded by Demucs from Meta).
$model = Join-Path $work 'models\ggml-model-htdemucs-4s-f16.bin'
if (!(Test-Path $model)) {
    $venv = Join-Path $work 'venv'
    if (!(Test-Path $venv)) { python -m venv $venv }
    $py = Join-Path $venv 'Scripts\python.exe'
    & $py -m pip install --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple -r (Join-Path $here 'requirements.txt')
    & $py -m pip install --no-deps -e (Join-Path $src 'vendor\demucs')
    & $py -I (Join-Path $here 'convert_from_model.py') (Join-Path $work 'models')
    if (!(Test-Path $model)) { throw 'model conversion failed' }
}

# 4. Install next to the app, with the OpenMP runtime and licenses.
$dest = Join-Path $root "build\windows\x64\runner\$Configuration\engines\demucs"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item $exe (Join-Path $dest 'demucs.exe') -Force
Copy-Item $model (Join-Path $dest 'htdemucs-4s-f16.bin') -Force
$omp = Get-ChildItem (Join-Path $vs 'VC\Redist\MSVC\*\x64\Microsoft.VC143.OpenMP\vcomp140.dll') |
    Sort-Object FullName | Select-Object -Last 1
Copy-Item $omp.FullName (Join-Path $dest 'vcomp140.dll') -Force
Copy-Item (Join-Path $src 'LICENSE') (Join-Path $dest 'DEMUCS-CPP-LICENSE.txt') -Force
Copy-Item (Join-Path $src 'vendor\demucs\LICENSE') (Join-Path $dest 'DEMUCS-LICENSE.txt') -Force
Copy-Item (Join-Path $src 'vendor\eigen\COPYING.MPL2') (Join-Path $dest 'EIGEN-LICENSE.txt') -Force
Copy-Item (Join-Path $src 'vendor\libnyquist\LICENSE') (Join-Path $dest 'LIBNYQUIST-LICENSE.txt') -Force
@"
Noor music separation engine
demucs.cpp $commit (MIT): https://github.com/sevagh/demucs.cpp
  built with MSVC from tool/demucs (patch: tool/demucs/demucs_mt-windows.patch)
Model: Demucs htdemucs (Meta, MIT), converted from the official weights
  with tool/demucs/convert_from_model.py
Eigen (MPL-2.0, unmodified headers), libnyquist (BSD-2-Clause),
vcomp140.dll (Microsoft Visual C++ OpenMP runtime, redistributable).
"@ | Set-Content (Join-Path $dest 'COMPONENTS.txt') -Encoding utf8
Write-Output "Installed music separation engine: $dest"
