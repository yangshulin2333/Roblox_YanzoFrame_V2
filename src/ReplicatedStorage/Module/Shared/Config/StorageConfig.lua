--!strict

local StorageConfig = {}

--架构版本号
StorageConfig.SchemaVersion = 1

--新玩家第一次进来，或者某个 key 第一次打开时，就会用这份默认数据做初始值。
StorageConfig.DefaultData = {
	SchemaVersion = StorageConfig.SchemaVersion,
}

function StorageConfig.Validate(data)
	if type(data) ~= "table" then
		return false, "必须是table类型"
	end

	if data.SchemaVersion ~= StorageConfig.SchemaVersion then
		return false, "SchemaVersion不匹配"
	end

	return true
end

return StorageConfig
