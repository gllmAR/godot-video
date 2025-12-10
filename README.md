# Godot Video (GAV) - Hardware-Accelerated Video Playback

A GDExtension for Godot 4.4+ providing hardware-accelerated video decoding using FFmpeg.

## Platform Support

| Platform | API | Codecs | Status |
|----------|-----|--------|--------|
| Linux | VAAPI | H.264, HEVC, VP9 | ✅ Stable |
| Android | MediaCodec | H.264, HEVC | ✅ Stable |
| macOS | VideoToolbox | H.264, HEVC, VP9, ProRes | ✅ **NEW** |

## Quick Start - Testing

See [TESTING_QUICKSTART.md](TESTING_QUICKSTART.md) for a guide to testing hardware acceleration.

```bash
# Generate test videos
./scripts/generate_test_media.sh --quick

# Open Godot, run test_chamber.tscn (F5)
```

## Build Instructions

### macOS (VideoToolbox)

Requirements:
- Xcode Command Line Tools
- Homebrew
- FFmpeg 8.0+ with VideoToolbox support

```bash
# Install FFmpeg
brew install ffmpeg

# Build
mkdir build-macos
cd build-macos
cmake ..
cmake --build . --target gav

# Library output: demo/addons/gav/macos/libgav.macos.template_debug.arm64.dylib
```

### Linux (VAAPI)

#### build with system ffmpeg

dependency on ubuntu

```
sudo apt install libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev ffmpeg \
libva-dev libxcb-dri3-dev libvdpau-dev libdrm-dev libx11-xcb-dev libvpx-dev libdav1d-dev libopus-dev liblzma-dev libmp3lame-dev libglx-dev libx265-dev libx264-dev \
libaom-dev libbz2-dev libnuma-dev libfdk-aac-dev libvorbis-dev libbz2-dev libglx-dev libgl1-mesa-dev
```

### Build with system ffmpeg

```
mkdir build-system
cd build-system
cmake -DUSE_SYSTEM_FFMPEG=ON ..
cmake --build . --target godot-video
```

### Build with integrated ffmpeg

```
mkdir build-integrated
cd build-integrated
cmake ..
cmake --build . --target libx264 libx265 zlib xz bzip2 ffnvenc
cmake --build . --target ffmpeg
cmake --build . --target gav
```

### Build for godot with vulkan video extensions enabled
**currently not working and only in the archive**
```
mkdir build-vkvideo
cd build-vkvideo
cmake -DUSE_GODOT_PATCHED=ON ..
cmake --build . --target libx264 libx265 zlib xz bzip2 ffnvenc
cmake --build . --target ffmpeg
cmake --build . --target gav
```

On intel vulkan video api is behind a flag. Launch with

```
ANV_VIDEO_DECODE=1 ./godot.linuxbsd.editor.x86_64 --main-pack something.pck
```

### Build for android
** needs prebuilt static androif ffmpeg libs in android ffmpeg (eg see https://github.com/Javernaut/ffmpeg-android-maker) **
```
# mkdir build-android
# cmake -DBUILD_ANDROID=ON ..
# cmake --build . --target godot-video-android
cd android
gradle assemble
```

## Notes

library is linked against vaapi 2.2, older ubuntu version need the intel ppa
```sudo add-apt-repository -y ppa:kobuk-team/intel-graphics```


## SDL TODO

