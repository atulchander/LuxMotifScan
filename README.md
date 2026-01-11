# LuxMotifScan

LuxMotifScan is a custom MEME/FIMO-based workflow for genome-wide screening
of Lux-box regulatory motifs using a curated motif library.

## Overview
The workflow performs:
1. Construction of MEME-formatted Lux-box motifs
2. Generation of a reference genome list
3. Parallelized motif scanning across genomes using FIMO

## Requirements
- Linux/Unix environment
- Python 3.x
- MEME Suite (FIMO)

## Input requirements
Input FASTA files must contain unique contig identifiers that match those
used in corresponding GFF annotation files.

## Execution environment
Scripts were executed on a Linux-based high-performance computing (HPC)
system. Paths and parallelization parameters may require adjustment for
other environments.

## Scope
LuxMotifScan orchestrates existing tools (MEME Suite / FIMO) and does not
introduce new motif discovery or scoring algorithms.

## Code availability
This repository is provided to support transparency and reproducibility
for the associated publication.

## Underlying software
LuxMotifScan relies on the MEME Suite (https://meme-suite.org), including FIMO (https://meme-suite.org/meme/doc/fimo.html), for motif scanning.
Users should cite the original MEME Suite and FIMO publications when
using this workflow.

LuxMotifScan also relies on data from the publication mentioned below, so users may cite this research article if using this tool.

Septer, Alecia N., and Karen L. Visick. "Lighting the way: how the Vibrio fischeri model microbe reveals the complexity of Earth’s “simplest” life forms." Journal of Bacteriology 206, no. 5 (2024): e00035-24.

