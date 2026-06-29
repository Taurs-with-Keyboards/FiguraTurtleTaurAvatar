-- Avatar color
avatar:color(vectors.hexToRGB("30723F"))

-- Glowing outline
renderer:outlineColor(vectors.hexToRGB("30723F"))

-- Host only instructions
if not host:isHost() then return end

-- Table setup
local c = {}

-- Action variables
c.hover     = vectors.hexToRGB("30723F")
c.active    = vectors.hexToRGB("A89A73")
c.primary   = "#30723F"
c.secondary = "#A89A73"

-- Return variables
return c