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

First chunk of 50,000 genomes had a final work directory size of 392Gb. The final output directory is still in the Mbs. So we can definitely double the number of genomes being processed at one time, plus add in the nf-boost cleanup functionality.

