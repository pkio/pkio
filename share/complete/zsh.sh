# shellcheck shell=bash
#compdef pkio

_pkio() {
  local -a progs flags
  flags=(
    '-C[Change to directory before doing anything]:dir:_directories'
    '--ro=[Add read-only path]:path:_files'
    '--rw=[Add read-write path]:path:_files'
    '--config[Edit config]:spec:->config'
    '--show-config[Print merged config for a program]'
    '--shell[Start sandboxed subshell]:shell:(bash zsh fish)'
    '--stash=[Move file to config stash and symlink]:file:_files'
    '--link=[Create symlinks for stashed files]:file:_files'
    '--unlink[Remove symlinks to stashed files]'
    '--complete[Output completion code]:shell:(bash zsh fish)'
    '--list[List programs with curated defaults]'
    '--update[Update pkio]'
    '--reset[Remove cached dependencies]'
    '--help[Show help]'
  )

  progs=()
  if [[ -n ${PKIO_ROOT-} ]]; then
    for d in "$PKIO_ROOT"/etc/cmd/*/; do
      [[ -d $d ]] && progs+=("$(basename "$d")")
    done
  fi

  _arguments -s \
    '1:command:->cmd' \
    '*::arg:->args'

  case $state in
    cmd)
      _alternative \
        'flags:flag:_describe "flag" flags' \
        'programs:program:compadd -a progs' \
        'commands:command:_command_names -e'
      ;;
    args)
      # Delegate to the program's own completion
      _normal
      ;;
  esac
}

_pkio "$@"
