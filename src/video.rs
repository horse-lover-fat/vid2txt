use anyhow::{bail, Context, Result};
use ffmpeg_sidecar::child::FfmpegChild;
use ffmpeg_sidecar::command::FfmpegCommand;
use ffmpeg_sidecar::event::{FfmpegEvent, OutputVideoFrame};
use ffmpeg_sidecar::ffprobe::ffprobe_path;
use ffmpeg_sidecar::iter::FfmpegIterator;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct VideoInfo {
    pub width: u32,
    pub height: u32,
    pub fps: f64,
}

pub struct VideoDecoder {
    path: PathBuf,
    cols: u32,
    rows: u32,
    child: Option<FfmpegChild>,
    iter: Option<FfmpegIterator>,
}

impl VideoDecoder {
    pub fn probe(path: &Path) -> Result<VideoInfo> {
        if ffprobe_path().exists() {
            probe_with_ffprobe(path)
        } else {
            probe_with_ffmpeg(path)
        }
    }

    pub fn open(path: PathBuf, cols: u32, rows: u32) -> Result<Self> {
        let mut decoder = Self {
            path,
            cols,
            rows,
            child: None,
            iter: None,
        };
        decoder.spawn()?;
        Ok(decoder)
    }

    pub fn spawn(&mut self) -> Result<()> {
        if let Some(mut child) = self.child.take() {
            self.iter = None;
            let _ = child.wait();
        }

        let filter = format!("scale={}:{}", self.cols, self.rows);
        let mut child = FfmpegCommand::new()
            .hide_banner()
            .input(self.path.to_string_lossy().as_ref())
            .filter(filter)
            .rawvideo()
            .spawn()
            .with_context(|| format!("failed to spawn ffmpeg for {}", self.path.display()))?;

        let iter = child.iter().context("failed to read ffmpeg output")?;
        self.child = Some(child);
        self.iter = Some(iter);
        Ok(())
    }

    pub fn next_frame(&mut self) -> Result<Option<OutputVideoFrame>> {
        let iter = self.iter.as_mut().context("video decoder is not open")?;

        for event in iter.by_ref() {
            if let FfmpegEvent::OutputFrame(frame) = event {
                return Ok(Some(frame));
            }
        }

        Ok(None)
    }
}

fn probe_with_ffprobe(path: &Path) -> Result<VideoInfo> {
    let output = Command::new(ffprobe_path())
        .args([
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,r_frame_rate",
            "-of",
            "csv=p=0:s=x",
        ])
        .arg(path)
        .output()
        .context("failed to run ffprobe")?;

    if !output.status.success() {
        bail!(
            "ffprobe failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let line = String::from_utf8_lossy(&output.stdout);
    let line = line.trim();
    let mut parts = line.split('x');
    let width: u32 = parts
        .next()
        .context("missing video width from ffprobe")?
        .parse()
        .context("invalid video width from ffprobe")?;
    let rest = parts
        .next()
        .context("missing video height/fps from ffprobe")?;
    let mut rest_parts = rest.split('x');
    let height: u32 = rest_parts
        .next()
        .context("missing video height from ffprobe")?
        .parse()
        .context("invalid video height from ffprobe")?;
    let fps_str = rest_parts.next().unwrap_or("24/1");
    let fps = parse_frame_rate(fps_str).unwrap_or(24.0);

    Ok(VideoInfo {
        width,
        height,
        fps,
    })
}

fn probe_with_ffmpeg(path: &Path) -> Result<VideoInfo> {
    let mut child = FfmpegCommand::new()
        .hide_banner()
        .input(path.to_string_lossy().as_ref())
        .format("null")
        .output("-")
        .spawn()
        .context("failed to spawn ffmpeg for probe")?;

    let metadata = child
        .iter()
        .context("failed to read ffmpeg probe output")?
        .collect_metadata()
        .context("failed to collect video metadata")?;

    let _ = child.wait();

    let stream = metadata
        .input_streams
        .iter()
        .find(|stream| stream.is_video())
        .context("no video stream found")?;
    let video = stream
        .video_data()
        .context("invalid video stream metadata")?;

    let fps = if video.fps > 0.0 {
        video.fps as f64
    } else {
        24.0
    };

    Ok(VideoInfo {
        width: video.width,
        height: video.height,
        fps,
    })
}

fn parse_frame_rate(rate: &str) -> Option<f64> {
    let rate = rate.trim();
    if let Some((num, den)) = rate.split_once('/') {
        let num: f64 = num.parse().ok()?;
        let den: f64 = den.parse().ok()?;
        if den == 0.0 {
            return None;
        }
        Some(num / den)
    } else {
        rate.parse().ok()
    }
}
