# Quick Start: Testing macOS VideoToolbox Support

## Generate Test Videos

```bash
# Quick test set (3 videos, ~5MB, 30 seconds)
./scripts/generate_test_media.sh --quick

# Full test suite (comprehensive, ~2-5GB, 5-10 minutes)
./scripts/generate_test_media.sh --all
```

## Run Test Chamber

1. **Open Godot Editor**
   ```bash
   # If you have Godot in Applications
   open -a Godot demo/project.godot
   ```

2. **Run Test Scene**
   - Open `test_chamber.tscn`
   - Press F5 or click Play Scene (▶)

3. **Test Playback**
   - The test chamber should show "✓ GAV Plugin Loaded" (green)
   - Double-click `quick_h264_720p.mp4` in the file tree
   - Video should play smoothly

## Verify Hardware Acceleration

### Method 1: Activity Monitor
1. Open Activity Monitor (Cmd+Space → "Activity Monitor")
2. Go to Window → GPU History
3. Play a video in test chamber
4. Look for `VTDecoderXPCService` process or GPU activity spike

### Method 2: Terminal
```bash
# Watch for VideoToolbox decoder process
watch -n 1 'ps aux | grep VTDecoderXPCService'
```

### Method 3: Check Logs
The GAV plugin logs hardware acceleration attempts. Check Godot console output:
- `[GAV] Using VideoToolbox decoder` = Success ✅
- `[GAV] VideoToolbox not available, using software` = Fallback ⚠️

## Quick Test Checklist

### ✅ Test 1: Software Decoding (Baseline)
1. Uncheck "HW Accel" in test chamber
2. Play `quick_h264_720p.mp4`
3. Expected: Video plays, CPU usage ~20-30%

### ✅ Test 2: H.264 Hardware Decoding
1. Check "HW Accel"
2. Play `quick_h264_720p.mp4`
3. Expected: Video plays, CPU usage <10%, `VTDecoderXPCService` visible

### ✅ Test 3: HEVC Hardware Decoding
1. Keep "HW Accel" checked
2. Play `quick_hevc_1080p.mp4`
3. Expected: Video plays smoothly, CPU usage ~10-15%

### ✅ Test 4: VP9 Testing
1. Play `quick_vp9_720p.webm`
2. Expected: Plays (HW support varies by Mac model)

## Troubleshooting

### Test Chamber shows "✗ GAV Plugin Not Found"
```bash
# Verify library exists
ls -lh demo/addons/gav/macos/

# Expected output:
# libgav.macos.template_debug.arm64.dylib
```

If missing, rebuild:
```bash
cd build-macos
cmake --build . --target gav
```

### No videos in file tree
```bash
# Verify test media exists
ls test_media/quick/

# Expected: .mp4 and .webm files
```

If missing, regenerate:
```bash
./scripts/generate_test_media.sh --quick
```

### Videos won't play
1. Check Godot imported the files (wait for import to finish)
2. Restart Godot Editor
3. Check Output panel for errors

### High CPU usage with HW Accel enabled
- VideoToolbox may have fallen back to software
- Check codec support: Not all Macs support all codecs
- Intel Macs: Limited VP9/HEVC support
- Apple Silicon: Full support for H.264/HEVC/VP9/ProRes

## Next Steps

### Generate Full Test Suite
```bash
./scripts/generate_test_media.sh --all
```

This creates:
- **Codec tests**: H.264 (baseline/main/high), HEVC (8-bit/10-bit), VP9, ProRes
- **Resolution tests**: 480p → 8K
- **Framerate tests**: 24fps → 120fps
- **Stress tests**: Long duration, high quality

### Test Existing Videos
The test chamber also scans the `demo/` directory for existing `.mp4`, `.mov`, `.webm` files.

Copy your own test videos to:
```bash
cp ~/Videos/test.mp4 demo/
```

Restart test chamber to see them in the "demo" category.

## Performance Reference

### Expected CPU Usage (Apple Silicon M1/M2/M3)

| Resolution | Software | Hardware |
|------------|----------|----------|
| 720p H.264 | 25-35%   | 5-10%    |
| 1080p H.264| 45-60%   | 8-15%    |
| 4K H.264   | 100%+    | 15-25%   |
| 4K HEVC    | 100%+    | 12-20%   |

### Expected CPU Usage (Intel Mac)

| Resolution | Software | Hardware |
|------------|----------|----------|
| 720p H.264 | 40-50%   | 10-15%   |
| 1080p H.264| 70-90%   | 15-25%   |
| 4K H.264   | 100%+    | 30-50%   |

## Success Criteria

✅ **macOS support is working if:**
1. Test chamber loads and shows "✓ GAV Plugin Loaded"
2. All 3 quick test videos play smoothly
3. CPU usage drops significantly with HW Accel enabled
4. `VTDecoderXPCService` appears in Activity Monitor during playback
5. Seeking works (dragging progress slider)
6. Audio plays (440Hz tone)

## Documentation

- Full test documentation: `TEST_CHAMBER.md`
- Build instructions: `README.md`
- Implementation details: Check commit history

## Reporting Issues

If tests fail:

1. **Capture System Info**
   ```bash
   system_profiler SPHardwareDataType SPDisplaysDataType > system_info.txt
   ffmpeg -version > ffmpeg_info.txt
   ```

2. **Capture Test Output**
   - Screenshot of test chamber showing error
   - Godot Output panel contents
   - Activity Monitor screenshot during playback

3. **Create Issue** with:
   - Mac model and macOS version
   - Test video that failed
   - System info files
   - Screenshots/logs
