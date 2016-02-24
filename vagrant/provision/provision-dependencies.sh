#!/bin/bash

localedef --force --inputfile=en_US --charmap=UTF-8 \
          --alias-file=/usr/share/locale/locale.alias \
          en_US.UTF-8 || exit 1
export LANG=en_US.UTF-8 || exit 1

apt-get -y update || exit 1
apt-get -y upgrade || exit 1

apt-get install --yes \
        postgresql-9.4 \
        postgresql-contrib-9.4 \
        postgresql-server-dev-9.4 \
        pgxnclient \
        libv8-dev \
        curl \
        python || exit 1

pgxn install plv8 || exit 1
