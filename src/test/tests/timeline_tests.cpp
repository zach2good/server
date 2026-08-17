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
// timeutils::Timeline scheduling contract.
//
// The Conflict (Ballista) match flow is a chain of scheduled events: sign-up
// announcements repeat every few Vana'diel minutes, rooks move on the hour, and
// rounds start and end at fixed times. Two behaviours below are load-bearing and
// easy to regress:
//
//   - A past-due repeating event fires ONCE, not once per missed interval. A match
//     recovered from the database can be hours of Vana'diel time behind; replaying
//     the backlog would spam every player in the zone with one announcement per
//     missed interval.
//
//   - Scheduling reads timer::now(), which honours timer::time_offset. The test
//     harness advances time only through that offset, so a Timeline built on raw
//     steady_clock::now() would silently ignore every skipTime() in the Lua suite.
//
// These run via Catch2 during xi_test startup, before the Lua engine boots.
//

#include "map/utils/timeutils.h"

#include "common/timer.h"

#include <catch2/catch_test_macros.hpp>

#include <chrono>
#include <tuple>
#include <vector>

using namespace std::chrono_literals;

namespace
{

// Restores the global timer offset, so a test that shifts time cannot leak into the rest of the run.
class ScopedTimeOffset
{
public:
    explicit ScopedTimeOffset(const timer::duration offset)
    : saved_(timer::time_offset)
    {
        timer::add_offset(offset);
    }

    ~ScopedTimeOffset()
    {
        timer::time_offset = saved_;
    }

    ScopedTimeOffset(const ScopedTimeOffset&)                    = delete;
    auto operator=(const ScopedTimeOffset&) -> ScopedTimeOffset& = delete;
    ScopedTimeOffset(ScopedTimeOffset&&)                         = delete;
    auto operator=(ScopedTimeOffset&&) -> ScopedTimeOffset&      = delete;

private:
    timer::duration saved_;
};

// Appends a marker each time it runs, and never asks to stop repeating.
auto record(std::vector<int>& log, const int marker) -> Fn<bool()>
{
    return [&log, marker]() -> bool
    {
        log.emplace_back(marker);
        return false;
    };
}

} // namespace

TEST_CASE("Timeline fires events in timestamp order", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    // Added out of order on purpose.
    std::ignore = timeline.AddEvent(now + 30s, record(fired, 3));
    std::ignore = timeline.AddEvent(now + 10s, record(fired, 1));
    std::ignore = timeline.AddEvent(now + 20s, record(fired, 2));

    REQUIRE(timeline.size() == 3);

    timeline.Tick(now + 60s);

    CHECK((fired == std::vector<int>{ 1, 2, 3 }));
    CHECK(timeline.empty());
}

TEST_CASE("Timeline breaks timestamp ties by insertion order", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 10s, record(fired, 1));
    std::ignore = timeline.AddEvent(now + 10s, record(fired, 2));
    std::ignore = timeline.AddEvent(now + 10s, record(fired, 3));

    timeline.Tick(now + 10s);

    CHECK((fired == std::vector<int>{ 1, 2, 3 }));
}

TEST_CASE("Timeline runs priority events ahead of regular ones at the same time", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 10s, record(fired, 1));
    std::ignore = timeline.AddPriorityEvent(now + 10s, record(fired, 0));
    std::ignore = timeline.AddEvent(now + 10s, record(fired, 2));

    timeline.Tick(now + 10s);

    CHECK((fired == std::vector<int>{ 0, 1, 2 }));
}

TEST_CASE("Timeline does not fire events that are not yet due", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 10s, record(fired, 1));
    std::ignore = timeline.AddEvent(now + 60s, record(fired, 2));

    timeline.Tick(now + 30s);

    CHECK((fired == std::vector<int>{ 1 }));
    CHECK(timeline.size() == 1);
}

TEST_CASE("Timeline coalesces a past-due repeating event into a single fire", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 1s, record(fired, 1), timeutils::ForceAdd::Yes, 1s);

    // Ten intervals have elapsed since the event was due. It must report once, not ten times.
    timeline.Tick(now + 10s);

    CHECK((fired == std::vector<int>{ 1 }));

    // ...and it is still scheduled, strictly in the future.
    REQUIRE(timeline.size() == 1);

    timeline.Tick(now + 11s);

    CHECK((fired == std::vector<int>{ 1, 1 }));
}

TEST_CASE("Timeline repeats a bounded event exactly the requested number of times", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 1s, record(fired, 1), timeutils::ForceAdd::Yes, 1s, 3);

    for (auto second = 1; second <= 10; ++second)
    {
        timeline.Tick(now + std::chrono::seconds(second));
    }

    CHECK(fired.size() == 3);
    CHECK(timeline.empty());
}

