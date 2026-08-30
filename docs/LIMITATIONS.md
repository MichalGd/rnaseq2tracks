# Limitations and interpretation boundaries

## Supported assay scope

- Conventional human and mouse bulk RNA-seq only.
- One project-wide SE or PE layout; mixed layouts are rejected/unsupported.
- Not a single-cell, spatial, long-read, small-RNA, nascent-RNA, or dedicated
  3'-end/APA workflow.
- Gene-level STAR counting; no transcript-isoform quantification or differential
  transcript usage.

For cleavage-site and alternative-polyadenylation analysis, use a validated
assay-specific workflow such as `rna_ends2tracks` rather than interpreting
ordinary gene-body coverage as PAS evidence.

## Replicates and design

- Technical merging assumes every row sharing `sample_id` is the same biological
  specimen with compatible library protocol and metadata. The workflow cannot
  infer a mistaken assignment.
- Technical lanes increase depth but do not add biological degrees of freedom.
- Automatic all-pairwise comparisons can create many contrasts; multiplicity is
  controlled within each DESeq2 contrast, not across the family of all contrasts.
- The default model is `~ condition`. Batch-aware additive designs require a
  full-rank, unconfounded design.
- The current contrast runner tests the `condition` factor. Interactions,
  repeated measures, paired designs, random effects, or other coefficients need
  expert validation and may require implementation changes.

## Alignment and counting

- STAR results depend on index/annotation compatibility and parameters encoded
  in the helper scripts.
- Gene-level counts inherit GTF gene definitions and cannot resolve ambiguous
  transcript isoforms.
- Coverage excludes secondary alignments in the coverage reader, but the final
  BAM remains the alignment deliverable; duplicate handling is not a UMI-aware
  molecular-counting method.
- A project-specific strandedness error can invert/replace the gene-count column
  and strand tracks; empirical QC must be reviewed.

## Normalization and tracks

- DESeq2 assumes that library-composition effects allow size-factor estimation;
  global one-directional expression shifts can violate this assumption.
- `sf_rpm` tracks are relative within the analyzed cohort, not absolute molecule
  counts and not directly comparable across separately normalized projects.
- Condition-level tracks average normalized sample signals and hide replicate
  variation. They are visualization aids, not statistical inputs.
- Canonical-chromosome filtering can omit alternate/decoy contigs by design.
- UCSC descriptors do not publish files; external HTTP(S) deployment is required.

## QC

- FastQ Screen detects only genomes/contaminants included in its configuration.
- The current FastQ Screen stage screens R1 only, including PE projects.
- Cross-species mapping can reflect conserved sequence and is not automatically
  contamination.
- RSeQC depends on a matching BED12 annotation. Gene-body curves have no
  universal pass threshold and can reflect protocol as well as RNA quality.
- QC summaries support review but do not automatically exclude samples.

## Differential expression and enrichment

- Independent-filtering `NA` values are untestable, not non-changing genes.
- LFC shrinkage can fall back from apeglm to ashr and then raw estimates; inspect
  logs/session information when exact estimator provenance matters.
- Enrichment depends on Ensembl-to-Entrez mapping and database versions.
- KEGG analysis may require upstream network/service availability.
- ORA depends on thresholds; GSEA depends on rank construction; neither proves a
  mechanistic pathway effect.
- Redundant gene sets and overlapping genes make enrichment terms statistically
  and biologically non-independent.

## Operations and reproducibility

- Output-existence checkpoints are practical resume guards, not content-addressed
  cache validation. Use a new `OUTDIR` after material input/reference/design
  changes.
- `FORCE_RERUN=1` is broad rather than stage-specific.
- The current CLI lacks validate-only, dry-run, stage-selection, and a dedicated
  status command.
- Run provenance hashes config and samplesheet but does not hash every large
  reference or output. Reference provenance remains a site/project obligation.
- Cleanup is guarded but deletes regenerable intermediates; recovery then
  requires recomputation from original FASTQs.
- The release installer freezes software, not external reference databases or
  changing online pathway resources.
