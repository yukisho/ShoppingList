local ADDON_NAME = "ShoppingList"

local function onLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(
        "GravvyShoppingList_LegacyRecovery",
        EVENT_ADD_ON_LOADED
    )

    local saved = ZO_SavedVars:NewAccountWide(
        "ShoppingList_Data",
        1,
        nil,
        {},
        GetWorldName()
    )
    GravvyShoppingListLegacySavedVariables = {
        saved = saved,
        source = ADDON_NAME,
        world = GetWorldName(),
    }
end

EVENT_MANAGER:RegisterForEvent(
    "GravvyShoppingList_LegacyRecovery",
    EVENT_ADD_ON_LOADED,
    onLoaded
)
