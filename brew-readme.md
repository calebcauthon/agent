# Homebrew install

This repo includes a Homebrew formula at `Formula/agent.rb`.

## Install directly from this git repo

Once the formula is pushed to GitHub, install with:

```sh
brew install https://raw.githubusercontent.com/calebcauthon/agent/main/Formula/agent.rb
```

For the latest `main` version:

```sh
brew install --HEAD https://raw.githubusercontent.com/calebcauthon/agent/main/Formula/agent.rb
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

## Tap-style install

You can also add the repo as a tap:

```sh
brew tap calebcauthon/agent https://github.com/calebcauthon/agent
brew install agent
```

If this becomes a dedicated Homebrew tap repo, the conventional repo name would be:

```txt
homebrew-agent
```

Then users could install with:

```sh
brew install calebcauthon/agent/agent
```

## Releasing a new version

Bump both files together:

```txt
VERSION
Formula/agent.rb
```

Example release:

```sh
printf '0.1.1\n' > VERSION
# edit Formula/agent.rb: version "0.1.1"

git add VERSION Formula/agent.rb
git commit -m "Release v0.1.1"
git tag v0.1.1
git push origin main --tags
```

For stable installs, point the formula at the tag instead of `main`:

```rb
url "https://github.com/calebcauthon/agent.git", tag: "v0.1.1"
version "0.1.1"
```

Then users get that exact version when they install normally.

## Updating after install

If installed from a raw formula URL:

```sh
brew reinstall https://raw.githubusercontent.com/calebcauthon/agent/main/Formula/agent.rb
```

If installed from a tap:

```sh
brew update
brew upgrade agent
```
