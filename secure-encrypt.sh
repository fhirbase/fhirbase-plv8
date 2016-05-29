#! /bin/bash

set -e

if ! [ -d ./secure ]; then
    echo 'Nothing to secure. Directy secure not found!'
    exit 1
fi

# if [ -f ./secure.tar.gz ]; then
#     mv -i ./secure.tar.gz ./secure_$(date +%Y%m%dT%H%M%S%Z).tar.gz
# fi

find ./secure -type f \
         ! \( -name "*.tar*" \) \
    -and ! \( -name "*.asc" \) \
    -and ! \( -name "*.enc" \) \
    -and ! \( -name ".gitkeep" \) \
    | tar --create --gzip --to-stdout --files-from - > secure.tar.gz

gpg --symmetric --armor ./secure.tar.gz || exit 1
