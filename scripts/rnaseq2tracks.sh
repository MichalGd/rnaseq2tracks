#!/usr/bin/env bash
# =============================================================================
# rnaseq2tracks.sh — master orchestrator
# =============================================================================
# Usage: rnaseq2tracks --config /absolute/path/to/config.conf
# =============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$REPO/VERSION" 2>/dev/null || echo unknown)"
PYTHON_BIN="${PYTHON_BIN:-python}"
usage() {
  cat <<EOF
Usage: rnaseq2tracks --config FILE
       rnaseq2tracks --version

The samplesheet path and all processing options are read from config.conf.
EOF
}
CONFIG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) [[ $# -ge 2 ]] || { echo "ERROR: --config requires a file" >&2; exit 2; }; CONFIG="$2"; shift 2 ;;
    --version) echo "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unrecognized argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$CONFIG" ]] || { echo "ERROR: --config FILE is required" >&2; usage >&2; exit 2; }
CONFIG="$(realpath "$CONFIG")"
[[ -f "$CONFIG" ]] || { echo "ERROR: config not found: $CONFIG" >&2; exit 1; }
CONTRASTS=""
source "$CONFIG"
CONFIG_DIR="$(dirname "$CONFIG")"
resolve_path() {
  local value="$1"
  [[ "$value" == "~/"* ]] && value="$HOME/${value#~/}"
  [[ "$value" == /* ]] || value="$CONFIG_DIR/$value"
  realpath -m "$value"
}
SAMPLESHEET="$(resolve_path "${SAMPLESHEET:?SAMPLESHEET not set in config}")"
[[ -n "${CONTRASTS:-}" ]] && CONTRASTS="$(resolve_path "${CONTRASTS}")"
[[ -n "${FASTQSCREEN_CONF:-}" ]] && FASTQSCREEN_CONF="$(resolve_path "${FASTQSCREEN_CONF}")"
OUTDIR="$(resolve_path "${OUTDIR:-rnaseq2tracks_output}")"
mkdir -p "$OUTDIR/logs" "$OUTDIR/metadata"
MASTER_LOG="$OUTDIR/logs/rnaseq2tracks.log"
exec > >(tee -a "$MASTER_LOG") 2>&1
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
skip() { log "SKIP — $* (output exists; set FORCE_RERUN=1 to rerun)"; }

RUN_STARTED="$(date --iso-8601=seconds)"
CURRENT_STAGE="initialization"
write_status() {
  local state="$1" message="$2"
  printf 'workflow\trnaseq2tracks\nversion\t%s\nstatus\t%s\nstage\t%s\nmessage\t%s\nupdated_at\t%s\npid\t%s\n' \
    "$VERSION" "$state" "$CURRENT_STAGE" "$message" "$(date --iso-8601=seconds)" "$$" \
    > "$OUTDIR/metadata/run_status.tsv"
}
RUN_FINALIZED=0
on_exit() {
  local status=$?
  if [[ $status -ne 0 && "$RUN_FINALIZED" != "1" ]]; then
    write_status failed "workflow exited with status $status during $CURRENT_STAGE"
    log "WORKFLOW FAILED stage=$CURRENT_STAGE exit_status=$status"
  fi
}
trap on_exit EXIT
write_status running "workflow initialized"
log "rnaseq2tracks $VERSION START pid=$$"
log "Config: $CONFIG"
log "Samplesheet: $SAMPLESHEET"
log "Output: $OUTDIR"

FORCE_RERUN="${FORCE_RERUN:-0}"
done_check() {
  [[ "$FORCE_RERUN" == "1" ]] && return 1
  [[ -e "$1" ]] && return 0 || return 1
}

# ── Job throttle ──────────────────────────────────────────────────────────────
declare -a _PIDS=()
submit() {
  while [[ ${#_PIDS[@]} -ge ${MAX_JOBS:-8} ]]; do
    local live=()
    for p in "${_PIDS[@]}"; do kill -0 "$p" 2>/dev/null && live+=("$p"); done
    _PIDS=("${live[@]+"${live[@]}"}"); [[ ${#_PIDS[@]} -ge ${MAX_JOBS:-8} ]] && sleep 2
  done
  eval "$@" &
  _PIDS+=($!)
}
wait_all() {
  local ok=0
  for p in "${_PIDS[@]+"${_PIDS[@]}"}"; do wait "$p" || ok=1; done
  _PIDS=()
  [[ $ok -eq 0 ]] || { log "ERROR: a background job failed"; exit 1; }
}

# ── Step 0: metadata and preflight ───────────────────────────────────────────
CURRENT_STAGE="preflight"
write_status running "validating configuration and lane metadata"
log "STEP 0 — Validate configuration and samplesheet"
"$PYTHON_BIN" "$REPO/scripts/prepare_samplesheet.py" \
  --samplesheet "$SAMPLESHEET" --layout "${LIBRARY_LAYOUT:?LIBRARY_LAYOUT not set}" \
  --output-dir "$OUTDIR/metadata" --check-fastq
if [[ -n "${CONTRASTS:-}" ]]; then
  log "Using explicit contrast selection: $CONTRASTS"
else
  CONTRASTS="$OUTDIR/metadata/pairwise_contrasts.csv"
  log "Using automatically generated all-pairwise contrasts: $CONTRASTS"
fi
export CONTRASTS RNASEQ2TRACKS_RESOLVED_CONTRASTS="$CONTRASTS"
N_CONTRASTS=$(awk 'END {print NR > 0 ? NR - 1 : 0}' "$CONTRASTS")
log "Resolved $N_CONTRASTS condition contrast(s)"
if [[ "${RUN_DE:-true}" == "true" && "$N_CONTRASTS" -eq 0 ]]; then
  log "ERROR: RUN_DE=true requires at least two conditions or one explicit contrast"
  exit 1
fi
"$REPO/scripts/preflight_check.sh" "$CONFIG"

# ── Species path resolution ───────────────────────────────────────────────────
SPECIES="${SPECIES:-mouse}"
case "$SPECIES" in
  human)
    STAR_INDEX="${STAR_INDEX_HUMAN:?STAR_INDEX_HUMAN not set}"
    GTF="${GTF_HUMAN:?GTF_HUMAN not set}"
    CHROM_SIZES="${CHROM_SIZES_HUMAN:?CHROM_SIZES_HUMAN not set}"
    RSEQC_BED="${RSEQC_BED_HUMAN:-}" ;;
  mouse)
    STAR_INDEX="${STAR_INDEX_MOUSE:?STAR_INDEX_MOUSE not set}"
    GTF="${GTF_MOUSE:?GTF_MOUSE not set}"
    CHROM_SIZES="${CHROM_SIZES_MOUSE:?CHROM_SIZES_MOUSE not set}"
    RSEQC_BED="${RSEQC_BED_MOUSE:-}" ;;
  *) echo "ERROR: SPECIES must be human|mouse" >&2; exit 1 ;;
esac
export SPECIES CHROMOSOME_NAMING="${CHROMOSOME_NAMING:-ucsc}" \
       REGULAR_CHROMS_ONLY="${REGULAR_CHROMS_ONLY:-true}"

[[ "$LIBRARY_LAYOUT" =~ ^(SE|PE)$ ]] || \
  { echo "ERROR: LIBRARY_LAYOUT must be SE|PE" >&2; exit 1; }

# ── Step 1: Output tree ───────────────────────────────────────────────────────
log "STEP 1 — Output: $OUTDIR"
mkdir -p \
  "$OUTDIR/fastQC/raw"          "$OUTDIR/fastQC/trimmed" \
  "$OUTDIR/multiQC/raw"         "$OUTDIR/multiQC/trimmed" \
  "$OUTDIR/multiQC/alignments"  "$OUTDIR/multiQC/final" \
  "$OUTDIR/trimmedFastq"        "$OUTDIR/STARalignments" \
  "$OUTDIR/STARlogs/lanes"      "$OUTDIR/STARgeneCounts/lanes" \
  "$OUTDIR/bams/lanes" \
  "$OUTDIR/07_qc/star"          "$OUTDIR/07_qc/rseqc" \
  "$OUTDIR/07_qc/multiqc" \
  "$OUTDIR/bedGraph/raw"        "$OUTDIR/bedGraph/normalized" \
  "$OUTDIR/bedGraph/merged" \
  "$OUTDIR/bigwig" \
  "$OUTDIR/analysis/counts"     "$OUTDIR/analysis/DE" \
  "$OUTDIR/analysis/figures"    "$OUTDIR/reports" \
  "$OUTDIR/fastQScreen"

# ── Parse validated lane and biological-sample metadata ──────────────────────
LANE_SHEET="$OUTDIR/metadata/validated_lanes.tsv"
ANALYSIS_SAMPLESHEET="$OUTDIR/metadata/analysis_samplesheet.csv"
SAMPLE_MANIFEST="$OUTDIR/metadata/validated_samples.tsv"
declare -a LID SID R1 R2 COND REP STRAND
while IFS=$'\t' read -r library_id sample_id biological_id technical_id lane_id r1 r2 condition batch description strandedness; do
  [[ "$library_id" == "library_id" ]] && continue
  LID+=("$library_id"); SID+=("$sample_id"); R1+=("$r1"); R2+=("$r2")
  COND+=("$condition"); REP+=("$biological_id"); STRAND+=("$strandedness")
done < "$LANE_SHEET"
N_LANES=${#LID[@]}
declare -a SAMPLE_ID SAMPLE_COND SAMPLE_REP SAMPLE_STRAND
while IFS=$'\t' read -r sample_id biological_id condition batch description strandedness technical_count lane_count; do
  [[ "$sample_id" == "sample_id" ]] && continue
  SAMPLE_ID+=("$sample_id"); SAMPLE_REP+=("$biological_id")
  SAMPLE_COND+=("$condition"); SAMPLE_STRAND+=("$strandedness")
done < "$SAMPLE_MANIFEST"
N_SAMPLES=${#SAMPLE_ID[@]}
log "Loaded $N_SAMPLES biological samples from $N_LANES technical-library/lane rows; layout=$LIBRARY_LAYOUT species=$SPECIES"

# ── Step 2–3: FastQC / MultiQC raw ───────────────────────────────────────────
CURRENT_STAGE="raw_qc"
write_status running "raw FastQC and FastQ Screen for $N_LANES lane rows"
_s2="$OUTDIR/fastQC/raw/.complete"
if done_check "$_s2"; then skip "STEP 2 — FastQC raw"
else
  log "STEP 2 — FastQC raw ($N_LANES technical-library/lane rows)"
  for ((i=0;i<N_LANES;i++)); do
    mkdir -p "$OUTDIR/fastQC/raw/${LID[$i]}"
    if [[ "$LIBRARY_LAYOUT" == "PE" ]]; then
      submit "${FASTQC_BIN:-fastqc} --outdir '$OUTDIR/fastQC/raw/${LID[$i]}' \
        --threads ${FASTQC_THREADS:-4} '${R1[$i]}' '${R2[$i]}'"
    else
      submit "${FASTQC_BIN:-fastqc} --outdir '$OUTDIR/fastQC/raw/${LID[$i]}' \
        --threads ${FASTQC_THREADS:-4} '${R1[$i]}'"
    fi
  done
  wait_all
  touch "$_s2"
fi
if done_check "$OUTDIR/multiQC/raw/multiQC_raw.html"; then skip "STEP 3 — MultiQC raw"
else
  log "STEP 3 — MultiQC raw"
  "${MULTIQC_BIN:-multiqc}" "$OUTDIR/fastQC/raw" -n multiQC_raw \
    -o "$OUTDIR/multiQC/raw" --data-format tsv --export -q
fi

# ── Step 2b: FastQ Screen — species swap + mycoplasma contamination ───────────
_s2b="$OUTDIR/fastQScreen/.complete"
if [[ "${RUN_FASTQSCREEN:-true}" != "true" ]]; then
  log "STEP 2b — FastQ Screen SKIPPED (RUN_FASTQSCREEN=false)"
elif done_check "$_s2b"; then skip "STEP 2b — FastQ Screen"
else
  FASTQSCREEN_CONF="${FASTQSCREEN_CONF:-$REPO/config/fastq_screen.conf}"
  if [[ -f "$FASTQSCREEN_CONF" ]] && command -v fastq_screen &>/dev/null; then
    log "STEP 2b — FastQ Screen (species + mycoplasma screen)"
    for ((i=0;i<N_LANES;i++)); do
      mkdir -p "$OUTDIR/fastQScreen/${LID[$i]}"
      submit "fastq_screen \
        --conf '$FASTQSCREEN_CONF' \
        --outdir '$OUTDIR/fastQScreen/${LID[$i]}' \
        --threads '${FASTQSCREEN_THREADS:-4}' \
        --subset '${FASTQSCREEN_SUBSET:-200000}' \
        --aligner bowtie2 \
        '${R1[$i]}'"
    done
    wait_all
    touch "$_s2b"
  else
    log "STEP 2b — FastQ Screen SKIPPED (fastq_screen not found or conf missing: $FASTQSCREEN_CONF)"
  fi
fi

# ── Step 4: TrimGalore ────────────────────────────────────────────────────────
CURRENT_STAGE="trimming"
write_status running "trimming $N_LANES technical-library/lane rows"
log "STEP 4 — TrimGalore ($LIBRARY_LAYOUT; per lane with checkpoints)"
for ((i=0;i<N_LANES;i++)); do
  _s4=$(if [[ "$LIBRARY_LAYOUT" == "PE" ]]; then
    echo "$OUTDIR/trimmedFastq/${LID[$i]}_val_1.fq.gz"
  else echo "$OUTDIR/trimmedFastq/${LID[$i]}_trimmed.fq.gz"; fi)
  if [[ "$FORCE_RERUN" != "1" && -f "$OUTDIR/STARlogs/lanes/${LID[$i]}_Log.final.out" ]]; then
    log "  SKIP ${LID[$i]} (downstream STAR checkpoint exists)"
  elif done_check "$_s4"; then
    log "  SKIP ${LID[$i]} (trimmed FASTQ exists)"
  else
    submit "$REPO/scripts/trimgalore_single.sh \
      '${R1[$i]}' '${R2[$i]}' '$OUTDIR/trimmedFastq' \
      '${TRIM_QUALITY:-20}' '${TRIM_MIN_LENGTH:-20}' '$LIBRARY_LAYOUT' '${LID[$i]}'"
  fi
done
wait_all

# ── Step 5–6: FastQC / MultiQC trimmed ───────────────────────────────────────
if done_check "$OUTDIR/multiQC/trimmed/multiQC_trimmed.html"; then
  skip "STEP 5+6 — FastQC/MultiQC trimmed"
else
  log "STEP 5 — FastQC trimmed"
  while IFS= read -r -d '' fq; do
    submit "${FASTQC_BIN:-fastqc} --outdir '$OUTDIR/fastQC/trimmed' \
      --threads ${FASTQC_THREADS:-4} '$fq'"
  done < <(find "$OUTDIR/trimmedFastq" -name "*.fq.gz" -print0 2>/dev/null); wait_all
  log "STEP 6 — MultiQC trimmed"
  "${MULTIQC_BIN:-multiqc}" "$OUTDIR/fastQC/trimmed" -n multiQC_trimmed \
    -o "$OUTDIR/multiQC/trimmed" --data-format tsv --export -q
fi

# ── Step 7: STAR ──────────────────────────────────────────────────────────────
CURRENT_STAGE="alignment"
write_status running "aligning $N_LANES technical-library/lane rows"
log "STEP 7 — STAR alignment (per lane with checkpoints)"
for ((i=0;i<N_LANES;i++)); do
  _s7="$OUTDIR/STARlogs/lanes/${LID[$i]}_Log.final.out"
  _staged_s7="$OUTDIR/STARalignments/${LID[$i]}_Log.final.out"
  _staged_bam="$OUTDIR/STARalignments/${LID[$i]}_Aligned.out.bam"
  _staged_counts="$OUTDIR/STARalignments/${LID[$i]}_ReadsPerGene.out.tab"
  if done_check "$_s7"; then
    log "  SKIP ${LID[$i]} (STAR log exists)"
  elif [[ "$FORCE_RERUN" != "1" && -s "$_staged_s7" && -s "$_staged_bam" && -s "$_staged_counts" ]]; then
    log "  SKIP ${LID[$i]} (complete staged STAR outputs exist from an interrupted run)"
  else
    if [[ "$LIBRARY_LAYOUT" == "PE" ]]; then
      _r1="$OUTDIR/trimmedFastq/${LID[$i]}_val_1.fq.gz"
      _r2="$OUTDIR/trimmedFastq/${LID[$i]}_val_2.fq.gz"
      submit "$REPO/scripts/star_PE_single.sh \
        '$STAR_INDEX' '$OUTDIR/STARalignments' '${LID[$i]}' '$_r1' '$_r2' \
        '${STAR_THREADS:-15}' '${TMPDIR:-/tmp}'"
    else
      _r1="$OUTDIR/trimmedFastq/${LID[$i]}_trimmed.fq.gz"
      submit "$REPO/scripts/star_SE_single.sh \
        '$STAR_INDEX' '$OUTDIR/STARalignments' '${LID[$i]}' '$_r1' \
        '${STAR_THREADS:-15}' '${TMPDIR:-/tmp}'"
    fi
  fi
done
wait_all
mv "$OUTDIR/STARalignments/"*ReadsPerGene.out.tab "$OUTDIR/STARgeneCounts/lanes/" 2>/dev/null || true
mv "$OUTDIR/STARalignments/"*Log.final.out "$OUTDIR/STARlogs/lanes/" 2>/dev/null || true

# ── Step 8: samtools sort + index ─────────────────────────────────────────────
log "STEP 8 — samtools sort + index lane BAMs"
for ((i=0;i<N_LANES;i++)); do
  bam="$OUTDIR/STARalignments/${LID[$i]}_Aligned.out.bam"
  sorted="$OUTDIR/bams/lanes/${LID[$i]}_sortedS.bam"
  sample_final="$OUTDIR/bams/${SID[$i]}_sortedS.bam"
  if [[ "$FORCE_RERUN" != "1" && -f "$sample_final" && -f "$sample_final.bai" ]]; then
    log "  SKIP ${LID[$i]} (consolidated sample BAM exists)"
  elif done_check "$sorted"; then
    log "  SKIP ${LID[$i]} (sorted lane BAM exists)"
  else
    submit "$REPO/scripts/bam_sort_index.sh '$bam' '$OUTDIR/bams/lanes' '${SAMTOOLS_THREADS:-4}'"
  fi
done
wait_all

# ── Step 8b: merge technical libraries/lanes into biological samples ─────────
CURRENT_STAGE="technical_replicate_merge"
write_status running "merging $N_LANES lane BAM/count units into $N_SAMPLES biological samples"
log "STEP 8b — Merge technical replicates and lanes"
for sample_id in "${SAMPLE_ID[@]}"; do
  merged="$OUTDIR/bams/${sample_id}_sortedS.bam"
  if done_check "$merged" && done_check "$merged.bai"; then
    log "  SKIP $sample_id (merged BAM exists)"
    continue
  fi
  inputs=()
  for ((i=0;i<N_LANES;i++)); do
    [[ "${SID[$i]}" == "$sample_id" ]] && inputs+=("$OUTDIR/bams/lanes/${LID[$i]}_sortedS.bam")
  done
  [[ ${#inputs[@]} -gt 0 ]] || { log "ERROR: no lane BAMs found for $sample_id"; exit 1; }
  log "  $sample_id: consolidating ${#inputs[@]} lane BAM(s)"
  if [[ ${#inputs[@]} -eq 1 ]]; then
    cp -f "${inputs[0]}" "$merged"
  else
    samtools merge -f -@ "${SAMTOOLS_THREADS:-4}" "$merged" "${inputs[@]}"
  fi
  samtools index -@ "${SAMTOOLS_THREADS:-4}" "$merged"
done

"$PYTHON_BIN" "$REPO/scripts/merge_star_counts.py" \
  --lanes "$LANE_SHEET" --count-dir "$OUTDIR/STARgeneCounts/lanes" \
  --output-dir "$OUTDIR/STARgeneCounts"
printf 'sample_id\tlane_count\tbam\n' > "$OUTDIR/metadata/technical_merge_audit.tsv"
for sample_id in "${SAMPLE_ID[@]}"; do
  lane_count=$(awk -F '\t' -v s="$sample_id" 'NR>1 && $2==s {n++} END {print n+0}' "$LANE_SHEET")
  printf '%s\t%s\t%s\n' "$sample_id" "$lane_count" "$OUTDIR/bams/${sample_id}_sortedS.bam" \
    >> "$OUTDIR/metadata/technical_merge_audit.tsv"
done

# ── Step 9: MultiQC alignments ────────────────────────────────────────────────
if done_check "$OUTDIR/multiQC/alignments/multiQC_alignments.html"; then
  skip "STEP 9 — MultiQC alignments"
else
  log "STEP 9 — MultiQC alignments"
  "${MULTIQC_BIN:-multiqc}" "$OUTDIR/STARlogs/lanes" -n multiQC_alignments \
    -o "$OUTDIR/multiQC/alignments" --data-format tsv --export -q
fi

# ── Step 9b: STAR QC summary ──────────────────────────────────────────────────
if done_check "$OUTDIR/07_qc/star/star_alignment_summary.tsv"; then
  skip "STEP 9b — STAR alignment summary"
else
  log "STEP 9b — STAR alignment summary"
  "$REPO/scripts/collect_star_qc.sh" "$OUTDIR/STARlogs/lanes" "$OUTDIR/07_qc"
fi

# ── Step 10: bam_to_bedgraph.R — PARALLEL (1 job per sample) ─────────────────
log "STEP 10 — bam_to_bedgraph.R (parallel: 1 job per sample)"
_any_s10_missing=0
CURRENT_STAGE="coverage"
write_status running "creating sample-level coverage tracks"
for ((i=0;i<N_SAMPLES;i++)); do
  _fwd="$OUTDIR/bedGraph/raw/${SAMPLE_ID[$i]}_FwdS.bedGraph.gz"
  _uns="$OUTDIR/bedGraph/raw/${SAMPLE_ID[$i]}_unstranded.bedGraph.gz"
  _norm_fwd="$OUTDIR/bedGraph/normalized/${SAMPLE_ID[$i]}_FwdS_norm.bedGraph.gz"
  _norm_uns="$OUTDIR/bedGraph/normalized/${SAMPLE_ID[$i]}_unstranded_norm.bedGraph.gz"
  if [[ "$FORCE_RERUN" != "1" && ( -f "$_norm_fwd" || -f "$_norm_uns" ) ]]; then
    log "  SKIP ${SAMPLE_ID[$i]} (downstream normalized bedGraph exists)"
  elif [[ -f "$_fwd" || -f "$_uns" ]] && [[ "$FORCE_RERUN" != "1" ]]; then
    log "  SKIP ${SAMPLE_ID[$i]} (bedGraph exists)"
  else
    _any_s10_missing=1
    submit "${RSCRIPT_BIN:-Rscript} '$REPO/scripts/Rscripts/bam_to_bedgraph.R' \
      --sample_id '${SAMPLE_ID[$i]}' \
      --bam '$OUTDIR/bams/${SAMPLE_ID[$i]}_sortedS.bam' \
      --strandedness '${SAMPLE_STRAND[$i]}' \
      --outdir '$OUTDIR/bedGraph/raw' \
      --layout '$LIBRARY_LAYOUT'"
  fi
done
wait_all
[[ $_any_s10_missing -eq 0 ]] && skip "STEP 10 — all bedGraphs already present" || true

# ── Step 10b: Strand consistency (always runs — fast safety check) ────────────
log "STEP 10b — Strand consistency check"
"$REPO/scripts/check_strand_consistency.sh" \
  "$ANALYSIS_SAMPLESHEET" "$OUTDIR/bams" "$LIBRARY_LAYOUT" "${STRAND_TOLERANCE_PCT:-5}" "${MAX_JOBS:-8}"

# ── Step 10c: RSeQC — background (steps 11-18 run in parallel) ─────────────
_s10c_sentinel="$OUTDIR/07_qc/rseqc/infer_experiment/${SAMPLE_ID[0]}_infer_experiment.txt"
RSEQC_BG_PID=""
if [[ "${RUN_RSEQC:-true}" == "true" && -n "${RSEQC_BED:-}" && -f "${RSEQC_BED:-/dev/null}" ]]; then
  if done_check "$_s10c_sentinel" && done_check "$OUTDIR/07_qc/multiqc/multiQC_rseqc.html"; then
    skip "STEP 10c — RSeQC (already complete)"
  else
    log "STEP 10c — RSeQC launching in background (PID will follow)"
    (
      if ! done_check "$_s10c_sentinel"; then
        "$REPO/scripts/run_rnaseq_qc.sh" "$ANALYSIS_SAMPLESHEET" "$OUTDIR/bams" "$OUTDIR/07_qc" "$RSEQC_BED" \
          "${RSEQC_BIN_DIR:-}" "$LIBRARY_LAYOUT" "${MAX_JOBS:-8}"
      fi
      if ! done_check "$OUTDIR/07_qc/multiqc/multiQC_rseqc.html"; then
        MQC_RSEQC=()
        for d in read_distribution junction_annotation junction_saturation genebody; do
          [[ -d "$OUTDIR/07_qc/rseqc/$d" ]] && MQC_RSEQC+=("$OUTDIR/07_qc/rseqc/$d")
        done
        [[ ${#MQC_RSEQC[@]} -gt 0 ]] &&         "${MULTIQC_BIN:-multiqc}" "${MQC_RSEQC[@]}"           -n multiQC_rseqc -o "$OUTDIR/07_qc/multiqc"           --data-format tsv --export -q || true
      fi
    ) &
    RSEQC_BG_PID=$!
    log "STEP 10c — RSeQC running in background PID=$RSEQC_BG_PID"
  fi
else
  log "STEP 10c — RSeQC SKIPPED (RUN_RSEQC=false or RSEQC_BED not found)"
fi

# ── Step 11: DESeq2 normalization (must be serial — needs all samples) ────────
CURRENT_STAGE="gene_expression"
write_status running "building biological-sample count matrix and DESeq2 model"
if done_check "$OUTDIR/analysis/counts/dds.RData"; then
  skip "STEP 11 — DESeq2 normalization"
else
  log "STEP 11 — DESeq2 normalization"
  "${RSCRIPT_BIN:-Rscript}" "$REPO/scripts/Rscripts/deseq2_normalize.R" \
    --samplesheet "$ANALYSIS_SAMPLESHEET" --countdir "$OUTDIR/STARgeneCounts" \
    --gtf "$GTF" --layout "$LIBRARY_LAYOUT" \
    --outdir "$OUTDIR/analysis/counts" --design "${DESIGN_FORMULA:-~ condition}"
fi

# ── Step 12: normalize_bedgraph.R — PARALLEL (1 job per sample) ──────────────
log "STEP 12 — normalize_bedgraph.R (parallel: 1 job per sample)"
for ((i=0;i<N_SAMPLES;i++)); do
  _nfwd="$OUTDIR/bedGraph/normalized/${SAMPLE_ID[$i]}_FwdS_norm.bedGraph.gz"
  _nuns="$OUTDIR/bedGraph/normalized/${SAMPLE_ID[$i]}_unstranded_norm.bedGraph.gz"
  if [[ -f "$_nfwd" || -f "$_nuns" ]] && [[ "$FORCE_RERUN" != "1" ]]; then
    log "  SKIP ${SAMPLE_ID[$i]} (normalized bedGraph exists)"
  else
    submit "${RSCRIPT_BIN:-Rscript} '$REPO/scripts/Rscripts/normalize_bedgraph.R' \
      --sample_id '${SAMPLE_ID[$i]}' \
      --strandedness '${SAMPLE_STRAND[$i]}' \
      --sffile '$OUTDIR/analysis/counts/size_factors.tsv' \
      --rawbgdir '$OUTDIR/bedGraph/raw' \
      --outdir '$OUTDIR/bedGraph/normalized' \
      --layout '$LIBRARY_LAYOUT'"
  fi
done; wait_all

# ── Step 13: BigWig per sample ────────────────────────────────────────────────
_s13="$OUTDIR/bigwig/${SAMPLE_ID[0]}_FwdS_norm.bw"
[[ ! -f "$_s13" ]] && _s13="$OUTDIR/bigwig/${SAMPLE_ID[0]}_unstranded_norm.bw"
if done_check "$_s13"; then skip "STEP 13 — BigWig per sample"
else
  log "STEP 13 — BigWig [species=$SPECIES naming=$CHROMOSOME_NAMING filter=$REGULAR_CHROMS_ONLY]"
  for bg in "$OUTDIR/bedGraph/normalized/"*_norm.bedGraph.gz; do
    [[ -f "$bg" ]] || continue
    submit "$REPO/scripts/norm_bedgraph_to_bigwig.sh \
      '$bg' '$CHROM_SIZES' '$OUTDIR/bigwig' '${KENTUTILS_DIR}'"
  done; wait_all
fi

# ── Step 14: merge_bedgraph_replicates.R — PARALLEL (1 job per condition) ─────
_n14=$(find "$OUTDIR/bedGraph/merged" -name "*_merged.bedGraph" 2>/dev/null | wc -l)
_existing_merged_bw=$(find "$OUTDIR/bigwig" -name "*_merged.bw" 2>/dev/null | wc -l)
if [[ "${MERGE_CONDITION_TRACKS:-${MERGE_REPLICATES:-true}}" != "true" ]]; then
  log "STEP 14 — condition-level merged tracks SKIPPED"
elif [[ "$_existing_merged_bw" -gt 0 ]] && [[ "$FORCE_RERUN" != "1" ]]; then
  skip "STEP 14 — downstream merged BigWigs already exist"
elif [[ "$_n14" -gt 0 ]] && [[ "$FORCE_RERUN" != "1" ]]; then
  skip "STEP 14 — merge_bedgraph_replicates.R"
else
  log "STEP 14 — merge_bedgraph_replicates.R (parallel: 1 job per condition)"
  # Build unique conditions with their sample IDs and strandedness
  declare -A COND_SIDS COND_STRAND
  for ((i=0;i<N_SAMPLES;i++)); do
    c="${SAMPLE_COND[$i]}"
    COND_SIDS["$c"]="${COND_SIDS[$c]:-}${COND_SIDS[$c]:+,}${SAMPLE_ID[$i]}"
    COND_STRAND["$c"]="${SAMPLE_STRAND[$i]}"
  done
  for c in "${!COND_SIDS[@]}"; do
    submit "${RSCRIPT_BIN:-Rscript} '$REPO/scripts/Rscripts/merge_bedgraph_replicates.R' \
      --condition '$c' \
      --sample_ids '${COND_SIDS[$c]}' \
      --strandedness '${COND_STRAND[$c]}' \
      --bgdir '$OUTDIR/bedGraph/normalized' \
      --outdir '$OUTDIR/bedGraph/merged' \
      --layout '$LIBRARY_LAYOUT'"
  done; wait_all
fi

# ── Step 15: merged BigWigs ───────────────────────────────────────────────────
_n15=$(find "$OUTDIR/bigwig" -name "*_merged.bw" 2>/dev/null | wc -l)
if [[ "${MERGE_CONDITION_TRACKS:-${MERGE_REPLICATES:-true}}" != "true" ]]; then
  log "STEP 15 — condition-level merged BigWigs SKIPPED"
elif [[ "$_n15" -gt 0 ]] && [[ "$FORCE_RERUN" != "1" ]]; then
  skip "STEP 15 — merged BigWigs"
else
  log "STEP 15 — merged BigWigs"
  for bg in "$OUTDIR/bedGraph/merged/"*_merged.bedGraph; do
    [[ -f "$bg" ]] || continue
    submit "$REPO/scripts/norm_bedgraph_to_bigwig.sh \
      '$bg' '$CHROM_SIZES' '$OUTDIR/bigwig' '${KENTUTILS_DIR}'"
  done; wait_all
fi

# ── Step 16: DESeq2 DE ────────────────────────────────────────────────────────
_n16=$(find "$OUTDIR/analysis/DE" -name "*_DE_results.tsv" 2>/dev/null | wc -l)
if [[ "${RUN_DE:-true}" != "true" ]]; then
  log "STEP 16 — DESeq2 DE SKIPPED (RUN_DE=false)"
elif [[ "$_n16" -gt 0 ]] && [[ "$FORCE_RERUN" != "1" ]]; then
  skip "STEP 16 — DESeq2 DE"
else
  export GTF
  log "STEP 16 — DESeq2 DE"
  "${RSCRIPT_BIN:-Rscript}" "$REPO/scripts/Rscripts/deseq2_de.R" \
    --countsrdata "$OUTDIR/analysis/counts/dds.RData" \
    --contrasts "$CONTRASTS" \
    --outdir "$OUTDIR/analysis/DE" \
    --padj "${DE_PADJ_THRESHOLD:-0.05}" --lfc "${DE_LFC_THRESHOLD:-1}"
fi

# ── Step 17: DESeq2 QC plots ──────────────────────────────────────────────────
if [[ "${RUN_DE:-true}" != "true" ]]; then
  log "STEP 17 — DESeq2 QC plots SKIPPED (RUN_DE=false)"
elif done_check "$OUTDIR/analysis/figures/PCA.pdf"; then
  skip "STEP 17 — DESeq2 QC plots"
else
  log "STEP 17 — DESeq2 QC plots"
  "${RSCRIPT_BIN:-Rscript}" "$REPO/scripts/Rscripts/deseq2_qc_plots.R" \
    --countsrdata "$OUTDIR/analysis/counts/dds.RData" \
    --outdir "$OUTDIR/analysis/figures"
fi

# ── Step 18: UCSC tracks ──────────────────────────────────────────────────────
if [[ "${UCSC_TRACKS:-true}" != "true" ]]; then
  log "STEP 18 — UCSC tracks SKIPPED (UCSC_TRACKS=false)"
elif done_check "$OUTDIR/reports/ucsc_tracks.txt"; then
  skip "STEP 18 — UCSC tracks"
else
  if [[ -n "${UCSC_BASE_URL:-}" ]]; then
    log "STEP 18 — UCSC tracks"
    "$REPO/scripts/create_ucsc_tracks.sh" \
      "$OUTDIR/bigwig" "$OUTDIR/reports/ucsc_tracks.txt" \
      "$OUTDIR/reports/bigwig_summary.txt" "$UCSC_BASE_URL"
  else
    log "STEP 18 — UCSC tracks SKIPPED (UCSC_BASE_URL not set)"
  fi
fi

# ── Wait for background RSeQC before final MultiQC ──────────────────────────
if [[ -n "${RSEQC_BG_PID:-}" ]]; then
  log "STEP 19 — waiting for background RSeQC (PID $RSEQC_BG_PID)..."
  wait "$RSEQC_BG_PID"
fi
# ── Step 19: MultiQC final ────────────────────────────────────────────────────
if done_check "$OUTDIR/multiQC/final/multiQC_final.html"; then
  skip "STEP 19 — MultiQC final"
else
  log "STEP 19 — MultiQC final"
  MQC_SOURCES=("$OUTDIR/fastQC" "$OUTDIR/fastQScreen" "$OUTDIR/multiQC/raw" "$OUTDIR/multiQC/trimmed"
               "$OUTDIR/STARlogs" "$OUTDIR/multiQC/alignments")
  for d in read_distribution junction_annotation junction_saturation genebody; do
    [[ -d "$OUTDIR/07_qc/rseqc/$d" ]] && MQC_SOURCES+=("$OUTDIR/07_qc/rseqc/$d")
  done
  "${MULTIQC_BIN:-multiqc}" "${MQC_SOURCES[@]}" \
  --ignore "$OUTDIR/07_qc/multiqc" \
    -n multiQC_final -o "$OUTDIR/multiQC/final" \
    --data-format tsv --export -q
fi

# ── Step 20: Gene enrichment analysis (ORA + GSEA) ───────────────────────────
CURRENT_STAGE="enrichment"
write_status running "running differential-expression enrichment"
if [[ "${RUN_DE:-true}" != "true" || "${RUN_ENRICHMENT:-true}" != "true" ]]; then
  log "STEP 20 — Enrichment analysis SKIPPED"
elif done_check "$OUTDIR/analysis/enrichment/.enrichment_done"; then
  skip "STEP 20 — Enrichment analysis"
else
  log "STEP 20 — Enrichment analysis (ORA + GSEA)"
  "${RSCRIPT_BIN:-Rscript}" "$REPO/scripts/Rscripts/deseq2_enrichment.R" \
    --dedir     "$OUTDIR/analysis/DE" \
    --contrasts "$(realpath "${CONTRASTS}")" \
    --outdir    "$OUTDIR/analysis/enrichment" \
    --species   "$SPECIES" \
    --padj      "${PADJ_THRESHOLD:-0.05}" \
    --lfc       "${LFC_THRESHOLD:-1}" \
    --minGS     "${ENRICHMENT_MINGS:-10}" \
    --maxGS     "${ENRICHMENT_MAXGS:-500}"
  touch "$OUTDIR/analysis/enrichment/.enrichment_done"
fi

# ── Step 21: final report ─────────────────────────────────────────────────────
# Render after enrichment so the report can include every requested result.
CURRENT_STAGE="report"
write_status running "rendering final report"
{
  printf 'workflow\trnaseq2tracks\n'
  printf 'version\t%s\n' "$VERSION"
  printf 'started_at\t%s\n' "$RUN_STARTED"
  printf 'report_rendered_at\t%s\n' "$(date --iso-8601=seconds)"
  printf 'config\t%s\n' "$CONFIG"
  printf 'samplesheet\t%s\n' "$SAMPLESHEET"
  printf 'biological_samples\t%s\n' "$N_SAMPLES"
  printf 'technical_library_or_lane_rows\t%s\n' "$N_LANES"
  printf 'condition_contrasts\t%s\n' "$N_CONTRASTS"
  printf 'contrasts\t%s\n' "$CONTRASTS"
  printf 'layout\t%s\n' "$LIBRARY_LAYOUT"
  printf 'species\t%s\n' "$SPECIES"
  printf 'config_sha256\t%s\n' "$(sha256sum "$CONFIG" | awk '{print $1}')"
  printf 'samplesheet_sha256\t%s\n' "$(sha256sum "$SAMPLESHEET" | awk '{print $1}')"
} > "$OUTDIR/metadata/run_provenance.tsv"
if done_check "$OUTDIR/reports/pipeline_report.html"; then
  skip "STEP 21 — Pipeline report"
else
  log "STEP 21 — Pipeline report"
  "${RSCRIPT_BIN:-Rscript}" -e "
    rmarkdown::render(
      input             = '$REPO/scripts/Rscripts/pipeline_report.Rmd',
      output_file       = 'pipeline_report.html',
      output_dir        = '$OUTDIR/reports',
      intermediates_dir = '$OUTDIR/reports',
      knit_root_dir     = '$OUTDIR',
      params = list(
        outdir      = '$OUTDIR',
        config      = '$CONFIG',
        samplesheet = '$ANALYSIS_SAMPLESHEET',
        species     = '$SPECIES',
        layout      = '$LIBRARY_LAYOUT'
      ),
      quiet = TRUE
    )
  "
fi

# =============================================================================
# Step 22 — Post-run cleanup of large intermediate files
# =============================================================================
# Enable:   set CLEANUP_INTERMEDIATES=1 in config.conf
# Dry-run:  set CLEANUP_DRYRUN=1        in config.conf  (prints, never deletes)
# Optional: set CLEANUP_ALLCHR_BEDGRAPH=1 to also remove all_chromosomes.bedGraph.gz
#
# FILES REMOVED (all regenerable from raw FASTQs + pipeline scripts):
#   trimmedFastq/    *_trimmed.fq.gz  *_val_1.fq.gz  *_val_2.fq.gz
#   STARalignments/  *_Aligned.out.bam  *_SJ.out.tab
#   bams/lanes/      lane-level *_sortedS.bam and indices after sample merging
#   bedGraph/raw/    *.bedGraph.gz        (un-normalised per-sample coverage)
#   bedGraph/merged/ *.bedGraph           (uncompressed merged bedGraphs)
#   bigwig/          *.all_chromosomes.bedGraph.gz  [optional]
#
# FILES KEPT:
#   Original FASTQs (never touched by pipeline)
#   bedGraph/normalized/  *_norm.bedGraph.gz
#   bigwig/               *.sorted.bedGraph.gz  *.bw
#   Biological-sample BAMs in bams/, STARgeneCounts/, STARlogs/, analysis/,
#   reports/ and QC outputs
# =============================================================================

cleanup_intermediates() {
    local outdir="$1"
    local remove_allchr="${CLEANUP_ALLCHR_BEDGRAPH:-0}"
    local dry="${CLEANUP_DRYRUN:-0}"

    log "STEP 22 — Cleanup: verifying pipeline completion sentinels..."

    local abort=0
    local -a sentinels=(
        "$outdir/multiQC/final/multiQC_final.html"
        "$outdir/reports/pipeline_report.html"
    )
    if [[ "${RUN_DE:-true}" == "true" && "${RUN_ENRICHMENT:-true}" == "true" ]]; then
        sentinels+=("$outdir/analysis/enrichment/.enrichment_done")
    fi
    for s in "${sentinels[@]}"; do
        if [[ ! -e "$s" ]]; then
            log "CLEANUP ABORTED — sentinel missing: $s"
            abort=1
        fi
    done

    local nbw
    nbw=$(find "$outdir/bigwig" -name "*.bw" 2>/dev/null | wc -l)
    if [[ "$nbw" -eq 0 ]]; then
        log "CLEANUP ABORTED — no .bw files found in $outdir/bigwig/"
        abort=1
    fi

    [[ $abort -eq 1 ]] && { log "Cleanup skipped — pipeline not fully complete."; return 1; }

    [[ "$dry" == "1" ]] && log "STEP 22 — DRY-RUN mode (nothing will be deleted)"
    log "STEP 22 — All sentinels OK. Starting cleanup..."

    _rm() {
        if [[ "$dry" == "1" ]]; then
            echo "  [DRY-RUN] would delete: $*"
        else
            rm -f "$@"
        fi
    }

    # 1. Trimmed FASTQs
    log "  1/5  Trimmed FASTQs: $outdir/trimmedFastq/"
    while IFS= read -r f; do _rm "$f"; done < <(
        find "$outdir/trimmedFastq" -maxdepth 1 \
            \( -name "*_trimmed.fq.gz" -o -name "*_val_1.fq.gz" -o -name "*_val_2.fq.gz" \) 2>/dev/null || true
    )

    # 2. STAR unsorted BAMs + SJ tables
    log "  2/5  STAR unsorted BAMs + SJ tables: $outdir/STARalignments/"
    while IFS= read -r f; do _rm "$f"; done < <(
        find "$outdir/STARalignments" -maxdepth 1 \
            \( -name "*_Aligned.out.bam" -o -name "*_SJ.out.tab" \) 2>/dev/null || true
    )

    # 3. Lane-level BAMs + indices; final biological-sample BAMs are retained
    log "  3/5  Lane BAMs + indices: $outdir/bams/lanes/"
    while IFS= read -r f; do _rm "$f"; done < <(
        find "$outdir/bams/lanes" -maxdepth 1 \
            \( -name "*_sortedS.bam" -o -name "*_sortedS.bam.bai" \) 2>/dev/null || true
    )

    # 4. Raw per-sample bedGraphs (already .gz from bam_to_bedgraph.R)
    log "  4/5  Raw bedGraphs: $outdir/bedGraph/raw/"
    while IFS= read -r f; do _rm "$f"; done < <(
        find "$outdir/bedGraph/raw" -maxdepth 1 -name "*.bedGraph.gz" 2>/dev/null || true
    )

    # 5. Uncompressed merged bedGraphs (keep .gz files)
    log "  5/5  Uncompressed merged bedGraphs: $outdir/bedGraph/merged/"
    while IFS= read -r f; do _rm "$f"; done < <(
        find "$outdir/bedGraph/merged" -maxdepth 1 -name "*.bedGraph" ! -name "*.gz" 2>/dev/null || true
    )

    # Optional: all_chromosomes.bedGraph.gz
    if [[ "$remove_allchr" == "1" ]]; then
        log "  OPT  all_chromosomes.bedGraph.gz: $outdir/bigwig/"
        while IFS= read -r f; do _rm "$f"; done < <(
            find "$outdir/bigwig" -maxdepth 1 -name "*.all_chromosomes.bedGraph.gz" 2>/dev/null || true
        )
    else
        log "  OPT  Keeping all_chromosomes.bedGraph.gz (CLEANUP_ALLCHR_BEDGRAPH=0)."
    fi

    log "STEP 22 — Cleanup complete."
}

# Invoke (off by default)
if [[ "${CLEANUP_INTERMEDIATES:-0}" == "1" ]]; then
    CURRENT_STAGE="cleanup"
    write_status running "removing receipt-protected regenerable intermediates"
    cleanup_intermediates "$OUTDIR"
else
    log "Post-run cleanup skipped (CLEANUP_INTERMEDIATES=0). Set to 1 in config to enable."
fi

CURRENT_STAGE="completed"
{
  printf 'workflow\trnaseq2tracks\n'
  printf 'version\t%s\n' "$VERSION"
  printf 'started_at\t%s\n' "$RUN_STARTED"
  printf 'completed_at\t%s\n' "$(date --iso-8601=seconds)"
  printf 'config\t%s\n' "$CONFIG"
  printf 'samplesheet\t%s\n' "$SAMPLESHEET"
  printf 'biological_samples\t%s\n' "$N_SAMPLES"
  printf 'technical_library_or_lane_rows\t%s\n' "$N_LANES"
  printf 'condition_contrasts\t%s\n' "$N_CONTRASTS"
  printf 'contrasts\t%s\n' "$CONTRASTS"
  printf 'layout\t%s\n' "$LIBRARY_LAYOUT"
  printf 'species\t%s\n' "$SPECIES"
  printf 'config_sha256\t%s\n' "$(sha256sum "$CONFIG" | awk '{print $1}')"
  printf 'samplesheet_sha256\t%s\n' "$(sha256sum "$SAMPLESHEET" | awk '{print $1}')"
} > "$OUTDIR/metadata/run_provenance.tsv"
write_status completed "all requested stages completed successfully"
log "rnaseq2tracks $VERSION COMPLETE biological_samples=$N_SAMPLES lane_rows=$N_LANES results=$OUTDIR"
RUN_FINALIZED=1
