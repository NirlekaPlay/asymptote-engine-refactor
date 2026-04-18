--!strict

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TypedRemotes = require(ReplicatedStorage.shared.network.remotes.TypedRemotes)
local I18n = require(StarterPlayer.StarterPlayerScripts.client.modules.resources.language.I18n)

LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function(...)
	print("Language changed", ...)
end)

TypedRemotes.ClientboundLocalizationAppend.OnClientEvent:Connect(function(lang: { [string]: string })
	if next(lang) ~= nil then
		I18n.loadTopLocalizationLayer(lang)
	else
		I18n.unloadTopLocalizationLayer()
	end
end)