use ffmpeg_sidecar::event::OutputVideoFrame;

pub struct AsciiConfig<'a> {
    pub charset: &'a str,
    pub color: bool,
}

pub fn frame_to_ascii(frame: &OutputVideoFrame, config: &AsciiConfig<'_>) -> String {
    let cols = frame.width as usize;
    let rows = frame.height as usize;
    let data = &frame.data;

    let per_char = if config.color { 20 } else { 1 };
    let mut out = String::with_capacity(cols * rows * per_char + rows);

    let charset: Vec<char> = config.charset.chars().collect();
    let max_idx = charset.len().saturating_sub(1);

    for y in 0..rows {
        for x in 0..cols {
            let i = (y * cols + x) * 3;
            if i + 2 >= data.len() {
                out.push(' ');
                continue;
            }

            let r = data[i];
            let g = data[i + 1];
            let b = data[i + 2];
            let l = luminance(r, g, b);
            let idx = ((l / 255.0) * max_idx as f32).round() as usize;
            let ch = charset[idx.min(max_idx)];

            if config.color {
                use std::fmt::Write as _;
                let _ = write!(out, "\x1b[38;2;{r};{g};{b}m{ch}\x1b[0m");
            } else {
                out.push(ch);
            }
        }
        if y + 1 < rows {
            out.push('\n');
        }
    }

    out
}

#[inline]
fn luminance(r: u8, g: u8, b: u8) -> f32 {
    0.299 * r as f32 + 0.587 * g as f32 + 0.114 * b as f32
}
