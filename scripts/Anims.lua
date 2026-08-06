-- Required scripts
require("lib.GSAnimBlend")
require("lib.Molang")
local parts   = require("lib.PartsAPI")
local sync    = require("lib.LetThatSyncFig")
local lerp    = require("lib.LerpAPI")
local origins = require("lib.OriginsAPI")
local ground  = require("lib.GroundCheck")
local pose    = require("scripts.Posing")
local effects = require("scripts.SyncedVariables")

-- Animations setup
local anims = animations.Turtle

-- Synced variables setup
local armsMove  = sync.new("AnimsArms", false):config()
local isHiding  = sync.new("AnimsHiding", 0):config()
local isShaking = sync.new("AnimsShaking", 1):config()
--[[
	For hiding:
		0 == not hiding
		1 == partial hiding
		2 == full hiding
	For shaking:
		0 == not shaking
		1 == only when hiding
		2 == shaking
--]]

-- Table setup
v = {}

-- Animation variables
v.head = vec(0, 0, 0)
v.lArm = vec(0, 0, 0)
v.rArm = vec(0, 0, 0)

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

-- Parrot pivots
local parrots = {
	
	parts.group.LeftParrotPivot,
	parts.group.RightParrotPivot
	
}

-- Calculate parent's rotations
local function calculateParentRot(m)
	
	local parent = m:getParent()
	if not parent then
		return m:getTrueRot()
	end
	return calculateParentRot(parent) + m:getTrueRot()
	
end

-- Body bounce
local bodyBounce = lerp.new(0, 0.3, 0.15)
local _onGround = true

-- Flipper parts tables
local flippers = {
	frontLeft  = parts:createChain("FrontLeftFlipper"),
	frontRight = parts:createChain("FrontRightFlipper")
}

-- Power data
local hidePower = nil

function events.TICK()
	
	-- Variables
	local vel = player:getVelocity()
	local yaw = player:getBodyYaw()
	local dir = vec(math.sin(math.rad(-yaw)), 0, math.cos(math.rad(-yaw)))
	local inWater    = player:isInWater()
	local underwater = player:isUnderwater()
	local walking    = vel.xz:length() ~= 0
	local moving     = vel:length() ~= 0
	local onGround   = ground()
	local vehicle    = player:getVehicle()
	local headRot    = getOriginRot("HEAD")
	hidePower = origins.getPowerData(player)["turtletaur:shelled_resource"]
	
	-- Directional velocity
	local fbVel = vel:dot((dir.x_z):normalized())
	local lrVel = vel:crossed(dir.x_z:normalized()).y
	local udVel = vel.y
	
	-- Speed control
	local moveSpeed = math.clamp((effects.cF and vel:length() or pose.climb and udVel or fbVel) * 10, -4, 4)
	
	-- Animation speeds
	anims.groundWalk:speed(moveSpeed)
	anims.waterSwim:speed(moveSpeed)
	anims.underwaterSwim:speed(moveSpeed * 0.75)
	
	-- Animation variables
	local groundAnim     = (onGround or pose.climb) and not ((pose.swim and inWater) or pose.elytra or pose.spin)
	local waterAnim      = (inWater or vehicle) and not (underwater or onGround or pose.elytra)
	local underwaterAnim = (underwater or effects.cF) and (not onGround or pose.swim) and not pose.elytra
	
	-- Animation states
	local groundIdle     = groundAnim and (not walking or (pose.climb and not moving))
	local groundWalk     = groundAnim and (walking or (pose.climb and moving))
	local waterIdle      = waterAnim and not walking
	local waterSwim      = waterAnim and walking
	local underwaterIdle = underwaterAnim and not moving
	local underwaterSwim = underwaterAnim and moving
	local swimPose       = pose.swim
	local elytraPose     = pose.elytra
	local spin           = pose.spin
	local climb          = pose.climb
	local sleep          = pose.sleep
	local canHide        = not (swimPose or elytraPose or spin or vehicle)
	local partHiding     = canHide and (hidePower or isHiding.curr) == 1
	local fullHiding     = canHide and (hidePower or isHiding.curr) == 2
	local shaking        = (isShaking.curr == 1 and (partHiding or fullHiding)) or isShaking.curr == 2
	
	-- Animations
	anims.groundIdle:playing(groundIdle)
	anims.groundWalk:playing(groundWalk)
	anims.waterIdle:playing(waterIdle)
	anims.waterSwim:playing(waterSwim)
	anims.underwaterIdle:playing(underwaterIdle)
	anims.underwaterSwim:playing(underwaterSwim)
	anims.swimPose:playing(swimPose)
	anims.elytraPose:playing(elytraPose)
	anims.spin:playing(spin)
	anims.climb:playing(climb)
	anims.sleep:playing(sleep)
	anims.partHiding:playing(partHiding)
	anims.fullHiding:playing(fullHiding)
	anims.shaking:playing(shaking)
	
	-- Lean target
	local canLean = not (sleep or partHiding or fullHiding)
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
	
	-- Set bounce target
	if pose.crawl or pose.spin or effects.cF then
		bodyBounce.target = 0
	elseif not onGround then
		bodyBounce.target = math.clamp(player:getVelocity().y, -0.5, 0.5) * 75
	elseif onGround and not _onGround then
		bodyBounce.target = -bodyBounce.target
	end
	
	-- Bounce limits
	if onGround and bodyBounce.currTick > 0 then
		bodyBounce:bounce(0, 0.85)
	elseif bodyBounce.currTick < -25 then
		bodyBounce:bounce(-25, 0.85)
	elseif bodyBounce.currTick > 35 then
		bodyBounce:bounce(35, 0.85)
	end
	
	-- Stiffness and damping
	if inWater then
		bodyBounce:setStiff(0.1)
		bodyBounce:setDamp(0.025)
	else
		bodyBounce:setStiff(0.3)
		bodyBounce:setDamp(0.15)
	end
	
	-- Store data
	_onGround = onGround
	
