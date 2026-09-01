from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
IMPORTER_PATH = ROOT / "scripts/config/import_config.py"
SPEC = importlib.util.spec_from_file_location("import_config", IMPORTER_PATH)
assert SPEC is not None and SPEC.loader is not None
import_config = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = import_config
SPEC.loader.exec_module(import_config)


def make_model(schema):
    sheets = {}
    for sheet in schema["sheets"]:
        sheets[sheet["name"]] = {
            "descriptions": [column["descriptionZh"] for column in sheet["columns"]],
            "keys": [column["key"] for column in sheet["columns"]],
            "rows": [],
            "formulas": set(),
        }

    sheets["ExampleGroups"]["rows"] = [
        {"row": 3, "values": ["Basic", "基础组"]},
        {"row": 4, "values": ["Advanced", "进阶组"]},
    ]
    sheets["ExampleItems"]["rows"] = [
        {
            "row": 3,
            "values": ["BasicItem", "基础示例", "Basic", "Common", 100, True, None],
        },
        {
            "row": 4,
            "values": [
                "AdvancedItem",
                "进阶示例",
                "Advanced",
                "Rare",
                500.5,
                False,
                "仅用于验证",
            ],
        },
    ]
    sheets["ServerSettings"]["rows"] = [
        {"row": 3, "values": ["RewardMultiplier", 1, True]},
        {"row": 4, "values": ["SpawnInterval", 5, True]},
    ]
    return {"sheetNames": list(sheets), "sheets": sheets}


class ImportConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads(
            (ROOT / "design/config-schema.json").read_text(encoding="utf-8")
        )
        import_config.validate_schema(cls.schema)

    def validate(self, model):
        return import_config.validate_workbook_model(model, self.schema)

    def test_valid_model_generates_shared_and_server_outputs(self):
        typed_rows, issues = self.validate(make_model(self.schema))
        self.assertEqual([], issues)

        outputs = import_config.build_outputs(self.schema, typed_rows)
        self.assertEqual(
            {"ExampleGroups.lua", "ExampleItems.lua"}, set(outputs["Shared"])
        )
        self.assertEqual({"ServerSettings.lua"}, set(outputs["Server"]))
        self.assertIn('GroupId = "Basic"', outputs["Shared"]["ExampleItems.lua"])

    def test_description_must_match_schema(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["descriptions"][0] = "错误说明"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_DESCRIPTION_MISMATCH", {issue.code for issue in issues})

    def test_formula_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["formulas"].add((3, 5))
        _, issues = self.validate(model)
        self.assertIn("CONFIG_FORMULA_NOT_ALLOWED", {issue.code for issue in issues})

    def test_duplicate_id_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][1]["values"][0] = "BasicItem"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_DUPLICATE_VALUE", {issue.code for issue in issues})

    def test_missing_required_value_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][1] = None
        _, issues = self.validate(model)
        self.assertIn("CONFIG_REQUIRED_MISSING", {issue.code for issue in issues})

    def test_wrong_type_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][5] = "yes"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_TYPE_INVALID", {issue.code for issue in issues})

    def test_excel_true_text_is_accepted(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][5] = "TRUE"
        typed_rows, issues = self.validate(model)
        self.assertEqual([], issues)
        self.assertIs(typed_rows["ExampleItems"][0]["Enabled"], True)

    def test_number_below_minimum_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][4] = -1
        _, issues = self.validate(model)
        self.assertIn("CONFIG_NUMBER_OUT_OF_RANGE", {issue.code for issue in issues})

    def test_unknown_enum_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][3] = "Unknown"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_ENUM_INVALID", {issue.code for issue in issues})

    def test_missing_reference_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][2] = "Missing"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_REFERENCE_NOT_FOUND", {issue.code for issue in issues})

    def test_unknown_sheet_is_rejected(self):
        model = make_model(self.schema)
        model["sheetNames"].append("UnknownSheet")
        model["sheets"]["UnknownSheet"] = {
            "descriptions": [],
            "keys": [],
            "rows": [],
            "formulas": set(),
        }
        _, issues = self.validate(model)
        self.assertIn("CONFIG_UNKNOWN_SHEET", {issue.code for issue in issues})

    def test_missing_sheet_is_rejected(self):
        model = make_model(self.schema)
        model["sheetNames"].remove("ServerSettings")
        del model["sheets"]["ServerSettings"]
        _, issues = self.validate(model)
        self.assertIn("CONFIG_SHEET_MISSING", {issue.code for issue in issues})

    def test_unknown_column_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleGroups"]["descriptions"].append("未知字段")
        model["sheets"]["ExampleGroups"]["keys"].append("Unknown")
        _, issues = self.validate(model)
        self.assertIn("CONFIG_UNKNOWN_COLUMN", {issue.code for issue in issues})

    def test_data_under_blank_unknown_column_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleGroups"]["descriptions"].append(None)
        model["sheets"]["ExampleGroups"]["keys"].append(None)
        model["sheets"]["ExampleGroups"]["rows"][0]["values"].append("unexpected")
        _, issues = self.validate(model)
        self.assertIn("CONFIG_UNKNOWN_COLUMN", {issue.code for issue in issues})

    def test_number_limit_on_string_is_invalid_schema(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"][0]["columns"][0]["min"] = 0
        with self.assertRaises(import_config.ConfigFailure) as context:
            import_config.validate_schema(schema)
        self.assertIn(
            "CONFIG_SCHEMA_INVALID", {issue.code for issue in context.exception.issues}
        )

    def test_real_workbook_matches_schema(self):
        model = import_config.read_workbook_model(ROOT / "design/GameConfig.xlsx", 3)
        _, issues = self.validate(model)
        self.assertEqual([], issues)

    def test_generation_is_deterministic(self):
        typed_rows, issues = self.validate(make_model(self.schema))
        self.assertEqual([], issues)
        first = import_config.build_outputs(self.schema, typed_rows)
        second = import_config.build_outputs(self.schema, copy.deepcopy(typed_rows))
        self.assertEqual(first, second)

    def test_atomic_write_matches_check_mode(self):
        typed_rows, issues = self.validate(make_model(self.schema))
        self.assertEqual([], issues)
        outputs = import_config.build_outputs(self.schema, typed_rows)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            import_config.write_outputs_atomic(root, outputs)
            self.assertEqual([], import_config.check_outputs(root, outputs))

            shared = import_config.output_targets(root)["Shared"] / "ExampleItems.lua"
            shared.write_text("outdated", encoding="utf-8")
            self.assertIn(
                "CONFIG_OUTPUT_OUTDATED",
                {issue.code for issue in import_config.check_outputs(root, outputs)},
            )

    def test_validation_failure_keeps_previous_outputs(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][1]["values"][0] = "BasicItem"

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            schema_path = root / "config-schema.json"
            schema_path.write_text(json.dumps(self.schema), encoding="utf-8")
            targets = import_config.output_targets(root)
            for target in targets.values():
                target.mkdir(parents=True)
                (target / "Previous.lua").write_text("previous", encoding="utf-8")

            args = SimpleNamespace(
                repo_root=str(root),
                workbook=str(root / "Invalid.xlsx"),
                schema=str(schema_path),
                check=False,
            )
            with mock.patch.object(import_config, "read_workbook_model", return_value=model):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(1, import_config.run(args))

            for target in targets.values():
                self.assertEqual("previous", (target / "Previous.lua").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
