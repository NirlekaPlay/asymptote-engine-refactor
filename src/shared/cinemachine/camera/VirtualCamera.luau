--!strict

--[=[
	@class VirtualCamera
]=]
local VirtualCamera = {}
VirtualCamera.__index = VirtualCamera

export type VirtualCamera = typeof(setmetatable({} :: {
	cframe: CFrame,
	priority: number
}, VirtualCamera))

function VirtualCamera.new(): VirtualCamera
	return setmetatable({
		cframe = CFrame.new(),
		priority = 0
	}, VirtualCamera)
end

--

function VirtualCamera.setCFrame(self: VirtualCamera, cframe: CFrame): ()
	self.cframe = cframe
end

function VirtualCamera.setPriority(self: VirtualCamera, priority: number): ()
	self.priority = priority
end

return VirtualCamera