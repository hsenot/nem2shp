#!/bin/bash
DATABASE_NAME=bze
DATABASE_PORT=54321
DATABASE_TRUSTED_USER=postgres

cat "$1" | grep "Punkt;" > /tmp/point.txt;

# We want to match only the first 6 columns to match the structure of the target table
cat "$1" | grep -o "Kante;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*" > /tmp/edge.txt;

# In some of the nem files, there is no "Kante"s but there are "Kanzeit"s
if [ ! -s "/tmp/edge.txt" ]
then
	cat "$1" | grep "Kanzeit;" > /tmp/edge.txt;
fi

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "drop table if exists hsr_point";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "CREATE TABLE hsr_point (gid serial,col1 character varying,col2 character varying,col3 character varying,col4 character varying,col5 character varying,col6 character varying,col7 character varying,col8 character varying,col9 character varying,col10 character varying)";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "copy hsr_point (col1,col2,col3,col4,col5,col6,col7,col8,col9,col10) from '/tmp/point.txt' delimiter ';'";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "drop table if exists hsr_edge";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "CREATE TABLE hsr_edge (gid serial,col1 character varying,col2 character varying,col3 character varying,col4 character varying,col5 character varying,col6 character varying)";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "copy hsr_edge (col1,col2,col3,col4,col5,col6) from '/tmp/edge.txt' delimiter ';'";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "drop table if exists hsr_point_g";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "create table hsr_point_g (gid serial NOT NULL,id character varying,the_geom geometry(POINT,4326))";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "insert into hsr_point_g (id,the_geom) select col2,ST_SetSRID(ST_Point(col3::float,col4::float),4326) from hsr_point";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "drop table if exists hsr_edge_g";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "create table hsr_edge_g (gid serial NOT NULL,id character varying,passengers integer,thick float,the_geom geometry(LINESTRING,4326))";

psql -U $DATABASE_TRUSTED_USER -p $DATABASE_PORT -d $DATABASE_NAME -c "insert into hsr_edge_g (id,passengers,thick,the_geom) select col2||'-'||col3,col5::integer,col5::float/500000,ST_SetSRID(ST_MakeLine(p1.the_geom,p2.the_geom),4326) from hsr_edge e,hsr_point_g p1,hsr_point_g p2 where e.col2=p1.id and e.col3=p2.id";

BASENAME=`basename $1` 
FILENAME="./out/${BASENAME%.*}.shp"
echo $FILENAME

pgsql2shp -p $DATABASE_PORT -f $FILENAME $DATABASE_NAME hsr_edge_g

# Zipping the files into a zip directory
rm ./zip/${BASENAME%.*}.zip
zip "./zip/${BASENAME%.*}.zip" ./out/${BASENAME%.*}.*
