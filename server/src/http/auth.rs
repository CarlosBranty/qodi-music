use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use serde::Deserialize;
use serde_json::{Value, json};

use super::error::{ApiError, ApiResult};
use super::extract::{ApiJson, AuthUser};
use crate::app::AppState;
use crate::auth::{
    Credentials, RegisterOutcome, User, UserRepository, check_password, hash_password_async, normalize_username,
    valid_password,
};
use crate::time::now_ms;

#[derive(Deserialize)]
pub struct LoginBody {
    username: String,
    password: String,
}

/// Exact match first; registered usernames are stored lowercase, so a name typed
/// with capitals falls back to its lowercase form.
async fn find_credentials(state: &AppState, username: &str) -> ApiResult<Option<Credentials>> {
    if let Some(found) = state.store.credentials(username).await? {
        return Ok(Some(found));
    }
    let lower = username.to_lowercase();
    if lower == username {
        return Ok(None);
    }
    Ok(state.store.credentials(&lower).await?)
}

fn session(state: &AppState, user: &User) -> ApiResult<Json<Value>> {
    let token = state.tokens.issue(user)?;
    Ok(Json(json!({ "token": token, "user": user })))
}

pub async fn login(State(state): State<AppState>, ApiJson(body): ApiJson<LoginBody>) -> ApiResult<Json<Value>> {
    let credentials = find_credentials(&state, &body.username).await?;
    let hash = credentials.as_ref().map(|c| c.password_hash.clone());
    if !check_password(body.password, hash).await {
        return Err(ApiError::invalid_credentials());
    }
    let credentials = credentials.ok_or_else(ApiError::invalid_credentials)?;
    session(&state, &credentials.user())
}

#[derive(Deserialize)]
pub struct RegisterBody {
    invite_code: String,
    username: String,
    password: String,
}

const USERNAME_RULE: &str = "username must match ^[a-z0-9_.-]{3,32}$ after lowercasing";
const PASSWORD_RULE: &str = "password must be 8 to 128 characters";

pub async fn register(
    State(state): State<AppState>,
    ApiJson(body): ApiJson<RegisterBody>,
) -> ApiResult<(StatusCode, Json<Value>)> {
    let username = normalize_username(&body.username).ok_or_else(|| ApiError::bad_request(USERNAME_RULE))?;
    if !valid_password(&body.password) {
        return Err(ApiError::bad_request(PASSWORD_RULE));
    }
    let hash = hash_password_async(body.password).await?;
    let code = body.invite_code.trim().to_uppercase();
    match state.store.register(&code, &username, &hash, now_ms()).await? {
        RegisterOutcome::Created(user) => {
            tracing::info!(username = %user.username, "registered user");
            Ok((StatusCode::CREATED, session(&state, &user)?))
        }
        RegisterOutcome::InvalidInvite => Err(ApiError::invalid_invite()),
        RegisterOutcome::UsernameTaken => Err(ApiError::username_taken()),
    }
}

pub async fn me(AuthUser(user): AuthUser) -> Json<User> {
    Json(user)
}

#[derive(Deserialize)]
pub struct PasswordBody {
    current_password: String,
    new_password: String,
}

pub async fn change_password(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiJson(body): ApiJson<PasswordBody>,
) -> ApiResult<StatusCode> {
    let credentials = state.store.credentials_by_id(&user.id).await?.ok_or_else(ApiError::unauthorized)?;
    if !check_password(body.current_password, Some(credentials.password_hash)).await {
        return Err(ApiError::invalid_credentials());
    }
    if !valid_password(&body.new_password) {
        return Err(ApiError::bad_request(PASSWORD_RULE));
    }
    let hash = hash_password_async(body.new_password).await?;
    state.store.set_password_hash(&user.id, &hash).await?;
    Ok(StatusCode::NO_CONTENT)
}
