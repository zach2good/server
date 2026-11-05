/*
===========================================================================

  Copyright (c) 2010-2015 Darkstar Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#pragma once

#include <common/cbasetypes.h>

#include <common/logging.h>
#include <common/types/hash_map.h>
#include <map/lua/sol_bindings.h>

#include <array>
#include <cstddef>
#include <functional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

class CAIEventHandler
{
    struct AIEvent
    {
        std::string   identifier_;
        sol::function luaFunc_;

        AIEvent(std::string identifier, sol::function luaFunc)
        : identifier_(std::move(identifier))
        , luaFunc_(std::move(luaFunc))
        {
        }
    };

public:
    CAIEventHandler() = default;

    // hotListeners_ points into this object's own map, so a copy or move would alias the source.
    CAIEventHandler(const CAIEventHandler&)                    = delete;
    auto operator=(const CAIEventHandler&) -> CAIEventHandler& = delete;
    CAIEventHandler(CAIEventHandler&&)                         = delete;
    auto operator=(CAIEventHandler&&) -> CAIEventHandler&      = delete;

    void addListener(const std::string& eventName, const sol::function& luaFunc, const std::string& identifier);
    void removeListener(const std::string& identifier);
    auto hasListener(std::string_view eventName) const -> bool;

    // Called on every entity tick ("TICK", "ROAM_TICK", ...), so it must be cheap when nothing listens.
    template <class... Args>
    void triggerListener(std::string_view eventName, Args&&... args) noexcept;

private:
    void removeFromAllListeners(const std::string& identifier);
    void refreshHotListeners();

    // Events fired on every entity tick. They bypass the map lookup (cold heap nodes, per entity) via
    // hotListeners_, which points straight at their listener lists.
    static constexpr std::array<std::string_view, 3> kHotEvents = { "TICK", "ROAM_TICK", "COMBAT_TICK" };

    // Index into kHotEvents, or kHotEvents.size() for any other name.
    static constexpr auto hotEventIndex(const std::string_view eventName) -> std::size_t
    {
        for (std::size_t i = 0; i < kHotEvents.size(); ++i)
        {
            if (kHotEvents[i] == eventName)
            {
                return i;
            }
        }
        return kHotEvents.size();
    }

    uint32 triggerDepth_ = 0;

    HashMap<std::string, std::vector<AIEvent>> eventListeners_;
    std::vector<std::string>                   eventsToRemove_;

    // Points into eventListeners_ (map nodes never move); refreshed whenever an entry is added or erased.
    std::array<std::vector<AIEvent>*, kHotEvents.size()> hotListeners_{};
};

//
// Template impls
//

template <class... Args>
void CAIEventHandler::triggerListener(const std::string_view eventName, Args&&... args) noexcept
{
    // Most entities never register a listener: skip hashing the name entirely.
    if (eventListeners_.empty())
    {
        return;
    }

    std::vector<AIEvent>* listenersPtr = nullptr;
    if (const auto hot = hotEventIndex(eventName); hot < kHotEvents.size())
    {
        listenersPtr = hotListeners_[hot];
    }
    else if (auto it = eventListeners_.find(eventName); it != eventListeners_.end())
    {
        // HashMap<std::string> is transparent, so no std::string is built.
        listenersPtr = &it->second;
    }

    if (listenersPtr == nullptr || listenersPtr->empty())
    {
        return;
    }

    // Only report triggers we're actually going to fire
    TracyZoneScoped;
    TracyZoneString(eventName);

    // Prevent modification while iterating
    ++triggerDepth_;
    {
        auto& listeners = *listenersPtr;
        for (auto& event : listeners)
        {
            auto result = event.luaFunc_(std::decay_t<Args>(args)...);
            if (!result.valid())
            {
                sol::error err = result;
                ShowErrorFmt("Error in listener event {}: {}", eventName, err.what());
            }
        }
    }
    --triggerDepth_;

    // Process deferred removals once the outermost trigger has finished. A nested trigger (a listener
    // firing another event) must not mutate listener lists an outer trigger is still iterating.
    if (triggerDepth_ == 0 && !eventsToRemove_.empty())
    {
        for (const auto& identifier : eventsToRemove_)
        {
            removeFromAllListeners(identifier);
        }
        eventsToRemove_.clear();
    }
}
