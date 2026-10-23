# workbench-shell

Opinionated shell/editor/prompt layer for the
[`workbench`](https://github.com/GingerGraham/workbench-core) ecosystem.

An **ecosystem module** (`workbench-core` ARCHITECTURE.md §2). Requires
`workbench-core` only — it works without any other workbench module, and
alongside a shell setup of your own (see "Using workbench-shell alongside
another shell setup" below):

```sh
wb add shell
# or, as part of a bundle:
wb install --bundle workstation
```

## What this gives you

- General-purpose aliases (`shell/aliases.sh`) and bash/zsh-specific
  interactive tweaks (`shell/bash.sh`/`shell/zsh.sh`) — history, completion,
  key bindings.
- **Prompt engine**, whichever you have installed, with a self-electing
  priority order: **oh-my-posh > starship > oh-my-zsh**. Exactly one wins;
  each file (`shell/omp.sh`/`shell/starship.sh`/`shell/omz.sh`) checks for
  the higher-priority engines and no-ops if one is present. See
  [Prompt engine election](#prompt-engine-election) below.
- zsh plugins: autosuggestions + syntax highlighting (`shell/zsh-plugins.sh`).
- `direnv` and `fzf` shell integration (`shell/direnv.sh`/`shell/fzf.sh`),
  plus `direnv-init-project` to scaffold a starter `.envrc`.
- `EDITOR`/`VISUAL`/`PAGER`/`BAT_THEME` defaults, with a self-electing
  `VISUAL` priority order — `code-insiders > code > nvim > vim`
  (`shell/editors.sh`).
- tmux and vim defaults, as a workbench block at the top of your own
  tmux config and vimrc — anything you set in your file wins
  (workbench-core D82).
- `starship.toml` and `direnv.toml` — kept current until you edit them,
  never touched once you have (workbench-core D81).
- `install-oh-my-posh`, `install-starship`, `install-oh-my-zsh`,
  `install-zsh`, `install-zsh-default-shell`, `install-zsh-plugins`,
  `install-direnv`, `install-fzf`, `install-neovim` — via `wb tools update`.

## Prompt engine election

`workbench-core`'s loader has no hardcoded prompt-engine logic (principle
4 — no special-casing baked into the engine). Instead, each prompt-engine
file is self-electing:

- `shell/omp.sh` — proceeds if `oh-my-posh` is on `PATH`. Always wins if present.
- `shell/starship.sh` — no-ops if `oh-my-posh` is present; otherwise
  proceeds if `starship` is on `PATH`.
- `shell/omz.sh` — no-ops if `oh-my-posh` or `starship` is present;
  otherwise proceeds if the shell is zsh and `~/.oh-my-zsh` exists.

oh-my-zsh is set to `reminder` update mode: it shows a notice every 7
days rather than pulling its own `master` branch unattended. Update
deliberately with `omz update` (or `install-oh-my-zsh`, which runs it).

Set `WORKBENCH_OVERRIDE_PROMPT_ENGINE` to `omp`, `starship`, or `omz` in
`~/.config/workbench/local/overrides/shell.sh` (see below) to force a
specific engine regardless of what's installed or this priority order.
If the named engine isn't actually installed, the override falls through
to no prompt engine at all — never silently back to this election.

`VISUAL` has its own priority order — `code-insiders > code > nvim >
vim` (GUI-only for the first two; `nvim` and `vim` are checked
regardless of `DISPLAY`/`WAYLAND_DISPLAY`) — set by `shell/editors.sh`.
It already has a natural escape hatch: set `VISUAL` yourself in
`overrides.sh` and it wins outright, no `WORKBENCH_OVERRIDE_*` needed.

The manifest lists them in this priority order (`omp` → `starship` → `omz`)
so, within workbench-shell's own `tier: tools` registration, they're sourced
in that order — though the guards above make the outcome correct regardless
of load order, since each engine only elects itself, never the others.

Whichever engine wins sets `WORKBENCH_PROMPT_ENGINE` (informational) and
`WORKBENCH_PROMPT_SET=true` (the actual Core API contract —
`contracts/core-api.md`'s prompt-ownership convention) so the loader skips
its own bare fallback prompt.

## Overriding this module's defaults

This module's deployed files live inside an immutable, per-sync snapshot
(`${XDG_DATA_HOME}/workbench/modules/shell/current/`, ARCHITECTURE.md
principle 6 / §12 D16) — editing them in place is silently discarded on
the next sync, and would corrupt the sync engine's manifest-hash tracking
in the meantime. `workbench-precursor`'s `set-omp-theme-permanent` used to
work around this by editing `tools/omp.sh` directly via `sed -i`, back
when that file was a real, persistent path in the donor's single git
clone — that doesn't work here.

Instead, this module ships `shell/overrides.sh`
(`overrides_src`, workbench-core ARCHITECTURE.md §12 D48) — deployed once,
to `~/.config/workbench/local/overrides/shell.sh`, and never touched
again by the sync engine. Edit it directly for `WORKBENCH_OVERRIDE_PROMPT_ENGINE`,
`OMP_THEME`, `ZSH_THEME`, oh-my-zsh's `plugins`, `VISUAL`/`EDITOR`, or
anything else a `shell/*.sh` file here reads with a default.
`set-omp-theme-permanent`
writes into this same file for you, rather than you editing it by hand.

### tmux and vim: a block in your own file

`wb add shell` adds a marked block at the top of your tmux config and your
vimrc. The block loads this module's `files/tmux.conf` / `files/vimrc`
straight from the module, so updates take effect with nothing copied:

```
# >>> workbench shell/tmux.conf under >>>
# Managed by workbench (wb files status). Put your settings outside this block.
source-file -q ".../modules/shell/current/files/tmux.conf"
# <<< workbench shell/tmux.conf under <<<
set -g mouse off        # yours: wins, because tmux keeps the last value
```

- **Which file:** the one the tool already reads — tmux:
  `~/.tmux.conf`, then `~/.config/tmux/tmux.conf`; vim: `~/.vimrc`, then
  `~/.vim/vimrc`, then `~/.config/vim/vimrc`. With none, workbench creates
  `~/.config/tmux/tmux.conf` (tmux 3.1+, else `~/.tmux.conf`) and
  `~/.vimrc`. Never a second file beside yours.
- **Your settings win.** Everything outside the block is yours and is
  never changed. Put your settings below it.
- **TPM** finds the plugins in the module's file and any `@plugin` lines
  you add to yours.
- **Don't want it:** `wb files policy shell tmux.conf skip` (or `vimrc`)
  removes the block; `wb add shell --skip-layer tmux.conf` never adds it.
- **Want only workbench's:** `wb files use shell tmux.conf` backs your file
  up and leaves just the block; `wb files restore shell tmux.conf` puts
  yours back.

`wb files status shell` lists both under "Layers".

### Upgrading from 0.7.x

0.7.x copied whole `tmux.conf`/`vimrc` files. On the first update to this
release, `workbench-core` converts each one:

- **A copy you never edited** becomes a file holding only the block.
- **A copy you edited** keeps everything you have, with the block added at
  the top. Those lines include 0.7.x's defaults, and because your lines
  win, they keep overriding future changes to this module's defaults
  (`wb files status` and a one-line warning say so). To follow the module
  again, delete the old default lines and keep only your own changes. To
  see which lines are yours:
  `diff ~/.vimrc ~/.local/share/workbench/modules/shell/current/files/vimrc`
  (same for your tmux config and `files/tmux.conf`).

### starship and direnv: whole files

`starship.toml` and `direnv.toml` are yours to edit (workbench-core D81):
neither tool can include another config file, so these stay whole-file
copies. While you haven't touched one, it picks up this module's
improvements on every update; once you edit it, workbench never changes it
again, and tells you (a one-line notice in a new shell, and `wb files
status`) when this module's default has moved on, so you can `wb files
diff`/`wb files resolve` at your own pace. `wb files use shell
starship.toml` puts this module's version in place and moves yours to the
backups folder; `wb files restore` puts yours back. `shell/overrides.sh`
above is yours permanently and isn't covered by `wb files use shell all`.

## Using workbench-shell alongside another shell setup

Your rc files, prompt and dotfiles manager can stay as they are. This
module's changes:

- **Aliases**, sourced in every shell — among them `cat` → `bat`, `top` →
  `btop`/`htop`, `python` → `python3`, `pip` → `pip3`, `code` →
  `code-insiders`, where those tools are installed. See
  `shell/aliases.sh`; an alias of your own defined later wins.
- **Prompt election.** If oh-my-posh, starship or oh-my-zsh is installed,
  this module starts it (see below). It doesn't detect a prompt you set up
  some other way. If you manage your prompt yourself, set
  `WORKBENCH_OVERRIDE_PROMPT_ENGINE` in
  `~/.config/workbench/local/overrides/shell.sh` to the engine you use — or
  to a value that names none, such as `none`, and no engine is started.
  A prompt manager that hooks your shell before workbench loads is left
  alone either way. A plain custom `PS1` with nothing behind it can still
  be replaced by workbench-core's own fallback prompt (workbench-core D64).
- **Editor election.** `VISUAL`/`EDITOR` are set only if you haven't set
  them; set `VISUAL` in `overrides.sh` and it wins.
- **direnv:** hooked only if nothing has hooked it already — your rc file,
  another setup, or workbench-git.
- **tmux and vim:** the blocks above; your settings outside them win.

## Files

| File | Where it goes | Notes |
|------|-------------|-------|
| `shell/overrides.sh` | `~/.config/workbench/local/overrides/shell.sh` | Deployed once, never overwritten — edit freely. Ships fully commented; see [Overriding this module's defaults](#overriding-this-modules-defaults) |
| `files/tmux.conf` | Not copied — included from a block at the top of your tmux config | Replaced on every update; don't edit it. Your own settings go in your file, below the block |
| `files/vimrc` | Not copied — included from a block at the top of your vimrc | Replaced on every update; don't edit it. Your own settings go in your file, below the block |
| `files/starship.toml` | `~/.config/starship.toml` | Kept current until you edit it; never touched once you have |
| `files/direnv.toml` | `~/.config/direnv/direnv.toml` | Kept current until you edit it; never touched once you have. Ships with `[whitelist]` commented out: direnv does not expand `~` in `direnv.toml`, so a default like `~/Projects` would silently never match anything. Uncomment it yourself with your `workbench-git` `projects_base`, fully expanded (e.g. `/home/you/Projects`), if you want per-project `direnv allow` prompts skipped |

## Requires

- `oh-my-posh`, `starship`, or `oh-my-zsh` for a themed prompt (optional —
  falls back to the loader's bare `PS1`/`PROMPT` if none is present).
- `direnv`, `fzf` (optional — each guards on its own presence).
