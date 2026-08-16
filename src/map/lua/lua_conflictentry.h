/*
===========================================================================

  Copyright (c) 2021 Eden Dev Teams

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

#include "common/cbasetypes.h"
#include "common/types/maybe.h"

#include "luautils.h"

#include <string>

class CBaseEntity;
class ConflictEntry;
class ConflictInstance;

class CLuaConflictEntry
{
public:
    explicit CLuaConflictEntry(ConflictEntry* PEntry);

    [[nodiscard]] auto GetEntry() const -> ConflictEntry*
    {
        return m_PEntry;
    }

    [[nodiscard]] auto getHeldPetras() const -> uint32;
    [[nodiscard]] auto getScoredPetras() const -> uint32;
    [[nodiscard]] auto getPoints() const -> uint32;

    auto addPetras(int32 petras) -> int32;
    auto scorePetras() -> int32;

    [[nodiscard]] auto hasGateBreach() const -> bool;
    auto               addGateBreach() -> bool;
    auto               removeGateBreach() -> bool;

    [[nodiscard]] auto getConflict() const -> ConflictInstance*;
    [[nodiscard]] auto getPlayer() const -> CBaseEntity*;
    [[nodiscard]] auto getName() const -> Maybe<std::string>;
    [[nodiscard]] auto getJob() const -> uint8;

    [[nodiscard]] auto canLeave() const -> bool;
    auto               leave() -> Maybe<uint32>;

    [[nodiscard]] auto getIndex() const -> uint8;
    [[nodiscard]] auto getTeamIndex() const -> uint8;
    [[nodiscard]] auto getTeamAllegiance() const -> uint8;
    [[nodiscard]] auto getTeamNation() const -> uint8;

    [[nodiscard]] auto isTempEntry() const -> bool;
    [[nodiscard]] auto canScore() const -> bool;

    void changeTeam(sol::optional<uint8> teamIdx);

    // Normally driven by the incoming action packet, exposed here for scripts and tests.
    void quarry();
    void sprint();
    void scout();

    static void Register();

private:
    ConflictEntry* m_PEntry = nullptr;
};
