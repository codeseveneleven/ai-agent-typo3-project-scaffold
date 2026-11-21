# TYPO3 AI Scaffold

A TYPO3 v14 project skeleton that is set up to be worked on **together with AI agents**
(Claude Code, and any other client that reads `.mcp.json` and `.agents/skills`).

The repository is not a finished website. It is the starting point for one: a clean
Composer-based TYPO3 installation plus the tooling that gives an agent

- **eyes on TYPO3**: MCP servers that answer questions about *this* installation (version,
  extensions, TCA, sites, documentation) and let the agent read and write content,
- **know-how**: skills for TYPO3 development, web best practices and spec-driven work,
- **rules**: a `CLAUDE.md` that tells the agent what it may and may not do,
- **a process**: [OpenSpec](https://openspec.dev) for planning changes before they are built.

Everything is wired up by one script, [`ai-setup.sh`](ai-setup.sh).

> **Planning to commit and push this as your own project?** Read
> [Turning the scaffold into your project](#turning-the-scaffold-into-your-project) first:
> remove the scaffold's `.git` folder, review `.gitignore` and adapt `composer.json`.

---

## Table of contents

1. [How the pieces fit together](#how-the-pieces-fit-together)
2. [Requirements](#requirements)
3. [Getting started](#getting-started)
4. [What `ai-setup.sh` does](#what-ai-setupsh-does)
5. [Repository layout](#repository-layout)
6. [MCP servers](#mcp-servers)
7. [Skills](#skills)
8. [Working with an agent](#working-with-an-agent)
9. [Rules for agents (`CLAUDE.md`)](#rules-for-agents-claudemd)
10. [The CMS MCP server and workspaces](#the-cms-mcp-server-and-workspaces)
11. [DDEV or local PHP](#ddev-or-local-php)
12. [Commit conventions](#commit-conventions)
13. [Turning the scaffold into your project](#turning-the-scaffold-into-your-project)
14. [Customizing the scaffold](#customizing-the-scaffold)
15. [Troubleshooting](#troubleshooting)

---

## How the pieces fit together

```
                         ┌──────────────────────────────┐
                         │          AI agent            │
                         │  (Claude Code, Cursor, ...)  │
                         └───────┬──────────┬───────────┘
                    reads rules  │          │  calls tools
              ┌──────────────────┘          └──────────────────────┐
              ▼                                                    ▼
   CLAUDE.md                .agents/skills/                   .mcp.json
   project rules            task knowledge                    MCP servers
                            (typo3-*, openspec-*,             ├─ typo3-dev-companion  read-only TYPO3 knowledge
                             modern-web-guidance)             ├─ CMS                  read/write content (workspace)
                                                              ├─ PHPStorm             IDE: inspections, run configs, debugger
                                                              └─ Figma                design input
                                       │
                                       ▼
                               openspec/  (propose → apply → archive)
                                       │
                                       ▼
                               packages/sitepackage  ← the code the agent writes
                               TYPO3 v14 + Content Blocks + Visual Editor
```

The agent never has to guess how this TYPO3 installation looks: it asks
`typo3-dev-companion`. It never edits content blindly: the `CMS` server works in a dedicated
workspace. It does not improvise a process: OpenSpec and the skills describe one.

## Requirements

| Tool | Why | Notes |
|------|-----|-------|
| PHP 8.5 CLI | runs TYPO3 and the companion | Composer is configured with `platform.php = 8.5.0`. Not needed on the host when using DDEV. |
| [Composer](https://getcomposer.org) | installs TYPO3 and the companion | |
| MySQL/MariaDB | the TYPO3 database | `ai-setup.sh` talks to it through `typo3 database:import --interactive`. |
| git | clones the companion if it is not installed | |
| Node.js (`npx`) | runs `modern-web-guidance` | Installed by the script via brew/apt/dnf/apk if missing. |
| curl | installs OpenSpec if it is missing | |
| [DDEV](https://ddev.com) | *optional*, container-based development | Used automatically when a `.ddev/` folder exists. |
| PhpStorm, Figma desktop | *optional* | Only needed if you want the `PHPStorm` / `Figma` MCP servers to connect. |

## Getting started

### 1. Install and set up TYPO3 first

`ai-setup.sh` refuses to run on a project without a working TYPO3, because it needs the
database. Do this before anything else:

```bash
# plain Composer setup
composer install
php vendor/bin/typo3 setup

# or, with DDEV (once a .ddev/ folder exists)
ddev composer install
ddev typo3 setup
```

You are ready when both `vendor/bin/typo3` and `config/system/settings.php` exist.

### 2. Run the AI setup

```bash
./ai-setup.sh
```

The script is safe to run again; see [what it does](#what-ai-setupsh-does) for what is
skipped and what is repeated. Some steps (`openspec init`, `modern-web-guidance`) print
their own output and may ask questions, so run it in a terminal.

### 3. Open the project in your agent

Start the agent from the project root. It picks up `CLAUDE.md`, `.mcp.json` and the skills
automatically. Approve the MCP servers when asked (`typo3-dev-companion`, `CMS`, `Figma`,
`PHPStorm`). A server that is not running (e.g. Figma when the desktop app is closed) is
simply unavailable; the others keep working.

## What `ai-setup.sh` does

| # | Step | Behaviour on re-run |
|---|------|---------------------|
| – | **Check TYPO3.** `.ddev/` present → DDEV setup (requires `ddev`), otherwise Composer + local `php`. Requires `vendor/bin/typo3` and `config/system/settings.php`, otherwise prints what is missing and exits with code 1. | always runs |
| 0 | **`.mcp.json`**: copied from `.mcp-template.json`. | skipped if `.mcp.json` exists |
| 1 | **typo3-dev-companion**: used from `$PATH` if available, otherwise cloned to `./typo3-dev-companion` and installed with Composer. Then `typo3-dev-companion install --agent=claude` writes its MCP entry and publishes its task skills for Claude Code. | reuses existing clone; `install` runs again |
| 1 | **npx**: if missing, Node.js is installed with brew, apt-get, dnf or apk. | skipped if present |
| 2 | **`npx modern-web-guidance@latest install`**: installs the web-guidance skill. | reinstalls (overwrites) |
| 3 | **OpenSpec**: installed with the official install script if missing, then `openspec init`. | `init` refreshes the generated skills |
| 4 | **`IJ_MCP_SERVER_PROJECT_PATH`** in `.mcp.json` is set to the absolute project path (via `jq`, `perl` or `python`, whichever exists). | always runs |
| 5 | **Workspace**: if `sys_workspace` is empty, inserts the workspace `Updates` (`pid=0`, `color=orange`, `db_mountpoints=1`). | skipped if any workspace exists |

The script stops at the first error (`set -euo pipefail`).

## Repository layout

```
.
├── ai-setup.sh              One-shot setup of the AI tooling (see above)
├── .mcp-template.json       Template for the (git-ignored) .mcp.json
├── CLAUDE.md                Rules for the agent (German, see below)
├── myprompt.txt             Example task prompt: implement a Figma design as Content Blocks
├── composer.json            TYPO3 v14.3 + Content Blocks + Visual Editor + dev tooling
├── openspec/
│   └── config.yaml          Project context handed to OpenSpec artifacts
├── packages/
│   └── sitepackage/         The site package: the code agents write goes here
├── config/                  sites/ and system/settings.php           (git-ignored)
├── public/  vendor/  var/   Web root, dependencies, caches/logs      (git-ignored)
│
│   — generated by ai-setup.sh, git-ignored —
├── .mcp.json                MCP server configuration
├── .agents/skills/          Skills for all agent clients (typo3-*, openspec-*, ...)
├── .claude/                 Claude Code settings and skill links
├── skills-lock.json         Pinned versions of installed skills
└── openspec/changes|specs/  Work in progress and living specs
```

What is tracked in git is the *recipe* (script, template, rules, `composer.json`); what
the recipe produces is not. That keeps the repository small and lets everyone regenerate
the AI tooling in their own environment, with their own absolute paths and ports.

> `composer.lock` and the whole `config/` directory are also git-ignored. If you turn this
> scaffold into a real project, adjust `.gitignore` so installations are reproducible and
> the site configuration is versioned (but never `config/system/settings.php`). See
> [Turning the scaffold into your project](#turning-the-scaffold-into-your-project).

### What is installed (`composer.json`)

- **TYPO3 14.3** with the usual system extensions, including `workspaces` (required by the
  CMS MCP server) and `form`.
- **`friendsoftypo3/content-blocks`**: content elements, page types and records defined as
  YAML + Fluid.
- **`friendsoftypo3/visual-editor`**: frontend editing. Content Blocks created here are
  expected to work with it (see `openspec/config.yaml`).
- **`georgringer/news`**, **`helhum/typo3-console`**, **`helhum/dotenv-connector`**.
- **`hn/typo3-mcp-server`** (dev): provides the `CMS` MCP server (`typo3 mcp:server`).
- Dev tooling: PHPStan (`saschaegerer/phpstan-typo3`), Rector (`ssch/typo3-rector`),
  `typo3/coding-standards`, `typo3/cms-styleguide`.
- `packages/*` is a Composer path repository, so the `sitepackage` is installed from the
  `packages/` folder.

## MCP servers

Defined in `.mcp-template.json` (and `typo3-dev-companion`, added by its own installer).

| Server | Transport | Purpose |
|--------|-----------|---------|
| `typo3-dev-companion` | stdio | **Read-only** knowledge about *this* TYPO3: version, extensions, sites, TCA/schema, FlexForms, icons, labels, changelogs, documentation, coding guidelines and task guides. The agent starts every TYPO3 task here. |
| `CMS` | stdio (`php vendor/bin/typo3 mcp:server`) | Reads and **writes content** in the TYPO3 backend, bound to a workspace. See [below](#the-cms-mcp-server-and-workspaces). |
| `PHPStorm` | SSE, `127.0.0.1:64442` | IDE access: inspections, run configurations, debugger, database tools, refactorings. Needs PhpStorm running with its MCP server enabled. The `IJ_MCP_SERVER_PROJECT_PATH` header tells it which open project to use; `ai-setup.sh` fills it in. |
| `Figma` | HTTP, `127.0.0.1:3845` | Reads the selected designs (desktop, tablet and mobile frames). Needs the Figma desktop app with its MCP server enabled. |

Servers listed in `.claude/settings.local.json` under `enabledMcpjsonServers` are enabled
for Claude Code without asking each time.

> Under DDEV, point the `CMS` entry at the container, e.g. command `ddev` with args
> `["typo3", "mcp:server"]`, since PHP and the database live inside it.

## Skills

Skills are packaged instructions the agent loads when a task matches. They live in
`.agents/skills/` (and are linked from `.claude/skills/` for Claude Code).

| Source | Skills | Installed by |
|--------|--------|--------------|
| `typo3-dev-companion` | `typo3-sitepackage-development`, `typo3-content-element-development`, `typo3-backend-module-development`, `typo3-extension-testing`, `typo3-extension-health`, `typo3-extension-upgrade`, `typo3-extension-documentation`, `typo3-development-installation`, `typo3-distribution-content`, `typo3-extension-asset-build`, `typo3-extension-patch-review`, `typo3-core-*` (issue triage, patch checkout / development / review) | `typo3-dev-companion install` |
| OpenSpec | `openspec-propose`, `-apply-change`, `-archive-change`, `-explore`, `-sync-specs`, `-update-change` | `openspec init` |
| Google Chrome | `modern-web-guidance`: current HTML/CSS/JS practice, so the agent does not reproduce obsolete patterns | `npx modern-web-guidance@latest install` |

Use `typo3-dev-companion update` to refresh the TYPO3 skills after the project gained new
extensions, and re-run `./ai-setup.sh` to refresh everything.

## Working with an agent

### Spec-driven changes with OpenSpec

For anything larger than a one-line fix, plan before building:

1. **Explore** (optional): think a problem through with the agent
   (`/openspec-explore`).
2. **Propose**: describe what you want; the agent writes the proposal, design, specs and
   task list (`/openspec-propose "your idea"`). Review and edit these files.
3. **Apply**: the agent works through the tasks (`/openspec-apply-change`).
4. **Archive**: finalize the change and fold its specs into the living specs
   (`/openspec-archive-change`).

Project-wide context for these artifacts goes into `openspec/config.yaml` (currently: TYPO3
v14, Content Blocks, Visual Editor compatibility, ticket ID from the PhpStorm task context).
Keep it to constraints an agent cannot infer from the code.

### Design to Content Blocks

[`myprompt.txt`](myprompt.txt) is a ready-made prompt for the main use case of this scaffold:
turning a Figma design into TYPO3. It tells the agent to

- read the selected frames through the **Figma** MCP,
- implement content elements and page layouts as **Content Blocks** in `packages/sitepackage`
  with plain CSS, a site set and typed site settings,
- make all texts editable with the **Visual Editor**, add backend previews, use restricted RTE
  presets,
- self-host fonts, check for horizontal overflow at 375/800/1280 px and for axe violations,
- create demo pages and content through the **CMS** MCP.

Adapt it per project and paste it (or point to it) at the start of a session.

### Good habits

- Ask the agent to **state its plan** before multi-file changes (the rules require it).
- Let it query `typo3-dev-companion` instead of relying on memory: TYPO3 changes a lot
  between major versions.
- Review the diff; commit yourself or explicitly tell the agent to.
- Keep changes in `packages/*`. Never edit `vendor/`, `var/` or generated files.

## Rules for agents (`CLAUDE.md`)

[`CLAUDE.md`](CLAUDE.md) is written in German for the team and is binding for the agent.
In short:

- **Git**: never commit, push, merge, rebase or tag on its own; no destructive git commands
  without asking; commit messages follow the TYPO3 format.
- **Scope**: change only what was asked, name the plan before larger changes, no
  `composer update/require` and no new dependencies without asking.
- **Hands off** `vendor/`, `var/` and generated files.
- **Environment** (rules 8 and 9): with DDEV, run PHP, TYPO3 CLI, Composer and tests through
  DDEV (`ddev exec`, `ddev typo3`, `ddev composer`); in a classic Composer setup, run them
  with the local command line.
- **Data and external systems**: no database changes (migrations, deletions, imports) or
  snapshot overwrites without asking; no actions against external systems (mail, payment,
  stage/production, deployment) without explicit approval; never print or commit `.env` or
  credentials.
- **Quality**: PHP 8.4 / TYPO3 style of the surrounding extension; run PHPStan and
  php-cs-fixer on changed files and report honestly; add or describe a test for bug fixes.
- **Communication**: answer in the language you were addressed in; code, comments and
  commit messages always in English; ask instead of guessing.

## The CMS MCP server and workspaces

The `CMS` server (from `hn/typo3-mcp-server`) can only act inside a **workspace**. This is
deliberate: everything the agent creates or changes is a draft that an editor can review
and publish (or discard) in the backend, and the live site is untouched.

`ai-setup.sh` therefore makes sure a workspace exists. If `sys_workspace` is empty it creates
**Updates** (`pid=0`, `color=orange`, `db_mountpoints=1`, i.e. the page tree below
uid 1 is mounted). If you already have workspaces, nothing is created.

The step talks to the database through `typo3 database:import --interactive`, feeding SQL on
stdin; this reuses TYPO3's own connection settings, so no credentials are read by the
script.

To look at what the agent did: open the TYPO3 backend, switch to the `Updates` workspace in
the workspace selector, and review the *Workspaces* module.

> **Hint: autosave in the Visual Editor needs a workspace too.** Editing in the frontend with
> `friendsoftypo3/visual-editor` also works in the live workspace, but **autosave** is only
> offered inside a workspace such as `Updates`. For live editing with autosave, switch to
> the `Updates` workspace first. Editors and the agent then work in the same workspace, and
> what is changed there stays a draft until it is published.

## DDEV or local PHP

`ai-setup.sh` detects the environment by looking for a `.ddev/` folder, and the agent rules
in `CLAUDE.md` (rules 8 and 9) distinguish the same two cases:

| | `.ddev/` exists | no `.ddev/` |
|---|---|---|
| Requires | `ddev` | `php` |
| TYPO3 CLI | `ddev typo3 …` | `php vendor/bin/typo3 …` |
| Composer | `ddev composer …` | `composer …` |

The project folder is mounted into the DDEV container, so `ai-setup.sh` checks
`vendor/bin/typo3` and `config/system/settings.php` from the host.

Note that the MCP entries in `.mcp-template.json` use the host's PHP. When using DDEV, change
the `CMS` entry to run inside the container (see [MCP servers](#mcp-servers)).

## Commit conventions

Commit messages follow the
[TYPO3 core format](https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/ApiOverview/VersionControl/Index.html):

```
[FEATURE|BUGFIX|TASK] Short imperative summary in English

Longer explanation of what and why.

Resolves: #<ticket>
```

When the agent runs inside PhpStorm, it reads the ticket ID from the task context. `[skip-ci]`
is only added on request. The agent commits only when you tell it to.

## Turning the scaffold into your project

This repository is a template. Before you commit and push it somewhere as a real project,
do the following, in this order.

1. **Remove the scaffold's git history and start your own.** The existing `.git` folder
   belongs to the scaffold; pushing it would carry its history and remote into your project.

   ```bash
   rm -rf .git
   git init
   ```

   Remove it only if you really want to detach from the scaffold: the history is gone
   afterwards. Clone or copy the scaffold elsewhere first if you may want to pull in later
   improvements.

2. **Check `.gitignore` before the first `git add`.** It is tuned for *using* the scaffold,
   not for shipping a project. Currently it ignores:

   | Entry | Why it may need to change |
   |-------|---------------------------|
   | `config/` | This contains `config/sites/` (site configuration, **should be versioned**) and `config/system/settings.php` (database credentials and secrets, **must not be pushed**). Ignore only `config/system/settings.php` (or the whole `config/system/`) and track the rest. |
   | `composer.lock` | Should be committed in a project so every installation gets identical versions. |
   | `.mcp.json`, `skills-lock.json`, `.agents`, `.claude` | Generated by `ai-setup.sh` with local paths and ports. Keep them ignored unless the whole team should share them. |
   | `openspec/changes/`, `openspec/specs/` | Your OpenSpec work. Decide whether specs belong in the repository; many teams track them. |
   | `public/`, `vendor/`, `var/`, `htdocs/` | Generated or installed. Keep ignored, but make sure a deployment builds them (`composer install`). |

   Afterwards run `git status` and look through the list of files that would be added.
   Nothing with credentials (`settings.php`, `.env`) and nothing generated should be in
   it.

3. **Adapt `composer.json`.** It is a test setup, not a project definition:
   - `name` (`test1/typo3`) and `description` (`Test MCP TYPO3`): use your vendor/project name.
   - `config.platform.php` pins `8.5.0`. Set it to the PHP version your servers run.
   - `repositories` points to `./packages/*`; adapt it when you add or rename packages, and
     require your site package (e.g. `vendor/sitepackage`) once it exists.
   - Review `require`: remove extensions you do not need (e.g. `news`, `indexed-search`,
     `reactions`, `webhooks`) and keep what the project uses. Version constraints use
     `^14.3`: tighten them if you want controlled upgrades.
   - `require-dev` holds the MCP server (`hn/typo3-mcp-server`) and quality tools. Keep
     the MCP server in `require-dev` so it is not installed on production
     (`composer install --no-dev`).
   - Run `composer update` afterwards to refresh the lock file, then commit
     `composer.json` and `composer.lock` together.

4. **Adapt the rest of the scaffold's identity:** replace this README with your project's
   own, review `CLAUDE.md` and `openspec/config.yaml` for rules that do not apply to you,
   and decide whether `myprompt.txt` stays.

5. **Then commit and push.**

   ```bash
   git add .
   git status        # one more look
   git commit -m "[TASK] Initial project setup"
   git remote add origin <your-repository-url>
   git push -u origin main
   ```

Anyone who clones the new repository then runs `composer install`, sets TYPO3 up, and runs
`./ai-setup.sh` to recreate the AI tooling.

## Customizing the scaffold

- **Agent rules**: edit `CLAUDE.md`.
- **MCP servers**: edit `.mcp-template.json` for everyone (it is tracked); edit `.mcp.json`
  for yourself (it is ignored). Remember `ai-setup.sh` only copies the template if
  `.mcp.json` does not exist, so delete `.mcp.json` to regenerate it from the template.
- **OpenSpec context**: `openspec/config.yaml`; add per-artifact rules there too.
- **Setup steps**: `ai-setup.sh` is plain bash, one commented section per step.
- **Task prompts**: keep reusable prompts like `myprompt.txt` in the repository.
- **Start a real project**: follow
  [Turning the scaffold into your project](#turning-the-scaffold-into-your-project).

## Troubleshooting

**`WARNING: TYPO3 has not been installed and set up yet`**
Run `composer install` and `typo3 setup` first (see [Getting started](#getting-started)).
The message names the file that is missing.

**An MCP server shows as failed or unavailable**
- `CMS`: needs `vendor/` (`composer install`) and a configured database; under DDEV it must
  run through `ddev`.
- `PHPStorm`: PhpStorm must be running with the MCP server enabled; check that the port in
  `.mcp.json` matches the IDE's setting.
- `Figma`: open the Figma desktop app and enable its MCP server.
- `typo3-dev-companion`: run `typo3-dev-companion help`; re-run `typo3-dev-companion install`
  in the project root.

**`Could not query sys_workspace`**
EXT:workspaces is not installed/active, or the database is not set up. Check
`composer.json`, run `typo3 setup`, and try again.

**`npx` / `openspec` not found after the script installed them**
The current shell has not picked up the new `$PATH`. Open a new terminal and re-run
`./ai-setup.sh`.

**The agent does not know my skills / MCP servers**
Start the agent from the project root, check that `.mcp.json` and `.agents/skills/` exist
(re-run `./ai-setup.sh` if not), and approve the MCP servers in the client.

**I deleted `.mcp.json` and lost my edits**
It is not in git. Keep durable changes in `.mcp-template.json`.
