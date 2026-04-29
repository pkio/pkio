# pkio completions for fish

complete -c pkio -l config -d 'Edit config' -x
complete -c pkio -l show-config -d 'Print merged config for a program'
complete -c pkio -l shell -d 'Start sandboxed subshell' -x -a 'bash zsh fish'
complete -c pkio -l complete -d 'Output completion code' -x -a 'bash zsh fish'
complete -c pkio -l list -d 'List programs with curated defaults'
complete -c pkio -l update -d 'Update pkio'
complete -c pkio -l reset -d 'Remove cached dependencies'
complete -c pkio -l help -d 'Show help'

if set -q PKIO_ROOT
  for d in $PKIO_ROOT/etc/cmd/*/
    complete -c pkio -a (basename $d) -d 'Run in sandbox'
  end
end
