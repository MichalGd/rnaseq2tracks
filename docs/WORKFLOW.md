# Workflow and methods

## Ordered stages

1. **Contract validation** checks config paths, FASTQ uniqueness, replicate
   hierarchy, layout, condition levels and required tools.
2. **Raw QC** runs FastQC and optional FastQ Screen on each technical row.
3. **Trimming** runs Trim Galore independently for every lane/library.
4. **Alignment** runs STAR independently per technical row with gene counting.
5. **Technical consolidation** coordinate-sorts lane BAMs, merges all rows sharing
   `sample_id`, indexes the final sample BAM and sums STAR count columns.
6. **Alignment/RNA QC** generates STAR summaries, MultiQC, strandedness checks
   and RSeQC modules.
7. **Coverage** creates sample-level strand-aware bedGraphs from final BAMs.
8. **Normalization** fits DESeq2 on biological-sample counts and applies size
   factors to coverage tracks.
9. **Tracks** converts normalized bedGraphs to BigWig and optionally merges
   biological samples by condition.
10. **Differential expression** evaluates configured contrasts, reports shrunken
    fold changes and produces MA/volcano and sample-level QC plots.
11. **Enrichment** runs ORA and ranked GSEA for GO, KEGG, Reactome and Hallmarks.
12. **Reporting** renders final HTML after all requested analytical modules.
13. **Cleanup** optionally deletes documented regenerable intermediates only
    after completion sentinels pass.

## Counting and strandedness

STAR `ReadsPerGene.out.tab` contains unstranded, forward and reverse count
columns. Lane tables are summed cell-by-cell only after verifying identical gene
order. The configured per-sample strandedness selects the appropriate column for
DESeq2. RSeQC and the strand-consistency audit provide an empirical check.

## Technical versus biological replication

Merging technical rows increases read depth for the same experimental unit; it
does not increase biological replication. Only final `sample_id` units enter the
DESeq2 design. Condition-level track merging is a visualization operation and is
not the source of differential-expression counts.

## Normalized tracks

Raw coverage is generated from coordinate-sorted sample BAMs. DESeq2 size factors
are estimated from the sample-level count matrix. The normalization helper writes
strand-specific or unstranded normalized bedGraphs, which are converted to
BigWig after chromosome filtering/sorting.

## Reproducibility

The installed tagged release fixes the workflow source and environment. The run
records version, paths, sample counts and SHA-256 hashes of config and samplesheet.
Generated sample/lane manifests document the exact aggregation performed.
