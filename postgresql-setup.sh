# TRAVIS_BUILD_DIR=`pwd`/tmp
# USER=devel

# sudo apt-get -qqy install git build-essential gettext libreadline6 libreadline6-dev zlib1g-dev flex bison libxml2-dev libxslt-dev
TRAVIS_BUILD_DIR=`pwd`
PG_DIR=$TRAVIS_BUILD_DIR/pg
PGDATA=$TRAVIS_BUILD_DIR/data
PG_BIN=$TRAVIS_BUILD_DIR/bin
PG_CONFIG=$TRAVIS_BUILD_DIR/conf
git clone -b REL9_4_STABLE --depth=1 git://git.postgresql.org/git/postgresql.git $PG_DIR

XML2_CONFIG=`which xml2-config` cd $PG_DIR && ./configure --prefix=$PG_BIN  --with-libxml && make && make install

cd $PG_DIR/contrib/pgcrypto && make && make install
cd $PG_DIR/contrib/pg_trgm && make && make install

# RUN git clone https://github.com/akorotkov/jsquery.git /var/postgresql/contrib/jsquery
# RUN cd /var/postgresql/contrib/jsquery && make && make install

# echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
# locale-gen

mkdir $PGDATA
$PG_BIN/bin/initdb -D $PGDATA -E utf8
echo "host all  all    0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf
echo "listen_addresses='*'" >> $PGDATA/postgresql.conf
echo "port=5777" >> $PGDATA/postgresql.conf				# (change requires restart)
$PG_BIN/bin/pg_ctl -D $PGDATA start
