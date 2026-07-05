--!strict
--统一网络请求的返回格式。
local NetResult = {}

--表示一个成功的结果，数据放在 Data 里。
function NetResult.Ok(data)
	return {
		Ok = true,
		Data = data,
	}
end

--表示一个失败的结果，携带错误码、错误信息和可选数据。
function NetResult.Err(code, message, data)
	return {
		Ok = false,
		Code = code,
		Message = message,
		Data = data,
	}
end

--只检查一件事：value 是不是表，并且 value.Ok 是不是布尔值。
function NetResult.IsResult(value)
	return type(value) == "table" and type(value.Ok) == "boolean"
end

return NetResult
