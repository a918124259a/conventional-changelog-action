# Automate Your CHANGELOG with AI: A Complete Guide

**Let's be honest — nobody *enjoys* writing changelogs.**

You ship a release, you're excited about the new features, and then... you stare at a blank `CHANGELOG.md`. You tell yourself "I'll write it later." Later never comes. Your changelog stays empty, your users are confused, and your open-source project looks abandoned.

This guide will show you how to **automate your entire changelog process** using Conventional Commits and a GitHub Action that generates beautiful, categorized changelogs on every release. No manual work. No forgotten entries. Just clean, professional changelogs every time.

---

## What We're Building

By the end of this guide, you'll have:

- ✅ **Automatic changelog generation** triggered on every push or release
- ✅ **Smart categorization** — features, fixes, breaking changes, docs, refactors
- ✅ **Semantic versioning** from git tags
- ✅ **GitHub Releases integration** — auto-create releases with full notes
- ✅ **Premium features** (emojis, AI summaries, contributor attribution) for sponsors
- ✅ **A GitHub Marketplace action** your whole team can use

---

## Why Conventional Commits?

The secret sauce is [Conventional Commits](https://www.conventionalcommits.org/) — a lightweight convention on top of commit messages. Instead of:

```
fixed the thing
```

You write:

```
fix(auth): resolve login timeout for EU users
```

This small change unlocks **massive automation power**. Your commit messages become machine-readable, allowing tools to:

1. Automatically determine the next semantic version (`major.minor.patch`)
2. Group changes into logical categories
3. Generate human-readable changelogs without any manual effort

### Commit Types We Support

| Type | Description | Example |
|------|-------------|---------|
| `feat` | A new feature | `feat: add dark mode toggle` |
| `fix` | A bug fix | `fix: resolve login timeout` |
| `perf` | Performance improvement | `perf: optimize database queries` |
| `docs` | Documentation only | `docs: update API reference` |
| `refactor` | Code restructuring | `refactor: extract auth module` |
| `test` | Adding tests | `test: add unit tests for parser` |
| `chore` | Maintenance | `chore: bump dependencies` |

And for breaking changes, just add `!` or a `BREAKING CHANGE` footer:

```
feat(api)!: remove deprecated v1 endpoints
```

---

## Getting Started in 30 Seconds

Here's the minimal setup. Add this workflow to `.github/workflows/changelog.yml`:

```yaml
name: Generate Changelog
on:
  push:
    branches: [main]

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

That's it. **Three minutes from zero to a fully automated changelog.**

On every push to main, the action will:
1. Scan all your git tags and commits
2. Group them by type (`feat`, `fix`, `perf`, `docs`, etc.)
3. Generate a beautiful `CHANGELOG.md`
4. (Optionally) auto-create a GitHub Release

---

## Full Configuration

Want more control? Here's everything you can configure:

```yaml
- name: Generate Changelog
  uses: a918124259a/conventional-changelog-action@v1
  with:
    # Required
    token: ${{ secrets.GITHUB_TOKEN }}

    # Tag configuration
    tag-prefix: 'v'                          # Default: 'v'
    release-branch: 'main'

    # Output configuration
    output-file: 'CHANGELOG.md'
    header: |
      # My Project Changelog

      All notable changes will be documented here.

    # Commit filtering
    include-commits: 'feat,fix,perf,docs'
    exclude-types: 'chore,style'

    # Formatting
    group-by-scope: 'true'
    include-links: 'true'
    include-breaking: 'true'
    unreleased-label: 'Unreleased'

    # Automation
    create-release: 'true'                   # Auto-create GitHub Release

    # ★ Premium (Sponsor-only) features
    premium-template: 'modern'
    premium-emojis: 'true'
    premium-summary: 'true'
    premium-contributors: 'true'
    premium-links: 'github'
```

### Input Reference

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `token` | No | `${{ github.token }}` | GitHub token for API access |
| `tag-prefix` | No | `v` | Prefix for version tags |
| `output-file` | No | `CHANGELOG.md` | Path to output file |
| `header` | No | *(standard)* | Custom header text |
| `release-branch` | No | *current* | Branch to scan |
| `include-commits` | No | *all types* | Types to include |
| `exclude-types` | No | *(empty)* | Types to exclude |
| `group-by-scope` | No | `false` | Group by scope |
| `include-links` | No | `true` | Link commits/issues |
| `include-breaking` | No | `true` | Flag breaking changes |
| `create-release` | No | `false` | Auto-create release |
| `unreleased-label` | No | `Unreleased` | Label for unreleased |
| `compare-url` | No | *(auto)* | Custom compare URL |

---

## Advanced: Auto-Commit + Release in One Workflow

Here's a production-grade workflow that generates the changelog, commits it back to the repo, and creates a GitHub Release — all in one pipeline:

```yaml
name: Release
on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

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
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
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

The action exposes three outputs you can use downstream:
- `changelog` — Full generated changelog content
- `version` — Latest detected version number
- `release-notes` — Changelog entry for the latest release

---

## Sample Output

Here's what a real generated changelog looks like:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Features
- ✨ Add user authentication flow ([a1b2c3d](https://github.com/org/repo/commit/a1b2c3d))
- ✨ Implement dark mode toggle ([e4f5g6h](https://github.com/org/repo/commit/e4f5g6h))

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

## Premium Features for Sponsors

The action is **free and open source** for all standard features. Premium features are reserved for GitHub Sponsors to help sustain development.

### Feature Overview

| Feature | Free | Supporter ($5/mo) | Pro ($15/mo) |
|---------|------|-------------------|--------------|
| Standard changelog gen | ✅ | ✅ | ✅ |
| Custom templates | ❌ | ✅ | ✅ |
| Emoji decorations | ❌ | ✅ | ✅ |
| AI-style summaries | ❌ | ✅ | ✅ |
| Contributor attribution | ❌ | ✅ | ✅ |
| Multi-platform links | ❌ | ✅ | ✅ |
| Priority support | ❌ | ❌ | ✅ |
| Enterprise SLA | ❌ | ❌ | Custom |

### Premium Templates

Choose from five themes to match your project's style:
- **classic** — The original Keep a Changelog format
- **minimal** — Clean, no-frills output
- **modern** — Contemporary design with section icons
- **detailed** — Full metadata, stats, and cross-references
- **json** — Machine-readable JSON output

### Why Sponsor?

- 🌟 **Unlock premium features** — emojis, AI summaries, custom templates
- 🎯 **Priority support** — direct help via GitHub Issues
- 🏆 **Your logo on README** — featured sponsor showcase
- 🚀 **Shape the roadmap** — vote on upcoming features
- 🔒 **Enterprise-ready** — guaranteed stability and SLA

[→ Become a Sponsor on GitHub](https://github.com/sponsors/a918124259a)

---

## Best Practices for Amazing Changelogs

### 1. Write Good Commit Messages

```bash
# ❌ Bad
git commit -m "fixed stuff"

# ✅ Good
git commit -m "fix(auth): resolve token refresh race condition"

# ✅ With breaking change
git commit -m "feat(api)!: remove deprecated v1 endpoints"
```

### 2. Use Scopes Consistently

Scopes group related changes within a type:
```
feat(auth): add OAuth2 login
feat(auth): implement session refresh
fix(api): correct pagination offset
fix(api): handle null response body
```

### 3. Keep Commits Atomic

Each commit should do one thing. This makes the changelog readable and makes reverts clean.

### 4. Tag Your Releases

Tags are how the action knows what changed between versions:
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 5. Mark Breaking Changes

Always use the `!` notation for breaking changes:
```
feat(config)!: restructure configuration format
```

---

## Real-World Impact

Teams that switch to automated changelogs report:

- **80% less time** spent on release documentation
- **Zero** forgotten changelog entries
- **Higher user satisfaction** — users can easily find what changed
- **Better open-source health** — active changelogs signal an active project
- **Easier debugging** — teams can trace regressions to specific releases

---

## Get Started Today

1. **Star the repo** on GitHub: [a918124259a/conventional-changelog-action](https://github.com/a918124259a/conventional-changelog-action)
2. **Add the workflow** to your repository (copy the YAML above)
3. **Tag your first release** with `git tag v1.0.0 && git push origin v1.0.0`
4. **Watch the magic happen** as your changelog generates automatically
5. **Become a sponsor** to unlock premium features: [github.com/sponsors/a918124259a](https://github.com/sponsors/a918124259a)

---

### 📦 Marketplace

Available on the [GitHub Marketplace](https://github.com/marketplace/actions/conventional-changelog-action)

### 🔗 Quick Links

- [GitHub Repository](https://github.com/a918124259a/conventional-changelog-action)
- [GitHub Release v1.0.0](https://github.com/a918124259a/conventional-changelog-action/releases/tag/v1.0.0)
- [Documentation](https://github.com/a918124259a/conventional-changelog-action#readme)
- [Sponsor the Project](https://github.com/sponsors/a918124259a)

---

<p align="center">
  <strong>Happy shipping! 🚀</strong>
</p>
