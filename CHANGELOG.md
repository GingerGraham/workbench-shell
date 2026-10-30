# Changelog

All notable changes to `workbench-shell` are documented here.

## [Unreleased]

## [0.8.5] - 2026-10-30

### Fixed

- **`wb tools install zsh-default-shell` checks the login shell, not
  `$SHELL`.** `${SHELL}` keeps its old value until the next desktop login,
  so after a successful `chsh` the tool read as not installed and
  re-running the install ran `chsh` again, with another password prompt.
  Both `install-zsh-default-shell` and `installed-zsh-default-shell` now
  read the login shell the system records (`getent passwd` on Linux,
  `dscl` on macOS), and `/bin/zsh` and `/usr/bin/zsh` both count. A failed
  `chsh` is now reported as a failure, and the message says the change
  applies at your next desktop login, not in a new terminal (workbench-core
  D107).

## [0.8.4] - 2026-10-29

### Fixed

- **fzf shell integration no longer fails silently on fzf older than 0.48.0.**
  `fzf --bash` and `fzf --zsh` first shipped in 0.48.0. On an older fzf
  (Pop!_OS 22.04/24.04 packages 0.44.1) the call printed nothing, and
  Ctrl-R, Ctrl-T and Alt-C quietly stayed unbound. `shell/fzf.sh` now only
  evaluates real output, and an interactive shell prints one warning naming
  the fzf version and the fix, `wb tools upgrade fzf`. Scripts and other
  non-interactive shells stay silent.

- **`wb tools install fzf` no longer stops at a distro fzf too old for shell
  integration.** After the distro install, `install-fzf` checks the version
  against 0.48.0, the first release with `fzf --bash` and `fzf --zsh`. If the
  package is older (Pop!_OS ships 0.44.1), it installs
  the upstream release to `~/.local/bin` as it already did when the distro
  install failed, and fails with a hint if an older fzf still comes first on
  `PATH`. When the active fzf is `~/.local/bin/fzf`, `wb tools upgrade fzf`
  refreshes it from the upstream release. Distros with a current fzf, such
  as Fedora and Arch, install nothing into `~/.local/bin`.

### Changed

- **Bug report template asks for OS family and environment separately.**
  The single "Platform" dropdown is replaced by an "Operating system"
  dropdown (Fedora/RHEL, Debian/Ubuntu, Arch, SUSE, other Linux, macOS),
  an optional distribution and version field, and an "Environment"
  dropdown (directly on the OS, container, or WSL2), so a report says
  which distro it ran on and whether that was WSL2 or a container.

## [0.8.3] - 2026-10-27

### Fixed

- **`wb tools install oh-my-zsh` no longer replaces your `~/.zshrc`.**
  oh-my-zsh's installer ran with no options: it backed up and replaced
  `~/.zshrc` (dropping workbench's loader stub), offered to change your
  login shell, and ended with `exec zsh`, which also ended a
  `wb tools install all` run. It now runs unattended with
  `--keep-zshrc`, `KEEP_ZSHRC=yes`, `RUNZSH=no` and `CHSH=no`;
  `shell/omz.sh` loads oh-my-zsh itself.
- **`wb tools upgrade oh-my-zsh` sees an existing install, and updates it
  instead of reinstalling.** The "installed" check looked for the `omz`
  command, a zsh function that never exists in the bash process `wb tools`
  runs in. It now checks `~/.oh-my-zsh/oh-my-zsh.sh`, and an existing
  install is updated with oh-my-zsh's own `tools/upgrade.sh`.
- **A `cd` inside `$(…)` no longer captures a directory listing in zsh, and
  your own `chpwd` keeps working.** The listing after `cd` is now a hook in
  zsh's `chpwd_functions`, runs only at an interactive prompt (never in a
  subshell or command substitution), and no longer replaces a `chpwd`
  function you define. macOS uses `ls -AlhG` (BSD `ls` has no `--color`).
