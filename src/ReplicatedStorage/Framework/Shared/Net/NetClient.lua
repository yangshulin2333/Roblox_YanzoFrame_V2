--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetResult = require(script.Parent.NetResult)
local RemoteGuards = require(script.Parent.RemoteGuards)
local RemoteNames = require(script.Parent.RemoteNames)

local NetClient = {}

local WAIT_TIMEOUT_SECONDS = 10

local rootFolder = nil
local requestFolder = nil
local clientEventFolder = nil
local serverEventFolder = nil

local function waitForFolder(parent, folderName)
	local child = parent:WaitForChild(folderName, WAIT_TIMEOUT_SECONDS)
	if child == nil or not child:IsA("Folder") then
		error("Missing remote folder: " .. folderName, 3)
	end
	return child
end

--ReplicatedStorage/YanzoFrame_V1_StorageModule_Remotes
function NetClient.GetRemoteFolder()
	if rootFolder == nil then
		rootFolder = waitForFolder(ReplicatedStorage, RemoteNames.RootFolder)
	end
	return rootFolder
end

--ReplicatedStorage/YanzoFrame_V1_StorageModule_Remotes/ClientToServer/Requests
function NetClient.GetRequestFolder()
	if requestFolder == nil then
		local clientToServerFolder = waitForFolder(NetClient.GetRemoteFolder(), RemoteNames.ClientToServerFolder)
		requestFolder = waitForFolder(clientToServerFolder, RemoteNames.RequestFolder)
	end
	return requestFolder
end

function NetClient.GetClientEventFolder()
	if clientEventFolder == nil then
		local clientToServerFolder = waitForFolder(NetClient.GetRemoteFolder(), RemoteNames.ClientToServerFolder)
		clientEventFolder = waitForFolder(clientToServerFolder, RemoteNames.EventFolder)
	end
	return clientEventFolder
end

function NetClient.GetServerEventFolder()
	if serverEventFolder == nil then
		local serverToClientFolder = waitForFolder(NetClient.GetRemoteFolder(), RemoteNames.ServerToClientFolder)
		serverEventFolder = waitForFolder(serverToClientFolder, RemoteNames.EventFolder)
	end
	return serverEventFolder
end

function NetClient.Request(remoteName, payload)
	--校验 remoteName 是否是合法的 RemoteName
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")

	--10s内在ClientToServer/Request 下查找 remoteName 对应的 RemoteFunction
	local remote = NetClient.GetRequestFolder():WaitForChild(remoteName, WAIT_TIMEOUT_SECONDS)
	if remote == nil or not remote:IsA("RemoteFunction") then
		return NetResult.Err("REMOTE_NOT_FOUND", "Remote request is not available", {
			RemoteName = remoteName,
		})
	end

	local ok, result = pcall(function()
		--客户端调用服务端 RemoteFunction，并把 payload 发过去。
		return remote:InvokeServer(payload) --Framework.Ping:InvokeServer({})
		--[[
		所以完整链路是：
			客户端 remote:InvokeServer({})
			-> 服务端 remote.OnServerInvoke(player, {})
			-> 服务端 _handleRequest("Framework.Ping", handler, player, {})
			-> handler 返回普通表
			-> 服务端 NetResult.Ok 包装
			-> 返回给客户端
		]]
	end)

	if not ok then
		return NetResult.Err("INVOKE_FAILED", "Remote request failed", {
			RemoteName = remoteName,
		})
	end

	if NetResult.IsResult(result) then
		return result
	end

	return NetResult.Ok(result)
end

function NetClient.FireServer(remoteName, payload)
	--检查 Remote 名字是否合法
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")

	--在 ClientToServer/Event 下查找 remoteName 对应的 RemoteEvent
	local remote = NetClient.GetClientEventFolder():WaitForChild(remoteName, WAIT_TIMEOUT_SECONDS)
	if remote == nil or not remote:IsA("RemoteEvent") then
		error("Remote event is not available: " .. remoteName, 2)
	end

	remote:FireServer(payload) --客户端把 payload 发给服务端。
end

--客户端监听服务端发来的消息。
function NetClient.OnServerEvent(remoteName, callback)
	RemoteGuards.AssertRemoteName(remoteName, "remoteName")
	if type(callback) ~= "function" then
		error("callback must be a function", 2)
	end

	--在 ServerToClient/Event 下查找 remoteName 对应的 RemoteEvent
	local remote = NetClient.GetServerEventFolder():WaitForChild(remoteName, WAIT_TIMEOUT_SECONDS)
	if remote == nil or not remote:IsA("RemoteEvent") then
		error("Remote event is not available: " .. remoteName, 2)
	end

	--当服务端 FireClient 或 FireAllClients 时，客户端执行 callback。
	return remote.OnClientEvent:Connect(callback)
end

return NetClient
