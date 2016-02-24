export DATABASE_URL=postgres://root:root@localhost:5432/test
#psql postgres -c 'drop database if exists build' && \
#psql postgres -c "create database build" #&& \
bash build.sh && \
time cat tmp/build.sql | psql test #&& \
#npm run test
