//! Lyrics: sidecar `.lrc` files or embedded lyrics tags, parsed into synced or plain lines.

use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Lyrics {
    pub synced: bool,
    pub lines: Vec<LyricLine>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct LyricLine {
    pub time_ms: Option<i64>,
    pub text: String,
}

/// Parses LRC (`[mm:ss.xx]text`, several timestamps per line allowed) or plain text.
/// Returns `None` when there is no lyric content.
pub fn parse(source: &str) -> Option<Lyrics> {
    let mut timed = Vec::new();
    let mut plain = Vec::new();

    for raw in source.lines() {
        let line = raw.trim_end_matches('\r');
        let mut rest = line.trim_start();
        let mut stamps = Vec::new();
        let mut had_tag = false;
        while let Some(stripped) = rest.strip_prefix('[') {
            let Some(end) = stripped.find(']') else { break };
            let tag = &stripped[..end];
            match parse_timestamp(tag) {
                Some(ms) => stamps.push(ms),
                None if is_metadata_tag(tag) => had_tag = true,
                None => break,
            }
            rest = &stripped[end + 1..];
        }
        if !stamps.is_empty() {
            let text = rest.trim().to_string();
            timed.extend(stamps.into_iter().map(|ms| LyricLine { time_ms: Some(ms), text: text.clone() }));
        } else if !had_tag {
            plain.push(LyricLine { time_ms: None, text: line.trim().to_string() });
        }
    }

    if !timed.is_empty() {
        timed.sort_by_key(|l| l.time_ms);
        return Some(Lyrics { synced: true, lines: timed });
    }
    while plain.first().is_some_and(|l| l.text.is_empty()) {
        plain.remove(0);
    }
    while plain.last().is_some_and(|l| l.text.is_empty()) {
        plain.pop();
    }
    (!plain.is_empty()).then_some(Lyrics { synced: false, lines: plain })
}

fn is_metadata_tag(tag: &str) -> bool {
    tag.split_once(':').is_some_and(|(key, _)| !key.is_empty() && key.chars().all(|c| c.is_ascii_alphabetic()))
}

/// `mm:ss`, `mm:ss.f`, `mm:ss.ff`, `mm:ss.fff` (also `:` as fraction separator).
fn parse_timestamp(tag: &str) -> Option<i64> {
    let (minutes, rest) = tag.split_once(':')?;
    let (seconds, fraction) = match rest.find(['.', ':']) {
        Some(i) => (&rest[..i], Some(&rest[i + 1..])),
        None => (rest, None),
    };
    let digits = |s: &str| !s.is_empty() && s.chars().all(|c| c.is_ascii_digit());
    if !digits(minutes) || !digits(seconds) {
        return None;
    }
    let mut ms = minutes.parse::<i64>().ok()? * 60_000 + seconds.parse::<i64>().ok()? * 1000;
    if let Some(fraction) = fraction {
        if !digits(fraction) {
            return None;
        }
        let padded: String = fraction.chars().chain("000".chars()).take(3).collect();
        ms += padded.parse::<i64>().ok()?;
    }
    Some(ms)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_synced_lrc() {
        let lyrics = parse("[ar:Someone]\n[00:12.50]Hello\n[01:02.003][00:05]Twice\n").unwrap();
        assert!(lyrics.synced);
        let times: Vec<_> = lyrics.lines.iter().map(|l| l.time_ms.unwrap()).collect();
        assert_eq!(times, vec![5000, 12500, 62003]);
        assert_eq!(lyrics.lines[1].text, "Hello");
    }

    #[test]
    fn parses_plain_text() {
        let lyrics = parse("\nfirst\n\nsecond\n\n").unwrap();
        assert!(!lyrics.synced);
        assert_eq!(lyrics.lines.len(), 3);
        assert_eq!(lyrics.lines[0], LyricLine { time_ms: None, text: "first".into() });
        assert_eq!(parse("  \n"), None);
    }
}
