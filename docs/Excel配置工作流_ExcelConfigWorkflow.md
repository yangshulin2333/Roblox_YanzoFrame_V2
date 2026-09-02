# Excel 配置工作流

## 目的

策划只编辑 `design/config/workbooks` 中的 Excel，程序或 Codex 维护 `design/config/config-schema.json`。Roblox 运行时只读取生成后的 Luau，不读取 Excel。

```text
design/config/workbooks/*.xlsx
← Schema 安全补齐缺失结构
→ Excel 与 Schema 校验
→ 临时目录生成 Luau
→ 全部成功后替换 Generated
→ Rojo 同步到 Studio
```

## 策划最短操作卡

日常调数只需要四步，不接触 JSON 和 Luau：

1. 打开 `design/config/workbooks/GameConfig.xlsx`。
2. 只修改目标 Sheet 第 4 行以后的数据。
3. 按 `Ctrl + S` 保存。
4. 回到项目根目录运行 `.\scripts\Import-GameConfig.ps1`；看到 `CONFIG_IMPORT_OK` 即完成。

如果命令失败，先看错误中的 `Sheet` 和 `Cell`，例如 `Sheet=ExampleItems | Cell=B4`。修正对应单元格后保存，再运行同一条命令。

## 正式模板（V2.2 第三阶段冻结）

正式模板只保留一个 `GameConfig.xlsx` 和三个中性示例 Sheet：

| Sheet | 输出范围 | 用于证明的能力 |
|---|---|---|
| `ExampleGroups` | `Shared` | 字符串、唯一 ID、被其他表引用 |
| `ExampleItems` | `Shared` | `ref`、`enum`、整数与小数、布尔值、可选值、字符串数组 |
| `ServerSettings` | `Server` | Server-only 数据不会生成到客户端目录 |

第二阶段教学用的 `Items`、`PracticeSettings` 和 `PracticeConfig.xlsx` 不属于正式模板，第三阶段已清除。真实游戏立项后，再由程序或 Codex 根据策划案建立真实 Sheet、真实字段和真实校验规则；不要从示例名称推断未来玩法。

## 文件组织

项目初期只使用 `GameConfig.xlsx`。当 Sheet 明显增多或多人同时编辑发生冲突时，再按领域增加 `Economy.xlsx`、`Combat.xlsx`、`LiveOps.xlsx`；不需要一个 Sheet 拆成一个 Excel。

所有工作簿中的 Sheet 名必须全局唯一。Schema 中的 `workbook` 决定 Sheet 应放在哪个文件，放错位置会阻止生成。

## 两类操作

- **日常改数据**：策划只编辑第 4 行以后的数据，不修改 Schema。
- **改变表结构**：程序或 Codex 修改 Schema；保存并关闭 Excel 后运行导表，工具自动创建缺失工作簿、Sheet、三行表头和安全的末尾新字段。

Schema 是表结构的唯一来源。不要手工在 Schema 与 Excel 之间复制三行表头，也不要让策划编辑 `config-schema.json`。

结构同步只执行可证明安全的操作：

- 可以创建缺失的工作簿和 Sheet。
- 可以为完全空白的 Sheet 创建三行表头。
- 现有字段与 Schema 前缀一致时，可以在末尾追加字段。
- 不移动、不删除、不重命名字段，不覆盖已有数据。
- 发现冲突时停止并报告，由程序处理迁移。

## 谁负责什么

- **策划**：只编辑 Excel 第 4 行以后的正式数据。
- **程序或 Codex**：决定 Sheet、字段、引用、`scope` 和目标工作簿，并维护 Schema。
- **Generated**：完全由导表工具生成，任何人都不手改。

开发者可以自行修改 Schema，但策划不需要理解 JSON。字段重命名、删除、重排、类型变化和 `scope` 迁移必须先检查代码引用，不能当成普通数据修改。

## 日常修改已有数据

1. 打开 Excel，修改第 4 行以后的数据。
2. 按 `Ctrl + S` 保存。
3. 在项目根目录运行 `.\scripts\Import-GameConfig.ps1`。
4. 看到 `CONFIG_IMPORT_OK` 即完成。

这类操作不修改工作簿结构，Excel 保存后可以保持打开。

## 新增 Sheet

1. 程序或 Codex 在 Schema 的 `sheets` 中新增定义，确定 `name`、`workbook`、`scope`、`primaryKey` 和 `columns`。
2. 关闭目标 Excel；不要手工创建 Sheet 或复制三行表头。
3. 运行 `.\scripts\Import-GameConfig.ps1`。
4. 工具在 Schema 指定的工作簿中创建 Sheet 和三行表头，并生成空的 Luau 配置模块。
5. 打开 Excel，从第 4 行开始填写数据，保存后再次运行导表。

`scope` 决定生成位置：

| `scope` | 客户端能否读取 | Luau 生成位置 |
|---|---|---|
| `Shared` | 可以 | `src/ReplicatedStorage/Game/Shared/Config/Generated` |
| `Server` | 不可以 | `src/ServerScriptService/Server/Game/Config/Generated` |

客户端需要读取且内容可以公开时使用 `Shared`；其他情况优先使用 `Server`。同一概念同时包含公开字段和服务器内部字段时拆成两张表，通过 ID 引用。

## 新增 Excel 工作簿

