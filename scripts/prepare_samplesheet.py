#!/usr/bin/env python3
"""Validate lane-level metadata and derive one analysis row per biological sample."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import OrderedDict
from itertools import combinations
from pathlib import Path


ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
COMMON_REQUIRED = {
    "sample_id",
    "biological_replicate_id",
    "technical_replicate_id",
    "lane_id",
    "fastq_R1",
    "condition",
    "strandedness",
}
CONSISTENT_FIELDS = (
    "biological_replicate_id",
    "condition",
    "batch",
    "description",
    "strandedness",
)


class SamplesheetError(ValueError):
    """Raised for an invalid samplesheet contract."""


def _rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        lines = [line for line in handle if line.strip() and not line.lstrip().startswith("#")]
    if not lines:
        raise SamplesheetError("samplesheet has no header or data rows")
    reader = csv.DictReader(lines)
    if reader.fieldnames is None:
        raise SamplesheetError("samplesheet header is missing")
    fields = [field.strip() for field in reader.fieldnames]
    if len(fields) != len(set(fields)):
        raise SamplesheetError("samplesheet contains duplicate column names")
    result: list[dict[str, str]] = []
    for number, raw in enumerate(reader, start=2):
        row = {(key or "").strip(): (value or "").strip() for key, value in raw.items()}
        row["_row_number"] = str(number)
        result.append(row)
    if not result:
        raise SamplesheetError("samplesheet has no data rows")
    return fields, result


def _path(value: str, base: Path) -> str:
    candidate = Path(value).expanduser()
    if not candidate.is_absolute():
        candidate = base / candidate
    return str(candidate.resolve(strict=False))


def validate(path: Path, layout: str, check_fastq: bool) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    fields, rows = _rows(path)
    required = set(COMMON_REQUIRED)
    if layout == "PE":
        required.add("fastq_R2")
    missing = sorted(required.difference(fields))
    if missing:
        raise SamplesheetError("missing required columns: " + ", ".join(missing))

    lane_keys: set[tuple[str, str, str]] = set()
    library_ids: set[str] = set()
    fastqs: dict[str, str] = {}
    samples: OrderedDict[str, dict[str, str]] = OrderedDict()
    lanes: list[dict[str, str]] = []

    for row in rows:
        number = row.pop("_row_number")
        for field in required:
            if not row.get(field, ""):
                raise SamplesheetError(f"row {number}: {field} is empty")
        for field in ("sample_id", "biological_replicate_id", "technical_replicate_id", "lane_id"):
            if not ID_RE.fullmatch(row[field]):
                raise SamplesheetError(
                    f"row {number}: {field} must use only letters, numbers, '.', '_' or '-'"
                )
        if row["strandedness"] not in {"unstranded", "forward", "reverse"}:
            raise SamplesheetError(
                f"row {number}: strandedness must be unstranded, forward or reverse"
            )
        key = (row["sample_id"], row["technical_replicate_id"], row["lane_id"])
        if key in lane_keys:
            raise SamplesheetError(
                f"row {number}: duplicate sample/technical-replicate/lane combination: {key}"
            )
        lane_keys.add(key)
        library_id = "__".join(key)
        if library_id in library_ids:
            raise SamplesheetError(f"row {number}: derived library_id collision: {library_id}")
        library_ids.add(library_id)

        for mate in ("fastq_R1", "fastq_R2"):
            if mate == "fastq_R2" and layout == "SE":
                row[mate] = ""
                continue
            resolved = _path(row[mate], path.parent)
            previous = fastqs.get(resolved)
            if previous is not None:
                raise SamplesheetError(
                    f"row {number}: {mate} is assigned more than once ({previous} and {library_id})"
                )
            fastqs[resolved] = library_id
            if check_fastq and not Path(resolved).is_file():
                raise SamplesheetError(f"row {number}: FASTQ does not exist: {resolved}")
            row[mate] = resolved

        row.setdefault("batch", "")
        row.setdefault("description", "")
        row["library_id"] = library_id
        lanes.append(row)

        sample_id = row["sample_id"]
        if sample_id not in samples:
            samples[sample_id] = {field: row.get(field, "") for field in CONSISTENT_FIELDS}
            samples[sample_id]["sample_id"] = sample_id
        else:
            for field in CONSISTENT_FIELDS:
                if samples[sample_id][field] != row.get(field, ""):
                    raise SamplesheetError(
                        f"row {number}: {field} differs among technical rows for sample {sample_id}"
                    )

    sample_rows: list[dict[str, str]] = []
    for sample_id, sample in samples.items():
        members = [row for row in lanes if row["sample_id"] == sample_id]
        sample["technical_replicate_count"] = str(len({row["technical_replicate_id"] for row in members}))
        sample["lane_count"] = str(len(members))
        sample_rows.append(sample)
    return lanes, sample_rows


def write_outputs(output_dir: Path, layout: str, lanes: list[dict[str, str]], samples: list[dict[str, str]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    lane_fields = [
        "library_id", "sample_id", "biological_replicate_id", "technical_replicate_id",
        "lane_id", "fastq_R1", "fastq_R2", "condition", "batch", "description", "strandedness",
    ]
    with (output_dir / "validated_lanes.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=lane_fields, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(lanes)

    sample_fields = [
        "sample_id", "biological_replicate_id", "condition", "batch", "description",
        "strandedness", "technical_replicate_count", "lane_count",
    ]
    with (output_dir / "validated_samples.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=sample_fields, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(samples)

    analysis_fields = (
        ["sample_id", "fastq_R1", "fastq_R2", "condition", "replicate",
         "biological_replicate_id", "batch", "description", "strandedness"]
        if layout == "PE"
        else ["sample_id", "fastq_R1", "condition", "replicate",
              "biological_replicate_id", "batch", "description", "strandedness"]
    )
    with (output_dir / "analysis_samplesheet.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=analysis_fields)
        writer.writeheader()
        for sample in samples:
            record = {
                "sample_id": sample["sample_id"],
                "fastq_R1": "",
                "fastq_R2": "",
                "condition": sample["condition"],
                "replicate": sample["biological_replicate_id"],
                "biological_replicate_id": sample["biological_replicate_id"],
                "batch": sample["batch"],
                "description": sample["description"],
                "strandedness": sample["strandedness"],
            }
            writer.writerow({field: record[field] for field in analysis_fields})

    conditions = list(OrderedDict.fromkeys(sample["condition"] for sample in samples))
    contrast_rows: list[dict[str, str]] = []
    used_ids: set[str] = set()
    for denominator, numerator in combinations(conditions, 2):
        base = f"{_slug(numerator)}_vs_{_slug(denominator)}"
        contrast_id = base
        suffix = 2
        while contrast_id in used_ids:
            contrast_id = f"{base}_{suffix}"
            suffix += 1
        used_ids.add(contrast_id)
        contrast_rows.append({
            "contrast_id": contrast_id,
            "numerator": numerator,
            "denominator": denominator,
        })
    with (output_dir / "pairwise_contrasts.csv").open(
        "w", encoding="utf-8", newline=""
    ) as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["contrast_id", "numerator", "denominator"]
        )
        writer.writeheader()
        writer.writerows(contrast_rows)


def _slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip()).strip("._-")
    return slug or "condition"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samplesheet", required=True, type=Path)
    parser.add_argument("--layout", required=True, choices=("SE", "PE"))
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--check-fastq", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    try:
        lanes, samples = validate(args.samplesheet.resolve(), args.layout, args.check_fastq)
        contrast_count = len({sample["condition"] for sample in samples})
        contrast_count = contrast_count * (contrast_count - 1) // 2
        if not args.validate_only:
            if args.output_dir is None:
                parser.error("--output-dir is required unless --validate-only is used")
            write_outputs(args.output_dir, args.layout, lanes, samples)
        print(json.dumps({
            "status": "valid",
            "biological_samples": len(samples),
            "technical_libraries_or_lanes": len(lanes),
            "pairwise_contrasts": contrast_count,
            "layout": args.layout,
        }))
        return 0
    except SamplesheetError as exc:
        parser.exit(2, f"ERROR: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
