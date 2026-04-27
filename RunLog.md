# Run Log

## 2026-01-21

Running all ATB (0.2 and incremental release 2024-08) with AMRFinderPlus v4.2.5, database 2025-12-03.1.

First chunk of 50,000 - will check disk usage of work + output directory after this to see if larger lists of files can be accommodated.
```
conda activate /scratch2/md52/conda_envs/atb-amrfp

./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 \
--archive_location /scratch2/md52/atb_archives \
--file_list /scratch2/md52/atb_archives/file_list_n2_50001.tsv \
-profile massive
```

## 2026-01-22
First chunk of 50,000 genomes had a final work directory size of 392Gb. The final output directory is still in the Mbs. So we can definitely double the number of genomes being processed at one time, plus add in the nf-boost cleanup functionality.

Creating list of 100,000 genomes:
```
(head -n 1 file_list_n50002_100001.tsv; tail -n +2 file_list_n50002_100001.tsv; tail -n +2 file_list_n100002_150001.tsv) > file_list_n50002_150001.tsv
```

Running (note this now includes the nf-boost in the config file, check how big work dir is when this has finished - should be less than predicted 800Gb as fasta files should get deleted)
```
./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 --archive_location /scratch2/md52/atb_archives --file_list /scratch2/md52/atb_archives/file_list_n50002_150001.tsv -profile massive
```

## 2026-01-26
Next 100,000 genomes (previous set took 1d5h to complete). Work dir was only a few 100Gb so definitely nf-boost cleanup function worked as expected. Weird though that nf said it was running only 99,991 genomes but anyway
```
(head -n 1 file_list_n150002_200001.tsv; tail -n +2 file_list_n150002_200001.tsv; tail -n +2 file_list_n200002_250001.tsv) > file_list_n150002_250001.tsv 
```

Running
```
./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 --archive_location /scratch2/md52/atb_archives --file_list /scratch2/md52/atb_archives/file_list_n150002_250001.tsv -profile massive
```

## 2026-01-28

```
(head -n 1 file_list_n250002_300001.tsv; tail -n +2 file_list_n250002_300001.tsv; tail -n +2 file_list_n300002_350001.tsv) > file_list_n250002_350001.tsv
./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 --archive_location /scratch2/md52/atb_archives --file_list /scratch2/md52/atb_archives/file_list_n250002_350001.tsv -profile massive
```

## 2026-01-30
First create new set of files that are 100,000 in size. Mean's next run we'll ignore the first 50,000 but easier to keep track of going forward
```
# get header
zcat file_list.all.latest.tsv.gz | head -1 > header.tmp
# split into 100,000 chunks
zcat file_list.all.latest.tsv.gz | tail -n +2 | split -l 100000 -d --additional-suffix=.tsv - file_list.chunk_
# rename with ranges and add header to each file
for file in file_list.chunk_*.tsv; do
  chunk_num=$(echo "$file" | sed 's/file_list.chunk_0*//' | sed 's/.tsv//')
  start=$((10#$chunk_num * 100000 + 1))
  end=$((start + $(wc -l < "$file") - 1))
  new_name="file_list.lines_${start}-${end}.tsv"
  cat header.tmp "$file" > "$new_name"
  rm "$file"
done
```

Now run next set
```
./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 --archive_location /scratch2/md52/atb_archives --file_list /scratch2/md52/atb_archives/file_list.lines_300001-400000.tsv -profile massive
```

## 2026-03-30
Eventually updated the number of genomes being processed at one time to 200,000.

**Now running the 2025-05 incremental release**
When I started this process, this release hadn't been made available yet. Including it now.

First, extract wget commands for all the archives for this release and download them:
```
gunzip -c file_list.all.latest.tsv.gz | awk -F"\t" 'NR>1 && /202505/ {print "wget -O "$4" "$5}' | uniq > wget_cmds.txt
sort -u wget_cmds.txt > wget_cmds_unique.txt
while read line; do echo $line; $line; done < wget_cmds.txt
```

Create the chunked set of 200,000 files, but only do it for those in the incremental release.
```
# Extract header
zcat file_list.all.latest.tsv.gz | head -1 > header.tmp

# Filter for incr_release.202505 lines and split into 200k-line chunks
zcat file_list.all.latest.tsv.gz | tail -n +2 | grep 'incr_release\.202505' | split -l 200000 --numeric-suffixes=1 --additional-suffix=.tsv - file_list_chunk_

# Prepend header to each chunk and rename
for file in file_list_chunk_*.tsv; do
    chunk_num=$(echo "$file" | sed 's/file_list_chunk_0*\([0-9]*\).tsv/\1/')
    start_line=$(( ($chunk_num - 1) * 200000 + 2 ))
    end_line=$(( $chunk_num * 200000 + 1 ))
    new_name="file_list_incr_202505_n${start_line}_${end_line}.tsv"
    cat header.tmp "$file" > "$new_name" && rm "$file"
done

rm header.tmp
```

The name of the species column has changed from `species_sylph` to `sylph_species`. However it's still the second column of the file. The `species_miniphy` column is also now missing (column 3). Have updated the nextflow pipe to take this into account.

## 2026-04-14

All samples now completed. Asked Warp AI (used CodeX and Claude) to write some bash code to help me work out if there were any samples that were missing from the output directory. It wrote the following:

```
tmp_existing=$(mktemp)
find /scratch2/md52/atb_amrfp_2026-01-21 -type f -name '*_amrfinder.txt' -printf '%f\n' | sed 's/_amrfinder\.txt$//' > "$tmp_existing"
awk -F '\t' -v out='/scratch2/md52/incomplete_atb_amrfp.txt' '
NR==FNR { have[$1]=1; next }
FNR==1 { print > out; next }
!($1 in have) { print > out; missing++ }
END { print missing+0 }
' "$tmp_existing" <(gzip -dc /scratch2/md52/atb_archives/file_list.all.latest.tsv.gz)
rm -f "$tmp_existing"
```

There were 7 genomes where we had no output file. Re-running just these using the `incomplete_atb_amrfp.txt` file.

```
./amrfp_atb.nf --output_dir /scratch2/md52/atb_amrfp_2026-01-21 --archive_location /scratch2/md52/atb_archives --file_list /scratch2/md52/incomplete_atb_amrfp.txt -profile massive
```

Genomes failed due to out of memory errors from AMRFP, could not get them to pass. Leaving for now.

## 2026-04-22

Combining all files into a single file. Cannot use a simple `cat` command to do this as ~2.7 million files is too many for the os to pass to the command.
```
# get header
find /scratch2/md52/atb_amrfp_2026-01-21 -type f -name '*_amrfinder.txt' -print -quit | xargs head -n 1 | gzip -c > /scratch2/md52/AMRFP_results.tsv.gz
# concat all files sans header
find /scratch2/md52/atb_amrfp_2026-01-21 -type f -name '*_amrfinder.txt' -print0 | xargs -0 -n 1000 tail -q -n +2 | gzip -c >> /scratch2/md52/AMRFP_results.tsv.gz
```












