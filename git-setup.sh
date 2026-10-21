#!/bin/sh
# Writes ~/.gitconfig from environment variables set in .env, then starts Open Terminal.
set -eu

cfg="$HOME/.gitconfig"
alt="$HOME/.gitconfig-alt"

# Replace rather than overwrite, in case an old file is owned by root.
rm -f "$cfg"

{
    if [ -n "${GIT_USER_NAME:-}" ] || [ -n "${GIT_USER_EMAIL:-}" ]; then
        echo "[user]"
        [ -n "${GIT_USER_NAME:-}" ] && printf '\tname = %s\n' "$GIT_USER_NAME"
        [ -n "${GIT_USER_EMAIL:-}" ] && printf '\temail = %s\n' "$GIT_USER_EMAIL"
    fi

    cat <<'EOF'
[filter "lfs"]
	process = git-lfs filter-process
	required = true
	clean = git-lfs clean -- %f
	smudge = git-lfs smudge -- %f
[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
EOF

    printf '[credential "https://%s"]\n\thelper =\n\thelper = !/usr/bin/glab auth git-credential\n' \
        "${GITLAB_HOST:-gitlab.com}"

    # Optional second email for remotes under one prefix, e.g. github.com/some-org.
    if [ -n "${GIT_ALT_REMOTE:-}" ] && [ -n "${GIT_ALT_EMAIL:-}" ]; then
        ssh_form=$(printf '%s' "$GIT_ALT_REMOTE" | sed 's|/|:|')
        for url in "https://$GIT_ALT_REMOTE/**" "git@$ssh_form/**" "gcrypt::https://$GIT_ALT_REMOTE/**"; do
            printf '[includeIf "hasconfig:remote.*.url:%s"]\n\tpath = %s\n' "$url" "$alt"
        done
    fi
} > "$cfg"

if [ -n "${GIT_ALT_REMOTE:-}" ] && [ -n "${GIT_ALT_EMAIL:-}" ]; then
    printf '[user]\n\temail = %s\n' "$GIT_ALT_EMAIL" > "$alt"
else
    rm -f "$alt"
fi

exec /app/entrypoint.sh "$@"
