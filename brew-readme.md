# Homebrew install

Homebrew packaging for `agent` lives in a separate tap repo, not in this source repo.

## Install

```sh
brew tap calebcauthon/agent
brew install agent
```

Or install in one command:

```sh
brew install calebcauthon/agent/agent
```

After install, these commands should be available:

```sh
agent
room
rooms
agents
logs
```

Check the installed version:

```sh
agent --version
room --version
rooms --version
```

## Releasing a new version

1. In this source repo, update `VERSION`.
2. Commit, tag, and push the source release:

```sh
git add VERSION
git commit -m "Release v0.1.1"
git tag v0.1.1
git push origin main --tags
```

3. In the separate Homebrew tap repo, update the `agent` formula to point at the new tag/version.
4. Push the tap repo change.

## Updating after install

```sh
brew update
brew upgrade agent
```