end

function events.RENDER(delta, context)
	
	-- Store animation variables
	v.head = getOriginRot("HEAD", delta)
	v.lArm = getOriginRot("LEFT_ARM", delta)
	v.rArm = getOriginRot("RIGHT_ARM", delta)
	
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
	
	-- Apply body bounce
	parts.group.LowerBody:offsetRot(bodyBounce.currPos, 0, 0)
	for k, v in pairs(flippers) do
		local flipperRot = vec(0, 0, bodyBounce.currPos * (k:find("Right") and -1 or 1))
		for _, part in ipairs(v) do
			part:offsetRot(flipperRot)
		end
	end
	
	-- Parrot rot offset
	for _, parrot in pairs(parrots) do
		parrot:rot(-calculateParentRot(parrot:getParent()) - getOriginRot("BODY", delta))
	end
	
	-- Crouch offset
	local bodyRot = getOriginRot("BODY", delta)
	local crouchPos = not (anims.partHiding:isPlaying() or anims.fullHiding:isPlaying()) and vec(0, -math.sin(math.rad(bodyRot.x)) * 2, -math.sin(math.rad(bodyRot.x)) * 12) or vec(0, 0, 0)
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
	{
		anim  = anims.groundIdle,
		ticks = {7,7}
	},
	{
		anim  = anims.groundWalk,
		ticks = {7,7}
	},
	{
		anim  = anims.waterIdle,
		ticks = {7,7}
	},
	{
		anim  = anims.waterSwim,
		ticks = {7,7}
	},
	{
		anim  = anims.underwaterIdle,
		ticks = {7,7}
	},
	{
		anim  = anims.underwaterSwim,
		ticks = {7,7}
	},
	{
		anim  = anims.swimPose,
		ticks = {12,12},
		type  = "linear"
	},
	{
		anim  = anims.elytraPose,
		ticks = {9,0},
		type  = "linear"
	},
	{
		anim  = anims.partHiding,
		ticks = {7,14}
	},
	{
		anim  = anims.fullHiding,
		ticks = {14,14}
	}
}

-- Apply GS Blending
for _, blend in ipairs(blendAnims) do
	if blend.anim ~= nil then
		blend.anim:blendTime(table.unpack(blend.ticks)):blendCurve(blend.type or "easeOutQuad")
	end
end

-- Host only instructions
if not host:isHost() then return end

-- Required script
local keybound = require("lib.Keybound")

