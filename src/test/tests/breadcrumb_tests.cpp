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

#include <common/breadcrumbs.h>
#include <common/logging.h>

#include <catch2/catch_test_macros.hpp>

#include <cstdint>
#include <cstdio>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace
{

// Rings are process-wide and outlive each test, so every test tags its breadcrumbs and only looks at those.
auto crumbsWithPrefix(const std::string_view prefix) -> std::vector<breadcrumbs::Entry>
{
    std::vector<breadcrumbs::Entry> matching;
    for (auto& entry : breadcrumbs::snapshot())
    {
        if (entry.message.starts_with(prefix))
        {
            matching.push_back(std::move(entry));
        }
    }
    return matching;
}

} // namespace

TEST_CASE("Breadcrumbs format strings, integers and format specs on read", "[breadcrumbs]")
{
    const std::string   name = "Wild_Rabbit";
    const std::uint32_t id   = 17187006;
    const std::uint16_t type = 0x01A;

    const int line = __LINE__ + 1;
    XI_BREADCRUMB("bc-format: {} ({}) 0x{:04X} {}", name, id, type, "literal");

    const auto crumbs = crumbsWithPrefix("bc-format:");
    REQUIRE(crumbs.size() == 1);
    CHECK(crumbs[0].message == "bc-format: Wild_Rabbit (17187006) 0x001A literal");
    CHECK(crumbs[0].line == line);
    CHECK(std::string_view(crumbs[0].file).ends_with("breadcrumb_tests.cpp"));
}

TEST_CASE("Breadcrumbs truncate strings that do not fit and mark them", "[breadcrumbs]")
{
    const std::string longText(300, 'x');
    XI_BREADCRUMB("bc-truncate: {} {}", longText, 7);

    const auto crumbs = crumbsWithPrefix("bc-truncate:");
    REQUIRE(crumbs.size() == 1);

    const auto& message = crumbs[0].message;
    CHECK(message.ends_with("…"));
    CHECK(message.size() < longText.size());
    // Numbers are never cut: they sit in the fixed part of the slot.
    CHECK(message.find(" 7") != std::string::npos);
}

TEST_CASE("Breadcrumbs keep the newest slots of a thread in order", "[breadcrumbs]")
{
    constexpr std::size_t kWrites = breadcrumbs::kRingSlots + 10;
    for (std::size_t i = 0; i < kWrites; ++i)
    {
        XI_BREADCRUMB("bc-wrap: {}", i);
    }

    const auto crumbs = crumbsWithPrefix("bc-wrap:");
    REQUIRE(crumbs.size() == breadcrumbs::kRingSlots);
    for (std::size_t i = 0; i < crumbs.size(); ++i)
    {
        CHECK(crumbs[i].message == "bc-wrap: " + std::to_string(i + 10));
    }
}

TEST_CASE("Breadcrumbs from several threads all show up, each in its own order", "[breadcrumbs]")
{
    constexpr int kThreads = 3;
    constexpr int kPerThread = static_cast<int>(breadcrumbs::kRingSlots); // a thread's ring keeps this many

    std::vector<std::thread> threads;
    for (int t = 0; t < kThreads; ++t)
    {
        threads.emplace_back(
            [t]
            {
                for (int i = 0; i < kPerThread; ++i)
                {
                    XI_BREADCRUMB("bc-threads: {} {}", t, i);
                }
            });
    }
    for (auto& thread : threads)
    {
        thread.join();
    }

    const auto crumbs = crumbsWithPrefix("bc-threads:");
    REQUIRE(crumbs.size() == static_cast<std::size_t>(kThreads * kPerThread));

    std::vector<int> next(kThreads, 0);
    for (const auto& crumb : crumbs)
    {
        int t = -1;
        int i = -1;
        REQUIRE(std::sscanf(crumb.message.c_str(), "bc-threads: %d %d", &t, &i) == 2);
        REQUIRE(t >= 0);
        REQUIRE(t < kThreads);
        CHECK(i == next[t]);
        next[t] = i + 1;
    }
}

TEST_CASE("GetBacktrace merges log lines and breadcrumbs onto one timeline", "[breadcrumbs]")
{
    ShowErrorFmt("bc-merge: log {}", 1);
    XI_BREADCRUMB("bc-merge: crumb {}", 2);

    const auto backtrace = logging::GetBacktrace();

    std::size_t logAt   = backtrace.size();
    std::size_t crumbAt = backtrace.size();
    for (std::size_t i = 0; i < backtrace.size(); ++i)
    {
        if (backtrace[i].ends_with(": bc-merge: log 1"))
        {
            logAt = i;
        }
        if (backtrace[i].ends_with(": bc-merge: crumb 2"))
        {
            crumbAt = i;
        }
    }

    REQUIRE(logAt < backtrace.size());
    REQUIRE(crumbAt < backtrace.size());
    CHECK(logAt < crumbAt);
    CHECK(backtrace[crumbAt].find("breadcrumb_tests.cpp:") != std::string::npos);
    CHECK(backtrace[logAt].find("breadcrumb_tests.cpp:") != std::string::npos);
}

TEST_CASE("Log lines survive a flood of breadcrumbs", "[breadcrumbs]")
{
    // Log lines go to the separate event ring, so breadcrumbs cannot evict them.
    ShowErrorFmt("bc-flood: error {}", 42);
    for (std::size_t i = 0; i < 2 * breadcrumbs::kRingSlots; ++i)
    {
        XI_BREADCRUMB("bc-flood-noise: {}", i);
    }

    CHECK(crumbsWithPrefix("bc-flood: error 42").size() == 1);
}

TEST_CASE("Long log lines fit in an event slot", "[breadcrumbs]")
{
    const std::string detail(300, 'y');
    ShowErrorFmt("bc-long: {}", detail);

    const auto crumbs = crumbsWithPrefix("bc-long:");
    REQUIRE(crumbs.size() == 1);
    CHECK(crumbs[0].message == "bc-long: " + detail);
}
