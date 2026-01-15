# LuxMotifScan (Snakemake + PBS/Slurm friendly)

This pipeline prepares reference genomes and scans Lux-box motifs using FIMO (MEME suite).

## Concepts
- `base_dir` = where your input data lives AND where outputs are written.
- Many HPC systems have **offline compute nodes**. This repo supports that by:
  1) creating conda environments on a node WITH internet (login node)
  2) running jobs on compute nodes without internet using the cached envs on shared storage

## Install (driver environment)
Create the Snakemake “driver env” (one-time):
```bash
conda env create -f workflow/envs/driver.yml -n lux_smk24
conda activate lux_smk24
