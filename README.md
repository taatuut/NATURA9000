# NATURA9000

Playing with the Natura 2000 data

https://en.wikipedia.org/wiki/HAL_9000

## Setup

Created on a MacBook Pro

Install brew https://brew.sh/

```
brew install gdal watch postgresql@14 postgis
```

```
postgresql@14
This formula has created a default database cluster with:
  initdb --locale=C -E UTF-8 /opt/homebrew/var/postgresql@14
For more details, read:
  https://www.postgresql.org/docs/14/app-initdb.html

To start postgresql@14 now and restart at login:
  brew services start postgresql@14
```


Some Docker relics to remove sometimes...

`Error: Permission denied @ apply2files - /usr/local/lib/docker/cli-plugins`

`sudo rm -r /usr/local/lib/docker/cli-plugins`

`postgresql@14` initializes database during installation, if using older version or in case did not happen use:

`initdb /usr/local/var/postgres`

To stop use `pg_ctl -D /usr/local/var/postgres stop`

To start `pg_ctl -D /usr/local/var/postgres -l logfile start`

```
python3 -m pip install --upgrade pip
python3 -m pip install geopandas matplotlib contextily
```

## Data

Go to https://www.eea.europa.eu/data-and-maps/data/natura-14

Click GIS Data

Download Natura 2000 - Spatial data

Natura 2000 End 2021 - Shapefile

Natura 2000 End 2021 - OGC Geopackage

Unzip Shapefile and Geopackage to folder `data`.

Downloaded `Natura2000_end2021_rev1_dataset_definitions.xls` to understand Geopackage contents.

### Test

NOTE: Skip the Shapefile steps, left the code in as reference for the command syntax.

The `fid` is internal feature id in numeric format.

To write specific features to a test shapefile with limited number of features using `fid` to select:

```
ogr2ogr -lco ENCODING=UTF-8 -sql "SELECT * FROM Natura2000_end2021_rev1_epsg3035 WHERE fid IN (1,2,3,4,5,6,7,8,9,10)" data/test.shp data/Natura2000_end2021_rev1_epsg3035.shp
```

Write first x features to a test shapefile using fid:

```
ogr2ogr -lco ENCODING=UTF-8 -sql "SELECT * FROM Natura2000_end2021_rev1_epsg3035 WHERE fid < 1000" data/test.shp data/Natura2000_end2021_rev1_epsg3035.shp
```

FYI: to create spatial index on a Shapefile, `qix` is open source alternative for `shx`, not tested if geopandas uses either of these anyway so could skip this step. Also using geopandas `.sindex` but not assessed impact.

```
ogrinfo --config CPL_DEBUG ON -sql "CREATE SPATIAL INDEX ON Natura2000_end2021_rev1_epsg3035" data/Natura2000_end2021_rev1_epsg3035.shp
```

```
ogrinfo --config CPL_DEBUG ON -sql "CREATE SPATIAL INDEX ON test" data/test.shp
```

## Script

### Python GeoPandas/Shapefile

NOTE: Skip the Shapefile steps, left the code in as reference for the command syntax.

Python scripts

```
count_dbf_records.py

natura2000nearest.py

natura2000nearest_visualisation.py
```

Load the shapefile into the table Natura2000

`shp2pgsql -s 3035 -I Natura2000_end2021_rev1_epsg3035.shp Natura2000 | psql -d sensingclues`

NOTE: If Geopackage is not a suitable alternative, use shapefile and update the table Natura2000 with ST_MakeValid

### FOR SHAPEFILE ONLY ###
# Create a spatial index on the Natura2000 table
psql -d sensingclues -c "CREATE INDEX ON Natura2000 USING gist(geom);"
# Drop the Natura2000nearest table if EXISTS
#psql -d sensingclues -c "DROP TABLE IF EXISTS Natura2000nearest;"
# Truncate the Natura2000nearest table if EXISTS
psql -d sensingclues -c "TRUNCATE Natura2000nearest;"

# Cannot just delete blocking records cause then nearest calculation for others is no longer correct
# Try to fix geometry during/after loading, or simplify
#psql -d sensingclues -c "DELETE FROM Natura2000 WHERE SITECODE IN ('SE0820434','SE0820433');"

# Create the Natura2000nearest table
psql -d sensingclues -c "CREATE TABLE Natura2000nearest (SITECODE VARCHAR, nearest_neighbors VARCHAR[]);"

# Create the function to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "CREATE OR REPLACE FUNCTION calculate_nearest_neighbors() RETURNS INTEGER AS '
DECLARE
  rec RECORD;
  nearest_sites VARCHAR[];
