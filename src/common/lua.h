/*
===========================================================================

  Copyright (c) 2022 LandSandBoat Dev Teams

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

#include <sol/sol.hpp>

extern sol::state& lua;

// Returns the Lua stack to where it was, however the scope exits.
//
// Code that works the raw stack pushes intermediate values and has to drop them again. By hand that
// means a lua_settop() on every exit, which is a pair the compiler could be sequencing instead: one
// missed early return leaves values on the stack for the rest of the process's life.
//
// It also covers exits that are not returns. sol throws when a conversion fails -- reading a
// sol::function off a value that is not callable, say -- and a throw walks past a manual
// lua_settop. In practice sol's own throw paths leave the stack balanced today (measured: 1000
// throwing lookups, depth unchanged), so this is about not depending on that rather than fixing a
// leak that exists.
//
// Note this *restores* the stack; sol::stack_guard only checks it and reports a mismatch.
class LuaStackRestore final
{
public:
    explicit LuaStackRestore(lua_State* L)
    : L_{ L }
    , top_{ lua_gettop(L) }
    {
    }

    ~LuaStackRestore()
    {
        lua_settop(L_, top_);
    }

    LuaStackRestore(const LuaStackRestore&)                    = delete;
    LuaStackRestore(LuaStackRestore&&)                         = delete;
    auto operator=(const LuaStackRestore&) -> LuaStackRestore& = delete;
    auto operator=(LuaStackRestore&&) -> LuaStackRestore&      = delete;

    // Where the stack was when this guard was made.
    [[nodiscard]] auto top() const -> int
    {
        return top_;
    }

private:
    lua_State* L_;
    int        top_;
};

void lua_init();
void lua_cleanup();
auto lua_to_string_depth(const sol::object& obj, std::size_t depth) -> std::string;
auto lua_to_string(sol::variadic_args va) -> std::string;
void lua_print(sol::variadic_args va);
auto lua_fmt(const std::string& fmtStr, sol::variadic_args va) -> std::string;
