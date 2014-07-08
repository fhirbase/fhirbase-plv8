PSQL_ARGS='-p 5455'
DB='fhirbase'

echo "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;" | ~/sql/pg/bin/psql $PSQL_ARGS -d postgres;
for scrpt in `ls *sql`; do
  echo "Execute: $scrpt ..."
  cat $scrpt | ~/sql/pg/bin/psql $PSQL_ARGS -d $DB -1
done

exit
echo "Run tests"

for scrpt in `ls test/*sql`; do
  cat $scrpt | ~/sql/pg/bin/psql $PSQL_ARGS -d $DB
done
