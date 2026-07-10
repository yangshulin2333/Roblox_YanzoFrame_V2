# YanzoFrame_V1_StorageModule Agent Rules

本项目是 `D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V1_StorageModule`，从 `YanzoFrame_V0` 复制而来，用于开发第一个正式 Roblox 可复用模块：`StorageModule`。

## 固定目标

`YanzoFrame_V0` 已作为基础框架本体冻结。本项目只在复制件中推进 `StorageModule`，不再反向扩大 V0 底座。

当前固定目标：

- 保持 V0 底座结构可理解、可验证。
- 把 Storage 从“最小内存边界”逐步整理为独立模块。
- 每次只推进一个清晰的小阶段。
- 模块要能单独理解、单独验证、单独接入别的 Roblox 项目。

## 语言规则

- 文档、解释、交接默认中文。
- 代码文件名、变量名、函数名使用简单英文。
- 必须用英文时，使用短句和常见单词。

## 代码边界

- `Framework` 放通用底座。
- `Module` 放当前模块自己的配置和共享数据。
- Server 负责真实状态修改。
- Client 只负责请求和显示。
- 配置写在表里，不把数值散落在逻辑里。
- 不把商店、背包、敌人、奖励等业务逻辑写进 StorageModule。

## Storage 边界

当前复制件已进入 `StorageModule V1.1` 持久化阶段。

当前已存在：

- `MemoryStorage`
- `ProfileStoreStorage`
- `StorageService`
- `StorageConfig`
- `Open / IsOpen / Get / Set / Update / Close`
- 默认数据校验
- 玩家数据加载失败和会话结束处理

当前阶段不加入：

- 自制原生 DataStore 适配器
- 数据迁移
- 批量维护
- JSON / Excel 导入导出
- 业务字段，例如 Coins、Items、Shop、Inventory

业务服务只能依赖 `StorageService`，不能直接依赖 `MemoryStorage`、`ProfileStoreStorage` 或 `ProfileStore`。
`Get` 只能读取已经打开的数据；只有 `Open` 可以加载或创建默认数据。`Close` 表示保存并释放会话，不表示删除永久数据。

## UI / Studio 边界

凡是位置、大小、颜色、层级、布局，默认 Studio 管。

代码只做：

1. 找到对象。
2. 绑定按钮事件。
3. 改文本、数值、显示隐藏。
4. 播放简单状态反馈。
5. 克隆明确标记为 Template 的对象。

代码默认不做：

- 不重排手工 UI。
- 不改手工对象尺寸位置。
- 不删除手工对象。
- 不把复杂 UI 全部代码生成。

## 验证要求

修改代码后至少运行：

```powershell
wally install
stylua --check src
selene src
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

涉及 Roblox Studio 的内容，还需要 Studio 手动确认。
