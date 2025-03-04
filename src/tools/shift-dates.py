#!/usr/bin/env python3

"""
Script to shift all invoice dates in an SQL file back by one year.
Usage: python3 shift-dates-python.py input_file output_file
"""

import re
import sys

def shift_dates(input_file, output_file):
    """Read input file, shift all dates back by 1 year, and write to output file."""
    
    # Regular expression to match dates in the format: date 'YYYY-MM-DD'
    date_pattern = re.compile(r"date '(\d{4})-(\d{1,3})-(\d{1,3})'")
    
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            # Function to replace each date with a year shifted back by 1
            def replace_date(match):
                year = int(match.group(1)) - 1
                month = match.group(2)
                day = match.group(3)
                return f"date '{year}-{month}-{day}'"
            
            # Replace all dates in the line
            modified_line = date_pattern.sub(replace_date, line)
            outfile.write(modified_line)
    
    print(f"Date shift completed. All invoice dates shifted back by 1 year.")
    print(f"Output written to {output_file}")

if __name__ == "__main__":
    # Check if correct number of arguments is provided
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input_file output_file")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Call the function to shift dates
    shift_dates(input_file, output_file)