- **`get-shell-functions` lists this module's names in zsh.** The
  hand-written getter read `${BASH_SOURCE[0]}`, which zsh doesn't set, so
  in zsh it printed `(none)`. It's removed; workbench-core 2.21's getter,
  built from `register.getters[]`, is used instead. Its headers now read
  "Shell/prompt/editor helpers (…) — functions:" / "— aliases:".
- **`routeprint`/`printrt` show the routing table.** They ran `ss -rn`,
  which lists sockets. Now `ip route` on Linux, `netstat -rn` on macOS or
  without `ip`.
- **`get-python-versions` works in zsh, and lists only real interpreters.**
  The `/usr/bin/python3*` glob was a "no matches found" error in zsh; it now
  searches `/usr/bin` and `/usr/local/bin`.
- **`get-public-ip` no longer prints an HTTP error page as an address**
  (`curl -fsS`).
- **fzf's key bindings and completion load on macOS's bash 3.2.** They were
  loaded with `source <(…)`, which bash 3.2 ignores; they're now `eval`'d.
- **zsh finds the plugins where `wb tools install zsh-plugins` puts them**
  (`~/.local/share/zsh/plugins`, or under `$XDG_DATA_HOME`), and on Arch
  (`/usr/share/zsh/plugins`) and Homebrew (`$HOMEBREW_PREFIX/share`,
  `/usr/local/share`). The git-clone fallback now also honours
  `XDG_DATA_HOME`.
- **`wb tools install zsh-plugins` runs.** It refused unless the current
  shell was zsh, which it never is under `wb tools`. `wb tools upgrade` and
  `wb tools list --status` now see it too (`installed-zsh-plugins`).
- **`wb tools install direnv` no longer sources `direnv.sh` into its own
  process**, where it could never reach your shell; it says to start a new
  shell.
- **oh-my-posh finds Homebrew's theme directory**
  (`$HOMEBREW_PREFIX/opt/oh-my-posh/themes`, `/usr/local/opt/…`), and no
  longer warns on every shell start when there's none.
- **`edit-starship-config` exists whenever starship is installed**, not only
  when starship won the prompt election.
- **`install-neovim` no longer stops on an unset `ZSH_VERSION`** while
  pruning old installs.
- Messages say `wb tools install zsh` / `wb tools install
  zsh-default-shell`, not the internal function names.

### Security

