# pkio

Project Kernel Isolation Orchestrator

or: Please Keep It Outside

## Name

pkio — run any program inside a nono kernel-level security sandbox
with per-project configuration.

## Synopsis

```
pkio [flags] <program> [args...]
```

## Description

pkio wraps programs inside a [nono](https://github.com/always-further/nono)
kernel-level sandbox.
It enforces a default-deny filesystem policy: programs can only access
the current working directory and explicitly allowed paths.

Configuration is layered — shipped defaults, user globals, and
per-project overrides combine to produce the final sandbox policy.

## Options

- `--ro=PATH` — Add a read-only path (repeatable).
- `--rw=PATH` — Add a read-write path (repeatable).
- `--config[=SPEC]` — Edit a config file in `$EDITOR`.
  - `--config` — project config
  - `--config=claude` — global config for claude
  - `--config=*` — global config (all programs)
- `--show-config` — Print the merged config for a program.
- `--shell[=SHELL]` — Start a sandboxed subshell.
- `--complete=SHELL` — Output tab completion code (bash, zsh, fish).
- `--history` — Print the path to the per-project shell history
  file.
- `--list` — List programs with curated default configs.
- `--update` — Update pkio (git pull + rebuild cache).
- `--reset` — Remove cached dependencies (`~/.cache/pkio/local`).
- `--help` — Show usage help.

Running `pkio` with no arguments starts a sandboxed subshell.

## Configuration

Config files are YAML and are layered in this order (later overrides
earlier):

| Level | Location | Scope |
|-------|----------|-------|
| 1 | `$PKIO_ROOT/etc/config.yaml` | shipped defaults |
| 2 | `$PKIO_ROOT/etc/cmd/<prog>/config.yaml` | shipped program defaults |
| 3 | `~/.config/pkio/config.yaml` | user global |
| 4 | `~/.config/pkio/cmd/<prog>.yaml` | user global per-program |
| 5 | `~/.config/pkio/<project>/config.yaml` | per-project |
| 6 | `~/.config/pkio/<project>/config.yaml` `cmd:<prog>` | per-project per-program |

### Config Schema

All config files share the same YAML schema.
Every field is optional.

```yaml
cmd-args:
- --some-flag

read-write:
- /tmp
- /dev/ptmx

read-only:
- /proc
- /etc/gitconfig

net:
  domains:
  - registry.npmjs.org
  ports:
    listen:
    - 3000
    open:
    - 5173

env:
  SOME_VAR: value

path:
- /usr/bin

browser: google-chrome

makes:
- node
- python

makefile: |
  CUSTOM-VAR := value

cmd:
  claude:
    read-only:
    - ~/.special/config
```

The `cmd:` key allows per-program overrides within a single config
file.
This is most useful in project configs where you want different
sandbox rules for different programs.

## Installation

Clone the repository and source the shell init file:

```bash
git clone https://github.com/pkio/pkio
echo 'source /path/to/pkio/.rc' >> ~/.bashrc
```

All dependencies (nono, YAMLScript, etc.) are installed automatically
under `~/.cache/pkio/` on first run.

## Examples

Run Claude Code in a sandbox:

```bash
pkio claude
```

Run tmate in a sandbox:

```bash
pkio tmate
```

Edit the project config:

```bash
pkio --config
```

Edit the global config for claude:

```bash
pkio --config=claude
```

Enable tab completion:

```bash
# Add to your shell profile:
source <(pkio --complete=bash)
```

## Environment

- `PKIO_ROOT` — pkio installation directory (set by `.rc`).
- `PKIO_CONFIG` — config home (default: `~/.config/pkio`).
- `PKIO_BASE` — resolved project base path (set at runtime).
- `PKIO_SHELL` — the user's shell (set by `.rc`).
- `PKIO_PROGRAM` — the program being sandboxed (set at runtime).

## Files

- `~/.config/pkio/` — user configuration and per-project settings.
- `~/.cache/pkio/` — cached dependencies (makes, local tools).

## License

MIT — see [License](License).

## Author

Ingy döt Net
