#!/usr/bin/env bash

# sorta need a datastructure for this as not all CLIs match their brew name.
#
#check_dependencies(){
#    R=$1 && REQUIRED_DEPENDENCIES=${R[*]}
#    MISSING_DEPENDENCIES=()
#
#    for DEPENDENCY in ${REQUIRED_DEPENDENCIES}; do
#        command -v "$DEPENDENCY" >/dev/null 2>&1 || { MISSING_DEPENDENCIES+=("$DEPENDENCY"); }
#    done
#
#    # Instead of exiting when we see a missing command, let's be nice and give the user a list.
#    if [ ${#MISSING_DEPENDENCIES[@]} -ne 0 ]; then
#        printf '> Missing %s, please install it!\n' "${MISSING_DEPENDENCIES[@]}"
#        printf 'Exiting.\n'
#        exit 1;
#    fi
#}
#
#check_dependencies fzf

# If you don't have the Azure cli installed on your system go ahead and install it now
if [ -f "/usr/local/bin/az" ] || [ -f "/opt/homebrew/bin/az" ]; then
    echo "Azure cli already installed"
else
    echo "installing Azure cli..."
    brew update
    brew install azure-cli
fi

# If you don't have the Azure cli installed on your system go ahead and install it now
if [ -f "/usr/local/bin/fzf" ] || [ -f "/opt/homebrew/bin/fzf" ]; then
    echo "fzf cli already installed"
else
    echo "installing fzf..."
    brew update
    brew install fzf
fi

#check if uaac is installed
if [ -f "/usr/local/bin/uaac" ]; then
    echo "uaac is already installed"
else
    echo "Please install uaac with gem install cf-uaac"
    exit $?
fi
