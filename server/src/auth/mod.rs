//! Auth: users, argon2 password hashes and JWT bearer tokens.

use std::future::Future;
use std::path::Path;
use std::sync::OnceLock;

use anyhow::{Context, Result, anyhow};
use argon2::Argon2;
use argon2::password_hash::phc::PasswordHash;
use argon2::password_hash::{PasswordHasher, PasswordVerifier};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct User {
    pub id: String,
    pub username: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Credentials {
    pub id: String,
    pub username: String,
    pub password_hash: String,
}

/// Port: user persistence.
pub trait UserRepository: Send + Sync {
    fn user_by_id(&self, id: &str) -> impl Future<Output = Result<Option<User>>> + Send;
    fn credentials(&self, username: &str) -> impl Future<Output = Result<Option<Credentials>>> + Send;
    fn create_user(&self, username: &str, password_hash: &str, now_ms: i64) -> impl Future<Output = Result<User>> + Send;
}

pub fn hash_password(password: &str) -> Result<String> {
    Argon2::default()
        .hash_password(password.as_bytes())
        .map(|hash| hash.to_string())
        .map_err(|err| anyhow!("hash password: {err}"))
}

pub fn verify_password(password: &str, phc: &str) -> bool {
    PasswordHash::new(phc)
        .map(|hash| Argon2::default().verify_password(password.as_bytes(), &hash).is_ok())
        .unwrap_or(false)
}

/// Verifies on the blocking pool. Unknown users still pay for one verification so
/// response timing does not reveal which usernames exist.
pub async fn check_password(password: String, phc: Option<String>) -> bool {
    tokio::task::spawn_blocking(move || match phc {
        Some(phc) => verify_password(&password, &phc),
        None => {
            static DUMMY: OnceLock<String> = OnceLock::new();
            let dummy = DUMMY.get_or_init(|| hash_password("qodi-dummy-password").unwrap_or_default());
            let _ = verify_password(&password, dummy);
            false
        }
    })
    .await
    .unwrap_or(false)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub username: String,
    pub iat: i64,
    pub exp: i64,
}

pub struct TokenService {
    encoding: EncodingKey,
    decoding: DecodingKey,
    ttl_secs: i64,
}

impl TokenService {
    pub fn new(secret: &[u8], ttl_days: i64) -> Result<Self> {
        Ok(Self {
            encoding: EncodingKey::from_secret(secret)?,
            decoding: DecodingKey::from_secret(secret)?,
            ttl_secs: ttl_days.max(1) * 86_400,
        })
    }

    pub fn issue(&self, user: &User) -> Result<String> {
        let now = chrono::Utc::now().timestamp();
        let claims = Claims { sub: user.id.clone(), username: user.username.clone(), iat: now, exp: now + self.ttl_secs };
        jsonwebtoken::encode(&Header::new(Algorithm::HS256), &claims, &self.encoding).context("sign token")
    }

    pub fn verify(&self, token: &str) -> Option<Claims> {
        let validation = Validation::new(Algorithm::HS256);
        jsonwebtoken::decode::<Claims>(token, &self.decoding, &validation).ok().map(|data| data.claims)
    }
}

/// Uses the configured secret, else the persisted `{data}/jwt_secret`, else generates
/// a random one and persists it with mode 0600.
pub fn load_or_create_secret(data_dir: &Path, configured: Option<&str>) -> Result<Vec<u8>> {
    if let Some(secret) = configured {
        return Ok(secret.as_bytes().to_vec());
    }
    let path = data_dir.join("jwt_secret");
    if path.exists() {
        let secret = std::fs::read_to_string(&path).context("read jwt_secret")?;
        let secret = secret.trim();
        if !secret.is_empty() {
            return Ok(secret.as_bytes().to_vec());
        }
    }
    let mut bytes = [0u8; 32];
    getrandom::fill(&mut bytes).map_err(|err| anyhow!("random secret: {err}"))?;
    let secret = hex::encode(bytes);
    write_private(&path, secret.as_bytes())?;
    tracing::info!(path = %path.display(), "generated JWT secret");
    Ok(secret.into_bytes())
}

fn write_private(path: &Path, contents: &[u8]) -> Result<()> {
    use std::io::Write;
    let mut options = std::fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(path).with_context(|| format!("create {}", path.display()))?;
    file.write_all(contents)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hashes_and_verifies() {
        let hash = hash_password("s3cret").unwrap();
        assert!(verify_password("s3cret", &hash));
        assert!(!verify_password("nope", &hash));
        assert!(!verify_password("s3cret", "garbage"));
    }

    #[test]
    fn tokens_round_trip_and_reject_tampering() {
        let tokens = TokenService::new(b"secret", 30).unwrap();
        let user = User { id: "u1".into(), username: "me".into() };
        let token = tokens.issue(&user).unwrap();
        assert_eq!(tokens.verify(&token).unwrap().sub, "u1");
        let other = TokenService::new(b"other", 30).unwrap();
        assert!(other.verify(&token).is_none());
    }
}
