#!/usr/bin/env python3
"""Print the rows of an .xlsx file that match a regular expression.

Made for creator tracking lists (backer number -> tracking number) exported
from Google Sheets. Uses only the standard library, so it can be run with
`python3 -I` on a downloaded, untrusted file.

Usage:
    xlsx_grep.py FILE PATTERN [--column N]

Without --column the pattern is searched in the whole row; with it, only in
that zero-based column. Numeric cells come back as floats ("123.0"), so match
a backer number with '^123(\\.0)?$' on its column.
"""
import argparse
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"


def shared_strings(archive):
    """Return the workbook's shared string table (empty if it has none)."""
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return ["".join(t.text or "" for t in item.iter(NS + "t")) for item in root.findall(NS + "si")]


def cell_value(cell, strings):
    """Resolve one cell to text, following shared and inline strings."""
    kind = cell.get("t")
    if kind == "inlineStr":
        return "".join(t.text or "" for t in cell.iter(NS + "t"))
    node = cell.find(NS + "v")
    value = "" if node is None else node.text or ""
    if kind == "s" and value:
        return strings[int(value)]
    return value


def sheet_rows(archive, name, strings):
    """Yield (row number, list of cell texts) for one worksheet."""
    root = ET.fromstring(archive.read(name))
    for row in root.iter(NS + "row"):
        yield row.get("r"), [cell_value(c, strings) for c in row.findall(NS + "c")]


def matches(cells, pattern, column):
    """True if the pattern is found in the chosen column or anywhere in the row."""
    if column is None:
        return bool(pattern.search(" ".join(cells)))
    return column < len(cells) and bool(pattern.search(cells[column]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("pattern")
    parser.add_argument("--column", type=int, help="zero-based column to match against")
    args = parser.parse_args()
    try:
        archive = zipfile.ZipFile(args.file)
    except (OSError, zipfile.BadZipFile) as err:
        sys.exit("cannot open %s as xlsx: %s" % (args.file, err))
    pattern = re.compile(args.pattern, re.I)
    strings = shared_strings(archive)
    sheets = sorted(n for n in archive.namelist() if n.startswith("xl/worksheets/sheet"))
    found = 0
    for name in sheets:
        rows = list(sheet_rows(archive, name, strings))
        print("== %s: %d rows; header: %s" % (name, len(rows), rows[0][1] if rows else []))
        for number, cells in rows:
            if matches(cells, pattern, args.column):
                found += 1
                print("  row %s: %s" % (number, cells))
    print("%d matching rows" % found)


if __name__ == "__main__":
    main()
