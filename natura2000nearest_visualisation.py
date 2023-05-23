import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
import contextily as ctx

# Use the test shapefile
shapefile_path = "data/test.shp"
# Uncomment next line to use the Natura2000 shapefile
#shapefile_path = 'data/Natura2000_end2021_rev1_epsg3035.shp'

# TODO: for now copy results/natura2000nearest.csv to results/output.csv and remove header and array format
# Path to the CSV file containing the selected values
csv_path = 'results/output.csv'

# Read the Shapefile into a GeoDataFrame
gdf = gpd.read_file(shapefile_path)

# Read the CSV file into a DataFrame
df = pd.read_csv(csv_path, header=None)

# Create a new column 'highlight' and set it to False for all features
gdf['highlight'] = False

# List to store distinct values
distinct_values = []

# Iterate over each line in the CSV file
for index, row in df.iterrows():
    # Reset the 'highlight' column to False for all features
    gdf['highlight'] = False

    # Get the values from the current line
    values = row.dropna().tolist()

    # Lookup lines in the CSV starting with each SITECODE value
    for sitecode in values:
        matching_lines = df[df[0].str.startswith(sitecode)]
        values_from_lines = matching_lines.iloc[:, 1:].values.flatten().tolist()
        distinct_values.extend(values_from_lines)
    print(distinct_values)

    # Highlight the features with the selected values
    selected_features = gdf[gdf['SITECODE'].isin(values)]
    selected_features.loc[selected_features.index[0], 'highlight'] = True

    # Calculate the bounding box coordinates for the selected features
    bbox = selected_features.total_bounds
    # NOTE: total_bounds is returned without commas, can this be configured?
    print(bbox)

    # Plot the selected features
    fig, ax = plt.subplots(figsize=(10, 10))

    # Plot the close features as the first layer
    close_features = gdf[gdf['SITECODE'].isin(distinct_values)]
    close_features.plot(ax=ax, color='lightgray', edgecolor='black', alpha=0.2)

    # Plot the selected features
    selected_features.plot(ax=ax, color='red', edgecolor='orange', alpha=0.2)
    selected_features.iloc[1:].plot(ax=ax, color='blue', edgecolor='green', alpha=0.2)

    # Label the selected features with the SITECODE value
    for x, y, label in zip(selected_features.iloc[:1].geometry.centroid.x, selected_features.geometry.centroid.y, selected_features['SITECODE']):
        ax.text(x+10, y+10, label, color='red', fontsize=10, ha='center', va='center')
    for x, y, label in zip(selected_features.iloc[1:].geometry.centroid.x, selected_features.geometry.centroid.y, selected_features['SITECODE']):
        ax.text(x+10, y+10, label, color='black', fontsize=8, ha='center', va='center')

    # Plot the OpenStreetMap basemap using the bounding box
    # NOTE: fails with extent because bbox lacks comma separation... not necessary here though
    #ctx.add_basemap(ax, crs=gdf.crs.to_string(), source=ctx.providers.OpenStreetMap.Mapnik, extent=bbox, alpha=0.5)
    ctx.add_basemap(ax, crs=gdf.crs.to_string(), source=ctx.providers.OpenStreetMap.Mapnik, alpha=0.5)

    # Save map to image file, just overwrite for now to keep last one only
    plt.savefig('results/map'+str(sitecode)+'.png', bbox_inches='tight')
    # Pause and wait for user confirmation
    # plt.show()
    # user_input = input("Press Enter to continue to the next line (or 'q' to quit): ")
    # if user_input.lower() == 'q':
    #     break

print('Done')