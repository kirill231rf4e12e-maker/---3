<?php

require_once __DIR__ . '/auth.php';

if (isset($_GET['logout'])) {
    logoutUser();
    header('Location: login.php');
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $login = trim((string)($_POST['login'] ?? ''));
    $password = (string)($_POST['password'] ?? '');

    if ($login === '' || $password === '') {
        $error = 'Заполните все поля';
    } else {
        try {
            $users = callProcedure(
                'CALL get_user_for_login(?)',
                [$login]
            );

            $user = $users[0] ?? null;

            if ($user && password_verify($password, $user['password'])) {
                loginUser((int)$user['id'], $user['login']);
                header('Location: index.php');
                exit;
            }

            $error = 'Неверный логин или пароль';
        } catch (PDOException $e) {
            $error = 'Не удалось выполнить вход';
        }
    }
}
?>
<!doctype html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Вход</title>
    <link rel="stylesheet" href="assets/css/base.css">
    <link rel="stylesheet" href="assets/css/login.css">
</head>
<body class="site-body auth-page">
<div class="page-shell page-shell--narrow">
    <main class="auth-card">
        <div class="brand-block">
            <span class="brand-mark">TB</span>
            <div>
                <p class="eyebrow">БЛОГ</p>
                <h1>Вход</h1>
            </div>
        </div>

        <?php if ($error): ?>
            <div class="alert alert--error"><?= h($error) ?></div>
        <?php endif; ?>

        <form method="post" class="form-stack">
            <label class="field">
                <span class="field__label">Логин</span>
                <input class="input" type="text" name="login" maxlength="50" autocomplete="username" required>
            </label>

            <label class="field">
                <span class="field__label">Пароль</span>
                <input class="input" type="password" name="password" autocomplete="current-password" required>
            </label>

            <button class="button button--primary button--full" type="submit">Войти</button>
        </form>

        <div class="auth-links">
            <a href="register.php">Создать аккаунт</a>
            <a href="index.php">На главную</a>
        </div>
    </main>
</div>
</body>
</html>