新增 Excel 不是先在 Excel 中点击“新建”。Schema 是结构来源，标准流程是：

1. 先确认是否真的需要拆分工作簿。项目初期优先继续在 `GameConfig.xlsx` 增加 Sheet。
2. 只有业务领域已经形成多张相关表、Sheet 难以查找，或多人同时编辑产生冲突时，才新增 `Economy.xlsx`、`Combat.xlsx`、`LiveOps.xlsx` 等领域工作簿。
3. 程序或 Codex 在一个或多个 Sheet 定义中填写新的 `workbook` 文件名，例如 `"workbook": "Economy.xlsx"`。
4. 关闭当前打开的配置 Excel，运行 `.\scripts\Import-GameConfig.ps1`。
5. 工具自动在 `design/config/workbooks` 创建新 Excel、对应 Sheet 和三行表头。
6. 打开新 Excel，从第 4 行开始填写数据，保存后再次运行导表。

一个 Sheet 生成一个 Luau 模块；拆分 Excel 只影响策划的文件组织，不改变 Roblox 运行时结构。所有工作簿中的 Sheet 名仍必须全局唯一。

## 什么时候关闭 Excel

| 操作 | 是否需要关闭 Excel |
|---|---|
| 修改现有数据行 | 不需要，保存即可 |
| 新增 Sheet | 需要 |
| 新建 Excel 工作簿 | 需要 |
| 在末尾追加字段 | 需要 |
| 只修改 `min`、`max`、`enum`、`ref` | 通常不需要 |
| 字段重命名、删除、重排或修改类型 | 先停止，由程序处理迁移 |

便于记忆的规则：**改 Schema 时先关闭 Excel；只改数据时保存即可。**

## 三行表头规则

每个数据 Sheet 都固定使用：

| 行 | 内容 | 谁使用 |
|---|---|---|
| 第 1 行 | 中文释义、单位和重要限制 | 策划阅读 |
| 第 2 行 | 简单稳定的英文键名 | 导入器和 Luau |
| 第 3 行 | 字段类型 | 策划和程序共同确认 |
| 第 4 行起 | 正式配置数据 | 策划编辑 |

示例：

| 唯一 ID（程序引用，不可重复，必填） | 价格（数字，必须大于等于 0，必填） | 是否启用（TRUE 或 FALSE，必填） |
|---|---|---|
| `Id` | `Price` | `Enabled` |
| `string` | `number` | `boolean` |
| `BasicItem` | `100` | `TRUE` |

不要合并字段单元格，不要修改前 3 行，不要使用公式或宏。新增 Sheet 或末尾字段时只修改 Schema，再运行导表自动同步；字段重命名、删除或重排必须由程序明确迁移。

## Schema 职责

每个字段必须声明：

- `key`：英文键名。
- `descriptionZh`：非空中文释义。
- `type`：`string`、`number`、`boolean`、`string[]` 或 `number[]`。
- `required`：是否必填。

数组在 Excel 中使用英文逗号分隔，例如 `starter,shop` 或 `100,250,500`。当前不支持嵌套表、数组 `enum` 或数组 `unique`；复杂结构优先拆成独立 Sheet，通过 ID 建立关系。

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

同步缺失结构并生成。在 VS Code 的项目根目录可以直接运行短命令：

```powershell
.\scripts\Import-GameConfig.ps1
```

检查 Excel、测试和生成结果：

```powershell
.\scripts\Validate-ConfigTool.ps1
```

## 失败保护

导入器只执行不会覆盖已有数据的结构补齐，然后完成全部校验并写入 `src` 外的临时目录；成功后才替换两个 `Generated` 目录。任何校验失败都不会覆盖上一份有效 Luau。结构变化需要写入 Excel 时，如果工作簿正在打开，会要求关闭 Excel 后重试。

常见错误码：

| 错误码 | 含义 |
|---|---|
| `CONFIG_DESCRIPTION_MISMATCH` | 中文释义与 Schema 不一致 |
| `CONFIG_HEADER_MISMATCH` | 英文键名与 Schema 不一致 |
| `CONFIG_TYPE_HEADER_MISMATCH` | 第 3 行字段类型与 Schema 不一致 |
| `CONFIG_DUPLICATE_SHEET` | 多个工作簿中出现同名 Sheet |
| `CONFIG_SHEET_WRONG_WORKBOOK` | Sheet 没有放在 Schema 指定的工作簿 |
| `CONFIG_WORKBOOK_WRITE_FAILED` | Excel 正在打开或工作簿无法安全更新 |
| `CONFIG_FORMULA_NOT_ALLOWED` | 单元格含公式 |
| `CONFIG_REQUIRED_MISSING` | 缺少必填值 |
| `CONFIG_TYPE_INVALID` | 字段类型错误 |
| `CONFIG_DUPLICATE_VALUE` | 唯一字段重复 |
| `CONFIG_NUMBER_OUT_OF_RANGE` | 数字超出范围 |
| `CONFIG_ENUM_INVALID` | 枚举值不存在 |
| `CONFIG_REFERENCE_NOT_FOUND` | 找不到跨表引用 |
| `CONFIG_OUTPUT_OUTDATED` | Excel 与已生成 Luau 不一致 |

`Generated` 文件固定带有“此文件由 Excel Config 工具自动生成，请勿手动修改”注释。需要改数据时回到 Excel，需要改字段规则时修改 Schema。
