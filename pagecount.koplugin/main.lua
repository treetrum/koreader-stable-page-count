local ConfirmBox = require("ui/widget/confirmbox")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local PageCount = require("pagecount")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local StablePageCount = WidgetContainer:extend{
    name = "pagecount",
    is_doc_only = true,
    chars_per_page_default = 1500,
    chars_per_page_min = 500,
    chars_per_page_max = 3000,
    desired_page_count_max = 10000,
}

function StablePageCount:init()
    self.ui.menu:registerToMainMenu(self)
end

function StablePageCount:getStablePageCount()
    local pagemap = self.ui.pagemap
    if not pagemap or not pagemap.has_pagemap then
        return nil
    end
    return select(3, pagemap:getCurrentPageLabel())
end

function StablePageCount:applySyntheticPageMap(chars_per_page)
    local pagemap = self.ui.pagemap
    if not pagemap.has_pagemap then
        pagemap.has_pagemap = true
        pagemap:resetLayout()
        pagemap.view:registerViewModule("pagemap", pagemap)
    end

    pagemap.chars_per_synthetic_page = chars_per_page
    pagemap.page_labels_cache = nil
    self.ui.document:buildSyntheticPageMap(chars_per_page)
    pagemap:updateVisibleLabels()
    self.ui.doc_settings:saveSetting("pagemap_chars_per_synthetic_page", chars_per_page)
    self.ui.doc_settings:saveSetting("pagemap_doc_pages", self:getStablePageCount())
    UIManager:broadcastEvent(Event:new("UsePageLabelsUpdated"))
    UIManager:setDirty(pagemap.view.dialog, "partial")
end

function StablePageCount:getDefaultStablePageCount()
    if self.default_page_count then
        return self.default_page_count
    end

    local pagemap = self.ui.pagemap
    local current_chars_per_page = pagemap.chars_per_synthetic_page
    if not current_chars_per_page then
        return nil
    end

    if current_chars_per_page == self.chars_per_page_default then
        self.default_page_count = self:getStablePageCount()
        return self.default_page_count
    end

    self.ui.document:buildSyntheticPageMap(self.chars_per_page_default)
    self.default_page_count = select(3, pagemap:getCurrentPageLabel())
    self.ui.document:buildSyntheticPageMap(current_chars_per_page)
    return self.default_page_count
end

function StablePageCount:usePublisherPageNumbers(dialog)
    UIManager:show(ConfirmBox:new{
        text = _("Use publisher page numbers?\nThe document will be reloaded."),
        ok_callback = function()
            UIManager:close(dialog)
            self.ui.doc_settings:delSetting("pagemap_chars_per_synthetic_page")
            self.ui.document:invalidateCacheFile()
            local after_open_callback = function(ui)
                ui.annotation:setNeedsUpdateFlag()
            end
            self.ui:reloadDocument(nil, nil, after_open_callback)
        end,
    })
end

function StablePageCount:setDesiredPageCount(target_pages, touchmenu_instance)
    local pagemap = self.ui.pagemap
    local function getPageCount(chars_per_page)
        self.ui.document:buildSyntheticPageMap(chars_per_page)
        return select(3, pagemap:getCurrentPageLabel())
    end

    local chars_per_page, actual_pages = PageCount.findBestCharsPerPage(
        target_pages,
        self.chars_per_page_min,
        self.chars_per_page_max,
        getPageCount
    )

    self:applySyntheticPageMap(chars_per_page)
    touchmenu_instance:updateItems()

    local message
    if actual_pages == target_pages then
        message = T(_("Stable page count set to %1 using %2 characters per page."), actual_pages, chars_per_page)
    else
        message = T(_("The closest available count is %1 pages using %2 characters per page (requested %3)."),
            actual_pages, chars_per_page, target_pages)
    end
    UIManager:show(InfoMessage:new{ text = message })
end

function StablePageCount:showPageCountDialog(touchmenu_instance)
    local pagemap = self.ui.pagemap
    local current_pages = self:getStablePageCount() or self.ui.document:getPageCount() or 1
    local default_pages = self:getDefaultStablePageCount()
    local input_dialog
    local action_buttons = {}

    if default_pages then
        table.insert(action_buttons, {
            text = T(_("Default: %1"), default_pages),
            callback = function()
                input_dialog:setInputText(tostring(default_pages), true, false)
            end,
        })
    end
    if pagemap.has_pagemap_document_provided and pagemap.chars_per_synthetic_page then
        table.insert(action_buttons, {
            text = _("Use publisher page numbers"),
            callback = function()
                input_dialog:onCloseKeyboard()
                self:usePublisherPageNumbers(input_dialog)
            end,
        })
    end

    local buttons = {}
    if #action_buttons > 0 then
        table.insert(buttons, action_buttons)
    end
    table.insert(buttons, {
        {
            text = _("Cancel"),
            id = "close",
            callback = function()
                UIManager:close(input_dialog)
            end,
        },
        {
            text = _("Set page count"),
            is_enter_default = true,
            callback = function()
                local target_pages = input_dialog:getInputValue()
                if not target_pages or target_pages < 1 or target_pages > self.desired_page_count_max
                        or target_pages % 1 ~= 0 then
                    UIManager:show(InfoMessage:new{
                        text = T(_("Enter a whole number from %1 to %2."), 1, self.desired_page_count_max),
                        timeout = 2,
                    })
                    return
                end
                UIManager:close(input_dialog)
                self:setDesiredPageCount(target_pages, touchmenu_instance)
            end,
        },
    })

    input_dialog = InputDialog:new{
        title = _("Desired stable page count"),
        input = "",
        input_hint = T(_("Current: %1 (1 - %2)"), current_pages, self.desired_page_count_max),
        input_type = "number",
        buttons = buttons,
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function StablePageCount:addToMainMenu(menu_items)
    local page_map_item = menu_items.page_map
    if not self.ui.pagemap or not page_map_item or not page_map_item.sub_item_table then
        return
    end

    -- ReaderPageMap keeps its characters-per-page control in this slot.
    page_map_item.sub_item_table[2] = {
        text_func = function()
            local count = self:getStablePageCount()
            return count and T(_("Desired page count: %1"), count) or _("Desired page count: disabled")
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            self:showPageCountDialog(touchmenu_instance)
        end,
    }
end

return StablePageCount
