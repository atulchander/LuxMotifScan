#!/usr/bin/env python3
"""
Generate a MEME-formatted motif file from a curated Lux-box motif dictionary.

Output:
  lux_motifs.meme

Notes:
- Motifs are derived from experimentally validated quorum-sensing regulators.
- Output is compatible with MEME Suite / FIMO.
"""

import os

# Project root (adjust as needed)
PROJECT_DIR = os.path.expanduser("/path/to/project")

# Output directory
target_dir = os.path.join(PROJECT_DIR)
os.makedirs(target_dir, exist_ok=True)

# Output file path
output_path = os.path.join(target_dir, "lux_motifs.meme")

# Curated Lux-box motif sequences
lux_dict = {
    "aubIbox": "ACCTGGCGGTTCGGCCAGGT",
    "ausI": "AACTACCAGATCTGATAGCT",
    "rhlI": "CCCTACCAGATCTGGCAGGT",
    "solI": "CCCTGTCAATCCTGACAGTT",
    "luxI": "ACCTGTAGGATCGTACAGGT",
    "lasI": "ACCTGCGAGAACTGGCAGGT",
    "afeI": "AGCTGTCAACCTTGACAGCT",
    "cepI": "CCCTGTAAGATTTACCAGTT",
    "rpaI1": "ACCTGTCCGATCGGAACAGTA",
    "rpaI2": "CACTGTTCCCGCCTGGAGAC",
    "psmI": "ACCTGTTCCCTAGGTACAGTA",
    "esaI": "ACCTGCACTATAGTACAGGC",
    "phzA": "ACCTACCAGATCTGTAGTT",
    "vanI": "AACTGTTCGATCGAACAGGT",
    "spnR": "ACCTGACCGAAGGTGCAGGT",
    "recA": "TACTGTATGACCATAACAGTA",
    "esaR": "ACCTGCACTATAGTACAGTA",
    "xccR": "ACCTTGGCAATTTGGCAGTT",
    "oryR": "ACCTGTGAGATTTGCCAGTT",
    "lecA": "TCCTGCATGAATTGGTAGGC",
    "vioA": "CCCTGACCCGTTGGAACAGTA",
    "psoA": "TTCTGCAGGCTTCTACAGGT",
    "ppuI": "ACCTCCCAATATTAGGTAGGA",
    "ppuA": "ACCTCCCTGTTCGGGAGGGT",
    "luxI_ATCC": "ACCTGTAGGATCGTACAGGT",
    "qsrP_MJ1": "ACCTGTATAAGTTACAGGA",
    "qsrP_ES114": "ACCTGTATAAACGACAGGA",
    "aidA": "ACCTGTTTACTTTTACAGCT",
    "phzM": "AACTACAAGATCTGGTAGGT",
    "rsaL": "AACTAGCAAATGAGAATAGAT",
    "rhlAB": "TCCTGTGAAATCTGGGCAGTT",
    "braI": "ACCTATCCAGGTAGGTAGGT",
    "xenI": "ACCTATCCAGGTAGGTAGGT",
    "phyI": "ACCTATCCAGGTAGGTAGGT",
    "unaI": "ACCTACCTATCTAGATAGGT",
    "luxI_MJ1": "ACCTGTAGGATCGTACAGGT",
    "bmaI": "CCCTGTAAGGGTTAAACAGTT",
    "pipI": "ACCTGAACGCCCGTTTCGCG",
    "phzI": "CACTACAAGATCTGGTAGGT",
    "PA1897_qsc102": "ACCTGCCGCGAAGGGCAGGT"
}
