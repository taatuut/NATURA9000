'''
Setup:
python3 -m pip install --upgrade pip
python3 -m pip install dbf
'''

import dbf

def count_dbf_records(file): # Assumes dbf file, no checks yet
    # Open the dbf file
    table = dbf.Table(file)
    # Count the number of records in the file
    return len(table)

file = 'Natura2000_end2021_rev1_epsg3035.dbf'
count = count_dbf_records(file)
# Print the result
print("Number of records:", count)


'''
python3 count_dbf_records.py
'''