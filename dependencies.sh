#!/usr/bin/env bash
# If you don't have the Azure cli installed on your system go ahead and install it now
if [ -f "/usr/local/bin/az" ] || [ -f "/opt/homebrew/bin/az" ]; then
    echo "Azure cli already installed"
else
    echo "installing Azure cli..."
    brew update
    brew install azure-cli
fi

#check if uaac is installed
if [ -f "/usr/local/bin/uaac" ]; then
    echo "uaac is already installed"
else
    echo "Please install uaac with gem install cf-uaac"
    exit $?
fi

# You can also install azcopy to move the blob
# if [ -f "/usr/local/bin/azcopy" ]; then
#     echo "Azcopy already installed"
# else
#     echo "installing azcopy..."
#     brew update && brew install azcopy
# fi