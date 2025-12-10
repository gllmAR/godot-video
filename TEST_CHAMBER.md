# GAV Test Chamber

A comprehensive testing environment for the Godot Audio Video (GAV) addon, specifically designed to validate hardware-accelerated video decoding across different platforms.

## Features

- **File Browser**: Browse and select test videos from organized categories
- **Video Playback**: Full playback controls (play, pause, stop, seek)
- **Hardware Acceleration Testing**: Toggle and monitor HW acceleration status
- **Format Coverage**: Test H.264, HEVC, VP9, AV1, ProRes across various resolutions and framerates
- **Real-time Info**: Display codec, resolution, framerate, and playback info

## Quick Start

### 1. Generate Test Media

```bash
# Quick test set (minimal, ~100MB)
./scripts/generate_test_media.sh --quick

# Full test suite (comprehensive, ~2-5GB)
./scripts/generate_test_media.sh --all

# Clean up test media
./scripts/generate_test_media.sh --clean
```

### 2. Open Test Chamber

In Godot Editor:
1. Open the demo project
2. Run `test_chamber.tscn` (F5 or click Play)
3. Browse test videos in the left panel
4. Double-click any video to play

## Test Categories

### Quick Tests
- **quick_h264_720p** - H.264 baseline test
- **quick_hevc_1080p** - HEVC compression test
- **quick_vp9_720p** - VP9 open codec test

### Codec Tests (Hardware Acceleration)
Tests hardware decoder support:

**H.264 (AVC)**
- `h264_baseline_720p` - Baseline profile (most compatible)
- `h264_main_1080p` - Main profile
- `h264_high_1080p` - High profile
- `h264_4k` - 4K stress test

**HEVC (H.265)**
- `hevc_main_1080p` - 8-bit 1080p
- `hevc_main_4k` - 8-bit 4K
- `hevc_main10_1080p` - 10-bit 1080p
- `hevc_main10_4k` - 10-bit 4K (stress test)

**VP9**
- `vp9_720p` - 8-bit standard
- `vp9_1080p` - 8-bit HD
- `vp9_10bit_1080p` - 10-bit HDR-ready

**ProRes** (macOS only)
- `prores_422hq_1080p` - Professional codec

### Resolution Tests
- 480p, 720p, 1080p, 1440p, 4K, 8K
- Vertical (portrait) and square aspect ratios

### Framerate Tests
- 24, 25, 30, 60, 120 fps
- NTSC framerates (23.976, 29.970)

### Stress Tests
- Duration: 1 sec, 30 sec, 2 min
- High quality/bitrate variants

## Hardware Acceleration Support

### macOS (VideoToolbox)
✅ **Supported**: H.264, HEVC (8-bit/10-bit), VP9, ProRes
- Test with: All codec tests
- Expected: GPU usage visible in Activity Monitor

### Linux (VAAPI)
✅ **Supported**: H.264, HEVC, VP9
- Test with: codec tests (skip ProRes)
- Expected: `/dev/dri/renderD128` in use

### Android (MediaCodec)
✅ **Supported**: H.264, HEVC
- Test with: H.264 and HEVC tests
- Expected: Smooth playback on device

## Interpreting Results

### Success Indicators
- ✅ Video plays smoothly without stuttering
- ✅ Seeking works (progress slider)
- ✅ Audio sync maintained (440Hz tone)
- ✅ Low CPU usage (check Activity Monitor/top)
- ✅ GPU process active (VideoToolbox/VAAPI)

### Failure Indicators
- ❌ Black screen or corrupted video
- ❌ Stuttering/dropped frames
- ❌ Seeking fails or crashes
- ❌ High CPU usage (>50% on modern hardware)
- ❌ No GPU decode process visible

### Common Issues

**Black screen on macOS with HEVC 10-bit**
- Verify VideoToolbox supports 10-bit: Check "About This Mac" → GPU
- Apple Silicon always supports 10-bit
- Intel Macs: Only newer models (2018+)

**Software fallback on Linux**
- Check VAAPI drivers: `vainfo`
- Ensure FFmpeg built with `--enable-vaapi`

**Android crashes with 4K**
- Device may lack 4K decoder support
- Try 1080p tests first

## Test Workflow

### Phase 1: Software Decoding Baseline
1. Disable hardware acceleration (uncheck "HW Accel")
2. Play `quick_h264_720p`
3. Verify basic functionality works

### Phase 2: H.264 Hardware Acceleration
1. Enable hardware acceleration
2. Test all H.264 variants (baseline → main → high → 4K)
3. Monitor GPU usage

### Phase 3: HEVC Testing
1. Test `hevc_main_1080p` (8-bit)
2. Test `hevc_main10_1080p` (10-bit)
3. Test 4K variants if hardware capable

### Phase 4: Stress Testing
1. Test high framerates (60fps, 120fps)
2. Test long durations (2min, 5min)
3. Test 4K/8K if capable

## Monitoring Tools

### macOS
```bash
# Watch GPU processes
watch -n 1 'ps aux | grep VTDecoderXPCService'

# Activity Monitor
# Window → GPU History
```

### Linux
```bash
# Check VAAPI support
vainfo

# Monitor GPU
intel_gpu_top    # Intel
radeontop        # AMD

# Watch decoder
watch -n 1 'lsof /dev/dri/renderD128'
```

### Android
```bash
# ADB logcat filter
adb logcat | grep MediaCodec
```

## File Structure

```
test_media/
├── quick/           # Quick validation set
├── codecs/          # Codec-specific tests
├── resolutions/     # Resolution scaling tests
├── framerates/      # Framerate tests
└── stress/          # Duration and quality tests
```

## Script Options

```bash
# Generate specific test set
./scripts/generate_test_media.sh --quick     # Fast, minimal
./scripts/generate_test_media.sh --all       # Complete suite

# Clean up
./scripts/generate_test_media.sh --clean
```

## Extending Tests

To add custom tests, edit `generate_test_media.sh`:

```bash
# Add to codec_tests()
generate_video "my_test" "codecs" 1920 1080 30 5 libx264 aac mp4
#              name      category  w    h    fps dur codec audio container
```

## Performance Expectations

### Software Decoding (CPU)
- 720p H.264: ~20-30% CPU
- 1080p H.264: ~40-60% CPU
- 4K H.264: 100%+ CPU (may drop frames)

### Hardware Decoding (GPU)
- 720p H.264: ~5-10% CPU
- 1080p H.264: ~8-15% CPU
- 4K H.264: ~10-20% CPU
- 8K HEVC: ~15-30% CPU

## Troubleshooting

### No test_media folder after generation
- Check script errors: `./scripts/generate_test_media.sh --quick 2>&1 | tee log.txt`
- Verify FFmpeg installed: `which ffmpeg`

### Test Chamber doesn't show files
- Ensure Godot imported the files (check `.godot/imported/`)
- Restart Godot Editor to refresh filesystem

### Videos won't play
- Check GAV plugin loaded: Status label should show "✓ GAV Plugin Loaded"
- Verify library exists: `ls demo/addons/gav/macos/libgav*.dylib`

## Contributing Test Cases

Found a codec/format that breaks? Add a test case:

1. Isolate the failing parameters (codec, resolution, framerate, pixel format)
2. Add test to `generate_test_media.sh`
3. Document expected behavior
4. Submit PR with test case

## License

Same as parent project (see LICENSE.md)
