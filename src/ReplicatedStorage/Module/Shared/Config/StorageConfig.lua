--!strict

local StorageConfig = {}

--架构版本号
StorageConfig.SchemaVersion = 1

local SupportedLanguages = {
	["zh-CN"] = true,
	["en-US"] = true,
}

--新玩家第一次进来，或者某个 key 第一次打开时，就会用这份默认数据做初始值。
StorageConfig.DefaultData = {
	SchemaVersion = StorageConfig.SchemaVersion,
	Settings = {
		Language = "zh-CN",
	},
	Modules = {},
}

function StorageConfig.Validate(data)
	if type(data) ~= "table" then
		return false, "必须是table类型"
	end

	if data.SchemaVersion ~= StorageConfig.SchemaVersion then
		return false, "SchemaVersion不匹配"
	end

	if type(data.Settings) ~= "table" then
		return false, "Settings必须是table类型"
	end

	if not SupportedLanguages[data.Settings.Language] then
		return false, "Settings.Language不支持"
	end

	if type(data.Modules) ~= "table" then
		return false, "Modules必须是table类型"
	end

	return true
end

return StorageConfig
