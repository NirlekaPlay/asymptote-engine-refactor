--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerStatusRegistry = require(ServerScriptService.server.player.PlayerStatusRegistry)
local WorldInteractionPrompt = require(ServerScriptService.server.world.level.interaction.WorldInteractionPrompt)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)
local PlayerStatus = require(ReplicatedStorage.shared.player.PlayerStatus)
local PlayerStatusTypes = require(ReplicatedStorage.shared.player.PlayerStatusTypes)
local TriggerAttributes = require(ReplicatedStorage.shared.world.interaction.TriggerAttributes)

local ENUM_HOLD_STATUS = {
	NONE = 0,
	MINOR_SUSPICIOUS = 1,
	CRIMINAL_SUSPICIOUS = 2
}

local ENUM_INTERACTION_KEY = {
	PRIMARY = 0,
	SECONDARY = 1
}

local INTERACTION_KEYS_TO_KEYCODES = {
	[ENUM_INTERACTION_KEY.PRIMARY] = Enum.KeyCode.F,
	[ENUM_INTERACTION_KEY.SECONDARY] = Enum.KeyCode.G
}

local DEFAULT_ACTIVATION_DISTANCE = 5
local DEFAULT_HOLD_DUR = 0.3
local DEFAULT_OMNI_DIR = true
local DEFAULT_TITLE_KEY = "ui.prompt.interact"
local DEFAULT_SUBTITLE_KEY = ""
local DEFAULT_NORMAL_ID = Enum.NormalId.Left
local DEFAULT_HOLD_STATUS_EXPR = `{ENUM_HOLD_STATUS.NONE}`
local DEFAULT_SERVER_VISIBLE_EXPR = `true`
local DEFAULT_SERVER_ENABLED_EXPR = `true`
local DEFAULT_DISABLED_SUBTITLE = "'ui.prompt.cant_interact'"
local DEFAULT_DISABLED_TITLE = ""
local DEFAULT_CLIENT_VISIBLE_EXPR = ""
local DEFAULT_CLIENT_ENABLED_EXPR = ""
local DEFAULT_WORLD_OFFSET_BY = 0
local DEFAULT_REQUIRED_TOOLS = ""
local ATTACHMENT_NAME = "Trigger"

--[=[
	@class InteractionPromptBuilder

	Serves as a friendly way to create interaction prompts without directly creating attachments,
	setting attributes, or other manual stuff. As the creation of interaction prompts may change.
]=]
local InteractionPromptBuilder = {}
InteractionPromptBuilder.__index = InteractionPromptBuilder

export type InteractionPromptBuilder = typeof(setmetatable({} :: {
	scene: SceneAccessor.SceneAccessor,
	setAttributes: {
		activationDist: number,
		holdDur: number,
		omniDir: boolean,
		titleKey: string,
		subtitleKey: string,
		tag: string?,
		normalId: Enum.NormalId,
		interactKey: number,
		worldOffsetBy: number,
		requiredTools: string,
		--
		disabledTitleKey: string,
		--
		serverVisibleExpr: string,
		serverEnabledExpr: string,
		holdStatusExpr: string,
		disabledSubtitleExpr: string,
		clientVisibleExpr: string,
		clientEnabledExpr: string
	}
}, InteractionPromptBuilder))

function InteractionPromptBuilder.new(scene: SceneAccessor.SceneAccessor): InteractionPromptBuilder
	return setmetatable({
		scene = scene,
		setAttributes = {
			activationDist = DEFAULT_ACTIVATION_DISTANCE,
			holdDur = DEFAULT_HOLD_DUR,
			omniDir = DEFAULT_OMNI_DIR,
			titleKey = DEFAULT_TITLE_KEY,
			subtitleKey = DEFAULT_SUBTITLE_KEY,
			normalId = DEFAULT_NORMAL_ID,
			holdStatusExpr = DEFAULT_HOLD_STATUS_EXPR,
			interactKey = ENUM_INTERACTION_KEY.PRIMARY,
			worldOffsetBy = DEFAULT_WORLD_OFFSET_BY,
			requiredTools = DEFAULT_REQUIRED_TOOLS,
			tag = nil :: string?,
			--
			serverVisibleExpr = DEFAULT_SERVER_VISIBLE_EXPR,
			serverEnabledExpr = DEFAULT_SERVER_ENABLED_EXPR,
			disabledSubtitleExpr = DEFAULT_DISABLED_SUBTITLE,
			clientVisibleExpr = DEFAULT_CLIENT_VISIBLE_EXPR,
			--
			disabledTitleKey = DEFAULT_DISABLED_TITLE,
			clientEnabledExpr = DEFAULT_CLIENT_ENABLED_EXPR
		}
	}, InteractionPromptBuilder)
