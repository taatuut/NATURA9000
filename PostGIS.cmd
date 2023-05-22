# Install PostgreSQL and PostGIS using brew
brew install postgresql postgis

# Some Docker relics to remove sometimes...
# Error: Permission denied @ apply2files - /usr/local/lib/docker/cli-plugins
# sudo rm -r /usr/local/lib/docker/cli-plugins

# Initialize the PostgreSQL database
initdb /usr/local/var/postgres

# Stop
pg_ctl -D /usr/local/var/postgres stop

# Start the PostgreSQL service
pg_ctl -D /usr/local/var/postgres -l logfile start

# Drop PostgreSQL database
dropdb sensingclues

# Create a new PostgreSQL database
createdb sensingclues

# Enable the PostGIS extension in the database
psql -d sensingclues -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Load geopackage
ogr2ogr -f PostgreSQL PG:"dbname='sensingclues'" /Users/emilzegers/GitHub/taatuut/NATURA9000/data/Natura2000_end2021_rev1.gpkg

### OR ###

# Load the shapefile into the table Natura2000
#shp2pgsql -s 3035 -I Natura2000_end2021_rev1_epsg3035.shp Natura2000 | psql -d sensingclues

# TODO: If geopackage no alternative, use shapefile and update the table Natura2000 with ST_MakeValid

# Comnect to the database sensingclues
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

# Call the function to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "SELECT calculate_nearest_neighbors();"

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

# Call the procedure to calculate nearest neighbors and insert into Natura2000nearest table
psql -d sensingclues -c "CALL procedure_calculate_nearest_neighbors();"

# Count records in the table Natura2000nearest
psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"

# using watch (install with brew on macos) or alternative
watch -n 5 psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"
while :; do clear; psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"; sleep 5; done

# Export the Natura2000nearest table to a CSV file named Natura2000nearest.csv
psql -d sensingclues -c "COPY Natura2000nearest TO '/Users/emilzegers/GitHub/taatuut/NATURA9000/results/natura2000nearest.csv' WITH (FORMAT CSV, HEADER);"

# Count lines in the CSV file named Natura2000nearest.csv
wc -l results/natura2000nearest.csv

# OPTIONAL: examine faster approach by rubberbanding Natura2000 polygons first, then running neareston rubberbands and compare results. Use https://postgis.net/docs/ST_ConvexHull.html
