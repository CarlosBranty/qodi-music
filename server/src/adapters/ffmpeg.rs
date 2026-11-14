//! ffmpeg-based opus transcoder.

use std::path::Path;
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail};

use crate::streaming::Transcoder;

pub struct FfmpegTranscoder {
    binary: String,
}

impl FfmpegTranscoder {
    pub fn new(binary: impl Into<String>) -> Self {
        Self { binary: binary.into() }
    }
}

impl Transcoder for FfmpegTranscoder {
    fn to_opus(&self, input: &Path, output: &Path, bitrate_kbps: u32) -> Result<()> {
        let result = Command::new(&self.binary)
            .args(["-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i"])
            .arg(input)
            .args(["-map", "0:a:0", "-vn", "-sn", "-dn", "-c:a", "libopus", "-b:a"])
            .arg(format!("{bitrate_kbps}k"))
            .args(["-f", "ogg"])
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
