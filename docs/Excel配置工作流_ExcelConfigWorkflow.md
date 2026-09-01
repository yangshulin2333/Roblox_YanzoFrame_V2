# Excel 配置工作流

## 目的

策划只编辑 `design/GameConfig.xlsx`，程序或 Codex 维护 `design/config-schema.json`。Roblox 运行时只读取生成后的 Luau，不读取 Excel。

```text
GameConfig.xlsx
→ Schema 校验
→ 临时目录生成 Luau
→ 全部成功后替换 Generated
→ Rojo 同步到 Studio
```

## 双表头规则

每个数据 Sheet 都固定使用：

| 行 | 内容 | 谁使用 |
|---|---|---|
| 第 1 行 | 中文释义、单位和重要限制 | 策划阅读 |
| 第 2 行 | 简单稳定的英文键名 | 导入器和 Luau |
| 第 3 行起 | 正式配置数据 | 策划编辑 |

示例：

| 唯一 ID（程序引用，不可重复，必填） | 价格（数字，必须大于等于 0，必填） | 是否启用（TRUE 或 FALSE，必填） |
|---|---|---|
| `Id` | `Price` | `Enabled` |
| `BasicItem` | `100` | `TRUE` |

不要合并字段单元格，不要修改第 1、2 行，不要使用公式或宏。

## Schema 职责

每个字段必须声明：

- `key`：英文键名。
- `descriptionZh`：非空中文释义。
- `type`：`string`、`number` 或 `boolean`。
- `required`：是否必填。

按需要再声明：

- `unique`：不能重复。
- `min` / `max`：数字范围。
- `enum`：允许值。
- `ref`：跨表引用，例如 `ExampleGroups.Id`。

每张表使用 Sheet 级 `scope`：

- `Shared`：输出到 `ReplicatedStorage.Game`，Client 和 Server 都能读取。
- `Server`：输出到 `ServerScriptService.Server.Game`，Client 不可读取。

同一张表不混放 Shared 和 Server-only 字段，避免误泄露。

## 使用命令

首次安装：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-ConfigTool.ps1
```

生成：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-GameConfig.ps1
```

检查 Excel、测试和生成结果：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ConfigTool.ps1
```

## 失败保护

导入器先完成全部校验并写入临时目录，成功后才替换两个 `Generated` 目录。任何校验失败都不会覆盖上一份有效 Luau。

常见错误码：

| 错误码 | 含义 |
|---|---|
| `CONFIG_DESCRIPTION_MISMATCH` | 中文释义与 Schema 不一致 |
| `CONFIG_HEADER_MISMATCH` | 英文键名与 Schema 不一致 |
| `CONFIG_FORMULA_NOT_ALLOWED` | 单元格含公式 |
| `CONFIG_REQUIRED_MISSING` | 缺少必填值 |
| `CONFIG_TYPE_INVALID` | 字段类型错误 |
| `CONFIG_DUPLICATE_VALUE` | 唯一字段重复 |
| `CONFIG_NUMBER_OUT_OF_RANGE` | 数字超出范围 |
| `CONFIG_ENUM_INVALID` | 枚举值不存在 |
| `CONFIG_REFERENCE_NOT_FOUND` | 找不到跨表引用 |
| `CONFIG_OUTPUT_OUTDATED` | Excel 与已生成 Luau 不一致 |

`Generated` 文件带有自动生成注释，禁止手工修改；需要改数据时回到 Excel，需要改字段规则时修改 Schema。
