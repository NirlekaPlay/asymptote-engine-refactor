--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Prop = require(ServerScriptService.server.world.level.props.Prop)
local PropHandlerBuilder = require(ServerScriptService.server.world.level.props.registry.PropHandlerBuilder)
local PropSceneAccessor = require(ServerScriptService.server.world.level.scene.props.PropSceneAccessor)

--[=[
	@class TriggerZone

	Sets a state to the number of players in a zone.
]=]
local TriggerZone = {}
TriggerZone.__index = TriggerZone

type Self = Prop.Fields & {
	activeExpStr: string?,
	targetVarName: string,
	zonePart: BasePart
}

export type TriggerZone = Prop.Prop & typeof(setmetatable({} :: Self, TriggerZone))

type PropSceneAccessor = PropSceneAccessor.PropSceneAccessor

function TriggerZone.new(id: number, zonePart: BasePart, activeExpStr: string?, varName: string): TriggerZone
	local self: Self = {
		id = id,
		updatesPerSec = nil :: number?,
		_elapsed = 0,
		--
		activeExpStr = activeExpStr,
		targetVarName = varName,
		zonePart = zonePart
	}

	return (setmetatable(self, TriggerZone) :: any) :: TriggerZone
end

function TriggerZone.handler()
	return PropHandlerBuilder.new()
		:onProccess(function(placeholder: BasePart, prop: Model?, scene)
			local expressionStr = placeholder:GetAttribute("Active") :: string
			local targetVariableName = placeholder:GetAttribute("Variable") :: string

			if expressionStr == "" then
				expressionStr = nil
			end

			TriggerZone.makePartStatic(placeholder)

			return true, TriggerZone.new(0, placeholder, expressionStr, targetVariableName)
		end)
		:build()
end

--

function TriggerZone.update(self: TriggerZone, deltaTime: number, scene: PropSceneAccessor): ()
	local canCheck = false
	if self.activeExpStr == nil then
		canCheck = true
	else
		local evaluated = scene:evaluateExpression(self.activeExpStr)

		canCheck = not not evaluated -- don't ask.
	end

	if not canCheck then
		return
	end

	local playersInZone = 0

	for _, player in Players:GetPlayers() do
		local playerPos = TriggerZone.getPlayerPos(player)
		if not playerPos then
			continue
		end

		local isInZone = TriggerZone.isPosInPart(playerPos, self.zonePart)
		if isInZone then
			playersInZone += 1
		end
	end

	scene:setState(self.targetVarName, playersInZone)
end

function TriggerZone.restart(self: TriggerZone): ()
	return
end

function TriggerZone.destroy(self: TriggerZone): ()
	return
end

--

function TriggerZone.makePartStatic(part: BasePart): ()
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.AudioCanCollide = false
end

function TriggerZone.getPlayerPos(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return nil
	end

	return humanoidRootPart.Position
end

function TriggerZone.isPosInPart(pos: Vector3, part: BasePart): boolean
	local v3 = part.CFrame:PointToObjectSpace(pos)
	return (math.abs(v3.X) <= part.Size.X / 2)
		and (math.abs(v3.Y) <= part.Size.Y / 2)
		and (math.abs(v3.Z) <= part.Size.Z / 2)
end

return TriggerZone