end

--[=[
	Returns a copy of this `InteractionPromptBuilder` instance.
]=]
function InteractionPromptBuilder.fork(self: InteractionPromptBuilder): InteractionPromptBuilder
	local newAttributes = {}

	for key, value in self.setAttributes :: { [string]: any } do
		newAttributes[key] = value
	end

	return setmetatable({
		scene = self.scene,
		setAttributes = newAttributes
	}, InteractionPromptBuilder) :: InteractionPromptBuilder
end

--[=[
	Sets the distance a player needs to be in order for the prompt to show.<p>
	Defaults to `5`.
]=]
function InteractionPromptBuilder.activationDistance(self: InteractionPromptBuilder, minDist: number): InteractionPromptBuilder
	self.setAttributes.activationDist = minDist
	return self
end

--[=[
	Sets which face of the prompt's parent part will be put on.
	Defaults to `Enum.Normalid.Left`.
]=]
function InteractionPromptBuilder.facing(self: InteractionPromptBuilder, normal: Enum.NormalId): InteractionPromptBuilder
	self.setAttributes.normalId = normal
	return self
end

--[=[
	Sets the amount of time in seconds needed to complete the interaction.<p>
	Defaults to `0.3`.
]=]
function InteractionPromptBuilder.holdDuration(self: InteractionPromptBuilder, holdDur: number): InteractionPromptBuilder
	self.setAttributes.holdDur = holdDur
	return self
end

--[=[
	Sets the status to give to the player when they are holding this prompt.
	Possible numbers for `value`:

	 * `0` No status is given.
	 * `1` Gives the **Minor Suspicious** status.
	 * `2` Gives the **Criminal Suspicious** status.

	Defaults to `0`.

	`valueExpr` must be an **Expression** returning one of these numbers.
]=]
function InteractionPromptBuilder.holdStatus(self: InteractionPromptBuilder, valueExpr: string): InteractionPromptBuilder
	self.setAttributes.holdStatusExpr = valueExpr
	return self
end

--[=[
	Sets if the prompt is omni directional or not. Which can be viewed from all angles.
	If `false`, the prompt will face its attachment's positive Z axis.<p>
	Defaults to `true`.
]=]
function InteractionPromptBuilder.omniDirectional(self: InteractionPromptBuilder, omniDir: boolean): InteractionPromptBuilder
	self.setAttributes.omniDir = omniDir
	return self
end

--[=[
	Sets the tag to this prompt that can be used for objectives.
	Defaults to none.
]=]
function InteractionPromptBuilder.tag(self: InteractionPromptBuilder, tagName: string): InteractionPromptBuilder
	self.setAttributes.tag = tagName
	return self
end

--[=[
	Sets the prompt's bigger text to state its action. Must be a key to a localized string.<p>
	Defaults to `ui.prompt.interact`.
]=]
function InteractionPromptBuilder.titleKey(self: InteractionPromptBuilder, titleKey: string): InteractionPromptBuilder
	self.setAttributes.titleKey = titleKey
	return self
end

--[=[
	Sets the prompt's smaller text to state the object its acting on. Must be a key to a localized string.<p>
	Defaults to an empty string.
]=]
function InteractionPromptBuilder.subtitleKey(self: InteractionPromptBuilder, subtitleKey: string): InteractionPromptBuilder
	self.setAttributes.subtitleKey = subtitleKey
	return self
end

--[=[
	Sets the key to interact with this prompt the **Primary Key**.<p>
	Defaults to the **Primary Key**.
]=]
function InteractionPromptBuilder.primaryInteractionKey(self: InteractionPromptBuilder): InteractionPromptBuilder
	self.setAttributes.interactKey = ENUM_INTERACTION_KEY.PRIMARY
	return self
