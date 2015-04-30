#!/bin/bash

cd assets/css
touch master.css
echo "" > master.css

while read file
do
  cat $file".css" >> master.css
done < manifest

if type minify > /dev/null 2>&1; then
  minify master.css
  rm master.css
else
  echo "\033[1;33m"Minify not found. Try 'npm install -g minifier'"\033[00m";
  mv master.css master.min.css
fi
