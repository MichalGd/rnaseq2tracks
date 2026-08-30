# Documentation index

This index separates ordinary run guidance from methods, interpretation, and
administrator references. The pages describe the current executable behavior of
`rnaseq2tracks` release `v6.0.0-alpha.1.post1`. Commands from
`rna_ends2tracks` are not interchangeable: this workflow does not currently
provide `status`, `--dry-run`, `--from-step`, or `--stop-after` CLI controls.

## Start and operate a project

| Question | Document |
|---|---|
| How do I create and launch a project? | [Quick start](QUICK_START.md) |
| What does each stage do and which stages overlap? | [Workflow steps and dependencies](WORKFLOW.md) |
| Which `config.conf` settings should I change? | [Configuration guide](CONFIGURATION.md) |
| How do I encode biological samples, technical libraries, and lanes? | [Samplesheet contract](SAMPLESHEET.md) |
| How do I monitor, resume, troubleshoot, or clean a run? | [Operations](OPERATIONS.md) |
| How is a tagged shared release installed or rolled back? | [Installation](INSTALLATION.md) |

## Methods, QC, and interpretation

| Topic | Document |
|---|---|
| Alignment, count selection, normalization, tracks, and reproducibility | [Methods](METHODS.md) |
| QC review order and decision principles | [QC overview](QC.md) |
| Species/contamination screening and database requirements | [FastQ Screen](FASTQ_SCREEN.md) |
| Orientation, read distribution, junctions, and gene-body coverage | [RSeQC](RSEQC.md) |
| DESeq2, MA/volcano plots, ORA, GSEA, and pathway databases | [Differential expression and enrichment](ANALYSIS.md) |
| Output tree, final HTML report, BigWigs, and UCSC descriptors | [Outputs](OUTPUTS.md) |
| Supported scope and scientific/operational boundaries | [Limitations](LIMITATIONS.md) |

## Migration and design references

- [Migration from `rnaseq2tracksP`](MIGRATION.md)
- [Architecture comparison and backport rationale](ARCHITECTURE_COMPARISON.md)

The root [README](../README.md) provides the shortest overview. The repository
`VERSION` file and `rnaseq2tracks --version` identify the software release;
release history is recorded in the root `CHANGELOG.md`.
