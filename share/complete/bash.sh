# shellcheck shell=bash

_pkio() {
  # Auto-reload this file when it changes
  local _file=$PKIO_ROOT/share/complete/bash.sh
  if [[ $_file -nt ${_pkio_mtime_ref:-/} ]]; then
    _pkio_mtime_ref=$(mktemp)
    source "$_file"
    _pkio "$@"
    return
  fi

  local cur prev cmds flags
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  flags="--config --show-config --stash= --link --unlink --shell --complete --list --update --reset --help"

  if [[ $COMP_CWORD -eq 1 ]]; then
    if [[ $cur == --config=* ]]; then
      # Complete program names after --config=
      local prefix="${cur%%=*}="
      local progs=""
      if [[ -n ${PKIO_ROOT-} ]]; then
        for d in "$PKIO_ROOT"/etc/cmd/*/; do
          [[ -d $d ]] && progs="$progs ${prefix}$(basename "$d") ${prefix}$(basename "$d"):g"
        done
        progs="$progs ${prefix}:g"
      fi
      COMPREPLY=( $(compgen -W "$progs" -- "$cur") )
    elif [[ $cur == --complete=* ]]; then
      local prefix="${cur%%=*}="
      COMPREPLY=( $(compgen -W "${prefix}bash ${prefix}zsh ${prefix}fish" -- "$cur") )
    elif [[ $cur == -* ]]; then
      COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
    else
      # Complete program names
      local progs=""
      if [[ -n ${PKIO_ROOT-} ]]; then
        for d in "$PKIO_ROOT"/etc/cmd/*/; do
          [[ -d $d ]] && progs="$progs $(basename "$d")"
        done
      fi
      COMPREPLY=( $(compgen -W "$progs" -- "$cur") )
    fi
  fi
}
complete -F _pkio pkio
