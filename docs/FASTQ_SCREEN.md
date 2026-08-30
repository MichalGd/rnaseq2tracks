# FastQ Screen species and contamination QC

FastQ Screen is enabled by default and is intended to detect gross species
misassignment and unexpected contamination before biological interpretation.

## What the workflow runs

For each technical-library/lane row, the workflow runs FastQ Screen on `fastq_R1`
with:

- the database file in `FASTQSCREEN_CONF`;
- Bowtie2 as aligner;
- `FASTQSCREEN_THREADS` threads;
- `FASTQSCREEN_SUBSET` sampled reads.

In PE projects, only R1 is screened by the current implementation. FastQC and
STAR still process both mates.

## Required site resources

The workflow environment supplies FastQ Screen and Bowtie2. The large databases
remain external site resources. Every `DATABASE` entry in
`FASTQSCREEN_CONF` must point to a readable Bowtie2 index prefix.

The server configuration used in prior validation includes mouse, human,
zebrafish, Drosophila, and Mycoplasma indexes. Projects on another server must
provide equivalent audited paths; repository example paths are not portable.

Preflight fails when FastQ Screen is enabled but the executable, configuration,
or a declared Bowtie2 index is missing.

## Configuration

```bash
RUN_FASTQSCREEN="true"
FASTQSCREEN_CONF="/home/micgdu/GenomicData/fastq_screen_db/fastq_screen.conf"
FASTQSCREEN_THREADS=4
FASTQSCREEN_SUBSET=200000
```

Increasing the subset improves precision but increases run time. Total CPU use
can approach `MAX_JOBS * FASTQSCREEN_THREADS`.

## Outputs

Each technical row has a directory under:

```text
fastQScreen/<library_id>/
```

FastQ Screen normally writes HTML, PNG, text summary, and tag files. The final
MultiQC run scans `fastQScreen/` and includes recognized summaries.

## Interpretation

For the intended species, expect most sampled reads to map uniquely or
non-uniquely to that genome. Some reads can also map to another vertebrate genome
because conserved sequence is shared. Interpret:

- reads mapping to only the intended genome;
- reads mapping to multiple genomes;
- reads unmapped to every configured genome;
- unexpected organism-specific hits;
- consistency across technical rows and biological samples.

Mycoplasma or another unexpected organism signal should trigger review of the
raw FastQ Screen report, sample history, and negative controls. A species screen
does not identify every contaminant: only configured databases can be detected.

The warning that Bowtie2 could not launch an `x86-64-v3` optimized binary and
used its default binary is a performance notice, not evidence of failed
alignment, when FastQ Screen exits successfully.

## Disabling the module

Set `RUN_FASTQSCREEN="false"` only for a documented reason. The run can proceed,
but the final report then lacks this species/contamination evidence. Disabling
the module does not validate sample identity by another method.
