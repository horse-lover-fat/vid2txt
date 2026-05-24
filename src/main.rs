mod ascii;
mod cli;
mod terminal;
mod video;

use anyhow::{bail, Context, Result};
use ascii::AsciiConfig;
use cli::Cli;
use clap::Parser;
use std::path::Path;
use terminal::TerminalGuard;
use video::VideoDecoder;

fn main() -> Result<()> {
    let cli = Cli::parse();

    if !Path::new(&cli.video).is_file() {
        bail!("video file not found: {}", cli.video.display());
    }

    #[cfg(feature = "download_ffmpeg")]
    ffmpeg_sidecar::download::auto_download()?;

    if cli.charset.is_empty() {
        bail!("charset must not be empty");
    }

    let info = VideoDecoder::probe(&cli.video)
        .with_context(|| format!("failed to probe {}", cli.video.display()))?;

    let fps = cli.fps.unwrap_or(info.fps);
    if fps <= 0.0 {
        bail!("fps must be positive");
    }

    let guard = TerminalGuard::new()?;
    let (cols, rows) = guard.render_size(&cli, info.width, info.height)?;

    let mut decoder = VideoDecoder::open(cli.video.clone(), cols, rows)?;
    let ascii_config = AsciiConfig {
        charset: &cli.charset,
        color: cli.color,
    };

    terminal::play(&mut decoder, fps, &ascii_config, cli.r#loop)?;

    Ok(())
}
