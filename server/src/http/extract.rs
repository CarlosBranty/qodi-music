//! Extractors: authenticated user, and Query/Json whose rejections use the error shape.

use axum::extract::{FromRequest, FromRequestParts, Query, Request};
use axum::http::header::AUTHORIZATION;
use axum::http::request::Parts;
use axum::Json;
use serde::Deserialize;
use serde::de::DeserializeOwned;

use super::error::ApiError;
use crate::app::AppState;
use crate::auth::{User, UserRepository};

/// The user authenticated by `Authorization: Bearer <jwt>` or `?token=<jwt>`.
pub struct AuthUser(pub User);

#[derive(Deserialize)]
struct TokenQuery {
    token: Option<String>,
}

fn bearer(parts: &Parts) -> Option<String> {
    let value = parts.headers.get(AUTHORIZATION)?.to_str().ok()?;
    let (scheme, token) = value.split_once(' ')?;
    scheme.eq_ignore_ascii_case("bearer").then(|| token.trim().to_string())
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let token = bearer(parts)
            .or_else(|| Query::<TokenQuery>::try_from_uri(&parts.uri).ok().and_then(|q| q.0.token))
            .filter(|t| !t.is_empty())
            .ok_or_else(ApiError::unauthorized)?;
        let claims = state.tokens.verify(&token).ok_or_else(ApiError::unauthorized)?;
        let user = state.store.user_by_id(&claims.sub).await?.ok_or_else(ApiError::unauthorized)?;
        Ok(Self(user))
    }
}

/// An authenticated user with `is_admin`; others get 403 `forbidden`.
pub struct AdminUser(pub User);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, ApiError> {
        let AuthUser(user) = AuthUser::from_request_parts(parts, state).await?;
        if !user.is_admin {
            return Err(ApiError::forbidden());
        }
        Ok(Self(user))
    }
}

/// `Query` with `bad_request` rejections.
pub struct ApiQuery<T>(pub T);

impl<T: DeserializeOwned, S: Send + Sync> FromRequestParts<S> for ApiQuery<T> {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, ApiError> {
        Query::<T>::try_from_uri(&parts.uri)
            .map(|q| Self(q.0))
            .map_err(|err| ApiError::bad_request(err.body_text()))
    }
}

/// `Json` with `bad_request` rejections.
pub struct ApiJson<T>(pub T);

impl<T: DeserializeOwned, S: Send + Sync> FromRequest<S> for ApiJson<T> {
    type Rejection = ApiError;

    async fn from_request(req: Request, state: &S) -> Result<Self, ApiError> {
        Json::<T>::from_request(req, state)
            .await
            .map(|j| Self(j.0))
            .map_err(|err| ApiError::bad_request(err.body_text()))
    }
}

/// Treats empty query values (`?q=`) as absent.
pub fn non_empty(value: Option<String>) -> Option<String> {
    value.filter(|v| !v.trim().is_empty())
}
