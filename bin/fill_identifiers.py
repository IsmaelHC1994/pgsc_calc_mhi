#!/usr/bin/env python3
"""
fill_identifiers.py — Batch-fill patient identifiers in generated reports.

Reads a CSV that maps sample IDs to identifier values, then does
find-and-replace in the matching DOCX and/or HTML report files.

Usage:
    python fill_identifiers.py --csv identifiers.csv --reports-dir ./regenerated_reports

CSV format (minimum columns):
    sample_id,identifier1,identifier2
    24-1979,557553,24-1979
    24-1901,632870,24-1901

The script searches reports-dir for files named patient_<sample_id>_report.docx
and patient_<sample_id>_report.html, then replaces every occurrence of the
placeholder text with the real values.

By default the placeholders are "Identifier1" and "Identifier2" (matching the
Quarto template defaults). Override with --placeholder1 / --placeholder2.

Requirements: Python 3.6+, no external packages.
"""

import argparse
import csv
import os
import re
import shutil
import sys
import tempfile
import zipfile


def replace_in_html(filepath, replacements):
    """Simple text replacement in an HTML file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    changed = False
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            changed = True
    if changed:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
    return changed


def replace_in_docx(filepath, replacements):
    """
    Replace text inside a DOCX file (which is a ZIP of XML files).
    Works on Pandoc/Quarto-generated DOCX where placeholder text is not split
    across XML runs.
    """
    tmp_dir = tempfile.mkdtemp()
    try:
        # Extract
        with zipfile.ZipFile(filepath, "r") as zin:
            zin.extractall(tmp_dir)

        changed = False
        # Walk all XML files inside the docx
        for root, _dirs, files in os.walk(tmp_dir):
            for fname in files:
                if not fname.endswith(".xml") and not fname.endswith(".rels"):
                    continue
                fpath = os.path.join(root, fname)
                with open(fpath, "r", encoding="utf-8") as f:
                    xml = f.read()
                modified = False
                for old, new in replacements:
                    if old in xml:
                        xml = xml.replace(old, new)
                        modified = True
                if modified:
                    with open(fpath, "w", encoding="utf-8") as f:
                        f.write(xml)
                    changed = True

        if changed:
            # Re-pack into a new DOCX (preserve compression)
            tmp_docx = filepath + ".tmp"
            with zipfile.ZipFile(tmp_docx, "w", zipfile.ZIP_DEFLATED) as zout:
                for root, _dirs, files in os.walk(tmp_dir):
                    for fname in files:
                        abs_path = os.path.join(root, fname)
                        arc_name = os.path.relpath(abs_path, tmp_dir)
                        zout.write(abs_path, arc_name)
            shutil.move(tmp_docx, filepath)

        return changed
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def find_report_files(reports_dir, sample_id):
    """Recursively find report files matching the sample_id pattern."""
    pattern = f"patient_{sample_id}_report"
    matches = []
    for root, _dirs, files in os.walk(reports_dir):
        for f in files:
            if f.startswith(pattern) and (f.endswith(".docx") or f.endswith(".html")):
                matches.append(os.path.join(root, f))
    return matches


def main():
    parser = argparse.ArgumentParser(
        description="Batch-fill patient identifiers in generated DOCX/HTML reports."
    )
    parser.add_argument(
        "--csv", required=True,
        help="CSV file with columns: sample_id, identifier1, identifier2"
    )
    parser.add_argument(
        "--reports-dir", required=True,
        help="Root directory containing the generated report files"
    )
    parser.add_argument(
        "--placeholder1", default="Identifier1",
        help="Placeholder text to replace for ID-1 (default: Identifier1)"
    )
    parser.add_argument(
        "--placeholder2", default="Identifier2",
        help="Placeholder text to replace for ID-2 (default: Identifier2)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be changed without modifying files"
    )
    args = parser.parse_args()

    if not os.path.isfile(args.csv):
        print(f"Error: CSV file not found: {args.csv}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isdir(args.reports_dir):
        print(f"Error: Reports directory not found: {args.reports_dir}", file=sys.stderr)
        sys.exit(1)

    # Read CSV
    rows = []
    with open(args.csv, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        # Normalize column names (strip whitespace, lowercase for matching)
        fieldnames = [c.strip() for c in reader.fieldnames]
        reader.fieldnames = fieldnames

        # Check required columns exist
        required = {"sample_id", "identifier1", "identifier2"}
        available = {c.lower() for c in fieldnames}
        missing = required - available
        if missing:
            print(f"Error: CSV is missing required columns: {missing}", file=sys.stderr)
            print(f"Available columns: {fieldnames}", file=sys.stderr)
            print(f"\nExpected CSV format:", file=sys.stderr)
            print(f"  sample_id,identifier1,identifier2", file=sys.stderr)
            print(f"  24-1979,557553,24-1979", file=sys.stderr)
            sys.exit(1)

        # Build a case-insensitive column name map
        col_map = {c.lower(): c for c in fieldnames}
        for row in reader:
            sample_id = row[col_map["sample_id"]].strip()
            id1 = row[col_map["identifier1"]].strip()
            id2 = row[col_map["identifier2"]].strip()
            if sample_id:
                rows.append((sample_id, id1, id2))

    print(f"Loaded {len(rows)} rows from {args.csv}")
    print(f"Searching for reports in: {args.reports_dir}")
    print(f"Placeholders: '{args.placeholder1}' → identifier1,  '{args.placeholder2}' → identifier2")
    print()

    updated = 0
    not_found = 0
    skipped = 0

    for sample_id, id1, id2 in rows:
        files = find_report_files(args.reports_dir, sample_id)
        if not files:
            print(f"  ⚠  No reports found for sample {sample_id}")
            not_found += 1
            continue

        replacements = [
            (args.placeholder1, id1),
            (args.placeholder2, id2),
        ]

        for fpath in files:
            relpath = os.path.relpath(fpath, args.reports_dir)
            if args.dry_run:
                print(f"  [dry-run] Would update: {relpath}  ({args.placeholder1}→{id1}, {args.placeholder2}→{id2})")
                updated += 1
                continue

            if fpath.endswith(".html"):
                ok = replace_in_html(fpath, replacements)
            elif fpath.endswith(".docx"):
                ok = replace_in_docx(fpath, replacements)
            else:
                continue

            if ok:
                print(f"  ✓ Updated: {relpath}")
                updated += 1
            else:
                print(f"  – Skipped (placeholders not found): {relpath}")
                skipped += 1

    print()
    print(f"Done. Updated: {updated}, Not found: {not_found}, Skipped: {skipped}")


if __name__ == "__main__":
    main()