- **neovim's tarball, and fzf's when it's installed from GitHub, are
  checked against the SHA-256 GitHub publishes for them before they're
  unpacked.** No published SHA-256, or one that doesn't match, and nothing
  is installed. fzf's releases-API request now fails on an HTTP error
  (`curl -fsSL`). The README has a table of what each installer verifies,
  including the vendor install scripts that run unverified (oh-my-posh,
  starship, oh-my-zsh, direnv's) and what `files/tmux.conf` does on first
  start (clones TPM, installs a boot-time autostart via
  `@continuum-boot 'on'`).

### Changed

- Requires workbench-core Core API 1.8 (`core_api: ">=1.8 <2.0"`): the
  core-defined getter and `_wb_gh_release_asset_url`, which replaces this
  module's private copy of the same helper.
- **Names that need a tool you don't have say so.** Every alias and
  function here that needs an external tool declares it (workbench-core's
  availability declarations), so `wb functions` and `get-shell-functions`
  list it under what it needs instead of as available. `python`, `pip`,
  `code`, `explorer` and `matrix` are now listed at all.

## [0.8.2] - 2026-10-25

### Fixed

- **A shell without direnv, fzf, lesspipe on `PATH`, or the zsh plugins
  now starts silently.** The direnv hook runs only when direnv is
  installed (its functions stay defined either way); fzf's shell
  integration is sourced only when fzf is installed (on Ubuntu, bash
  otherwise ran a line of the command-not-found message as a command);
  `lesspipe` runs by the path it was checked at, by setting
  `LESSOPEN`/`LESSCLOSE` directly instead of evaluating its output; a
  missing zsh-autosuggestions or zsh-syntax-highlighting is reported at
  debug level, pointing at `wb tools install zsh-plugins`, instead of a
  warning on every start.
- **zsh no longer runs compinit's full security check on every start, or
  aborts it without a terminal.** The once-a-day dump refresh never
  matched (`[[ ]]` does no globbing), so every start ran the full check;
  where an `fpath` directory is group- or world-writable, compinit asked
  whether to continue and, with no terminal, printed "compinit:
  initialization aborted" and left completion off. The refresh now runs
  only when the dump is missing or a day old, and drops insecure
  directories (`compinit -i`) instead of asking. Required by workbench-core's module
  CI clean-shell check (its `docs/decisions-log.md` D94).

## [0.8.1] - 2026-10-23

### Fixed

- **Updating from 0.7.x no longer prints a syntax error in the open
  shell.** `wb update` reloads the shell in place, and 0.7.x's
  `tmux-reload` alias was still defined there: bash and zsh expanded it
  inside 0.8.0's `tmux-reload()` definition and failed to parse
  `shell/aliases.sh` from that line on. The function is now defined with
  `function`, which neither shell alias-expands, and the old alias is
  removed. New shells were never affected.

## [0.8.0] - 2026-10-23

### Changed

- **tmux and vim defaults are a block in your own config**
  (workbench-core D82; needs Core API 1.6, `core_api: ">=1.6 <2.0"`).
  workbench-core adds a marked block at the top of the tmux config and
  vimrc you already use, loading `files/tmux.conf` / `files/vimrc` from
  the module; anything you set in your file wins. No second tmux config is
  created beside yours. On update, an unedited 0.7.x copy becomes a file
  holding only the block; an edited one keeps all your lines, with the
  block on top. `starship.toml` and `direnv.toml` stay whole-file copies.
- **direnv is hooked only if nothing has hooked it already** (your rc
  file, another setup, or workbench-git; workbench-core D83).

### Fixed

- **`tmux-reload` reloads the config tmux actually reads** —
  `~/.tmux.conf` when you have one — instead of always
  `~/.config/tmux/tmux.conf`.

## [0.7.0] - 2026-10-21

### Changed

- **`tmux.conf` and `vimrc` yield to a config you already have.** With
  `~/.tmux.conf`, or `~/.vim/vimrc`/`~/.config/vim/vimrc`, present, this
  module no longer adds a second one beside it (tmux would load both, and
  a new `~/.vimrc` would shadow yours). `wb files use shell <file>` opts in
  to this module's version; `wb files restore` puts yours back. Requires
  the workbench-core release with D81.
- **A `LESS` you set yourself is kept** — `-R` is now only the default.

## [0.6.3] - 2026-10-10

### Security

- **oh-my-zsh no longer auto-updates; it shows a reminder instead.**
  `shell/omz.sh` now sets `zstyle ':omz:update' mode reminder` (was
  `auto`), so oh-my-zsh no longer pulls its own `master` branch
  unattended into code sourced by every zsh, outside workbench's release
  tags, cooldown and adoption log (security review M9). Update
  deliberately with `omz update` or `install-oh-my-zsh`.

## [0.6.2] - 2026-09-25

### Security

- **oh-my-zsh's installer script is now downloaded to a file and
  executed from there, not run straight off the network through
  `sh -c "$(curl|wget|fetch …)"`.** A failed download (network error,
  an HTTP error page) is now caught before anything runs, instead of
  `sh` trying to interpret whatever came back (security review M3). All
  three fallback paths (curl, wget, fetch) are covered.

## [0.6.1] - 2026-09-23

### Fixed

- **`reset-shell`/`rs` no longer open a pager or dump the full aliases
  listing.** Both now call `get-functions --no-pager --no-aliases`
  instead of a bare `get-functions`, matching the summary a fresh shell
  already shows you (`WORKBENCH_SHOW_FUNCTIONS`'s startup banner in
  `workbench-core`) rather than inheriting `wb functions`' interactive
  pager and full output once `workbench-core` gained one. `aliases` is
  unchanged — it's still the full listing, by design. Requires a
  `workbench-core` release carrying its `docs/decisions-log.md`
  D72/D73 fix; on an older `workbench-core`, the two flags are silently
  ignored (no error, no regression).

## [0.6.0] - 2026-09-23

### Added

- **Manual `workflow_dispatch` release override.** `release.yml` now
  accepts a `bump_type` (patch/minor/major) input to force a release
  through `workbench-core`'s reusable `module-release.yml`, regardless of
  what Conventional Commits since the last tag would compute — a floor,
  never a downgrade of a higher severity already pending. Manual dispatch
  only runs from `main`. See `workbench-core`'s `docs/decisions-log.md` D67.

## [0.5.1] - 2026-09-16

### Fixed

- **`open-workspace` (`shell/editors.sh`) no longer listed when unusable.**
  Added `_open-workspace-available()`, a hand-written predicate mirroring
  the function's own `code`/`code-insiders` OR-check, so listings hide it
  on hosts with neither installed instead of showing a function that
  would immediately fail its own preflight. One module's slice of the
  shared `_<name>-available` predicate convention landing in
  `workbench-core` (`lib/core/functions.sh`).

## [0.5.0] - 2026-09-15

### Added

- **`nvim` added to `shell/editors.sh`'s `VISUAL` election** — new
  candidate between `code`/`code-insiders` (GUI sessions only) and the
  bare `vim` fallback, guarded on `nvim` actually being installed, and
  checked regardless of whether a GUI session is present. Part of #2.
- **`open-workspace`** (`shell/editors.sh`) — VS Code workspace picker,
  ported from workbench-precursor's `core/functions.sh`. Closes #8 (in
  part — `plain-shell`/`pretty-shell` land in `workbench-core` instead,
  see its own CHANGELOG).
