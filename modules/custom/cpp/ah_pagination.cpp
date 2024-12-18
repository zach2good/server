/************************************************************************
 * Auction House Pagination
 *
 * This allows players to list and view more than the client-restricted 7
 * entries. This works by using multiple pages of 6 entries and pages
 * through them every time the player opens their AH listing page.
 ************************************************************************/

#include "map/utils/moduleutils.h"

#include "common/timer.h"
#include "map/packets/auction_house.h"
#include "map/packets/chat_message.h"
#include "map/zone.h"

extern uint8                                                                             PacketSize[512];
extern std::function<void(map_session_data_t* const, CCharEntity* const, CBasicPacket&)> PacketParser[512];

class AHPaginationModule : public CPPModule
{
    void OnInit() override
    {
        TracyZoneScoped;

        // If this is set to 7, the client won't let you put up more than 7 items. So, 6.
        auto ITEMS_PER_PAGE = 6U;
        auto TOTAL_PAGES    = 6;

        ShowInfo("[AH PAGES] Setting AH_LIST_LIMIT to %i.", ITEMS_PER_PAGE * TOTAL_PAGES);
        lua["xi"]["settings"]["search"]["AH_LIST_LIMIT"] = ITEMS_PER_PAGE * TOTAL_PAGES;

        auto originalHandler = PacketParser[0x04E];

        auto newHandler = [this, ITEMS_PER_PAGE, TOTAL_PAGES, originalHandler](map_session_data_t* const PSession, CCharEntity* const PChar, CBasicPacket& data) -> void
        {
            TracyZoneScoped;

            if (PChar->m_GMlevel == 0 && !PChar->loc.zone->CanUseMisc(MISC_AH))
            {
                ShowWarning("%s is trying to use the auction house in a disallowed zone [%s]", PChar->getName(), PChar->loc.zone->getName());
                return;
            }

            // Only intercept for action 0x05: Open List Of Sales / Wait
            auto action = data.ref<uint8>(0x04);
            if (action == 0x05)
            {
                uint32 curTick = gettick();
                if (curTick - PChar->m_AHHistoryTimestamp > 1500)
                {
                    // This will get wiped on zoning
                    auto currentAHPage = PChar->GetLocalVar("AH_PAGE");
                    PChar->SetLocalVar("AH_PAGE", (currentAHPage + 1) % TOTAL_PAGES);

                    PChar->m_ah_history.clear();
                    PChar->m_AHHistoryTimestamp = curTick;
                    PChar->pushPacket<CAuctionHousePacket>(action);

                    auto rset = db::preparedStmt("SELECT itemid, price, stack FROM auction_house WHERE seller = ? and sale = 0 ORDER BY id ASC LIMIT ? OFFSET ?", PChar->id, ITEMS_PER_PAGE, currentAHPage * ITEMS_PER_PAGE);
                    if (rset && rset->rowsCount() == 0)
                    {
                        PChar->pushPacket<CChatMessagePacket>(PChar, MESSAGE_SYSTEM_3, fmt::format("No results for page: {} of {}.", currentAHPage + 1, TOTAL_PAGES).c_str(), "");

                        // Reset to Page 1
                        auto rset1 = db::preparedStmt("SELECT itemid, price, stack FROM auction_house WHERE seller = ? and sale = 0 ORDER BY id ASC LIMIT ? OFFSET ?", PChar->id, ITEMS_PER_PAGE, 0);

                        // Show Page 1 this time
                        currentAHPage = 0;

                        // Prepare Page 2 for next load
                        PChar->SetLocalVar("AH_PAGE", currentAHPage + 1);
                    }

                    PChar->pushPacket<CChatMessagePacket>(PChar, MESSAGE_SYSTEM_3, fmt::format("Current page: {} of {}. Showing {} items.", currentAHPage + 1, TOTAL_PAGES, rset->rowsCount()).c_str(), "");

                    if (rset && rset->rowsCount())
                    {
                        while (rset->next())
                        {
                            PChar->m_ah_history.emplace_back(AuctionHistory_t{
                                .itemid = rset->get<uint16>("itemid"),
                                .stack  = rset->get<uint8>("stack"),
                                .price  = rset->get<uint32>("price"),
                                .status = 0,
                            });
                        }
                    }

                    auto totalItemsOnAh = PChar->m_ah_history.size();
                    for (size_t slot = 0; slot < totalItemsOnAh; slot++)
                    {
                        PChar->pushPacket<CAuctionHousePacket>(0x0C, (uint8)slot, PChar);
                    }
                }
                else
                {
                    PChar->pushPacket<CAuctionHousePacket>(action, 246, 0, 0, 0, 0); // try again in a little while msg
                }
            }
            else // Otherwise, call original handler
            {
                originalHandler(PSession, PChar, data);
            }
        };

        PacketParser[0x04E] = newHandler;
    }
};

REGISTER_CPP_MODULE(AHPaginationModule);
