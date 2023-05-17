import geopandas as gpd
import csv

# Use the test shapefile
file = "test.shp"
# Uncomment next line to use the full Natura2000 shapefile  
file = "Natura2000_end2021_rev1_epsg3035.shp"
shp = gpd.read_file(file)
shp.sindex

output = 'output.csv'
# Open the CSV file for writing (or appending)
with open(output, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    # NOTE: csv.writer saves to files in batches of 72-73 rows? Or interval bases?

    # Loop through each polygon geometry
    for i, poly in enumerate(shp.geometry):

        # Find the nearest three polygons
        nearest = shp.geometry[shp.geometry.distance(poly).argsort()[1:6]].index.tolist()
        # Did not feel like solving code for not selecting self as nearest in case of multi polygons or other causes
        # Just get 5 nearest neighbours instead of 3 and filter later
        # Multi polygons might give unpredictable results because will show up multiple times in results? Check!

        # Print the polygon ID and the IDs of the nearest polygons
        print(f"Polygon {i} is nearest to polygons {nearest}")

        # Get the ID of the current polygon
        poly_id = shp.loc[i, 'SITECODE']

        # Write the polygon SITECODE and the SITECODEs of the nearest polygons to the CSV file
        writer.writerow([poly_id, shp.loc[nearest[0], 'SITECODE'], shp.loc[nearest[1], 'SITECODE'], shp.loc[nearest[2], 'SITECODE'], shp.loc[nearest[3], 'SITECODE'], shp.loc[nearest[4], 'SITECODE']])

