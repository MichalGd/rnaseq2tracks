#!/usr/bin/env bash
# ORIGIN: NEW v3 / UPDATED v5 — adds enrichment R package checks
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == "--config" ]]; then
  [[ $# -ge 2 ]] || { echo "--config requires a file" >&2; exit 2; }
  CONFIG="$2"
elif [[ $# -gt 0 ]]; then
  CONFIG="$1"
else
  CONFIG="$REPO/config/config.conf"
fi
CONFIG="$(realpath "$CONFIG")"
CONFIG_DIR="$(dirname "$CONFIG")"
PASS=0; FAIL=0; WARN=0
ok()   { echo "  [PASS] $*"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN+1)); }
section() { echo ""; echo "── $* ─────────────────────────────────────"; }

section "1. Bash syntax"
while IFS= read -r -d '' f; do
  bash -n "$f" 2>/dev/null && ok "$(basename "$f")" || fail "$(basename "$f")"
done < <(find "$REPO/scripts" -name "*.sh" -print0)

section "2. R packages — core"
for pkg in DESeq2 apeglm ashr Rsamtools GenomicAlignments rtracklayer \
           GenomicFeatures GenomicRanges vsn pheatmap RColorBrewer \
           ggplot2 data.table optparse knitr kableExtra rmarkdown; do
  Rscript -e "library($pkg,quietly=TRUE)" 2>/dev/null && ok "R: $pkg" || fail "R: $pkg"
done

section "3. R packages — enrichment"
for pkg in clusterProfiler enrichplot ReactomePA fgsea msigdbr \
           org.Hs.eg.db org.Mm.eg.db; do
  Rscript -e "library($pkg,quietly=TRUE)" 2>/dev/null && ok "R: $pkg" || warn "R: $pkg not found (required for Step 21)"
done

section "4. Core tools"
for t in STAR samtools bedtools fastqc trim_galore multiqc Rscript; do
  command -v "$t" &>/dev/null && ok "$t" || warn "$t not found"
done

section "5. Kent utils"
[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null || true
[[ -x "${KENTUTILS_DIR:-}/bedGraphToBigWig" ]] \
  && ok "bedGraphToBigWig" || warn "bedGraphToBigWig not found"

section "6. RSeQC"
RSEQC_DIR="${RSEQC_BIN_DIR:-}"
for py in infer_experiment.py read_distribution.py geneBody_coverage.py \
          junction_annotation.py junction_saturation.py; do
  if [[ -n "$RSEQC_DIR" && -x "$RSEQC_DIR/$py" ]]; then ok "RSeQC: $py"
  elif command -v "$py" &>/dev/null; then ok "RSeQC: $py"
  else warn "RSeQC: $py not found"; fi
done

section "7. Config"
if [[ -f "$CONFIG" ]]; then
  for v in SPECIES LIBRARY_LAYOUT SAMPLESHEET OUTDIR RUN_RSEQC \
            REGULAR_CHROMS_ONLY CHROMOSOME_NAMING STRAND_TOLERANCE_PCT \
            PADJ_THRESHOLD LFC_THRESHOLD; do
    [[ -n "${!v:-}" ]] && ok "$v=${!v}" || warn "$v empty"
  done
  case "${SPECIES:-}" in
    human) for v in STAR_INDEX_HUMAN GTF_HUMAN CHROM_SIZES_HUMAN RSEQC_BED_HUMAN; do
      [[ -n "${!v:-}" ]] && ok "$v" || warn "$v empty"; done ;;
    mouse) for v in STAR_INDEX_MOUSE GTF_MOUSE CHROM_SIZES_MOUSE RSEQC_BED_MOUSE; do
      [[ -n "${!v:-}" ]] && ok "$v" || warn "$v empty"; done ;;
    *) warn "SPECIES not set" ;;
  esac
else warn "config.conf not found at $CONFIG"; fi

section "8. Samplesheet"
SS="${SAMPLESHEET:-$REPO/config/samplesheet.csv}"
[[ "$SS" == /* ]] || SS="$CONFIG_DIR/$SS"
if [[ -f "$SS" ]]; then
  N=$(grep -vc '^[[:space:]]*#\|^sample_id' "$SS" || true)
  ok "$N technical-library/lane rows in $SS"
  if "${PYTHON_BIN:-python}" "$REPO/scripts/prepare_samplesheet.py" \
      --samplesheet "$SS" --layout "${LIBRARY_LAYOUT:-PE}" \
      --check-fastq --validate-only; then
    ok "samplesheet hierarchy"
  else
    fail "samplesheet hierarchy"
  fi
else warn "Samplesheet not found: $SS"; fi

section "9. Contrasts"
CF="${CONTRASTS:-}"
[[ -n "$CF" && "$CF" != /* ]] && CF="$CONFIG_DIR/$CF"
if [[ -n "$CF" && -f "$CF" ]]; then
  NC=$(grep -vc '^[[:space:]]*#\|^contrast_id' "$CF" || true)
  ok "$NC explicit contrasts in $CF"
elif [[ -z "$CF" && -f "$SS" ]]; then
  NC=$("${PYTHON_BIN:-python}" - "$SS" <<'PY'
import csv
import sys
with open(sys.argv[1], encoding="utf-8-sig", newline="") as handle:
    rows = csv.DictReader(
        line for line in handle
        if line.strip() and not line.lstrip().startswith("#")
    )
    conditions = list(dict.fromkeys(row["condition"].strip() for row in rows))
print(len(conditions) * (len(conditions) - 1) // 2)
PY
  )
  ok "$NC automatic all-pairwise contrasts"
else
  fail "Configured contrasts file not found: $CF"
fi

echo ""; echo "════════════════════════════════════════"
echo "Smoke test: $PASS passed  $FAIL failed  $WARN warnings"
echo "════════════════════════════════════════"
[[ $FAIL -eq 0 ]] || { echo "Fix FAIL items before running."; exit 1; }
