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