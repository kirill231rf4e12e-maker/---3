<?php

require_once __DIR__ . '/db.php';

function isLoggedIn(): bool
{
    return isset($_SESSION['user_id']);
}

function userId(): ?int
{
    return isset($_SESSION['user_id']) ? (int)$_SESSION['user_id'] : null;
}

function loginUser(int $id, string $login): void
{
    session_regenerate_id(true);

    $_SESSION['user_id'] = $id;
    $_SESSION['login'] = $login;
}

function logoutUser(): void
{
    $_SESSION = [];

    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();

        setcookie(
            session_name(),
            '',
            time() - 42000,
            $params['path'],
            $params['domain'],
            $params['secure'],
            $params['httponly']
        );
    }

    session_destroy();
}

function requireLogin(): void
{
    if (!isLoggedIn()) {
        jsonResponse(false, 'Необходима авторизация');
    }
}

function currentLogin(): string
{
    return $_SESSION['login'] ?? '';
}
