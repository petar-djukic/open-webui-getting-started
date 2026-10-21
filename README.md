# Open WebUI: getting started

A step-by-step guide, plus a few helper files, for running [Open WebUI](https://docs.openwebui.com/) locally with [Open Terminal](https://docs.openwebui.com/features/open-terminal/setup/installation), so a model in your chats can work on your own code inside a sandboxed shell.

What you get:

- Open WebUI at http://localhost:3000, run with Docker Compose.
- A sandboxed terminal the model can use, with your projects folder mounted and `git`, `gh` (GitHub CLI) and `glab` (GitLab CLI) installed.
- **Folder terminals**: one command gives a single repository its own terminal, which can write only to that repository and read the others. Each one shows up in the chat's terminal picker by its path.
- Notes on using the Open WebUI desktop app with this server, and fixes for the problems you are likely to hit.

The guide is written for macOS with Docker Desktop. On Linux, replace `pbcopy` with `xclip -selection clipboard` and `sed -i ''` with `sed -i`.

## How it fits together

```
Open WebUI (localhost:3000) ──HTTP + API key──▶ open-terminal        ~/<WORKSPACE> read-write
                            ──HTTP + API key──▶ term-<folder> ...   one folder read-write, the rest read-only
```

Every terminal is a container on the Compose network, reached by its service name (for example `http://open-terminal:8000`). None of them publishes a port to your Mac. The model can only touch what is mounted into the container it is using.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | The `open-webui` and `open-terminal` services and their volumes |
| `Dockerfile` | Extends the Open Terminal image with `gh`, `glab` and Git LFS |
| `git-setup.sh` | Writes the terminal's git config from `.env` at startup |
| `terminals.sh` | Adds, removes and registers [folder terminals](#folder-terminals) |
| `.env.example` | Template for `.env`: workspace folder, API keys, git identity and tokens |
| `.env` | Your settings and secrets. Git ignores it; never commit it |

## Setup

Do all five steps, and check step 5 in the browser, before you start the [desktop app](#desktop-app).

### 1. Create `.env`

Copy the template and generate the terminal API key:

```bash
cp .env.example .env
sed -i '' "s/^OPEN_TERMINAL_API_KEY=.*/OPEN_TERMINAL_API_KEY=$(openssl rand -hex 32)/" .env
```

Then edit `.env`:

- `WORKSPACE`: the folder under your home directory that holds your repositories, for example `projects` for `~/projects`. The main terminal mounts it read-write.
- `GIT_USER_NAME` and `GIT_USER_EMAIL`: the identity for commits the model makes.
- Clear or fill the optional variables (see [Git, GitHub and GitLab](#git-github-and-gitlab)).

Compose refuses to start while `OPEN_TERMINAL_API_KEY` or `WORKSPACE` is unset, so the terminal never runs with a key you don't know.

### 2. Start the stack

```bash
docker compose up -d
docker compose ps
```

The first start builds the terminal image. Open WebUI is then at http://localhost:3000; give it a minute on first start. The first account you create becomes the admin.

### 3. Check that Open WebUI can reach the terminal

```bash
docker exec open-webui curl -s http://open-terminal:8000/health
```

Expected output: `{"status":"ok"}`.

### 4. Connect the terminal in Open WebUI

1. Click your name at the bottom of the left sidebar and go to **Settings → Admin → Integrations**. Use the Admin settings, not your Personal ones: a personal connection sends the API key to your browser.
2. Scroll to the **Open Terminal** section and click **+**. Don't use "External Tools" or "Tool Servers". If the section is greyed out, `ENABLE_TOOL_SERVERS` is set to `False`.
3. Fill in:
   - **URL:** `http://open-terminal:8000`
   - **Name:** anything, for example `WORKSPACE`. This is the name you pick in chats.
   - **API Key:** the value of `OPEN_TERMINAL_API_KEY` in `.env`. To copy it to the clipboard without printing it:
     ```bash
     grep OPEN_TERMINAL_API_KEY .env | cut -d= -f2- | tr -d '\n' | pbcopy
     ```
     `pbcopy` prints nothing. Paste with Cmd+V into an empty field; pasting over existing text can drop the first character (see [Troubleshooting](#troubleshooting)).
   - **Auth Type:** `Bearer` (the default)
   - Leave **Chat Uploads** and the advanced options at their defaults.
4. Click **Save**. The connection appears with its toggle on.
5. Under **Workspace → Models**, edit your model and set **Function Calling** to **Native**, not Legacy.

### 5. Try it

Start a new chat with a chat model (not an embedding model). Click the terminal (cloud) icon and choose your connection under **System**. The terminal is off until you select it in the chat. Then ask:

> List the folders in my workspace

## Folder terminals

A folder terminal lets a chat work in one folder, usually one repository. Inside it:

- the folder is writable, and the shell starts there;
- the rest of the folder's top-level directory (for example `~/projects`) is read-only, so the model can read your other repositories but not change them;
- this guide's folder, which holds `.env`, appears empty.

```bash
./terminals.sh add ~/projects/my-repo      # start a terminal and register it in Open WebUI
./terminals.sh list                        # folders, addresses and container state
./terminals.sh remove ~/projects/my-repo   # stop it and remove its connection
./terminals.sh sync                        # re-apply everything, e.g. after editing .env
```

In a new chat, click the terminal icon: each folder is listed by its path, for example `~/projects/my-repo`. Pick one and the model works there. If a new folder doesn't show up in the desktop app, reload it with Cmd+R.

How it works:

- `terminals.txt` lists the folders. `terminals.sh` generates one Compose service per folder into `terminals.yml`, which Compose loads through `COMPOSE_FILE` in `.env`. Both files are local and ignored by git.
- Each folder terminal gets its own API key in `.env` (`TERM_<FOLDER>_KEY`).
- The script registers the terminals through Open WebUI's admin API, so you never paste their keys. It authenticates with a five-minute admin token minted inside the `open-webui` container, which needs no setup. This relies on Open WebUI internals; if an update breaks it, create an admin API key (**Settings → Account → API Keys**, after enabling API keys under **Admin → Settings → General**) and set `OPEN_WEBUI_API_KEY` in `.env`.
- The script only replaces the connections it created (id prefix `repo-terminal:`) and keeps your enabled/disabled choice for them.
- Folder terminals get no GitHub or GitLab token. To let one push, add `TERM_<FOLDER>_GH_TOKEN` or `TERM_<FOLDER>_GITLAB_TOKEN` to `.env` and run `./terminals.sh sync`.
- Each folder terminal is its own container, using roughly 100–200 MB of memory. Removing one keeps its home volume; delete it with `docker volume rm` if you no longer need it.

## Desktop app

> [!CAUTION]
> **It is extremely important that everything is fully set up before you start the desktop app.** Finish [Setup](#setup) steps 1–5 first: the stack is running, the terminal connection is saved with the right key, and a chat in the browser at http://localhost:3000 can list your workspace. Only then install or launch the app.
>
> On first launch the app offers to install its own Open WebUI server, and it can install and start its own unsandboxed Open Terminal in your home folder. If the Docker server isn't ready, you end up with a second server with separate chats, or a terminal with full access to your Mac, and the app uses those instead of this setup.

The Open WebUI desktop app (`brew install --cask open-webui`) can use this server instead of running its own, and adds a Spotlight-style chat bar (Shift+Cmd+I) and push-to-talk:

1. On first launch, don't install the local server. Add a connection to `http://localhost:3000` and make it the default.
2. In the desktop app's own settings (not Open WebUI's Admin settings), open **Terminal** and turn **Open Terminal** off, then quit the app with Cmd+Q and reopen it.
3. In a chat, select your connection from the terminal icon, as in the browser.

With its built-in terminal on, the app installs its own Python and runs a second Open Terminal natively on your Mac. That terminal runs as your user, in your home folder, with no sandbox, and the app uses it instead of this server's terminals. Check that it is gone:

```bash
pgrep -fl "open-terminal run"
```

No output means only the Docker terminals are running.

## The main terminal's workspace

The main terminal mounts `~/<WORKSPACE>` read-write at `/home/user/<WORKSPACE>`. The model can read and change every repository there, and its changes land directly in your working copies. Everything else it creates stays in the `open-terminal` volume.

To make the mount read-only, append `:ro` to it in `docker-compose.yml` and run `docker compose up -d`. To mount another folder, add a line of the same shape. Mount only what the model needs, since it can run any command against a read-write mount. For day-to-day work on one repository, prefer a [folder terminal](#folder-terminals).

## Git, GitHub and GitLab

The terminals run a local image, `open-terminal-gh`, built from the [`Dockerfile`](Dockerfile). It adds the GitHub CLI (`gh`), the GitLab CLI (`glab`) and Git LFS to the upstream image.

On every start, [`git-setup.sh`](git-setup.sh) writes the container's `~/.gitconfig` from `.env`. No identity lives in this repository.

| Variable | Effect |
|---|---|
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | Commit author |
| `GIT_ALT_REMOTE`, `GIT_ALT_EMAIL` | Optional. Repositories with a remote under the prefix (for example `github.com/some-org`) commit with the alternate email |
| `GH_TOKEN` | Git pushes to github.com and `gh`, in the main terminal |
| `GITLAB_TOKEN`, `GITLAB_HOST` | Git pushes to the GitLab host and `glab`, in the main terminal. `GITLAB_HOST` defaults to `gitlab.com` |

Git authenticates through `gh` and `glab`, which read the tokens from the environment. After editing `.env`, run `docker compose up -d open-terminal` (or `./terminals.sh sync` for folder terminals).

### GitHub token

1. Create a fine-grained token at https://github.com/settings/personal-access-tokens/new:
   - **Resource owner:** your account. A fine-grained token covers one owner, so repositories under an organization need a separate token.
   - **Repository access:** only the repositories the model should push to.
   - **Permissions:** Contents: Read and write; Pull requests: Read and write; Issues: Read and write if wanted. Leave Administration and everything else at No access.
   - **Expiration:** short, such as 30 days.
2. Add it to `.env`:
   ```bash
   GH_TOKEN=github_pat_...
   ```
3. Recreate the terminal so it picks up the token, and check:
   ```bash
   docker compose up -d open-terminal
   docker exec open-terminal gh auth status
   ```

### GitLab token

1. Create a personal access token on your GitLab host under **Preferences → Access tokens**, or a project access token for a single project. Give it the `api` and `write_repository` scopes and a short expiry.
2. Add it to `.env`, with `GITLAB_HOST` set if you don't use gitlab.com:
   ```bash
   GITLAB_TOKEN=glpat-...
   GITLAB_HOST=gitlab.com
   ```
3. Recreate the terminal and check:
   ```bash
   docker compose up -d open-terminal
   docker exec open-terminal glab auth status
   ```

To revoke access, delete the token on GitHub or GitLab, or clear it in `.env` and recreate the terminal.

## Operations

```bash
docker compose pull open-webui && docker compose build --pull open-terminal && docker compose up -d   # update the images
docker compose logs -f open-terminal          # follow the main terminal's log
docker compose down                           # stop everything (volumes are kept)
```

After changing the `Dockerfile` or `git-setup.sh`, rebuild with `docker compose build open-terminal && docker compose up -d`.

To expose the main terminal's API docs at http://localhost:8000/docs, add `ports: ["8000:8000"]` to the `open-terminal` service.

## Troubleshooting

**The model says it has no access to local files.** Open WebUI isn't giving it the terminal. Check, in order:

1. The terminal is selected in this chat (terminal icon → your connection).
2. The API key is right. The terminal logs one request per check; `401` means a wrong key:
   ```bash
   docker compose logs open-terminal | grep '/system'
   ```
   If you see `401 Unauthorized`, delete the connection, add it again, and paste the key into the empty field.
3. **Function Calling** is **Native** for the model (**Workspace → Models**).
4. The model can use tools. Small local models often don't; try a larger one.

**"does not support chat".** You picked an embedding model, such as `qwen3-embedding`. Pick a chat model.

**`docker compose up` fails with "container name is already in use".** A container named `open-terminal` or `open-webui` was started outside Compose, for example with `docker run` from the upstream docs. Remove it with `docker rm -f open-terminal` and run `docker compose up -d` again.

**A folder terminal isn't in the picker.** Run `./terminals.sh sync` and read its last line. It should report how many folder terminals it registered; otherwise it says why it couldn't. Then start a new chat.

**A terminal container keeps restarting.** Read its log with `docker compose logs open-terminal` (or the folder terminal's service name from `./terminals.sh list`).

## Security notes

- The model can run any command inside the terminal it is using. Its files persist in that terminal's home volume at `/home/user`.
- The main terminal mounts your workspace read-write, so the model can change or delete anything in it, including uncommitted work. Commit or push before letting it loose on a repository.
- A folder terminal can only write to its folder, but it can read every other repository in the same top-level folder. Keep secrets out of that folder.
- With a GitHub or GitLab token set, the model can push and use `gh` or `glab` with everything that token allows. Keep tokens fine-grained, limited to specific repositories and short-lived. Never give a terminal a classic token or your own `gh` login.
- The container user has passwordless `sudo`, so the model is effectively root inside the container. Docker doesn't give the container the capability to remount, so read-only mounts stay read-only.
- Keep the desktop app's built-in Open Terminal off. It runs unsandboxed as your Mac user.
- Leave **Forward cookies** off. When it is on, every cookie your browser holds for the Open WebUI domain is sent to the terminal server.
- Setting **Chat Uploads** to **Filesystem** writes uploaded files into the terminal, where the model can act on them.

## References

- [Open Terminal installation](https://docs.openwebui.com/features/open-terminal/setup/installation)
- [Connecting Open Terminal to Open WebUI](https://docs.openwebui.com/features/open-terminal/setup/connecting)
- [Open WebUI environment variables](https://docs.openwebui.com/reference/env-configuration)
- [Open WebUI desktop app](https://github.com/open-webui/desktop)
