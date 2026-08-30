# Differential expression and enrichment

## DESeq2 input

The count matrix has one column per biological `sample_id`. Technical lane counts
have already been summed. DESeq2 estimates library size factors and dispersions,
fits the configured design, and evaluates every unique pair of samplesheet
conditions. An optional explicit `CONTRASTS` file can restrict or reorder these
comparisons.

Canonical result tables use shrunken log2 fold changes from apeglm when possible,
with ashr and unshrunken fallbacks. Raw and shrunken MA/volcano plots are retained
so estimation and presentation can be reviewed separately.

Typical significance settings are adjusted p-value below 0.05 and absolute log2
fold change above 1, but thresholds are study decisions and should be declared in
reporting. Independent-filtering `NA` values are not significant results.

## Enrichment

Enrichment runs after differential expression and before the final report.

- **ORA** uses significant genes and the tested/mapped background.
- **GSEA** uses a signed ranking statistic across testable mapped genes.
- Databases: GO BP, GO MF, GO CC, KEGG, Reactome and MSigDB Hallmarks.
- Tables and dotplots/barplots are written for both strategies where results are
  available; ORA also attempts concept-network plots.

ORA can be empty when too few genes pass the DE threshold. GSEA can still be
informative in that situation. Enrichment is hypothesis generation: redundant
terms, gene-ID mapping coverage, set size and database version must be considered.

## KEGG behavior

KEGG functions can require current online pathway metadata even though annotation
packages are installed locally. A network or upstream-service failure should be
reported as a module failure, not silently interpreted as “no enrichment.”

## Key locations

- `analysis/counts/`: raw/normalized counts, DESeq2 object and size factors.
- `analysis/DE/`: complete and significant result tables plus plots.
- `analysis/tables/`: annotated count tables per contrast.
- `analysis/figures/`: PCA and global sample diagnostics.
- `analysis/enrichment/<contrast>/`: database-specific outputs.
