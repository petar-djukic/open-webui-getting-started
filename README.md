# Open WebUI with Open Terminal

Run [Open WebUI](https://docs.openwebui.com/) on your laptop with [Open Terminal](https://github.com/open-webui/open-terminal), so any model in your chats can read your code, run commands and commit. Everything runs in Docker; the model's shell can reach only the folders you mount into it.

## Quick start

You need Docker Desktop. The setup is tested on macOS.

1. Create your settings:

   ```bash
   cp .env.example .env
   ```

   In `.env`, set `WORKSPACE` to the folder in your home directory that holds your repositories (`projects` for `~/projects`), and set your git name and email.

2. Start everything:

   ```bash
   ./terminals.sh sync
   ```

   The first run builds the terminal image, generates its API key, and ends by asking you to create an account.

3. Open http://localhost:3000 and create an account. The first account is the admin.

4. Register the terminal in Open WebUI:

   ```bash
   ./terminals.sh sync
   ```

5. Start a new chat, click the terminal icon next to the message box, and pick `~/projects`. Ask the model to list the folders there.

## One terminal or one per repository

The quick start gives you one terminal that sees your whole workspace read-write. That is the simplest setup, and it suits work that spans repositories. Its cost is reach: every chat shares one shell that can change every repository.

For day-to-day work on a single repository, add a terminal for it:

```bash
./terminals.sh add ~/projects/my-repo
```

The new terminal shows up in the chat's terminal picker as `~/projects/my-repo`. Inside it, the shell starts in `my-repo`, the model can change only that repository, and every other repository in `~/projects` is read-only. Picking a terminal in the chat is how you pick the folder the model works in.

| | Main terminal | Repository terminal |
|---|---|---|
| Writes to | the whole workspace | one repository |
| Reads | the whole workspace | the whole workspace |
| Shell starts in | its home folder | the repository |
| Pushes with | `GH_TOKEN`, `GITLAB_TOKEN` | its own token, if you give it one |
| Cost | one container | one more container (roughly 100–200 MB) each |

Run `./terminals.sh list` to see the repository terminals, and `./terminals.sh remove ~/projects/my-repo` to remove one.

## What terminals.sh does

Open Terminal is one server per container, and Open WebUI needs a connection, with an API key, for every terminal. Doing that by hand means editing the Compose file and pasting keys into the admin settings for each repository. `terminals.sh` does both:

- generates an API key per terminal and stores it in `.env`;
- writes one Compose service per repository into `terminals.yml` (listed in `terminals.txt`) and starts it;
- registers every terminal in Open WebUI through its admin API, named after its folder.

It authenticates to Open WebUI with a short-lived admin token created inside the `open-webui` container, so there is no API key to set up. It only touches the connections it created. `.env`, `terminals.txt` and `terminals.yml` are local and ignored by git.

## Pushing

Commits use `GIT_USER_NAME` and `GIT_USER_EMAIL` from `.env`. To let the main terminal push, set `GH_TOKEN` or `GITLAB_TOKEN` (plus `GITLAB_HOST` if you don't use gitlab.com) and run `./terminals.sh sync`. For a repository terminal, set `TERM_<NAME>_GH_TOKEN` or `TERM_<NAME>_GITLAB_TOKEN`, where `TERM_<NAME>` matches its `TERM_<NAME>_KEY` line in `.env`.

Use [fine-grained GitHub tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) limited to the repositories the model should push to, with Contents and Pull requests set to read and write and a short expiry. For GitLab, use a token with `api` and `write_repository` scopes. Never give a terminal your own `gh` login.

## The desktop app

> [!CAUTION]
> Finish the quick start, and check it in the browser, before you open the Open WebUI desktop app. On first launch it offers to install its own Open WebUI server, and it can start its own Open Terminal that runs unsandboxed in your home folder. The app then uses those instead of this setup.

The [desktop app](https://github.com/open-webui/desktop) (`brew install --cask open-webui`) adds a global chat bar and push-to-talk. To use it with this setup:

1. Don't install its local server; add a connection to `http://localhost:3000` instead.
2. In the app's own settings, open **Terminal** and turn **Open Terminal** off. Quit with Cmd+Q and reopen.
3. Check that no unsandboxed terminal is left: `pgrep -fl "open-terminal run"` should print nothing.

## Troubleshooting

**The model says it can't see your files.** Select the terminal in the chat (terminal icon); it is off until you do. If it still fails, check that the model's **Function Calling** is **Native** under **Workspace → Models**, and try a larger model: small models often ignore tools.

**"does not support chat".** You picked an embedding model. Pick a chat model.

**A terminal is missing from the picker.** Run `./terminals.sh sync` and read its last line, then start a new chat. In the desktop app, reload with Cmd+R.

**`./terminals.sh sync` can't get an admin token.** A newer Open WebUI may have changed its internals. Create an API key (**Admin → Settings → General → API Keys** on, then **Settings → Account → API Keys**), add `OPEN_WEBUI_API_KEY=sk-...` to `.env`, and run it again.

**"container name is already in use".** An `open-terminal` or `open-webui` container was started outside this setup, for example with `docker run` from the upstream docs. Remove it with `docker rm -f open-terminal` and run `./terminals.sh sync` again.

## Security notes

- The model can run any command inside the terminal it uses, as root via passwordless `sudo`. It still cannot remount a read-only folder: Docker withholds the capability that mounting needs.
- The main terminal can change or delete anything in your workspace, uncommitted work included. Prefer a repository terminal, and commit before you start.
- The folder holding this setup, and its `.env`, appears empty inside every terminal, so a model cannot read the keys and tokens.
- Leave **Forward cookies** off in the connection settings.

## Updating and stopping

```bash
docker compose pull open-webui && docker compose build --pull && ./terminals.sh sync   # update
docker compose down                                                                     # stop; chats and files are kept
```

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Open WebUI and the main terminal |
| `Dockerfile` | The Open Terminal image plus `gh`, `glab` and Git LFS, set up so git authenticates with your tokens |
| `terminals.sh` | Starts everything and manages the terminals (see above) |
| `.env.example` | Template for `.env`, your local settings and keys |
