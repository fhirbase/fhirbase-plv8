mkdir --parents tmp

coffee utils/generate_migrations.coffee -n > tmp/schema.sql
coffee utils/generate_patch.coffee -n > tmp/patch.sql

plpl/bin/plpl compile tmp/code.sql

cat tmp/schema.sql > tmp/build.sql
cat tmp/patch.sql >> tmp/build.sql
cat tmp/code.sql >> tmp/build.sql

cat tmp/code.sql >> tmp/patch.sql

# psql postgres -c 'drop database build' && psql postgres -c "create database build with ENCODING = 'UTF-8' LC_CTYPE = 'ru_RU.UTF-8' LC_COLLATE = 'ru_RU.UTF-8'   template = template0" && cat tmp/build.sql | psql build && npm run test
