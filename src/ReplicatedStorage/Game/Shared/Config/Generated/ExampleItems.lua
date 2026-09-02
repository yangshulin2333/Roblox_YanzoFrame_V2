--!strict
-- 此文件由 Excel Config 工具自动生成，请勿手动修改。
-- 来源：design/config/workbooks/GameConfig.xlsx / ExampleItems

return {
	["BasicItem"] = {
		Id = "BasicItem",
		DisplayName = "基础示例",
		GroupId = "Basic",
		Tier = "Common",
		Price = 100,
		Enabled = true,
		Tags = { "starter", "shop" },
	},
	["AdvancedItem"] = {
		Id = "AdvancedItem",
		DisplayName = "进阶示例",
		GroupId = "Advanced",
		Tier = "Rare",
		Price = 500.5,
		Enabled = false,
		Note = "仅用于验证",
		Tags = { "rare", "shop" },
	},
}
