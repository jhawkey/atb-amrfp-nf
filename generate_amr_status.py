import gzip
import csv

# File paths
results_file = 'AMRFP_results.tsv.gz'
master_list_file = 'file_list.all.latest.tsv.gz'
fail_list_file = 'incomplete_atb_amrfp.txt'
output_file = 'AMRFP_status.tsv.gz'

def generate_fast_test():
    # 1. Load ONLY the first column of the failure list
    print("Loading failure list (column 1 only)...")
    fail_samples = set()
    try:
        with open(fail_list_file, 'r') as f:
            # We use csv.reader here too to handle potential tabs in the fail list
            reader = csv.reader(f, delimiter='\t')
            for row in reader:
                if row:
                    fail_samples.add(row[0].strip())
    except FileNotFoundError:
        print(f"Notice: {fail_list_file} not found.")

    # 2. Index ONLY the first 30 entries of the results file
    samples_with_hits = set()
    #print(f"Peeking at the first {limit} lines of the results file...")
    print("Parsing results file...")
    with gzip.open(results_file, 'rt') as f:
        reader = csv.reader(f, delimiter='\t')
        next(reader, None) # Skip header
        
        for i, row in enumerate(reader):
            #if i >= limit:
            #    break
            if row:
                samples_with_hits.add(row[0].strip())

    # 3. Process ONLY the first 30 samples from the master list
    #print(f"Generating status file for first {limit} master samples...")
    print("Generating status file...")
    with gzip.open(output_file, 'wt') as out_f:
        writer = csv.writer(out_f, delimiter='\t')
        writer.writerow(['sample', 'status', 'comment'])

        with gzip.open(master_list_file, 'rt') as f:
            reader = csv.reader(f, delimiter='\t')
            next(reader, None) # Skip header
            
            for i, row in enumerate(reader):
                #if i >= limit:
                #    break
                if not row: continue
                
                sample_id = row[0].strip()
                
                # Check if this sample is marked as a failure
                if sample_id in fail_samples:
                    continue
                
                status = "PASS"
                comment = ""
                
                # Check against the tiny peeked results set
                if sample_id not in samples_with_hits:
                    comment = "No AMRFinderPlus hits detected"
                
                writer.writerow([sample_id, status, comment])

        # 4. Append the FAIL samples
        # We only append them here so they don't get the 'PASS' logic above
        for sample_id in sorted(fail_samples):
            writer.writerow([sample_id, "FAIL", ""])

    print(f"Fast test complete! Created {output_file}")

if __name__ == "__main__":
    generate_fast_test()
