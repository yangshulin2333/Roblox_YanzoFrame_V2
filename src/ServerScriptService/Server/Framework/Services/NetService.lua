--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetResult = require(ReplicatedStorage.Framework.Shared.Net.NetResult) --统一返回格式
local RemoteGuards = require(ReplicatedStorage.Framework.Shared.Net.RemoteGuards) --Guards 指校验、防护、拦截规则。检查 Remote 名字是否合法
local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames) --Remote 文件夹名和请求名

local NetService = {
	Name = "NetService",
}

--[[
	_logger	保存 Logger
	_rootFolder	保存 YanzoFrame_V1_StorageModule_Remotes 文件夹
	_requestFolder	保存 ClientToServer/Requests
	_clientEventFolder	保存 ClientToServer/Events
	_serverEventFolder	保存 ServerToClient/Events
	_requestHandlers	记录已经注册的 RemoteFunction 请求
	_eventHandlers	记录已经注册的 RemoteEvent 事件
	]]
NetService._logger = nil
NetService._rootFolder = nil
NetService._requestFolder = nil
NetService._clientEventFolder = nil
NetService._serverEventFolder = nil
NetService._requestHandlers = {}
NetService._eventHandlers = {}

--传入一个父对象和一个文件夹名，返回这个文件夹的引用。
local function getOrCreateFolder(parent, folderName)
	local existing = parent:FindFirstChild(folderName)
	if existing ~= nil then
		if not existing:IsA("Folder") then
			error("预期文件夹位于" .. existing:GetFullName(), 3)
		end
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	return folder
end

--传入一个父对象和一个 RemoteFunction 名字，返回这个 RemoteFunction 的引用。
local function getOrCreateRemoteFunction(parent, remoteName)
	local existing = parent:FindFirstChild(remoteName)
	if existing ~= nil then
		if not existing:IsA("RemoteFunction") then
			error("预期 RemoteFunction 位于" .. existing:GetFullName(), 3)
		end
		return existing
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = remoteName
	remote.Parent = parent
	return remote
end

--传入一个父对象和一个 RemoteEvent 名字，返回这个 RemoteEvent 的引用。
local function getOrCreateRemoteEvent(parent, remoteName)
	local existing = parent:FindFirstChild(remoteName)
	if existing ~= nil then
		if not existing:IsA("RemoteEvent") then
			error("Expected RemoteEvent at " .. existing:GetFullName(), 3)
		end
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = parent
	return remote
end

function NetService:Init(context)
	self._logger = context.Logger

	local root = getOrCreateFolder(ReplicatedStorage, RemoteNames.RootFolder) --创建一个 YanzoFrame_V1_StorageModule_Remotes 文件夹在 ReplicatedStorage 下面
	local clientToServer = getOrCreateFolder(root, RemoteNames.ClientToServerFolder) --创建一个 ClientToServer 文件夹在 YanzoFrame_V1_StorageModule_Remotes 下面
	local serverToClient = getOrCreateFolder(root, RemoteNames.ServerToClientFolder) --创建一个 ServerToClient 文件夹在 YanzoFrame_V1_StorageModule_Remotes 下面

	--全局变量
	self._rootFolder = root --引用类型，指向 YanzoFrame_V1_StorageModule_Remotes
	self._requestFolder = getOrCreateFolder(clientToServer, RemoteNames.RequestFolder) --创建一个 Requests 文件夹在 ClientToServer 下面
	self._clientEventFolder = getOrCreateFolder(clientToServer, RemoteNames.EventFolder) --创建一个 Events 文件夹在 ClientToServer 下面
	self._serverEventFolder = getOrCreateFolder(serverToClient, RemoteNames.EventFolder) --创建一个 Events 文件夹在 ServerToClient 下面
	--[[
	NetService:Init(context) 完成后，Roblox 里应该有：
		ReplicatedStorage
		  YanzoFrame_V1_StorageModule_Remotes
		    ClientToServer
		      Requests
		      Events
		    ServerToClient
		      Events

		同时 NetService 表里保存了这些引用：
		NetService._rootFolder = YanzoFrame_V1_StorageModule_Remotes
		NetService._requestFolder = ClientToServer.Requests
		NetService._clientEventFolder = ClientToServer.Events
		NetService._serverEventFolder = ServerToClient.Events
	]]
