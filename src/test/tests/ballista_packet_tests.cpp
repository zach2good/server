/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

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

//
// Byte layout of the 0x00E6 scout response.
//
// The field offsets come from the packet reference at
// https://github.com/atom0s/XiPackets/tree/main/world/server/0x00E6, and the values from a capture
// of a retail match. Both are pinned here by offset rather than through the struct, because an
// earlier reading of this packet had the position axes swapped and the distance pre-scaled, and
// neither is visible without a client.
//
// These run via Catch2 during xi_test startup, before the Lua engine boots.
//

#include "map/entities/base_entity.h"
#include "map/packets/s2c/0x0e6_ballista.h"

#include <catch2/catch_approx.hpp>
#include <catch2/catch_test_macros.hpp>

#include <string>

namespace
{

// CBaseEntity is abstract (Tick/PostTick); the scout response only reads identity and position.
class TestRook final : public CBaseEntity
{
public:
    TestRook(const uint32 _id, const float x, const float y, const float z)
    {
        id      = _id;
        targid  = 1;
        name    = "Rook";
        loc.p.x = x;
        loc.p.y = y;
        loc.p.z = z;
    }

    auto Tick(timer::time_point) -> Task<void> override
    {
        co_return;
    }

    void PostTick() override
    {
    }
};

// What the client does with RookDistance before it puts a number on screen.
constexpr auto clientDistance(const float sent) -> float
{
    return sent * 0.91399997f + 0.5f;
}

constexpr auto kRookPositionOffset = 0x10;
constexpr auto kRookDistanceOffset = 0x20;

} // namespace

TEST_CASE("Ballista scout response", "[packets][conflict]")
{
    // A height well away from the horizontal coordinates, so a swapped axis cannot pass by looking
    // close enough.
    const auto rook = TestRook(0x1234567, 100.0f, -8.0f, -250.0f);

    SECTION("carries the position as X, Z, Y")
    {
        const auto packet = GP_SERV_COMMAND_BALLISTA::SCOUT(&rook, 30.0f);

        CHECK(packet.ref<float>(kRookPositionOffset + 0) == Catch::Approx(100.0f));
        CHECK(packet.ref<float>(kRookPositionOffset + 4) == Catch::Approx(-250.0f));
        CHECK(packet.ref<float>(kRookPositionOffset + 8) == Catch::Approx(-8.0f));
    }

    SECTION("pre-compensates the distance the client will rescale")
    {
        for (const auto realDistance : { 1.0f, 5.5f, 30.0f, 120.0f })
        {
            const auto packet = GP_SERV_COMMAND_BALLISTA::SCOUT(&rook, realDistance);
            const auto sent   = packet.ref<float>(kRookDistanceOffset);

            CHECK(clientDistance(sent) == Catch::Approx(realDistance));
        }
    }

    SECTION("repeats the distance in the fourth position slot")
    {
        const auto packet = GP_SERV_COMMAND_BALLISTA::SCOUT(&rook, 42.0f);

        CHECK(packet.ref<float>(kRookPositionOffset + 12) == Catch::Approx(packet.ref<float>(kRookDistanceOffset)));
    }

    SECTION("answers an absent rook with an empty response")
    {
        const auto packet = GP_SERV_COMMAND_BALLISTA::SCOUT(nullptr, 0.0f);

        CHECK(packet.ref<uint32>(0x08) == 0);
        CHECK(packet.ref<float>(kRookDistanceOffset) == 0.0f);
    }
}

TEST_CASE("Ballista scoreboard set counter", "[packets][conflict]")
{
    // The timeline sets an odd phase when a round starts and the even one after it when the round
    // ends, so both phases of a set have to show the same number.
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(1) / 2 == 1);
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(2) / 2 == 1);
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(3) / 2 == 2);
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(4) / 2 == 2);
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(5) / 2 == 3);
    CHECK(GP_SERV_COMMAND_BALLISTA::ToMatchSet(6) / 2 == 3);
}
