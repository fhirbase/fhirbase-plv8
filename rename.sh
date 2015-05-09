#!/bin/bash


if [ ! -f "$1" ]
then
  echo "Could not find file $1";
  exit 1
fi

src_file=$1
src_name=`basename $src_file .sql`

dest_name=$2
dest_path="${src_file%/*}"
dest_file="$dest_path/$dest_name.sql"

echo "Move $src_file -> $dest_file";

replace_expr="s/\\b$src_name\./$dest_name./g"

grep -rl -e "$src_name\." **/*sql  | xargs sed $replace_expr | grep --color $dest_name

read -p "Replace? [y] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 1
fi

echo "Rename $src_name -> $dest_name";
mv $src_file $dest_file
grep -rl -e "$src_name\." **/*sql  | xargs sed -i $replace_expr | grep --color $src_name

echo "Replacing..."
