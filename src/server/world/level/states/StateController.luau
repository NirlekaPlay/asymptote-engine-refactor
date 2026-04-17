--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ASTNode = require(ReplicatedStorage.shared.expression.ASTNode)
local ExpressionContext = require(ReplicatedStorage.shared.expression.ExpressionContext)
local ExpressionEvaluationSorter = require(ReplicatedStorage.shared.expression.ExpressionEvaluationSorter)
local ExpressionParser = require(ReplicatedStorage.shared.expression.ExpressionParser)

--[=[
	@class StateController

	# States
	Level states is basically a giant dictionary.

	Fig. 1.
	```json
	{
		"DeanDead": "AssTargetDeathCounter > 0",
		"MissionComplete": "DeanDead && !Mission_AlarmRaised"
	}
	```

	## How states are born
	There are two ways a state can be set:
	 * **Set States.** States that are externally set, for exmaple by a Prop or a StateComponent. They do not listen for changes.
	 for example a `TriggerZone` prop is set to increment the state `EntitiesInOffice` whenever an entity enters.
	 * **Derived States.** States that are explictly defined in **MissionSetup** *(fig. 1.).* They listen to changes whenever one of the
	 states in the expression changes.
]=]
local StateController = {}
StateController.__index = StateController

export type StateController = typeof(setmetatable({} :: {
	rawStates: { [string]: any },
	derivedStates: { [string]: any },
	derivedEntries: { [string]: DerivedEntry },
	topoOrder: { string },
	adjacency: { [string]: { string } },   -- usedVar -> dependents

	pendingRawSets: { [string]: any },
	isTicking: boolean,
	dirtyDerived: { [string]: true },
	watchersByVar: { [string]: { [ExpressionWatcher]: boolean } },
	context: ExpressionContext.ExpressionContext
}, StateController))

export type DerivedEntry = {
	parsed: ASTNode.ASTNode,
	usedVariables: { [string]: true },
	isDirty: boolean,
}

export type ExpressionWatcher = {
	expression: string,
	parsed: ASTNode.ASTNode?,
	usedVariables: { [string]: true },
	callback: (newValue: any) -> (),
	lastValue: any,
}

function StateController.new(): StateController
	local self = {
		rawStates = {},
		derivedStates = {},
		derivedEntries = {},
		topoOrder = {},
		adjacency = {},

		pendingRawSets = {},
		isTicking = false,
		dirtyDerived = {},
		watchersByVar = {}
	}

	-- Metatable black magic to merge both derived and set states for the context
	local mergedView = setmetatable({}, {
		__index = function(_, key)
			local d = self.derivedStates[key]
			if d ~= nil then
				return d
			end
			return self.rawStates[key]
		end,
		__tostring = function()
			return "<MergedReferenceTable>"
		end
	})

	self.context = ExpressionContext.new(mergedView)

	return setmetatable(self, StateController) :: StateController
end

--

function StateController.subscribeExpressionChange(self: StateController, expressionStr: string, callback: (any) -> ()): () -> ()
	local parsed = ExpressionParser.fromString(expressionStr):parse()
	local usedVars = if parsed then ExpressionParser.getVariablesSet(parsed) else {}
	
	local watcher: ExpressionWatcher = {
		expression = expressionStr,
		parsed = parsed,
		usedVariables = usedVars,
		callback = callback,
		lastValue = self:evaluateExpression(expressionStr)
	}

	-- task.spawn(callback, watcher.lastValue) -- ???? Should we? Nahhh

	for varName in usedVars do
		if not self.watchersByVar[varName] then
			self.watchersByVar[varName] = {}
		end
		self.watchersByVar[varName][watcher] = true
	end

	-- Unsubscribe function
	return function()
		for varName in usedVars do
			if self.watchersByVar[varName] then
				self.watchersByVar[varName][watcher] = nil
			end
		end
	end
end

--

