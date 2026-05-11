--!strict

export type StateComponentType<T> = {
	name: string,
	isInstanceOf: (component: any) -> boolean
}

return nil