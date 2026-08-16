---@meta

-- luacheck: ignore 241
---@class CConflictEntry
local CConflictEntry = {}

---@nodiscard
---@return integer
function CConflictEntry:getHeldPetras()
end

---@nodiscard
---@return integer
function CConflictEntry:getScoredPetras()
end

---@nodiscard
---@return integer
function CConflictEntry:getPoints()
end

---@param petras integer
---@return integer
function CConflictEntry:addPetras(petras)
end

---@return integer
function CConflictEntry:scorePetras()
end

---@nodiscard
---@return boolean
function CConflictEntry:hasGateBreach()
end

---@return boolean
function CConflictEntry:addGateBreach()
end

---@return boolean
function CConflictEntry:removeGateBreach()
end

---@nodiscard
---@return CConflict
function CConflictEntry:getConflict()
end

---@nodiscard
---@return CBaseEntity?
function CConflictEntry:getPlayer()
end

---@nodiscard
---@return string?
function CConflictEntry:getName()
end

---@nodiscard
---@return xi.job
function CConflictEntry:getJob()
end

---@nodiscard
---@return boolean
function CConflictEntry:canLeave()
end

-- Returns the gil the Herald hands back, or nil when nothing is owed.
---@return integer?
function CConflictEntry:leave()
end

---@nodiscard
---@return integer
function CConflictEntry:getIndex()
end

---@nodiscard
---@return integer
function CConflictEntry:getTeamIndex()
end

---@nodiscard
---@return xi.allegiance
function CConflictEntry:getTeamAllegiance()
end

-- The team's nation counted from zero, where allegiance counts from San d'Oria.
---@nodiscard
---@return integer
function CConflictEntry:getTeamNation()
end

---@nodiscard
---@return boolean
function CConflictEntry:isTempEntry()
end

---@nodiscard
---@return boolean
function CConflictEntry:canScore()
end

-- Swaps to the other team when no index is given.
---@param teamIdx integer?
function CConflictEntry:changeTeam(teamIdx)
end

function CConflictEntry:quarry()
end

function CConflictEntry:sprint()
end

function CConflictEntry:scout()
end
