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
if [ ${#failed[@]} -eq 0 ]; then
  clear
  echo -e "\e[00;32m"
  echo "Tests passed"
  echo ""
  echo ""
  echo -e "\e[92m|||||||||||||||||||||||||||||||||||||"
  echo -e "|||||||||||||||||||||||||||||||||||||"
  echo -e "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV\e[32m"
  echo -e "|                                   |"
  echo -e "|    |||||     |   |     |||||      |"
  echo -e "|    -----     |   |     -----      |"
  echo -e "|    |||||     |   |     |||||      |"
  echo -e "|             (0 _ 0)               |"
  echo -e "|                                   |"
  echo -e "|      \e[00;31m_____________________\e[00;32m        |"
  echo -e "|                                   |"
  echo -e "|                o                  |"
  echo -e "\\___________________________________/"
  echo -e "\e[00m"
  sleep 2s
  clear
  echo -e "\e[00;32m"
  echo "Tests passed"
  echo ""
  echo ""
  echo -e "\e[92m|||||||||||||||||||||||||||||||||||||"
  echo -e "|||||||||||||||||||||||||||||||||||||"
  echo -e "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV\e[32m"
  echo -e "|                                   |"
  echo -e "|    |||||     |   |     |||||      |"
  echo -e "|    <\e[107m * \e[49m>     |   |     <\e[107m * \e[49m>      |"
  echo -e "|    |||||     |   |     |||||      |"
  echo -e "|             (0 _ 0)               |"
  echo -e "|                                   |"
  echo -e "|      \e[00;31m_____________________\e[00;32m        |"
  echo -e "|      \e[00;31m\e[101m_____________________\e[49m \e[00;32m       |"
  echo -e "|                o                  |"
  echo -e "\\___________________________________/"
  echo -e "\e[00m"
else
  echo -e "\e[00;31m"
  echo "Tests failed:"
  echo $failed
  echo -e "\e[00m"
fi
