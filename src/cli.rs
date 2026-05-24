use clap::Parser;
use std::path::PathBuf;

pub const DEFAULT_CHARSET: &str = " .:-=+*#%@";

#[derive(Debug, Parser)]
#[command(
    name = "vid2txt",
    about = "Play a video as ASCII art in the terminal",
    version
)]
pub struct Cli {
    /// Path to the video file
    pub video: PathBuf,

    /// Enable truecolor ASCII (default: monochrome)
    #[arg(long)]
    pub color: bool,

    /// Override playback frame rate
    #[arg(long)]
    pub fps: Option<f64>,

    /// Force render width in columns (default: terminal width)
    #[arg(long)]
    pub width: Option<u16>,

    /// Force render height in rows (default: terminal height)
    #[arg(long)]
    pub height: Option<u16>,

    /// Custom density charset, dark to light
    #[arg(long, default_value = DEFAULT_CHARSET)]
    pub charset: String,

    /// Loop playback until Ctrl+C
    #[arg(long)]
    pub r#loop: bool,

    /// Use full terminal height (no reserved row)
    #[arg(long)]
    pub no_margin: bool,
}
