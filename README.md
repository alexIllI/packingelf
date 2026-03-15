# List available presets

```bash
cd desktop-app
cmake --list-presets
```

# Configure and build (Debug)

```bash
cd desktop-app
cmake --preset msvc-debug
cmake --build --preset msvc-debug
```

# Configure and build (Release)

```bash
cd desktop-app
cmake --preset msvc-release
cmake --build --preset msvc-release
```

# Run the executable

```bash
# After debug build
.\build\msvc-debug\Debug\packingelf.exe

# After release build
.\build\msvc-release\packingelf.exe
```

# Override C++ standard (optional)

## If you want to test with C++17 instead of C++20:

```bash
cmake --preset msvc-debug -DPACKINGELF_CXX_STANDARD=17
cmake --build --preset msvc-debug
```
