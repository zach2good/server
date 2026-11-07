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

#include "lua_global_function_cache.h"

namespace
{

// As sol::table did: a table or a userdata can be indexed, anything else ends a walk with nil.
auto isIndexable(lua_State* L, int index) -> bool
{
    const auto type = lua_type(L, index);

    return type == LUA_TTABLE || type == LUA_TUSERDATA;
}

} // namespace

auto GlobalFunctionCache::resolvePath(std::string_view path) -> std::unique_ptr<Entry>
{
    const auto            L = lua.lua_state();
    const LuaStackRestore restore{ L };

    lua_getfield(L, LUA_GLOBALSINDEX, "_G");

    std::size_t start = 0;
    while (true)
    {
        if (!isIndexable(L, -1))
        {
            return nullptr;
        }

        const auto dot = path.find('.', start);
        if (dot == std::string_view::npos)
        {
            break;
        }

        const auto part = path.substr(start, dot - start);
        lua_pushlstring(L, part.data(), part.size());
        lua_gettable(L, -2);
        lua_remove(L, -2);

        start = dot + 1;
    }

    auto entry = std::make_unique<Entry>();

    entry->parent = sol::stack::get<sol::table>(L, -1);
    entry->leaf   = path.substr(start);

    return entry;
}

auto GlobalFunctionCache::readLeaf(const Entry& entry) -> sol::function
{
    const auto            L = lua.lua_state();
    const LuaStackRestore restore{ L };

    entry.parent.push(L);

    if (!isIndexable(L, -1))
    {
        return sol::lua_nil;
    }

    lua_pushlstring(L, entry.leaf.data(), entry.leaf.size());
    lua_gettable(L, -2);

    // A stub or spy is callable userdata, not a function. This throws when the leaf is neither, so
    // the guard above is what returns the stack rather than a lua_settop on each exit.
    return sol::stack::get<sol::function>(L, -1);
}

auto GlobalFunctionCache::find(std::string_view path) -> const sol::function*
{
    auto entry = entries_.find(path);
    if (entry == entries_.end())
    {
        auto resolved = resolvePath(path);
        if (!resolved)
        {
            return nullptr;
        }

        entry = entries_.emplace(std::string(path), std::move(resolved)).first;
    }

    auto& cached = *entry->second;
    if (!cached.func.valid())
    {
        cached.func = readLeaf(cached);
        if (!cached.func.valid())
        {
            return nullptr;
        }
    }

    return &cached.func;
}

auto GlobalFunctionCache::findOwned(std::string_view path) -> sol::function
{
    const auto* func = find(path);
    if (func == nullptr)
    {
        return sol::lua_nil;
    }

    return *func;
}

void GlobalFunctionCache::invalidate(std::string_view path)
{
    const auto entry = entries_.find(path);
    if (entry == entries_.end())
    {
        return;
    }

    // Keep parent and leaf: a double only overwrote the leaf key, so the next lookup can re-read it
    // without walking from _G again.
    entry->second->func = sol::lua_nil;
}

void GlobalFunctionCache::clear()
{
    entries_.clear();
}
