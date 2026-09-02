async function api(action, data = {}) {
    const formData = new FormData();

    for (const [key, value] of Object.entries(data)) {
        formData.append(key, value ?? '');
    }

    const response = await fetch(
        'api.php?action=' + encodeURIComponent(action),
        {
            method: 'POST',
            body: formData,
            credentials: 'same-origin',
            headers: {
                'Accept': 'application/json',
            },
        }
    );

    let result;

    try {
        result = await response.json();
    } catch (error) {
        return {
            success: false,
            message: 'Сервер вернул некорректный ответ',
            data: {},
        };
    }

    if (!response.ok && result.success !== false) {
        result.success = false;
        result.message = 'Ошибка HTTP: ' + response.status;
    }

    return result;
}

function showResult(element, data) {
    if (!element) {
        return;
    }

    element.textContent = data.message || '';
    element.className = data.success ? 'result success' : 'result error';
}

async function createPost() {
    const form = document.getElementById('create-post-form');

    if (!form) {
        return;
    }

    const data = new FormData(form);

    const result = await api('create_post', {
        title: data.get('title'),
        text: data.get('text'),
        is_private: data.get('is_private') ? 1 : 0,
        tags: data.get('tags'),
    });

    showResult(document.getElementById('create-result'), result);

    if (result.success) {
        form.reset();
        updatePrivateFields();

        if (result.data && result.data.secret_code) {
            const message = 'Пост создан. Секретный код: ' + result.data.secret_code;
            const output = document.getElementById('create-result');
            if (output) {
                output.textContent = message;
                output.className = 'result success result--code';
            }
            setTimeout(() => location.reload(), 4000);
        } else {
            setTimeout(() => location.reload(), 500);
        }
    }
}

async function deletePost(id) {
    if (!confirm('Удалить пост?')) {
        return;
    }

    const result = await api('delete_post', { id });

    if (result.success) {
        location.href = 'index.php';
        return;
    }

    alert(result.message);
}

async function updateProfileSubscriptionUI(userId, data) {
    if (!data) {
        return;
    }

    const button = document.getElementById('profile-subscribe-button');

    if (button && Number(userId) === Number(button.dataset.userId)) {
        const following = Number(data.is_following) === 1;
        button.dataset.following = following ? '1' : '0';
        button.dataset.userId = String(userId);
        button.classList.toggle('button--primary', !following);
        button.classList.toggle('button--secondary', following);
        button.textContent = following ? 'Отписаться' : 'Подписаться';
    }

    const followers = document.getElementById('profile-followers-count');
    if (followers && data.followers_count !== undefined) {
        followers.textContent = String(data.followers_count);
    }

    const followingCount = document.getElementById('profile-following-count');
    if (followingCount && data.following_count !== undefined) {
        followingCount.textContent = String(data.following_count);
    }
}

async function toggleSubscription(userId) {
    const button = document.getElementById('profile-subscribe-button');
    const currentlyFollowing = button && Number(button.dataset.following) === 1;
    const action = currentlyFollowing ? 'unsubscribe' : 'subscribe';

    if (button) {
        button.disabled = true;
    }

    const result = await api(action, { user_id: userId });

    if (result.success) {
        await updateProfileSubscriptionUI(userId, result.data);
    } else {
        alert(result.message);
    }

    if (button) {
        button.disabled = false;
    }
}

async function subscribe(userId) {
    const result = await api('subscribe', { user_id: userId });

    if (result.success) {
        const button = document.querySelector(
            '[onclick="subscribe(' + Number(userId) + ')"]'
        );

        if (button) {
            button.textContent = 'Отписаться';
            button.classList.remove('button--primary');
            button.classList.add('button--secondary');
            button.setAttribute('onclick', 'unsubscribe(' + Number(userId) + ')');
            button.dataset.following = '1';
        }
    } else {
        alert(result.message);
    }
}

async function unsubscribe(userId) {
    const result = await api('unsubscribe', { user_id: userId });

    if (result.success) {
        const button = document.querySelector(
            '[onclick="unsubscribe(' + Number(userId) + ')"]'
        );

        if (button) {
            button.textContent = 'Подписаться';
            button.classList.remove('button--secondary');
            button.classList.add('button--primary');
            button.setAttribute('onclick', 'subscribe(' + Number(userId) + ')');
            button.dataset.following = '0';
        }
    } else {
        alert(result.message);
    }
}

