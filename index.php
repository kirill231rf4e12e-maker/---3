<?php

require_once __DIR__ . '/auth.php';

$initialTag = trim((string)($_GET['tag'] ?? ''));
$publicPosts = [];
$feed = [];

try {
    $publicPosts = callProcedure('CALL get_public_posts()');

    if (isLoggedIn()) {
        $feed = callProcedure('CALL get_feed(?)', [userId()]);
    }
} catch (PDOException $e) {
    $publicPosts = [];
    $feed = [];
}
?>
<!doctype html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Мой блог</title>
    <link rel="stylesheet" href="assets/css/base.css">
    <link rel="stylesheet" href="assets/css/index.css">
</head>
<body class="site-body" data-initial-tag="<?= h($initialTag) ?>">
<div class="page-shell">
    <header class="site-header">
        <div>
            <p class="eyebrow">БЛОГ</p>
            <h1>Мой блог</h1>
            <p class="muted">Публикации, подписки и приватные записи в одном месте.</p>
        </div>

        <nav class="header-actions">
            <?php if (isLoggedIn()): ?>
                <span class="user-chip">@<?= h(currentLogin()) ?></span>
                <a class="button button--ghost" href="login.php?logout=1">Выйти</a>
            <?php else: ?>
                <a class="button button--ghost" href="login.php">Войти</a>
                <a class="button button--primary" href="register.php">Регистрация</a>
            <?php endif; ?>
        </nav>
    </header>

    <?php if (isLoggedIn()): ?>
        <section class="dashboard-grid">
            <div class="content-column">
                <section class="panel">
                    <div class="section-heading">
                        <div>
                            <p class="eyebrow">ПУБЛИКАЦИЯ</p>
                            <h2>Создать пост</h2>
                        </div>
                    </div>

                    <form id="create-post-form" class="form-stack">
                        <label class="field">
                            <span class="field__label">Заголовок</span>
                            <input class="input" type="text" name="title" placeholder="О чём ваш пост?" maxlength="255" required>
                        </label>

                        <label class="field">
                            <span class="field__label">Текст</span>
                            <textarea class="input textarea" name="text" placeholder="Напишите что-нибудь интересное..." required></textarea>
                        </label>

                        <div class="inline-fields">
                            <label class="checkbox-field">
                                <input type="checkbox" name="is_private" value="1" id="private-checkbox">
                                <span>Приватный пост</span>
                            </label>

                            <div id="private-code-hint" class="field-note is-hidden">
                                Код доступа будет сгенерирован автоматически после публикации и показан только вам.
                            </div>
                        </div>

                        <label class="field">
                            <span class="field__label">Теги</span>
                            <input class="input" type="text" name="tags" maxlength="500" placeholder="php, учеба, программирование">
                            <small class="field__hint">Разделяйте несколько тегов запятыми.</small>
                        </label>

                        <button class="button button--primary" type="submit">Опубликовать</button>
                    </form>

                    <div id="create-result" class="result"></div>
                </section>

                <section class="panel">
                    <div class="section-heading">
                        <div>
                            <p class="eyebrow">ПОДПИСКИ</p>
                            <h2>Моя лента</h2>
                        </div>
                        <button class="button button--ghost" type="button" onclick="loadFeed()">Обновить</button>
                    </div>

                    <div id="feed">
                        <?php if (!$feed): ?>
                            <div class="empty-state">Лента пока пустая.</div>
                        <?php endif; ?>

                        <?php foreach ($feed as $post): ?>
                            <article class="post-card">
                                <div class="post-card__top">
                                    <div>
                                        <h3><?= h($post['title']) ?></h3>
                                        <p class="post-meta">Автор: <a class="author-link" href="user.php?id=<?= (int)$post['user_id'] ?>">@<?= h($post['login']) ?></a></p>
                                    </div>
                                </div>
                                <p class="post-preview"><?= nl2br(h($post['text'])) ?></p>
                                <?php if (!empty($post['tags'])): ?>
                                    <div class="tag-list">
                                        <?php foreach (explode(',', $post['tags']) as $tag): ?>
                                            <?php $tag = trim($tag); ?>
                                            <?php if ($tag !== ""): ?>
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
            </div>
        </section>
    <?php endif; ?>

    <section class="panel">
        <div class="section-heading">
            <div>
                <p class="eyebrow">ПУБЛИКАЦИИ</p>
                <h2>Публичные посты</h2>
            </div>
            <button class="button button--ghost" type="button" onclick="loadPublicPosts()">Обновить</button>
        </div>

        <div id="public-posts" class="posts-grid">
            <?php if (!$publicPosts): ?>
                <div class="empty-state">Публичных постов пока нет.</div>
            <?php endif; ?>

            <?php foreach ($publicPosts as $post): ?>
                <article class="post-card">
                    <div class="post-card__top">
                        <div>
                            <h3><?= h($post['title']) ?></h3>
                            <p class="post-meta">Автор: <a class="author-link" href="user.php?id=<?= (int)$post['user_id'] ?>">@<?= h($post['login']) ?></a></p>
                        </div>
                    </div>
                    <p class="post-preview"><?= nl2br(h($post['text'])) ?></p>
                    <?php if (!empty($post['tags'])): ?>
                        <div class="tag-list">
                            <?php foreach (explode(',', $post['tags']) as $tag): ?>
                                <?php $tag = trim($tag); ?>
                                <?php if ($tag !== ""): ?>
                                    <a class="tag" href="index.php?tag=<?= rawurlencode($tag) ?>">#<?= h($tag) ?></a>
                                <?php endif; ?>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                    <div class="post-actions">
                        <a class="button button--small button--ghost" href="post.php?id=<?= (int)$post['id'] ?>">Открыть</a>
                        <?php if ((int)$post['user_id'] !== userId()): ?>
                            <button class="button button--small button--secondary" type="button" onclick="subscribe(<?= (int)$post['user_id'] ?>)">Подписаться</button>
                        <?php endif; ?>
                    </div>
                </article>
            <?php endforeach; ?>
        </div>
    </section>

    <section class="tools-grid">
        <section class="panel">
            <div class="section-heading">
                <div>
                    <p class="eyebrow">ТЕГИ</p>
                    <h2>Поиск по тегу</h2>
                </div>
            </div>

            <form id="tag-form" class="inline-form">
                <input class="input" type="text" name="tag" maxlength="50" placeholder="Например: php" required>
                <button class="button button--primary" type="submit">Найти</button>
            </form>

            <div id="tag-results" class="stack-list"></div>
        </section>

        <section class="panel">
            <div class="section-heading">
                <div>
                    <p class="eyebrow">ПРИВАТНЫЙ ДОСТУП</p>
                    <h2>Открыть приватный пост</h2>
                </div>
            </div>

            <form id="secret-form" class="inline-form">
                <input class="input" type="text" name="code" maxlength="64" placeholder="Секретный код" required>
                <button class="button button--primary" type="submit">Открыть</button>
            </form>

            <div id="secret-result" class="stack-list"></div>
        </section>
    </section>

    </div>

<script src="assets/app.js"></script>
</body>
</html>
