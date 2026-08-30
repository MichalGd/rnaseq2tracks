#!/usr/bin/env python3
"""Sum lane-level STAR ReadsPerGene tables into one table per biological sample."""

from __future__ import annotations

import argparse
import csv
from collections import OrderedDict
from pathlib import Path


def read_counts(path: Path) -> tuple[list[str], list[list[int]]]:
    genes: list[str] = []
    values: list[list[int]] = []
    with path.open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 4:
                raise ValueError(f"{path}:{number}: expected four STAR count columns")
            genes.append(fields[0])
            values.append([int(value) for value in fields[1:]])
    return genes, values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lanes", required=True, type=Path)
    parser.add_argument("--count-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    groups: OrderedDict[str, list[str]] = OrderedDict()
    with args.lanes.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            groups.setdefault(row["sample_id"], []).append(row["library_id"])
    args.output_dir.mkdir(parents=True, exist_ok=True)

    for sample_id, library_ids in groups.items():
        expected_genes: list[str] | None = None
        totals: list[list[int]] | None = None
        for library_id in library_ids:
            source = args.count_dir / f"{library_id}_ReadsPerGene.out.tab"
            if not source.is_file():
                raise FileNotFoundError(f"lane-level STAR count table is missing: {source}")
            genes, values = read_counts(source)
            if expected_genes is None:
                expected_genes = genes
                totals = values
            elif genes != expected_genes:
                raise ValueError(f"STAR gene ordering differs for library {library_id}")
            else:
                assert totals is not None
                for index, row in enumerate(values):
                    totals[index] = [a + b for a, b in zip(totals[index], row)]
        assert expected_genes is not None and totals is not None
        target = args.output_dir / f"{sample_id}_ReadsPerGene.out.tab"
        with target.open("w", encoding="utf-8", newline="") as handle:
            for gene, row in zip(expected_genes, totals):
                handle.write("\t".join([gene, *(str(value) for value in row)]) + "\n")
        print(f"Merged {len(library_ids)} lane count table(s) -> {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
