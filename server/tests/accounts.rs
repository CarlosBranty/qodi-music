//! User management through the public HTTP interface: invites, registration,
//! admin endpoints, password changes and the admin bootstrap.

mod common;

use std::path::Path;

use axum::http::StatusCode;
use axum::Router;
use qodi_server::{App, Config};
use serde_json::{Value, json};
use sqlx::SqlitePool;

use common::*;

const INVITE_ALPHABET: &str = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

async fn db(data_dir: &Path) -> SqlitePool {
    SqlitePool::connect(&format!("sqlite://{}", data_dir.join("qodi.db").display())).await.unwrap()
}

async fn create_invite(env: &Env, body: Value) -> Value {
    let (status, invite) = env.send("POST", "/api/v1/admin/invites", Some(body)).await;
    assert_eq!(status, StatusCode::CREATED, "{invite}");
    invite
}

async fn register(router: &Router, code: &str, username: &str, password: &str) -> (StatusCode, Value) {
    let body = json!({"invite_code": code, "username": username, "password": password});
    json_call(router, "POST", "/api/v1/auth/register", None, Some(body)).await
}

async fn invite_uses(env: &Env, code: &str) -> i64 {
    let (_, list) = env.get("/api/v1/admin/invites").await;
    list["items"].as_array().unwrap().iter().find(|i| i["code"] == code).unwrap()["uses"].as_i64().unwrap()
}

/// Registers a fresh non-admin user and returns `(id, token)`.
async fn new_member(env: &Env, username: &str) -> (String, String) {
    let invite = create_invite(env, json!({})).await;
    let (status, body) = register(&env.app.router, invite["code"].as_str().unwrap(), username, "member-pass").await;
    assert_eq!(status, StatusCode::CREATED, "{body}");
    (body["user"]["id"].as_str().unwrap().to_string(), body["token"].as_str().unwrap().to_string())
}

#[tokio::test]
async fn invites_have_contract_shape_and_validate_input() {
    let env = setup().await;
    let before = chrono::Utc::now();
    let invite = create_invite(&env, json!({})).await;
    let code = invite["code"].as_str().unwrap();
    assert_eq!(code.len(), 12);
    assert!(code.chars().all(|c| INVITE_ALPHABET.contains(c)), "{code}");
    assert_eq!(invite["max_uses"], 1);
    assert_eq!(invite["uses"], 0);
    let created = chrono::DateTime::parse_from_rfc3339(invite["created_at"].as_str().unwrap()).unwrap();
    let expires = chrono::DateTime::parse_from_rfc3339(invite["expires_at"].as_str().unwrap()).unwrap();
    assert!((created.timestamp() - before.timestamp()).abs() <= 2);
    assert_eq!((expires - created).num_hours(), 72);

    let custom = create_invite(&env, json!({"expires_in_hours": 1, "max_uses": 50})).await;
    assert_eq!(custom["max_uses"], 50);
    let created = chrono::DateTime::parse_from_rfc3339(custom["created_at"].as_str().unwrap()).unwrap();
    let expires = chrono::DateTime::parse_from_rfc3339(custom["expires_at"].as_str().unwrap()).unwrap();
    assert_eq!((expires - created).num_hours(), 1);
    assert_ne!(custom["code"], invite["code"]);

    // A request without a body uses the defaults too.
    let (status, _, bytes) = call(&env.app.router, "POST", "/api/v1/admin/invites", Some(&env.token), None, &[]).await;
    assert_eq!(status, StatusCode::CREATED);
    let bare: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(bare["max_uses"], 1);

    for bad in [
        json!({"expires_in_hours": 0}),
        json!({"expires_in_hours": 721}),
        json!({"max_uses": 0}),
        json!({"max_uses": 51}),
        json!({"max_uses": "many"}),
    ] {
        let (status, body) = env.send("POST", "/api/v1/admin/invites", Some(bad.clone())).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "{bad}");
        assert_error(&body, "bad_request");
    }

    // Newest first, including used ones.
    let (status, list) = env.get("/api/v1/admin/invites").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(list["total"], 3);
    assert_eq!(list["items"][0]["code"], bare["code"]);
    assert_eq!(list["items"][2], invite);
}

