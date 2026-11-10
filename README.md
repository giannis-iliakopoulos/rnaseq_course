# RNA-seq: host response to *Toxoplasma gondii* infection in mice

RNA-seq course project (IBU, University of Bern): differential gene expression analysis.

## Data
Subset of Singhania et al. 2019, *Nat. Commun.* (GEO: GSE119855).
Mouse blood, wild-type vs. Ifnar/Ifngr double knockout, infected vs. uninfected (3-5 replicates per group).
Strand-specific paired-end reads, Illumina HiSeq 4000.

## Project layout
- `scripts/`  numbered scripts, in order of execution (`helpers/` = scripts called by other scripts)
- `config/`   settings used by the scripts
- `resources/` sample list and sample metadata
- `data/raw_data` symlink to the course reads (never copied or edited)
- `data/external_data/` reference genome and annotation (Ensembl)
- `data/processed_data/` intermediate files (e.g. BAM)
- `logs/`     SLURM .out/.err files
- `results/`  outputs, one subfolder per step; everything here is rebuilt by a script
- `reports/`  final report and figures

Data, results and logs are not tracked by git (see `.gitignore`).

## Steps
### 01 Link raw reads (login node)
```bash
bash scripts/01_link_reads.sh
```
Links `data/raw_data` to the course reads (blood, 15 paired-end samples),
copies the sample metadata into `resources/` and writes `resources/samples.txt`.
Data source: GEO GSE119855, downloaded by the course with `fasterq-dump --split-files`.

| Group | Samples | n |
|---|---|---|
| WT infected (Case) | SRR7821949-953 | 5 |
| WT uninfected (Control) | SRR7821968-970 | 3 |
| DKO infected (Case) | SRR7821954-957 | 4 |
| DKO uninfected (Control) | SRR7821971-973 | 3 |

### 02 Read quality control (FastQC, SLURM job array)
```bash
sbatch --array=0 scripts/02_run_fastqc.sh      # test on one sample first
sbatch --array=1-14 scripts/02_run_fastqc.sh   # remaining samples after the test succeeded
```
The test task was checked (`sacct`: COMPLETED 0:0, log shows FastQC v0.12.1,
4 output files) before submitting the remaining tasks.
Running `sbatch scripts/02_run_fastqc.sh` without `--array` processes all 15 samples at once.
Output: `results/02_fastqc/<sample>_<1|2>_fastqc.{html,zip}`,
logs: `logs/fastqc_<jobid>_<task>.{out,err}`.

## Software and versions
| Tool | Version | Container | Resources per task |
|---|---|---|---|
| FastQC | 0.12.1 | `/containers/apptainer/fastqc-0.12.1.sif` | 2 CPU, 2 GB, 1 h (partition pshort_el8) |


### 03 Combined QC report (MultiQC)
```bash
sbatch scripts/03_run_multiqc.sh
```
Combines the 30 FastQC reports (15 samples x 2 mates) into one report:
`results/03_multiqc/multiqc_fastqc_raw.html` (+ `multiqc_fastqc_raw_data/` with the tables).
Used to compare read numbers, per-base quality and adapter content across all samples.
Single job (not an array), log: `logs/multiqc_<jobid>.{out,err}`.

## Software and versions
| Tool | Version | Container | Resources |
|---|---|---|---|
| MultiQC | 1.33 | `/containers/apptainer/multiqc-1.33.sif` | 1 CPU, 4 GB, 30 min (partition pshort_el8) |


## QC results and decision
Based on the FastQC and MultiQC reports (`results/03_multiqc/multiqc_fastqc_raw.html`):

- **Reads per sample:** 18.8–34.2 M read pairs (mean 26.4 M, ≈395.7 M in total); mate 1 and mate 2 have identical read counts in all samples.
- **Base quality:** mean Phred score > 30 at all positions in all 30 files (mostly 38–40), slightly lower in the first ~5 bases and the last bases; mates 1 and 2 have nearly identical profiles.
- **Adapters:** < 1% in most files (max ~6% at the last positions); adapter dimers account for ~0.3% of all reads.
- **Expected RNA-seq warnings:** per-base sequence content (random hexamer priming bias) and high duplication (58–92%; blood RNA is dominated by a few highly expressed transcripts). Duplicates were not removed (no UMIs).
- **SRR7821956 (DKO infected)** stands out: two narrow peaks in the GC distribution (45% and 47% GC, ~5% of reads each), the highest duplication (~92%) and the largest fraction of overrepresented sequences (~7–10%). Its overall GC distribution is normal (~50%), so there is no sign of contamination; the peaks come from a few highly repeated sequences.

**Decision (confirmed with the supervisor):** read quality is good and no trimming is needed; the raw reads are used for mapping.
SRR7821956 is kept unchanged and re-checked after mapping (alignment rate, reads assigned to genes, PCA). Trimming or exclusion will only be considered if it performs clearly worse than the other samples.

### 04 Download reference genome and annotation (login node)
```bash
bash scripts/04_download_reference.sh 2>&1 | tee logs/download_ref_loginnode.log
```
Downloads the mouse genome (GRCm39, primary assembly) and gene annotation (GTF) from **Ensembl release 116**
into `data/external_data/`, verifies both with the Ensembl CHECKSUMS (`sum`; both OK) and unzips the genome for HISAT2.
Run on the login node, because compute nodes have no internet access (downloading is not computationally heavy).
Release and file names are recorded in `data/external_data/reference_info.txt`.

