# NATURA9000

Playing with the Natura 2000 data

https://en.wikipedia.org/wiki/HAL_9000

## Setup

Created on a MacBook Pro

'''
python3 -m pip install --upgrade pip
python3 -m pip install geopandas matplotlib contextily
'''

'''
brew install gdal
'''

## Script

Python scripts

'''
count_dbf_records.py

natura2000nearest.py

natura2000nearest_visualisation.py
'''

## Data

Go to https://www.eea.europa.eu/data-and-maps/data/natura-14

Click GIS Data

Download Natura 2000 - Spatial data

Natura 2000 End 2021 - Shapefile

Natura 2000 End 2021 - OGC Geopackage

Unzip Shapefile to folder `data`.

### Test

The fid is internal feature id in numeric format.

To write specific features to a test shapefile with limited number of features using fid to select:

```
ogr2ogr -lco ENCODING=UTF-8 -sql "SELECT * FROM Natura2000_end2021_rev1_epsg3035 WHERE fid IN (1,2,3,4,5,6,7,8,9,10)" test.shp Natura2000_end2021_rev1_epsg3035.shp
```

Write first x features to a test shapefile using fid:

```
ogr2ogr -lco ENCODING=UTF-8 -sql "SELECT * FROM Natura2000_end2021_rev1_epsg3035 WHERE fid < 1000" test.shp Natura2000_end2021_rev1_epsg3035.shp
```

FYI: create spatial index, qix is open source alternative for shx, not tested if geopandas uses either of these anyway so could skip this step. Also using geopandas .sindex but not assessed impact.

```
ogrinfo --config CPL_DEBUG ON -sql "CREATE SPATIAL INDEX ON Natura2000_end2021_rev1_epsg3035" Natura2000_end2021_rev1_epsg3035.shp
```

```
ogrinfo --config CPL_DEBUG ON -sql "CREATE SPATIAL INDEX ON test" test.shp
```

## Run

```
python3 natura2000nearest.py
```

## Todo

- Check 'geopandas only calculates planar distances, so with data in lat-long you will always get significant errors'. May need to convert to reproject to a projected (Equidistant?) coordinate system to get better accuracy.

# Questions

Q:
Shapefile and OGC Geopackage. Can Geopandas handle both formats? Which one is faster?

## Links

https://mapshaper.org/
