# Prepare environment using steps from README

# Step 1: Create a new table to store the results

psql -d sensingclues -c "CREATE TABLE IF NOT EXISTS nearest_features (
  source_sitecode TEXT,
  target_sitecode TEXT,
  distance FLOAT,
  resolution_time INTERVAL
);"

# Step 2: Define the configurable parameters

psql -d sensingclues -c "DO $$DECLARE
  parallel_workers INTEGER := 6; -- Set the number of parallel workers here (2 to 16)
BEGIN
  -- Step 3: Create a function to find the nearest features for each source feature
  CREATE OR REPLACE FUNCTION find_nearest_features(source_sitecode TEXT) RETURNS INTEGER AS '
  DECLARE
    nearest_cursor CURSOR FOR
      SELECT DISTINCT ON (nf.sitecode) nf.sitecode, ST_Distance(sf.geometry, nf.geometry) AS distance
      FROM naturasite_polygon AS sf, naturasite_polygon AS nf
      WHERE sf.sitecode = source_sitecode
        AND nf.sitecode <> source_sitecode
      ORDER BY nf.sitecode, sf.geometry <-> nf.geometry
      LIMIT 5;
    nearest_record RECORD;
    start_time TIMESTAMP;
  BEGIN
    start_time := clock_timestamp();
    
    -- Step 4: Loop through the nearest features and insert them into the result table
    FOR nearest_record IN nearest_cursor LOOP
      INSERT INTO nearest_features (source_sitecode, target_sitecode, distance, resolution_time)
      VALUES (source_sitecode, nearest_record.sitecode, nearest_record.distance, clock_timestamp() - start_time);
    END LOOP;
  END;
' LANGUAGE plpgsql;"

## Step 5: Enable parallel execution for the function
ALTER FUNCTION find_nearest_features SET parallel_workers = parallel_workers;

## Step 6: Run the function for each feature in parallel
WITH source_features AS (
  SELECT DISTINCT sitecode
  FROM naturasite_polygon
)
SELECT find_nearest_features(source_sitecode)
FROM source_features
ORDER BY source_sitecode;
$$;
