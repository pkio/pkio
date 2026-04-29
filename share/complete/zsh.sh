# shellcheck shell=bash
#compdef pkio

_pkio() {
  local -a progs flags
  flags=(
    '--config[Edit config]:spec:->config'
    '--show-config[Print merged config for a program]'
    '--shell[Start sandboxed subshell]:shell:(bash zsh fish)'
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
    '*:args:->args'

  case $state in
    cmd)
      _alternative \
        'flags:flag:_describe "flag" flags' \
        'programs:program:compadd -a progs' \
        'commands:command:_command_names -e'
      ;;
  esac
}

_pkio "$@"
