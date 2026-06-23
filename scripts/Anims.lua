-- Required scripts
require("lib.GSAnimBlend")
require("lib.Molang")
local parts = require("lib.PartsAPI")
local sync  = require("lib.LetThatSyncFig")
local lerp  = require("lib.LerpAPI")
local pose  = require("scripts.Posing")

-- Animations setup
local anims = animations.Turtle

-- Synced variables setup
local armsMove = sync.new("AnimsArms", false):config()

-- Lean setup
local leanParts = {
	parts.group.UpperBody,
	parts.group.Neck
}
local leanOffsetParts = {
	parts.group.Head,
	parts.group.LeftArm,
	parts.group.RightArm
}

-- Lean setup
local lean = lerp.new(vec(0, 0, 0), 0.2)

-- Arms setup
local leftArmLerp  = lerp.new(armsMove.curr and 1 or 0, 0.5)
local rightArmLerp = lerp.new(armsMove.curr and 1 or 0, 0.5)

-- Gets the origin rotation of a part, clamped
local function getOriginRot(part)
	return (vanilla_model[part]:getOriginRot() + 180) % 360 - 180
end

function events.TICK()
	
	-- Variables
	local vel = player:getVelocity()
	local yaw = player:getBodyYaw()
	local dir = vec(math.sin(math.rad(-yaw)), 0, math.cos(math.rad(-yaw)))
	local headRot = getOriginRot("HEAD")
	
	-- Directional velocity
	local fbVel = vel:dot((dir.x_z):normalized())
	local lrVel = vel:crossed(dir.x_z:normalized()).y
	local udVel = vel.y
	
	-- Speed control
	local moveSpeed = math.clamp((pose.climb and udVel or fbVel) * 10, -4, 4)
	
	-- Animation speeds
	anims.walk:speed(moveSpeed)
	
	-- Animation variables
	local walking = vel.xz:length() ~= 0
	local moving  = vel:length() ~= 0
	
	-- Animation states
	local idle    = not walking or (pose.climb and not moving)
	local walk    = walking or (pose.climb and moving)
	local sleep   = pose.sleep
	local canLean = not sleep
	
	-- Animations
	anims.idle:playing(idle)
	anims.walk:playing(walk)
	anims.sleep:playing(sleep)
	
	-- Lean target
	lean.target = canLean and headRot * vec(0.35, 0.5, 0.25) or 0
	
	-- Arm variables
	local handed = player:isLeftHanded()
	local mainL  = not handed and "OFF_HAND" or "MAIN_HAND"
	local mainR  = handed and "OFF_HAND" or "MAIN_HAND"
	local swingL = player:getSwingArm() == mainL
	local swingR = player:getSwingArm() == mainR
	local using  = player:isUsingItem()
	local active = player:getActiveHand()
	local itemL  = player:getHeldItem(not handed)
	local itemR  = player:getHeldItem(handed)
	local usingL = using and active == mainL and itemL:getUseAction()
	local usingR = using and active == mainR and itemR:getUseAction()
	local bow    = (usingL or usingR or ""):find("BOW") or (itemL:getTag().Charged or itemR:getTag().Charged) == 1
	
	-- Arms movement override
	local armShouldMove = pose.swim or pose.elytra or pose.crawl or pose.climb
	
	-- Arms movement targets
	leftArmLerp.target  = (armsMove.curr or armShouldMove or swingL or usingL or bow) and 1 or 0
	rightArmLerp.target = (armsMove.curr or armShouldMove or swingR or usingR or bow) and 1 or 0
	
end

function events.RENDER(delta, context)
	
	-- Apply lean rotatons
	for _, part in ipairs(leanParts) do
		part:offsetRot(lean.currPos / #leanParts)
	end
	
	-- Apply lean offsets
	for _, part in ipairs(leanOffsetParts) do
		part:offsetRot(-lean.currPos)
	end
	
	-- Arm idle rotation
	local idleTimer   = world.getTime(delta)
	local firstPerson = context == "FIRST_PERSON"
	local idleRot     = not firstPerson and vec(math.deg(math.sin(idleTimer * 0.067) * 0.05), 0, math.deg(math.cos(idleTimer * 0.09) * 0.05 + 0.05)) or vec(0, 0, 5.75)
	
	-- Control arm rotations
	vanilla_model.LEFT_ARM:rot(math.lerp(-idleRot, getOriginRot("LEFT_ARM"),  leftArmLerp.currPos))
	vanilla_model.RIGHT_ARM:rot(math.lerp(idleRot, getOriginRot("RIGHT_ARM"), rightArmLerp.currPos))
	
	-- Crouch offset
	local bodyRot = getOriginRot("BODY", delta)
	local crouchPos = vec(0, -math.sin(math.rad(bodyRot.x)) * 2, -math.sin(math.rad(bodyRot.x)) * 12)
	parts.group.UpperBody:offsetPivot(crouchPos * 0.8):pos(-crouchPos.x_z + crouchPos._y_)
	parts.group.Player:pos(crouchPos.x_z + crouchPos._y_ * 2)
	
	-- Spyglass rotations
	local headRot = getOriginRot("HEAD")
	headRot.x = math.clamp(headRot.x, -90, 30)
	parts.group.Spyglass:offsetRot(headRot - lean.currPos)
		:pos(pose.crouch and vec(0, -4, 0) or nil)
	
end

-- GS Blending Setup
local blendAnims = {
	{ anim = anims.idle, ticks = {7,7} },
	{ anim = anims.walk, ticks = {7,7} }
}

-- Apply GS Blending
for _, blend in ipairs(blendAnims) do
	if blend.anim ~= nil then
		blend.anim:blendTime(table.unpack(blend.ticks)):blendCurve("easeOutQuad")
	end
end

-- Host only instructions
if not host:isHost() then return end

-- Required script
local s, wheel, c = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found

-- Check for if page already exists
local pageExists = action_wheel:getPage("Anims")

-- Pages
local parentPage = action_wheel:getPage("Main")
local animsPage  = pageExists or action_wheel:newPage("Anims")

-- Actions table setup
local a = {}

-- Actions
if not pageExists then
	a.pageAct = parentPage:newAction()
		:item("jukebox")
		:onLeftClick(function() wheel:descend(animsPage) end)
end

a.armsAct = animsPage:newAction()
	:item("red_dye")
	:toggleItem("rabbit_foot")
	:onToggle(function(bool)
		armsMove:update(bool)
	end)
	:toggled(armsMove.curr)

-- Update actions
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		if a.pageAct then
			a.pageAct
				:title(toJson(
					{text = "Animation Settings", bold = true, color = c.primary}
				))
		end
		
		a.armsAct
			:title(toJson(
				{
					"",
					{text = "Arm Movement Toggle\n\n", bold = true, color = c.primary},
					{text = "Toggles the movement swing movement of the arms.\nActions are not effected.", color = c.secondary}
				}
			))
		
		for _, act in pairs(a) do
			act:hoverColor(c.hover):toggleColor(c.active)
		end
		
	end
	
end