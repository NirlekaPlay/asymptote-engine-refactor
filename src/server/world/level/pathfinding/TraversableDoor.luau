--!strict

export type TraversableDoor = {
	open: (self: TraversableDoor, side: number, overrideLock: boolean?) -> (),
	close: (self: TraversableDoor) -> (),
	getSideRelativeTo: (self: TraversableDoor, pos: Vector3) -> number,
	isClosed: (self: TraversableDoor) -> boolean,
	isClosing: (self: TraversableDoor) -> boolean
}

return nil