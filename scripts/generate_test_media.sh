#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# generate_test_media.sh — Generate test videos for godot-video (GAV)
# ---------------------------------------------------------------------------
# Creates test videos for validating hardware acceleration on:
#   - macOS (VideoToolbox): H.264, HEVC, VP9, ProRes
#   - Linux (VAAPI): H.264, HEVC, VP9
#   - Android (MediaCodec): H.264, HEVC
#
# Coverage includes:
#   - Multiple codecs (H.264, HEVC, VP9, ProRes, AV1)
#   - Multiple containers (MP4, MKV, WebM, MOV)
#   - Multiple resolutions (480p, 720p, 1080p, 4K, 8K)
#   - Multiple pixel formats (YUV420, YUV422, 10-bit, 12-bit)
#   - Various framerates (24, 30, 60, 120fps)
#   - Audio formats (AAC, Opus, Vorbis)
#   - Edge cases (very short, long, odd dimensions)
#
# Usage:
#   ./scripts/generate_test_media.sh [--all|--quick|--clean]
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/demo/test_media"

MODE="${1:---all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Check FFmpeg
# ---------------------------------------------------------------------------
check_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${RED}❌ FFmpeg not found${NC}" >&2
        echo "   macOS:  brew install ffmpeg"
        echo "   Linux:  apt install ffmpeg"
        exit 1
    fi
    
    echo -e "${BLUE}Checking FFmpeg encoders...${NC}"
    local encoders
    encoders=$(ffmpeg -hide_banner -encoders 2>/dev/null)
    
    for enc in libx264 libx265 libvpx-vp9 libaom-av1; do
        if echo "$encoders" | grep -q " $enc "; then
            echo -e "  ${GREEN}✓${NC} $enc"
        else
            echo -e "  ${YELLOW}○${NC} $enc (not available)"
        fi
    done
}

# ---------------------------------------------------------------------------
# Font detection for overlay
# ---------------------------------------------------------------------------
detect_font() {
    local fonts=(
        "/System/Library/Fonts/Menlo.ttc"
        "/System/Library/Fonts/Supplemental/Courier New.ttf"
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
        "/usr/share/fonts/liberation-mono/LiberationMono-Regular.ttf"
    )
    for f in "${fonts[@]}"; do
        [[ -f "$f" ]] && { echo "$f"; return; }
    done
    echo ""
}

FONTFILE=$(detect_font)

# ---------------------------------------------------------------------------
# Check encoder availability
# ---------------------------------------------------------------------------
has_encoder() {
    # PIPESTATUS[1] checks grep's exit code to handle SIGPIPE from grep -q
    ffmpeg -hide_banner -encoders 2>/dev/null | grep -q " $1 " || [[ ${PIPESTATUS[1]} == 0 ]]
}

