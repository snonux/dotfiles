#!/usr/bin/env python3
"""Print the rows of an .xlsx file that match a regular expression.

Made for creator tracking lists (backer number -> tracking number) exported
from Google Sheets. Uses only the standard library, so it can be run with
`python3 -I` on a downloaded, untrusted file.

Usage:
    xlsx_grep.py FILE PATTERN [--column N]

Without --column the pattern is searched in the whole row; with it, only in
that non-negative, zero-based column (A=0, B=1, AA=26). Missing cells retain
their column positions as empty strings. Numeric cells retain their stored
text ("123" or "123.0"), so match a backer number with '^123(\\.0)?$'.
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
        cells = []
        next_column = 0
        for cell in row.findall(NS + "c"):
            reference = cell.get("r")
            column = cell_column(reference) if reference else next_column
            if column >= len(cells):
                cells.extend([""] * (column + 1 - len(cells)))
            cells[column] = cell_value(cell, strings)
            next_column = column + 1
        yield row.get("r"), cells


def cell_column(reference):
    """Return the zero-based column of an Excel cell reference such as AA12."""
    match = re.fullmatch(r"([A-Z]+)[1-9][0-9]*", reference)
    if match is None:
        raise ValueError("invalid cell reference: %s" % reference)
    column = 0
    for letter in match.group(1):
        column = column * 26 + ord(letter) - ord("A") + 1
        if column > 16_384:
            raise ValueError("cell column outside XLSX range: %s" % reference)
    return column - 1


def matches(cells, pattern, column):
    """True if the pattern is found in the chosen column or anywhere in the row."""
    if column is None:
        return bool(pattern.search(" ".join(cells)))
    return 0 <= column < len(cells) and bool(pattern.search(cells[column]))


def non_negative_column(value):
    """Parse a column argument without allowing Python's negative indexing."""
    try:
        column = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError("column must be a non-negative integer") from None
    if column < 0:
        raise argparse.ArgumentTypeError("column must be a non-negative integer")
    return column


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("pattern")
    parser.add_argument(
        "--column", type=non_negative_column,
        help="non-negative, zero-based column to match against (A=0, AA=26)",
    )
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
