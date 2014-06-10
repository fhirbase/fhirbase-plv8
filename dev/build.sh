PSQL_ARGS=''
DB='fhirb' #ase_test'

echo "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;" | psql $PSQL_ARGS -d postgres;
for scrpt in `ls *sql`; do
  cat $scrpt | psql $PSQL_ARGS -d $DB -1
done

exit
echo "Run tests"

for scrpt in `ls test/*sql`; do
  cat $scrpt | psql $PSQL_ARGS -d $DB
done
