<?php

require_once __DIR__ . '/auth.php';

$action = (string)($_GET['action'] ?? '');

function input(string $name, mixed $default = ''): mixed
{
    return $_POST[$name] ?? $default;
}

function intInput(string $name): int
{
    return (int)input($name, 0);
}

function textInput(string $name, int $maxLength = 0): string
{
    $value = trim((string)input($name, ''));

    if ($maxLength > 0) {
        $value = mb_substr($value, 0, $maxLength);
    }

    return $value;
}

function getPost(int $postId): ?array
{
    $rows = callProcedure('CALL get_post_by_id(?)', [$postId]);
    return $rows[0] ?? null;
}

function getPostComments(int $postId): array
{
    return callProcedure('CALL get_comments(?)', [$postId]);
}

function getPostTags(int $postId): array
{
    return callProcedure('CALL get_post_tags(?)', [$postId]);
}

function getComment(int $commentId): ?array
{
    $rows = callProcedure('CALL get_comment_by_id(?)', [$commentId]);
    return $rows[0] ?? null;
}

switch ($action) {
    case 'logout':
        logoutUser();
        jsonResponse(true, 'Вы вышли из аккаунта');

    case 'create_post':
        requireLogin();

        $title = textInput('title', 255);
        $text = textInput('text');
        $private = (int)(bool)input('is_private', 0);
        $tags = textInput('tags', 500);

        if ($title === '' || $text === '') {
            jsonResponse(false, 'Заполните заголовок и текст');
        }

        try {
            $rows = callProcedure(
                'CALL create_post(?, ?, ?, ?, ?)',
                [userId(), $title, $text, $private, $tags]
            );

            $post = $rows[0] ?? null;
            $postId = (int)($post['id'] ?? 0);
            $secretCode = $post['secret_code'] ?? null;

            if ($postId <= 0) {
                jsonResponse(false, 'Пост создан, но его ID не найден');
            }

            $data = ['id' => $postId];

            if ($private && $secretCode) {
                $data['secret_code'] = $secretCode;
            }

            jsonResponse(
                true,
                $private
                    ? 'Приватный пост создан. Секретный код сгенерирован автоматически.'
                    : 'Пост создан',
                $data
            );
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось создать пост');
        }

    case 'edit_post':
        requireLogin();

        $postId = intInput('id');
        $title = textInput('title', 255);
        $text = textInput('text');
        $private = (int)(bool)input('is_private', 0);

        if ($postId <= 0 || $title === '' || $text === '') {
            jsonResponse(false, 'Некорректные данные');
        }

        try {
            $rows = callProcedure(
                'CALL edit_post(?, ?, ?, ?, ?)',
                [$postId, userId(), $title, $text, $private]
            );

            $updated = $rows[0] ?? null;

            if (!$updated) {
                jsonResponse(false, 'Пост не найден или у вас нет прав');
            }

            $data = [
                'id' => (int)$updated['id'],
                'is_private' => (int)$updated['is_private'],
            ];

            if ((int)$updated['is_private'] === 1 && !empty($updated['secret_code'])) {
                $data['secret_code'] = $updated['secret_code'];
            }

            jsonResponse(
                true,
                (int)$updated['is_private'] === 1 && !empty($updated['secret_code'])
                    ? 'Пост изменён. Секретный код: ' . $updated['secret_code']
                    : 'Пост изменён',
                $data
            );
        } catch (PDOException $e) {
            $message = ($e->errorInfo[1] ?? null) === 1644
                ? ($e->errorInfo[2] ?? 'Пост не найден')
                : 'Не удалось изменить пост';

            jsonResponse(false, $message);
        }

    case 'delete_post':
        requireLogin();

        $postId = intInput('id');

        if ($postId <= 0) {
            jsonResponse(false, 'Некорректный ID поста');
        }

        try {
            callProcedure('CALL delete_post(?, ?)', [$postId, userId()]);
            jsonResponse(true, 'Пост удалён');
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось удалить пост');
        }

    case 'subscribe':
    case 'unsubscribe':
        requireLogin();

        $followingId = intInput('user_id');

        if ($followingId <= 0) {
            jsonResponse(false, 'Некорректный пользователь');
        }

        $subscribe = $action === 'subscribe';

        try {
            $rows = callProcedure(
                'CALL toggle_subscription(?, ?, ?)',
                [userId(), $followingId, $subscribe ? 1 : 0]
            );

            $state = $rows[0] ?? null;

            if (!$state) {
                jsonResponse(false, 'Не удалось изменить подписку');
            }

            jsonResponse(
                true,
                (int)$state['is_following'] === 1
                    ? 'Подписка оформлена'
                    : 'Вы отписались от пользователя',
                [
                    'user_id' => (int)$state['user_id'],
                    'is_following' => (int)$state['is_following'],
                    'followers_count' => (int)$state['followers_count'],
                    'following_count' => (int)$state['following_count'],
                ]
            );
        } catch (PDOException $e) {
            jsonResponse(
                false,
                ($e->errorInfo[2] ?? '') !== ''
                    ? $e->errorInfo[2]
                    : 'Не удалось изменить подписку'
            );
        }

    case 'comment':
        requireLogin();

        $postId = intInput('post_id');
        $text = textInput('text');
        $secretCode = textInput('secret_code', 64);

        if ($postId <= 0 || $text === '') {
            jsonResponse(false, 'Комментарий не может быть пустым');
        }

        try {
            $post = getPost($postId);

            if (!$post) {
                jsonResponse(false, 'Пост не найден');
            }

            if ((int)$post['is_private'] === 1) {
                $isOwner = isLoggedIn() && (int)$post['user_id'] === userId();
                $hasValidCode = $secretCode !== ''
                    && !empty($post['secret_code'])
                    && hash_equals((string)$post['secret_code'], $secretCode);

                if (!$isOwner && !$hasValidCode) {
                    jsonResponse(false, 'Это приватный пост');
                }
            }

            callProcedure('CALL add_comment(?, ?, ?)', [$postId, userId(), $text]);
            jsonResponse(true, 'Комментарий добавлен');
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось добавить комментарий');
        }

    case 'edit_comment':
        requireLogin();

        $commentId = intInput('id');
        $text = textInput('text');

        if ($commentId <= 0 || $text === '') {
            jsonResponse(false, 'Некорректные данные');
        }

        try {
            $comment = getComment($commentId);

            if (!$comment) {
                jsonResponse(false, 'Комментарий не найден');
            }

            if ((int)$comment['user_id'] !== userId()) {
                jsonResponse(false, 'Недостаточно прав');
            }

            callProcedure('CALL edit_comment(?, ?, ?)', [$commentId, userId(), $text]);
            jsonResponse(true, 'Комментарий изменён');
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось изменить комментарий');
        }

    case 'delete_comment':
        requireLogin();

        $commentId = intInput('id');

        if ($commentId <= 0) {
            jsonResponse(false, 'Некорректный ID комментария');
        }

        try {
            $comment = getComment($commentId);

            if (!$comment) {
                jsonResponse(false, 'Комментарий не найден');
            }

            if ((int)$comment['user_id'] !== userId()) {
                jsonResponse(false, 'Недостаточно прав');
            }

            callProcedure('CALL delete_comment(?, ?)', [$commentId, userId()]);
            jsonResponse(true, 'Комментарий удалён');
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось удалить комментарий');
        }

    case 'feed':
        requireLogin();

        try {
            $posts = callProcedure('CALL get_feed(?)', [userId()]);
            jsonResponse(true, 'Лента получена', ['posts' => $posts]);
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось получить ленту');
        }

    case 'public_posts':
        try {
            $posts = callProcedure('CALL get_public_posts()');
            jsonResponse(true, 'Публичные посты получены', ['posts' => $posts]);
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось получить посты');
        }

    case 'posts_by_tag':
        $tag = textInput('tag', 50);

        if ($tag === '') {
            jsonResponse(false, 'Укажите тег');
        }

        try {
            $posts = callProcedure('CALL get_posts_by_tag(?)', [$tag]);
            jsonResponse(true, 'Посты по тегу получены', ['posts' => $posts]);
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось получить посты');
        }

    case 'secret_post':
        $code = textInput('code', 64);

        if ($code === '') {
            jsonResponse(false, 'Введите секретный код');
        }

        try {
            $posts = callProcedure('CALL get_secret_post(?)', [$code]);

            if (!$posts) {
                jsonResponse(false, 'Пост с таким кодом не найден');
            }

            $post = $posts[0];

            jsonResponse(true, 'Пост найден', [
                'post' => $post,
                'comments' => getPostComments((int)$post['id']),
                'tags' => getPostTags((int)$post['id']),
            ]);
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось получить пост');
        }

    case 'user_profile':
        $profileId = intInput('user_id');

        if ($profileId <= 0) {
            jsonResponse(false, 'Некорректный пользователь');
        }

        try {
            $rows = callProcedure(
                'CALL get_user_profile(?, ?)',
                [$profileId, userId()]
            );

            if (!$rows) {
                jsonResponse(false, 'Пользователь не найден');
            }

            $posts = callProcedure('CALL get_user_public_posts(?)', [$profileId]);

            jsonResponse(true, 'Профиль получен', [
                'user' => $rows[0],
                'posts' => $posts,
            ]);
        } catch (PDOException $e) {
            jsonResponse(false, 'Не удалось получить профиль');
        }

    default:
        jsonResponse(false, 'Неизвестное действие');
}