end

--[=[
	Sets the key to interact with this prompt the **Secondary Key**.<p>
	Defaults to the **Primary Key**.
]=]
function InteractionPromptBuilder.secondaryInteractionKey(self: InteractionPromptBuilder): InteractionPromptBuilder
	self.setAttributes.interactKey = ENUM_INTERACTION_KEY.SECONDARY
	return self
end

--[=[
	Sets an **expression** that dictates if the prompt should be visible. Evaluated from the server.
]=]
function InteractionPromptBuilder.serverVisibleExpression(self: InteractionPromptBuilder, serverVisibleExpr: string): InteractionPromptBuilder
	self.setAttributes.serverVisibleExpr = serverVisibleExpr
	return self
end

--[=[
	Sets an **expression** that dictates if the prompt should be enabled. If the prompt is disabled,
	uses the prompt's disabled subtitle to tell the player why it is disabled.
]=]
function InteractionPromptBuilder.serverEnabledExpression(self: InteractionPromptBuilder, serverEnabledExpr: string): InteractionPromptBuilder
	self.setAttributes.serverEnabledExpr = serverEnabledExpr
	return self
end

--[=[
	Sets an **expression** returning a key to a localized string. If the prompt is disabled, the localized string
	returned by this expression is used to tell the player why it is disabled.
]=]
function InteractionPromptBuilder.disabledSubtitleExpr(self: InteractionPromptBuilder, disabledSubtitleExpr: string): InteractionPromptBuilder
	self.setAttributes.disabledSubtitleExpr = disabledSubtitleExpr
	return self
end

--[=[
	Sets an expression that is evaluated on the client and dictates if the prompt should be shown or not.<p>
	Defaults to an empty string.
]=]
function InteractionPromptBuilder.clientVisibleExpression(self: InteractionPromptBuilder, clientVisibleExpr: string): InteractionPromptBuilder
	self.setAttributes.clientVisibleExpr = clientVisibleExpr
	return self
end

--[=[
	Sets an expression that is evaluated on the client and dictates if the prompt should be interactable.<p>
	Defaults to an empty string.
]=]
function InteractionPromptBuilder.clientEnabledExpression(self: InteractionPromptBuilder, clientEnabledExpr: string): InteractionPromptBuilder
	self.setAttributes.clientEnabledExpr = clientEnabledExpr
	return self
end

--[=[
	Sets the bigger text that shows when this prompt is disabled. `disabledTitleKey` must be a localised string.<p>
	Defaults to an empty string.
]=]
function InteractionPromptBuilder.disabledTitleKey(self: InteractionPromptBuilder, disabledTitleKey: string): InteractionPromptBuilder
	self.setAttributes.disabledTitleKey = disabledTitleKey
	return self
end

--[=[
	Sets the offset of the attachment from the prompt's parent part.
	Defaults to 0.
]=]
function InteractionPromptBuilder.worldOffsetBy(self: InteractionPromptBuilder, offset: number): InteractionPromptBuilder
	self.setAttributes.worldOffsetBy = offset
	return self
end

--[=[
	Dictates wether or not this prompt will be enabled on the client if the player have any of the specific tools in
	`requiredToolsStr`, seperated by whitespace.
]=]
function InteractionPromptBuilder.requiredTools(self: InteractionPromptBuilder, requiredToolsStr: string): InteractionPromptBuilder
	self.setAttributes.requiredTools = requiredToolsStr
	return self
end

--

