--!strict

local ATTRIBUTE_NAME = "FaceState"

--[=[
	@class ServerFaceControl

	Server-side mirror of FaceControl. Instead of manipulating decals directly
	(which would require replication plumbing), it writes a serialised state
	attribute onto the character's Head part. A client-side listener reads that
	attribute and drives the actual decals.

	Attribute schema (JSON-encoded string on Head["FaceState"]):
	{
		faceAlias: string,              -- e.g. "Neutral", "Angry"
		eyesAlias: string?,             -- "Open" | "Closed" | nil (inherit from faceAlias)
		mouthOverride: number? | false  -- assetId override, false = reset to expression
	}
]=]
local ServerFaceControl = {}
ServerFaceControl.__index = ServerFaceControl

export type ServerFaceControl = typeof(setmetatable({} :: {
	head: BasePart,
	_faceAlias: string,
	_eyesAlias: string?,
	_mouthOverride: number? | boolean,
}, ServerFaceControl))

type FaceAlias = "Neutral" | "Shocked" | "Angry" | "Unconscious" | "None"
type EyesAlias = "Open" | "Closed"
type Phoneme   = "A" | "E" | "O" | "M" | "L"

-- TODO: Should be exchangeable by face pack
local LIPSYNC_ASSET_MAP: { [string]: number } = {
	["A"] = 9806566637,
	["E"] = 9806566055,
	["O"] = 13670499760,
	["M"] = 9806565498,
	["L"] = 9806561846,
}

local function encode(self: ServerFaceControl): string
	local mouthField: string
	if self._mouthOverride == false then
		mouthField = '"mouthOverride":false'
	elseif self._mouthOverride ~= nil then
		mouthField = string.format('"mouthOverride":%d', self._mouthOverride :: number)
	else
		mouthField = '"mouthOverride":null'
	end

	local eyesField = self._eyesAlias and string.format('"eyesAlias":"%s"', self._eyesAlias) or '"eyesAlias":null'

	return string.format('{"faceAlias":"%s",%s,%s}', self._faceAlias, eyesField, mouthField)
end

local function flush(self: ServerFaceControl)
	self.head:SetAttribute(ATTRIBUTE_NAME, encode(self))
end

function ServerFaceControl.new(character: Model): ServerFaceControl
	local head = character:FindFirstChild("Head") :: BasePart
	assert(head, "ServerFaceControl: character has no Head")

	local self = setmetatable({}, ServerFaceControl)
	self.head = head
	self._faceAlias = "None"
	self._eyesAlias = nil :: string?
	self._mouthOverride = nil :: number? | boolean

	flush(self)
	return self
end

function ServerFaceControl.setFace(self: ServerFaceControl, faceAlias: FaceAlias)
	self._faceAlias = faceAlias
	self._eyesAlias = nil
	self._mouthOverride = nil
	flush(self)
end

function ServerFaceControl.setEyesAlias(self: ServerFaceControl, eyesAlias: EyesAlias)
	self._eyesAlias = eyesAlias
	flush(self)
end

function ServerFaceControl.setMouth(self: ServerFaceControl, assetId: number?)
	self._mouthOverride = if assetId ~= nil then assetId else false
	flush(self)
end

function ServerFaceControl.setMouthPhoneme(self: ServerFaceControl, phonemeKey: Phoneme)
	local assetId = LIPSYNC_ASSET_MAP[phonemeKey]
	if assetId then
		self._mouthOverride = assetId
	else
		self._mouthOverride = false
	end
	flush(self)
end

function ServerFaceControl.resetEyesToExpression(self: ServerFaceControl)
	self._eyesAlias = nil
	flush(self)
end

function ServerFaceControl.resetMouthToExpression(self: ServerFaceControl)
	self._mouthOverride = false
	flush(self)
end

return ServerFaceControl