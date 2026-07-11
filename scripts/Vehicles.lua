-- Required scripts
local parts   = require("lib.PartsAPI")
local carrier = require("lib.GSCarrier")

-- GSCarrier rider
carrier.rider.addRoots(models)
carrier.rider.addTag("gscarrier:taur")
carrier.rider.controller.setGlobalOffset(vec(0, -10, 0))
carrier.rider.controller.setModifyCamera(false)
carrier.rider.controller.setModifyEye(false)
carrier.rider.controller.setAimEnabled(false)

-- GSCarrier vehicle
carrier.vehicle.addTag("gscarrier:taur", "gscarrier:land", "gscarrier:water")

-- Seat 1
carrier.vehicle.newSeat("Seat1", parts.group.Seat1, {
	priority = 1,
	tags = {["gscarrier:flat"] = true}
})

function events.TICK()
	
	-- Variables
	local vehicle = player:getVehicle() or false
	local type    = vehicle and vehicle:getType() or ""
	
	-- Vehicle renders/part toggle
	renderer:setRenderVehicle(not type:find("boat"))
	
	-- Redirect all passengers to pivots if vehicle is a boat
	carrier.vehicle.setRedirect(type:find("boat"))
	
end