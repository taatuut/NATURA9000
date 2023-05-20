# Install PostgreSQL and PostGIS using brew
brew install postgresql postgis

# Some Docker relics to remove sometimes...
# Error: Permission denied @ apply2files - /usr/local/lib/docker/cli-plugins
# sudo rm -r /usr/local/lib/docker/cli-plugins

# Initialize the PostgreSQL database
initdb /usr/local/var/postgres

# Start the PostgreSQL service
pg_ctl -D /usr/local/var/postgres -l logfile start

# Stop
#pg_ctl -D /usr/local/var/postgres stop

# Create a new PostgreSQL database
createdb sensingclues

# Enable the PostGIS extension in the database
psql -d sensingclues -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Load the shapefile into the Natura2000 table
shp2pgsql -s 3035 -I Natura2000_end2021_rev1_epsg3035.shp Natura2000 | psql -d sensingclues

# Create a spatial index on the Natura2000 table
psql -d sensingclues -c "CREATE INDEX ON Natura2000 USING gist(geom);"

# Drop the Natura2000nearest table if EXISTS
#psql -d sensingclues -c "DROP TABLE IF EXISTS Natura2000nearest;"

# Truncate the Natura2000nearest table if EXISTS
psql -d sensingclues -c "TRUNCATE Natura2000nearest;"

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
  FOR rec IN SELECT SITECODE, geom FROM Natura2000 LOOP
    RAISE NOTICE ''sc : %'', rec.SITECODE;
    nearest_sites := ARRAY(
      SELECT b.SITECODE
      FROM Natura2000 AS b
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
#watch -n 5 psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"
#while :; do clear; psql -d sensingclues -c "SELECT COUNT(*) FROM Natura2000nearest"; sleep 5; done

# Export the Natura2000nearest table to a CSV file named Natura2000nearest.csv
psql -d sensingclues -c "COPY Natura2000nearest TO '/Users/emilzegers/GitHub/taatuut/NATURA9000/results/natura2000nearest.csv' WITH (FORMAT CSV, HEADER);"
