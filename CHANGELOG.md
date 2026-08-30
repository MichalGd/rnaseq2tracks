# Changelog

## 6.0.0-alpha.1 — 2026-08-30

Breaking metadata and launch-contract revision:

- Renamed the workflow identity from `rnaseq2tracksP` to `rnaseq2tracks`.
- Added explicit biological-sample, technical-replicate and lane hierarchy.
- Added lane validation, collision checks and deterministic library IDs.
- STAR and QC run per technical row; BAMs and counts consolidate by biological
  `sample_id` before sample-level statistics and tracks.
- Added `rnaseq2tracks --config FILE`, immutable release installation,
  chronological logging, machine-readable status and checksummed provenance.
- Made module switches effective and moved the final report after enrichment.
- Expanded the final report, rewrote documentation and fixed KEGG ORA invocation.

## 5.1 — 2026-06-05

- Added optional post-run cleanup of regenerable intermediates.
- Added cleanup completion guards and storage documentation.

## 5.0 — 2026-06-04

- Added contrast-level ORA and GSEA for GO, KEGG, Reactome and Hallmarks.
- Added database-specific plots and annotated result tables.

## 4.3 — 2026-06-03

- Expanded DESeq2 plots and RMarkdown reporting.
- Parallelized per-sample and per-condition track operations.

## 4.0–4.2 — 2026-05

- Added preflight checks, FastQ Screen, STAR/RSeQC summaries, restart checkpoints,
  DESeq2 normalization and strand-aware browser tracks.

## 1.0–3.0 — 2026-05

- Initial FASTQ-to-BAM/count/BigWig workflow with human/mouse and SE/PE support.
