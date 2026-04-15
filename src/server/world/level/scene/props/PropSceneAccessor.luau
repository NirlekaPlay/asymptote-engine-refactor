--!strict

export type PropSceneAccessor = {
	evaluateExpression: (self: PropSceneAccessor, str: string) -> any,
	setState: (self: PropSceneAccessor, key: string, value: any) -> ()
}

return nil