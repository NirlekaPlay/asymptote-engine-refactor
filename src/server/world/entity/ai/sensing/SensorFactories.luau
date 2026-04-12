--!nonstrict

local HearingPlayersSensor = require(script.Parent.HearingPlayersSensor)
local SensorFactory = require(script.Parent.SensorFactory)
local VisibleEntitiesSensor = require(script.Parent.VisibleEntitiesSensor)

return {
	VISIBLE_ENTITIES_SENSOR = SensorFactory.new(VisibleEntitiesSensor.new),
	HEARING_PLAYERS_SENSOR = SensorFactory.new(HearingPlayersSensor.new)
}