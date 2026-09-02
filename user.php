<?php

require_once __DIR__ . '/auth.php';

$profile = null;
$posts = [];
$error = '';

$profileId = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($profileId <= 0) {
    $error = 'Пользователь не найден';
} else {
    try {
        $rows = callProcedure(
            'CALL get_user_profile(?, ?)',
            [$profileId, userId()]
        );

        $profile = $rows[0] ?? null;

        if (!$profile) {
            $error = 'Пользователь не найден';
        } else {
            $posts = callProcedure(
                'CALL get_user_public_posts(?)',
                [$profileId]
            );
        }
    } catch (PDOException $e) {
        $error = 'Ошибка базы данных';
    }
}
?>
<!doctype html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= $profile ? '@' . h($profile['login']) : 'Профиль' ?></title>
    <link rel="stylesheet" href="assets/css/base.css">
    <link rel="stylesheet" href="assets/css/user.css">
</head>
<body class="site-body">
<div class="page-shell page-shell--narrow-wide">
    <div class="page-topbar">
        <a class="text-link" href="index.php">← На главную</a>
        <?php if (isLoggedIn()): ?>
            <span class="user-chip">@<?= h(currentLogin()) ?></span>
        <?php else: ?>
            <a class="button button--small button--ghost" href="login.php">Войти</a>
        <?php endif; ?>
    </div>

    <?php if ($error): ?>
        <div class="alert alert--error"><?= h($error) ?></div>
    <?php elseif ($profile): ?>
        <section class="profile-hero">
            <div class="profile-avatar">@</div>
            <div class="profile-main">
                <p class="eyebrow">ПРОФИЛЬ</p>
                <h1>@<?= h($profile['login']) ?></h1>
                <p class="muted">Аккаунт создан <?= h(date('d.m.Y', strtotime($profile['created_at']))) ?></p>
            </div>

            <?php if (isLoggedIn() && (int)$profile['id'] !== userId()): ?>
                <div class="profile-actions">
                    <button
                        id="profile-subscribe-button"
                        class="button <?= (int)$profile['is_following'] === 1 ? 'button--secondary' : 'button--primary' ?>"
                        type="button"
                        onclick="toggleSubscription(<?= (int)$profile['id'] ?>)"
                        data-following="<?= (int)$profile['is_following'] ?>"
                        data-user-id="<?= (int)$profile['id'] ?>"
                    >
                        <?= (int)$profile['is_following'] === 1 ? 'Отписаться' : 'Подписаться' ?>
                    </button>
                </div>
            <?php endif; ?>
        </section>

        <section class="stats-grid">
            <div class="stat-card"><strong><?= (int)$profile['public_posts_count'] ?></strong><span>Публичных постов</span></div>
            <div class="stat-card"><strong id="profile-followers-count"><?= (int)$profile['followers_count'] ?></strong><span>Подписчиков</span></div>
            <div class="stat-card"><strong id="profile-following-count"><?= (int)$profile['following_count'] ?></strong><span>Подписок</span></div>
        </section>

        <section class="panel">
            <div class="section-heading">
                <div>
                    <p class="eyebrow">ЗАПИСИ</p>
                    <h2>Публичные записи</h2>
                </div>
            </div>

            <div class="posts-grid">
                <?php if (!$posts): ?>
                    <div class="empty-state">Публичных постов пока нет.</div>
                <?php endif; ?>

                <?php foreach ($posts as $post): ?>
                    <article class="post-card">
                        <h3><?= h($post['title']) ?></h3>
                        <p class="post-meta">Автор: <a class="author-link" href="user.php?id=<?= (int)$post['user_id'] ?>">@<?= h($post['login']) ?></a></p>
                        <p class="post-preview"><?= nl2br(h($post['text'])) ?></p>

                        <?php if (!empty($post['tags'])): ?>
                            <div class="tag-list">
                                <?php foreach (explode(',', $post['tags']) as $tag): ?>
                                    <?php $tag = trim($tag); ?>
                                    <?php if ($tag !== ''): ?>
                                        <a class="tag" href="index.php?tag=<?= rawurlencode($tag) ?>">#<?= h($tag) ?></a>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>

                        <a class="text-link" href="post.php?id=<?= (int)$post['id'] ?>">Открыть →</a>
                    </article>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endif; ?>
</div>

<script src="assets/app.js"></script>
</body>
</html>
