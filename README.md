# workbench-shell

Opinionated shell/editor/prompt layer for the
[`workbench`](https://github.com/GingerGraham/workbench-core) ecosystem.

An **ecosystem module** (`workbench-core` ARCHITECTURE.md §2) — meaningless
standalone. Requires `workbench-core` installed first:

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
- `EDITOR`/`VISUAL`/`PAGER`/`BAT_THEME` defaults (`shell/editors.sh`).
- `tmux.conf`, `vimrc`, `starship.toml`, and `direnv.toml` — all deployed
  once, never overwritten afterwards — edit freely.
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

Set `WORKBENCH_OVERRIDE_PROMPT_ENGINE` to `omp`, `starship`, or `omz` in
`~/.config/workbench/local/overrides/shell.sh` (see below) to force a
specific engine regardless of what's installed or this priority order.
If the named engine isn't actually installed, the override falls through
to no prompt engine at all — never silently back to this election.

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
`OMP_THEME`, `ZSH_THEME`, oh-my-zsh's `plugins`, or anything else a
`shell/*.sh` file here reads with a default. `set-omp-theme-permanent`
writes into this same file for you, rather than you editing it by hand.

Made a mess of `starship.toml`, `direnv.toml`, `tmux.conf`, or `vimrc`
and just want the workbench default back? `wb module reset shell
<name>` (workbench-core ARCHITECTURE.md §12 D51) force-redeploys that
one file from this module's current snapshot — `wb module reset shell
all` for every one of them at once. Always confirms first; this
discards whatever you had. Note the leading dot for `.vimrc` — the
target is the deployed file's basename, and `~/.vimrc`'s basename
includes it. This doesn't cover `shell/overrides.sh` above — that's a
separate mechanism (`overrides_src`, not `deploy[]`), and there's
nothing to "reset" it to, since it's yours from the moment it's first
deployed.

**If you already had this module installed before `tmux.conf`/`vimrc`
moved from symlinked to deployed-once-editable:** an ordinary sync does
*not* migrate a pre-existing symlink for you — it's left exactly as it
was, deliberately, so it can't silently discard whatever you'd done
through that symlink. Run `wb module reset shell tmux.conf` and `wb
module reset shell .vimrc` once, by hand, to convert them to real,
detached, editable files.

## Files

| File | Deployed to | Notes |
|------|-------------|-------|
| `shell/overrides.sh` | `~/.config/workbench/local/overrides/shell.sh` | Deployed once, never overwritten — edit freely. Ships fully commented; see [Overriding this module's defaults](#overriding-this-modules-defaults) |
| `files/tmux.conf` | `~/.config/tmux/tmux.conf` | Deployed once, never overwritten — edit freely |
| `files/vimrc` | `~/.vimrc` | Deployed once, never overwritten — edit freely |
| `files/starship.toml` | `~/.config/starship.toml` | Deployed once, never overwritten — edit freely |
| `files/direnv.toml` | `~/.config/direnv/direnv.toml` | Deployed once, never overwritten — edit freely. Ships with `[whitelist]` commented out: direnv does not expand `~` in `direnv.toml`, so a default like `~/Projects` would silently never match anything. Uncomment it yourself with your `workbench-git` `projects_base`, fully expanded (e.g. `/home/you/Projects`), if you want per-project `direnv allow` prompts skipped |

## Requires

- `oh-my-posh`, `starship`, or `oh-my-zsh` for a themed prompt (optional —
  falls back to the loader's bare `PS1`/`PROMPT` if none is present).
- `direnv`, `fzf` (optional — each guards on its own presence).
