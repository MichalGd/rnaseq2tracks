# Quality control and interpretation

QC is evidence for review, not an automatic guarantee that an experiment is
biologically valid. Interpret metrics in the context of organism, RNA selection,
library protocol and expected expression profile.

## FastQC and MultiQC

FastQC runs on raw and trimmed FASTQs. Review base quality, adapter content,
sequence duplication, overrepresented sequences, GC profile and read loss after
trimming. RNA-seq duplication can reflect true abundant transcripts and should
not be interpreted like genomic-library duplication.

## FastQ Screen

FastQ Screen samples reads and aligns them against configured Bowtie2 indices.
It helps detect species swaps and contamination. The selected species should
dominate; cross-mapping to related genomes can be real homology. Mycoplasma or
unexpected organism signal requires investigation. Databases are site resources
and are configured through `FASTQSCREEN_CONF`.

## STAR

Review input reads, uniquely mapped percentage, multimapping, too-short reads and
average mapped length for every lane. Large differences between lanes of one
sample should be investigated before merging. Lane-level STAR logs are retained
under `STARlogs/lanes/`; the summary is in `07_qc/star/`.

## RSeQC

- `infer_experiment.py`: verifies library orientation.
- `read_distribution.py`: reports exon/intron/intergenic distribution.
- `geneBody_coverage.py`: displays positional coverage across normalized gene
  bodies and can reveal degradation or strong 5'/3' bias.
- `junction_annotation.py`: classifies splice junctions.
- `junction_saturation.py`: evaluates discovery saturation.

Gene-body curves should be compared across biological samples, not judged by one
universal shape. Strong, sample-specific skew can confound expression estimates.
RSeQC requires a BED matching the same assembly and naming convention as BAMs.

## Sample relationships

PCA, distance and correlation plots should primarily group samples by biological
condition rather than lane, batch or library quality. Outliers should be traced
back through FastQC, FastQ Screen, STAR, RSeQC and sample provenance before any
decision to exclude them.

## Recommended review order

1. FastQ Screen and raw/trimmed MultiQC.
2. STAR mapping summary by lane.
3. technical merge audit.
4. strandedness and gene-body coverage.
5. PCA/sample-distance plots.
6. size factors and contrast diagnostics.
