@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set VULKAN_SDK=C:\VulkanSDK\1.4.341.1
set PATH=%VULKAN_SDK%\Bin;C:\Users\Osman\AppData\Local\Microsoft\WinGet\Links;%PATH%
cd /d C:\Users\Osman\projeler\drivelink\packages\flutter_llama\llama.cpp\ggml\src\ggml-vulkan\vulkan-shaders
if exist build rmdir /s /q build
mkdir build
cd build
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN_COOPMAT_GLSLC_SUPPORT=ON -DGGML_VULKAN_COOPMAT2_GLSLC_SUPPORT=ON -DGGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT=ON -DGGML_VULKAN_BFLOAT16_GLSLC_SUPPORT=ON
cmake --build . --config Release
echo BUILD_RESULT=%ERRORLEVEL%
