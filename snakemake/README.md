# LuxMotifScan (PBS-ready Lux-box motif scanning)

LuxMotifScan is an HPC-friendly pipeline that prepares genome files (GFF + FASTA), builds Lux-box motifs, generates a genome FASTA list, and runs **FIMO** scans in parallel via **PBS/OpenPBS**.

✅ **Main usage:** after setup, users run **one command**:

```bash
./luxmotif_pipeline.sh
```

It will prompt for the dataset folder (BASE_DIR) and then run the full pipeline.

---

## What the pipeline does

### W0 steps (prepare inputs)

* **W0a**: Unzip genomes + collect GFF/FASTA into `BASE_DIR/GFFnFASTA/`
* **W0b**: Make contig IDs consistent between FASTA and GFF; archive old files
* **W0c**: Create `BASE_DIR/lux_motifs.meme`
* **W0d**: Create `BASE_DIR/reference_genomes.list` (paths to processed FASTAs)

### W1 step (scan motifs)

* Submits a PBS job to run **FIMO** on each FASTA in `reference_genomes.list`
* Writes results under `BASE_DIR/fimo_output/`

---

## Input format (what users provide)

Create a dataset folder (BASE_DIR) containing **zip files**, one per genome. Each zip should contain:

* a **GFF** file (`*.gff` / `*.gtf`)
* a **FASTA** file (`*.fa` / contigs FASTA)

Example:

```
BASE_DIR/
  BL16A.zip
  GV4.zip
  K61.zip
  Y88A.zip
```

---

## Output files (inside BASE_DIR)

After a successful run, BASE_DIR will contain:

* `GFFnFASTA/`
  processed GFF + FASTA files (contigs synced/renamed)
* `lux_motifs.meme`
  MEME motif file for FIMO
* `reference_genomes.list`
  FASTA list used for scanning
* `fimo_output/fimo_run_<RUN_ID>/`
  per-genome FIMO outputs + run log + summary

---

## One-time setup (per user / per HPC account)

W1 needs **FIMO (MEME suite)** on compute nodes. On many HPC systems it is **not installed by default**, and PBS jobs do **not** inherit your interactive shell PATH.

### Recommended (portable): create a conda MEME/FIMO env once

Run this **once on a login node with internet**:

```bash
cd LuxMotifScan/snakemake
chmod +x setup_meme_env.sh
./setup_meme_env.sh              # default env name: luxmotifscan_meme
# or: ./setup_meme_env.sh myenv   # custom env name
```

After this, **compute nodes can be offline** — the PBS job will run FIMO via:

* cluster module (`module load meme`) if available, OR
* `conda --no-plugins run -n <env> ...` using the env you created above

### If you use a custom env name

Set it before running the pipeline:

```bash
export LUX_MEME_ENV=myenv
```

## Run (the normal user flow)

From the repo directory:

```bash
chmod +x luxmotif_pipeline.sh
./luxmotif_pipeline.sh
```

It will ask:

```
Enter BASE directory: /path/to/BASE_DIR
```

Then it runs W0 steps and submits the W1 PBS job.

### Non-interactive run (optional)

You can also pass BASE_DIR as an argument:

```bash
./luxmotif_pipeline.sh /path/to/BASE_DIR
```

---

## Monitoring jobs

When the pipeline submits the W1 PBS job, you can monitor it:

```bash
qstat <jobid>
tail -f lux_fimo.o<jobid>
```

---

## Adding new genomes

Just add new `*.zip` files into BASE_DIR and run again:

```bash
./luxmotif_pipeline.sh /path/to/BASE_DIR
```

It will rebuild/update inputs as needed and rescan.

---

## Repo contents

* `luxmotif_pipeline.sh` — main launcher (runs W0 + submits W1)
* `W0a_*` `W0b_*` `W0c_*` `W0d_*` — preprocessing
* `W1_run_fimo_parallel.sh` — FIMO parallel runner
* `W1_run_fimo_parallel.pbs` — PBS wrapper for W1
* `workflow/` — optional Snakemake workflow (not required for normal use)
* `condarc` — conda channel restrictions (useful on restricted networks)

---

## Notes / common issues

### “Motif file missing” or “FASTA list missing”

These must exist in BASE_DIR before W1 runs:

* `BASE_DIR/lux_motifs.meme`
* `BASE_DIR/reference_genomes.list`

Normally the pipeline creates them automatically during W0 steps.

### FIMO not found

If W1 fails with `fimo: command not found`, ensure the PBS job loads the conda env or module that provides FIMO.
