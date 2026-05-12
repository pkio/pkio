# pkio completions for fish

function __fish_pkio_using_program
    set -l cmd (commandline -opc)
    set -e cmd[1]
    set -l skip_next 0
    for arg in $cmd
        if test $skip_next = 1
            set skip_next 0
            continue
        end
        switch $arg
            case -C
                set skip_next 1
            case '-*'
                continue
            case '*'
                return 0
        end
    end
    return 1
end

complete -c pkio -n 'not __fish_pkio_using_program' -s C -d 'Change to directory' -r -a '(__fish_complete_directories)'
complete -c pkio -n 'not __fish_pkio_using_program' -l ro -d 'Add read-only path' -r -F
complete -c pkio -n 'not __fish_pkio_using_program' -l rw -d 'Add read-write path' -r -F
complete -c pkio -n 'not __fish_pkio_using_program' -l config -d 'Edit config' -x
complete -c pkio -n 'not __fish_pkio_using_program' -l show-config -d 'Print merged config for a program'
complete -c pkio -n 'not __fish_pkio_using_program' -l shell -d 'Start sandboxed subshell' -x -a 'bash zsh fish'
complete -c pkio -n 'not __fish_pkio_using_program' -l complete -d 'Output completion code' -x -a 'bash zsh fish'
complete -c pkio -n 'not __fish_pkio_using_program' -l stash -d 'Move file to config stash and symlink' -x -a '(__fish_complete_path)'
complete -c pkio -n 'not __fish_pkio_using_program' -l link -d 'Create symlinks for stashed files' -x
complete -c pkio -n 'not __fish_pkio_using_program' -l unlink -d 'Remove symlinks to stashed files'
complete -c pkio -n 'not __fish_pkio_using_program' -l list -d 'List programs with curated defaults'
complete -c pkio -n 'not __fish_pkio_using_program' -l update -d 'Update pkio'
complete -c pkio -n 'not __fish_pkio_using_program' -l reset -d 'Remove cached dependencies'
complete -c pkio -n 'not __fish_pkio_using_program' -l help -d 'Show help'

if set -q PKIO_ROOT
  for d in $PKIO_ROOT/etc/cmd/*/
    complete -c pkio -n 'not __fish_pkio_using_program' -a (basename $d) -d 'Run in sandbox'
  end
end

# Once a program is given, delegate to that program's own completion
complete -c pkio -n '__fish_pkio_using_program' -xa '(__fish_complete_subcommand)'
