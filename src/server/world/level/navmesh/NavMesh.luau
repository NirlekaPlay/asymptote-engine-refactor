--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Node = require(ServerScriptService.server.world.level.navmesh.Node)

--[=[
	@class NavMesh
]=]
local NavMesh = {}
NavMesh.__index = NavMesh

export type NavMesh = typeof(setmetatable({} :: {
	registry: {[Instance]: Node.Node},
	groups: {[string]: {Node.Node}}
}, NavMesh))

function NavMesh.new(): NavMesh
	return setmetatable({
		registry = {},
		groups = {}
	}, NavMesh)
end

--

function NavMesh.getPostGroup(self: NavMesh, groupName: string): {Node.Node}
	return self.groups[groupName] or {}
end

--

function NavMesh.setPostsFromFolder(self: NavMesh, nodesFolder: Folder, destroyPlaceholder: boolean?): ()
	table.clear(self.registry)
	table.clear(self.groups)

	destroyPlaceholder = destroyPlaceholder or true

	local stack: {{folder: Folder, groupName: string}} = {{folder = nodesFolder, groupName = nodesFolder.Name}}
	local top = 1

	while top > 0 do
		local entry = stack[top]
		top -= 1

		local folder = entry.folder
		local groupName = entry.groupName

		if not self.groups[groupName] then
			self.groups[groupName] = {}
		end

		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				if not self.registry[child] then
					self.registry[child] = Node.new(child.CFrame)
				end
				table.insert(self.groups[groupName], self.registry[child])
				child:Destroy()
			elseif child:IsA("Folder") then
				top += 1
				stack[top] = {folder = child, groupName = child.Name}
			end
		end
	end
end

return NavMesh