# ---------------------------------------------------------------------------
# Generate test video
# ---------------------------------------------------------------------------
generate_video() {
    local name="$1"
    local category="$2"
    local width="$3"
    local height="$4"
    local fps="$5"
    local duration="$6"
    local vcodec="$7"
    local acodec="${8:-aac}"
    local container="${9:-mp4}"
    local pix_fmt="${10:-yuv420p}"
    local extra_opts="${11:-}"
    
    # Skip if encoder unavailable
    if ! has_encoder "$vcodec"; then
        echo -e "  ${YELLOW}⊘${NC} Skipping $name ($vcodec unavailable)"
        return 0
    fi
    
    local outdir="$OUTPUT_DIR/$category"
    local outfile="$outdir/${name}.${container}"
    
    mkdir -p "$outdir"
    
    if [[ -f "$outfile" ]]; then
        echo -e "  ${GREEN}✓${NC} Exists: $name.$container"
        return 0
    fi
    
    echo -e "  ${BLUE}⋯${NC} Creating: $name.$container (${width}x${height}@${fps}fps, ${duration}s)"
    
    # Build filter with timecode overlay
    local filter="testsrc2=s=${width}x${height}:r=${fps}:d=${duration}"
    
    if [[ -n "$FONTFILE" ]]; then
        filter="$filter,drawtext=fontfile='${FONTFILE}':\
text='${name} %{pts\\:hms}':x=(w-text_w)/2:y=h-80:\
fontcolor=white:fontsize=${height}/15:box=1:boxcolor=black@0.7:boxborderw=8"
    fi
    
    # Frame counter
    filter="$filter,drawtext=text='Frame %{frame_num}':x=10:y=10:\
fontcolor=yellow:fontsize=${height}/25"
    
    # Build ffmpeg command
    local cmd=(ffmpeg -hide_banner -loglevel error -y)
    cmd+=(-f lavfi -i "$filter")
    
    # Audio
    if [[ "$acodec" != "none" ]]; then
        cmd+=(-f lavfi -i "sine=frequency=440:sample_rate=48000:duration=${duration}")
        case "$acodec" in
            aac)   cmd+=(-c:a aac -b:a 128k) ;;
            opus)  cmd+=(-c:a libopus -b:a 64k) ;;
            vorbis) cmd+=(-c:a libvorbis -q:a 4) ;;
        esac
    else
        cmd+=(-an)
    fi
    
    # Video codec
    cmd+=(-c:v "$vcodec" -pix_fmt "$pix_fmt")
    
    # Codec-specific settings
    case "$vcodec" in
        libx264)
            cmd+=(-preset medium -crf 23 -g 30)
            ;;
        libx265)
            cmd+=(-preset medium -crf 28 -g 30 -tag:v hvc1)
            ;;
        libvpx-vp9)
            cmd+=(-b:v 0 -crf 30 -deadline good -cpu-used 2)
            ;;
        libaom-av1)
            cmd+=(-b:v 0 -crf 32 -cpu-used 6)
            ;;
        prores_ks)
            cmd+=(-profile:v 3)  # ProRes 422 HQ
            ;;
    esac
    
    # Extra options
    if [[ -n "$extra_opts" ]]; then
        cmd+=($extra_opts)
    fi
    
    cmd+=("$outfile")
    
    if "${cmd[@]}" 2>&1 | grep -q "Error"; then
        echo -e "  ${RED}✗${NC} Failed: $name"
        return 1
    fi
    
    local size=$(du -h "$outfile" | cut -f1)
    echo -e "  ${GREEN}✓${NC} Created: $name.$container ($size)"
}

# ---------------------------------------------------------------------------
# Test categories
# ---------------------------------------------------------------------------

generate_codec_tests() {
    echo -e "\n${BLUE}=== Codec Tests (Hardware Acceleration) ===${NC}"
    
    # H.264 - Most widely supported
    generate_video "h264_baseline_720p" "codecs" 1280 720 30 5 libx264 aac mp4 yuv420p "-profile:v baseline"
    generate_video "h264_main_1080p" "codecs" 1920 1080 30 5 libx264 aac mp4 yuv420p "-profile:v main"
    generate_video "h264_high_1080p" "codecs" 1920 1080 30 5 libx264 aac mp4 yuv420p "-profile:v high"
    generate_video "h264_4k" "codecs" 3840 2160 30 5 libx264 aac mp4 yuv420p "-profile:v high"
    
    # HEVC/H.265 - Modern compression
    generate_video "hevc_main_1080p" "codecs" 1920 1080 30 5 libx265 aac mp4 yuv420p
    generate_video "hevc_main_4k" "codecs" 3840 2160 30 5 libx265 aac mp4 yuv420p
    generate_video "hevc_main10_1080p" "codecs" 1920 1080 30 5 libx265 aac mp4 yuv420p10le "-profile:v main10"
    generate_video "hevc_main10_4k" "codecs" 3840 2160 30 5 libx265 aac mp4 yuv420p10le "-profile:v main10"
    
    # VP9 - Open codec
    generate_video "vp9_720p" "codecs" 1280 720 30 5 libvpx-vp9 opus webm yuv420p
    generate_video "vp9_1080p" "codecs" 1920 1080 30 5 libvpx-vp9 opus webm yuv420p
    generate_video "vp9_10bit_1080p" "codecs" 1920 1080 30 5 libvpx-vp9 opus webm yuv420p10le
    
    # AV1 - Next-gen (slow to encode)
    generate_video "av1_720p" "codecs" 1280 720 30 3 libaom-av1 opus webm yuv420p
    
    # ProRes - Professional/macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        generate_video "prores_422hq_1080p" "codecs" 1920 1080 24 5 prores_ks aac mov yuv422p10le
    fi
}

