# Quality-control review and interpretation

QC is evidence for scientific review, not an automatic declaration that an
experiment is valid. Interpret it in the context of RNA selection, library
protocol, organism, expected expression, sequencing design, and experimental
history.

## QC dependency chain

```text
FASTQ identity and integrity
  -> raw sequence quality and contamination
  -> trimming outcome
  -> alignment and strandedness
  -> feature/gene-body/junction distribution
  -> sample relationships
  -> DE and enrichment diagnostics
```

A downstream result can look numerically complete even when an upstream sample
identity or protocol setting is wrong. Review the chain in order.

## Recommended review order

1. `metadata/validated_lanes.tsv`, `validated_samples.tsv`, and
   `technical_merge_audit.tsv`.
2. Raw and trimmed FastQC/MultiQC.
3. FastQ Screen species and contamination results.
4. STAR lane-level mapping summary.
5. RSeQC orientation, read distribution, gene-body coverage, and junctions.
6. DESeq2 size factors, PCA, sample distance, and variable-gene heatmap.
7. Contrast-level MA/volcano plots and p-value behavior.
8. Enrichment mapping coverage and result tables.

## FastQC and trimming

Review base quality, adapter content, overrepresented sequences, GC profile,
read length, and read loss after trimming. RNA-seq duplication can reflect
genuinely abundant transcripts and should not be interpreted exactly like
genomic-library duplication.

Large lane-to-lane differences within one `sample_id` should be investigated
before accepting technical consolidation. The final MultiQC report includes raw
and trimmed FastQC evidence.

## FastQ Screen

FastQ Screen samples R1 from each technical row and aligns it against the
configured Bowtie2 databases. It detects likely species swaps and unexpected
organism signal. Cross-mapping between related genomes can reflect homology, so
review unique and multi-genome categories rather than one percentage alone.

See [FASTQ_SCREEN.md](FASTQ_SCREEN.md).

## STAR alignment

Review input reads, uniquely mapped percentage, multi-mapped percentage,
too-short reads, mismatch failures, and average mapped length for every lane.
Substantial differences among technical rows assigned to one biological sample
can indicate library, lane, sample, or metadata problems.

The summary is `07_qc/star/star_alignment_summary.tsv`; full lane logs remain in
`STARlogs/lanes/` and are collected into alignment/final MultiQC.

## RSeQC

RSeQC checks empirical orientation, exonic/intronic/intergenic distribution,
gene-body coverage, and splice-junction annotation/saturation. Gene-body curves
are comparative; there is no universal pass threshold. Strong sample-specific
5'/3' bias can indicate degradation, protocol differences, or other systematic
effects.

See [RSEQC.md](RSEQC.md).

## Sample relationships

PCA, sample-distance clustering, and the top-variable-gene heatmap should be
consistent with the experimental design. Investigate samples that group by lane,
batch, library quality, or unexpected identity rather than the intended biology.

Do not exclude an outlier solely because it is distant in PCA. Trace it through
metadata, raw QC, contamination, mapping, strandedness, gene-body coverage, and
laboratory history, then document any exclusion and rerun in a new output
directory.

## Differential-expression diagnostics

Review size factors for extreme library composition, mean-SD behavior, MA plot
centering, volcano plot distribution, the number of independently filtered
genes, and whether results are dominated by one sample. A very large DE list can
be genuine, but it can also indicate confounding, sample identity, or an
inappropriate design.

## Final acceptance questions

- Were the intended FASTQs assigned once and merged into the correct samples?
- Does the expected species dominate FastQ Screen?
- Are read-quality and trimming outcomes consistent among replicates?
- Is mapping adequate and comparable across lanes/samples?
- Does empirical orientation support the configured strandedness?
- Are gene-body and feature-distribution profiles plausible and comparable?
- Do biological replicates group reasonably without unexplained batch structure?
- Are DE and enrichment results supported by the full QC chain?

Record project-specific acceptance decisions; the workflow deliberately avoids
universal hard cutoffs for biological QC metrics.
