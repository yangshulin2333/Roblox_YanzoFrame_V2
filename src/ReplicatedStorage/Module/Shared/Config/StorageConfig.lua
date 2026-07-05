--!strict

local StorageConfig = {}

StorageConfig.SchemaVersion = 1

StorageConfig.DefaultData = {
	SchemaVersion = StorageConfig.SchemaVersion,
}

function StorageConfig.Validate(data)
	if type(data) ~= "table" then
		return false, "data must be a table"
	end

	if data.SchemaVersion ~= StorageConfig.SchemaVersion then
		return false, "SchemaVersion is invalid"
	end

	return true
end

return StorageConfig
