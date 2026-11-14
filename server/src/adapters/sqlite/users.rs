use anyhow::Result;
use sqlx::SqliteConnection;

use super::SqliteStore;
use crate::auth::{Credentials, Invite, InviteRepository, RegisterOutcome, User, UserRepository, UserSummary};

/// The single insert used by both the admin bootstrap and registration.
async fn insert_user(
    conn: &mut SqliteConnection,
    username: &str,
    password_hash: &str,
    is_admin: bool,
    now_ms: i64,
) -> Result<User> {
    let id = uuid::Uuid::new_v4().to_string();
    sqlx::query("INSERT INTO users (id, username, password_hash, created_at, is_admin) VALUES (?1, ?2, ?3, ?4, ?5)")
        .bind(&id)
        .bind(username)
        .bind(password_hash)
        .bind(now_ms)
        .bind(is_admin)
        .execute(conn)
        .await?;
    Ok(User { id, username: username.to_string(), is_admin })
}

impl UserRepository for SqliteStore {
    async fn user_by_id(&self, id: &str) -> Result<Option<User>> {
        Ok(sqlx::query_as::<_, User>("SELECT id, username, is_admin FROM users WHERE id = ?1")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn credentials(&self, username: &str) -> Result<Option<Credentials>> {
        Ok(sqlx::query_as::<_, Credentials>(
            "SELECT id, username, is_admin, password_hash FROM users WHERE username = ?1",
        )
        .bind(username)
        .fetch_optional(&self.pool)
        .await?)
    }

    async fn credentials_by_id(&self, id: &str) -> Result<Option<Credentials>> {
        Ok(sqlx::query_as::<_, Credentials>("SELECT id, username, is_admin, password_hash FROM users WHERE id = ?1")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn create_user(&self, username: &str, password_hash: &str, is_admin: bool, now_ms: i64) -> Result<User> {
        let mut conn = self.pool.acquire().await?;
        insert_user(&mut conn, username, password_hash, is_admin, now_ms).await
    }

    async fn set_admin(&self, id: &str, is_admin: bool) -> Result<()> {
        sqlx::query("UPDATE users SET is_admin = ?2 WHERE id = ?1").bind(id).bind(is_admin).execute(&self.pool).await?;
        Ok(())
    }

    async fn set_password_hash(&self, id: &str, password_hash: &str) -> Result<()> {
        sqlx::query("UPDATE users SET password_hash = ?2 WHERE id = ?1")
            .bind(id)
            .bind(password_hash)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn users(&self) -> Result<Vec<UserSummary>> {
        Ok(sqlx::query_as::<_, UserSummary>(
            "SELECT id, username, is_admin, created_at FROM users ORDER BY created_at, username",
        )
        .fetch_all(&self.pool)
        .await?)
    }

    async fn delete_user(&self, id: &str) -> Result<bool> {
        // Playlists (and their tracks), favorites and plays go by ON DELETE CASCADE.
        let result = sqlx::query("DELETE FROM users WHERE id = ?1").bind(id).execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }

    async fn register(&self, invite_code: &str, username: &str, password_hash: &str, now_ms: i64) -> Result<RegisterOutcome> {
        // BEGIN IMMEDIATE takes the write lock up front, so the invite check, the
        // username check and both writes are serialized against concurrent registrations.
        let mut tx = self.pool.begin_with("BEGIN IMMEDIATE").await?;
        let consumed = sqlx::query(
            "UPDATE invites SET uses = uses + 1 WHERE code = ?1 AND uses < max_uses AND expires_at > ?2",
        )
        .bind(invite_code)
        .bind(now_ms)
        .execute(&mut *tx)
        .await?;
        if consumed.rows_affected() == 0 {
            return Ok(RegisterOutcome::InvalidInvite);
        }
        let taken: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users WHERE lower(username) = lower(?1))")
            .bind(username)
            .fetch_one(&mut *tx)
            .await?;
        if taken {
            // Dropping the transaction rolls back the consumed use.
            return Ok(RegisterOutcome::UsernameTaken);
        }
        let user = insert_user(&mut tx, username, password_hash, false, now_ms).await?;
        tx.commit().await?;
        Ok(RegisterOutcome::Created(user))
    }
}

impl InviteRepository for SqliteStore {
    async fn create_invite(&self, invite: &Invite, created_by: &str) -> Result<()> {
        sqlx::query(
            "INSERT INTO invites (code, created_by, created_at, expires_at, max_uses, uses) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )
        .bind(&invite.code)
        .bind(created_by)
        .bind(invite.created_at)
        .bind(invite.expires_at)
        .bind(invite.max_uses)
        .bind(invite.uses)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn invites(&self) -> Result<Vec<Invite>> {
        Ok(sqlx::query_as::<_, Invite>(
            "SELECT code, created_at, expires_at, max_uses, uses FROM invites ORDER BY created_at DESC, rowid DESC",
        )
        .fetch_all(&self.pool)
        .await?)
    }

    async fn delete_invite(&self, code: &str) -> Result<bool> {
        let result = sqlx::query("DELETE FROM invites WHERE code = ?1").bind(code).execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }
}
