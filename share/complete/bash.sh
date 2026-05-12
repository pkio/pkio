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

  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local flags="--ro= --rw= --config --show-config --stash= --link --unlink --shell --complete --list --update --reset --help -C"

  # After -C, complete directories
  if [[ $prev == -C ]]; then
    COMPREPLY=( $(compgen -d -- "$cur") )
    return
  fi

  # Check whether a program has already been specified
  local i has_program=false
  for (( i=1; i < COMP_CWORD; i++ )); do
    case "${COMP_WORDS[i]}" in
      -C) (( i++ )); continue ;;  # skip -C's argument
      -*) continue ;;
      *) has_program=true; break ;;
    esac
  done

  # After the program, delegate to that program's own completion
  if $has_program; then
    if ! declare -F _command_offset >/dev/null 2>&1; then
      # bash-completion not loaded yet; try to load it
      if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
      elif [[ -r /etc/bash_completion ]]; then
        source /etc/bash_completion
      fi
    fi
    if declare -F _command_offset >/dev/null 2>&1; then
      _command_offset $i
    else
      COMPREPLY=( $(compgen -f -- "$cur") )
    fi
    return
  fi

  if [[ $cur == --config=* ]]; then
    # Complete program names after --config=
    local prefix="${cur%%=*}="
    local progs="${prefix}*"
    if [[ -n ${PKIO_ROOT-} ]]; then
      for d in "$PKIO_ROOT"/etc/cmd/*/; do
        [[ -d $d ]] && progs="$progs ${prefix}$(basename "$d")"
      done
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
}
complete -F _pkio pkio