- **`get-python-versions`, `get-public-ip`** (`shell/aliases.sh`) — ported
  from workbench-precursor's `core/functions.sh`. Closes #8 (in part).

### Fixed

- **`shell/editors.sh` respects a pre-set `VISUAL`.** The election
  previously overwrote `VISUAL` unconditionally in its GUI branch even
  when the user had already set one via `overrides.sh` — fixed to check
  first, election only runs when `VISUAL` is genuinely unset. Documented
  in `overrides.sh` and `README.md`. Closes #2.
- **Plain-mode prompt guard** (`shell/omp.sh`/`starship.sh`/`omz.sh`) —
  each now no-ops when `WORKBENCH_PLAIN_SHELL=true`, so `workbench-core`'s
  new `plain-shell` function actually produces a bare prompt instead of
  being silently overwritten by whichever engine's render hook was
  already live.

## [0.4.1] - 2026-09-15

### Added

- **Agent-instruction files** (`AGENTS.md`, `CLAUDE.md`,
  `.github/copilot-instructions.md`,
  `.claude/skills/conventional-commits/SKILL.md`) — ports
  `workbench-core`'s D32 agent-instruction topology to this repo. See
  `workbench-core`'s `docs/decisions-log.md` D58.
- **Repo governance files** (`.github/PULL_REQUEST_TEMPLATE.md`,
  `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config}.yml`,
  `.github/CODEOWNERS`, `CONTRIBUTING.md`, `SECURITY.md`) — ports
  `workbench-core`'s D31 governance-file topology to this repo,
  piloted on `workbench-git` first. See `workbench-core`'s
  `docs/decisions-log.md` D60.

### Fixed

- **`install-oh-my-posh`, `install-starship`, and the direnv install-script
  fallback no longer pipe a downloaded install script straight into
  `bash`/`sh`** — each now downloads to a temp file first (via
  `_download_file_robust` where a curl path is available), verifies the
  download landed and is non-empty, then executes the file. Closes a
  `scan-patterns` CI finding (remote-script-execution pattern); a
  truncated or failed download can no longer be silently piped into a
  shell.

## [0.4.0] - 2026-09-12

### Changed