#[tokio::test]
async fn register_with_valid_invite() {
    let env = setup().await;
    let router = &env.app.router;
    let invite = create_invite(&env, json!({"max_uses": 2})).await;
    let code = invite["code"].as_str().unwrap();

    let (status, body) = register(router, code, "  New.User_1 ", "password-123").await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "spaces are not allowed: {body}");
    assert_error(&body, "bad_request");

    let (status, body) = register(router, code, "New.User_1", "password-123").await;
    assert_eq!(status, StatusCode::CREATED, "{body}");
    assert_eq!(body["user"]["username"], "new.user_1");
    assert_eq!(body["user"]["is_admin"], false);
    let id = body["user"]["id"].as_str().unwrap().to_string();
    let token = body["token"].as_str().unwrap();
    let (status, me) = json_call(router, "GET", "/api/v1/me", Some(token), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me, json!({"id": id, "username": "new.user_1", "is_admin": false}));
    assert_eq!(invite_uses(&env, code).await, 1);

    // Login works with the stored lowercase name and with the name as typed.
    for name in ["new.user_1", "New.User_1"] {
        let (status, login) =
            json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": name, "password": "password-123"})))
                .await;
        assert_eq!(status, StatusCode::OK, "{name}");
        assert_eq!(login["user"], json!({"id": id, "username": "new.user_1", "is_admin": false}));
    }

    // Duplicate usernames are rejected case-insensitively and do not consume a use.
    let (status, body) = register(router, code, "NEW.USER_1", "password-123").await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_error(&body, "username_taken");
    let (status, body) = register(router, code, "Admin", "password-123").await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_error(&body, "username_taken");
    assert_eq!(invite_uses(&env, code).await, 1);

    // The second use succeeds, then the invite is used up.
    let (status, _) = register(router, code, "second", "password-123").await;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(invite_uses(&env, code).await, 2);
    let (status, body) = register(router, code, "third", "password-123").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "invalid_invite");
}

#[tokio::test]
async fn register_rejects_bad_invites_and_input() {
    let env = setup().await;
    let router = &env.app.router;

    let (status, body) = register(router, "AAAAAAAAAAAA", "someone", "password-123").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "invalid_invite");

    let expired = create_invite(&env, json!({})).await;
    let expired_code = expired["code"].as_str().unwrap();
    let pool = db(&env.data).await;
    sqlx::query("UPDATE invites SET expires_at = ?1 WHERE code = ?2")
        .bind(chrono::Utc::now().timestamp_millis() - 1000)
        .bind(expired_code)
        .execute(&pool)
        .await
        .unwrap();
    let (status, body) = register(router, expired_code, "someone", "password-123").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "invalid_invite");
    assert_eq!(invite_uses(&env, expired_code).await, 0);

    let invite = create_invite(&env, json!({})).await;
    let code = invite["code"].as_str().unwrap();
    let long_name = "a".repeat(33);
    let long_password = "p".repeat(129);
    for (username, password) in [
        ("ab", "password-123"),
        (long_name.as_str(), "password-123"),
        ("bad name", "password-123"),
        ("ñandú", "password-123"),
        ("valid", "short"),
        ("valid", long_password.as_str()),
    ] {
        let (status, body) = register(router, code, username, password).await;
        assert_eq!(status, StatusCode::BAD_REQUEST, "{username} / {password}");
        assert_error(&body, "bad_request");
    }
    let (status, body) =
        json_call(router, "POST", "/api/v1/auth/register", None, Some(json!({"username": "x", "password": "y"}))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
    assert_eq!(invite_uses(&env, code).await, 0);

    // Boundaries are accepted.
    let edge_name = "a".repeat(32);
    let edge_password = "p".repeat(128);
    let (status, _) = register(router, code, &edge_name, &edge_password).await;
    assert_eq!(status, StatusCode::CREATED);
}

#[tokio::test]
async fn concurrent_registrations_respect_max_uses() {
    let env = setup().await;
    let invite = create_invite(&env, json!({"max_uses": 1})).await;
    let code = invite["code"].as_str().unwrap().to_string();

    let tasks: Vec<_> = (0..8)
        .map(|i| {
            let router = env.app.router.clone();
            let code = code.clone();
            tokio::spawn(async move { register(&router, &code, &format!("racer{i}"), "password-123").await })
        })
        .collect();
    let mut created = 0;
    for task in tasks {
        let (status, body) = task.await.unwrap();
        if status == StatusCode::CREATED {
            created += 1;
        } else {
            assert_eq!(status, StatusCode::BAD_REQUEST);
            assert_error(&body, "invalid_invite");
        }
    }
    assert_eq!(created, 1);
    assert_eq!(invite_uses(&env, &code).await, 1);
    let (_, users) = env.get("/api/v1/admin/users").await;
    assert_eq!(users["total"], 2);
}