end

--会被service:Start()调用，注册一个 RemoteFunction 请求，匿名函数就是这个请求的处理函数。
function NetService:Start()
	self:RegisterRequest(
		RemoteNames.FrameworkPing,
		function(player, _payload) --"Framework.Ping",匿名函数，返回一个表，里面有玩家的 UserId 和服务器时间
			return {
				PlayerUserId = player.UserId,
				ServerTime = os.time(),
			}
		end
	)

	self._logger.Info(self.Name, "Remote boundary ready")
end

function NetService:GetRemoteFolder()
	if self._rootFolder == nil then
		error("NetService is not initialized", 2)
	end
	return self._rootFolder
end

function NetService:GetRequestFolder()
	if self._requestFolder == nil then
		error("NetService is not initialized", 2)
	end
	return self._requestFolder
end

function NetService:GetClientEventFolder()
	if self._clientEventFolder == nil then
		error("NetService is not initialized", 2)
	end
	return self._clientEventFolder
end

function NetService:GetServerEventFolder()
	if self._serverEventFolder == nil then
		error("NetService is not initialized", 2)
	end
	return self._serverEventFolder
end

function NetService:EnsureServerEvent(remoteName)
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")
	return getOrCreateRemoteEvent(self:GetServerEventFolder(), remoteName)
end

--[[
	匿名函数作为 handler 传进 RegisterRequest
	-> remoteName 是 "Framework.Ping"
	-> RegisterRequest 创建 Framework.Ping 这个 RemoteFunction
	-> 客户端 InvokeServer 这个 RemoteFunction 时，Roblox 触发 OnServerInvoke
	-> OnServerInvoke 调用 _handleRequest
	-> _handleRequest 执行 handler
	-> handler 就是那段匿名函数
	所以：
		客户端 InvokeServer Framework.Ping
		-> 服务端 OnServerInvoke
		-> 服务端 _handleRequest
		-> 服务端 执行匿名函数，返回一个表 { PlayerUserId = player.UserId, ServerTime = os.time() }
		-> 服务端 _handleRequest 返回 NetResult.Ok({ PlayerUserId = player.UserId, ServerTime = os.time() })
		-> Roblox 把这个结果返回给客户端
		]]
function NetService:RegisterRequest(remoteName, handler) --"Framework.Ping", 匿名函数
	RemoteGuards.AssertRemoteName(remoteName, "remoteName") --调用AssertRemoteName函数 检查 remoteName 是否符合规则

	if type(handler) ~= "function" then
		error("handler必须是一个函数", 2)
	end

	--检查这个请求名是不是已经注册过了。 不能重复注册。
	if self._requestHandlers[remoteName] ~= nil then
		error("请求已注册: " .. remoteName, 2)
	end
	--在 ClientToServer/Requests 下面找到或创建一个叫 Framework.Ping 的 RemoteFunction。
	local remote = getOrCreateRemoteFunction(self:GetRequestFolder(), remoteName)
	self._requestHandlers[remoteName] = handler --NetService._requestHandlers["Framework.Ping"] = 匿名函数

	--[[
		存到NetService._requestHandlers表里：
		NetService._requestHandlers = {
			["Framework.Ping"] = function(player, _payload)
				return {
					PlayerUserId = player.UserId,
					ServerTime = os.time(),
				}
			end,
		}
	]]

	--[[
		FireServer      客户端发给服务端
		OnServerEvent   服务端接收客户端事件

		FireClient      服务端发给单个客户端
		FireAllClients  服务端发给所有客户端
		OnClientEvent   客户端接收服务端事件

		InvokeServer    客户端请求服务端并等返回
		OnServerInvoke  服务端处理客户端请求并返回

		InvokeClient    服务端请求客户端并等返回
		OnClientInvoke  客户端处理服务端请求并返回
	]]

	--当客户端 remote:InvokeServer(payload) 这个 RemoteFunction 时，roblox 会触发 remote.OnServerInvoke 事件，传入发起请求的玩家和客户端传来的数据。
	remote.OnServerInvoke = function(player, payload) --设置这个 RemoteFunction 被客户端调用时，服务端要执行的函数。
		--[[
			该匿名函数创建时，handler 是 RegisterRequest 的局部参数。
			但是这个内部函数引用了 handler。
			所以 Luau 会保留这个 handler，让以后 OnServerInvoke 被调用时还能用。
			这就是闭包。
		]]
		--返回的是 NetResult.Ok({ PlayerUserId = player.UserId, ServerTime = os.time() }) 这个表
		return self:_handleRequest(remoteName, handler, player, payload)
	end

	--打日志并返回 remote
	self._logger.Debug(self.Name, "注册请求: " .. remoteName)
	return remote
