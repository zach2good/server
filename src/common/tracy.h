/*
===========================================================================

  Copyright (c) 2023 LandSandBoat Dev Teams

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

#include <cstdint>
#include <string>

#include <fmt/format.h>

//
// TODO: Move these somewhere else
//

inline auto hex8ToString(std::uint8_t hex) -> std::string
{
    return fmt::format("0x{:02X}", hex);
}

inline auto hex16ToString(std::uint16_t hex) -> std::string
{
    return fmt::format("0x{:04X}", hex);
}

inline auto hex32ToString(std::uint32_t hex) -> std::string
{
    return fmt::format("0x{:08X}", hex);
}

// clang-format off
#ifdef TRACY_ENABLE

#include "tracy/Tracy.hpp"

#include <cstdint>
#include <fmt/format.h>
#include <string>

#define TracyFrameMark            FrameMark
#define TracyZoneScoped           ZoneScoped
#define TracyZoneScopedN(n)       ZoneScopedN(n)
#define TracyZoneNamed(var, name) ZoneNamedN(var, name, true)
#define TracyZoneText(n, l)       ZoneText(n, l)
#define TracyZoneScopedC(c)       ZoneScopedC(c)
#define TracyZoneScopedNC(n, c)   ZoneScopedNC(n, c)
#define TracyZoneScopedS(depth)   ZoneScopedS(depth)
#define TracyZoneString(str)      ZoneText(str.data(), str.size())
#define TracyZoneCString(cstr)    ZoneText(cstr, std::strlen(cstr))
#define TracyMessageStr(str)      TracyMessage(str.c_str(), str.size())
#define TracySetThreadName(str)   tracy::SetThreadName(str)

#define TracyZoneHex8(num) \
    auto str = hex8ToString(num); \
    TracyZoneText(str.c_str(), str.size());

#define TracyZoneHex16(num) \
    auto str = hex16ToString(num); \
    TracyZoneText(str.c_str(), str.size());

#define TracyZoneHex32(num) \
    auto str = hex32ToString(num); \
    TracyZoneText(str.c_str(), str.size());

#define TracyReportGraphNumber(name, num) \
    TracyPlotConfig(name, tracy::PlotFormatType::Number, false, true, 0); \
    TracyPlot(name, num);

#define TracyReportGraphBytes(name, num) \
    TracyPlotConfig(name, tracy::PlotFormatType::Memory, false, true, 0); \
    TracyPlot(name, num);

#define TracyReportGraphPercent(name, num) \
    TracyPlotConfig(name, tracy::PlotFormatType::Percentage, false, true, 0); \
    TracyPlot(name, num);

#define TracyReportLuaMemory(L) \
    TracyReportGraphBytes("Lua Memory Usage", static_cast<double>(lua_gc(L, LUA_GCCOUNT, 0)) * 1024.0);

#else // Empty stubs for regular builds
// The arguments sit in an unevaluated sizeof: they cost nothing at runtime (no getName() calls, no
// formatted strings), but they still have to compile, so Tracy-only code can't rot in regular builds
// and variables used only for Tracy don't trip -Wunused-variable.
#define XI_TRACY_UNUSED(x)                 ((void)sizeof((x)))
#define TracyFrameMark                     ((void)0)
#define TracyZoneScoped                    ((void)0)
#define TracyZoneScopedN(n)                XI_TRACY_UNUSED(n)
#define TracyZoneNamed(var, name)          XI_TRACY_UNUSED(name)
#define TracyZoneText(n, l)                (XI_TRACY_UNUSED(n), XI_TRACY_UNUSED(l))
#define TracyZoneScopedC(c)                XI_TRACY_UNUSED(c)
#define TracyZoneScopedNC(n, c)            (XI_TRACY_UNUSED(n), XI_TRACY_UNUSED(c))
#define TracyZoneScopedS(depth)            XI_TRACY_UNUSED(depth)
#define TracyZoneString(str)               XI_TRACY_UNUSED(str)
#define TracyZoneCString(cstr)             XI_TRACY_UNUSED(cstr)
#define TracyZoneIString(istr)             XI_TRACY_UNUSED(istr)
#define TracyZoneHex8(num)                 XI_TRACY_UNUSED(num)
#define TracyZoneHex16(num)                XI_TRACY_UNUSED(num)
#define TracyZoneHex32(num)                XI_TRACY_UNUSED(num)
#define TracyReportGraphNumber(name, num)  (XI_TRACY_UNUSED(name), XI_TRACY_UNUSED(num))
#define TracyReportGraphBytes(name, num)   (XI_TRACY_UNUSED(name), XI_TRACY_UNUSED(num))
#define TracyReportGraphPercent(name, num) (XI_TRACY_UNUSED(name), XI_TRACY_UNUSED(num))
#define TracyReportLuaMemory(L)            XI_TRACY_UNUSED(L)
#define TracyMessageStr(str)               XI_TRACY_UNUSED(str)
#define TracySetThreadName(str)            XI_TRACY_UNUSED(str)
#define TracyLockable(m, n)                m n
#define TracySharedLockable(m, n)          m n
#define LockableBase(type)                 type
#define SharedLockableBase(type)           type
#define LockMark(m)                        XI_TRACY_UNUSED(m)
#endif
// clang-format on
