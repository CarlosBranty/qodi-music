//! Time helpers: the store keeps epoch milliseconds, the API speaks RFC 3339 UTC.

use chrono::{DateTime, SecondsFormat, Utc};
use serde::Serializer;

pub fn now_ms() -> i64 {
    Utc::now().timestamp_millis()
}

/// Formats epoch milliseconds as an RFC 3339 UTC string with second precision
/// (`2026-11-13T20:15:00Z`), matching the API contract examples.
pub fn format_ms(ms: i64) -> String {
    DateTime::<Utc>::from_timestamp_millis(ms)
        .unwrap_or_default()
        .to_rfc3339_opts(SecondsFormat::Secs, true)
}

/// Parses an RFC 3339 timestamp into epoch milliseconds.
///
/// A `+` in an un-encoded query string arrives as a space, so a space before the
/// offset is accepted as `+`.
pub fn parse_rfc3339(input: &str) -> Option<i64> {
    let input = input.trim();
    DateTime::parse_from_rfc3339(input)
        .or_else(|_| DateTime::parse_from_rfc3339(&input.replace(' ', "+")))
        .ok()
        .map(|d| d.timestamp_millis())
}

pub fn serialize_ms<S: Serializer>(ms: &i64, serializer: S) -> Result<S::Ok, S::Error> {
    serializer.serialize_str(&format_ms(*ms))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_seconds() {
        let ms = parse_rfc3339("2026-11-13T20:15:00Z").unwrap();
        assert_eq!(format_ms(ms), "2026-11-13T20:15:00Z");
        assert_eq!(parse_rfc3339("2026-11-13T21:15:00 01:00"), Some(ms));
        assert_eq!(parse_rfc3339("nope"), None);
    }
}
