#!/bin/bash

for f in in/*.nem
do
	echo "File considered: $f"
	./nem2shp.sh "$f"
done

