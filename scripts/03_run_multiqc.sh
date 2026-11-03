#!/usr/bin/env bash
#SBATCH --job-name=multiqc
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
# 03_run_multiqc.sh
# Combines the FastQC reports of all samples (step 02) into one MultiQC report:
# reads per sample, per-base quality, adapter content for all samples at once.
# Single job (not an array). Run after step 02 has finished:
#   sbatch scripts/03_run_multiqc.sh
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
FASTQC_DIR=$WORKDIR/results/02_fastqc
OUT_DIR=$WORKDIR/results/03_multiqc
CONTAINER=/containers/apptainer/multiqc-1.33.sif

# ---- commands ----
mkdir -p "$OUT_DIR"

# Record the tool version in the log (reproducibility)
apptainer exec --bind /data/ "$CONTAINER" multiqc --version

apptainer exec --bind /data/ "$CONTAINER" multiqc \
  --force \
  --outdir "$OUT_DIR" \
  --filename multiqc_fastqc_raw \
  "$FASTQC_DIR"

echo "Done: $OUT_DIR/multiqc_fastqc_raw.html"