TEST_CASE("Timeline repeats an unbounded event until its action stops it", "[timeline]")
{
    const auto now = timer::now();

    auto timeline = timeutils::Timeline();
    auto runs     = 0;

    std::ignore = timeline.AddEvent(now + 1s, [&runs]() -> bool
                                    {
                                        ++runs;
                                        return runs == 4;
                                    },
                                    timeutils::ForceAdd::Yes,
                                    1s);

    for (auto second = 1; second <= 10; ++second)
    {
        timeline.Tick(now + std::chrono::seconds(second));
    }

    CHECK(runs == 4);
    CHECK(timeline.empty());
}

TEST_CASE("Timeline drops a skippable one-shot event that is already late", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    const auto skipped = timeline.AddEvent(now - 10s, record(fired, 1), timeutils::ForceAdd::No);
    const auto forced  = timeline.AddEvent(now - 10s, record(fired, 2), timeutils::ForceAdd::Yes);

    CHECK_FALSE(skipped.has_value());
    CHECK(forced.has_value());

    timeline.Tick(now);

    CHECK((fired == std::vector<int>{ 2 }));
}

TEST_CASE("Timeline skips a late repeating event forward instead of dropping it", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    // Due 10 intervals ago, but it repeats, so it belongs on the heap at its next future occurrence.
    REQUIRE(timeline.AddEvent(now - 10s, record(fired, 1), timeutils::ForceAdd::No, 1s).has_value());

    timeline.Tick(now);

    CHECK(fired.empty());

    timeline.Tick(now + 1s);

    CHECK((fired == std::vector<int>{ 1 }));
}

TEST_CASE("Timeline drops a late repeating event whose repeats are exhausted", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    // Three repeats requested, but ten intervals have already passed.
    const auto eventId = timeline.AddEvent(now - 10s, record(fired, 1), timeutils::ForceAdd::No, 1s, 3);

    CHECK_FALSE(eventId.has_value());
    CHECK(timeline.empty());
}

TEST_CASE("Timeline Clean drops pending events and is idempotent", "[timeline]")
{
    const auto now = timer::now();

    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    std::ignore = timeline.AddEvent(now + 10s, record(fired, 1));
    std::ignore = timeline.AddEvent(now + 20s, record(fired, 2));

    timeline.Clean();
    CHECK(timeline.empty());

    timeline.Clean();
    CHECK(timeline.empty());

    timeline.Tick(now + 60s);

    CHECK(fired.empty());
}

TEST_CASE("Timeline schedules against the offset clock, not raw steady_clock", "[timeline]")
{
    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    {
        // Jump an hour forward the way the Lua test harness does.
        const auto shifted = ScopedTimeOffset(1h);

        // Due 10 seconds ago on the shifted clock. A Timeline reading raw steady_clock::now()
        // would place this an hour in the future and drop it as unreachable.
        const auto eventId = timeline.AddEvent(timer::now() - 10s, record(fired, 1), timeutils::ForceAdd::No, 1s);

        REQUIRE(eventId.has_value());

        timeline.Tick(timer::now() + 1s);
    }

    CHECK((fired == std::vector<int>{ 1 }));
}

TEST_CASE("Timeline stops draining when an action empties it", "[timeline]")
{
    auto             timeline = timeutils::Timeline();
    std::vector<int> fired;

    const auto now = timer::now();

    // A repeating event that cleans the timeline from inside its own action. Re-queueing it
    // afterwards would leave one event alive on a timeline that was just emptied.
    std::ignore = timeline.AddEvent(
        now - 1s,
        [&]() -> bool
        {
            fired.emplace_back(1);
            timeline.Clean();

            return false;
        },
        timeutils::ForceAdd::Yes,
        1s);

    std::ignore = timeline.AddEvent(now - 1s, record(fired, 2), timeutils::ForceAdd::Yes);

    timeline.Tick(now);

    CHECK((fired == std::vector<int>{ 1 }));
    CHECK(timeline.empty());
}

TEST_CASE("Timeline does not spin on an action that schedules past-due work", "[timeline]")
{
    auto timeline = timeutils::Timeline();
    auto fired    = 0;

    const auto now = timer::now();

    // Each firing queues another event already due, which an unbounded drain would chase forever.
    std::ignore = timeline.AddEvent(
        now - 1s,
        [&]() -> bool
        {
            ++fired;
            std::ignore = timeline.AddEvent(now - 1s, [&]() -> bool
                                            {
                                                ++fired;
                                                return true;
                                            },
                                            timeutils::ForceAdd::Yes);

            return true;
        },
        timeutils::ForceAdd::Yes);

    timeline.Tick(now);

    // Bounded rather than hung. The exact ceiling is an implementation detail; that it returns is not.
    CHECK(fired > 0);
    CHECK(fired <= 256);
}
