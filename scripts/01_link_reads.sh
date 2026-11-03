#!/usr/bin/env bash
# 01_link_reads.sh
# Links the course blood reads into data/raw_data (never copied), keeps a copy
# of the SRA sample metadata, and writes the sample list for the SLURM arrays.
# Light work - run on the login node:  bash scripts/01_link_reads.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
READS_SRC=/data/courses/rnaseq_course/toxoplasma_de/reads_Blood
RAW_LINK=$WORKDIR/data/raw_data
SAMPLE_LIST=$WORKDIR/resources/samples.txt

# ---- commands ----
# Symbolic link to the read-only course folder (-sfn: safe to rerun)
ln -sfn "$READS_SRC" "$RAW_LINK"

# Sample metadata from SRA (genotype, infection) - needed later for DESeq2
cp "$READS_SRC/SraRunTable.csv" "$WORKDIR/resources/"

# Course README: sample -> experimental group (WT/DKO, Case/Control)
cp "$READS_SRC/README" "$WORKDIR/resources/sample_groups.txt"

# Sample list, one SRR ID per line
bash "$WORKDIR/scripts/helpers/make_sample_list.sh" "$RAW_LINK" "$SAMPLE_LIST"

echo "Linked $RAW_LINK -> $READS_SRC"
echo "Samples: $(wc -l < "$SAMPLE_LIST") (list in $SAMPLE_LIST)"