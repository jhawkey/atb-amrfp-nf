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

