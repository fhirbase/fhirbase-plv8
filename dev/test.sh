PSQL_ARGS=''
DB='fhirb' #ase_test'

echo "Run tests"
failed=()

rm -rf out
mkdir out
for script in `ls test/*_test.sql`; do
  nm=`basename $script`
  example="expected/$nm.out"
  out="out/$nm.out"
  echo "run $nm"
  cat $script | psql $PSQL_ARGS -e -d $DB > $out
  if diff -Bb $out $example
  then
    echo -e "\e[00;32m"
    echo "OK"
    echo -e "\e[00m"
  else
    echo -e "\e[00;31m"
    failed+=$script
    diff -Bb -y $out $example
    echo -e "\e[00m"
  fi
done


echo '-----------------------------'
echo -e "\e[00;31m"
echo $failed
echo -e "\e[00m"
