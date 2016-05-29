#! /bin/bash

set -e

if ! [ -f ./secure.tar.gz.asc ]; then
    echo 'File secure.tar.gz.asc not found!'
    exit 1
fi

gpg --decrypt --output - ./secure.tar.gz.asc | tar --extract --gzip --file -
