use anyhow::Result;

use super::SqliteStore;
use crate::auth::{Credentials, User, UserRepository};

impl UserRepository for SqliteStore {
    async fn user_by_id(&self, id: &str) -> Result<Option<User>> {
        Ok(sqlx::query_as::<_, User>("SELECT id, username FROM users WHERE id = ?1")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn credentials(&self, username: &str) -> Result<Option<Credentials>> {
        Ok(sqlx::query_as::<_, Credentials>("SELECT id, username, password_hash FROM users WHERE username = ?1")
            .bind(username)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn create_user(&self, username: &str, password_hash: &str, now_ms: i64) -> Result<User> {
        let id = uuid::Uuid::new_v4().to_string();
        sqlx::query("INSERT INTO users (id, username, password_hash, created_at) VALUES (?1, ?2, ?3, ?4)")
            .bind(&id)
            .bind(username)
            .bind(password_hash)
            .bind(now_ms)
            .execute(&self.pool)
            .await?;
        Ok(User { id, username: username.to_string() })
    }
}
