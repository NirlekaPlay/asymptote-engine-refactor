--!strict

return function<T>(v: T): typeof(setmetatable({} :: { value: T }, { __mode = "v" }))
	return setmetatable({ value = v }, { __mode = "v" })
end