use crate::ascii::{frame_to_ascii, AsciiConfig};
use crate::cli::Cli;
use crate::video::VideoDecoder;
use anyhow::{Context, Result};
use crossterm::cursor::{Hide, MoveTo, Show};
use crossterm::execute;
use crossterm::terminal::{self, EnterAlternateScreen, LeaveAlternateScreen};
use std::io::{stdout, Write};
use std::time::{Duration, Instant};

/// Terminal character cells are roughly twice as tall as they are wide.
const CHAR_ASPECT: f64 = 2.0;

pub struct TerminalGuard {
    active: bool,
}

impl TerminalGuard {
    pub fn new() -> Result<Self> {
        execute!(stdout(), EnterAlternateScreen, Hide)?;
        Ok(Self { active: true })
    }

    pub fn render_size(&self, cli: &Cli, video_width: u32, video_height: u32) -> Result<(u32, u32)> {
        let (term_cols, term_rows) = terminal::size().context("failed to query terminal size")?;
        Ok(compute_render_size(
            term_cols,
            term_rows,
            video_width,
            video_height,
            cli.width,
            cli.height,
            cli.no_margin,
        ))
    }
}

impl Drop for TerminalGuard {
    fn drop(&mut self) {
        if self.active {
            let _ = execute!(stdout(), Show, LeaveAlternateScreen);
        }
    }
}

pub fn compute_render_size(
    term_cols: u16,
    term_rows: u16,
    video_width: u32,
    video_height: u32,
    width_override: Option<u16>,
    height_override: Option<u16>,
    no_margin: bool,
) -> (u32, u32) {
    let max_cols = width_override
        .unwrap_or_else(|| term_cols.saturating_sub(1))
        .max(1) as u32;
    let max_rows = height_override
        .unwrap_or_else(|| {
            if no_margin {
                term_rows
            } else {
                term_rows.saturating_sub(1)
            }
        })
        .max(1) as u32;

    if width_override.is_some() && height_override.is_some() {
        return (max_cols, max_rows);
    }

    let video_aspect = video_width as f64 / video_height.max(1) as f64;
    let term_aspect = max_cols as f64 / (max_rows as f64 * CHAR_ASPECT);

    let (cols, rows) = if video_aspect > term_aspect {
        let cols = max_cols;
        let rows = ((cols as f64 / video_aspect) / CHAR_ASPECT)
            .round()
            .max(1.0) as u32;
        (cols, rows)
    } else {
        let rows = max_rows;
        let cols = (rows as f64 * CHAR_ASPECT * video_aspect)
            .round()
            .max(1.0) as u32;
        (cols.min(max_cols), rows)
    };

    match (width_override, height_override) {
        (Some(_), None) => (max_cols, rows),
        (None, Some(_)) => (cols, max_rows),
        _ => (cols, rows),
    }
}

pub fn play(
    decoder: &mut VideoDecoder,
    fps: f64,
    ascii_config: &AsciiConfig<'_>,
    loop_playback: bool,
) -> Result<()> {
    let frame_duration = Duration::from_secs_f64(1.0 / fps.max(0.001));
    let mut next_deadline = Instant::now();

    loop {
        while let Some(frame) = decoder.next_frame()? {
            let ascii = frame_to_ascii(&frame, ascii_config);
            execute!(stdout(), MoveTo(0, 0))?;
            print!("{ascii}");
            stdout().flush()?;

            next_deadline += frame_duration;
            let now = Instant::now();
            if now < next_deadline {
                std::thread::sleep(next_deadline - now);
            } else {
                next_deadline = now;
            }
        }

        if !loop_playback {
            break;
        }

        decoder.spawn()?;
        next_deadline = Instant::now();
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::compute_render_size;

    #[test]
    fn respects_explicit_width_and_height() {
        assert_eq!(compute_render_size(120, 40, 1920, 1080, Some(80), Some(20), false), (80, 20));
    }

    #[test]
    fn letterboxes_wide_video() {
        let (cols, rows) = compute_render_size(100, 50, 1920, 1080, None, None, false);
        assert_eq!(cols, 99);
        assert!(rows < 49);
        assert!(rows > 0);
    }

    #[test]
    fn letterboxes_tall_video() {
        let (cols, rows) = compute_render_size(100, 50, 1080, 1920, None, None, false);
        assert!(cols < 99);
        assert_eq!(rows, 49);
    }

    #[test]
    fn no_margin_allows_extra_row_for_tall_video() {
        let (_, rows_with_margin) = compute_render_size(100, 50, 1080, 1920, None, None, false);
        let (_, rows_no_margin) = compute_render_size(100, 50, 1080, 1920, None, None, true);
        assert_eq!(rows_with_margin, 49);
        assert_eq!(rows_no_margin, 50);
    }
}
