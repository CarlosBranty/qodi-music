//! symphonia-based waveform analyzer.

use std::fs::File;
use std::path::Path;

use anyhow::{Context, Result, anyhow};
use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::errors::Error;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;

use crate::streaming::WaveformAnalyzer;

pub struct SymphoniaWaveform;

impl WaveformAnalyzer for SymphoniaWaveform {
    /// Decodes the whole file and returns the peak absolute amplitude of each packet.
    fn raw_peaks(&self, path: &Path) -> Result<Vec<f32>> {
        let file = File::open(path).with_context(|| format!("open {}", path.display()))?;
        let stream = MediaSourceStream::new(Box::new(file), Default::default());
        let mut hint = Hint::new();
        if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            hint.with_extension(ext);
        }
        let mut format = symphonia::default::get_probe()
            .probe(&hint, stream, FormatOptions::default(), MetadataOptions::default())
            .context("probe audio")?;
        let track = format.default_track(TrackType::Audio).ok_or_else(|| anyhow!("no audio track"))?;
        let track_id = track.id;
        let params = track
            .codec_params
            .as_ref()
            .and_then(|p| p.audio())
            .ok_or_else(|| anyhow!("no audio codec parameters"))?;
        let mut decoder = symphonia::default::get_codecs()
            .make_audio_decoder(params, &AudioDecoderOptions::default())
            .context("create decoder")?;

        let mut peaks = Vec::new();
        let mut samples: Vec<f32> = Vec::new();
        loop {
            let packet = match format.next_packet() {
                Ok(Some(packet)) => packet,
                Ok(None) | Err(Error::ResetRequired) => break,
                Err(err) if peaks.is_empty() => return Err(err).context("read packet"),
                Err(_) => break,
            };
            if packet.track_id != track_id {
                continue;
            }
            match decoder.decode(&packet) {
                Ok(buffer) => {
                    samples.resize(buffer.samples_interleaved(), 0.0);
                    buffer.copy_to_slice_interleaved(&mut samples);
                    peaks.push(samples.iter().fold(0.0f32, |m, v| m.max(v.abs())));
                }
                Err(Error::DecodeError(_)) | Err(Error::IoError(_)) => continue,
                Err(err) => return Err(err).context("decode"),
            }
        }
        Ok(peaks)
    }
}
