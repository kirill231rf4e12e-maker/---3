-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Sep 02, 2026 at 04:34 PM
-- Server version: 8.4.3
-- PHP Version: 8.3.16

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `the_blog`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_comment` (IN `p_post` INT, IN `p_user` INT, IN `p_text` TEXT)   BEGIN
    INSERT INTO comments(post_id, user_id, text)
    VALUES (p_post, p_user, p_text);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `create_post` (IN `p_user_id` INT, IN `p_title` VARCHAR(255), IN `p_text` TEXT, IN `p_private` BOOLEAN, IN `p_tags` TEXT)   BEGIN
    DECLARE v_post_id INT DEFAULT 0;
    DECLARE v_secret_code VARCHAR(64) DEFAULT NULL;
    DECLARE v_tag_name VARCHAR(50);
    DECLARE v_tag_id INT DEFAULT 0;
    DECLARE v_rest TEXT;
    DECLARE v_comma INT DEFAULT 0;
    DECLARE v_code_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_private = 1 THEN
        code_loop: LOOP
            SET v_secret_code = CONCAT('private-', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12)));

            SELECT COUNT(*) INTO v_code_exists
            FROM posts
            WHERE secret_code = v_secret_code;

            IF v_code_exists = 0 THEN
                LEAVE code_loop;
            END IF;
        END LOOP;
    END IF;

    START TRANSACTION;

    INSERT INTO posts(user_id, title, text, is_private, secret_code)
    VALUES (p_user_id, TRIM(p_title), p_text, p_private, v_secret_code);

    SET v_post_id = LAST_INSERT_ID();
    SET v_rest = COALESCE(p_tags, '');

    WHILE TRIM(v_rest) <> '' DO
        SET v_comma = LOCATE(',', v_rest);

        IF v_comma = 0 THEN
            SET v_tag_name = TRIM(v_rest);
            SET v_rest = '';
        ELSE
            SET v_tag_name = TRIM(SUBSTRING(v_rest, 1, v_comma - 1));
            SET v_rest = TRIM(SUBSTRING(v_rest, v_comma + 1));
        END IF;

        SET v_tag_name = LEFT(v_tag_name, 50);

        IF v_tag_name <> '' THEN
            INSERT INTO tags(name)
            VALUES (v_tag_name)
            ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);

            SET v_tag_id = LAST_INSERT_ID();

            INSERT IGNORE INTO post_tags(post_id, tag_id)
            VALUES (v_post_id, v_tag_id);
        END IF;
    END WHILE;

    COMMIT;

    SELECT v_post_id AS id, v_secret_code AS secret_code;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `delete_comment` (IN `p_comment` INT, IN `p_user` INT)   BEGIN
    DELETE FROM comments
    WHERE id = p_comment AND user_id = p_user;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `delete_post` (IN `p_post_id` INT, IN `p_user_id` INT)   BEGIN
    DELETE FROM posts
    WHERE id = p_post_id AND user_id = p_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `edit_comment` (IN `p_comment` INT, IN `p_user` INT, IN `p_text` TEXT)   BEGIN
    UPDATE comments
    SET text = p_text
    WHERE id = p_comment AND user_id = p_user;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `edit_post` (IN `p_post_id` INT, IN `p_user_id` INT, IN `p_title` VARCHAR(255), IN `p_text` TEXT, IN `p_private` BOOLEAN)   BEGIN
    DECLARE v_secret_code VARCHAR(64) DEFAULT NULL;
    DECLARE v_code_exists INT DEFAULT 0;
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*), MAX(secret_code)
    INTO v_exists, v_secret_code
    FROM posts
    WHERE id = p_post_id
      AND user_id = p_user_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Пост не найден';
    END IF;

    IF p_private = 1 AND (v_secret_code IS NULL OR TRIM(v_secret_code) = '') THEN
        code_loop: LOOP
            SET v_secret_code = CONCAT('private-', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12)));

            SELECT COUNT(*) INTO v_code_exists
            FROM posts
            WHERE secret_code = v_secret_code;

            IF v_code_exists = 0 THEN
                LEAVE code_loop;
            END IF;
        END LOOP;
    END IF;

    IF p_private = 0 THEN
        SET v_secret_code = NULL;
    END IF;

    UPDATE posts
    SET title = TRIM(p_title),
        text = p_text,
        is_private = p_private,
        secret_code = v_secret_code
    WHERE id = p_post_id
      AND user_id = p_user_id;

    SELECT id, is_private, secret_code
    FROM posts
    WHERE id = p_post_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_comments` (IN `p_post_id` INT)   BEGIN
    SELECT c.id, c.post_id, c.user_id, c.text, c.created_at, u.login
    FROM comments c
    INNER JOIN users u ON u.id = c.user_id
    WHERE c.post_id = p_post_id
    ORDER BY c.created_at ASC, c.id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_comment_by_id` (IN `p_comment_id` INT)   BEGIN
    SELECT id, post_id, user_id, text, created_at
    FROM comments
    WHERE id = p_comment_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_feed` (IN `p_user` INT)   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login,
           COALESCE(GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ','), '') AS tags
    FROM posts p
    INNER JOIN subscriptions s ON s.following_id = p.user_id
    INNER JOIN users u ON u.id = p.user_id
    LEFT JOIN post_tags pt ON pt.post_id = p.id
    LEFT JOIN tags t ON t.id = pt.tag_id
    WHERE s.follower_id = p_user
      AND p.is_private = 0
    GROUP BY p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login
    ORDER BY p.created_at DESC, p.id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_posts_by_tag` (IN `p_tag` VARCHAR(50))   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login,
           COALESCE(GROUP_CONCAT(DISTINCT all_tags.name ORDER BY all_tags.name SEPARATOR ','), '') AS tags
    FROM posts p
    INNER JOIN users u ON u.id = p.user_id
    INNER JOIN post_tags match_pt ON match_pt.post_id = p.id
    INNER JOIN tags match_t ON match_t.id = match_pt.tag_id
    LEFT JOIN post_tags all_pt ON all_pt.post_id = p.id
    LEFT JOIN tags all_tags ON all_tags.id = all_pt.tag_id
    WHERE p.is_private = 0
      AND match_t.name = TRIM(p_tag)
    GROUP BY p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login
    ORDER BY p.created_at DESC, p.id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_post_by_id` (IN `p_post_id` INT)   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login
    FROM posts p
    INNER JOIN users u ON u.id = p.user_id
    WHERE p.id = p_post_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_post_tags` (IN `p_post_id` INT)   BEGIN
    SELECT t.id, t.name
    FROM tags t
    INNER JOIN post_tags pt ON pt.tag_id = t.id
    WHERE pt.post_id = p_post_id
    ORDER BY t.name ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_public_posts` ()   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login,
           COALESCE(GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ','), '') AS tags
    FROM posts p
    INNER JOIN users u ON u.id = p.user_id
    LEFT JOIN post_tags pt ON pt.post_id = p.id
    LEFT JOIN tags t ON t.id = pt.tag_id
    WHERE p.is_private = 0
    GROUP BY p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login
    ORDER BY p.created_at DESC, p.id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_secret_post` (IN `p_code` VARCHAR(64))   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, p.secret_code, u.login
    FROM posts p
    INNER JOIN users u ON u.id = p.user_id
    WHERE p.secret_code = TRIM(p_code)
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_for_login` (IN `p_login` VARCHAR(50))   BEGIN
    SELECT id, login, password
    FROM users
    WHERE login = TRIM(p_login)
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_profile` (IN `p_user_id` INT, IN `p_viewer_id` INT)   BEGIN
    SELECT u.id, u.login, u.created_at,
           (SELECT COUNT(*) FROM posts p1 WHERE p1.user_id = u.id AND p1.is_private = 0) AS public_posts_count,
           (SELECT COUNT(*) FROM subscriptions s1 WHERE s1.following_id = u.id) AS followers_count,
           (SELECT COUNT(*) FROM subscriptions s2 WHERE s2.follower_id = u.id) AS following_count,
           CASE
               WHEN p_viewer_id IS NULL OR p_viewer_id = u.id THEN 0
               WHEN EXISTS (
                   SELECT 1 FROM subscriptions sx
                   WHERE sx.follower_id = p_viewer_id AND sx.following_id = u.id
               ) THEN 1
               ELSE 0
           END AS is_following
    FROM users u
    WHERE u.id = p_user_id
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_public_posts` (IN `p_user_id` INT)   BEGIN
    SELECT p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, u.login,
           COALESCE(GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ','), '') AS tags
    FROM posts p
    INNER JOIN users u ON u.id = p.user_id
    LEFT JOIN post_tags pt ON pt.post_id = p.id
    LEFT JOIN tags t ON t.id = pt.tag_id
    WHERE p.user_id = p_user_id
      AND p.is_private = 0
    GROUP BY p.id, p.user_id, p.title, p.text, p.is_private, p.created_at, u.login
    ORDER BY p.created_at DESC, p.id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `register_user` (IN `p_login` VARCHAR(50), IN `p_password` VARCHAR(255))   BEGIN
    INSERT INTO users(login, password)
    VALUES (TRIM(p_login), p_password);

    SELECT id, login
    FROM users
    WHERE id = LAST_INSERT_ID()
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `subscribe_user` (IN `p_follower` INT, IN `p_following` INT)   BEGIN
    IF p_follower = p_following THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Нельзя подписаться на самого себя';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_following) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Пользователь не найден';
    END IF;

    INSERT IGNORE INTO subscriptions(follower_id, following_id)
    VALUES (p_follower, p_following);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `toggle_subscription` (IN `p_follower` INT, IN `p_following` INT, IN `p_subscribe` TINYINT)   BEGIN
    IF p_follower = p_following THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Нельзя подписаться на самого себя';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_following) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Пользователь не найден';
    END IF;

    IF p_subscribe = 1 THEN
        INSERT IGNORE INTO subscriptions(follower_id, following_id)
        VALUES (p_follower, p_following);
    ELSE
        DELETE FROM subscriptions
        WHERE follower_id = p_follower
          AND following_id = p_following;
    END IF;

    SELECT
        p_following AS user_id,
        EXISTS (
            SELECT 1 FROM subscriptions
            WHERE follower_id = p_follower
              AND following_id = p_following
        ) AS is_following,
        (SELECT COUNT(*) FROM subscriptions WHERE following_id = p_following) AS followers_count,
        (SELECT COUNT(*) FROM subscriptions WHERE follower_id = p_following) AS following_count;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `unsubscribe_user` (IN `p_follower` INT, IN `p_following` INT)   BEGIN
    IF p_follower = p_following THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Нельзя отписаться от самого себя';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_following) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Пользователь не найден';
    END IF;

    DELETE FROM subscriptions
    WHERE follower_id = p_follower
      AND following_id = p_following;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `comments`
