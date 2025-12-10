# Test Chamber Controls Guide

## Playback State Management

The test chamber now uses a proper state machine with three states:
- **STOPPED**: No video loaded or playback has been stopped
- **PLAYING**: Video is actively playing
- **PAUSED**: Video is paused (can be resumed)

## Button Behavior

### Play Button
- **When STOPPED**: Starts playback (visible when stopped)
- **When PLAYING**: Disabled and hidden (Pause/Resume button is shown)
- **When PAUSED**: Hidden (Resume button takes its place)
- **After Stop**: Available to replay the video without reloading

### Pause/Resume Button
- **When PLAYING**: Shows "⏸ Pause" - pauses the video
- **When PAUSED**: Shows "▶ Resume" - resumes playback from current position
- **When STOPPED**: Hidden (Play button is shown)
- **Smart Behavior**: Single button that toggles between pause and resume

### Stop Button
- **When PLAYING/PAUSED**: Stops playback and resets to beginning
- **When STOPPED**: Disabled
- **Note**: Keeps video loaded so you can replay with Play button

### Progress Slider
- **When STOPPED**: Disabled
- **When PLAYING/PAUSED**: Enabled for seeking
- Updates in real-time during playback
- Dragging pauses auto-update while seeking

### Loop Toggle
- Can be toggled at any time
- Dynamically updates the stream's loop property during playback
- When enabled, video seamlessly loops at the end
- When disabled, video stops at the end

## Keyboard Shortcuts

- **Space**: Toggle Play/Pause
- **Esc**: Stop playback
- **← Left Arrow**: Seek backward 5 seconds
- **→ Right Arrow**: Seek forward 5 seconds
- **Shift+L**: Toggle loop mode

## Features

### Seamless Loop Support
- Loop state is checked dynamically during playback
- Changing loop during playback takes effect immediately
- No reload required when toggling loop

### Proper Pause/Resume
- Pausing preserves the exact playback position
- Resume continues from where it was paused
- Audio sync is maintained after resume

### Seeking
- Drag the progress slider to seek
- Use arrow keys for quick 5-second jumps
- Seeking works in both playing and paused states
- Time display updates while seeking

### State Synchronization
- Button states always reflect current playback state
- UI updates immediately when state changes
- No stale button states or incorrect enabled/disabled logic

## Implementation Details

### State Transitions
```
STOPPED → PLAYING:  Press Play or double-click video file
PLAYING → PAUSED:   Press Pause/Resume button or Space
PAUSED → PLAYING:   Press Resume button (same as Pause button) or Space
PLAYING → STOPPED:  Press Stop, Esc, or video finishes (when loop disabled)
PAUSED → STOPPED:   Press Stop or Esc
STOPPED → PLAYING:  Press Play to replay loaded video
```

### Resource Management
- Stopping keeps the video stream loaded for quick replay
- Press Play after Stop to replay without reloading
- Progress slider resets to 0 when stopped
- Time display shows "0:00 / 0:00" when stopped

### Error Handling
- Failed video loads set state to STOPPED
- Missing files show error message
- Invalid operations are prevented by button states
