ShoppingListContextMenu = {}

local ContextMenu = ShoppingListContextMenu

function ContextMenu:Initialize(owner)
    local menu = LibCustomMenu
    if not menu or not menu.RegisterContextMenu then
        return
    end

    menu:RegisterContextMenu(function(inventorySlot, slotActions)
        local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if bagId == nil or slotIndex == nil then
            return
        end

        local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
        if not itemLink or itemLink == "" then
            return
        end

        local listName = owner.data:GetCurrentList().name
        slotActions:AddCustomSlotAction(zo_strformat(
            GetString(SI_SHOPPING_LIST_CONTEXT_ADD_TO_LIST),
            listName
        ), function()
            local item, message = owner:AddItem("", 1, itemLink)
            if not item then
                owner.ui:SetStatus(message, true)
                return
            end
            owner.ui:SetStatus(zo_strformat(
                GetString(SI_SHOPPING_LIST_STATUS_ADDED_ITEM),
                item.name
            ))
            owner.editor:Open(item)
        end, "")
    end, menu.CATEGORY_PRIMARY)
end