--[=[
	Builds and creates and returns an instance of `WorldInteractionPrompt`.
]=]
function InteractionPromptBuilder.create(self: InteractionPromptBuilder, parentPart: BasePart, givenAttachment: Attachment?): WorldInteractionPrompt.WorldInteractionPrompt
	local setAttributes = self.setAttributes
	local attachment = givenAttachment or InteractionPromptBuilder.createAttachmentAtNormal(parentPart, ATTACHMENT_NAME, setAttributes.normalId, setAttributes.worldOffsetBy)

	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.MaxActivationDistance = setAttributes.activationDist
	proximityPrompt.ActionText = setAttributes.titleKey
	proximityPrompt.ObjectText = setAttributes.subtitleKey
	proximityPrompt.ClickablePrompt = true
	proximityPrompt.HoldDuration = setAttributes.holdDur
	proximityPrompt.KeyboardKeyCode = INTERACTION_KEYS_TO_KEYCODES[setAttributes.interactKey]
	proximityPrompt.RequiresLineOfSight = true
	--proximityPrompt.Style = Enum.ProximityPromptStyle.Custom

	if setAttributes.tag then
		attachment:AddTag(setAttributes.tag)
	end

	attachment:SetAttribute(TriggerAttributes.OMNIDIRECTIONAL, setAttributes.omniDir)
	attachment:SetAttribute(TriggerAttributes.MIN_REQUIRED_TOOLS, setAttributes.requiredTools)

	--

	proximityPrompt.Parent = attachment
	local worldPrompt = WorldInteractionPrompt.new(proximityPrompt)

	local function bindAttributeToExpression(attrName: string, exprStr: string)
		local unsub = self.scene:subscribeExpressionChange(exprStr, function(newValue)
			attachment:SetAttribute(attrName, newValue)
		end)

		worldPrompt:getMaid():giveTask(unsub)
	end

	bindAttributeToExpression(TriggerAttributes.SERVER_VISIBLE, setAttributes.serverVisibleExpr)
	bindAttributeToExpression(TriggerAttributes.SERVER_ENABLED, setAttributes.serverEnabledExpr)
	bindAttributeToExpression(TriggerAttributes.DISABLED_SUBTITLE, setAttributes.disabledSubtitleExpr)

	attachment:SetAttribute(TriggerAttributes.DISABLED_TITLE, setAttributes.disabledTitleKey)
	attachment:SetAttribute(TriggerAttributes.CLIENT_VISIBLE, setAttributes.clientVisibleExpr)
	attachment:SetAttribute(TriggerAttributes.CLIENT_ENABLED, setAttributes.clientEnabledExpr)

	worldPrompt:getMaid():giveTask(attachment)

	-- TODO: This should be handled in the WorldProximityPrompt itself
	-- Considering it needs to evaluate an expression

	local setHoldStatusValue = tonumber(setAttributes.holdStatusExpr) :: number
	if setHoldStatusValue ~= ENUM_HOLD_STATUS.NONE then
		-- NOTES: Maybe clean up connections?
		-- I don't see why though, since most prompts are persistent and won't get destroyed anyway

		local giveStatus: PlayerStatus.PlayerStatus
		if setHoldStatusValue == ENUM_HOLD_STATUS.MINOR_SUSPICIOUS then
			giveStatus = PlayerStatusTypes.MINOR_SUSPICIOUS
		elseif setHoldStatusValue == ENUM_HOLD_STATUS.CRIMINAL_SUSPICIOUS then
			giveStatus = PlayerStatusTypes.CRIMINAL_SUSPICIOUS
		end

		worldPrompt:getMaid():giveTask(
			worldPrompt:getHoldBeganEvent():Connect(function(player)
				local playerStatus = PlayerStatusRegistry.getPlayerStatusHolder(player)
				if playerStatus then
					playerStatus:addStatus(giveStatus)
				end
			end)
		)

		worldPrompt:getMaid():giveTask(
			worldPrompt:getHoldEndedEvent():Connect(function(player)
				local playerStatus = PlayerStatusRegistry.getPlayerStatusHolder(player)
				if playerStatus then
					playerStatus:removeStatus(giveStatus)
				end
			end)
		)
	end

	return worldPrompt
end

--

function InteractionPromptBuilder.createAttachmentAtNormal(inst: BasePart, name: string, normalId: Enum.NormalId, frontOffset: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = inst

	local normalVector = Vector3.FromNormalId(normalId)
	local surfacePosition = (inst.Size * normalVector) / 2
	local offset = surfacePosition + (normalVector * frontOffset)

	attachment.CFrame = CFrame.lookAt(offset, offset + normalVector)
	
	return attachment
end

return InteractionPromptBuilder