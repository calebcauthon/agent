# agent

Docker-backed isolated coding-agent rooms.

## Install with Homebrew

Homebrew packaging lives in a separate tap repo, not in this source repo.

```sh
brew tap calebcauthon/agent
brew install agent
```

Or install in one command:

```sh
brew install calebcauthon/agent/agent
```

After install, these commands are available:

```sh
room [name]
agent [agent-name] [-r room-name]
logs [room-name]
rooms [rm container-name]
agents [room-name]
agents rm [room-name] <agent-name>
```

Check the installed version:

```sh
agent --version
room --version
```

Codex CLI auth is shared by default across rooms via `~/.rooms/codex/global`, seeded once from host `~/.codex/auth.json` and `~/.codex/config.toml` when present. Override with `CODEX_AUTH_SCOPE=project`, `room`, or `none`.

Pi auth is separate from Codex CLI auth. It is shared by default across rooms via `~/.rooms/pi/global`, seeded once from host `~/.pi/agent/auth.json`, `settings.json`, and `models.json` when present. Override with `PI_AUTH_SCOPE=project`, `room`, or `none`.

If you prefer shell functions, add this to `~/.zshrc` after installing:

```sh
export ROOMS_DIR="$(brew --prefix agent)/libexec"
source "$(brew --prefix agent)/libexec/shell.sh"
```

## Releasing a new version

The source release and Homebrew formula are maintained separately:

1. Update `VERSION` in this repo.
2. Commit, tag, and push the source release:

```sh
git add VERSION
git commit -m "Release v0.1.1"
git tag v0.1.1
git push origin main --tags
```

3. In the separate Homebrew tap repo, update the `agent` formula to point at the new tag/version.
4. Users can then update with:

```sh
brew update
brew upgrade agent
```
