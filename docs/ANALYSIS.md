# Differential expression and functional enrichment

Differential expression and enrichment operate on biological samples after all
technical rows assigned to a `sample_id` have been consolidated. This page
describes the current statistical outputs and how to interpret them.

## Inputs to DESeq2

STAR produces four rows of mapping summaries followed by gene-level unstranded,
forward, and reverse count columns. The workflow:

1. verifies identical gene order among technical rows;
2. sums all three count columns within each biological `sample_id`;
3. selects the count column matching each sample's `strandedness`;
4. constructs one count-matrix column per biological sample;
5. fits the configured DESeq2 design, normally `~ condition`.

Technical lanes do not become independent replicates. The count matrix, size
factors, serialized DESeq2 object, and R session information are in
`analysis/counts/`.

## Automatic pairwise contrasts

By default, all unique condition pairs are generated in deterministic
first-appearance order and written to
`metadata/pairwise_contrasts.csv`. With `control`, `drugA`, and `drugB`, three
contrasts are tested.

An optional `CONTRASTS` CSV can deliberately restrict or reorder comparisons.
It does not change samples or fit a different factor; numerator and denominator
must be levels of `condition`.

## Effect estimates and significance

For each contrast, the workflow calculates unshrunken Wald-test results and a
canonical shrunken log2 fold change:

1. apeglm shrinkage when the requested coefficient is available;
2. ashr shrinkage if apeglm fails;
3. unshrunken effect only if both shrinkage approaches fail.

The complete result table is sorted by adjusted p-value. The significant subset
requires both:

```text
padj < DE_PADJ_THRESHOLD
abs(log2FoldChange) > DE_LFC_THRESHOLD
```

The defaults are 0.05 and 1. Genes with `padj=NA` after independent filtering
are untestable at that stage and are not significant.

## Contrast outputs

For `<contrast_id>`, `analysis/DE/` contains:

| Pattern | Content |
|---|---|
| `<contrast>_DE_results.tsv` | Complete canonical table with shrunken effect. |
| `<contrast>_significant.tsv` | Thresholded significant subset. |
| `<contrast>_volcano_raw.{pdf,png}` | Unshrunken LFC versus `-log10(padj)`. |
| `<contrast>_volcano_shrunk.{pdf,png}` | Shrunken LFC versus `-log10(padj)`. |
| `*_volcano_*_clipped.{pdf,png}` | Fixed-window display variants; points are not removed from tables. |
| `<contrast>_MA_raw.{pdf,png}` | Unshrunken MA plot. |
| `<contrast>_MA_shrunk.{pdf,png}` | Shrunken MA plot. |

`analysis/tables/<contrast>_annotated_counts.csv` joins gene metadata from the
configured GTF with raw counts, normalized counts, and contrast statistics.

## Global expression diagnostics

`analysis/figures/` includes:

- `PCA.pdf` and `PCA.png`;
- sample-distance clustering PDF/PNG;
- top-500 variable-gene heatmap PDF/PNG;
- mean-SD plot PDF/PNG;
- R session information.

These plots use a variance-stabilizing transform. PCA shape encodes the
biological replicate label, not a technical lane. Interpret clustering with
batch, RNA quality, and sample provenance.

## Over-representation analysis

ORA uses genes passing `PADJ_THRESHOLD` and `LFC_THRESHOLD` after Ensembl-to-
Entrez mapping. The tested/mapped genes form the universe. It asks whether a
gene set contains more significant genes than expected given that background.

ORA can legitimately be empty when few genes pass the thresholds. An empty ORA
does not establish absence of coordinated pathway change.

## Ranked GSEA

GSEA uses testable mapped genes ranked by:

```text
sign(log2FoldChange) * -log10(padj)
```

It can detect coordinated shifts when few genes cross a hard DE threshold. When
multiple Ensembl identifiers map to one Entrez identifier, the entry with the
largest absolute rank metric is retained.

## Databases and plots

The workflow attempts:

- GO Biological Process, Molecular Function, and Cellular Component;
- KEGG pathways;
- Reactome pathways;
- MSigDB Hallmark gene sets.

Per database and method, it writes TSV result tables and, when results are
available, PDF/PNG dotplots and barplots. ORA also attempts concept-network
plots. Plotting failures or empty result sets are logged without fabricating
terms.

KEGG functions can query upstream pathway metadata. A network/service failure
must be distinguished from a valid empty biological result by reviewing
`logs/rnaseq2tracks.log` and the presence/content of result files.

## Enrichment outputs

Each contrast has a directory:

```text
analysis/enrichment/<contrast_id>/
```

File names identify method and database, for example:

```text
<contrast>_ORA_GOBP.tsv
<contrast>_ORA_KEGG.tsv
<contrast>_ORA_Reactome.tsv
<contrast>_GSEA_GOBP.tsv
<contrast>_GSEA_KEGG.tsv
<contrast>_GSEA_Reactome.tsv
<contrast>_GSEA_Hallmarks.tsv
```

Associated plot files use `_dotplot`, `_barplot`, and, for ORA where possible,
`_cnetplot`. A global R session record is written to
`analysis/enrichment/deseq2_enrichment_sessionInfo.txt`.

## Interpretation checklist

Before reporting a pathway:

1. confirm sample QC and the DE model are acceptable;
2. inspect the underlying complete DE table and direction of effect;
3. review Ensembl-to-Entrez mapping loss;
4. distinguish ORA thresholding from ranked GSEA;
5. account for redundant/overlapping gene sets;
6. report the database, method, gene-set-size limits, and adjusted-p-value
   threshold;
7. treat concept networks as visualization, not independent statistical tests.

The HTML report summarizes DE counts and enrichment table sizes, but complete
tables under `analysis/` are the authoritative analytical outputs.
