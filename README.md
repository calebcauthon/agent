# agent

Docker-backed isolated coding-agent rooms.

## Install with Homebrew

From this repo/branch:

```sh
brew install --HEAD https://raw.githubusercontent.com/calebcauthon/agent/main/Formula/agent.rb
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

If you prefer shell functions, add this to `~/.zshrc` after installing:

```sh
export ROOMS_DIR="$(brew --prefix agent)/libexec"
source "$(brew --prefix agent)/libexec/shell.sh"
```

## Releasing a new version

1. Update `VERSION`.
2. Update `version` in `Formula/agent.rb` to match.
3. Commit, tag, and push:

```sh
git commit -am "Release v0.1.1"
git tag v0.1.1
git push origin main --tags
```

For a stable formula, point `url` in `Formula/agent.rb` at the tag instead of the branch, e.g. `tag: "v0.1.1"`.
