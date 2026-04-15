# 文件

- [安裝說明](docs/INSTALLATION.md)
- [測試說明](docs/TESTING.md)

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

# Build portable packages / installer

```powershell
# Build portable client + host folders under dist/portable
.\scripts\build-installer.ps1 -PortableOnly

# Build the final Windows installer
# Preferred: Inno Setup if ISCC.exe is installed
.\scripts\build-installer.ps1

# Optional: force Qt Installer Framework if binarycreator.exe is installed
.\scripts\build-installer.ps1 -PreferIfw
```

Installer output:

```text
dist/PackingElf-Setup-1.0.0.exe
```

Recommended distribution:

- Upload the installer `.exe` to GitHub Releases
- Give office users the GitHub Releases download link
- They only need to download and run the installer, not Git or any dev tools