generate_resolution_tests() {
    echo -e "\n${BLUE}=== Resolution Tests ===${NC}"
    
    generate_video "res_480p" "resolutions" 854 480 30 3 libx264 aac mp4
    generate_video "res_720p" "resolutions" 1280 720 30 3 libx264 aac mp4
    generate_video "res_1080p" "resolutions" 1920 1080 30 3 libx264 aac mp4
    generate_video "res_1440p" "resolutions" 2560 1440 30 3 libx264 aac mp4
    generate_video "res_4k" "resolutions" 3840 2160 30 3 libx264 aac mp4
    generate_video "res_8k" "resolutions" 7680 4320 30 2 libx265 aac mp4  # HEVC for 8K
    
    # Non-standard
    generate_video "res_vertical_720p" "resolutions" 720 1280 30 3 libx264 aac mp4
    generate_video "res_square_1080" "resolutions" 1080 1080 30 3 libx264 aac mp4
}

generate_framerate_tests() {
    echo -e "\n${BLUE}=== Framerate Tests ===${NC}"
    
    generate_video "fps_24" "framerates" 1280 720 24 5 libx264 aac mp4
    generate_video "fps_25" "framerates" 1280 720 25 5 libx264 aac mp4
    generate_video "fps_30" "framerates" 1280 720 30 5 libx264 aac mp4
    generate_video "fps_60" "framerates" 1920 1080 60 3 libx264 aac mp4
    generate_video "fps_120" "framerates" 1280 720 120 2 libx264 aac mp4
    
    # NTSC framerates
    generate_video "fps_23976" "framerates" 1280 720 "24000/1001" 5 libx264 aac mp4
    generate_video "fps_29970" "framerates" 1920 1080 "30000/1001" 5 libx264 aac mp4
}

generate_stress_tests() {
    echo -e "\n${BLUE}=== Stress Tests ===${NC}"
    
    # Duration tests
    generate_video "dur_1sec" "stress" 1280 720 30 1 libx264 aac mp4
    generate_video "dur_30sec" "stress" 1280 720 30 30 libx264 aac mp4
    generate_video "dur_2min" "stress" 1280 720 30 120 libx264 aac mp4
    
    # High bitrate/quality
    generate_video "quality_1080p_high" "stress" 1920 1080 60 10 libx264 aac mp4 yuv420p "-crf 18"
    generate_video "quality_4k_high" "stress" 3840 2160 30 5 libx265 aac mp4 yuv420p "-crf 20"
}

generate_quick_tests() {
    echo -e "\n${BLUE}=== Quick Test Set ===${NC}"
    
    generate_video "quick_h264_720p" "quick" 1280 720 30 3 libx264 aac mp4
    generate_video "quick_hevc_1080p" "quick" 1920 1080 30 3 libx265 aac mp4
    generate_video "quick_vp9_720p" "quick" 1280 720 30 3 libvpx-vp9 opus webm
}

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
clean_media() {
    if [[ -d "$OUTPUT_DIR" ]]; then
        echo -e "${YELLOW}Removing: $OUTPUT_DIR${NC}"
        rm -rf "$OUTPUT_DIR"
        echo -e "${GREEN}✓ Cleaned${NC}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Godot Video Test Media Generator        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    
    case "$MODE" in
        --clean)
            clean_media
            ;;
        --quick)
            check_ffmpeg
            echo -e "\nOutput: ${OUTPUT_DIR}"
            generate_quick_tests
            ;;
        --all)
            check_ffmpeg
            echo -e "\nOutput: ${OUTPUT_DIR}"
            generate_quick_tests
            generate_codec_tests
            generate_resolution_tests
            generate_framerate_tests
            generate_stress_tests
            ;;
        *)
            echo "Usage: $0 [--all|--quick|--clean]"
            exit 1
            ;;
    esac
    
    if [[ "$MODE" != "--clean" ]]; then
        echo -e "\n${GREEN}════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Done! Test media in: $OUTPUT_DIR${NC}"
        
        if [[ -d "$OUTPUT_DIR" ]]; then
            local count=$(find "$OUTPUT_DIR" -type f | wc -l | tr -d ' ')
            local size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
            echo -e "Files: $count, Size: $size"
        fi
    fi
}

main
