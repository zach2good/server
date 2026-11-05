/*
===========================================================================

  Copyright (c) 2021 LandSandBoat Dev Teams

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

#include <common/macros.h>
#include <common/tracy.h>

#include <cstdint>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>

#include <fmt/format.h>
#include <fmt/printf.h>

#include <spdlog/spdlog.h>

//
// Forward declaration
//

namespace settings
{

template <typename T>
auto get(std::string_view) -> T;

} // namespace settings

namespace logging
{

void InitializeLog(const std::string& serverName, const std::string& logFile, bool appendDate);
void ShutDown();

void SetPattern(const std::string& str);

// One breadcrumb slot; `file` points at a __FILE__ literal, so it is stored rather than copied.
struct BacktraceEntry
{
    const char*   file{ nullptr };
    int           line{ 0 };
    std::uint64_t sequence{ 0 };
    std::string   message;
};

namespace detail
{

// Separate rings, so a busy tick cannot evict the warnings and errors you want after a crash.
void pushTraceEntry(const char* file, int line, const char* message, std::size_t length);
void pushEventEntry(const char* file, int line, const char* message, std::size_t length);

// Reused across calls so formatting a breadcrumb does not allocate.
auto scratchBuffer() -> fmt::memory_buffer&;

} // namespace detail

template <typename... Args>
void AddTrace(const char* file, int line, fmt::format_string<Args...> formatStr, Args&&... args)
{
    auto& scratch = detail::scratchBuffer();
    scratch.clear();
    fmt::format_to(std::back_inserter(scratch), formatStr, std::forward<Args>(args)...);
    detail::pushTraceEntry(file, line, scratch.data(), scratch.size());
}

void AddTraceString(const char* file, int line, std::string_view message);
void AddBacktrace(const char* file, int line, std::string_view message);

// Both rings merged into sequence order, oldest first, rendered as "file:line: message".
auto GetBacktrace() -> std::vector<std::string>;

// Returns the logger registered under `name` ("debug", "info", "error", ...).
// Resolved during InitializeLog and read lock-free afterward, so emit paths avoid
// spdlog's registry mutex on every log call. Non-owning; valid until the next refresh.
auto loggerFor(std::string_view name) -> spdlog::logger*;

// Re-resolves the lock-free loggerFor cache from the spdlog registry. MUST be called after
// anything that drops/re-registers loggers (e.g. spdlog::shutdown + re-register), otherwise
// loggerFor would return dangling pointers. Call when no other thread is logging.
void RefreshLoggerCache();

void tapWarningOrError();

namespace detail
{

inline bool gJsonMode{ false };

struct LogRecord
{
    std::string_view levelName;
    std::string_view file;
    int              line;
    std::string_view function;
    std::string_view msg;
};

void renderJsonLine(fmt::memory_buffer& buf, const LogRecord& rec);

// The sink end of every Show*/Debug* macro, kept out of line. Inlined, its buffers (the JSON path's
// fmt::memory_buffer alone is 500 bytes) and spdlog's machinery land in the stack frame of whatever
// function contains the log call, so a small hot function with a never-taken error branch pays a large
// frame, ten saved registers and a stack-protector check on every call.
XI_COLD void emit(spdlog::level::level_enum level, std::string_view loggerName, const char* file, int line, const char* function, std::string_view message);

// END_CATCH_HANDLER's reporting, out of line for the same reason. `what` is null for a non-std exception.
XI_COLD void reportLoggingException(const char* file, int line, const char* what);

} // namespace detail

} // namespace logging

// clang-format off

template <typename T>
auto asStringFromUntrustedSource(const T* ptr, size_t max_size) -> std::string
{
    if (!ptr)
    {
        return "";
    }

    const auto str = reinterpret_cast<const char*>(ptr);
    const auto len = strnlen(str, max_size);
    return std::string(str, len);
}

// Helper for allowing `enum` and `enum class` types to be formatted
// as their underlying numeric type.
#define DECLARE_FORMAT_AS_UNDERLYING(type) \
inline auto format_as(type v) \
{ \
    return std::to_underlying(v); \
}

#define STATEMENT_CLOSE \
    std::ignore = 0

