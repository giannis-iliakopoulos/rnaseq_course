#!/usr/bin/env bash
#SBATCH --job-name=download_ref
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
# 04_download_reference.sh
# Downloads the latest Ensembl mouse genome (GRCm39, primary assembly) and gene
# annotation (GTF), verifies them with the Ensembl CHECKSUMS (`sum`), and
# unzips the genome for HISAT2. Records the Ensembl release used.
# Compute nodes may have no internet; if so run on the login node:
#   bash scripts/04_download_reference.sh 2>&1 | tee logs/download_ref_loginnode.log
set -euo pipefail

# ---- settings: change only here ----
WORKDIR=/data/users/$USER/rnaseq_course
REF_DIR=$WORKDIR/data/external_data
ENSEMBL=https://ftp.ensembl.org/pub
FASTA=Mus_musculus.GRCm39.dna.primary_assembly.fa.gz

# ---- find the newest release that contains the mouse GTF ----
RELEASES=$(wget -q -O - "$ENSEMBL/" | grep -oE 'release-[0-9]+' | sort -t- -k2 -n -u | tail -3 | sort -t- -k2 -nr || true)
[ -n "$RELEASES" ] || { echo "ERROR: could not list $ENSEMBL/ (no internet?)" >&2; exit 1; }

RELEASE=""
for r in $RELEASES; do
  n=${r#release-}
  if wget -q --spider "$ENSEMBL/$r/gtf/mus_musculus/Mus_musculus.GRCm39.$n.gtf.gz"; then
    RELEASE=$n; break
  fi
  echo "Release $n: mouse GTF not found, trying an older release"
done
[ -n "$RELEASE" ] || { echo "ERROR: no recent release with the mouse GTF found" >&2; exit 1; }

FASTA_URL=$ENSEMBL/release-$RELEASE/fasta/mus_musculus/dna
GTF_URL=$ENSEMBL/release-$RELEASE/gtf/mus_musculus
GTF=Mus_musculus.GRCm39.$RELEASE.gtf.gz
echo "Ensembl release: $RELEASE"
echo "Genome:     $FASTA_URL/$FASTA"
echo "Annotation: $GTF_URL/$GTF"

# ---- download (-nc: skip files that already exist) ----
mkdir -p "$REF_DIR"
cd "$REF_DIR"
wget -nc "$FASTA_URL/$FASTA"
wget -nc "$GTF_URL/$GTF"
wget -O CHECKSUMS_fasta "$FASTA_URL/CHECKSUMS"
wget -O CHECKSUMS_gtf   "$GTF_URL/CHECKSUMS"

# ---- verify: `sum` must match the two numbers in CHECKSUMS for that file ----
check() {  # $1 = file, $2 = CHECKSUMS file
  expected=$(grep " $1\$" "$2" | awk '{print $1, $2}')
  observed=$(sum "$1" | awk '{print $1, $2}')
  if [ -n "$expected" ] && [ "$expected" = "$observed" ]; then
    echo "Checksum OK: $1 ($observed)"
  else
    echo "Checksum MISMATCH: $1 (expected '$expected', got '$observed')" >&2
    exit 1
  fi
}
check "$FASTA" CHECKSUMS_fasta
check "$GTF"   CHECKSUMS_gtf

# HISAT2 needs the uncompressed genome; featureCounts can read the gzipped GTF
gunzip -kf "$FASTA"

# ---- record what was used (for the README and the report) ----
echo -e "ensembl_release\t$RELEASE\nassembly\tGRCm39\ngenome\t${FASTA%.gz}\nannotation\t$GTF\ndownloaded\t$(date -I)" > reference_info.txt
cat reference_info.txt
echo "Done"