--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local en_us = require(ReplicatedStorage.shared.assets.lang["en-us"])

--[=[
	@class I18n
]=]
local I18n = {}

local default: { [string]: string } = en_us :: any
local sceneOverrides: { [string]: string } = {}

function I18n.t(key: string, params: { any }?): string
	local str: string = sceneOverrides[key] or default[key] or key

	if params then
		str = str:gsub("{(%w+)}", function(token)
			return tostring(params[token] or "{" .. token .. "}")
		end)
	end

	return str
end

function I18n.loadTopLocalizationLayer(sceneLocale)
	sceneOverrides = sceneLocale
end

function I18n.unloadTopLocalizationLayer()
	sceneOverrides = {}
end

return I18n