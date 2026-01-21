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
wget -O file_list.all.latest.tsv.gz https://osf.io/zxfmy/files/4yv85
```

Then use this file to download each of the archive files for ATB into your central directory.
```
gunzip -c file_list.all.latest.tsv.gz  | awk -F"\t" 'NR>1 {print "wget -O "$5" "$6}' | uniq | bash
```

Note that this file only include metadata on the genomes from the first release, 0.2, and the incremental release 2024-08.

It **does not** include the genome information for genomes in the 2025-05 release.

Finally, file_list needs to be broken up into chunks of 50,000. This is so the pipeline will only ever process 50,000 genomes at a time, to prevent the working directory from getting too large and overwhelming disk space on the cluster. 

```
zcat file_list.all.latest.tsv.gz | head -1 > header.tmp
zcat file_list.all.latest.tsv.gz | tail -n +2 | split -l 50000 --numeric-suffixes=1 --additional-suffix=.tsv - file_list_chunk_
for file in file_list_chunk_*.tsv; do chunk_num=$(echo "$file" | sed 's/file_list_chunk_0*\([0-9]*\).tsv/\1/'); start_line=$(( ($chunk_num - 1) * 50000 + 2 )); end_line=$(( $chunk_num * 50000 + 1 )); new_name="file_list_n${start_line}_${end_line}.tsv"; cat header.tmp "$file" > "$new_name" && rm "$file"; done
```

## Usage

Three parameters that need to be set:

* `output_dir`: location for the final AMRFP output files (labelled <accession>_amrfinder.txt). **ALL** output files should be put here, as the pipeline will check against all accessions in `file_list` and skip any which have already been completed
* `archive_location`: folder where the ATB archives are stored
* `file_list`: list of files to process, extracted from `file_list.all.latest.tsv.gz`
* `-profile massive`: set this is running on the M3 cluster at Monash, otherwise execution will be local

```
conda activate /scratch2/md52/conda_envs/atb-amrfp
amrfp_atb.nf --output_dir <output_dir_location> --archive_location <archive_folder> --file_list file_list_n2_50001.tsv -profile massive
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

## Contributions

This pipeline was workshopped at the IMMEM 2025 Hackathon by Jane Hawkey, Raphi Sieber, and  Erkison Ewomazino Odih.

