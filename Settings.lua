ShoppingListSettings = {}

local Settings = ShoppingListSettings

function Settings:Initialize(owner)
    local saved = owner.data:GetSettings()
    local panelName = "ShoppingListOptions"
    local panel = {
        type = "panel",
        name = GetString(SI_SHOPPING_LIST_TITLE),
        displayName = GetString(SI_SHOPPING_LIST_TITLE),
        author = "Gravvy",
        version = owner.version,
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
            type = "checkbox",
            name = GetString(SI_SHOPPING_LIST_SETTINGS_SHOW_COMPLETED),
            getFunc = function() return saved.showCompleted end,
            setFunc = function(value)
                saved.showCompleted = value
                owner.ui:Refresh()
            end,
            default = true,
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
            end,
            width = "half",
        },
    })
end
