<?php

require_once __DIR__ . '/auth.php';

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $login = trim((string)($_POST['login'] ?? ''));
    $password = (string)($_POST['password'] ?? '');
    $password2 = (string)($_POST['password2'] ?? '');

    if ($login === '' || $password === '') {
        $error = 'Заполните все поля';
    } elseif (mb_strlen($login) > 50) {
        $error = 'Логин слишком длинный';
    } elseif (strlen($password) < 4) {
        $error = 'Пароль должен содержать минимум 4 символа';
    } elseif ($password !== $password2) {
        $error = 'Пароли не совпадают';
    } else {
        try {
            $hash = password_hash($password, PASSWORD_DEFAULT);

            $rows = callProcedure(
                'CALL register_user(?, ?)',
                [$login, $hash]
            );

            $user = $rows[0] ?? null;

            if (!$user) {
                throw new RuntimeException('Пользователь не был создан');
            }

            loginUser((int)$user['id'], $user['login']);

            header('Location: index.php');
            exit;
        } catch (PDOException $e) {
            if (($e->errorInfo[1] ?? null) === 1062) {
                $error = 'Такой логин уже существует';
            } else {
                $error = 'Не удалось зарегистрировать пользователя';
            }
        } catch (RuntimeException $e) {
            $error = 'Не удалось зарегистрировать пользователя';
        }
    }
}
?>
<!doctype html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Регистрация</title>
    <link rel="stylesheet" href="assets/css/base.css">
    <link rel="stylesheet" href="assets/css/register.css">
</head>
<body class="site-body auth-page">
<div class="page-shell page-shell--narrow">
    <main class="auth-card">
        <div class="brand-block">
            <span class="brand-mark">TB</span>
            <div>
                <p class="eyebrow">БЛОГ</p>
                <h1>Создание аккаунта</h1>
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
                <input class="input" type="password" name="password" autocomplete="new-password" required>
            </label>

            <label class="field">
                <span class="field__label">Повторите пароль</span>
                <input class="input" type="password" name="password2" autocomplete="new-password" required>
            </label>

            <button class="button button--primary button--full" type="submit">Зарегистрироваться и войти</button>
        </form>

        <div class="auth-links">
            <a href="login.php">Уже есть аккаунт? Войти</a>
            <a href="index.php">На главную</a>
        </div>
    </main>
</div>
</body>
</html>
