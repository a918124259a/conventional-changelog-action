# 📋 Changelog Generator

> **Auto-generate beautiful CHANGELOG.md files from Conventional Commits — with GitHub Releases integration, smart version detection, and sponsor-only premium features.**

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Conventional%20Changelog%20Action-brightgreen?logo=github)](https://github.com/marketplace/actions/conventional-changelog-action)
[![GitHub Release](https://img.shields.io/github/v/release/a918124259a/conventional-changelog-action?logo=github&color=blue)](https://github.com/a918124259a/conventional-changelog-action/releases)
[![GitHub Stars](https://img.shields.io/github/stars/a918124259a/conventional-changelog-action?style=social)](https://github.com/a918124259a/conventional-changelog-action)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-blue.svg)](https://conventionalcommits.org)
[![Keep a Changelog](https://img.shields.io/badge/Keep%20a%20Changelog-1.1.0-%23E05735)](https://keepachangelog.com)
[![Docker](https://img.shields.io/badge/Docker-Alpine-0db7ed?logo=docker)](https://github.com/a918124259a/conventional-changelog-action/pkgs/container/conventional-changelog-action)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%E2%9D%A4%EF%B8%8F-ff69b4?logo=githubsponsors)](https://github.com/sponsors/a918124259a)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Features

- **🔍 Automatic Discovery** — Parses all tags and commits following [Conventional Commits](https://www.conventionalcommits.org/)
- **📦 Semantic Versioning** — Detects versions from git tags automatically
- **🏷️ Smart Grouping** — Organizes changes by type (`feat`, `fix`, `perf`, `docs`, etc.)
- **🔗 Rich Linking** — Auto-links commit SHAs, issue references, and version comparisons
- **🚀 GitHub Releases** — Optionally auto-creates GitHub Releases with changelog content
- **⚙️ Fully Configurable** — Custom headers, tag prefixes, include/exclude filters, and more
- **📤 Action Outputs** — Exposes `changelog`, `version`, and `release-notes` for downstream workflows

### ⭐ Premium Features (Sponsors Only)

| Feature | Description |
|---------|-------------|
| 🎨 **Custom Templates** | Choose from `classic`, `minimal`, `modern`, `detailed`, or `json` themes |
| 😄 **Emoji Decorations** | Auto-add emoji icons next to each commit type |
| 📊 **AI Summary** | Auto-generated executive summary of release changes |
| 👥 **Contributor Attribution** | Lists contributors for each release section |
| 🔗 **Multi-Platform Links** | Supports GitHub, GitLab, Bitbucket, and Gitea |

---

## 🚀 Quick Start

### Basic Usage

```yaml
name: Generate Changelog
on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for tag history

      - name: Generate Changelog
        uses: a918124259a/conventional-changelog-action@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

### Full Configuration

```yaml
- name: Generate Changelog
  uses: your-org/changelog-generator@v1
  with:
    # Required
    token: ${{ secrets.GITHUB_TOKEN }}

    # Tag configuration
    tag-prefix: 'v'                          # Default: 'v'
    release-branch: 'main'                   # Default: current branch

    # Output configuration
    output-file: 'CHANGELOG.md'              # Default: 'CHANGELOG.md'
    header: |
      # My Project Changelog

      All notable changes will be documented here.

    # Commit filtering
    include-commits: 'feat,fix,perf,docs'    # Default: all conventional types
    exclude-types: 'chore,style'             # Exclude noisy types

    # Formatting
    group-by-scope: 'true'                   # Group by scope within types
    include-links: 'true'                    # Link commits and issues
    include-breaking: 'true'                 # Surface breaking changes
    unreleased-label: 'Unreleased'           # Label for unreleased section
    compare-url: 'https://github.com/org/repo/compare/{{from}}...{{to}}'

    # Automation
    create-release: 'true'                   # Auto-create GitHub Release

    # ★ Premium features (support us on GitHub Sponsors!)
    premium-template: 'modern'               # Template theme
    premium-emojis: 'true'                   # Emoji decorations
    premium-summary: 'true'                  # AI-style summary
    premium-contributors: 'true'             # Contributor listing
    premium-links: 'github'                  # Platform link style
```

---

## 📋 Inputs Reference

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `token` | No | `${{ github.token }}` | GitHub token for API access |
| `tag-prefix` | No | `v` | Prefix for version tags |
| `output-file` | No | `CHANGELOG.md` | Path to output file |
| `header` | No | *(see docs)* | Custom header text |
| `release-branch` | No | *current branch* | Branch to scan for tags |
| `include-commits` | No | *all types* | Comma-separated commit types to include |
| `exclude-types` | No | *(empty)* | Comma-separated types to exclude |
| `group-by-scope` | No | `false` | Group commits by scope |
| `include-links` | No | `true` | Include commit/issue links |
| `include-breaking` | No | `true` | Flag breaking changes |
| `create-release` | No | `false` | Auto-create GitHub Release |
| `unreleased-label` | No | `Unreleased` | Label for unreleased section |
| `compare-url` | No | *(auto)* | Custom compare URL template |
| `premium-template` | No | `classic` | ★ Sponsors: template theme |
| `premium-emojis` | No | `false` | ★ Sponsors: emoji decorations |
| `premium-summary` | No | `false` | ★ Sponsors: AI executive summary |
| `premium-contributors` | No | `false` | ★ Sponsors: contributor listing |
| `premium-links` | No | `github` | ★ Sponsors: platform link style |

---

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `changelog` | Full generated changelog content |
| `version` | Latest detected version number |
| `release-notes` | Changelog entry for the latest release |

### Example: Create Release with Changelog

```yaml
name: Release
on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate Changelog
        id: changelog
        uses: a918124259a/conventional-changelog-action@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          create-release: 'true'
          include-commits: 'feat,fix,perf,breaking'
          premium-emojis: 'true'
          premium-summary: 'true'

      - name: Commit Changelog
        run: |
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add CHANGELOG.md
          git commit -m "docs: update changelog [skip ci]" || true
          git push

      - name: Print Summary
        run: |
          echo "### 📋 Changelog Generated"
          echo "**Version:** ${{ steps.changelog.outputs.version }}"
          echo ""
          echo "${{ steps.changelog.outputs.release-notes }}"
```

---

## 📄 Generated Changelog Example

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Features
- ✨ Add user authentication flow ([a1b2c3d](https://github.com/org/repo/commit/a1b2c3d))
- ✨ Implement dark mode toggle ([e4f5g6h](https://github.com/org/repo/commit/e4f5g6h)) — @octocat

### Bug Fixes
- 🐛 Fix login timeout issue (#42) ([i7j8k9l](https://github.com/org/repo/commit/i7j8k9l))
- 🐛 Resolve memory leak in background worker ([m0n1o2p](https://github.com/org/repo/commit/m0n1o2p))

## [1.2.0] - 2025-03-15

### ⚠️ Breaking Changes
- 💥 Drop support for Node 16

### Features
- ✨ Add GraphQL API support
```

---

## 💖 Sponsorship & Monetization

This action is **free and open source** for basic use. Premium features require sponsorship to sustain development and provide priority support.

### Why Sponsor?

- 🌟 **Unlock premium features** — emojis, summaries, templates, contributors
- 🎯 **Priority support** — direct help via GitHub Issues
- 🏆 **Your logo on README** — featured sponsor showcase
- 🚀 **Shape the roadmap** — vote on upcoming features
- 🔒 **Enterprise-ready** — guaranteed stability and SLA

### Premium Tiers

| Tier | Price | Features |
|------|-------|----------|
| **Basic** | Free | All standard features, unlimited repos |
| **⭐ Supporter** | $5/mo | Emojis + Summary + Contributor attributions |
| **🚀 Pro** | $15/mo | All premium features + priority support |
| **🏢 Enterprise** | Custom | Custom templates, SLA, dedicated support |

[→ Become a Sponsor](https://github.com/sponsors/a918124259a)

---

## 🤝 Contributing

Contributions are welcome! Please ensure your commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new feature
fix: resolve bug in parser
docs: update README
feat(api)!: breaking API change
```

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">Made with ❤️ by the Changelog Generator Team</p>
