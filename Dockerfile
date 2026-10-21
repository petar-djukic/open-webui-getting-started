# Open Terminal plus the GitHub CLI, the GitLab CLI and Git LFS, so the model can push and use gh and glab.
FROM ghcr.io/open-webui/open-terminal:latest

ARG GLAB_VERSION=1.124.0

USER root
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh git-lfs \
    && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    arch=$(dpkg --print-architecture); \
    deb="glab_${GLAB_VERSION}_linux_${arch}.deb"; \
    base="https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads"; \
    cd /tmp; \
    curl -fsSLO "$base/$deb"; \
    curl -fsSL "$base/checksums.txt" | grep " $deb\$" | sha256sum -c -; \
    dpkg -i "$deb"; \
    rm "$deb"

# git authenticates through gh and glab, which read GH_TOKEN and GITLAB_TOKEN from the
# environment. Each helper answers only for its own hosts, so they can be chained.
RUN git config --system credential.helper '!gh auth git-credential' \
    && git config --system --add credential.helper '!glab auth git-credential' \
    && git lfs install --system

USER user
