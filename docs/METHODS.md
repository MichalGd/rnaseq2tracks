# Methods and normalization

This document describes the current computational methods. It is not a protocol
for dedicated 3'-end RNA-seq; conventional gene-level RNA-seq and
`rna_ends2tracks` PAS/APA analysis answer different questions.

## Read-level preprocessing

Raw FastQC is run for every FASTQ-producing technical row and for both mates in
PE projects. Optional FastQ Screen samples R1 to assess species identity and
contamination. Trim Galore applies the configured quality and minimum-length
cutoffs, after which FastQC and MultiQC are repeated.

## Alignment and gene counts

STAR aligns each technical row independently to one project-wide genome index
and produces a BAM, splice-junction table, final alignment log, and
`ReadsPerGene.out.tab`. PE reads are aligned together; SE reads are aligned as a
single stream.

Lane BAMs are coordinate-sorted and indexed. All rows sharing a `sample_id` are
then merged into one biological-sample BAM. STAR count tables are summed
cell-by-cell only after verifying that gene identifiers and row order are
identical. The unstranded, forward, and reverse STAR count columns are all
preserved during this merge.

## Stranded count selection

For each biological sample, the configured `strandedness` selects the STAR count
column used in DESeq2:

| Samplesheet value | STAR `ReadsPerGene.out.tab` data column |
|---|---:|
| `unstranded` | unstranded count |
| `forward` | forward-strand count |
| `reverse` | reverse-strand count |

The strand-consistency check and RSeQC `infer_experiment.py` provide independent
evidence that this setting matches the library. A valid run configuration is not
a substitute for checking the empirical orientation result.

## Count matrix and DESeq2 size factors

The count matrix contains one column per biological `sample_id`. Technical rows
have already been summed. A DESeq2 data set is constructed from the configured
formula, normally `~ condition`, and size factors are estimated once for the
project.

The workflow writes:

- `raw_counts.tsv`;
- `normalized_counts.tsv` from `counts(dds, normalized=TRUE)`;
- `size_factors.tsv`;
- `dds.RData`;
- the R session information.

These size factors are used for expression statistics and also contribute to
the track scale described below.

## Coverage tracks

Coverage is derived from the consolidated biological-sample BAM. Secondary
alignments are excluded by the coverage reader; the BAM itself is retained as
the complete sample alignment deliverable.

Unstranded projects produce one coverage signal. Stranded projects produce
forward-transcript and reverse-transcript signals. Reverse coverage is stored as
negative values so genome browsers can display mirrored strands.

For PE libraries, read pairs are handled as paired alignments in unstranded
coverage. In strand-aware coverage, mate orientation is interpreted according to
forward/reverse library type and aligned read blocks contribute to coverage.

## Track normalization (`sf_rpm`)

The normalized browser tracks are not labelled as plain CPM. The workflow first
estimates DESeq2 size factors, then calculates an `sf_rpm` anchor from the mean
exonic RPM signal of genes with mean RPM above one. Each sample bedGraph score is
divided by that sample's `sf_rpm` value.

The exact factors are recorded in `analysis/counts/size_factors.tsv` with both
`size_factor` and `sf_rpm` columns. This cohort-relative scale supports visual
comparison within the analyzed project; it is not an absolute molecule count
and should not be compared blindly across separately normalized projects.

## Condition-level tracks

When enabled, normalized biological-sample bedGraphs are averaged by condition
after disjoining their genomic intervals. These tracks summarize the mean
visual signal. They do not replace sample-level tracks and are never used as
replicates or as the source of DESeq2 counts.

## Differential expression

DESeq2 fits the project data set and evaluates each resolved condition contrast
using a Wald test. The complete unshrunken result is retained for diagnostic
plots. The canonical reported effect uses apeglm shrinkage when the required
coefficient is available, ashr as fallback, and the raw result only if both
shrinkage methods fail.

For every contrast, the workflow writes:

- the complete result table;
- a significant subset using configured adjusted-p-value and absolute LFC
  thresholds;
- raw and shrunken MA plots;
- raw and shrunken volcano plots;
- clipped plot variants for dense/extreme results;
- an annotated count table joined to GTF gene metadata.

Independent-filtering `NA` adjusted p-values are untestable and are not
significant.

## Sample-level diagnostics

A variance-stabilizing transform is used for PCA, sample-distance clustering,
the top-500 variable-gene heatmap, and the mean-SD diagnostic. These plots help
identify outliers, batch effects, sample swaps, and whether the intended biology
is visible relative to unwanted variation.

## Functional enrichment

ORA selects mapped genes passing the configured DE adjusted-p-value and absolute
LFC thresholds and uses the tested/mapped genes as background. Ranked GSEA uses
all testable mapped genes with the metric:

```text
sign(log2FoldChange) * -log10(padj)
```

When multiple Ensembl IDs map to one Entrez ID, the entry with the largest
absolute rank metric is retained for GSEA. GO BP/MF/CC, KEGG, Reactome, and
MSigDB Hallmarks are attempted. See [ANALYSIS.md](ANALYSIS.md) for outputs and
interpretation.

## Reproducibility

The tagged installed release fixes workflow source and package environment. Each
run records the release version, resolved input paths, biological/technical
counts, contrast count, layout, species, and SHA-256 hashes of `config.conf` and
the original samplesheet in `metadata/run_provenance.tsv`.

Reference FASTA/index, GTF, chromosome sizes, RSeQC BED, FastQ Screen databases,
and online pathway resources are external to the release. Their identity must be
recorded and managed by the site/project; a software tag alone does not freeze
those resources.
