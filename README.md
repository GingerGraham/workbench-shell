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
- `tmux.conf` and `vimrc` (symlinked into place, kept in sync on every
  update) and default `starship.toml`/`direnv.toml` (deployed once, never
  overwritten afterwards — edit freely).
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

The manifest lists them in this priority order (`omp` → `starship` → `omz`)
so, within workbench-shell's own `tier: tools` registration, they're sourced
in that order — though the guards above make the outcome correct regardless
of load order, since each engine only elects itself, never the others.

Whichever engine wins sets `WORKBENCH_PROMPT_ENGINE` (informational) and
`WORKBENCH_PROMPT_SET=true` (the actual Core API contract —
`contracts/core-api.md`'s prompt-ownership convention) so the loader skips
its own bare fallback prompt.

## `set-omp-theme-permanent` and immutable snapshots

`workbench-precursor`'s `set-omp-theme-permanent` edited `tools/omp.sh` in
place via `sed -i` — that file was a real, persistent path inside the
donor's single git clone. That approach doesn't work under
`workbench-core`'s distribution model: this module's deployed files live
inside an immutable, per-sync snapshot
(`${XDG_DATA_HOME}/workbench/modules/shell/current/`, ARCHITECTURE.md
principle 6 / §12 D16) — editing them in place is silently discarded on
the next sync, and would corrupt the sync engine's manifest-hash tracking
in the meantime.

`set-omp-theme-permanent` here instead writes (or updates) an
`export OMP_THEME="..."` line in
`~/.config/workbench/local/settings.sh` (the D22 local-overrides file,
sourced after every module's own registered content) — this persists
correctly and survives every future sync.

## Files

| File | Deployed to | Notes |
|------|-------------|-------|
| `files/tmux.conf` | `~/.config/tmux/tmux.conf` | Symlinked — kept in sync on every update |
| `files/vimrc` | `~/.vimrc` | Symlinked — kept in sync on every update |
| `files/starship.toml` | `~/.config/starship.toml` | Deployed once, never overwritten — edit freely |
| `files/direnv.toml` | `~/.config/direnv/direnv.toml` | Deployed once, never overwritten — edit freely; adjust the `[whitelist]` prefix if your `workbench-git` `projects_base` isn't the default `~/Projects` |

## Requires

- `oh-my-posh`, `starship`, or `oh-my-zsh` for a themed prompt (optional —
  falls back to the loader's bare `PS1`/`PROMPT` if none is present).
- `direnv`, `fzf` (optional — each guards on its own presence).
