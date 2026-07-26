--!strict

local DeveloperConfig = {}

-- 是否允许开发者初始化自己的整档数据。
DeveloperConfig.EnableDataReset = true

-- Studio Play 默认允许当前测试玩家使用重置入口。
DeveloperConfig.AllowDataResetInStudio = true

-- 正式服务器默认拒绝；如确有受控测试需求，再显式填写 Roblox UserId。
DeveloperConfig.AllowedUserIds = {}

-- 判断正式服务器中的指定用户是否在开发者白名单内。
function DeveloperConfig.IsUserAllowed(userId)
	return DeveloperConfig.AllowedUserIds[userId] == true
end

return DeveloperConfig
