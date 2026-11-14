use axum::Json;
use axum::extract::State;
use serde::Deserialize;
use serde_json::{Value, json};

use super::error::{ApiError, ApiResult};
use super::extract::{ApiJson, ApiQuery, AuthUser};
use crate::app::AppState;
use crate::stats::{PlayRecord, StatsRange, StatsRepository, Summary};
use crate::time::{now_ms, parse_rfc3339};

#[derive(Deserialize)]
pub struct PlayInput {
    client_id: String,
    track_id: String,
    played_at: String,
    listened_ms: i64,
}

#[derive(Deserialize)]
pub struct PlaysBody {
    plays: Vec<PlayInput>,
}

pub async fn record_plays(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiJson(body): ApiJson<PlaysBody>,
) -> ApiResult<Json<Value>> {
    let plays = body
        .plays
        .into_iter()
        .map(|play| {
            let client_id = uuid::Uuid::parse_str(&play.client_id)
                .map_err(|_| ApiError::bad_request("client_id must be a UUID"))?;
            let played_at_ms =
                parse_rfc3339(&play.played_at).ok_or_else(|| ApiError::bad_request("played_at must be RFC 3339"))?;
            if play.listened_ms < 0 {
                return Err(ApiError::bad_request("listened_ms must not be negative"));
            }
            Ok(PlayRecord {
                client_id: client_id.hyphenated().to_string(),
                track_id: play.track_id,
                played_at_ms,
                listened_ms: play.listened_ms,
            })
        })
        .collect::<Result<Vec<_>, ApiError>>()?;
    let accepted = state.store.record_plays(&user.id, &plays).await?;
    Ok(Json(json!({ "accepted": accepted })))
}

#[derive(Deserialize)]
pub struct SummaryQuery {
    range: Option<String>,
}

pub async fn summary(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiQuery(query): ApiQuery<SummaryQuery>,
) -> ApiResult<Json<Summary>> {
    let range = StatsRange::parse(query.range.as_deref())
        .ok_or_else(|| ApiError::bad_request("range must be 7d, 30d or all"))?;
    Ok(Json(state.store.summary(&user.id, range, now_ms()).await?))
}
