--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TypedRemotes = require(ReplicatedStorage.shared.network.remotes.TypedRemotes)
local ParsedObjective = require(ServerScriptService.server.world.level.objectives.ParsedObjective)
local SceneAccessor = require(ServerScriptService.server.world.level.scene.SceneAccessor)

--[=[
	@class ObjectiveManager
]=]
local ObjectiveManager = {}
ObjectiveManager.__index = ObjectiveManager

export type ObjectiveManager = typeof(setmetatable({} :: {
	parsedObjectives: { [string]: { [number]: ParsedObjectiveEntry } },
	currentActiveObjectives: { [string]: { text: string, tag: string } },
	_unsubscribeFns: { () -> () },
}, ObjectiveManager))

export type RawObjectiveEntry = {
	Active: string,
	Text: string?,
	Tag: string?,
	Header: string?,
	SubState: { [number]: RawObjectiveEntry }?,
}

export type RawMissionSetupTable = { [string]: { [number]: RawObjectiveEntry } }

export type ParsedObjectiveEntry =
	ParsedObjective.ParsedObjective
	| {
		parsedObjective: ParsedObjective.ParsedObjective,
		SubState: { [number]: ParsedObjectiveEntry },
	}

function ObjectiveManager.new(): ObjectiveManager
	return setmetatable({
		parsedObjectives = {},
		currentActiveObjectives = {},
		_unsubscribeFns = {},
	}, ObjectiveManager)
end

function ObjectiveManager.fromMissionSetupTable(
	self: ObjectiveManager,
	missionTable: RawMissionSetupTable
)
	for headerName, objectiveList in missionTable do
		if typeof(objectiveList) == "table" and headerName ~= "Timer" then
			local parsedList: { [number]: ParsedObjectiveEntry } = {}
			for i, rawEntry in objectiveList do
				parsedList[i] = ObjectiveManager.parseObjectiveEntry(rawEntry)
			end
			self.parsedObjectives[headerName] = parsedList
		end
	end
end

function ObjectiveManager.parseObjectiveEntry(rawEntry: RawObjectiveEntry): ParsedObjectiveEntry
	if rawEntry.SubState then
		local subStateTable: { [number]: ParsedObjectiveEntry } = {}
		for i, subEntry in rawEntry.SubState do
			subStateTable[i] = ObjectiveManager.parseObjectiveEntry(subEntry)
		end
		return {
			parsedObjective = ParsedObjective.new(
				rawEntry.Active,
				rawEntry.Tag or "",
				rawEntry.Text or ""
			),
			SubState = subStateTable,
		}
	else
		return ParsedObjective.new(
			rawEntry.Active,
			rawEntry.Tag or "",
			rawEntry.Text or ""
		)
	end
end

function ObjectiveManager._collectAllConditionExpressions(
	self: ObjectiveManager
): { string }
	local seen: { [string]: true } = {}
	local result: { string } = {}

	local function walk(list: { [number]: ParsedObjectiveEntry })
		for _, entry in list do
			local isSubState = (entry :: any).SubState ~= nil
			if isSubState then
				local sub = entry :: { parsedObjective: ParsedObjective.ParsedObjective, SubState: { [number]: ParsedObjectiveEntry } }
				local expr = sub.parsedObjective:getConditionExpressionString()
				if not seen[expr] then
					seen[expr] = true
					table.insert(result, expr)
				end
				walk(sub.SubState)
			else
				local obj = entry :: ParsedObjective.ParsedObjective
				local expr = obj:getConditionExpressionString()
				if not seen[expr] then
					seen[expr] = true
					table.insert(result, expr)
				end
			end
		end
	end

	for _, objectiveList in self.parsedObjectives do
		walk(objectiveList)
	end

	return result
end

