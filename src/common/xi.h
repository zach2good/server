/*
===========================================================================

  Copyright (c) 2024 LandSandBoat Dev Teams

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

#include <optional>
#include <type_traits>
#include <utility>

// The purpose of this namespace IS NOT to replace the C++ standard library.
//
// It is to provide convenience wrappers around common standard library types
// so that they are easier and more intuitive to use in the context of this project.
//
// You should be:
// - Forwarding all of the expected and useful functions from the underlying standard library type
// - Not forwarding/hiding the ones that are not useful
// - Adding new functions that are useful and convenient

namespace xi
{

    // A wrapper around std::optional to allow usage of object.apply([](auto& obj) { ... });
    // https://en.cppreference.com/w/cpp/utility/optional
    template <typename T>
    class optional
    {
    public:
        constexpr optional() = default;
        constexpr explicit optional(std::nullopt_t) noexcept
        : m_value(std::nullopt)
        {
        }
        constexpr optional(const optional& other)                = default;
        constexpr optional(optional&& other) noexcept            = default;
        constexpr optional& operator=(const optional& other)     = default;
        constexpr optional& operator=(optional&& other) noexcept = default;
        ~optional()                                              = default;

        constexpr optional& operator=(std::nullopt_t) noexcept
        {
            m_value = std::nullopt;
            return *this;
        }

        constexpr optional& operator=(T&& value)
        {
            m_value = std::move(value);
            return *this;
        }

        template <typename F>
        constexpr void apply(F&& f) &
        {
            if (m_value)
            {
                f(*m_value);
            }
        }

        template <typename F>
        constexpr void apply(F&& f) const&
        {
            if (m_value)
            {
                f(*m_value);
            }
        }

        constexpr explicit operator bool() const noexcept
        {
            return m_value.has_value();
        }

        constexpr T& operator*() &
        {
            return *m_value;
        }

        constexpr const T& operator*() const&
        {
            return *m_value;
        }

        constexpr T* operator->() noexcept
        {
            return m_value.operator->();
        }

        constexpr const T* operator->() const noexcept
        {
            return m_value.operator->();
        }

        constexpr void reset() noexcept
        {
            m_value.reset();
        }

        template <typename... Args>
        constexpr T& emplace(Args&&... args)
        {
            return m_value.emplace(std::forward<Args>(args)...);
        }

        constexpr bool operator==(const optional& other) const
        {
            return m_value == other.m_value;
        }

        constexpr bool operator!=(const optional& other) const
        {
            return m_value != other.m_value;
        }

    private:
        std::optional<T> m_value;
    };

    // TODO: A wrapper around std::variant to allow usage of:
    //     :   object.visit(overloaded{...});
    //     :   object.get<T>() -> xi::optional<T>;

} // namespace xi
