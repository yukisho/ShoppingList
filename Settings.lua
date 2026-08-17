ShoppingListSettings = {}

local Settings = ShoppingListSettings

function Settings:Initialize(owner)
    local saved = owner.data:GetSettings()
    local panelName = "ShoppingListOptions"
    local buildVersion = owner:GetBuildVersion()
    local panel = {
        type = "panel",
        name = GetString(SI_SHOPPING_LIST_TITLE),
        displayName = GetString(SI_SHOPPING_LIST_TITLE),
        author = "Gravvy",
        version = buildVersion and string.format("Build %d", buildVersion) or nil,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LibAddonMenu2:RegisterAddonPanel(panelName, panel)
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = "checkbox",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_OPEN_WITH_STORE),
            getFunc = function() return saved.autoOpen end,
            setFunc = function(value) saved.autoOpen = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_CLOSE_WITH_STORE),
            getFunc = function() return saved.closeWithStore end,
            setFunc = function(value) saved.closeWithStore = value end,
            default = true,
        },
        {
            type = "dropdown",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_ITEM_FILTER),
            choices = {
                GetString(SI_SHOPPING_LIST_FILTER_ALL),
                GetString(SI_SHOPPING_LIST_FILTER_NEEDED),
                GetString(SI_SHOPPING_LIST_FILTER_COMPLETED),
                GetString(SI_SHOPPING_LIST_FILTER_OVER_TARGET),
                GetString(SI_SHOPPING_LIST_FILTER_RESTRICTED),
            },
            choicesValues = {
                "all",
                "needed",
                "completed",
                "overTarget",
                "restricted",
            },
            getFunc = function() return owner.data:GetItemFilter() end,
            setFunc = function(value)
                owner.data:SetItemFilter(value)
                owner.ui.offset = 0
                owner.ui:Refresh()
                owner.gamepad:Refresh()
            end,
            default = "all",
        },
        {
            type = "checkbox",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_ANNOUNCE_PURCHASES),
            getFunc = function() return saved.announcePurchases end,
            setFunc = function(value) saved.announcePurchases = value end,
            default = true,
        },
        {
            type = "dropdown",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_PANEL_SIDE),
            choices = {
                GetString(SI_SHOPPING_LIST_SETTINGS_LEFT),
                GetString(SI_SHOPPING_LIST_SETTINGS_RIGHT),
            },
            choicesValues = { "left", "right" },
            getFunc = function() return saved.panelSide end,
            setFunc = function(value)
                saved.panelSide = value
                owner.ui:PositionBesideStore()
            end,
            default = "right",
        },
        {
            type = "button",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_RESET_WINDOW),
            func = function()
                owner.ui:ResetGeometry()
            end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_CLEAR_COMPLETED),
            func = function()
                owner.data:ClearCompleted()
                owner.ui:Refresh()
                owner.gamepad:Refresh()
            end,
            width = "half",
        },
    })
end