// NOTE: In order to preserve the ability for Tracy and spdlog to track the source location of
//     : logging calls, we have to stack a lot of macros. This leads to some strangeness with
//     : the output of Tracy: Each logging call creates its own scope, and will have its own
//     : entry in the Tracy statistics. This is a low price to pay for the ability to profile
//     : logging calls, and everything else, and still have all the information we want delivered
//     : to the logging system.
#define BEGIN_CATCH_HANDLER \
    try                     \
    {

#define END_CATCH_HANDLER(File, Line)                                   \
    }                                                                   \
    catch (std::exception const& ex)                                    \
    {                                                                   \
        ::logging::detail::reportLoggingException(File, Line, ex.what()); \
    }                                                                   \
    catch (...)                                                         \
    {                                                                   \
        ::logging::detail::reportLoggingException(File, Line, nullptr); \
    } STATEMENT_CLOSE

// LOG_TYPE_MACRO names the spdlog macro for the level; these map it to the level itself.
#define XI_LOG_LEVEL_SPDLOG_LOGGER_DEBUG    ::spdlog::level::debug
#define XI_LOG_LEVEL_SPDLOG_LOGGER_INFO     ::spdlog::level::info
#define XI_LOG_LEVEL_SPDLOG_LOGGER_WARN     ::spdlog::level::warn
#define XI_LOG_LEVEL_SPDLOG_LOGGER_ERROR    ::spdlog::level::err
#define XI_LOG_LEVEL_SPDLOG_LOGGER_CRITICAL ::spdlog::level::critical

