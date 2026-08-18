local ConfirmBox = require("ui/widget/confirmbox")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local PageCount = require("pagecount")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local PageCountCustomiser = WidgetContainer:extend{
    name = "pagecount",
    is_doc_only = true,
    chars_per_page_default = 1500,
    chars_per_page_min = 500,
    chars_per_page_max = 3000,
    desired_page_count_max = 10000,
}

function PageCountCustomiser:init()
    self.ui.menu:registerToMainMenu(self)
end

function PageCountCustomiser:getStablePageCount()
    local pagemap = self.ui.pagemap
    if not pagemap or not pagemap.has_pagemap then
        return nil
    end
    return select(3, pagemap:getCurrentPageLabel())
end

function PageCountCustomiser:applySyntheticPageMap(chars_per_page)
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

function PageCountCustomiser:getDefaultStablePageCount()
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

function PageCountCustomiser:usePublisherPageNumbers(spin)
    UIManager:show(ConfirmBox:new{
        text = _("Use publisher page numbers?\nThe document will be reloaded."),
        ok_callback = function()
            spin:onClose()
            self.ui.doc_settings:delSetting("pagemap_chars_per_synthetic_page")
            self.ui.document:invalidateCacheFile()
            local after_open_callback = function(ui)
                ui.annotation:setNeedsUpdateFlag()
            end
            self.ui:reloadDocument(nil, nil, after_open_callback)
        end,
    })
end

function PageCountCustomiser:setDesiredPageCount(target_pages, touchmenu_instance)
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

function PageCountCustomiser:showPageCountDialog(touchmenu_instance)
    local pagemap = self.ui.pagemap
    local current_pages = self:getStablePageCount() or self.ui.document:getPageCount() or 1
    local default_pages = self:getDefaultStablePageCount()
    UIManager:show(SpinWidget:new{
        title_text = _("Desired stable page count"),
        info_text = _("KOReader will calculate the characters per page and use its native stable page numbers."),
        value = current_pages,
        value_min = 1,
        value_max = self.desired_page_count_max,
        value_step = 1,
        value_hold_step = 10,
        default_value = default_pages,
        ok_text = _("Set page count"),
        ok_always_enabled = true,
        keep_shown_on_apply = true,
        callback = function(spin)
            spin:onClose()
            self:setDesiredPageCount(spin.value, touchmenu_instance)
        end,
        extra_text = pagemap.has_pagemap_document_provided and pagemap.chars_per_synthetic_page
            and _("Use publisher page numbers"),
        extra_callback = function(spin)
            self:usePublisherPageNumbers(spin)
        end,
    })
end

function PageCountCustomiser:addToMainMenu(menu_items)
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

return PageCountCustomiser
