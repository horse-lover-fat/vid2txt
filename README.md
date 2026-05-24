# vid2txt

Play a video file in the terminal as ASCII art. Each frame is decoded with FFmpeg, downscaled to fit your terminal (with character aspect correction), mapped to density characters, and refreshed at the video's native frame rate.

## Prerequisites

**FFmpeg** must be available on your `PATH`. If `ffprobe` is present, it is used for metadata; otherwise vid2txt falls back to FFmpeg for probing.

```bash
# macOS
brew install ffmpeg

# Debian/Ubuntu
sudo apt install ffmpeg

# Fedora
sudo dnf install ffmpeg
```

Alternatively, build with the `download_ffmpeg` feature to auto-download a platform FFmpeg binary on first run:

```bash
cargo build --release --features download_ffmpeg
```

## Install

From this directory:

```bash
cargo install --path .
```

Or build a release binary:

```bash
cargo build --release
# binary at target/release/vid2txt
```

## Usage

```bash
vid2txt <VIDEO> [OPTIONS]
```

### Options

| Flag | Description |
|------|-------------|
| `--color` | Enable truecolor ASCII (default: monochrome) |
| `--fps <N>` | Override playback frame rate |
| `--width <COLS>` | Force render width (default: terminal width) |
| `--height <ROWS>` | Force render height (default: terminal height) |
| `--charset <STR>` | Custom density charset, dark→light (default: ` .:-=+*#%@`) |
| `--loop` | Loop playback until Ctrl+C |
| `--no-margin` | Use full terminal height (no reserved row) |

### Examples

Monochrome playback at native FPS:

```bash
vid2txt sample.mp4
```

Truecolor output:

```bash
vid2txt --color sample.mp4
```

Custom frame rate and looping:

```bash
vid2txt --fps 15 --loop sample.mp4
```

Custom charset and fixed size:

```bash
vid2txt --charset "@%#*+=-:. " sample.mp4
vid2txt --width 120 --height 40 sample.mp4
```

## Terminal notes

- Works best in modern terminals with truecolor support (iTerm2, Kitty, WezTerm, Windows Terminal, recent GNOME Terminal).
- Output uses the **alternate screen** so scrollback is not polluted; press **Ctrl+C** to exit.
- Performance scales with terminal size — larger terminals decode and render more pixels per frame.
- Character cells are roughly **2× taller than wide**; vid2txt adjusts sizing so video aspect ratio looks correct in the terminal.

## Supported formats

Any format FFmpeg can decode (`.mp4`, `.mov`, `.webm`, `.mkv`, `.avi`, etc.).
