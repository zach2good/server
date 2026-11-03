# AGENTS.md

LandSandBoat (LSB) is an open-source FFXI server emulator: C++23 servers that run Lua game scripts against a MariaDB database and YAML game data.

Read [`docs/ai_agents/README.md`](docs/ai_agents/README.md) first. It sets the project's rules for AI-assisted work, and maintainers close PRs that ignore them.

## Ground rules

- Retail FFXI is the spec. You have no access to retail or the client, so don't invent values, ids, message ids or event flow. Get them from packet captures, event dumps, the in-repo tables below, or wikis (the Japanese wiki over BG Wiki over FFXIclopedia), and say which.
- When a value is unverified, say so in your reply and leave a `TODO:` in the code. Never present a guess as retail.
- Copy the patterns of nearby, recently changed code. Plenty of older files predate the current style and APIs. So does anything you remember from DarkStar, Topaz, Windower or other Lua projects.
- Keep changes small and in scope. Don't reformat or refactor code you weren't asked to touch.
- Leave commit messages and PR descriptions to the human, or keep them to the format in [the Git guide](docs/wiki/Development-Guide-Git.md#writing-useful-commit-messages). Don't add AI attribution trailers.
- If a change closes a hole a player could abuse, follow [Security Fixes](CONTRIBUTING.md#security-fixes). Never say "exploit", "dupe" or "vulnerability" in a commit, PR, comment or test, never write reproduction steps, and tell the user to report it privately.

## Layout

| Path | What lives there |
| --- | --- |
| `src/common` | Shared runtime: settings, logging, scheduler, IPC, type aliases (`types/`) |
| `src/login` | Login/lobby server, target `xi_connect` |
| `src/map` | Game server, target `xi_map`. Lua bindings in `lua/`, packets in `packets/`, AI in `ai/` |
| `src/world` | World server, target `xi_world`: conquest, Besieged, campaign, parties |
| `src/search`, `src/profile` | `xi_search`, `xi_profile` |
| `src/test` | `xi_test` harness. Catch2 tests in `src/test/tests` |
| `scripts/zones/<Zone>/` | `IDs.lua`, `Zone.lua`, `DefaultActions.lua`, `npcs/`, `mobs/` |
| `scripts/quests`, `scripts/missions` | Quests and missions on the Interaction Framework (`scripts/globals/interaction`) |
| `scripts/actions` | Abilities, mob skills, spells, weapon skills |
| `scripts/enum` | Lua enums. `*.codegen.lua` files are generated, never edit them |
| `scripts/specs` | LuaLS annotations for the C++ bindings |
| `scripts/tests` | Lua tests run by `xi_test` |
| `data/enums/*.yaml` | Enum sources for the generated Lua and C++ enums |
| `data/zones/<zone>/` | `zone.yaml`, `mobs.yaml`, `npcs.yaml`, `regions.yaml`: NPC and mob placement, spawns, drops |
| `data/*.yaml` | Shared datasets (experience, merits, skills, status effects) |
| `sql/` | Schema and static data, one table per file. `tools/migrations` for schema changes |
| `settings/default/` | Default settings. Local overrides go in `settings/`, which git ignores |
| `modules/` | Optional C++, Lua and SQL overrides. `modules/init.txt` picks what loads |
| `tools/` | `build.py`, `dbtool.py`, codegen, CI checks |

NPC, mob, spawn and drop data moved from SQL to `data/zones/*`. `sql/npc_list.sql` and `sql/mob_spawn_points.sql` now hold only instanced and dynamic zones.

## Build

Run everything from the repo root. Binaries land there.

```sh
pip install -r tools/requirements.txt   # configure fails without jinja2, jsonschema, ruamel.yaml
python3 tools/build.py                  # default preset, RelWithDebInfo
python3 tools/build.py -t xi_map        # one target
python3 tools/build.py -p debug         # debug, release and tracy presets also exist
```

On Windows, `build.py` enters the Visual Studio developer environment itself. A bare `cmake` from a plain shell can't find the MSVC headers.

Targets: `xi_map`, `xi_world`, `xi_connect`, `xi_search`, `xi_profile`, `xi_test`. `xi_map` and `xi_test` validate all of `data/` at build time, so bad YAML breaks the build.

## Test

`xi_test` needs a populated database (`python3 tools/dbtool.py update`). It runs the Catch2 tests, then the Lua suite in `scripts/tests`.

```sh
./xi_test --keep-going                      # everything, as CI does
./xi_test --file 'missions/cop'             # files matching a regex
./xi_test --filter 'trades the item'        # tests whose name matches a regex
```

Never run two `xi_test` processes at once. They share `xidb` and the test character ids, and fail in confusing ways.

Add a test for behaviour you change. See [Testing](docs/wiki/Testing.md).

## Check before you finish

Commit, then run the checks CI runs on a PR:

```sh
./tools/ci/sanity_checks.sh origin/base
```

Single checks, the full style rules and the tools they need are in the [Development Guide](docs/wiki/Development-Guide.md#before-you-push). The ones agents trip over most:

- C++ is formatted by clang-format **22** (`python3 tools/run_clang_format.py`).
- Lua strings take single quotes. Use enums, not literal ids. Build strings with `string.format`.
- A new Lua global must be added to `global_objects` in `tools/ci/sanity_checks/lua.sh`.
- A new C++ Lua binding needs a matching entry in `scripts/specs`.
- YAML under `data/` must pass `python3 tools/yaml/format.py <files> --check`.

## Review rules

CI won't catch these. Reviewers will. The full list is the [Review Checklist](docs/wiki/Review-Checklist.md). Read it before you write Lua, C++ or SQL. The ones raised most often:

- No one-line Lua helpers and no function used in only one place. Inline them.
- Return early instead of nesting. No guard the next expression already covers. No nil checks on values that always exist.
- Tables over `if`/`elseif` chains. Enums over magic numbers. No local for a value used once.
- Put code where it belongs: quest logic in `scripts/quests`, mob behaviour in the mob script or a mixin, no logic in zone scripts or `IDs.lua`, entity iteration in C++.
- No new binding, setting or enum entry without a use in the same change.
- Every new value has a source. Mark guesses with `-- TODO: Capture needed` (Lua, SQL) or `# TODO: Capture needed` (YAML).
- Comments go above the code they describe, and say why, not what.

## Traps

- Edit the YAML in `data/enums`, never the generated `scripts/enum/*.codegen.lua`, `data/schemas/*.schema.json` or anything under `build/generated`.
- Text and message ids in `IDs.lua` differ per zone. Never copy one from another zone.
- An NPC id is `0x1000000 + (zoneId << 12) + index`.
- `dbtool.py update` diffs `sql/` between commits, so it skips uncommitted SQL edits. Use `dbtool.py update full`.
- Player tables (`chars`, `char_*`, `accounts` and others, listed in `dbtool.py`) are never overwritten by updates. Changing their schema needs a migration.
- The repo root collects local logs, binaries and profiler output. Most of it is git-ignored. Don't treat it as source.

## Reference data in the repo

- `docs/MessageSystemIDs.log` and `docs/message.log`: client message dumps, ids matching the message enums.
- `docs/*.txt` and `docs/Regime_IDs.csv`: battlefield, music, model, animation and other id tables. Some predate `data/enums`. When they disagree, `data/enums` wins.
- `docs/AI_Events.txt`: every `triggerListener` event.
- Task guides in [`docs/ai_agents`](docs/ai_agents/README.md#available-agent-guides): Interaction Framework migration, NPC script headers, retail packet captures.
