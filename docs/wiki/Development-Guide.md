# <a id="table-of-contents"/>Development Guide

- [Before you push](#before-you-push)
- [All files](#all-files)
- [C++](#c)
- [Lua](#lua)
- [YAML and data](#yaml)
- [SQL](#sql)
- [Python](#python)
- [Git](Development-Guide-Git)

Read the [Contributing Guide](https://github.com/LandSandBoat/server/blob/base/CONTRIBUTING.md) first. If you use an AI agent, read [AI Agents](https://github.com/LandSandBoat/server/blob/base/docs/ai_agents/README.md) too.

Most rules below are enforced by CI. Where a rule is a preference rather than a check, it says so. When in doubt, copy the style of recent code nearby.

## <a id="before-you-push"/>Before you push

Commit first. The checks compare against a git ref and some of them read the working tree.

```sh
./tools/ci/sanity_checks.sh origin/base
```

This runs the same checks as the PR job: commit messages, whitespace, licence headers, C++ formatting, cppcheck, Lua style, luacheck, SQL and Python. It needs `clang-format` 22, `cppcheck`, `luacheck`, `black`, `pylint` and `tools/requirements.txt` installed. It writes `sanity_checks_summary.md` and `changed-files.txt` to the repo root. Both are git-ignored.

To run one check:

| What | Command |
| --- | --- |
| C++ formatting (fix) | `python3 tools/run_clang_format.py` |
| C++ formatting (check) | `python3 tools/run_clang_format.py --check` |
| Lua style | `python3 tools/ci/sanity_checks/lua_stylecheck.py <file.lua>` |
| luacheck | `bash tools/ci/sanity_checks/lua.sh <files...>` |
| Commit messages | `python3 tools/ci/sanity_checks/git.py origin/base` |
| YAML data (fix) | `python3 tools/yaml/format.py <files...>` |
| YAML data (check) | `python3 tools/yaml/format.py <files...> --check` |
| Python | `black --check <file.py>` and `pylint --errors-only <file.py>` |
| Data schema | `cmake --build <build dir> --target data_schema_check` |
| Tests | `xi_test`, see [Testing](Testing) |

clang-tidy runs in CI on a clang 22 build. To run it locally, configure with `-DENABLE_CLANG_TIDY=ON`.

## <a id="all-files"/>All files

Checked on every changed file except Python and `docs/`:

- No byte order mark.
- Spaces, never tabs.
- End with exactly one newline. No blank line at the end of the file.
- Never two blank lines in a row.

## <a id="c"/>C++

### <a id="c-formatting"/>Formatting

`.clang-format` defines the layout and CI checks it with **clang-format 22**. Other versions format differently. Run `python3 tools/run_clang_format.py` and don't hand-format. The main points, so the code you write looks right before you run it:

- Allman braces, 4-space indent, no tabs.
- `Type* name`, not `Type *name`.
- Consecutive assignments and declarations are aligned on `=` and on the name.
- No function, `if`, loop or lambda body on one line.
- Spaces inside braced lists: `{ 1, 2, 3 }`.
- Constructor initialisers start each line with `:` or `,`.
- Includes are sorted for you.

### <a id="c-naming-misc"/>Naming

- `UpperCamelCase` for classes and namespaced functions.
- `UPPER_SNAKE_CASE` for plain enum values. Style enum classes like classes.
- `lowerCamelCase` for everything else.
- Entity pointers take a `P` prefix: `PChar`, `PMob`, `PTarget`.

### <a id="c-types"/>Project types

Use the aliases in `src/common` over the raw types:

| Use | Instead of | Header |
| --- | --- | --- |
| `uint8` ... `uint64`, `int8` ... `int64` | `uint32_t` etc. | `cbasetypes.h` |
| `Maybe<T>` | `std::optional<T>` | `types/maybe.h` |
| `Box<T>` | `std::unique_ptr<T>` | `types/box.h` |
| `ErrorOr<T, E>` | `std::expected<T, E>` | `types/error_or.h` |
| `Fn<Sig>` | `std::function<Sig>` | `types/fn.h` |
| `HashMap<K, V>` | `std::unordered_map<K, V>` | `types/hash_map.h` |
| `FlatHashMap<K, V>` | a hand-rolled flat map | `types/flat_hash_map.h` |

Free owned raw pointers with `destroy(ptr)` or `destroy_arr(ptr)` from `cbasetypes.h`, never a naked `delete`. Better still, own them with `Box`.

### <a id="c-auto-const"/>auto and const

Declare most variables with `auto`, with the type on the right when it isn't obvious: `const auto x = static_cast<uint16>(y);`. Bind as tightly as you can: `constexpr`, then `const auto` (or `const auto&`), and plain `auto` only when you reassign. Mark member functions `const` when they don't change the object.

### <a id="c-ternaries"/>Ternaries

New code uses an immediately-invoked lambda instead of `?:`. Older code still has ternaries. Don't churn them, but don't add more, and never nest them.

```cpp
// Correct ✔️
const auto delay = [&]
{
    if (isRanged)
    {
        return rangedDelay;
    }

    return meleeDelay;
}();

// Wrong ❌
const auto delay = isRanged ? rangedDelay : meleeDelay;
```

### <a id="c-trailing-return-types"/>Trailing return types for non-void functions

Enforced by clang-tidy (`modernize-use-trailing-return-type`). Functions that return a value use a trailing return type in both declaration and definition. `void` functions and lambdas keep the plain form.

```cpp
// Correct ✔️
auto getName() const -> const std::string&;
auto Classname::getValue() const -> uint16
{
    return value;
}
void setName(const std::string& name);

// Wrong ❌
const std::string& getName() const;
auto setName(const std::string& name) -> void;
```

### <a id="c-braces-around-statements"/>Braces around every statement

```cpp
// Correct ✔️
if (x == 5)
{
    function();
}

// Wrong ❌
if (x == 5)
    function();
```

### <a id="c-breaks-between-consecutive-conditional-statements"/>Blank line between consecutive `if` blocks

```cpp
// Correct ✔️
if (thisThing())
{
}

if (thatThing())
{
}

// Wrong ❌
if (thisThing())
{
}
if (thatThing())
{
}
```

### <a id="c-breaks-to-split-wide-conditional-lines-after-the-operator"/>Split wide conditions after the operator

There's no hard column limit. Avoid sideways scrolling.

```cpp
// Correct ✔️
if (lotsOfStuff &&
    evenMoreStuff &&
    evenMoreStuff)
{
}

// Wrong ❌
if (lotsOfStuff
    && evenMoreStuff
    && evenMoreStuff)
{
}
```

### <a id="c-casting-static-cast-over-c-style"/>Casts

Use `static_cast`, never a C-style cast. When you aren't certain of an entity's type, downcast with `dynamic_cast` and check the result. A failed `static_cast` doesn't give you `nullptr`, so a null check after it proves nothing.

```cpp
// Correct ✔️
const auto param = static_cast<uint32>(input);

if (auto* PChar = dynamic_cast<CCharEntity*>(PEntity))
{
    PChar->doSomething();
}

// Wrong ❌
uint32 param = (uint32)input;

if (auto* PChar = static_cast<CCharEntity*>(PEntity)) // Always true
{
    PChar->doSomething();
}
```

### <a id="c-lambdas"/>Lambdas

When a lambda is a function argument, start it on its own line after the open parenthesis and let clang-format indent it. Don't wrap lambdas in `// clang-format off` guards.

```cpp
// Correct ✔️
PChar->ForParty(
    [&](CBattleEntity* PMember)
    {
        PMember->doStuff();
    });

// Wrong ❌
// clang-format off
PChar->ForParty([&](CBattleEntity* PMember)
{
    PMember->doStuff();
});
// clang-format on
```

### <a id="c-misc"/>Other rules

- Every `.cpp` and `.h` under `src/` carries the GPLv3 licence header. Copy it from a neighbouring file.
- No `#include "../..."`. Include from the source root.
- Put a blank line after `TracyZoneScoped;`.
- A new `triggerListener("NAME")` must be listed in `docs/AI_Events.txt`.
- clang-tidy also flags uninitialised variables, `malloc`, `goto`, missing `override`, `NULL` instead of `nullptr`, and `push_back` where `emplace_back` fits. See `.clang-tidy`.
- Prefer the standard library to hand-rolled code.
- Throw exceptions only when something has gone badly wrong, such as a risk of corrupt player data. Catch the ones that third-party code throws in normal use (LuaJIT does), and move on.
- Heavy work belongs in C++, not Lua. See [Programming for Performance](Programming-for-Performance).

[Back to Top](#table-of-contents)

## <a id="lua"/>Lua

`tools/ci/sanity_checks/lua_stylecheck.py` and luacheck enforce most of this. LuaLS also type-checks the scripts in CI.

### <a id="lua-naming-and-misc"/>Naming and Misc

- `lowerCamelCase` for functions, locals and table members. No capitals or underscores in local names, except `ID`.
- Use `local` for everything. Globals are a luacheck error.
- Strings take single quotes.
- Indent with 4 spaces.
- Build strings with `string.format`, not `..`.
- Use enums (`xi.item.X`, `xi.effect.X`, `xi.mission.id.X`), not numbers. The style check rejects literal ids in calls such as `addItem`, `messageSpecial` and `addStatusEffect`.
- Get a zone's IDs with `local ID = zones[xi.zone.X]`. Don't `require` an `IDs` file.
- Use `math.random(lo, hi)` with both bounds, or `math.randomInt`/`math.randomFloat`.
- No `== true` or `== false`.
- `scripts/globals/npc_util.lua` has helpers for common NPC work.
- A shortened name must keep its meaning:

```lua
-- Correct ✔️
local copMissionStatus = player:getCharVar('PromathiaStatus')
local sandyQuests      = xi.quest.id.sandoria

-- Wrong ❌
local missionStatus = player:getCharVar('PromathiaStatus')
local quests        = xi.quest.id.sandoria
```

### <a id="lua-header"/>File headers

Script headers and section dividers are lines of exactly 35 dashes. The NPC header layout is in the [NPC header guide](https://github.com/LandSandBoat/server/blob/base/docs/ai_agents/npc-header-guide.md).

```lua
-----------------------------------
-- Area: Port Bastok
--  NPC: Example
-----------------------------------
```

### <a id="lua-allman-braces"/><a id="lua-table-formatting"/>Table formatting

Multi-line tables open their brace on a new line and end every entry with a comma. Align `=` across consecutive fields and assignments.

```lua
-- Correct ✔️
local table =
{
    one   = 1,
    three = 3,
}

-- Correct (small tables) ✔️
local table = { 1, 2, 3, 4 }

-- Wrong ❌
local table = {
    one = 1,
    three = 3
}
```

The one exception is a table passed as the only argument to a call:

```lua
-- Correct ✔️
xi.func({
    entry = 1,
    other = 2,
})

-- Wrong ❌
xi.func(
    {
        entry = 1,
        other = 2,
    }
)
```

### <a id="lua-no-parentheses-unless-needed-to-clarify-order-of-operations"/>Parentheses only where they clarify precedence

```lua
-- Correct ✔️
if condition1 and (condition2 or condition3) then
    trigger()
end

-- Wrong ❌
if (condition1 == 1) then
    trigger()
end
```

### <a id="lua-no-semicolons"/>No semicolons

```lua
-- Correct ✔️
local x = 42
trigger(42)

-- Wrong ❌
local x = 42;
```

### <a id="lua-formatting-conditional-blocks"/>Conditional blocks

Nothing follows `then` on the same line. A long condition (over 72 characters with `and`/`or`) goes on its own lines, with `if` and `then` alone. Put `not` before a term and `and`/`or` at the end of a line.

```lua
-- Correct ✔️
if condition then
    bla()
end

-- Correct ✔️
if
    condition1 and
    condition2 or
    not condition3
then
    bla()
end

-- Wrong ❌
if condition1 and condition2 and
    not condition3 then
    bla()
end

-- Wrong ❌
if
    condition1
    and condition2
then
    bla()
end
```

### <a id="lua-no-excess-whitespace"/>Whitespace

- No padding inside parentheses: `(a or b)`, not `( a or b )`.
- No space between a function name and its `(`. One space after each comma.
- One space either side of operators: `a = b + c`.
- A blank line after `end` when more code follows at the same level.
- No blank line straight after a function header or straight before its `end`.
- No one-line functions or `if` blocks.

```lua
-- Correct ✔️
local function myFunction(param1, param2)
    if param1 == param2 then
        return param1 + param2
    end

    return 0
end

-- Wrong ❌
local function myFunction (param1,param2)

    if param1==param2 then return param1+param2 end
    return 0
end
```

### <a id="lua-tests"/>Tests

Lua tests live in `scripts/tests`. See [Testing](Testing).

[Back to Top](#table-of-contents)

## <a id="yaml"/>YAML and data

Game data lives in `data/`: zone, mob, NPC and region data in `data/zones/<zone>/`, enums in `data/enums/`, and shared tables in `data/*.yaml`. Code generators turn the enums into `scripts/enum/*.codegen.lua` and C++ headers. Edit the YAML, never the generated files.

- Format with `python3 tools/yaml/format.py <files>`: 2-space indent, single quotes, aligned values and comments. CI runs it with `--check`.
- Every file starts with its `# yaml-language-server: $schema=` line.
- A change under `data/` or `tools/codegen` runs the `data_schema_check` build target in CI.
- JSON under `data/` is formatted with Prettier 3 (`.prettierrc`).

[Back to Top](#table-of-contents)

## <a id="sql"/>SQL

- Don't quote numbers: `42,0`, not `'42','0'`.
- One statement per line. Don't break an `INSERT` across lines.
- Keywords in upper case: `INSERT INTO`, not `insert into`.
- Names use underscores for spaces. Hyphens are allowed. Strip most other symbols from item, mob and NPC names, except in `polutils_name` and `packet_name`, where you escape them.
- Skill, spell, pet and ability names are lower case.
- `--` comments need a space after them, and a line can't start with `--- `.
- Schema changes need a migration in `tools/migrations`.

### <a id="sql-commenting-in-sql"/>Comments

Add a short trailing comment when a row isn't readable on its own. Don't use `;` inside the comment.

```sql
INSERT INTO `mob_droplist` VALUES (504,0,0,1000,888,340); -- (Colossal Calamari) seashell
```

A row with a name column needs no comment:

```sql
INSERT INTO `abilities` VALUES (16,'mighty_strikes',1,0,1,3600,0,0,0,33,2000,0,6,0,0,0,1,300,0,0,NULL);
```

### <a id="sql-placeholder-data-in-table-rows"/>Placeholder data

Comment out a row whose data you haven't captured (a guessed model, say) rather than committing it with a note. A row that "works" won't get finished, and players report it as our bug. A commented-out row is plainly incomplete.

```sql
-- Missing model
-- INSERT INTO `item_equipment` VALUES (65534,'holy_moly_mace',43,0,1048645,???,0,0,3,0,0);
```

Never substitute item modifiers.

[Back to Top](#table-of-contents)

## <a id="python"/>Python

Python is for tools, under `tools/`.

- `lower_snake_case` names.
- Format with Black's defaults. CI runs `black --check` and `pylint --errors-only` on changed files.

[Back to Top](#table-of-contents)
