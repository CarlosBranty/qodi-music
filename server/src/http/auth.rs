use axum::Json;
use axum::extract::State;
use serde::Deserialize;
use serde_json::{Value, json};

use super::error::{ApiError, ApiResult};
use super::extract::{ApiJson, AuthUser};
use crate::app::AppState;
use crate::auth::{User, UserRepository, check_password};

#[derive(Deserialize)]
pub struct LoginBody {
    username: String,
    password: String,
}

pub async fn login(State(state): State<AppState>, ApiJson(body): ApiJson<LoginBody>) -> ApiResult<Json<Value>> {
    let credentials = state.store.credentials(&body.username).await?;
    let hash = credentials.as_ref().map(|c| c.password_hash.clone());
    if !check_password(body.password, hash).await {
        return Err(ApiError::invalid_credentials());
    }
    let credentials = credentials.ok_or_else(ApiError::invalid_credentials)?;
    let user = User { id: credentials.id, username: credentials.username };
    let token = state.tokens.issue(&user)?;
    Ok(Json(json!({ "token": token, "user": user })))
}

pub async fn me(AuthUser(user): AuthUser) -> Json<User> {
    Json(user)
}
