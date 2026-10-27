# GH-Bar

A lightweight macOS menu bar app that shows your GitHub Actions and Pull Requests at a glance. Built with Swift and SwiftUI, powered by the `gh` CLI.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) [![CI](https://github.com/mailsvb/open-gh/actions/workflows/ci.yml/badge.svg)](https://github.com/mailsvb/open-gh/actions/workflows/ci.yml)

## Features

- **Menu bar icon** — always visible, one click to open; shows a red dot when the latest run of a workflow (or your PR's CI) failed, orange while something is running
- **Actions tab** — workflow runs organized by repo, grouped by workflow name
  - Per-workflow stats: success rate, average duration, failure count
  - Most recently active repo auto-expanded
  - Active repo fetches more run history automatically
- **PRs tab** — your open pull requests with CI status and review state
- **Org switcher** — dropdown to switch between orgs and personal repos
- **Smart polling** — every 30s while the popover is open, every 5 min in the background (for the status dot)
- **Click to open** — any run or PR opens directly in your browser
- **Configurable** — click **Config** in the footer to edit `~/.ghbar/config.json`; changes apply on the next refresh, no restart needed
- **Open at login** — toggle in the footer

## Prerequisites

- macOS 14+
- Swift 6.0+ (Xcode 16 or later)
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

```bash
# Install gh if needed
brew install gh
gh auth login
```

## Install

```bash
git clone https://github.com/mailsvb/open-gh.git
cd open-gh
./install.sh
```

This builds `GHBar.app`, installs it to `~/Applications` (no `sudo` needed), and launches it. On first launch it registers itself to open at login; turn that off with the **Open at login** checkbox in the popover footer.

Upgrading from an older version? `install.sh` also removes the old Launch Agent and `/usr/local/bin/ghbar`.

To stop GHBar, click **Quit** in the popover. To start it again, open `~/Applications/GHBar.app`.

## Uninstall

```bash
./uninstall.sh
```

## Configuration

Config lives at `~/.ghbar/config.json`. Created automatically on first run. Missing keys fall back to the defaults below; if the file can't be parsed it is left untouched and the error is shown in the popover.

```json
{
  "orgs": ["my-org"],
  "includePersonal": true,
  "username": "my-github-username",
  "pollingIntervalSeconds": 30,
  "backgroundPollingMinutes": 5,
  "maxReposPerOrg": 25,
  "runsPerRepo": 8,
  "activeRepoRunsLimit": 25,
  "maxConcurrency": 8
}
```

| Key | Description | Default |
|-----|-------------|---------|
| `orgs` | GitHub organizations to monitor | `[]` |
| `includePersonal` | Include your personal repos as a source | `true` |
| `username` | Your GitHub username (for personal repos). Leave empty to use the `gh` login | `""` |
| `pollingIntervalSeconds` | Refresh interval when popover is open (min 5) | `30` |
| `backgroundPollingMinutes` | Refresh interval while the popover is closed, for the status dot. `0` disables it | `5` |
| `maxReposPerOrg` | Max repos to scan per org | `25` |
| `runsPerRepo` | Workflow runs to fetch per repo | `8` |
| `activeRepoRunsLimit` | Extra runs fetched for the most active repo | `25` |
| `maxConcurrency` | Parallel `gh` CLI calls | `8` |

## Development

```bash
# Build and run (debug)
swift build && .build/debug/GHBar

# Run tests
swift test

# Build GHBar.app into .build/
./scripts/bundle.sh
```

Open-at-login only works when running from the bundled `.app`; the bare debug binary hides that option. CI builds, tests and bundles the app on every push and pull request.

## How it works

GHBar shells out to the `gh` CLI to fetch data from GitHub. No tokens or OAuth needed beyond your existing `gh auth` session. Fetches are parallelized and throttled to stay within API limits.

- **Actions**: lists the source's repos, then fetches recent runs per repo.
- **PRs**: one `gh search prs --author @me` call finds the repos where you have open PRs, then only those repos are queried for CI and review status.

Errors from `gh` (not installed, not logged in, rate limited) are shown in a banner at the top of the popover.

## License

MIT
