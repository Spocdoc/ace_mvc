#!/bin/zsh

main()
{
  local file
  for file in **/*.coffee; do
    echo rm -f ${file%.coffee}.{js,log}
    command rm -f ${file%.coffee}.{js,log}
  done
}

main "$@"