BEGIN
  FOR rec IN SELECT SITECODE, geom FROM Natura2000 LOOP
    nearest_sites := ARRAY(
      SELECT b.SITECODE
      FROM Natura2000 AS b
      WHERE rec.SITECODE != b.SITECODE
      ORDER BY rec.geom <-> b.geom
      LIMIT 5
    );
    INSERT INTO Natura2000nearest (SITECODE, nearest_neighbors) VALUES (rec.SITECODE, nearest_sites);
  END LOOP;
  SELECT 1 AS result;
END;
' LANGUAGE plpgsql;"

Run scripts

```
python3 natura2000nearest.py

python3 natura2000nearest_visualisation.py
```

Results

```
results/output.csv
```

[DEPRECATED] Switched to PostgreSQL with Shapefile

Call the function to calculate nearest neighbors and insert into Natura2000nearest table

`psql -d sensingclues -c "SELECT calculate_nearest_neighbors();"`

# Create a spatial index on the Natura2000 table
psql -d sensingclues -c "CREATE INDEX ON Natura2000 USING gist(geom);"
# Drop the Natura2000nearest table if EXISTS
#psql -d sensingclues -c "DROP TABLE IF EXISTS Natura2000nearest;"
# Truncate the Natura2000nearest table if EXISTS
psql -d sensingclues -c "TRUNCATE Natura2000nearest;"

# Cannot just delete blocking records cause then nearest calculation for others is no longer correct
# Try to fix geometry during/after loading, or simplify
#psql -d sensingclues -c "DELETE FROM Natura2000 WHERE SITECODE IN ('SE0820434','SE0820433');"

# Create the Natura2000nearest table
psql -d sensingclues -c "CREATE TABLE Natura2000nearest (SITECODE VARCHAR, nearest_neighbors VARCHAR[]);"

# Create the function to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "CREATE OR REPLACE FUNCTION calculate_nearest_neighbors() RETURNS INTEGER AS '
DECLARE
  rec RECORD;
  nearest_sites VARCHAR[];
BEGIN
  FOR rec IN SELECT SITECODE, geom FROM Natura2000 LOOP
    nearest_sites := ARRAY(
      SELECT b.SITECODE
      FROM Natura2000 AS b
      WHERE rec.SITECODE != b.SITECODE
      ORDER BY rec.geom <-> b.geom
      LIMIT 5
    );
    INSERT INTO Natura2000nearest (SITECODE, nearest_neighbors) VALUES (rec.SITECODE, nearest_sites);
  END LOOP;
  SELECT 1 AS result;
END;
' LANGUAGE plpgsql;"

# Call the function to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "SELECT calculate_nearest_neighbors();"

### PostgreSQL/PostGIS

Drop PostgreSQL database

`dropdb sensingclues`

Create a new PostgreSQL database

`createdb sensingclues`

Enable the PostGIS extension in the database

`psql -d sensingclues -c "CREATE EXTENSION IF NOT EXISTS postgis;"`

Load geopackage

`ogr2ogr -f PostgreSQL PG:"dbname='sensingclues'" /Users/emilzegers/GitHub/taatuut/NATURA9000/data/Natura2000_end2021_rev1.gpkg`

Connect to the database sensingclues. Use `\q` to quit `psql`.

```
psql -d sensingclues
psql (14.8 (Homebrew))
Type "help" for help.

sensingclues=# \dt+
                                           List of relations
 Schema |        Name        | Type  |   Owner    | Persistence | Access method |  Size   | Description 
--------+--------------------+-------+------------+-------------+---------------+---------+-------------
 public | bioregion          | table | emilzegers | permanent   | heap          | 1720 kB | 
 public | designationstatus  | table | emilzegers | permanent   | heap          | 5240 kB | 
 public | directivespecies   | table | emilzegers | permanent   | heap          | 240 kB  | 
 public | habitatclass       | table | emilzegers | permanent   | heap          | 13 MB   | 
 public | habitats           | table | emilzegers | permanent   | heap          | 21 MB   | 
 public | impact             | table | emilzegers | permanent   | heap          | 18 MB   | 
 public | management         | table | emilzegers | permanent   | heap          | 10 MB   | 
 public | metadata           | table | emilzegers | permanent   | heap          | 16 kB   | 
 public | natura2000sites    | table | emilzegers | permanent   | heap          | 55 MB   | 
 public | naturasite_polygon | table | emilzegers | permanent   | heap          | 1049 MB | 
 public | otherspecies       | table | emilzegers | permanent   | heap          | 30 MB   | 
 public | spatial_ref_sys    | table | emilzegers | permanent   | heap          | 6936 kB | 
 public | species            | table | emilzegers | permanent   | heap          | 40 MB   | 
(13 rows)
```