function StateController.setDerivedStates(self: StateController, states: { [string]: string }): ()
	table.clear(self.adjacency)

	local adjacency: { [string]: { string } }  = {}
	local entries: { string } = {}
	local derivedNames: { [string]: boolean } = {}
	local expressions: { [string]: DerivedEntry } = {}

	for varName, varExpr in states do
		table.insert(entries, varName)
		derivedNames[varName] = true
		adjacency[varName] = {}

		local parsed = ExpressionParser.fromString(varExpr):parse()
		local usedVars = if parsed then ExpressionParser.getVariablesSet(parsed) else {}
		expressions[varName] = { parsed = parsed, usedVariables = usedVars } :: any
	end

	-- gets an edge usedVar -> varName ("varName depends on usedVar")
	for varName, entry in expressions do
		for usedVarName in entry.usedVariables do
			if derivedNames[usedVarName] and usedVarName ~= varName then
				table.insert(adjacency[usedVarName], varName)
			end
		end
	end

	for varName, entry in expressions do
		for usedVarName in entry.usedVariables do
			if not derivedNames[usedVarName] then
				-- raw -> derived edge
				if not self.adjacency[usedVarName] then
					self.adjacency[usedVarName] = {}
				end
				table.insert(self.adjacency[usedVarName], varName)
			end
		end
	end

	local topoOrder = ExpressionEvaluationSorter.kahnsTopologicalSort(entries, adjacency)
	assert(topoOrder, "Cycle detected in derived state expressions!")

	for usedVar, dependents in adjacency do
		if not self.adjacency[usedVar] then
			self.adjacency[usedVar] = {}
		end
		for _, dep in dependents do
			table.insert(self.adjacency[usedVar], dep)
		end
	end

	self.derivedEntries = expressions
	self.topoOrder = topoOrder

	-- Mark everything dirty so first tick initialises all derived values
	for varName in expressions do
		self.dirtyDerived[varName] = true
	end
end

function StateController.evaluateExpression(self: StateController, str: string): any
	return ExpressionParser.evaluate(ExpressionParser.fromString(str):parse(), self.context)
end

function StateController.setState(self: StateController, key: string, value: any)
	--[[if self.isTicking then
		self.pendingRawSets[key] = value -- deferred to next tick
		return
	end
	self.rawStates[key] = value
	self:markDependentsDirty(key)]]
	self.pendingRawSets[key] = value
end

function StateController.getState(self: StateController, key: string): any
	local d = self.derivedStates[key]
	if d ~= nil then
		return d
	end
	return self.rawStates[key]
end

function StateController.hasState(self: StateController, key: string): boolean
	return self.rawStates[key] ~= nil or self.derivedStates[key] ~= nil
end

function StateController.getOrElseSet<T>(self: StateController, key: string, default: T): T
	if not self:hasState(key) and default ~= nil then
		self:setState(key, default)
		return default
	else
		return self:getState(key)
	end
end

function StateController.markDependentsDirty(self: StateController, changedKey: string)
	local deps = self.adjacency[changedKey]
	if deps then
		for _, depName in deps do
			self.dirtyDerived[depName] = true
		end
	end
end

function StateController.tick(self: StateController): ()
	self.isTicking = true

	local watchersToCheck = {} :: { [ExpressionWatcher]: boolean }

	local function markWatchers(key: string)
		if self.watchersByVar[key] then
			for watcher in self.watchersByVar[key] do
				watchersToCheck[watcher] = true
			end
		end
	end

	for key, value in self.pendingRawSets do
		self.rawStates[key] = value
		self:markDependentsDirty(key)
		markWatchers(key)
	end
	table.clear(self.pendingRawSets)

	local changed: { [string]: any } = {}
	for _, varName in self.topoOrder do
		if not self.dirtyDerived[varName] then continue end
		
		local entry = self.derivedEntries[varName]
		local newVal = ExpressionParser.evaluate(entry.parsed, self.context)
		
		if newVal ~= self.derivedStates[varName] then
			self.derivedStates[varName] = newVal
			changed[varName] = newVal
			self:markDependentsDirty(varName) -- cascade within same tick
			markWatchers(varName)
		end
		
		self.dirtyDerived[varName] = nil
	end

	for watcher in watchersToCheck do
		local newVal = ExpressionParser.evaluate(watcher.parsed, self.context)
		if newVal ~= watcher.lastValue then
			watcher.lastValue = newVal
			watcher.callback(newVal)
		end
	end

	self.isTicking = false
end

--

function StateController.clear(self: StateController): ()
	table.clear(self.rawStates)
	table.clear(self.derivedStates)
	table.clear(self.derivedEntries)
	table.clear(self.topoOrder)
	table.clear(self.adjacency)
	table.clear(self.pendingRawSets)
	table.clear(self.dirtyDerived)
	self.isTicking = false
end

return StateController