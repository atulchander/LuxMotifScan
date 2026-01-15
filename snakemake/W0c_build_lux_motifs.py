import os
import sys

# Output target directory should follow the user-provided base directory
target_dir = os.environ.get("LUX_BASE_DIR")
if not target_dir:
    print("ERROR: LUX_BASE_DIR is not set. Run via the master script that exports LUX_BASE_DIR.", file=sys.stderr)
    sys.exit(1)

target_dir = os.path.expanduser(target_dir)
os.makedirs(target_dir, exist_ok=True)

# Output file path inside the chosen base directory
output_path = os.path.join(target_dir, "lux_motifs.meme")

# Lux motif sequences
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
    "qsrP__MJ1": "ACCTGTATAAGTTACAGGA",
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

# Write MEME file
with open(output_path, "w") as f:
    f.write("MEME version 4\n\n")
    for name, seq in lux_dict.items():
        f.write(f"MOTIF {name}\n")
        f.write("letter-probability matrix: alength= 4 w= %d nsites=1 E=0\n" % len(seq))
        for base in seq:
            counts = {"A": 0, "C": 0, "G": 0, "T": 0}
            counts[base] = 1
            f.write(" ".join(str(counts[nuc]) for nuc in "ACGT") + "\n")
        f.write("\n")

print(f"✅ lux_motifs.meme created successfully at: {output_path}")