```
sensingclues=# \d+ naturasite_polygon
                                                                 Table "public.naturasite_polygon"
   Column   |          Type           | Collation | Nullable |                    Default                     | Storage  | Compression | Stats target | Description 
------------+-------------------------+-----------+----------+------------------------------------------------+----------+-------------+--------------+-------------
 id         | integer                 |           | not null | nextval('naturasite_polygon_id_seq'::regclass) | plain    |             |              | 
 sitecode   | character varying(200)  |           |          |                                                | extended |             |              | 
 sitename   | character varying(200)  |           |          |                                                | extended |             |              | 
 ms         | character varying(200)  |           |          |                                                | extended |             |              | 
 sitetype   | character varying(200)  |           |          |                                                | extended |             |              | 
 inspire_id | character varying(200)  |           |          |                                                | extended |             |              | 
 geom       | geometry(Geometry,3035) |           |          |                                                | main     |             |              | 
Indexes:
    "naturasite_polygon_pkey" PRIMARY KEY, btree (id)
    "naturasite_polygon_geom_geom_idx" gist (geom)
Access method: heap
```

# Create the procedure to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "CREATE OR REPLACE PROCEDURE procedure_calculate_nearest_neighbors()
LANGUAGE plpgsql
AS '
DECLARE
  rec RECORD;
  nearest_sites VARCHAR[];
BEGIN
  FOR rec IN SELECT SITECODE, geom FROM naturasite_polygon LOOP
    RAISE NOTICE ''SITECODE : %'', rec.SITECODE;
    nearest_sites := ARRAY(
      SELECT b.SITECODE
      FROM naturasite_polygon AS b
      WHERE rec.SITECODE != b.SITECODE
      ORDER BY rec.geom <-> b.geom
      LIMIT 5
    );
    INSERT INTO Natura2000nearest (SITECODE, nearest_neighbors) VALUES (rec.SITECODE, nearest_sites);
    COMMIT;
  END LOOP;
  SELECT 1 AS result;
END;
';"

Call the procedure to calculate nearest neighbors and insert into Natura2000nearest table

`psql -d sensingclues -c "CALL procedure_calculate_nearest_neighbors();"`

Count records in the table Natura2000nearest

`psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"`

Using watch (install with brew on macos) or alternative

```
watch -n 5 psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"
while :; do clear; psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"; sleep 5; done
```

Export the Natura2000nearest table to a CSV file named Natura2000nearest.csv

`psql -d sensingclues -c "COPY Natura2000nearest TO '/Users/emilzegers/GitHub/taatuut/NATURA9000/results/natura2000nearest.csv' WITH (FORMAT CSV, HEADER);"`

Count lines in the CSV file named Natura2000nearest.csv

`wc -l results/natura2000nearest.csv`

OPTIONAL: examine faster approach by rubberbanding Natura2000 polygons first, then running neareston rubberbands and compare results. Use https://postgis.net/docs/ST_ConvexHull.html


## Visualisation

Example visualisation of results:

![kaart](images/map.png "Kaart")

## Todo

- Check 'geopandas only calculates planar distances, so with data in lat-long you will always get significant errors'. May need to convert to reproject to a projected (equidistant?) coordinate system to get better accuracy.

## Questions

Q:
Shapefile and OGC Geopackage. Can Geopandas handle both formats? Which one is faster?

## Notes

1.
Natura2000_end2021_rev1_Shapefile.zip 677 MB from https://www.eea.europa.eu/data-and-maps/data/natura-14

To find out that again real life is bit more  complex. The data is in `EPSG:3035 - ETRS89-extended`, so should be reprojected to `EPSG:4326 - WGS84` for databases that only support WGS84 (like GraphDB, MongoDB, note that MarkLogic does support ETRS89). Be aware that both EPSG 3035 and 4326 are in decimal degrees, so will load into databases with WGS84 support. Maybe calculations sometimes even do produce the same results without reprojection, but that would not be the right way.
Reprojecting to EPSG:4326 - WGS84

You can reproject with `ogr2ogr`

```
ogr2ogr -f "ESRI Shapefile" Natura2000_end2021_rev1_epsg4326.json -s_srs EPSG:3035 -t_srs EPSG:4326 Natura2000_end2021_rev1_epsg3035.shp
```

2.
Looks like the source data already has 4 decimals only, need to doublecheck. If that is the case then useful to check if possible to limit number of decimals in or when loading into a database, or maybe the Shapefile to RDF triples tool does that?

`COORDINATE_PRECISION` is not supported for Shapefile, can be used with geojson but as said maybe not necessary, check source data decimals first.

Check this Shapefile to RDF tool: https://geotriples.di.uoa.gr/, and/or this one https://github.com/SLIPO-EU/TripleGeo

## Links

https://mapshaper.org/