#define LOGGER_EMIT(LOG_TYPE_MACRO, LogStringName, File, Line, MsgVar) \
    ::logging::detail::emit(XI_LOG_LEVEL_##LOG_TYPE_MACRO, LogStringName, File, Line, static_cast<const char*>(__FUNCTION__), MsgVar)

#define LOGGER_BODY(LOG_TYPE_MACRO, LogStringName, File, Line, ...) \
    BEGIN_CATCH_HANDLER const auto _msgStr = fmt::sprintf(__VA_ARGS__); TracyZoneScoped; TracyMessageStr(_msgStr); logging::AddBacktrace(File, Line, _msgStr); LOGGER_EMIT(LOG_TYPE_MACRO, LogStringName, File, Line, _msgStr); END_CATCH_HANDLER(File, Line)

#define LOGGER_BODY_CONDITIONAL(LOG_TYPE_MACRO, LogStringName, LogConditionStr, File, Line, ...) \
    BEGIN_CATCH_HANDLER if (settings::get<bool>(LogConditionStr)) { const auto _msgStr = fmt::sprintf(__VA_ARGS__); TracyZoneScoped; TracyMessageStr(_msgStr); logging::AddBacktrace(File, Line, _msgStr); LOGGER_EMIT(LOG_TYPE_MACRO, LogStringName, File, Line, _msgStr); } END_CATCH_HANDLER(File, Line)

#define LOGGER_BODY_FMT(LOG_TYPE_MACRO, LogStringName, File, Line, ...) \
    BEGIN_CATCH_HANDLER const auto _msgStr = fmt::format(__VA_ARGS__); TracyZoneScoped; TracyMessageStr(_msgStr); logging::AddBacktrace(File, Line, _msgStr); LOGGER_EMIT(LOG_TYPE_MACRO, LogStringName, File, Line, _msgStr); END_CATCH_HANDLER(File, Line)

#define LOGGER_BODY_CONDITIONAL_FMT(LOG_TYPE_MACRO, LogStringName, LogConditionStr, File, Line, ...) \
    BEGIN_CATCH_HANDLER if (settings::get<bool>(LogConditionStr)) { const auto _msgStr = fmt::format(__VA_ARGS__); TracyZoneScoped; TracyMessageStr(_msgStr); logging::AddBacktrace(File, Line, _msgStr); LOGGER_EMIT(LOG_TYPE_MACRO, LogStringName, File, Line, _msgStr); } END_CATCH_HANDLER(File, Line)

// Regular Loggers
// NOTE 1: Trace is not for logging to screen or file; it's for filling the backtrace buffer and reporting to Tracy.
// NOTE 2: It isn't possible (or a good idea) to allow the user to disable TRACE, ERROR, or CRITICAL logging.
#define ShowTrace(...)    logging::AddTraceString(__FILE__, __LINE__, fmt::sprintf(__VA_ARGS__))
#define ShowDebug(...)    LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.LOG_DEBUG", __FILE__, __LINE__, __VA_ARGS__)
#define ShowInfo(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_INFO, "info", "logging.LOG_INFO", __FILE__, __LINE__, __VA_ARGS__)
#define ShowWarning(...)  LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_WARN, "warn", "logging.LOG_WARNING", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowLua(...)      LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_INFO, "lua", "logging.LOG_LUA", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowError(...)    LOGGER_BODY(SPDLOG_LOGGER_ERROR, "error", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowCritical(...) LOGGER_BODY(SPDLOG_LOGGER_CRITICAL, "critical", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()

// Regular Loggers fmt variants
#define ShowTraceFmt(...)    logging::AddTrace(__FILE__, __LINE__, __VA_ARGS__)
#define ShowDebugFmt(...)    LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.LOG_DEBUG", __FILE__, __LINE__, __VA_ARGS__)
#define ShowInfoFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_INFO, "info", "logging.LOG_INFO", __FILE__, __LINE__, __VA_ARGS__)
#define ShowWarningFmt(...)  LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_WARN, "warn", "logging.LOG_WARNING", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowLuaFmt(...)      LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_INFO, "lua", "logging.LOG_LUA", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowErrorFmt(...)    LOGGER_BODY_FMT(SPDLOG_LOGGER_ERROR, "error", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()
#define ShowCriticalFmt(...) LOGGER_BODY_FMT(SPDLOG_LOGGER_CRITICAL, "critical", __FILE__, __LINE__, __VA_ARGS__); logging::tapWarningOrError()

// Debug Loggers
#define DebugSockets(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_SOCKETS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIPC(...)         LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_IPC", __FILE__, __LINE__, __VA_ARGS__)
#define DebugNavmesh(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_NAVMESH",__FILE__, __LINE__, __VA_ARGS__)
#define DebugPackets(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PACKETS",__FILE__, __LINE__, __VA_ARGS__)
#define DebugActions(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_ACTIONS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugSQL(...)         LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_SQL", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIDLookup(...)    LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_ID_LOOKUP", __FILE__, __LINE__, __VA_ARGS__)
#define DebugModules(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_MODULES", __FILE__, __LINE__, __VA_ARGS__)
#define DebugAuctions(...)    LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_AUCTIONS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugDeliveryBox(...) LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_DELIVERY_BOX", __FILE__, __LINE__, __VA_ARGS__)
#define DebugBazaars(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_BAZAARS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugPerformance(...) LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PERFORMANCE", __FILE__, __LINE__, __VA_ARGS__)
#define DebugTest(...)        LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_TEST", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIRC(...)         LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_IRC", __FILE__, __LINE__, __VA_ARGS__)
#define DebugProfile(...)     LOGGER_BODY_CONDITIONAL(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PROFILE", __FILE__, __LINE__, __VA_ARGS__)

// Debug Loggers fmt variants
#define DebugSocketsFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_SOCKETS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIPCFmt(...)         LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_IPC", __FILE__, __LINE__, __VA_ARGS__)
#define DebugNavmeshFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_NAVMESH", __FILE__, __LINE__, __VA_ARGS__)
#define DebugPacketsFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PACKETS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugActionsFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_ACTIONS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugSQLFmt(...)         LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_SQL", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIDLookupFmt(...)    LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_ID_LOOKUP", __FILE__, __LINE__, __VA_ARGS__)
#define DebugModulesFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_MODULES", __FILE__, __LINE__, __VA_ARGS__)
#define DebugAuctionsFmt(...)    LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_AUCTIONS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugDeliveryBoxFmt(...) LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_DELIVERY_BOX", __FILE__, __LINE__, __VA_ARGS__)
#define DebugBazaarsFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_BAZAARS", __FILE__, __LINE__, __VA_ARGS__)
#define DebugPerformanceFmt(...) LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PERFORMANCE", __FILE__, __LINE__, __VA_ARGS__)
#define DebugTestFmt(...)        LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_TEST", __FILE__, __LINE__, __VA_ARGS__)
#define DebugIRCFmt(...)         LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_IRC", __FILE__, __LINE__, __VA_ARGS__)
#define DebugProfileFmt(...)     LOGGER_BODY_CONDITIONAL_FMT(SPDLOG_LOGGER_DEBUG, "debug", "logging.DEBUG_PROFILE", __FILE__, __LINE__, __VA_ARGS__)

// clang-format on