--

CREATE TABLE `comments` (
  `id` int NOT NULL,
  `post_id` int NOT NULL,
  `user_id` int NOT NULL,
  `text` text NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `comments`
--

INSERT INTO `comments` (`id`, `post_id`, `user_id`, `text`, `created_at`) VALUES
(3, 7, 1, 'Вау, очень полезная информация!)', '2026-09-02 16:04:03');

-- --------------------------------------------------------

--
-- Table structure for table `posts`
--

CREATE TABLE `posts` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `title` varchar(255) NOT NULL,
  `text` text NOT NULL,
  `is_private` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `secret_code` varchar(64) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `posts`
--

INSERT INTO `posts` (`id`, `user_id`, `title`, `text`, `is_private`, `created_at`, `secret_code`) VALUES
(1, 1, 'Основы программирования', 'Программирование позволяет создавать программы, которые решают различные задачи. Важными базовыми понятиями являются переменные, условия, циклы и функции.', 0, '2026-08-27 17:45:41', NULL),
(2, 1, 'Что такое алгоритм', 'Алгоритм представляет собой последовательность действий, которая приводит к решению определённой задачи. Хороший алгоритм должен быть понятным и однозначным.', 0, '2026-08-27 17:45:41', NULL),
(3, 1, 'Зачем нужны комментарии в коде', 'Комментарии помогают разработчику понять назначение сложных участков программы. Особенно полезны они при работе над большим проектом вместе с другими разработчиками.', 0, '2026-08-27 17:45:41', NULL),
(4, 1, 'Первое знакомство с базами данных', 'База данных предназначена для хранения структурированной информации. Таблицы позволяют удобно организовывать данные и связывать их между собой.', 0, '2026-08-27 17:45:41', NULL),
(5, 1, 'Почему важно тестировать программы', 'Тестирование помогает обнаруживать ошибки до того, как программа попадёт к пользователям. Даже небольшие проекты полезно проверять после внесения изменений.', 0, '2026-08-27 17:45:41', NULL),
(6, 1, 'Личные заметки по проекту', 'Это приватная заметка User1 для проверки механизма приватных публикаций. Пост предназначен только для доступа по секретному коду.', 1, '2026-08-27 17:45:41', 'private-1F37F469A23F'),
(7, 2, 'Как работает HTTP', 'HTTP используется для обмена данными между клиентом и сервером. Браузер отправляет запрос, а сервер формирует и возвращает ответ.', 0, '2026-08-27 17:45:41', NULL),
(8, 2, 'Что такое API', 'API представляет собой интерфейс, с помощью которого одна программа может взаимодействовать с другой. В веб-разработке часто используются HTTP API.', 0, '2026-08-27 17:45:41', NULL),
(9, 2, 'Основы HTML', 'HTML используется для создания структуры веб-страницы. С помощью различных элементов можно определить заголовки, абзацы, списки, изображения и другие компоненты.', 0, '2026-08-27 17:45:41', NULL),
(10, 2, 'Для чего нужен CSS', 'CSS отвечает за внешний вид веб-страницы. С его помощью можно изменять размеры, отступы, расположение и другие визуальные свойства элементов.', 0, '2026-08-27 17:45:41', NULL),
(11, 2, 'Что такое JavaScript', 'JavaScript позволяет добавлять интерактивность веб-страницам. Он может изменять содержимое страницы, реагировать на действия пользователя и обращаться к API.', 0, '2026-08-27 17:45:41', NULL),
(12, 2, 'Приватная заметка о веб-проекте', 'Учебная приватная запись User2. Используется для проверки получения публикации по секретному коду.', 1, '2026-08-27 17:45:41', 'private-1F40100EA23F'),
(13, 3, 'Что такое переменная', 'Переменная используется для хранения значения, которое может изменяться во время выполнения программы. Тип переменной зависит от используемого языка программирования.', 0, '2026-08-27 17:45:41', NULL),
(14, 3, 'Условия в программах', 'Условные конструкции позволяют программе выполнять разные действия в зависимости от определённых условий. Чаще всего для этого используются конструкции if и else.', 0, '2026-08-27 17:45:41', NULL),
(15, 3, 'Циклы', 'Циклы позволяют повторять определённый блок инструкций несколько раз. Это особенно удобно при обработке коллекций и выполнении повторяющихся операций.', 0, '2026-08-27 17:45:41', NULL),
(16, 3, 'Функции', 'Функция объединяет определённый набор действий и позволяет повторно использовать его в программе. Использование функций делает код более структурированным.', 0, '2026-08-27 17:45:41', NULL),
(17, 3, 'Структура хорошего проекта', 'Разделение программы на логические модули помогает поддерживать порядок в коде. Большой проект удобнее сопровождать, когда разные части системы находятся в отдельных файлах.', 0, '2026-08-27 17:45:41', NULL),
(18, 3, 'Личная учебная заметка', 'Приватная учебная запись User3 для проверки секретных публикаций и доступа к ним по специальному коду.', 1, '2026-08-27 17:45:41', 'private-1F489AACA23F'),
(19, 4, 'Что такое SQL', 'SQL используется для работы с реляционными базами данных. С его помощью можно создавать структуру базы и выполнять различные операции с данными.', 0, '2026-08-27 17:45:41', NULL),
(20, 4, 'Таблицы в базе данных', 'Таблица состоит из строк и столбцов. Каждая строка обычно представляет отдельную запись, а столбцы описывают свойства этой записи.', 0, '2026-08-27 17:45:41', NULL),
(21, 4, 'Первичный ключ', 'Первичный ключ позволяет однозначно идентифицировать запись в таблице. Обычно для этого используется уникальный идентификатор.', 0, '2026-08-27 17:45:41', NULL),
(22, 4, 'Связи между таблицами', 'В реляционных базах данных таблицы могут быть связаны между собой. Для этого используются внешние ключи и различные типы связей.', 0, '2026-08-27 17:45:41', NULL),
(23, 4, 'Почему важны индексы', 'Индексы позволяют ускорить поиск данных в таблицах. Однако большое количество индексов также увеличивает стоимость операций изменения данных.', 0, '2026-08-27 17:45:41', NULL),
(24, 4, 'Приватная заметка User4', 'Учебная приватная публикация для проверки работы секретных ссылок и приватных постов.', 1, '2026-08-27 17:45:41', 'private-1F50FD45A23F'),
(25, 5, 'Основы Git', 'Git используется для контроля версий. Он позволяет сохранять историю изменений проекта и возвращаться к предыдущим версиям файлов.', 0, '2026-08-27 17:45:41', NULL),
(26, 5, 'Что такое commit', 'Commit фиксирует набор изменений в репозитории. Хорошие сообщения коммитов помогают понять историю разработки проекта.', 0, '2026-08-27 17:45:41', NULL),
(27, 5, 'Ветвление в Git', 'Ветки позволяют разработчикам работать над разными изменениями независимо друг от друга. После завершения работы изменения можно объединить.', 0, '2026-08-27 17:45:41', NULL),
(28, 5, 'Зачем нужен README', 'README помогает новым участникам проекта быстро понять его назначение, структуру и способы запуска. Для открытых проектов такой файл особенно полезен.', 0, '2026-08-27 17:45:41', NULL),
(29, 5, 'Документирование проекта', 'Хорошая документация экономит время при дальнейшем сопровождении проекта. В документации можно описать установку, настройки и основные возможности программы.', 0, '2026-08-27 17:45:41', NULL),
(30, 5, 'Приватные заметки проекта', 'Приватная учебная запись User5. Используется для тестирования механизма секретных кодов.', 1, '2026-08-27 17:45:41', 'private-1F59B4B6A23F'),
(31, 6, 'Что такое сервер', 'Сервер — это система, которая предоставляет определённые ресурсы или услуги другим устройствам. В веб-разработке сервер обычно обрабатывает запросы клиентов.', 0, '2026-08-27 17:45:41', NULL),
(32, 6, 'Клиент и сервер', 'Клиент отправляет запрос серверу, после чего сервер обрабатывает его и возвращает результат. Такая модель используется во многих современных приложениях.', 0, '2026-08-27 17:45:41', NULL),
(33, 6, 'Что такое JSON', 'JSON — популярный текстовый формат обмена структурированными данными. Он часто используется при взаимодействии веб-клиента с API.', 0, '2026-08-27 17:45:41', NULL),
(34, 6, 'Основы безопасности веб-приложений', 'При разработке веб-приложений важно проверять входные данные, правильно работать с паролями и ограничивать доступ к защищённым операциям.', 0, '2026-08-27 17:45:41', NULL),
(35, 6, 'Пароли и хеширование', 'Пароли пользователей не следует хранить в базе данных в открытом виде. Для их защиты применяются специальные алгоритмы хеширования.', 0, '2026-08-27 17:45:41', NULL),
(36, 6, 'Приватная учебная заметка', 'Приватная публикация User6 для проверки получения поста по секретному коду.', 1, '2026-08-27 17:45:41', 'private-1F6876A0A23F'),
(41, 6, 'екуекуе', 'еукеку', 1, '2026-08-27 18:41:13', 'private-E0F46CC0A246'),
(42, 1, 'Приватный пост', 'Текст Текст Текст Текст Текст Текст', 1, '2026-09-02 15:47:51', 'private-A7A03B15A6E5');

-- --------------------------------------------------------

--
-- Table structure for table `post_tags`
--

CREATE TABLE `post_tags` (
  `post_id` int NOT NULL,
  `tag_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `post_tags`
--

INSERT INTO `post_tags` (`post_id`, `tag_id`) VALUES
(1, 1),
(3, 1),
(8, 1),
(11, 1),
(13, 1),
(14, 1),
(15, 1),
(17, 1),
(26, 1),
(1, 2),
(2, 2),
(5, 2),
(14, 2),
(15, 2),
(21, 2),
(25, 2),
(29, 2),
(1, 3),
(13, 3),
(2, 4),
(2, 6),
(4, 6),
(20, 6),
(3, 8),
(13, 8),
(16, 8),
(3, 9),
(5, 9),
(9, 9),
(16, 9),
(17, 9),
(25, 9),
(26, 9),
(27, 9),
(28, 9),
(29, 9),
(34, 9),
(4, 10),
(19, 10),
(20, 10),
(21, 10),
(22, 10),
(23, 10),
(24, 10),
(35, 10),
(4, 11),
(19, 11),
(5, 13),
(6, 16),
(12, 16),
(18, 16),
(24, 16),
(30, 16),
(36, 16),
(42, 16),
(6, 17),
(18, 17),
(30, 17),
(7, 18),
(7, 19),
(8, 19),
(9, 19),
(10, 19),
(11, 19),
(12, 19),
(31, 19),
(32, 19),
(33, 19),
(34, 19),
(7, 20),
(31, 20),
(8, 21),
(33, 21),
(9, 24),
(10, 27),
(10, 29),
(11, 30),
(14, 39),
(15, 41),
(16, 44),
(17, 48),
(22, 48),
(19, 52),
(20, 52),
(21, 52),
(22, 52),
(23, 52),
(23, 65),
(25, 69),
(26, 69),
(27, 69),
(28, 69),
(30, 69),
(27, 77),
(28, 79),
(29, 79),
(31, 87),
(32, 87),
(32, 90),
(33, 93),
(34, 96),
(35, 96),
(36, 96),
(35, 100),
(42, 104);

-- --------------------------------------------------------

--
-- Table structure for table `subscriptions`
--

CREATE TABLE `subscriptions` (
  `id` int NOT NULL,
  `follower_id` int NOT NULL,
  `following_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `subscriptions`
--

INSERT INTO `subscriptions` (`id`, `follower_id`, `following_id`) VALUES
(6, 1, 3),
(5, 6, 5);

-- --------------------------------------------------------

--
-- Table structure for table `tags`
--

CREATE TABLE `tags` (
  `id` int NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `tags`
--

INSERT INTO `tags` (`id`, `name`) VALUES
(21, 'API'),
(27, 'CSS'),
(69, 'Git'),
(24, 'HTML'),
(18, 'HTTP'),
(30, 'JavaScript'),
(93, 'JSON'),
(11, 'MySQL'),
(52, 'SQL'),
(19, 'Web'),
(4, 'Алгоритмы'),
(48, 'Архитектура'),
(10, 'БазыДанных'),
(96, 'Безопасность'),
(105, 'Дебаг'),
(29, 'Дизайн'),
(79, 'Документация'),
(106, 'екуеу'),
(17, 'Заметки'),
(20, 'Интернет'),
(6, 'Информатика'),
(90, 'Клиент'),
(8, 'Код'),
(77, 'КоманднаяРабота'),
(2, 'Обучение'),
(65, 'Оптимизация'),
(3, 'Основы'),
(100, 'Пароли'),
(1, 'Программирование'),
(9, 'Разработка'),
(87, 'Сервер'),
(104, 'Тест'),
(13, 'Тестирование'),
(39, 'Условия'),
(16, 'Учеба'),
(44, 'Функции'),
(41, 'Циклы');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `login` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `login`, `password`, `created_at`) VALUES
(1, 'User1', '$2y$10$uNIXO5nx1CsVVo/tb9B5b.yFzTJd2k/a1XQKtHE5Bb0o1MZB0z/3O', '2026-08-27 17:10:14'),
(2, 'User2', '$2y$10$8ST01tb9Yrf9BOaeW.Pqwuq26Im67o2XWv6GthPWZqRL/a/2tXKny', '2026-08-27 17:14:45'),
(3, 'User3', '$2y$10$AU16b8cckTyTjnjGwe51MuzTUDNy17f5Ki8m0pXw9LS0I287lsbEy', '2026-08-27 17:18:05'),
(4, 'User4', '$2y$10$Rd3wtBq6GZ5dwYLpFZUX9O1qhzDQLmEehDaw8ii6pC.QA8G8f9DHy', '2026-08-27 17:19:14'),
(5, 'User5', '$2y$10$CLlJKqr/ukQs3LpR8Cv5SuSm9dRLufl4NIUjIVa/svlcMoP/npQui', '2026-08-27 17:19:52'),
(6, 'User6', '$2y$10$71ta7GoHdpEeY1gjNZoN0uKxxhNF4dQViuasuhU9G3c2/wuNt3SgO', '2026-08-27 17:32:29');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `comments`
--
ALTER TABLE `comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_comments_post_id` (`post_id`),
  ADD KEY `idx_comments_user_id` (`user_id`);

--
-- Indexes for table `posts`
--
ALTER TABLE `posts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_posts_secret_code` (`secret_code`),
  ADD KEY `idx_posts_user_id` (`user_id`),
  ADD KEY `idx_posts_created_at` (`created_at`);

--
-- Indexes for table `post_tags`
--
ALTER TABLE `post_tags`
  ADD PRIMARY KEY (`post_id`,`tag_id`),
  ADD KEY `idx_post_tags_tag_id` (`tag_id`);

--
-- Indexes for table `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_subscriptions_pair` (`follower_id`,`following_id`),
  ADD KEY `idx_subscriptions_following` (`following_id`);

--
-- Indexes for table `tags`
--
ALTER TABLE `tags`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_tags_name` (`name`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_users_login` (`login`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `comments`
--
ALTER TABLE `comments`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `posts`
--
ALTER TABLE `posts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT for table `subscriptions`
--
ALTER TABLE `subscriptions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `tags`
--
ALTER TABLE `tags`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=109;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `comments`
--
ALTER TABLE `comments`
  ADD CONSTRAINT `fk_comments_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_comments_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `posts`
--
ALTER TABLE `posts`
  ADD CONSTRAINT `fk_posts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `post_tags`
--
ALTER TABLE `post_tags`
  ADD CONSTRAINT `fk_post_tags_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_post_tags_tag` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `subscriptions`
--
ALTER TABLE `subscriptions`
  ADD CONSTRAINT `fk_subscriptions_follower` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_subscriptions_following` FOREIGN KEY (`following_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
