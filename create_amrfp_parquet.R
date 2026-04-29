#!/usr/bin/env Rscript

library(arrow)
library(tidyr)
library(dplyr)

# 1. Prepare the Metadata (The small file)
# We read this fully into RAM since it's only 23MB
print("Processing metadata...")
metadata <- read_tsv_arrow("file_list.all.latest.tsv.gz") %>% select(sample, sylph_species) %>% mutate(genus = sub(" .*", "", sylph_species), species = sylph_species) %>% select(sample, genus, species)

# Convert metadata to an Arrow Table to keep the join inside the Arrow engine
metadata_arrow <- as_arrow_table(metadata)

amrfp_schema <- schema(
  Name = string(),
  `Protein id` = string(),           # Fixed from null
  `Contig id` = string(),
  Start = int64(),
  Stop = int64(),
  Strand = string(),
  `Element symbol` = string(),
  `Element name` = string(),
  Scope = string(),
  Type = string(),
  Subtype = string(),
  Class = string(),
  Subclass = string(),
  Method = string(),
  `Target length` = int64(),
  `Reference sequence length` = int64(),
  `% Coverage of reference` = double(),
  `% Identity to reference` = double(),
  `Alignment length` = int64(),
  `Closest reference accession` = string(),
  `Closest reference name` = string(),
  `HMM accession` = string(),        # Fixed from null
  `HMM description` = string(),      # Fixed from null
  `Hierarchy node` = string()
)

# 2. Open the Results file as an Arrow Dataset (The big file)
# This is 'lazy'—it does NOT load the 14GB into RAM.
print("Mapping the AMRFP_results.tsv file...")
results_ds <- open_dataset("AMRFP_results.tsv", format = "tsv", schema = amrfp_schema, skip_rows=1)

# 3. Perform the Join and Write to Parquet
# Arrow is smart enough to join the small in-memory table 
# to the streaming big table and write it out efficiently.
print("Joining and writing to Parquet. This may take a few minutes...")

all_results <- results_ds %>% left_join(metadata_arrow, by = c("Name" = "sample"))
all_results %>% write_dataset(path = "parquet_out", format = "parquet", compression = "zstd")

print("Success! AMRFP Parquet file created.")
