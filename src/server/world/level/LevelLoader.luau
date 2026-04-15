--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local EntityType = require(ServerScriptService.server.world.entity.registry.EntityType)
local Cell = require(ServerScriptService.server.world.level.cell.Cell)
local MissionSetupReader = require(ServerScriptService.server.world.level.mission.reading.MissionSetupReader)
local PropRegistry = require(ServerScriptService.server.world.level.props.registry.PropRegistry)
local Scene = require(ServerScriptService.server.world.level.scene.Scene)
local Clutter = require(ServerScriptService.server.world.level.scene.props.Clutter)
local LightingSetter = require(ServerScriptService.server.world.lighting.LightingSetter)

--[=[
	@class LevelLoader
]=]
local LevelLoader = {}

function LevelLoader.loadFromFolder(folder: Folder): Scene.Scene
	local missionSetupObj = LevelLoader.getAndParseMissionSetupModule(folder)
	local cellsConfigs = missionSetupObj.cells
	local cellsFolder = folder:FindFirstChild("Cells") :: Folder
	if cellsFolder and not cellsFolder:IsA("Folder") then
		cellsFolder = nil
	end

	local cells = LevelLoader.createCellsFromFolder(cellsConfigs, cellsFolder)

	if missionSetupObj.lightingSettings then
		LightingSetter.readConfig(missionSetupObj.lightingSettings)
	end

	local newScene = Scene.new(cells, missionSetupObj)
	newScene.stateController:setDerivedStates(missionSetupObj.globalsExpressionStrs)

	local propsFolder = folder:FindFirstChild("Props")
	if propsFolder and propsFolder:IsA("Folder") then
		LevelLoader.initializeProps(propsFolder, missionSetupObj, newScene)
	end

	local nodesFolder = folder:FindFirstChild("Nodes")
	if nodesFolder and nodesFolder:IsA("Folder") then
		newScene.navMesh:setPostsFromFolder(nodesFolder)
	end

	local npcsFolder = folder:FindFirstChild("Bots") or folder:FindFirstChild("Npcs")
	if npcsFolder and npcsFolder:IsA("Folder") then
		local function initNpc(inst: BoolValue): ()
			local npc = EntityType.NPC.create(newScene)
			for k, v in inst:GetAttributes() do
				npc:getWorldInstance():SetAttribute(k, v)
			end
			-- TODO: What is this bullshit.
			if npc.finalizeSpawn then
				npc:finalizeSpawn()
			end
			newScene:addFreshEntity(npc)
		end

		local function parseNpcs(folder: Folder): ()
			for _, child in folder:GetChildren() do
				if child:IsA("BoolValue") then
					initNpc(child)
				elseif child:IsA("Folder") then
					parseNpcs(child)
				else
					continue
				end
			end
		end

		parseNpcs(npcsFolder)
	end

	return newScene
end

function LevelLoader.getAndParseMissionSetupModule(sceneFolder: Folder)
	local missionSetupModule = sceneFolder:FindFirstChild("MissionSetup") :: ModuleScript?
	if not missionSetupModule or not missionSetupModule:IsA("ModuleScript") then
		error("Unable to initialize Mission: MissionSetup module not found in Level folder or is not a ModuleScript.")
	else
		return MissionSetupReader.read(missionSetupModule)
	end
end

function LevelLoader.initializeProps(propsFolder: Folder, missionSetupObj, newScene: Scene.Scene): ()
	local function proccessPlaceholders(placeholder: BasePart, passed: boolean, prop: Model & { Base: BasePart }): boolean
		if passed and prop then
			for attName, v in pairs(placeholder:GetAttributes()) do
				prop:SetAttribute(attName, v);
				(prop :: any).Base:SetAttribute(attName, v)
			end

			(prop :: any).Base.Size = placeholder.Size

			local tagAtt = prop:GetAttribute("Tag")
			if tagAtt and type(tagAtt) == "string" and tagAtt ~= "" then
				prop:AddTag(tagAtt)
			end

			local turnTransparent = prop:GetAttribute("Transparent") == true
			if turnTransparent then
				for _, child in prop:GetDescendants() do
					if child:IsA("BasePart") then
						child.Transparency = 1
					end
				end
			end
		else
			local tagAtt = placeholder:GetAttribute("Tag")
			if tagAtt and type(tagAtt) == "string" and tagAtt ~= "" then
				placeholder:AddTag(tagAtt)
			end
		end

		local handler = PropRegistry.getHandler(placeholder.Name)
		if handler then
			local success, returnedProp = handler:proccess(placeholder, prop, newScene)
			if returnedProp then
				newScene.propManager:addProp(returnedProp)
			end

			if success then
				return true
			end
		end

		return false
	end

	Clutter.replacePlaceholdersWithProps(
		propsFolder,
		missionSetupObj.colors,
		newScene,
		proccessPlaceholders
	)
end

function LevelLoader.createCellsFromFolder(parsedConfigs, cellsFolder: Folder?): {Cell.Cell}
	local cells: {Cell.Cell} = {}

	if not cellsFolder then
		return cells
	end

	for _, cellModel in cellsFolder:GetChildren() do
		local cell = {}
		cell.name = cellModel.Name
		cell.hasFloor = cellModel:FindFirstChild("Floor") ~= nil
		cell.locationStr = cellModel:GetAttribute("Location") :: string?
		cell.config = parsedConfigs[cellModel.Name] and parsedConfigs[cellModel.Name].config or nil

		local bounds = {}
		local boundsI = 0
		for _, part in cellModel:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end

			local type = part.Name
			if type ~= "Floor" and type ~= "Roof" then
				continue
			end

			local bound = {}
			bound.cframe = part.CFrame
			bound.size = part.Size
			bound.type = if type == "Floor" then Cell.BoundType.FLOOR else Cell.BoundType.ROOF

			boundsI += 1
			bounds[boundsI] = bound
		end

		cell.bounds = bounds
		table.insert(cells, cell)
	end

	return cells
end

return LevelLoader