# Outputs and final report

## Output tree

```text
OUTDIR/
|-- metadata/
|   |-- validated_lanes.tsv
|   |-- validated_samples.tsv
|   |-- analysis_samplesheet.csv
|   |-- pairwise_contrasts.csv
|   |-- technical_merge_audit.tsv
|   |-- run_status.tsv
|   `-- run_provenance.tsv
|-- logs/
|   `-- rnaseq2tracks.log
|-- fastQC/
|   |-- raw/<library_id>/
|   `-- trimmed/
|-- fastQScreen/<library_id>/
|-- trimmedFastq/
|-- STARalignments/
|-- STARlogs/lanes/
|-- STARgeneCounts/
|   `-- lanes/
|-- bams/
|   `-- lanes/
|-- 07_qc/
|   |-- star/star_alignment_summary.tsv
|   |-- rseqc/
|   `-- multiqc/
|-- multiQC/
|   |-- raw/
|   |-- trimmed/
|   |-- alignments/
|   `-- final/
|-- bedGraph/
|   |-- raw/
|   |-- normalized/
|   `-- merged/
|-- bigwig/
|-- analysis/
|   |-- counts/
|   |-- DE/
|   |-- tables/
|   |-- figures/
|   `-- enrichment/<contrast_id>/
`-- reports/
    |-- pipeline_report.html
    |-- ucsc_tracks.txt
    `-- bigwig_summary.txt
```

Optional/disabled modules may leave their directories empty or omit their final
files.

## Technical-row versus biological-sample outputs

Files under `STARlogs/lanes/`, `STARgeneCounts/lanes/`, and `bams/lanes/`
correspond to technical processing units identified by derived `library_id`.

Top-level sample outputs represent biological samples after consolidation:

```text
bams/<sample_id>_sortedS.bam
bams/<sample_id>_sortedS.bam.bai
STARgeneCounts/<sample_id>_ReadsPerGene.out.tab
```

DESeq2, RSeQC, sample tracks, and condition tracks use these biological-sample
outputs.

## Final HTML report

`reports/pipeline_report.html` is self-contained and is rendered after requested
enrichment completes. It contains:

- run provenance and selected configuration values;
- biological-sample metadata and technical-merge audit;
- lane-level STAR summary;
- RSeQC orientation summaries and available gene-body images;
- size-factor table;
- PCA, clustering, variable-gene, and mean-SD plots;
- per-contrast significant/up/down DE counts;
- shrunken MA and volcano images;
- enrichment result inventory and term counts;
- deliverable-directory presence summary.

The report links/summarizes rather than duplicating every native result. Use
`multiQC/final/multiQC_final.html`, `analysis/DE/`, and
`analysis/enrichment/` for full detail. A report can be complete while a
database legitimately has no significant enrichment terms.

## QC outputs

| Location | Purpose |
|---|---|
| `multiQC/raw/multiQC_raw.html` | Raw FastQC aggregation. |
| `multiQC/trimmed/multiQC_trimmed.html` | Post-trimming FastQC aggregation. |
| `multiQC/alignments/multiQC_alignments.html` | STAR lane metrics. |
| `07_qc/multiqc/multiQC_rseqc.html` | Recognized RSeQC outputs. |
| `multiQC/final/multiQC_final.html` | Combined final QC review. |
| `07_qc/star/star_alignment_summary.tsv` | Machine-readable lane mapping summary. |
| `07_qc/rseqc/` | Native orientation, distribution, junction, and gene-body outputs. |

## Count and analysis outputs

`analysis/counts/` contains the project-wide biological-sample count matrix,
DESeq2-normalized counts, size factors, serialized model, and session record.

`analysis/DE/` contains complete/significant tables and MA/volcano plots for each
contrast. `analysis/tables/` contains GTF-annotated count/statistic tables.
`analysis/figures/` contains global sample diagnostics. See
[ANALYSIS.md](ANALYSIS.md).

## Coverage and BigWigs

Raw bedGraphs are sample coverage before `sf_rpm` scaling. Normalized bedGraphs
and sample BigWigs use `sf_rpm`. Optional condition tracks average normalized
sample signals.

For stranded data, filenames contain `FwdS` or `RevS`; reverse signal values are
negative. Unstranded data use `unstranded`. BigWig conversion can retain a
compressed sorted bedGraph and an optional all-chromosome archive while the
published `.bw` follows the configured canonical-chromosome policy.

## UCSC descriptors

When `UCSC_TRACKS=true` and `UCSC_BASE_URL` is non-empty, the workflow writes:

- `reports/ucsc_tracks.txt`: one physical `track type=bigWig ...` line per
  BigWig;
- `reports/bigwig_summary.txt`: BigWig name and local path.

Each descriptor uses the public base URL plus the BigWig basename. Names
containing `Rev`/`rev` receive `negateValues=on`. The workflow does not upload or
move BigWigs to the web server; publication is an external administrator/user
step.

Use plain URL text in config, not Markdown link syntax. Before publishing,
verify that every `bigDataUrl` resolves to the corresponding file and that the
target UCSC assembly matches the track coordinates.

## Durable deliverables

Retain:

- metadata, master log, and provenance;
- raw/trimmed/final MultiQC and native QC evidence;
- lane STAR logs and final biological-sample BAMs/counts;
- normalized bedGraphs and BigWigs;
- DESeq2 counts/model, DE tables/plots, annotated tables, and enrichment;
- final report and UCSC descriptors.

Original FASTQs remain outside `OUTDIR` and are never modified. Optional cleanup
can remove trimmed FASTQs, unsorted STAR outputs, lane BAMs after consolidation,
raw bedGraphs, and uncompressed merged bedGraphs. See [OPERATIONS.md](OPERATIONS.md).
