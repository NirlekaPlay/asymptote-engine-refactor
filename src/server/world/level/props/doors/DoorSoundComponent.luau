--!strict

--[=[
	@class DoorSoundComponent
]=]
local DoorSoundComponent = {}
DoorSoundComponent.__index = DoorSoundComponent

export type DoorSoundComponent = typeof(setmetatable({} :: {
	soundOpen: Sound,
	soundClose: Sound,
	soundUnlock: Sound
}, DoorSoundComponent))

function DoorSoundComponent.new(
	soundOpen: Sound,
	soundClose: Sound,
	soundUnlock: Sound
): DoorSoundComponent
	return setmetatable({
		soundClose = soundClose,
		soundOpen = soundOpen,
		soundUnlock = soundUnlock
	}, DoorSoundComponent)
end

--

function DoorSoundComponent.onDoorOpened(self: DoorSoundComponent): ()
	self.soundOpen:Play()
end

function DoorSoundComponent.onDoorClosed(self: DoorSoundComponent): ()
	self.soundClose:Play()
end

function DoorSoundComponent.onDoorUnlocked(self: DoorSoundComponent): ()
	task.spawn(function()
		task.wait(0.3)
		self.soundUnlock:Play()
	end)
end

return DoorSoundComponent