| File | Checksum (`sum`) |
|---|---|
| Mus_musculus.GRCm39.dna.primary_assembly.fa.gz | 16996 787519 |
| Mus_musculus.GRCm39.116.gtf.gz | 42607 105329 |

### 05 Build HISAT2 index (SLURM, ~40 min)
```bash
sbatch scripts/05_build_hisat2_index.sh
```
Builds the HISAT2 index of the GRCm39 primary assembly (Ensembl 116) in
`data/external_data/hisat2_index/` (index basename `GRCm39`, 8 files `GRCm39.1-8.ht2`).
Submitted to partition pibu_el8 (course estimate ~3 h); the job completed in 38 min 44 s
(COMPLETED 0:0) and all 8 index files were created.

**Software:**
| Tool | Version | Container | Resources |
|---|---|---|---|
| HISAT2 (hisat2-build) | 2.2.1 | `/containers/apptainer/hisat2_samtools_408dfd02f175cd88.sif` | 1 CPU, 10 GB, 4 h (partition pibu_el8) |

### 06 Map reads to the genome (HISAT2 → samtools, SLURM job array)
```bash
sbatch --array=0 scripts/06_map_reads_hisat2.sh      # test on one sample first
sbatch --array=1-14 scripts/06_map_reads_hisat2.sh   # remaining samples after the test succeeded
```
Maps each sample to GRCm39 (Ensembl 116) with HISAT2 using the strand setting for this
reverse-stranded library (`--rna-strandness RF`). The HISAT2 output is piped directly into
`samtools sort`, which writes a coordinate-sorted BAM and its index (`--write-index`), so no SAM
or unsorted BAM file is ever stored. A `samtools quickcheck` verifies each BAM.
- BAM files: `data/processed_data/bam/<sample>.sorted.bam` (+ `.bai`; not tracked by git)
- HISAT2 alignment summaries: `results/06_mapping/<sample>.hisat2.summary.txt`
- Logs: `logs/hisat2_map_<jobid>_<task>.{out,err}`

The test task (SRR7821949) completed in 14 min with a peak memory of 22 GB (of 25 GB requested),
so the memory request was raised to 32 GB for the remaining, partly larger samples.
All 15 tasks completed (COMPLETED 0:0, 8–15 min each) and 15 BAM files were created.

**Software:**
| Tool | Version | Container | Resources per task |
|---|---|---|---|
| HISAT2 | 2.2.1 | `/containers/apptainer/hisat2_samtools_408dfd02f175cd88.sif` | 4 CPU, 32 GB, 4 h (partition pibu_el8) |
| samtools | 1.20 | same container | same job; sort with 4 threads × 4 GB |

### 07 Summarise the mapping statistics (login node)
```bash
bash scripts/07_summarise_mapping.sh 2>&1 | tee logs/summarise_mapping.log
```
Collects the HISAT2 summaries of all samples into one table:
`results/06_mapping/alignment_summary.tsv` (total read pairs, % pairs aligned concordantly
exactly once, % pairs aligned concordantly more than once, overall alignment rate).
Light work, so it is run on the login node; the output is saved to `logs/summarise_mapping.log`.

### Mapping results
| Group | Samples | Overall alignment | Concordant, unique | Concordant, multimapped |
|---|---|---|---|---|
| WT infected | SRR7821949–953 | 95.6–97.0% | 85.0–86.2% | 7.1–7.7% |
| WT control | SRR7821968–970 | 87.9–93.3% | 74.5–77.9% | 7.6–11.0% |
| DKO infected | SRR7821954, 955, 957 | 87.9–90.7% | 74.3–76.1% | 7.6–8.0% |
| DKO infected | **SRR7821956** | **83.1%** | **68.9%** | 8.4% |
| DKO control | SRR7821971–973 | 90.2–94.0% | 75.7–82.1% | 8.1–9.7% |

- **Alignment rates:** 83.1–97.0% overall in all samples; WT infected samples map best.
- **Concordant alignment** means both mates of a pair map to the same chromosome, in the expected
  orientation and at a plausible distance, as expected for a correctly aligned paired-end fragment.
  69–86% of pairs aligned concordantly exactly once.
- **Multimapped reads:** 7–11% of pairs aligned concordantly to more than one location
  (e.g. gene families, repeats). They are not counted by featureCounts by default, so they do not
  create false signal, but expression of genes with highly similar copies may be slightly underestimated.

**Follow-up of SRR7821956** (flagged in QC; checked after mapping as agreed with the supervisor):
this sample has the lowest overall alignment rate (83.1%) and the lowest fraction of uniquely,
concordantly aligned pairs (68.9%, vs. 74–76% in the other DKO infected samples). Its multimapping
rate is normal (8.4%), so the difference comes from unmapped reads, which is consistent with the
adapter dimers and overrepresented sequences found in QC. With ~21.5 M uniquely and concordantly
aligned pairs it still has more usable data than several other samples, so it is **kept**
without trimming. It will be checked again in the PCA (does it cluster with the other DKO infected samples?).