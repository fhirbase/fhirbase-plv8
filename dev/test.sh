PSQL_ARGS=''
DB='fhirb' #ase_test'

echo "Run tests"

rm -rf out
mkdir out
for script in `ls test/*_test.sql`; do
  nm=`basename $script`
  example="expected/$nm.out"
  out="out/$nm.out"
  echo "run $nm"
  cat $script | psql $PSQL_ARGS -e -d $DB > $out
  diff -Bb $out $example && echo 'ok!'
done
