#!/usr/bin/env python3

import sys
import os
import gzip

def check_output_dir(output_dir, file_list):
    """
    Read file list and exclude accessions that already have results in output_dir.
    
    Args:
        output_dir: Directory containing existing AMRFinder results
        file_list: Path to gzip-compressed TSV file with accession, species, and file path
    """
    
    # Get list of already processed accessions
    processed = set()
    if os.path.exists(output_dir):
        for filename in os.listdir(output_dir):
            if filename.endswith("_amrfinder.txt"):
                accession = filename.replace("_amrfinder.txt", "")
                processed.add(accession)
    
    # Read file list and output unprocessed entries
    with open(file_list, "rt") as fh:
        header = 0
        if header == 0:
            next(fh)  # Skip header line
            header = 1
        for line in fh:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split("\t")
            accession = parts[0]
            if accession not in processed:
                print(line)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: check_output_dir.py <output_dir> <file_list>", file=sys.stderr)
        sys.exit(1)
    
    output_dir = sys.argv[1]
    file_list = sys.argv[2]
    
    check_output_dir(output_dir, file_list)
