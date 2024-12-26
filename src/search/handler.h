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

#include <asio/ts/buffer.hpp>
#include <asio/ts/internet.hpp>

#include "search_handler.h"

template <typename T>
class handler
{
public:
    handler(asio::io_context& io_context, unsigned int port, shared_guarded<std::unordered_set<std::string>>& in_IPAddressInUseList, shared_guarded<std::unordered_set<std::string>>& in_IPAddressWhitelist)
    : acceptor_(io_context, asio::ip::tcp::endpoint(asio::ip::tcp::v4(), port))
    , io_context_(io_context)
    , IPAddressInUseList_(in_IPAddressInUseList)
    , IPAddressWhitelist_(in_IPAddressWhitelist)
    {
        acceptor_.set_option(asio::socket_base::reuse_address(true));

        do_accept();
    }

private:
    void do_accept()
    {
        // clang-format off
        acceptor_.async_accept(
        [this](std::error_code ec, asio::ip::tcp::socket socket)
        {
            if (!ec)
            {
                if constexpr (std::is_same_v<T, search_handler>)
                {
                    auto auth_handler = std::make_shared<T>(std::move(socket), io_context_, IPAddressInUseList_, IPAddressWhitelist_);
                    auth_handler->start();
                }
            }
            else
            {
                ShowError(ec.message());
            }

            do_accept();
        });
        // clang-format on
    }

    asio::ip::tcp::acceptor acceptor_;

    asio::io_context& io_context_; // Handed off to the handler for timers

    // Handed off to the handler for shared state
    shared_guarded<std::unordered_set<std::string>>& IPAddressInUseList_;
    shared_guarded<std::unordered_set<std::string>>& IPAddressWhitelist_;
};
