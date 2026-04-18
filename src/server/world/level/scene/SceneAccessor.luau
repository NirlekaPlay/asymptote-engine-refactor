--!strict

export type SceneAccessor = {
	evaluateExpression: (self: SceneAccessor, str: string) -> any,
	setState: (self: SceneAccessor, key: string, value: any) -> (),
	hasState: (self: SceneAccessor, state: string) -> (),
	getState: (self: SceneAccessor, state: string) -> any,
	subscribeExpressionChange: (self: SceneAccessor, expressionStr: string, callback: (any) -> ()) -> () -> (),
	getLocalizedStrings: (self: SceneAccessor) -> { [string]: string }
}

return nil