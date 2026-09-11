#!/usr/bin/env bash
# shell/overrides.sh — workbench-shell
# Uncomment any of these to change workbench-shell's defaults. This file
# is yours — workbench-core deploys it once, to
# ~/.config/workbench/local/overrides/shell.sh, and never touches it
# again (workbench-core ARCHITECTURE.md §12 D48).
#
# It's sourced as ordinary shell, early — before any of this module's own
# tier content runs. You're not limited to the lines below: anything a
# shell/*.sh file in this module reads with a default (or checks for
# election, like WORKBENCH_OVERRIDE_PROMPT_ENGINE) can be set here,
# including plain shell like `plugins=(git docker)` for oh-my-zsh.

# Force a specific prompt engine, regardless of what's installed or the
# register-order election (omp > starship > omz — see README.md's
# "Prompt engine election"). Valid values: omp, starship, omz. If the
# named engine isn't actually installed, the override falls through to
# no prompt engine at all — core's own bare PS1/PROMPT fallback, not
# silently back to the election.
# export WORKBENCH_OVERRIDE_PROMPT_ENGINE="starship"

# oh-my-posh theme name (looked up in oh-my-posh's own theme cache dir —
# run `omp-themes` to list what's available).
# export OMP_THEME="jandedobbeleer"

# oh-my-zsh theme name.
# export ZSH_THEME="robbyrussell"
