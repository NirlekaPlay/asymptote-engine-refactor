--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maid = require(ReplicatedStorage.shared.util.misc.Maid)

local TWEEN_RATE = 0.5

local function isValidPart(inst: Instance)
	if not (inst:IsA("BasePart") or inst:IsA("Decal")) then return false end
	if inst:FindFirstAncestorOfClass("Tool") then return false end
	return true
end

--[=[
	@class TransparencyController
]=]
local TransparencyController = {}
TransparencyController.__index = TransparencyController

export type TransparencyController = typeof(setmetatable({} :: {
	characterHidden: boolean,
	partsCache: { [Instance]: true },
	partsCacheDirty: { [Instance]: true },
	maid: Maid.Maid
}, TransparencyController))

function TransparencyController.new(): TransparencyController
	return setmetatable({
		characterHidden = false,
		partsCache = {},
		partsCacheDirty = {},
		maid = Maid.new()
	}, TransparencyController)
end

--

function TransparencyController.show(self: TransparencyController): ()
	self.characterHidden = false
end

function TransparencyController.hide(self: TransparencyController): ()
	self.characterHidden = true
end

--

function TransparencyController.setCharacter(self: TransparencyController, character: Model?): ()
	self.maid:doCleaning()
	table.clear(self.partsCache)
	table.clear(self.partsCacheDirty)

	if not character then
		return
	end

	for _, inst in character:GetDescendants() do
		if isValidPart(inst) then
			self.partsCache[inst] = true
		end
	end

	self.maid:giveTask(character.DescendantRemoving:Connect(function(instance)
		if self.partsCache[instance] then
			self.partsCacheDirty[instance] = nil
		end
	end))

	self.maid:giveTask(character.DescendantAdded:Connect(function(instance)
		if isValidPart(instance) then
			self.partsCache[instance] = true
			self.partsCacheDirty[instance] = nil
		end
	end))

	self.maid:giveTask(character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			self:setCharacter(nil)
		end
	end))
end

function TransparencyController.update(self: TransparencyController, deltaTime: number): ()
	local targetTransparency = self.characterHidden and 1 or 0
	local step = TWEEN_RATE * deltaTime * 60

	for inst in self.partsCache do

		if self.partsCacheDirty[inst] then
			self.partsCache[inst] = nil
			self.partsCacheDirty[inst] = nil
			continue
		end

		if inst:IsA("BasePart") or inst:IsA("Decal") then
			inst.LocalTransparencyModifier = inst.LocalTransparencyModifier
				+ (targetTransparency - inst.LocalTransparencyModifier) * step
		end
	end
end

function TransparencyController.destroy(self: TransparencyController): ()
	self.maid:doCleaning()
end

return TransparencyController