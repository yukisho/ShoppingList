local Gamepad = ShoppingListGamepad

local MANAGE_DIALOG = "SHOPPING_LIST_GAMEPAD_MANAGE"
local EDIT_DIALOG = "SHOPPING_LIST_GAMEPAD_EDIT_ITEM"
local ARCHIVES_DIALOG = "SHOPPING_LIST_GAMEPAD_ARCHIVES"
local SHARE_DIALOG = "SHOPPING_LIST_GAMEPAD_SHARE"
local IMPORT_DIALOG = "SHOPPING_LIST_GAMEPAD_IMPORT"
local HELP_DIALOG = "SHOPPING_LIST_GAMEPAD_HELP"
local RELEASE_NOTES_DIALOG = "SHOPPING_LIST_GAMEPAD_RELEASE_NOTES"

local function showError(message)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, message)
end

local function formatGold(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if ZO_CommaDelimitNumber then
        return zo_strformat(
            GetString(SI_SHOPPING_LIST_GOLD_SHORT),
            ZO_CommaDelimitNumber(value)
        )
    end
    return zo_strformat(GetString(SI_SHOPPING_LIST_GOLD_SHORT), value)
end

local function releaseAndOpen(dialogName, callback)
    ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
    zo_callLater(callback, 10)
end

local function actionEntry(text, callback, visible)
    local data = {
        setup = ZO_SharedGamepadEntry_OnSetup,
        callback = callback,
    }
    if visible then
        data.visible = visible
    end
    return {
        template = "ZO_GamepadMenuEntryTemplate",
        text = text,
        templateData = data,
    }
end

local function setupTextField(control, data, selected, options)
    local edit = control.editBoxControl
    control.highlight:SetHidden(not selected)
    edit:SetDefaultText(options.defaultText or "")
    edit:SetMaxInputChars(options.maxChars)
    edit:SetNewLineEnabled(options.multiline == true)
    edit:SetSelectAllOnFocus(true)
    edit:SetTextType(options.numeric and TEXT_TYPE_NUMERIC or TEXT_TYPE_ALL)
    edit:SetText(options.value() or "")
    edit.textChangedCallback = function(editBox)
        options.changed(editBox:GetText())
    end
    data.control = control
end

local function focusTextField(dialog)
    local data = dialog.entryList:GetTargetData()
    if data and data.control then
        data.control.editBoxControl:TakeFocus()
    end
end

local function textFieldEntry(header, options)
    return {
        template = options.multiline
            and "ZO_Gamepad_GenericDialog_TextFieldItem_Multiline_Large"
            or "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
        header = header,
        templateData = {
            setup = function(control, data, selected)
                setupTextField(control, data, selected, options)
            end,
            callback = focusTextField,
            narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
        },
    }
end

local function dropdownEntry(header, choices, value, changed)
    local label = GetString(header)
    return {
        template = "ZO_GamepadDropdownItem",
        header = header,
        text = label,
        templateData = {
            setup = function(control, data, selected)
                local dropdown = control.dropdown
                dropdown:SetName(label)
                dropdown:SetSortsItems(false)
                dropdown:SetSelectedItemTextColor(selected)
                dropdown:ClearItems()

                local firstEntry
                local selectedEntry
                local selectedValue = value()
                for _, choice in ipairs(choices) do
                    local choiceValue = choice.value
                    local entry = dropdown:CreateItemEntry(choice.label, function()
                        changed(choiceValue)
                    end)
                    dropdown:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
                    firstEntry = firstEntry or entry
                    if choiceValue == selectedValue then
                        selectedEntry = entry
                    end
                end

                dropdown:UpdateItems()
                dropdown:SelectItem(selectedEntry or firstEntry, true)
                SCREEN_NARRATION_MANAGER:RegisterDialogDropdown(data.dialog, dropdown)
            end,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control then
                    control.dropdown:Activate()
                end
            end,
            narrationText = function(_, control)
                return control.dropdown:GetNarrationText()
            end,
        },
    }
end

local function selectDialogEntry(dialog)
    local data = dialog.entryList:GetTargetData()
    if data and data.callback then
        data.callback(dialog)
    end
end

local function cancelDialog(dialogName)
    return function()
        ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
    end
end

function Gamepad:InitializeManagementDialogs()
    self:InitializeManageDialog()
    self:InitializeEditDialog()
    self:InitializeArchivesDialog()
    self:InitializeShareDialog()
    self:InitializeImportDialog()
    self:InitializeHelpDialogs()
end

function Gamepad:InitializeManageDialog()
    ZO_Dialogs_RegisterCustomDialog(MANAGE_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = SI_SHOPPING_LIST_GAMEPAD_MANAGE_TITLE,
        },
        mainText = {
            text = SI_SHOPPING_LIST_GAMEPAD_MANAGE_HELP,
        },
        parametricList = {
            actionEntry(
                SI_SHOPPING_LIST_GAMEPAD_EDIT_MATCHING,
                function() self:OpenEditDialogFromManagement() end,
                function() return self:GetTargetItem() ~= nil end
            ),
            actionEntry(
                SI_SHOPPING_LIST_GAMEPAD_ARCHIVE_CURRENT,
                function() self:ArchiveCurrentListFromManagement() end
            ),
            actionEntry(
                function()
                    return zo_strformat(
                        GetString(SI_SHOPPING_LIST_ARCHIVED_COUNT),
                        #self.owner.data:GetArchivedLists()
                    )
                end,
                function() self:OpenArchivesFromManagement() end
            ),
            actionEntry(
                SI_SHOPPING_LIST_GAMEPAD_SHARE_CURRENT,
                function() self:OpenShareFromManagement() end
            ),
            actionEntry(
                SI_SHOPPING_LIST_GAMEPAD_IMPORT_LIST,
                function() self:OpenImportFromManagement() end
            ),
            actionEntry(
                SI_SHOPPING_LIST_GAMEPAD_HELP,
                function() self:OpenHelpFromManagement() end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(MANAGE_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeEditDialog()
    local qualityModes = {
        { label = GetString(SI_SHOPPING_LIST_CHOICE_ANY), value = "any" },
        { label = GetString(SI_SHOPPING_LIST_CHOICE_AT_LEAST), value = "minimum" },
        { label = GetString(SI_SHOPPING_LIST_CHOICE_EXACTLY), value = "exact" },
    }
    local levelModes = {
        { label = GetString(SI_SHOPPING_LIST_CHOICE_ANY), value = "any" },
        { label = GetString(SI_SHOPPING_LIST_CHOICE_EXACTLY), value = "exact" },
    }

    ZO_Dialogs_RegisterCustomDialog(EDIT_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            local item = self.owner.data:FindItem(dialog.data.itemId)
            if not item then
                showError(GetString(SI_SHOPPING_LIST_ERROR_ITEM_MISSING))
                ZO_Dialogs_ReleaseDialogOnButtonPress(EDIT_DIALOG)
                return
            end

            local rule = item.match or {}
            self.editingItemId = item.id
            self.pendingEdit = {
                desired = tostring(item.desired),
                setName = rule.setName or "",
                traitType = rule.traitType or ITEM_TRAIT_TYPE_NONE,
                qualityMode = rule.qualityMode or "any",
                quality = rule.quality or ITEM_QUALITY_NORMAL,
                levelMode = rule.levelMode or "any",
                level = tostring(rule.level or 1),
                championPoints = tostring(rule.championPoints or 0),
                maxUnitPrice = item.maxUnitPrice and tostring(item.maxUnitPrice) or "",
            }
            dialog:setupFunc()
        end,
        title = {
            text = SI_SHOPPING_LIST_EDITOR_TITLE,
        },
        mainText = {
            text = function(dialog)
                local item = self.owner.data:FindItem(dialog.data.itemId)
                return item and item.name or ""
            end,
        },
        parametricList = {
            textFieldEntry(SI_SHOPPING_LIST_EDITOR_QUANTITY, {
                value = function() return self.pendingEdit.desired end,
                changed = function(value) self.pendingEdit.desired = value end,
                defaultText = GetString(SI_SHOPPING_LIST_EDITOR_QUANTITY),
                maxChars = 6,
                numeric = true,
            }),
            textFieldEntry(SI_SHOPPING_LIST_EDITOR_SET, {
                value = function() return self.pendingEdit.setName end,
                changed = function(value) self.pendingEdit.setName = value end,
                defaultText = GetString(SI_SHOPPING_LIST_EDITOR_ANY_SET),
                maxChars = 100,
            }),
            dropdownEntry(
                SI_SHOPPING_LIST_EDITOR_TRAIT,
                ShoppingListEditor.GetTraitChoices(),
                function() return self.pendingEdit.traitType end,
                function(value) self.pendingEdit.traitType = value end
            ),
            dropdownEntry(
                SI_SHOPPING_LIST_EDITOR_QUALITY_RULE,
                qualityModes,
                function() return self.pendingEdit.qualityMode end,
                function(value) self.pendingEdit.qualityMode = value end
            ),
            dropdownEntry(
                SI_SHOPPING_LIST_GAMEPAD_QUALITY,
                ShoppingListEditor.GetQualityChoices(),
                function() return self.pendingEdit.quality end,
                function(value) self.pendingEdit.quality = value end
            ),
            dropdownEntry(
                SI_SHOPPING_LIST_EDITOR_LEVEL_RULE,
                levelModes,
                function() return self.pendingEdit.levelMode end,
                function(value) self.pendingEdit.levelMode = value end
            ),
            textFieldEntry(SI_SHOPPING_LIST_EDITOR_LEVEL, {
                value = function() return self.pendingEdit.level end,
                changed = function(value) self.pendingEdit.level = value end,
                defaultText = GetString(SI_SHOPPING_LIST_EDITOR_LEVEL),
                maxChars = 4,
                numeric = true,
            }),
            textFieldEntry(SI_SHOPPING_LIST_EDITOR_CHAMPION_POINTS, {
                value = function() return self.pendingEdit.championPoints end,
                changed = function(value) self.pendingEdit.championPoints = value end,
                defaultText = GetString(SI_SHOPPING_LIST_EDITOR_CHAMPION_POINTS),
                maxChars = 4,
                numeric = true,
            }),
            textFieldEntry(SI_SHOPPING_LIST_EDITOR_MAX_UNIT_PRICE, {
                value = function() return self.pendingEdit.maxUnitPrice end,
                changed = function(value) self.pendingEdit.maxUnitPrice = value end,
                defaultText = GetString(SI_SHOPPING_LIST_EDITOR_GOLD_NONE),
                maxChars = 10,
                numeric = true,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_SHOPPING_LIST_BUTTON_SAVE,
                callback = function() self:SaveGamepadItemEdit() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(EDIT_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeArchivesDialog()
    ZO_Dialogs_RegisterCustomDialog(ARCHIVES_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            dialog.info.parametricList = self:BuildArchivedListEntries()
            dialog:setupFunc()
        end,
        title = {
            text = SI_SHOPPING_LIST_ARCHIVE_TITLE,
        },
        mainText = {
            text = function()
                local count = #self.owner.data:GetArchivedLists()
                return zo_strformat(
                    GetString(SI_SHOPPING_LIST_ARCHIVE_SUMMARY),
                    count,
                    GetString(count == 1
                        and SI_SHOPPING_LIST_NOUN_ARCHIVED_LIST
                        or SI_SHOPPING_LIST_NOUN_ARCHIVED_LISTS)
                )
            end,
        },
        parametricList = {},
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_SHOPPING_LIST_BUTTON_RESTORE,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = cancelDialog(ARCHIVES_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeShareDialog()
    local options = {
        value = function() return self.gamepadShareCode end,
        changed = function(value) self.gamepadShareCode = value end,
        defaultText = GetString(SI_SHOPPING_LIST_SHARE_CURRENT_CODE),
        maxChars = ShoppingListShare.MAX_CODE_LENGTH,
        multiline = true,
    }
    ZO_Dialogs_RegisterCustomDialog(SHARE_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            self.gamepadShareCode = dialog.data.code
            dialog:setupFunc()
        end,
        title = {
            text = SI_SHOPPING_LIST_SHARE_TITLE,
        },
        mainText = {
            text = SI_SHOPPING_LIST_GAMEPAD_SHARE_HELP,
        },
        parametricList = {
            textFieldEntry(SI_SHOPPING_LIST_SHARE_CURRENT_CODE, options),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_SHOPPING_LIST_SHARE_SELECT_CODE,
                callback = function(dialog) self:SelectGamepadShareCode(dialog) end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_SHOPPING_LIST_SHARE_IMPORT_CODE,
                callback = function() self:OpenImportFromShare() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = cancelDialog(SHARE_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeImportDialog()
    local options = {
        value = function() return self.gamepadImportCode end,
        changed = function(value) self.gamepadImportCode = value end,
        defaultText = GetString(SI_SHOPPING_LIST_IMPORT_PLACEHOLDER),
        maxChars = ShoppingListShare.MAX_CODE_LENGTH,
        multiline = true,
    }
    ZO_Dialogs_RegisterCustomDialog(IMPORT_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            self.gamepadImportCode = ""
            dialog:setupFunc()
        end,
        title = {
            text = SI_SHOPPING_LIST_IMPORT_TITLE,
        },
        mainText = {
            text = SI_SHOPPING_LIST_GAMEPAD_IMPORT_HELP,
        },
        parametricList = {
            textFieldEntry(SI_SHOPPING_LIST_SHARE_IMPORT_CODE, options),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_SHOPPING_LIST_SHARE_IMPORT_CODE,
                callback = function() self:ImportGamepadCode() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(IMPORT_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeHelpDialogs()
    ZO_Dialogs_RegisterCustomDialog(HELP_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = SI_SHOPPING_LIST_HELP_TITLE,
        },
        mainText = {
            text = SI_SHOPPING_LIST_HELP_CONTENT,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_SHOPPING_LIST_HELP_RELEASE_NOTES,
                callback = function() self:OpenGamepadReleaseNotes() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = cancelDialog(HELP_DIALOG),
            },
        },
    })

    ZO_Dialogs_RegisterCustomDialog(RELEASE_NOTES_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = SI_SHOPPING_LIST_HELP_RELEASE_NOTES,
        },
        mainText = {
            text = SI_SHOPPING_LIST_RELEASE_NOTES_CONTENT,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_SHOPPING_LIST_HELP_GETTING_STARTED,
                callback = function() self:OpenGamepadHelp() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = cancelDialog(RELEASE_NOTES_DIALOG),
            },
        },
    })
end

function Gamepad:ShowManagementDialog()
    ZO_Dialogs_ShowGamepadDialog(MANAGE_DIALOG)
end

function Gamepad:OpenEditDialogFromManagement()
    local item = self:GetTargetItem()
    if not item then
        showError(GetString(SI_SHOPPING_LIST_ERROR_ITEM_MISSING))
        return
    end
    local itemId = item.id
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(EDIT_DIALOG, { itemId = itemId })
    end)
end

function Gamepad:SaveGamepadItemEdit()
    local item = self.owner.data:FindItem(self.editingItemId)
    if not item then
        showError(GetString(SI_SHOPPING_LIST_ERROR_ITEM_MISSING))
        return
    end

    local ok, message = self.owner.data:UpdateItem(item.id, self.pendingEdit)
    if not ok then
        showError(message)
        return
    end

    ZO_Dialogs_ReleaseDialogOnButtonPress(EDIT_DIALOG)
    self.owner.ui:Refresh()
    self:Refresh(true)
    local status = zo_strformat(GetString(SI_SHOPPING_LIST_STATUS_ITEM_UPDATED), item.name)
    self:SetStatus(status)
    self.owner.ui:SetStatus(status)
end

function Gamepad:ArchiveCurrentListFromManagement()
    local ok, listOrMessage = self.owner.data:ArchiveList(
        self.owner.data:GetCurrentList().id
    )
    if not ok then
        showError(listOrMessage)
        return
    end

    ZO_Dialogs_ReleaseDialogOnButtonPress(MANAGE_DIALOG)
    self.owner.ui.listSignature = nil
    self.owner.ui:Refresh()
    self:Refresh(true)
    local status = zo_strformat(
        GetString(SI_SHOPPING_LIST_STATUS_LIST_ARCHIVED),
        listOrMessage.name
    )
    self:SetStatus(status)
    self.owner.ui:SetStatus(status)
end

function Gamepad:OpenArchivesFromManagement()
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(ARCHIVES_DIALOG)
    end)
end

function Gamepad:BuildArchivedListEntries()
    local entries = {}
    local lists = self.owner.data:GetArchivedLists()
    for index = #lists, 1, -1 do
        local list = lists[index]
        local listId = list.id
        local entry = ZO_GamepadEntryData:New(list.name)
        entry.setup = ZO_SharedGamepadEntry_OnSetup
        entry.callback = function() self:RestoreArchivedList(listId) end
        entry:AddSubLabel(zo_strformat(
            GetString(SI_SHOPPING_LIST_GAMEPAD_ARCHIVE_DETAILS),
            #list.items,
            formatGold(list.totalSpent)
        ))
        entries[#entries + 1] = {
            template = "ZO_GamepadMenuEntryTemplate",
            entryData = entry,
        }
    end

    if #entries == 0 then
        local empty = actionEntry(GetString(SI_SHOPPING_LIST_ARCHIVE_EMPTY), function() end)
        empty.templateData.enabled = false
        entries[1] = empty
    end
    return entries
end

function Gamepad:RestoreArchivedList(listId)
    local ok, listOrMessage = self.owner.data:RestoreList(listId)
    if not ok then
        showError(listOrMessage)
        return
    end

    ZO_Dialogs_ReleaseDialogOnButtonPress(ARCHIVES_DIALOG)
    self.owner.ui.listSignature = nil
    self.owner.ui:Refresh()
    self:Refresh(true)
    local status = zo_strformat(
        GetString(SI_SHOPPING_LIST_STATUS_LIST_RESTORED),
        listOrMessage.name
    )
    self:SetStatus(status)
    self.owner.ui:SetStatus(status)
end

function Gamepad:OpenShareFromManagement()
    local code, message = ShoppingListShare.EncodeList(
        self.owner.data:GetCurrentList()
    )
    if not code then
        showError(message)
        return
    end
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(SHARE_DIALOG, { code = code })
    end)
end

function Gamepad:SelectGamepadShareCode(dialog)
    local data = dialog.entryList:GetTargetData()
    if not data or not data.control then
        return
    end
    local edit = data.control.editBoxControl
    edit:TakeFocus()
    if edit.SelectAll then
        edit:SelectAll()
    end
end

function Gamepad:OpenImportFromManagement()
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(IMPORT_DIALOG)
    end)
end

function Gamepad:OpenImportFromShare()
    releaseAndOpen(SHARE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(IMPORT_DIALOG)
    end)
end

function Gamepad:ImportGamepadCode()
    local decoded, message = ShoppingListShare.DecodeCode(self.gamepadImportCode)
    if not decoded then
        showError(message)
        return
    end

    local list, importMessage = self.owner.data:ImportList(decoded.name, decoded.items)
    if not list then
        showError(importMessage)
        return
    end

    ZO_Dialogs_ReleaseDialogOnButtonPress(IMPORT_DIALOG)
    self.owner.ui.listSignature = nil
    self.owner.ui:Refresh()
    self:Refresh(true)
    local status = zo_strformat(
        GetString(SI_SHOPPING_LIST_STATUS_LIST_IMPORTED),
        list.name,
        #list.items,
        GetString(#list.items == 1
            and SI_SHOPPING_LIST_NOUN_ITEM
            or SI_SHOPPING_LIST_NOUN_ITEMS)
    )
    self:SetStatus(status)
    self.owner.ui:SetStatus(status)
end

function Gamepad:OpenHelpFromManagement()
    releaseAndOpen(MANAGE_DIALOG, function()
        self:ShowHelpDialog()
    end)
end

function Gamepad:ShowHelpDialog()
    ZO_Dialogs_ShowGamepadDialog(HELP_DIALOG)
end

function Gamepad:OpenGamepadReleaseNotes()
    releaseAndOpen(HELP_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(RELEASE_NOTES_DIALOG)
    end)
end

function Gamepad:OpenGamepadHelp()
    releaseAndOpen(RELEASE_NOTES_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(HELP_DIALOG)
    end)
end
