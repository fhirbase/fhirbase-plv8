#!/bin/bash
apt-get update

apt-get install --yes \
postgresql-9.4 \
postgresql-contrib-9.4 \
postgresql-server-dev-9.4 \
pgxnclient \
libv8-dev \
curl \
python

pgxn install plv8
