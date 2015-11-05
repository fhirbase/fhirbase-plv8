mkdir -p tmp
coffee  utils/generate_migrations.coffee -n > tmp/schema.sql
plpl/bin/plpl compile tmp/code.sql
cat tmp/schema.sql > tmp/build.sql
cat tmp/code.sql >> tmp/build.sql
rm tmp/code.sql
rm tmp/schema.sql



