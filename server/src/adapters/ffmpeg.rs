//! ffmpeg-based transcoder: lossy Ogg/Opus and lossless FLAC.

use std::path::Path;
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail};

use crate::streaming::{Target, Transcoder};

pub struct FfmpegTranscoder {
    binary: String,
}

impl FfmpegTranscoder {
    pub fn new(binary: impl Into<String>) -> Self {
        Self { binary: binary.into() }
    }
}

impl Transcoder for FfmpegTranscoder {
    fn transcode(&self, input: &Path, output: &Path, target: Target) -> Result<()> {
        let codec: Vec<String> = match target {
            Target::Opus { bitrate_kbps } => {
                ["-c:a", "libopus", "-b:a", &format!("{bitrate_kbps}k"), "-f", "ogg"].map(String::from).to_vec()
            }
            // FLAC keeps sample rate and bit depth (24-bit sources stay 24-bit).
            Target::Flac => ["-c:a", "flac", "-f", "flac"].map(String::from).to_vec(),
        };
        let result = Command::new(&self.binary)
            .args(["-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i"])
            .arg(input)
            .args(["-map", "0:a:0", "-vn", "-sn", "-dn"])
            .args(&codec)
            .arg(output)
            .stdin(Stdio::null())
            .output()
            .with_context(|| format!("run {}", self.binary))?;
        if !result.status.success() {
            let stderr = String::from_utf8_lossy(&result.stderr);
            bail!("ffmpeg failed ({}): {}", result.status, stderr.trim());
        }
        Ok(())
    }
}
