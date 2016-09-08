export DATABASE_URL=postgres://root:root@localhost:5432/build
psql postgres -c 'drop database if exists build' && \
psql postgres -c "create database build" && \
bash build-commit.sh --rebuild && \
time cat build/latest/build.sql | psql build &&  npm run test
