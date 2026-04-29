# atb-amrfp-nf
Nextflow pipe for analysing AllTheBacteria genomes with AMRFinderPlus.

## Installation & Setup

### Create environment
First create a conda environment with Nextflow and AMRFinderPlus installed:

```
conda create -p /scratch2/md52/conda_envs/atb-amrfp

conda activate /scratch2/md52/conda_envs/atb-amrfp
conda install nextflow
conda install -c conda-forge -c bioconda --strict-channel-priority ncbi-amrfinderplus
# install the latest AMRFP database
amrfinder -u 
```

### Prepare ATB data
Second, the ATB archives need to be downloaded to the cluster and placed in a central directory.

Download the list of all files in ATB from OSF into your central ATB directory.
```
wget -O file_list.all.latest.tsv.gz https://osf.io/zxfmy/files/3xs6h
```

Then use this file to download each of the archive files for ATB into your central directory.
```
gunzip -c file_list.all.latest.tsv.gz  | awk -F"\t" 'NR>1 {print "wget -O "$4" "$5}' | uniq | bash
```

This file includes metadata on the genomes from the first release, 0.2, the incremental release 2024-08, and the incremental 2025-05 release.

Finally, file_list needs to be broken up into chunks of 200,000. This is so the pipeline will only ever process 200,000 genomes at a time, to prevent the working directory from getting too large and overwhelming disk space on the cluster. The pipe also uses nf-boost to assist with cleanup as it's running.

```
zcat file_list.all.latest.tsv.gz | head -1 > header.tmp
zcat file_list.all.latest.tsv.gz | tail -n +2 | split -l 200000 --numeric-suffixes=1 --additional-suffix=.tsv - file_list_chunk_
for file in file_list_chunk_*.tsv; do chunk_num=$(echo "$file" | sed 's/file_list_chunk_0*\([0-9]*\).tsv/\1/'); start_line=$(( ($chunk_num - 1) * 200000 + 2 )); end_line=$(( $chunk_num * 200000 + 1 )); new_name="file_list_n${start_line}_${end_line}.tsv"; cat header.tmp "$file" > "$new_name" && rm "$file"; done
```

## Usage

Three parameters that need to be set:

* `output_dir`: location for the final AMRFP output files (labelled <accession>_amrfinder.txt). **ALL** output files should be put here, as the pipeline will check against all accessions in `file_list` and skip any which have already been completed
* `archive_location`: folder where the ATB archives are stored
* `file_list`: list of files to process, extracted from `file_list.all.latest.tsv.gz`
* `-profile massive`: set this if running on the M3 cluster at Monash, otherwise execution will be local

```
conda activate /scratch2/md52/conda_envs/atb-amrfp

amrfp_atb.nf --output_dir <output_dir_location> \
--archive_location <archive_folder> \
--file_list file_list_n2_50001.tsv -profile massive
```

## Workflow

1. Check `file_list` and `output_dir` and determine if any genomes in `file_list` have already been processed. If yes, exclude from downstream processing
2. For accessions to process, extract from `file_list` the species of the genome, the archive file, and the fasta file path
3. Match the species to `unique_ATB_spp.txt` and extract the relevant AMRFP organism (as per the [AMRFP docs](https://github.com/ncbi/amr/wiki/Running-AMRFinderPlus#--organism-option)). If there is no matching organism, then ignore the species value and don't use it for the AMRFP call.
4. Extract the fasta file from the relevant ATB archive
5. Run AMRFP with the command below (note `-O $organism` will be omitted if there is no match):

```
amrfinder --name $accession -n $fasta_file --print_node --plus -O $organism -o ${accession}_amrfinder.txt
```

**The work directory should be removed between each run to prevent disk space issues**

Keeping track of commands and progress, as well as AMRFP version and database versions [here](https://github.com/jhawkey/atb-amrfp-nf/blob/main/RunLog.md)

## Prepare files for OSF

For the upload to OSF we need to:
1) concatenate all results files into a single file called `AMRFP_results.tsv.gz`
2) create the `AMRFP_status.tsv.gz` file which lists the status of every sample in ATB (PASS/FAIL for the run, if PASS but no hits, state this in the comments column)
3) create `amrfinderplus.parquet`, which adds two additional columns (genus and species) to the end of the AMRFP_results.tsv.gz file, so it can be filtered appropriately by the ATB cli

### File concatenation
```
# get header
find /scratch2/md52/atb_amrfp_2026-01-21 -type f -name '*_amrfinder.txt' -print -quit | xargs head -n 1 | gzip -c > /scratch2/md52/AMRFP_results.tsv.gz
# concat all files sans header
find /scratch2/md52/atb_amrfp_2026-01-21 -type f -name '*_amrfinder.txt' -print0 | xargs -0 -n 1000 tail -q -n +2 | gzip -c >> /scratch2/md52/AMRFP_results.tsv.gz
```

### Create status file
Use the `generate_amr_status.py` file in this repo. Requires `file_list.all.latest.tsv.gz` and `incomplete_atb_amrfp.txt`, which lists all samples which did not successfully complete through the pipeline.
This script needs python 3 but has no other dependencies.

### Create the parquet database file
Use the `create_amrfp_parquet.R` file. Needs an **uncompressed version of AMRFP_results.tsv** as input, alongside `file_list.all.latest.tsv.gz` which is where it will get the genus and species information from.
Requires the following libraries to be installed:
  * dplyr
  * tidyr
  * arrow

Will create an output folder called `parquet_out` which will contain one or more .parquet files that can be concatenated using the following commands:
```
library(arrow)
final_table <- open_dataset("parquet_out")
write_parquet(final_table, "amrfinderplus.parquet")
```

Check that final table and the original file contain the same number of rows
```
dim(final_table) # from above
results_ds$num_rows # see how to read in from the create_amrfp_parquet.R script, is quick
```

## Contributions

This pipeline was workshopped at the IMMEM 2025 Hackathon by Jane Hawkey, Raphi Sieber, and  Erkison Ewomazino Odih.

