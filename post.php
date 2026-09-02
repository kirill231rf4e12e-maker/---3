<?php

require_once __DIR__ . '/auth.php';

$post = null;
$comments = [];
$tags = [];
$error = '';

$postId = isset($_GET['id']) ? (int)$_GET['id'] : 0;
$secretCode = trim((string)($_GET['code'] ?? ''));

try {
    if ($postId > 0) {
        $result = callProcedure('CALL get_post_by_id(?)', [$postId]);
        $post = $result[0] ?? null;

        if (!$post) {
            $error = 'Пост не найден';
        } elseif (
            (int)$post['is_private'] === 1
            && !(
                isLoggedIn()
                && (int)$post['user_id'] === userId()
            )
        ) {
            $error = 'Этот пост приватный. Используйте секретный код.';
            $post = null;
        }
    } elseif ($secretCode !== '') {
        $result = callProcedure('CALL get_secret_post(?)', [$secretCode]);
        $post = $result[0] ?? null;

        if (!$post) {
            $error = 'Пост с таким секретным кодом не найден';
        }
    } else {
        $error = 'Пост не указан';
    }

    if ($post) {
        $postId = (int)$post['id'];
        $comments = callProcedure('CALL get_comments(?)', [$postId]);
        $tags = callProcedure('CALL get_post_tags(?)', [$postId]);
    }
} catch (PDOException $e) {
    $error = 'Ошибка базы данных';
}
?>
<!doctype html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= $post ? h($post['title']) : 'Пост' ?></title>
    <link rel="stylesheet" href="assets/css/base.css">
    <link rel="stylesheet" href="assets/css/post.css">
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

        <?php if (!$post): ?>
            <section class="panel">
                <h2>Открыть по секретному коду</h2>
                <form method="get" class="inline-form">
                    <input class="input" type="text" name="code" maxlength="64" placeholder="Секретный код">
                    <button class="button button--primary" type="submit">Открыть</button>
                </form>
            </section>
        <?php endif; ?>
    <?php endif; ?>

    <?php if ($post): ?>
        <article class="post-detail <?= (int)$post['is_private'] ? 'post-detail--private' : '' ?>">
            <div class="post-detail__header">
                <div>
                    <span class="post-badge <?= (int)$post['is_private'] ? 'post-badge--private' : '' ?>">
                        <?= (int)$post['is_private'] ? 'Приватный пост' : 'Публичный пост' ?>
                    </span>
                    <h1><?= h($post['title']) ?></h1>
                    <p class="post-meta">Автор: <a class="author-link" href="user.php?id=<?= (int)$post['user_id'] ?>">@<?= h($post['login']) ?></a></p>
                </div>
            </div>

            <?php if ((int)$post['is_private'] === 1 && isLoggedIn() && (int)$post['user_id'] === userId() && !empty($post['secret_code'])): ?>
                <div class="secret-code-box">
                    <span class="secret-code-box__label">Ваш секретный код</span>
                    <code id="owner-secret-code"><?= h($post['secret_code']) ?></code>
                    <button class="button button--tiny button--ghost" type="button" onclick="copySecretCode()">Скопировать</button>
                </div>
            <?php endif; ?>

            <div class="post-content"><?= nl2br(h($post['text'])) ?></div>

            <?php if ($tags): ?>
                <div class="tag-list">
                    <?php foreach ($tags as $tag): ?>
                        <a class="tag" href="index.php">#<?= h($tag['name']) ?></a>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>

            <?php if (isLoggedIn() && (int)$post['user_id'] === userId()): ?>
                <div class="editor-box">
                    <div class="section-heading">
                        <div>
                            <p class="eyebrow">АВТОР</p>
                            <h2>Редактирование</h2>
                        </div>
                    </div>

                    <form id="edit-post-form" class="form-stack">
                        <input type="hidden" name="id" value="<?= (int)$post['id'] ?>">

                        <label class="field">
                            <span class="field__label">Заголовок</span>
                            <input class="input" type="text" name="title" value="<?= h($post['title']) ?>" maxlength="255" required>
                        </label>

                        <label class="field">
                            <span class="field__label">Текст</span>
                            <textarea class="input textarea" name="text" required><?= h($post['text']) ?></textarea>
                        </label>

                        <label class="checkbox-field">
                            <input type="checkbox" name="is_private" value="1" <?= (int)$post['is_private'] ? 'checked' : '' ?>>
                            <span>Приватный пост</span>
                        </label>

                        <div class="button-row">
                            <button class="button button--primary" type="submit">Сохранить</button>
                            <button class="button button--danger" type="button" onclick="deletePost(<?= (int)$post['id'] ?>)">Удалить</button>
                        </div>
                    </form>

                    <div id="edit-result" class="result"></div>
                </div>
            <?php endif; ?>
        </article>

        <section class="panel comments-panel">
            <div class="section-heading">
                <div>
                    <p class="eyebrow">ОБСУЖДЕНИЕ</p>
                    <h2>Комментарии</h2>
                </div>
                <span class="count-badge"><?= count($comments) ?></span>
            </div>

            <div id="comments" class="comments-list">
                <?php if (!$comments): ?>
                    <div class="empty-state">Комментариев пока нет.</div>
                <?php endif; ?>

                <?php foreach ($comments as $comment): ?>
                    <article class="comment-card">
                        <div class="comment-card__header">
                            <strong>@<?= h($comment['login']) ?></strong>
                            <?php if (isLoggedIn() && (int)$comment['user_id'] === userId()): ?>
                                <div class="button-row button-row--small">
                                    <button
                                        class="button button--tiny button--ghost"
                                        type="button"
                                        onclick="editComment(<?= (int)$comment['id'] ?>, <?= htmlspecialchars(json_encode($comment['text'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), ENT_QUOTES, 'UTF-8') ?>)"
                                    >
                                        Изменить
                                    </button>
                                    <button
                                        class="button button--tiny button--danger"
                                        type="button"
                                        onclick="deleteComment(<?= (int)$comment['id'] ?>, <?= (int)$post['id'] ?>)"
                                    >
                                        Удалить
                                    </button>
                                </div>
                            <?php endif; ?>
                        </div>
                        <p><?= nl2br(h($comment['text'])) ?></p>
                    </article>
                <?php endforeach; ?>
            </div>

            <?php if (isLoggedIn()): ?>
                <form id="comment-form" class="comment-form">
                    <input type="hidden" name="post_id" value="<?= (int)$post['id'] ?>">
                    <input type="hidden" name="secret_code" value="<?= h($secretCode) ?>">
                    <label class="field">
                        <span class="field__label">Ваш комментарий</span>
                        <textarea class="input textarea textarea--small" name="text" placeholder="Написать комментарий..." required></textarea>
                    </label>
                    <button class="button button--primary" type="submit">Добавить комментарий</button>
                </form>
                <div id="comment-result" class="result"></div>
            <?php else: ?>
                <div class="login-hint">
                    <a href="login.php">Войдите</a>, чтобы оставлять комментарии.
                </div>
            <?php endif; ?>
        </section>
    <?php endif; ?>
</div>

<script src="assets/app.js"></script>
</body>
</html>
