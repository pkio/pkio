#!/usr/bin/env bash

source test/init

+cmd:ok-ver shellcheck 0.11.0 ||
  plan skip-all "Test requires shellcheck 0.11.0 to be installed"

# 1090 - Can't follow dynamic source path
# 1091 - Can't open sourced file
# 2030 - Variable modification local to subshell
# 2031 - Variable modified in subshell may be lost
# 2034 - Variable appears unused
# 2154 - Variable referenced but not assigned
# 2207 - Array via unquoted command substitution
skip=1090,1091,2030,2031,2034,2154,2207

while read -r file; do
  [[ -h $file ]] && continue
  [[ -f $file ]] || continue

  shebang=$(head -n1 "$file" | LC_ALL=C tr -d '\0')

  if [[ $file == *.bash ]] ||
     [[ $shebang == '#!'*[/\ ]bash ]]
  then
    ok "$(shellcheck -e "$skip" "$file")" \
      "Bash file '$file' passes shellcheck"

  elif
    [[ $file == *.sh ]] ||
    [[ $shebang == '#!'*[/\ ]sh ]]
  then
    ok "$(shellcheck -e "$skip" "$file")" \
      "Shell script file '$file' passes shellcheck"
  fi
done < <(
  git ls-files
)

done-testing