- **`tmux.conf`/`vimrc` are now deployed once and freely editable**
  (`mode: copy`), matching `starship.toml`/`direnv.toml` — previously
  `mode: link`, permanently synced with the module and impossible to
  customise. Restore either to the workbench default any time with `wb
  module reset shell tmux.conf` / `wb module reset shell .vimrc`
  (workbench-core ARCHITECTURE.md §12 D51).

  **Migration for existing installs:** this does not happen
  automatically — an ordinary sync leaves a pre-existing `mode: link`
  destination exactly as it was, deliberately, so it can't silently
  discard a change made through the old symlink. Run `wb module reset
  shell tmux.conf` and `wb module reset shell .vimrc` once, by hand, to
  convert them to real, detached, editable files.

## [0.3.0] - 2026-09-11

### Added

- **Prompt-engine election is now overridable** — set
  `WORKBENCH_OVERRIDE_PROMPT_ENGINE` (`omp`, `starship`, or `omz`) in
  `~/.config/workbench/local/overrides/shell.sh` to force a specific
  engine regardless of what's installed or the register-order election.
  Falls through to no prompt engine (never silently back to the
  election) if the named engine isn't actually installed. New
  `overrides_src: shell/overrides.sh` ships a commented template for
  this plus `OMP_THEME`/`ZSH_THEME` (workbench-core ARCHITECTURE.md §12
  D48). `ZSH_THEME` and oh-my-zsh's `plugins` array are no longer
  hardcoded, unconditional literals — both now respect a pre-set value.
  `set-omp-theme-permanent` now persists into this new overrides file
  instead of the shared `~/.config/workbench/local/settings.sh`.

### Changed

- **Manifest renamed** from `.dotfiles-sync.yml` to `workbench.yml`
  (`version: 2`) — no functional change, identical field set
  (workbench-core ARCHITECTURE.md §12 D46). Prompt-engine election
  overrides land in a separate, immediately-following change.

## [0.2.0] - 2026-09-09

### Added

- Added `installed-oh-my-posh`, `installed-starship`, `installed-oh-my-zsh`,
  `installed-zsh`, `installed-zsh-default-shell`, `installed-direnv`,
  `installed-fzf`, `installed-neovim` — reports install status to
  `wb tools upgrade`/`wb tools list --status` (workbench-core §12 D43).
  `install-zsh-plugins` deliberately has no predicate — see
  shell/installers.sh comment for why.

## [0.1.0] - 2026-09-09

### Added

- Initial decomposition from `workbench-precursor` (Wave C): core aliases,
  bash/zsh-specific tweaks, the self-electing prompt-engine trio
  (oh-my-posh/starship/oh-my-zsh), zsh plugins (autosuggestions + syntax
  highlighting), direnv/fzf shell integration, editor environment
  defaults, `tmux.conf`/`vimrc`/`starship.toml`/`direnv.toml`, and
  `install-oh-my-posh`/`install-starship`/`install-oh-my-zsh`/`install-zsh`/
  `install-zsh-default-shell`/`install-zsh-plugins`/`install-direnv`/
  `install-fzf`/`install-neovim`.

### Changed

- Prompt-engine election is now self-contained in each of
  `omp.sh`/`starship.sh`/`omz.sh` (each checks for higher-priority engines
  itself) rather than decided by `loader.sh` — `workbench-core`'s loader
  has no hardcoded per-module branching (principle 4).
- `set-omp-theme-permanent` now persists via
  `~/.config/workbench/local/settings.sh` instead of editing `omp.sh` in
  place — the latter lives inside an immutable per-sync snapshot under
  `workbench-core` and would be silently discarded on the next sync.
- `direnv-init-project`'s generated-`.envrc` detection now matches
  `workbench-git`'s marker (`# Generated by workbench-git`).
- `WORKBENCH_OS`/`WORKBENCH_DISTRO`/`WORKBENCH_SHELL`/`WORKBENCH_ARCH`
  replace `DOTFILES_OS`/`DOTFILES_DISTRO`/`DOTFILES_SHELL`.
- `files/direnv.toml`'s `[whitelist]` prefix is now commented out by
  default instead of shipping a non-functional `~/Projects` entry —
  direnv does not expand `~` in `direnv.toml`, so that default silently
  matched nothing. Documented in the file and the README as something you
  enable yourself with your own fully-expanded `projects_base`.