#[tokio::test]
async fn admin_routes_require_admin() {
    let env = setup().await;
    let router = &env.app.router;
    let (member_id, member) = new_member(&env, "member").await;

    let routes = [
        ("GET", "/api/v1/admin/users".to_string()),
        ("DELETE", format!("/api/v1/admin/users/{member_id}")),
        ("POST", "/api/v1/admin/invites".to_string()),
        ("GET", "/api/v1/admin/invites".to_string()),
        ("DELETE", "/api/v1/admin/invites/AAAAAAAAAAAA".to_string()),
    ];
    for (method, uri) in &routes {
        let body = (*method == "POST").then(|| json!({}));
        let (status, error) = json_call(router, method, uri, Some(&member), body.clone()).await;
        assert_eq!(status, StatusCode::FORBIDDEN, "{method} {uri}");
        assert_error(&error, "forbidden");
        let (status, error) = json_call(router, method, uri, None, body).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "{method} {uri}");
        assert_error(&error, "unauthorized");
    }
    // The member still exists: the forbidden DELETE did nothing.
    let (status, _) = json_call(router, "GET", "/api/v1/me", Some(&member), None).await;
    assert_eq!(status, StatusCode::OK);
}

#[tokio::test]
async fn admin_manages_users_and_invites() {
    let env = setup().await;
    let router = &env.app.router;
    let (_, admin) = env.get("/api/v1/me").await;
    let admin_id = admin["id"].as_str().unwrap().to_string();
    let (member_id, member) = new_member(&env, "member").await;
    let (other_id, other) = new_member(&env, "other").await;

    let (status, users) = env.get("/api/v1/admin/users").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(users["total"], 3);
    let names: Vec<_> = users["items"].as_array().unwrap().iter().map(|u| u["username"].as_str().unwrap()).collect();
    assert_eq!(names, vec![USER, "member", "other"]);
    let first = users["items"][0].as_object().unwrap();
    let mut keys: Vec<_> = first.keys().map(String::as_str).collect();
    keys.sort_unstable();
    assert_eq!(keys, vec!["created_at", "id", "is_admin", "username"]);
    assert_eq!(users["items"][0]["is_admin"], true);
    assert_eq!(users["items"][1]["is_admin"], false);
    assert!(users["items"][1]["created_at"].as_str().unwrap().ends_with('Z'));

    // The member builds up personal data.
    let alpha = short_hash(ALPHA);
    let (status, playlist) =
        json_call(router, "POST", "/api/v1/playlists", Some(&member), Some(json!({"name": "Mine"}))).await;
    assert_eq!(status, StatusCode::CREATED);
    let patch = json!({"track_ids": [alpha]});
    let uri = format!("/api/v1/playlists/{}", playlist["id"].as_str().unwrap());
    assert_eq!(json_call(router, "PATCH", &uri, Some(&member), Some(patch)).await.0, StatusCode::OK);
    let fav = format!("/api/v1/favorites/{alpha}");
    assert_eq!(json_call(router, "PUT", &fav, Some(&member), None).await.0, StatusCode::NO_CONTENT);
    assert_eq!(json_call(router, "PUT", &fav, Some(&other), None).await.0, StatusCode::NO_CONTENT);
    let play = json!({"plays": [{"client_id": "6f1c2b9e-0c55-4d1e-9a7a-6f8d2a3b4c5d", "track_id": alpha,
        "played_at": "2026-11-13T10:00:00Z", "listened_ms": 1000}]});
    assert_eq!(json_call(router, "POST", "/api/v1/plays", Some(&member), Some(play.clone())).await.0, StatusCode::OK);
    assert_eq!(json_call(router, "POST", "/api/v1/plays", Some(&other), Some(play)).await.0, StatusCode::OK);

    // Admins cannot delete themselves; unknown users are 404.
    let (status, body) = env.send("DELETE", &format!("/api/v1/admin/users/{admin_id}"), None).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
    let (status, body) = env.send("DELETE", "/api/v1/admin/users/nobody", None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");

    let (status, body) = env.send("DELETE", &format!("/api/v1/admin/users/{member_id}"), None).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "{body}");
    assert_eq!(body, Value::Null);
    let (status, body) = json_call(router, "GET", "/api/v1/me", Some(&member), None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_error(&body, "unauthorized");
    let (status, _) = env.send("DELETE", &format!("/api/v1/admin/users/{member_id}"), None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let pool = db(&env.data).await;
    for table in ["playlists", "favorites", "plays"] {
        let count: i64 = sqlx::query_scalar(sqlx::AssertSqlSafe(format!("SELECT COUNT(*) FROM {table} WHERE user_id = ?1")))
            .bind(&member_id)
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(count, 0, "{table}");
    }
    let orphans: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM playlist_tracks").fetch_one(&pool).await.unwrap();
    assert_eq!(orphans, 0);

    // The other user is unaffected.
    let (status, favorites) = json_call(router, "GET", "/api/v1/favorites", Some(&other), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(favorites["total"], 1);
    let (_, stats) = json_call(router, "GET", "/api/v1/stats/summary?range=all", Some(&other), None).await;
    assert_eq!(stats["total_plays"], 1);
    let (_, users) = env.get("/api/v1/admin/users").await;
    let ids: Vec<_> = users["items"].as_array().unwrap().iter().map(|u| u["id"].as_str().unwrap()).collect();
    assert_eq!(ids, vec![admin_id.as_str(), other_id.as_str()]);

    // Revoking an invite removes it and makes it unusable.
    let invite = create_invite(&env, json!({})).await;
    let code = invite["code"].as_str().unwrap();
    let (status, body) = env.send("DELETE", &format!("/api/v1/admin/invites/{code}"), None).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
    assert_eq!(body, Value::Null);
    let (_, list) = env.get("/api/v1/admin/invites").await;
    assert!(list["items"].as_array().unwrap().iter().all(|i| i["code"] != code));
    let (status, body) = env.send("DELETE", &format!("/api/v1/admin/invites/{code}"), None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");
    let (status, body) = register(router, code, "late", "password-123").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "invalid_invite");

    // Revocation accepts the code in any case, like registration does.
    let invite = create_invite(&env, json!({})).await;
    let lower = invite["code"].as_str().unwrap().to_lowercase();
    let (status, _) = env.send("DELETE", &format!("/api/v1/admin/invites/{lower}"), None).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}

#[tokio::test]
async fn change_password() {
    let env = setup().await;
    let router = &env.app.router;
    let login = |password: &'static str| {
        let router = router.clone();
        async move {
            json_call(&router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER, "password": password})))
                .await
                .0
        }
    };

    let (status, body) = env
        .send("PUT", "/api/v1/me/password", Some(json!({"current_password": "wrong", "new_password": "brand-new-pass"})))
        .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_error(&body, "invalid_credentials");
    for new_password in ["short".to_string(), "x".repeat(129)] {
        let (status, body) = env
            .send("PUT", "/api/v1/me/password", Some(json!({"current_password": PASSWORD, "new_password": new_password})))
            .await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_error(&body, "bad_request");
    }
    let (status, body) = env.send("PUT", "/api/v1/me/password", Some(json!({"current_password": PASSWORD}))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
    let (status, body) = json_call(
        router,
        "PUT",
        "/api/v1/me/password",
        None,
        Some(json!({"current_password": PASSWORD, "new_password": "brand-new-pass"})),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_error(&body, "unauthorized");
    assert_eq!(login(PASSWORD).await, StatusCode::OK);

    let (status, body) = env
        .send("PUT", "/api/v1/me/password", Some(json!({"current_password": PASSWORD, "new_password": "brand-new-pass"})))
        .await;
    assert_eq!(status, StatusCode::NO_CONTENT);
    assert_eq!(body, Value::Null);
    assert_eq!(login(PASSWORD).await, StatusCode::UNAUTHORIZED);
    assert_eq!(login("brand-new-pass").await, StatusCode::OK);
}

#[tokio::test]
async fn bootstrap_promotes_admin_and_never_resets_password() {
    let env = setup().await;
    let (member_id, _) = new_member(&env, "member").await;
    let config_for = |admin: &str, password: &str| {
        let mut config = Config::new(&env.music, &env.data);
        config.web_dir = env.data.join("no-web");
        config.scan_interval_secs = 0;
        config.admin_user = Some(admin.into());
        config.admin_password = Some(password.into());
        config
    };
    let login = |app: &App, username: &str, password: &str| {
        let router = app.router.clone();
        let body = json!({"username": username, "password": password});
        async move { json_call(&router, "POST", "/api/v1/auth/login", None, Some(body)).await }
    };

    // Restart with a different password: the stored one stays, the user stays admin.
    let app = App::build(config_for(USER, "another-password")).await.unwrap();
    assert_eq!(login(&app, USER, "another-password").await.0, StatusCode::UNAUTHORIZED);
    let (status, body) = login(&app, USER, PASSWORD).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["user"]["is_admin"], true);
    let (_, body) = login(&app, "member", "member-pass").await;
    assert_eq!(body["user"]["is_admin"], false);

    // Naming an existing user as admin promotes it without touching its password.
    let app = App::build(config_for("member", "ignored-password")).await.unwrap();
    let (status, body) = login(&app, "member", "member-pass").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["user"], json!({"id": member_id, "username": "member", "is_admin": true}));
    assert_eq!(login(&app, "member", "ignored-password").await.0, StatusCode::UNAUTHORIZED);

    // A configured admin that does not exist yet is created as admin.
    let app = App::build(config_for("fresh", "fresh-password")).await.unwrap();
    let (status, body) = login(&app, "fresh", "fresh-password").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["user"]["is_admin"], true);
}
