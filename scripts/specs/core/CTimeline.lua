---@meta

-- luacheck: ignore 241
---@class CTimeline
local CTimeline = {}

---@param hours integer
---@param minutes integer?
---@return CTimeline
function CTimeline:addVanaTime(hours, minutes)
end

---@param vanaMinutes integer
---@return CTimeline
function CTimeline:addVanaMinutes(vanaMinutes)
end

---@param hours integer
---@param minutes integer?
---@param seconds integer?
---@return CTimeline
function CTimeline:setTime(hours, minutes, seconds)
end

---@param timestamp integer
---@return CTimeline
function CTimeline:setTimestamp(timestamp)
end

---@nodiscard
---@return integer
function CTimeline:getTimestamp()
end

---@param offset integer
---@return CTimeline
function CTimeline:offsetMilliseconds(offset)
end

---@param offset integer
---@return CTimeline
function CTimeline:offsetSeconds(offset)
end

---@return CTimeline
function CTimeline:resetOffset()
end

-- Returns the scheduled event id, or nil when the event was dropped as past due.
---@param eventFunc fun(): boolean?
---@return integer?
function CTimeline:addEvent(eventFunc)
end

---@param eventFunc fun(): boolean?
function CTimeline:addSkippableEvent(eventFunc)
end

---@param eventFunc fun(): boolean?
function CTimeline:addImportantEvent(eventFunc)
end

---@param options table
---@param eventFunc fun(): boolean?
---@return boolean
function CTimeline:addRepeatingEvent(options, eventFunc)
end