function ObjectiveManager.subscribe(
	self: ObjectiveManager,
	scene: SceneAccessor.SceneAccessor
): () -> ()
	self:unsubscribe()

	local function onAnyConditionChanged(_newValue: any)
		local displayData = self:getDisplayedObjectives(scene)
		if self:objectivesHaveChanged(displayData) then
			self.currentActiveObjectives = displayData
			self:sendCurrentObjectivesToClients()
		end
	end

	-- Also subscribe to tag expressions so displayed tag strings stay current
	local expressions = self:_collectAllConditionExpressions()

	for _, expr in expressions do
		if expr ~= "" then
			local unsub = scene:subscribeExpressionChange(expr, onAnyConditionChanged)
			table.insert(self._unsubscribeFns, unsub)
		end
	end

	-- Run an initial evaluation immediately so state is correct on load
	onAnyConditionChanged(nil)

	return function()
		self:unsubscribe()
	end
end

function ObjectiveManager.unsubscribe(self: ObjectiveManager)
	for _, fn in self._unsubscribeFns do
		fn()
	end
	table.clear(self._unsubscribeFns)
end

--

function ObjectiveManager.objectivesHaveChanged(
	self: ObjectiveManager,
	newObjectives: { [string]: { text: string, tag: string } }
): boolean
	for headerName in newObjectives do
		if not self.currentActiveObjectives[headerName] then
			return true
		end
	end
	for headerName in self.currentActiveObjectives do
		if not newObjectives[headerName] then
			return true
		end
	end
	for headerName, newData in newObjectives do
		local currentData = self.currentActiveObjectives[headerName]
		if currentData.text ~= newData.text or currentData.tag ~= newData.tag then
			return true
		end
	end
	return false
end

function ObjectiveManager.sendCurrentObjectivesToClients(self: ObjectiveManager): ()
	TypedRemotes.ClientBoundObjectivesInfo:FireAllClients(self.currentActiveObjectives)
end

function ObjectiveManager.sendCurrentObjectivesToPlayer(self: ObjectiveManager, player: Player): ()
	TypedRemotes.ClientBoundObjectivesInfo:FireClient(player, self.currentActiveObjectives)
end

function ObjectiveManager.sendEmptyObjectivesToClients(self: ObjectiveManager): ()
	TypedRemotes.ClientBoundObjectivesInfo:FireAllClients({})
end

function ObjectiveManager.getActiveObjectiveByFirstValid(
	self: ObjectiveManager,
	objectiveList: { [number]: ParsedObjectiveEntry },
	scene: SceneAccessor.SceneAccessor
): (string?, string?)
	for _, entry in objectiveList do
		local isSubState = ((entry :: any).SubState ~= nil)

		if isSubState then
			local subStateEntry = entry :: {
				parsedObjective: ParsedObjective.ParsedObjective,
				SubState: { [number]: ParsedObjectiveEntry },
			}

			if subStateEntry.parsedObjective:evaluateCondition(scene) then
				local textKey, tagStr =
					self:getActiveObjectiveByFirstValid(subStateEntry.SubState, scene)
				if textKey then
					return textKey, tagStr
				end
			end
		else
			local parsedObjective = entry :: ParsedObjective.ParsedObjective

			if parsedObjective:evaluateCondition(scene) then
				local textKey = parsedObjective:getLocalizedTextKey()
				local tagStr = parsedObjective:evaluateTag(scene)

				if textKey and textKey ~= "" then
					return textKey, tagStr
				end
			end
		end
	end

	return nil, nil
end

function ObjectiveManager.getDisplayedObjectives(
	self: ObjectiveManager,
	scene: SceneAccessor.SceneAccessor
): { [string]: { text: string, tag: string } }
	local displayData: { [string]: { text: string, tag: string } } = {}

	for headerName, objectiveList in self.parsedObjectives do
		local textKey, tagStr = self:getActiveObjectiveByFirstValid(objectiveList, scene)

		if textKey and tagStr then
			displayData[headerName] = { text = textKey, tag = tagStr }
		end
	end

	return displayData
end

return ObjectiveManager