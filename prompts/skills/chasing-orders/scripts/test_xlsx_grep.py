#!/usr/bin/env python3
"""Regression tests using generated XLSX archives, never personal workbooks.

Run with: python3 -B -I -m unittest discover -s prompts/skills/chasing-orders/scripts -p 'test_xlsx_grep.py'
"""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


SCRIPT = Path(__file__).with_name("xlsx_grep.py")
SPEC = importlib.util.spec_from_file_location("xlsx_grep", SCRIPT)
xlsx_grep = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(xlsx_grep)

SHEET = """<?xml version="1.0"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1"><v>123.0</v></c>
      <c r="C1" t="inlineStr"><is><t>shipment</t></is></c>
    </row>
    <row r="7">
      <c r="A7"><v>123</v></c>
      <c r="C7" t="inlineStr"><is><t>tracking</t></is></c>
    </row>
    <row r="9"><c r="C9" t="s"><v>1</v></c></row>
    <row r="12">
      <c r="AA12" t="inlineStr"><is><t>far</t></is></c>
      <c r="AAA12" t="inlineStr"><is><t>distant</t></is></c>
    </row>
    <row r="13"><c r="A13"/><c r="C13" t="inlineStr"><is><t/></is></c></row>
    <row r="14"><c><v>456</v></c><c t="inlineStr"><is><t>sequential</t></is></c></row>
  </sheetData>
</worksheet>
"""
STRINGS = """<?xml version="1.0"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><r><t>backer</t></r><r><t> number</t></r></si>
  <si><t>leading</t></si>
</sst>
"""


class XlsxGrepTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.workbook = Path(self.temp.name) / "tracking.xlsx"
        with zipfile.ZipFile(self.workbook, "w") as archive:
            archive.writestr("xl/worksheets/sheet1.xml", SHEET)
            archive.writestr("xl/sharedStrings.xml", STRINGS)

    def run_cli(self, pattern, *args):
        return subprocess.run(
            [sys.executable, "-I", str(SCRIPT), str(self.workbook), pattern, *args],
            capture_output=True, text=True, check=False,
        )

    def test_rows_keep_positions_values_and_row_numbers(self):
        with zipfile.ZipFile(self.workbook) as archive:
            rows = list(xlsx_grep.sheet_rows(
                archive, "xl/worksheets/sheet1.xml", xlsx_grep.shared_strings(archive),
            ))
        self.assertEqual(rows[:3], [
            ("1", ["backer number", "123.0", "shipment"]),
            ("7", ["123", "", "tracking"]),
            ("9", ["", "", "leading"]),
        ])
        self.assertEqual(rows[3], ("12", [""] * 26 + ["far"] + [""] * 675 + ["distant"]))
        self.assertEqual(rows[4:], [
            ("13", ["", "", ""]),
            ("14", ["456", "sequential"]),
        ])

    def test_sparse_column_cli_matches_c_but_not_b(self):
        result = self.run_cli("^tracking$", "--column", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         "== xl/worksheets/sheet1.xml: 6 rows; header: ['backer number', '123.0', 'shipment']\n"
                         "  row 7: ['123', '', 'tracking']\n1 matching rows\n")
        result = self.run_cli("^tracking$", "--column", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith("0 matching rows\n"))

    def test_normal_leading_and_multiple_letter_columns(self):
        for pattern, column, row in [
            ("^123\\.0$", 1, 1), ("^leading$", 2, 9),
            ("^far$", 26, 12), ("^distant$", 702, 12),
        ]:
            with self.subTest(column=column):
                result = self.run_cli(pattern, "--column", str(column))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("  row %s:" % row, result.stdout)
                self.assertTrue(result.stdout.endswith("1 matching rows\n"))

    def test_whole_row_search_still_matches_case_insensitively(self):
        result = self.run_cli("TRACKING")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("  row 7: ['123', '', 'tracking']\n", result.stdout)
        self.assertTrue(result.stdout.endswith("1 matching rows\n"))

    def test_blank_and_out_of_range_columns(self):
        result = self.run_cli("^$", "--column", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("  row 7: ['123', '', 'tracking']\n", result.stdout)
        self.assertIn("  row 9: ['', '', 'leading']\n", result.stdout)
        self.assertIn("  row 13: ['', '', '']\n", result.stdout)
        self.assertTrue(result.stdout.endswith("4 matching rows\n"))
        result = self.run_cli("^$", "--column", "703")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.endswith("0 matching rows\n"))

    def test_cli_rejects_negative_and_nonsensical_columns(self):
        for column in ["-1", "C", "1.5"]:
            with self.subTest(column=column):
                result = self.run_cli(".*", "--column", column)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
                self.assertIn("column must be a non-negative integer", result.stderr)

    def test_worksheet_without_shared_string_table(self):
        with zipfile.ZipFile(self.workbook, "w") as archive:
            archive.writestr("xl/worksheets/sheet1.xml", SHEET.replace('t="s"', 't="n"'))
        result = self.run_cli("^tracking$", "--column", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("  row 7: ['123', '', 'tracking']\n", result.stdout)

    def test_cell_columns_are_bounded_by_the_xlsx_format(self):
        # A malformed reference must not cause an arbitrarily large row allocation.
        for reference in ["XFD1", "XFE1", "ZZZZZZZZ1"]:
            with self.subTest(reference=reference):
                sheet = '<worksheet xmlns="%s"><sheetData><row r="1"><c r="%s"><v>1</v></c></row></sheetData></worksheet>' % (
                    xlsx_grep.NS[1:-1], reference,
                )
                with zipfile.ZipFile(self.workbook, "w") as archive:
                    archive.writestr("xl/worksheets/sheet1.xml", sheet)
                with zipfile.ZipFile(self.workbook) as archive:
                    if reference == "XFD1":
                        rows = list(xlsx_grep.sheet_rows(archive, "xl/worksheets/sheet1.xml", []))
                        self.assertEqual(rows, [("1", [""] * 16_383 + ["1"])])
                    else:
                        with self.assertRaisesRegex(ValueError, "cell column outside XLSX range"):
                            list(xlsx_grep.sheet_rows(archive, "xl/worksheets/sheet1.xml", []))

    def test_malformed_cell_references_are_rejected(self):
        for reference in ["1A", "A0", "A-1"]:
            with self.subTest(reference=reference):
                sheet = '<worksheet xmlns="%s"><sheetData><row r="1"><c r="%s"><v>1</v></c></row></sheetData></worksheet>' % (
                    xlsx_grep.NS[1:-1], reference,
                )
                with zipfile.ZipFile(self.workbook, "w") as archive:
                    archive.writestr("xl/worksheets/sheet1.xml", sheet)
                with zipfile.ZipFile(self.workbook) as archive:
                    with self.assertRaisesRegex(ValueError, "invalid cell reference"):
                        list(xlsx_grep.sheet_rows(archive, "xl/worksheets/sheet1.xml", []))


if __name__ == "__main__":
    unittest.main()
