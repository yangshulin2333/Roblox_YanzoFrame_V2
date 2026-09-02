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
            "types": [column["type"] for column in sheet["columns"]],
            "rows": [],
            "formulas": set(),
            "workbook": sheet["workbook"],
        }

    sheets["ExampleGroups"]["rows"] = [
        {"row": 4, "values": ["Basic", "基础组"]},
        {"row": 5, "values": ["Advanced", "进阶组"]},
    ]
    sheets["ExampleItems"]["rows"] = [
        {
            "row": 4,
            "values": [
                "BasicItem",
                "基础示例",
                "Basic",
                "Common",
                100,
                True,
                None,
                "starter,shop",
            ],
        },
        {
            "row": 5,
            "values": [
                "AdvancedItem",
                "进阶示例",
                "Advanced",
                "Rare",
                500.5,
                False,
                "仅用于验证",
                "rare,shop",
            ],
        },
    ]
    sheets["ServerSettings"]["rows"] = [
        {"row": 4, "values": ["RewardMultiplier", 1, True]},
        {"row": 5, "values": ["SpawnInterval", 5, True]},
    ]
    return {"sheetNames": list(sheets), "sheets": sheets}


class ImportConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads(
            (ROOT / "design/config/config-schema.json").read_text(encoding="utf-8")
        )
        import_config.validate_schema(cls.schema)

    def validate(self, model):
        return import_config.validate_workbook_model(model, self.schema)

    def test_valid_model_generates_shared_and_server_outputs(self):
        typed_rows, issues = self.validate(make_model(self.schema))
        self.assertEqual([], issues)

        outputs = import_config.build_outputs(self.schema, typed_rows)
        for scope in ("Shared", "Server"):
            expected = {
                f"{sheet['name']}.lua"
                for sheet in self.schema["sheets"]
                if sheet["scope"] == scope
            }
            self.assertEqual(expected, set(outputs[scope]))
        self.assertIn('GroupId = "Basic"', outputs["Shared"]["ExampleItems.lua"])
        self.assertIn(
            'Tags = { "starter", "shop" }', outputs["Shared"]["ExampleItems.lua"]
        )
        for scope_outputs in outputs.values():
            for content in scope_outputs.values():
                self.assertIn(
                    "-- 此文件由 Excel Config 工具自动生成，请勿手动修改。",
                    content,
                )

    def test_formatted_error_includes_sheet_and_cell(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["rows"][0]["values"][1] = None
        _, issues = self.validate(model)
        issue = next(
            issue for issue in issues if issue.code == "CONFIG_REQUIRED_MISSING"
        )
        self.assertEqual(
            "CONFIG_REQUIRED_MISSING | Sheet=ExampleItems | Cell=B4 | "
            "字段 DisplayName 为必填项",
            issue.format(),
        )

    def test_description_must_match_schema(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["descriptions"][0] = "错误说明"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_DESCRIPTION_MISMATCH", {issue.code for issue in issues})

    def test_type_header_must_match_schema(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["types"][4] = "string"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_TYPE_HEADER_MISMATCH", {issue.code for issue in issues})

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

    def test_number_array_is_parsed(self):
        value, issues = import_config.validate_value(
            "1, 2.5, 3",
            {"key": "Weights", "type": "number[]", "required": True},
            "ExampleItems",
            4,
            1,
        )
        self.assertEqual([], issues)
        self.assertEqual([1, 2.5, 3], value)

    def test_invalid_number_array_is_rejected(self):
        _, issues = import_config.validate_value(
            "1, wrong, 3",
            {"key": "Weights", "type": "number[]", "required": True},
            "ExampleItems",
            4,
            1,
        )
        self.assertIn("CONFIG_TYPE_INVALID", {issue.code for issue in issues})

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
            "types": [],
            "rows": [],
            "formulas": set(),
            "workbook": "GameConfig.xlsx",
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
        model["sheets"]["ExampleGroups"]["types"].append("string")
        _, issues = self.validate(model)
        self.assertIn("CONFIG_UNKNOWN_COLUMN", {issue.code for issue in issues})

    def test_data_under_blank_unknown_column_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleGroups"]["descriptions"].append(None)
        model["sheets"]["ExampleGroups"]["keys"].append(None)
        model["sheets"]["ExampleGroups"]["types"].append(None)
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
        model = import_config.read_workbooks_model(
            ROOT / "design/config/workbooks", self.schema["layout"]
        )
        _, issues = self.validate(model)
        self.assertEqual([], issues)

    def test_sync_creates_missing_workbook_sheet_and_headers(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            changes = import_config.sync_workbooks_from_schema(workbook_dir, schema)

            self.assertEqual(1, len(changes))
            path = workbook_dir / "GameConfig.xlsx"
            workbook = import_config.load_workbook(path)
            try:
                self.assertEqual(["ServerSettings"], workbook.sheetnames)
                worksheet = workbook["ServerSettings"]
                self.assertEqual("唯一 ID（程序引用，不可重复，必填）", worksheet["A1"].value)
                self.assertEqual(["Id", "NumberValue", "Enabled"], [
                    worksheet.cell(2, column).value for column in range(1, 4)
                ])
                self.assertEqual(["string", "number", "boolean"], [
                    worksheet.cell(3, column).value for column in range(1, 4)
                ])
                self.assertEqual("A4", str(worksheet.freeze_panes))
            finally:
                workbook.close()

    def test_sync_is_idempotent_and_preserves_existing_data(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            import_config.sync_workbooks_from_schema(workbook_dir, schema)
            path = workbook_dir / "GameConfig.xlsx"
            workbook = import_config.load_workbook(path)
            workbook["ServerSettings"]["A4"] = "KeepMe"
            workbook.save(path)
            workbook.close()

            changes = import_config.sync_workbooks_from_schema(workbook_dir, schema)
            workbook = import_config.load_workbook(path)
            try:
                self.assertEqual([], changes)
                self.assertEqual("KeepMe", workbook["ServerSettings"]["A4"].value)
            finally:
                workbook.close()

    def test_sync_only_appends_new_trailing_columns(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            path = workbook_dir / "GameConfig.xlsx"
            workbook = import_config.Workbook()
            worksheet = workbook.active
            worksheet.title = "ServerSettings"
            first_column = schema["sheets"][0]["columns"][0]
            worksheet["A1"] = first_column["descriptionZh"]
            worksheet["A2"] = first_column["key"]
            worksheet["A3"] = first_column["type"]
            worksheet["A4"] = "KeepMe"
            workbook.save(path)
            workbook.close()

            changes = import_config.sync_workbooks_from_schema(workbook_dir, schema)
            workbook = import_config.load_workbook(path)
            try:
                self.assertEqual(1, len(changes))
                self.assertIn("Action=APPEND_COLUMNS", changes[0])
                self.assertEqual("KeepMe", workbook["ServerSettings"]["A4"].value)
                self.assertEqual("NumberValue", workbook["ServerSettings"]["B2"].value)
                self.assertEqual("Enabled", workbook["ServerSettings"]["C2"].value)
            finally:
                workbook.close()

    def test_sync_does_not_rewrite_conflicting_existing_headers(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            path = workbook_dir / "GameConfig.xlsx"
            workbook = import_config.Workbook()
            worksheet = workbook.active
            worksheet.title = "ServerSettings"
            worksheet["A2"] = "WrongKey"
            worksheet["A4"] = "KeepMe"
            workbook.save(path)
            workbook.close()

            changes = import_config.sync_workbooks_from_schema(workbook_dir, schema)
            workbook = import_config.load_workbook(path)
            try:
                self.assertEqual([], changes)
                self.assertEqual("WrongKey", workbook["ServerSettings"]["A2"].value)
                self.assertEqual("KeepMe", workbook["ServerSettings"]["A4"].value)
            finally:
                workbook.close()

    def test_sync_write_failure_keeps_original_workbook(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            path = workbook_dir / "GameConfig.xlsx"
            workbook = import_config.Workbook()
            workbook.active.title = "Existing"
            workbook.active["A1"] = "KeepMe"
            workbook.save(path)
            workbook.close()
            original = path.read_bytes()

            with mock.patch.object(
                import_config.os,
                "replace",
                side_effect=PermissionError("workbook locked"),
            ):
                with self.assertRaises(import_config.ConfigFailure) as context:
                    import_config.sync_workbooks_from_schema(workbook_dir, schema)

            self.assertIn(
                "CONFIG_WORKBOOK_WRITE_FAILED",
                {issue.code for issue in context.exception.issues},
            )
            self.assertEqual(original, path.read_bytes())
            self.assertEqual([], list(workbook_dir.glob(".*.config-sync-*.xlsx")))

    def test_run_import_syncs_then_generates(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workbook_dir = root / "workbooks"
            schema_path = root / "config-schema.json"
            schema_path.write_text(json.dumps(schema), encoding="utf-8")
            args = SimpleNamespace(
                repo_root=str(root),
                workbook_dir=str(workbook_dir),
                schema=str(schema_path),
                check=False,
            )

            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(0, import_config.run(args))

            self.assertIn("Action=CREATE_SHEET", output.getvalue())
            self.assertIn("CONFIG_IMPORT_OK", output.getvalue())
            self.assertTrue((workbook_dir / "GameConfig.xlsx").is_file())
            self.assertTrue(
                (
                    import_config.output_targets(root)["Server"] / "ServerSettings.lua"
                ).is_file()
            )

    def test_check_mode_never_creates_workbook_structure(self):
        schema = copy.deepcopy(self.schema)
        schema["sheets"] = [
            sheet for sheet in schema["sheets"] if sheet["name"] == "ServerSettings"
        ]

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workbook_dir = root / "workbooks"
            workbook_dir.mkdir()
            schema_path = root / "config-schema.json"
            schema_path.write_text(json.dumps(schema), encoding="utf-8")
            args = SimpleNamespace(
                repo_root=str(root),
                workbook_dir=str(workbook_dir),
                schema=str(schema_path),
                check=True,
            )

            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(1, import_config.run(args))
            self.assertFalse((workbook_dir / "GameConfig.xlsx").exists())

    def test_multiple_workbooks_are_merged(self):
        with tempfile.TemporaryDirectory() as directory:
            workbook_dir = Path(directory)
            first_path = workbook_dir / "First.xlsx"
            second_path = workbook_dir / "Second.xlsx"
            first_path.touch()
            second_path.touch()

            def fake_read(path, _layout):
                sheet_name = path.stem
                return {
                    "sheetNames": [sheet_name],
                    "sheets": {
                        sheet_name: {
                            "descriptions": [],
                            "keys": [],
                            "types": [],
                            "rows": [],
                            "formulas": set(),
                            "workbook": path.name,
                        }
                    },
                }

            with mock.patch.object(import_config, "read_workbook_model", side_effect=fake_read):
                model = import_config.read_workbooks_model(
                    workbook_dir, self.schema["layout"]
                )

            self.assertEqual(["First", "Second"], model["sheetNames"])

    def test_sheet_in_wrong_workbook_is_rejected(self):
        model = make_model(self.schema)
        model["sheets"]["ExampleItems"]["workbook"] = "Other.xlsx"
        _, issues = self.validate(model)
        self.assertIn("CONFIG_SHEET_WRONG_WORKBOOK", {issue.code for issue in issues})

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

    def test_atomic_write_keeps_backup_outside_source_tree(self):
        typed_rows, issues = self.validate(make_model(self.schema))
        self.assertEqual([], issues)
        outputs = import_config.build_outputs(self.schema, typed_rows)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            import_config.write_outputs_atomic(root, outputs)
            destinations = []
            real_replace = import_config.os.replace

            def record_replace(source, destination):
                destinations.append(Path(destination))
                return real_replace(source, destination)

            with mock.patch.object(
                import_config.os, "replace", side_effect=record_replace
            ):
                import_config.write_outputs_atomic(root, outputs)

            backup_destinations = [
                path for path in destinations if path.name.endswith(".previous")
            ]
            self.assertEqual(2, len(backup_destinations))
            self.assertTrue(
                all(path.parent.name.startswith(".config-build-") for path in backup_destinations)
            )
            self.assertFalse(
                any("config-backup" in path.name for path in destinations)
            )

    def test_atomic_write_cleanup_failure_keeps_committed_outputs(self):
        old_outputs = {
            "Shared": {"OldShared.lua": "return { Old = true }\n"},
            "Server": {"OldServer.lua": "return { Old = true }\n"},
        }
        new_outputs = {
            "Shared": {"NewShared.lua": "return { New = true }\n"},
            "Server": {"NewServer.lua": "return { New = true }\n"},
        }

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            import_config.write_outputs_atomic(root, old_outputs)
            real_rmtree = import_config.shutil.rmtree
            failure_injected = False

            def fail_second_backup_once(path, *args, **kwargs):
                nonlocal failure_injected
                if Path(path).name == "Server.previous" and not failure_injected:
                    failure_injected = True
                    raise OSError("simulated backup cleanup failure")
                return real_rmtree(path, *args, **kwargs)

            with mock.patch.object(
                import_config.shutil,
                "rmtree",
                side_effect=fail_second_backup_once,
            ):
                import_config.write_outputs_atomic(root, new_outputs)

            self.assertTrue(failure_injected)
            for scope, target in import_config.output_targets(root).items():
                self.assertEqual(
                    set(new_outputs[scope]),
                    {path.name for path in target.iterdir()},
                )
                for file_name, content in new_outputs[scope].items():
                    self.assertEqual(
                        content,
                        (target / file_name).read_text(encoding="utf-8"),
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
                workbook_dir=str(root / "workbooks"),
                schema=str(schema_path),
                check=False,
            )
            with mock.patch.object(import_config, "read_workbooks_model", return_value=model):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(1, import_config.run(args))

            for target in targets.values():
                self.assertEqual("previous", (target / "Previous.lua").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