-- Setup keybinds
local hidingKeybind = keybound.new(
	keybinds
		:newKeybind("Hiding Animation", "key.keyboard.keypad.1")
		:onPress(function() if hidePower then return end isHiding:update((isHiding.curr + 1) % 3) end),
	"AnimHidingKeybind"
)

-- Required script
local s, pageNav, acts, c = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found

-- Check for if page already exists
local pageExists = action_wheel:getPage("Anims")

-- Pages
local parentPage = action_wheel:getPage("Main")
local animsPage  = pageExists or action_wheel:newPage("Anims")

-- Actions
if not pageExists then
	acts.animsPage = parentPage:newAction()
		:item("jukebox")
		:onLeftClick(function() pageNav.descend(animsPage) end)
end

-- Set hiding style
local function setIntensity(x, i)
	return (x + i) % 3
end

acts.animsArmsToggle = animsPage:newAction()
	:item("red_dye")
	:toggleItem("rabbit_foot")
	:onToggle(function(bool)
		armsMove:update(bool)
	end)
	:toggled(armsMove.curr)

acts.animsHidingStyle = animsPage:newAction()
	:onLeftClick(function() if hidePower then return end isHiding:update(setIntensity(isHiding.curr, 1)) end)
	:onRightClick(function() if hidePower then return end isHiding:update(setIntensity(isHiding.curr, -1)) end)
	:onScroll(function(x) if hidePower then return end isHiding:update(setIntensity(isHiding.curr, x), 10) end)

acts.animsShakingStyle = animsPage:newAction()
	:onLeftClick(function() isShaking:update(setIntensity(isShaking.curr, 1)) end)
	:onRightClick(function() isShaking:update(setIntensity(isShaking.curr, -1)) end)
	:onScroll(function(x) isShaking:update(setIntensity(isShaking.curr, x), 10) end)

-- Update actions
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		if acts.animsPage then
			acts.animsPage
				:title(toJson(
					{text = "Animation Settings", bold = true, color = c.primary}
				))
				:hoverColor(c.hover)
		end
		
		acts.animsArmsToggle
			:title(toJson(
				{
					"",
					{text = "Arm Movement Toggle\n\n", bold = true, color = c.primary},
					{text = "Toggles the movement swing movement of the arms.\nActions are not effected.", color = c.secondary}
				}
			))
			:hoverColor(c.hover)
			:toggleColor(c.active)
		
		acts.animsHidingStyle
			:title(toJson(
				{
					"",
					{text = "Play Hiding animation", bold = true, color = c.primary},
					{text = "\n\nLeft and Right click to change intensity!", color = c.secondary},
					{text = "\n\nCurrent intensity: ", bold = true, color = c.secondary},
					{
						text = hidePower and "Overwritten by origin power!"
							or isHiding.curr == 2 and "Full"
							or isHiding.curr == 1 and "Partial"
							or "None",
						color = hidePower and "gold"
							or isHiding.curr == 2 and "red"
							or isHiding.curr == 1 and "yellow"
							or "white"
					}
				}
			))
			:item(isHiding.curr ~= 0 and "turtle_helmet" or "scute")
			:color(
				hidePower and vec(1, 0.5, 0) or
				isHiding.curr == 2 and vec(1, 0, 0) or
				isHiding.curr == 1 and vec(1, 1, 0) or
				nil
			)
			:hoverColor(c.hover)
			
		acts.animsShakingStyle
			:title(toJson(
				{
					"",
					{text = "Play Shaking animation", bold = true, color = c.primary},
					{text = "\n\nLeft and Right click to change intensity!", color = c.secondary},
					{text = "\n\nCurrent intensity: ", bold = true, color = c.secondary},
					{
						text = isShaking.curr == 2 and "Always"
							or isShaking.curr == 1 and "Only When Hiding"
							or "None",
						color = isShaking.curr == 2 and "red"
							or isShaking.curr == 1 and "yellow"
							or "white"
					}
				}
			))
			:item(isShaking.curr ~= 0 and "sculk_sensor" or "cut_sandstone_slab")
			:color(
				isShaking.curr == 2 and vec(1, 0, 0) or
				isShaking.curr == 1 and vec(1, 1, 0) or
				nil
			)
			:hoverColor(c.hover)
		
	end
	
end