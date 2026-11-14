//! `/admin/*`: user and invite management. Every handler takes [`AdminUser`].

use axum::Json;
use axum::body::Bytes;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use serde::Deserialize;
use serde_json::Value;

use super::error::{ApiError, ApiResult};
use super::extract::AdminUser;
use super::list;
use crate::app::AppState;
use crate::auth::{Invite, InviteRepository, UserRepository, generate_invite_code};
use crate::time::now_ms;

pub async fn list_users(State(state): State<AppState>, _admin: AdminUser) -> ApiResult<Json<Value>> {
    let users = state.store.users().await?;
    let total = users.len() as i64;
    Ok(list(users, total))
}

pub async fn delete_user(
    State(state): State<AppState>,
    AdminUser(admin): AdminUser,
    Path(id): Path<String>,
) -> ApiResult<StatusCode> {
    // Only admins delete and they cannot delete themselves, so at least one admin always remains.
    if id == admin.id {
        return Err(ApiError::bad_request("you cannot delete yourself"));
    }
    if !state.store.delete_user(&id).await? {
        return Err(ApiError::not_found("user"));
    }
    tracing::info!(admin = %admin.username, user_id = %id, "deleted user");
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Deserialize, Default)]
struct InviteBody {
    expires_in_hours: Option<i64>,
    max_uses: Option<i64>,
}

/// The body is optional: an empty body means all defaults.
pub async fn create_invite(
    State(state): State<AppState>,
    AdminUser(admin): AdminUser,
    body: Bytes,
) -> ApiResult<(StatusCode, Json<Invite>)> {
    let body: InviteBody = if body.iter().all(u8::is_ascii_whitespace) {
        InviteBody::default()
    } else {
        serde_json::from_slice(&body).map_err(|err| ApiError::bad_request(format!("invalid JSON body: {err}")))?
    };
    let hours = body.expires_in_hours.unwrap_or(72);
    if !(1..=720).contains(&hours) {
        return Err(ApiError::bad_request("expires_in_hours must be between 1 and 720"));
    }
    let max_uses = body.max_uses.unwrap_or(1);
    if !(1..=50).contains(&max_uses) {
        return Err(ApiError::bad_request("max_uses must be between 1 and 50"));
    }
    let now = now_ms();
    let invite = Invite {
        code: generate_invite_code()?,
        created_at: now,
        expires_at: now + hours * 3_600_000,
        max_uses,
        uses: 0,
    };
    state.store.create_invite(&invite, &admin.id).await?;
    Ok((StatusCode::CREATED, Json(invite)))
}

pub async fn list_invites(State(state): State<AppState>, _admin: AdminUser) -> ApiResult<Json<Value>> {
    let invites = state.store.invites().await?;
    let total = invites.len() as i64;
    Ok(list(invites, total))
}

pub async fn delete_invite(
    State(state): State<AppState>,
    _admin: AdminUser,
    Path(code): Path<String>,
) -> ApiResult<StatusCode> {
    if !state.store.delete_invite(&code.trim().to_uppercase()).await? {
        return Err(ApiError::not_found("invite"));
    }
    Ok(StatusCode::NO_CONTENT)
}
