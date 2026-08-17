ShoppingList = {
    name = "ShoppingList",
    version = "0.15.0",
}

local addon = ShoppingList

local function formatGold(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(value)
    end
    return tostring(value)
end

function addon:Initialize()
    self.data = ShoppingListData:New()
    self.matcher = ShoppingListMatcher
    self.ui = ShoppingListUI:New(self)
    self.ui:Initialize()
    self.gamepad = ShoppingListGamepad:New(self)
    self.gamepad:Initialize()
    self.history = ShoppingListHistory:New(self)
    self.history:Initialize()
    self.archive = ShoppingListArchive:New(self)
    self.archive:Initialize()
    self.share = ShoppingListShare:New(self)
    self.share:Initialize()
    self.editor = ShoppingListEditor:New(self)
    self.editor:Initialize()
    self.help = ShoppingListHelp:New(self)
    self.help:Initialize()

    self.ags = ShoppingListAGSAdapter:New(self)
    local hasAGS = self.ags:Initialize()

    self.purchaseTracker = ShoppingListPurchaseTracker:New(self)
    self.purchaseTracker:Initialize(hasAGS)

    ShoppingListSettings:Initialize(self)
    ShoppingListContextMenu:Initialize(self)
    ShoppingListMainMenu:Initialize(self)
    self:RegisterEvents()
    self:RegisterCommands()
end

function addon:RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(
        "ShoppingList_OpenStore",
        EVENT_OPEN_TRADING_HOUSE,
        function()
            self.storeOpen = true
            zo_callLater(function()
                if self.data:GetSettings().autoOpen then
                    if IsInGamepadPreferredMode() then
                        self.gamepad:ShowForStore()
                    else
                        self.ui:ShowForStore()
                    end
                else
                    self.ui:Refresh()
                    self.gamepad:Refresh()
                end
            end, 100)
        end
    )
    EVENT_MANAGER:RegisterForEvent(
        "ShoppingList_CloseStore",
        EVENT_CLOSE_TRADING_HOUSE,
        function()
            self.storeOpen = false
            self.ui:HideForStore()
            self.gamepad:HideForStore()
            self.ui:Refresh()
            self.gamepad:Refresh()
        end
    )
end

function addon:RegisterCommands()
    SLASH_COMMANDS["/shoppinglist"] = function() self:ToggleWindow() end
    SLASH_COMMANDS["/shoppinglisthelp"] = function()
        if IsInGamepadPreferredMode() then
            self.gamepad:ShowHelpDialog()
        else
            self.help:Open()
        end
    end
end

function addon:ToggleWindow()
    if IsInGamepadPreferredMode() then
        self.ui:Hide()
        self.gamepad:Toggle()
    else
        self.gamepad:Hide()
        self.ui:Toggle(true)
    end
end

function addon:AddItem(name, quantity, itemLink, nameHash)
    local item, message = self.data:AddItem(name, quantity, itemLink, nameHash)
    if item then
        self.ui:Refresh()
        self.gamepad:Refresh()
    end
    return item, message
end

function addon:RemoveItem(id)
    if self.data:RemoveItem(id) then
        self.ui:Refresh()
        self.gamepad:Refresh()
    end
end

function addon:ToggleItem(id)
    if self.data:ToggleItem(id) then
        self.ui:Refresh()
        self.gamepad:Refresh()
    end
end

function addon:MoveItem(id, direction)
    if not self.data:MoveItem(id, direction) then
        return false
    end
    self.ui:Refresh()
    self.gamepad:Refresh()
    return true
end

function addon:RecordPurchase(itemLink, itemName, quantity, purchase)
    purchase = purchase or {}
    purchase.itemLink = purchase.itemLink or itemLink
    purchase.itemName = purchase.itemName or itemName
    local list = self.data:GetCurrentList()
    local spendingBefore = tonumber(list.totalSpent) or 0
    local changes = self.matcher:ApplyPurchase(
        self.data:GetItems(),
        itemLink,
        itemName,
        quantity
    )
    if #changes == 0 then
        return
    end

    for _, change in ipairs(changes) do
        self.data:RecordPurchase(change.entry, change.quantity, purchase)
    end
    if list.budget
        and spendingBefore <= list.budget
        and list.totalSpent > list.budget
    then
        d(zo_strformat(
            GetString(SI_SHOPPING_LIST_CHAT_OVER_BUDGET),
            list.name,
            formatGold(list.totalSpent - list.budget)
        ))
    end
    self.ui:Refresh()
    self.gamepad:Refresh()
    if self.data:GetSettings().announcePurchases then
        for _, change in ipairs(changes) do
            local entry = change.entry
            d(zo_strformat(
                GetString(SI_SHOPPING_LIST_CHAT_PURCHASE_PROGRESS),
                entry.name,
                entry.purchased,
                entry.desired
            ))
        end
    end
end

local function onAddOnLoaded(_, name)
    if name ~= addon.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("ShoppingList_Loaded", EVENT_ADD_ON_LOADED)
    addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent("ShoppingList_Loaded", EVENT_ADD_ON_LOADED, onAddOnLoaded)
