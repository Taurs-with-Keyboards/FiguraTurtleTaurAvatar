-- Avatar color
avatar:color(vectors.hexToRGB("30723F"))

-- Glowing outline
renderer:outlineColor(vectors.hexToRGB("30723F"))

-- Host only instructions
if not host:isHost() then return end

-- Table setup
local colors = {}

-- Action variables
colors.hover     = vectors.hexToRGB("30723F")
colors.active    = vectors.hexToRGB("A89A73")
colors.primary   = "#30723F"
colors.secondary = "#A89A73"

-- Return variables
return colors