---@meta

-- luacheck: ignore 241
---@class CConflict
local CConflict = {}

---@nodiscard
---@param timestamp integer
---@return CTimeline
function CConflict:getTimelineAt(timestamp)
end

function CConflict:cleanTimeline()
end

---@nodiscard
---@return integer
function CConflict:getStartTime()
end

---@nodiscard
---@return integer
function CConflict:getEndTime()
end

---@param start integer
---@param length integer
function CConflict:setStartAndLength(start, length)
end

---@nodiscard
---@return CZone
function CConflict:getZone()
end

---@nodiscard
---@return xi.zone
function CConflict:getZoneID()
end

---@nodiscard
---@return integer
function CConflict:getRookCount()
end

---@nodiscard
---@return integer
function CConflict:getMaxTeamSize()
end

---@param maxTeamSize integer
---@param rookCount integer
function CConflict:configureGameSetup(maxTeamSize, rookCount)
end

---@nodiscard
---@return xi.conflictState
function CConflict:getState()
end

---@param state xi.conflictState
function CConflict:setState(state)
end

---@nodiscard
---@return boolean
function CConflict:isCombatEnabled()
end

---@param enabled boolean
function CConflict:setCombatEnabled(enabled)
end

---@param enabled boolean
function CConflict:setLevelRestrictionEnabled(enabled)
end

---@nodiscard
---@return xi.conflictType
function CConflict:getType()
end

---@nodiscard
---@return integer
function CConflict:getSignupFee()
end

---@nodiscard
---@return integer
function CConflict:getLevelCap()
end

---@nodiscard
---@return boolean
function CConflict:hasItemRestriction()
end

---@nodiscard
---@return xi.conflictSignupState
function CConflict:getSignupState()
end

---@param state xi.conflictSignupState
function CConflict:setSignupState(state)
end

---@param phase integer
function CConflict:setPhase(phase)
end

---@param teamIdx integer
---@param roundsToAdd integer?
---@return boolean
function CConflict:addTeamRoundWon(teamIdx, roundsToAdd)
end

---@param entity CBaseEntity
---@param teamIdx integer?
---@return boolean
function CConflict:addPlayer(entity, teamIdx)
end

---@nodiscard
---@param entity CBaseEntity
---@return boolean
function CConflict:hasPlayerLeft(entity)
end

---@nodiscard
---@return CBaseEntity[]
function CConflict:getPlayers()
end

---@nodiscard
---@return CConflictEntry[]
function CConflict:getEntries()
end

-- Returns one table per team, not a single table.
---@nodiscard
---@return CBaseEntity[]
---@return CBaseEntity[]
function CConflict:getTeamPlayers()
end

---@nodiscard
---@return integer
---@return integer
function CConflict:getTeamCounts()
end

-- The gil each member of a team would take home if they won.
---@nodiscard
---@return integer
---@return integer
function CConflict:getTeamWinnings()
end

---@nodiscard
---@return integer
---@return integer
function CConflict:getTeamScores()
end

---@nodiscard
---@return integer
---@return integer
function CConflict:getTeamRounds()
end

---@nodiscard
---@return integer
---@return integer
function CConflict:getTeamNations()
end

---@nodiscard
---@return xi.allegiance
---@return xi.allegiance
function CConflict:getTeamAllegiances()
end

---@nodiscard
---@return CConflictEntry?
function CConflict:getHighScorer()
end

-- Returns nil on a draw, or before the match has finished.
---@nodiscard
---@return integer?
function CConflict:getWinningTeam()
end

---@nodiscard
---@return boolean
function CConflict:areRooksOpen()
end
