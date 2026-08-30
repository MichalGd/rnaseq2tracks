# RSeQC quality control

RSeQC runs on final biological-sample BAMs after technical lanes/libraries have
been consolidated. Its BED12 annotation must match the STAR reference assembly
and chromosome naming style.

## Analyses

| Program | Question | Output directory |
|---|---|---|
| `infer_experiment.py` | Does empirical read orientation match the declared library strandedness? | `07_qc/rseqc/infer_experiment/` |
| `read_distribution.py` | How are reads distributed among coding exons, UTRs, introns, and intergenic regions? | `07_qc/rseqc/read_distribution/` |
| `junction_annotation.py` | Which splice junctions are known versus novel? | `07_qc/rseqc/junction_annotation/` |
| `junction_saturation.py` | Is splice-junction discovery approaching saturation with sequencing depth? | `07_qc/rseqc/junction_saturation/` |
| `geneBody_coverage.py` | Is normalized coverage balanced across transcript bodies, or strongly 5'/3' biased? | `07_qc/rseqc/genebody/` |

Each program runs per biological sample. Module jobs are throttled by
`MAX_JOBS`. The complete RSeQC branch runs in the background while coverage,
tracks, and DE analysis continue, then the workflow waits for it before final
MultiQC.

## Annotation contract

`RSEQC_BED_HUMAN` or `RSEQC_BED_MOUSE` must be a readable BED12 transcript
annotation for the same assembly and contig naming convention as the sample
BAMs. A GTF is not accepted directly by the RSeQC commands.

Assembly or naming mismatch can produce empty or misleading results even when
the program exits. Confirm representative chromosomes in the BED and BAM before
production.

## Configuration

```bash
RUN_RSEQC="true"
RSEQC_BED_MOUSE="/shared/GRCm39/gencode.annotation.bed12"
RSEQC_BED_HUMAN="/shared/GRCh38/gencode.annotation.bed12"
RSEQC_BIN_DIR=""
```

An empty `RSEQC_BIN_DIR` uses executables supplied through the self-contained
launcher environment. A non-empty value is an expert override.

## Orientation interpretation

Compare `infer_experiment.py` output to the samplesheet:

- `unstranded` libraries should not show a strong single-strand rule;
- `forward` and `reverse` libraries should show the expected dominant rule;
- inconsistent samples can indicate an incorrect protocol label, swap, mixed
  library construction, or low-information data.

The workflow also runs a strand-consistency safety check with
`STRAND_TOLERANCE_PCT`. Do not loosen it simply to make a run pass; first resolve
the protocol and sample evidence.

## Gene-body coverage interpretation

`geneBody_coverage.py` scales annotated transcript bodies from 0% to 100% and
summarizes relative coverage. Review curves across biological samples:

- similar shapes support comparable RNA quality/protocol behavior;
- strong sample-specific 5' loss can indicate degradation;
- strong 3' or 5' bias can also be protocol-specific;
- very sparse curves can indicate low mRNA content, annotation mismatch, or poor
  mapping.

There is no universal numeric pass threshold. Interpret trends relative to
library preparation and expected RNA biology.

## Read distribution and junctions

Unexpectedly high intronic signal may reflect pre-mRNA, nuclear RNA, genomic DNA,
annotation mismatch, or biology. Junction saturation is most informative for
splicing-rich poly(A)/total-RNA libraries and less decisive for protocols not
designed for transcriptome-wide splice discovery.

## MultiQC and final report

Recognized RSeQC outputs are collected into
`07_qc/multiqc/multiQC_rseqc.html` and the final
`multiQC/final/multiQC_final.html`. The pipeline HTML report embeds orientation
summaries and available gene-body images, but the native RSeQC/MultiQC files
remain the detailed source evidence.
