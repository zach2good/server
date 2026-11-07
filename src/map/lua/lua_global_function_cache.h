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

#pragma once

#include <memory>
#include <string>
#include <string_view>

#include "common/macros.h"
#include <common/lua.h>
#include <common/types/flat_hash_map.h>

// Resolves a dotted global Lua path such as "xi.server.onTimeServerTick" to the function it names,
// and remembers the answer.
//
// Caching this at all looks unsafe, because test doubles replace the function a path names. It is
// safe because the cache is in two layers and only one of them is the function:
//
//   * The path's **parent table and final key**. A table along a path is only replaced by a script
//     reload or a module override, and both of those clear the cache outright.
//   * The **resolved function**. Stubs and spies overwrite the final key in the parent table, so
//     installing or restoring one calls invalidate(), which drops the function alone. The next
//     lookup re-reads that key through the cached parent rather than walking from _G.
//
// The thing cached is not the thing mocks mutate, which is why memoising here does not break them.
//
// The leaf read is metatable-aware (lua_gettable, not lua_rawget), as sol's proxy read was, so a
// double installed behind __index is still found. Changing that to a raw get would silently break
// metatable-based mocks while every direct-assignment test kept passing.
class GlobalFunctionCache final
{
public:
    GlobalFunctionCache()  = default;
    ~GlobalFunctionCache() = default;

    DISALLOW_COPY_AND_MOVE(GlobalFunctionCache);

    // The resolved function, or nullptr when the path does not name one.
    //
    // The pointer is owned by the cache and makes no sol::function copy, which would cost two Lua
    // registry references (sol::function is a protected function here, so it carries one for the
    // function and one for the error handler). It stays valid until clear(), so it is for callers
    // that use the function and let it go. Anything that keeps the function beyond its own call
    // takes a copy through findOwned().
    //
    // Negative results are not cached: a path that does not resolve is re-walked next time, so a
    // function defined later is still picked up without relying on invalidation.
    [[nodiscard]] auto find(std::string_view path) -> const sol::function*;

    // An owning copy, for callers that outlive their own call. sol::lua_nil when not found.
    [[nodiscard]] auto findOwned(std::string_view path) -> sol::function;

    // Drop the resolved function for one path, keeping the path to its parent table. Called when a
    // test double is installed at, or restored to, that path.
    void invalidate(std::string_view path);

    // Drop everything. Called when Lua is reloaded or a module override is applied, since either
    // can replace a table along a cached path.
    void clear();

    [[nodiscard]] auto size() const -> std::size_t
    {
        return entries_.size();
    }

private:
    // Behind a unique_ptr because FlatHashMap moves its entries when it grows, while a caller may
    // be holding the pointer find() returned across the Lua call it makes.
    struct Entry
    {
        sol::table    parent;
        std::string   leaf;
        sol::function func;
    };

    // Walk the path as far as the table holding the final key. nullptr when a step is missing or is
    // not something that can be indexed.
    [[nodiscard]] static auto resolvePath(std::string_view path) -> std::unique_ptr<Entry>;

    // Read the final key out of a cached parent table.
    [[nodiscard]] static auto readLeaf(const Entry& entry) -> sol::function;

    StringKeyedFlatHashMap<std::unique_ptr<Entry>> entries_;
};