async function addComment() {
    const form = document.getElementById('comment-form');

    if (!form) {
        return;
    }

    const data = new FormData(form);

    const result = await api('comment', {
        post_id: data.get('post_id'),
        text: data.get('text'),
    });

    showResult(document.getElementById('comment-result'), result);

    if (result.success) {
        form.reset();
        setTimeout(() => location.reload(), 300);
    }
}

async function editComment(id, oldText) {
    const text = prompt('Измените комментарий:', oldText);

    if (text === null || text.trim() === '') {
        return;
    }

    const result = await api('edit_comment', { id, text });
    alert(result.message);

    if (result.success) {
        location.reload();
    }
}

async function deleteComment(id, postId) {
    if (!confirm('Удалить комментарий?')) {
        return;
    }

    const result = await api('delete_comment', { id });
    alert(result.message);

    if (result.success) {
        location.href = 'post.php?id=' + encodeURIComponent(postId);
    }
}

async function loadFeed() {
    const result = await api('feed');
    const container = document.getElementById('feed');

    if (!container) {
        return;
    }

    if (!result.success) {
        container.textContent = result.message;
        return;
    }

    renderPosts(container, result.data.posts);
}

async function loadPublicPosts() {
    const result = await api('public_posts');
    const container = document.getElementById('public-posts');

    if (!container) {
        return;
    }

    if (!result.success) {
        container.textContent = result.message;
        return;
    }

    renderPosts(container, result.data.posts);
}

async function loadPostsByTag(tag) {
    const result = await api('posts_by_tag', { tag });
    const container = document.getElementById('tag-results');

    if (!container) {
        return;
    }

    if (!result.success) {
        container.textContent = result.message;
        return;
    }

    renderPosts(container, result.data.posts);
}

async function loadSecretPost(code) {
    const result = await api('secret_post', { code });
    const container = document.getElementById('secret-result');

    if (!container) {
        return;
    }

    if (!result.success) {
        container.textContent = result.message;
        return;
    }

    const post = result.data.post;
    container.innerHTML = '';

    const article = document.createElement('article');
    article.className = 'post-card post-card--private';

    const badge = document.createElement('span');
    badge.className = 'post-badge post-badge--private';
    badge.textContent = 'Приватный пост';

    const title = document.createElement('h3');
    title.textContent = post.title;

    const author = document.createElement('p');
    author.className = 'post-meta';
    author.appendChild(document.createTextNode('Автор: '));

    const authorLink = document.createElement('a');
    authorLink.className = 'author-link';
    authorLink.href = 'user.php?id=' + encodeURIComponent(post.user_id);
    authorLink.textContent = '@' + post.login;
    author.appendChild(authorLink);

    const text = document.createElement('p');
    text.className = 'post-preview';
    text.textContent = post.text;

    const tagList = document.createElement('div');
    tagList.className = 'tag-list';

    for (const tagValue of (result.data.tags || [])) {
        const tagName = String(tagValue.name || '').trim();
        if (!tagName) continue;

        const tagLink = document.createElement('a');
        tagLink.className = 'tag';
        tagLink.href = 'index.php?tag=' + encodeURIComponent(tagName);
        tagLink.textContent = '#' + tagName;
        tagList.appendChild(tagLink);
    }

    const link = document.createElement('a');
    link.className = 'text-link';
    link.href = 'post.php?code=' + encodeURIComponent(code);
    link.textContent = 'Открыть полностью →';

    article.appendChild(badge);
    article.appendChild(title);
    article.appendChild(author);
    article.appendChild(text);
    if (tagList.childElementCount > 0) {
        article.appendChild(tagList);
    }
    article.appendChild(link);
    container.appendChild(article);
}

