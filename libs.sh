#!/usr/bin/env bash

source dependencies.sh
source azure_setup.sh
source azure_paving.sh
source opsman.sh
source director.sh
source tas.sh

is_sourced() {
   if [ -n "${ZSH_VERSION:-}" ]; then
       case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
   else
       case ${0##*/} in dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0;; esac
   fi
   return 1  # NOT sourced.
}