end

function NetService:RegisterClientEvent(remoteName, handler)
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")

	if type(handler) ~= "function" then
		error("handler must be a function", 2)
	end

	if self._eventHandlers[remoteName] ~= nil then
		error("Client event already registered: " .. remoteName, 2)
	end

	--在 ClientToServer/Event 下找到或创建一个叫 remoteName 的 RemoteEvent。
	local remote = getOrCreateRemoteEvent(self:GetClientEventFolder(), remoteName)
	self._eventHandlers[remoteName] = handler

	--连接 RemoteEvent 的 OnServerEvent 信号，调用 handler 并用 pcall 捕获错误。
	remote.OnServerEvent:Connect(function(player, payload)
		--用 pcall 调用 handler，防止 handler 内部报错导致整个事件崩溃。
		local ok, err = pcall(handler, player, payload)
		if not ok then
			self._logger.Warn(self.Name, "Client event failed: " .. remoteName .. " / " .. tostring(err))
		end
	end)

	self._logger.Debug(self.Name, "Registered client event: " .. remoteName)
	return remote
end

--服务端给指定玩家发消息。
function NetService:FireClient(remoteName, player, payload)
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")

	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("player must be a Player", 2)
	end
	--在 ServerToClient/Event 下找到或创建一个叫 remoteName 的 RemoteEvent。
	local remote = getOrCreateRemoteEvent(self:GetServerEventFolder(), remoteName)
	remote:FireClient(player, payload)
end

--服务端给所有玩家发消息。
function NetService:FireAllClients(remoteName, payload)
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")

	local remote = getOrCreateRemoteEvent(self:GetServerEventFolder(), remoteName)
	remote:FireAllClients(payload)
end

--统一处理 pcall 防崩溃，错误日志，统一 NetResult 返回格式
function NetService:_handleRequest(remoteName, handler, player, payload)
	--[[
		pcall(要执行的函数, 参数1, 参数2, 参数3...)
			所以：
				pcall(handler, player, payload)
				意思就是：
				保护性地执行 handler(player, payload)
			第一个参数必须是函数；
			后面的参数会传给这个函数；
			pcall 会调用这个函数；
			如果函数报错，pcall 不让外层崩掉，而是返回 false 和错误信息。

			尝试执行 handler(player, payload)
			如果成功：
				ok = true
				result = handler 的返回值

			如果失败：
				ok = false
				result = 错误信息
		]]
	local ok, result = pcall(handler, player, payload) ---->handler(player, payload)

	--[[
		{
	    	Ok = false,
	    	Code = "SERVER_ERROR",
	    	Message = "Request failed",
	    	Data = {
	    	    RemoteName = remoteName,
	    	},
		}
	]]
	if not ok then
		self._logger.Warn(self.Name, "请求失败: " .. remoteName .. " / " .. tostring(result))
		return NetResult.Err("SERVER_ERROR", "Request failed", {
			RemoteName = remoteName,
		})
	end

	--[[
	handler 返回普通表。
	_handleRequest 发现它不是 NetResult。
	于是用 NetResult.Ok(result) 包一层。
	所以客户端收到 Ok = true。
	]]
	if NetResult.IsResult(result) then
		return result
	end

	return NetResult.Ok(result)
end

return NetService
