# YanzoFrame_V0 Agent Rules

本项目是 `D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V0` 的 Roblox 模块开发底座。

## 固定目标

YanzoFrame_V0 是后续复制用的基础框架本体。

每次只打磨一个可复用模块。模块要能单独理解、单独验证、单独接入别的 Roblox 项目。

在用户明确完成基础框架学习前，不开始第一个正式模块。

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

## Storage 边界

基础框架保留 Storage，但只保留最小边界。

允许：

- `MemoryStorage`
- `StorageService`
- `StorageConfig`
- `Open / Get / Set / Update / Remove`
- 默认数据校验

禁止在基础框架阶段加入：

- DataStore
- ProfileStore
- 数据迁移
- 批量维护
- JSON / Excel 导入导出
- 业务字段，例如 Coins、Items、Shop、Inventory

完整 StorageModule 以后作为第一个正式模块单独开发。

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
stylua --check src
selene src
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

涉及 Roblox Studio 的内容，还需要 Studio 手动确认。
