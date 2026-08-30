#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: install_release.sh --tag TAG [--repo URL] [--env-parent DIR] [--bin-dir DIR] [--mamba EXE] [--no-promote]"
}

TAG=""
REPO="https://github.com/MichalGd/rnaseq2tracks.git"
ENV_PARENT="/opt/conda_envs"
BIN_DIR="/opt/conda_envs/bin"
MAMBA="/opt/miniconda/condabin/mamba"
PROMOTE=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --env-parent) ENV_PARENT="$2"; shift 2 ;;
    --bin-dir) BIN_DIR="$2"; shift 2 ;;
    --mamba) MAMBA="$2"; shift 2 ;;
    --no-promote) PROMOTE=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$TAG" ]] || { echo "--tag is required" >&2; exit 2; }
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-alpha\.[0-9]+([.]post[0-9]+)?)?$ ]] || {
  echo "Unexpected release tag: $TAG" >&2; exit 2;
}
[[ -x "$MAMBA" ]] || { echo "Mamba is not executable: $MAMBA" >&2; exit 2; }
[[ -d "$ENV_PARENT" && -w "$ENV_PARENT" ]] || {
  echo "Environment parent is not writable: $ENV_PARENT" >&2; exit 2;
}
mkdir -p "$BIN_DIR"
[[ -w "$BIN_DIR" ]] || { echo "Launcher directory is not writable: $BIN_DIR" >&2; exit 2; }

VERSION="${TAG#v}"
ENV_TOKEN="${VERSION/-alpha./a}"
ENV_PREFIX="$ENV_PARENT/rnaseq2tracks-$ENV_TOKEN"
VERSIONED_LAUNCHER="$BIN_DIR/rnaseq2tracks-$VERSION"
STABLE_LAUNCHER="$BIN_DIR/rnaseq2tracks"
[[ ! -e "$ENV_PREFIX" ]] || { echo "Versioned environment already exists: $ENV_PREFIX" >&2; exit 2; }
[[ ! -e "$VERSIONED_LAUNCHER" ]] || { echo "Versioned launcher already exists: $VERSIONED_LAUNCHER" >&2; exit 2; }

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/rnaseq2tracks_install.XXXXXX")"
trap 'rm -rf -- "$STAGING"' EXIT
git clone --quiet --branch "$TAG" --depth 1 "$REPO" "$STAGING/repository"
cd "$STAGING/repository"
[[ "$(cat VERSION)" == "$VERSION" ]] || { echo "Tag/VERSION mismatch" >&2; exit 2; }
COMMIT="$(git rev-parse HEAD)"

AUDIT="$ENV_PARENT/rnaseq2tracks-deployments/$TAG"
mkdir -p "$AUDIT"
cp environment.yml "$AUDIT/environment.yml"
printf 'release=%s\ncommit=%s\nenvironment=%s\n' "$TAG" "$COMMIT" "$ENV_PREFIX" \
  > "$AUDIT/deployment.txt"

export MAMBA_ROOT_PREFIX="$ENV_PARENT/.mamba-rnaseq2tracks"
mkdir -p "$MAMBA_ROOT_PREFIX"
nice -n 10 "$MAMBA" --no-rc env create --prefix "$ENV_PREFIX" --file environment.yml \
  2>&1 | tee "$AUDIT/mamba-create.log"

WORKFLOW_ROOT="$ENV_PREFIX/share/rnaseq2tracks"
mkdir -p "$WORKFLOW_ROOT"
cp -a README.md CHANGELOG.md CITATION.cff LICENSE VERSION environment.yml \
  bin config docs examples scripts tests "$WORKFLOW_ROOT/"
chmod 755 "$WORKFLOW_ROOT/bin/rnaseq2tracks" \
  "$WORKFLOW_ROOT/scripts/rnaseq2tracks.sh" \
  "$WORKFLOW_ROOT/scripts/preflight_check.sh"
find "$WORKFLOW_ROOT/scripts" -type f -name '*.sh' -exec chmod 755 {} +

"$MAMBA" run -p "$ENV_PREFIX" python -m unittest discover -s "$WORKFLOW_ROOT/tests" -v \
  2>&1 | tee "$AUDIT/python-tests.log"
bash "$WORKFLOW_ROOT/tests/check_bash_syntax.sh" \
  2>&1 | tee "$AUDIT/bash-syntax.log"
"$MAMBA" run -p "$ENV_PREFIX" Rscript -e \
  'files <- list.files(commandArgs(TRUE)[1], pattern="[.]R$", full.names=TRUE); stopifnot(length(files) >= 5L); invisible(lapply(files, parse))' \
  "$WORKFLOW_ROOT/scripts/Rscripts" \
  2>&1 | tee "$AUDIT/r-parse.log"

cat > "$VERSIONED_LAUNCHER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ENV_PREFIX="$ENV_PREFIX"
WORKFLOW_ROOT="$WORKFLOW_ROOT"
unset PYTHONHOME PYTHONPATH R_HOME R_LIBS R_LIBS_USER
export PATH="\$ENV_PREFIX/bin:\${PATH:-/usr/bin:/bin}"
exec "\$WORKFLOW_ROOT/bin/rnaseq2tracks" "\$@"
EOF
chmod 755 "$VERSIONED_LAUNCHER"

"$VERSIONED_LAUNCHER" --version
"$MAMBA" list -p "$ENV_PREFIX" --explicit > "$AUDIT/environment-linux-64.explicit.txt"
chmod -R a+rX "$ENV_PREFIX" "$AUDIT"
chmod -R a-w "$ENV_PREFIX"
if find "$ENV_PREFIX" ! -type l -perm /222 -print -quit | grep -q .; then
  echo "Writable content remains in versioned environment" >&2
  exit 2
fi

if $PROMOTE; then
  temporary="$BIN_DIR/.rnaseq2tracks.promote.$$"
  ln -s "$VERSIONED_LAUNCHER" "$temporary"
  mv -Tf "$temporary" "$STABLE_LAUNCHER"
fi
printf 'installed_at=%s\npromoted=%s\n' "$(date --iso-8601=seconds)" "$PROMOTE" \
  >> "$AUDIT/deployment.txt"
echo "Installed $TAG at $ENV_PREFIX"
echo "Versioned launcher: $VERSIONED_LAUNCHER"
$PROMOTE && echo "Stable launcher: $STABLE_LAUNCHER"
