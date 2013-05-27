#!/bin/zsh

main()
{
  local file
  for file in */**.coffee; do
    command rm -f ${file%.coffee}.{js,log}
  done
}

main "$@"