function renderPosts(container, posts) {
    container.innerHTML = '';

    if (!posts || posts.length === 0) {
        container.innerHTML = '<div class="empty-state">Постов нет.</div>';
        return;
    }

    for (const post of posts) {
        const article = document.createElement('article');
        article.className = 'post-card';

        if (Number(post.is_private) === 1) {
            article.classList.add('post-card--private');
        }

        const title = document.createElement('h3');
        title.textContent = post.title;

        const author = document.createElement('p');
        author.className = 'post-meta';
        author.appendChild(document.createTextNode('Автор: '));

        const authorLink = document.createElement('a');
        authorLink.className = 'author-link';
        authorLink.href = 'user.php?id=' + encodeURIComponent(post.user_id);
        authorLink.textContent = '@' + post.login;
        author.appendChild(authorLink);

        const text = document.createElement('p');
        text.className = 'post-preview';
        text.textContent = post.text;

        const tags = document.createElement('div');
        tags.className = 'tag-list';

        if (post.tags) {
            for (const tagValue of String(post.tags).split(',')) {
                const tagName = tagValue.trim();
                if (!tagName) continue;

                const tagLink = document.createElement('a');
                tagLink.className = 'tag';
                tagLink.href = 'index.php?tag=' + encodeURIComponent(tagName);
                tagLink.textContent = '#' + tagName;
                tags.appendChild(tagLink);
            }
        }

        const link = document.createElement('a');
        link.className = 'text-link';
        link.href = 'post.php?id=' + encodeURIComponent(post.id);
        link.textContent = 'Открыть →';

        article.appendChild(title);
        article.appendChild(author);
        article.appendChild(text);
        if (tags.childElementCount > 0) {
            article.appendChild(tags);
        }
        article.appendChild(link);

        container.appendChild(article);
    }
}

function updatePrivateFields() {
    const checkbox = document.getElementById('private-checkbox');
    const hint = document.getElementById('private-code-hint');

    if (!checkbox || !hint) {
        return;
    }

    hint.classList.toggle('is-hidden', !checkbox.checked);
}

function copySecretCode() {
    const codeElement = document.getElementById('owner-secret-code');

    if (!codeElement) {
        return;
    }

    const code = codeElement.textContent.trim();

    if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(code);
        alert('Секретный код скопирован');
        return;
    }

    const textarea = document.createElement('textarea');
    textarea.value = code;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    textarea.remove();
    alert('Секретный код скопирован');
}


document.addEventListener('DOMContentLoaded', () => {
    const privateCheckbox = document.getElementById('private-checkbox');

    if (privateCheckbox) {
        privateCheckbox.addEventListener('change', updatePrivateFields);
        updatePrivateFields();
    }

    const createForm = document.getElementById('create-post-form');

    if (createForm) {
        createForm.addEventListener('submit', event => {
            event.preventDefault();
            createPost();
        });
    }

    const commentForm = document.getElementById('comment-form');

    if (commentForm) {
        commentForm.addEventListener('submit', event => {
            event.preventDefault();
            addComment();
        });
    }

    const editForm = document.getElementById('edit-post-form');

    if (editForm) {
        editForm.addEventListener('submit', async event => {
            event.preventDefault();

            const data = new FormData(editForm);
            const result = await api('edit_post', {
                id: data.get('id'),
                title: data.get('title'),
                text: data.get('text'),
                is_private: data.get('is_private') ? 1 : 0,
            });

            showResult(document.getElementById('edit-result'), result);

            if (result.success) {
                setTimeout(() => location.reload(), 300);
            }
        });
    }

    const tagForm = document.getElementById('tag-form');

    if (tagForm) {
        tagForm.addEventListener('submit', event => {
            event.preventDefault();
            const data = new FormData(tagForm);
            loadPostsByTag(data.get('tag'));
        });
    }

    const initialTag = document.body.dataset.initialTag || '';
    if (initialTag) {
        const tagInput = document.querySelector('#tag-form input[name="tag"]');
        if (tagInput) {
            tagInput.value = initialTag;
        }
        loadPostsByTag(initialTag);
    }

    const secretForm = document.getElementById('secret-form');

    if (secretForm) {
        secretForm.addEventListener('submit', event => {
            event.preventDefault();
            const data = new FormData(secretForm);
            loadSecretPost(data.get('code'));
        });
    }
});
