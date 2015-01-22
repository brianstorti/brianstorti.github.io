#!/bin/bash

cd assets/css
touch master.css
echo "" > master.css

while read file
do
  cat $file".css" >> master.css
done < manifest

minify master.css
rm master.css
