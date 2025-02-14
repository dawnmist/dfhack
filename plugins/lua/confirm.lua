local _ENV = mkmodule('plugins.confirm')

local confs = {}
-- Wraps df.interface_key[foo] functionality but fails with invalid keys
keys = {}
setmetatable(keys, {
    __index = function(self, k)
        return df.interface_key[k] or error('Invalid key: ' .. tostring(k))
    end,
    __newindex = function() error('Table is read-only') end
})
-- Mouse keys will be sent as a string instead of interface_key
local MOUSE_LEFT = "MOUSE_LEFT"
local MOUSE_RIGHT = "MOUSE_RIGHT"
--[[ The screen where a confirmation has been triggered
Note that this is *not* necessarily the topmost viewscreen, so do not use
gui.getCurViewscreen() or related functions. ]]
screen = nil

function if_nil(obj, default)
    if obj == nil then
        return default
    else
        return obj
    end
end

function defconf(id)
    if not get_ids()[id] then
        error('Bad confirmation ID (not defined in plugin): ' .. id)
    end
    local cls = {}
    cls.intercept_key = function(key) return false end
    cls.get_title = function() return if_nil(cls.title, '<No title>') end
    cls.get_message = function() return if_nil(cls.message, '<No message>') end
    cls.get_color = function() return if_nil(cls.color, COLOR_YELLOW) end
    confs[id] = cls
    return cls
end

--[[ Beginning of confirmation definitions
All confirmations declared in confirm.cpp must have a corresponding call to
defconf() here, and should implement intercept_key(), get_title(), and
get_message(). get_color() can also be implemented here, but the default should
be sufficient.

In cases where getter functions always return the same value (e.g. get_title()),
they can be replaced with a field named after the method without the "get_"
prefix:

    trade.title = "Confirm trade"

is equivalent to:

    function trade.get_title() return "Confirm trade" end

]]

trade_cancel = defconf('trade-cancel')
function trade_cancel.intercept_key(key)
    return dfhack.gui.matchFocusString("dwarfmode/Trade") and
    (key == keys.LEAVESCREEN or key == MOUSE_RIGHT) and
    (trader_goods_selected() or broker_goods_selected())
end
trade_cancel.title = "Cancel trade"
trade_cancel.message = "Are you sure you want leave this screen?\nSelected items will not be saved."

haul_delete_route = defconf('haul-delete-route')
function haul_delete_route.intercept_key(key)
    return df.global.game.main_interface.current_hover == 180 and key == MOUSE_LEFT
end
haul_delete_route.title = "Confirm deletion"
haul_delete_route.message = "Are you sure you want to delete this route?"

haul_delete_stop = defconf('haul-delete-stop')
function haul_delete_stop.intercept_key(key)
    return df.global.game.main_interface.current_hover == 185 and key == MOUSE_LEFT
end
haul_delete_stop.title = "Confirm deletion"
haul_delete_stop.message = "Are you sure you want to delete this stop?"

depot_remove = defconf('depot-remove')
function depot_remove.intercept_key(key)
    if df.global.game.main_interface.current_hover == 299 and
            key == MOUSE_LEFT and
            df.building_tradedepotst:is_instance(dfhack.gui.getSelectedBuilding(true)) then
        for _, caravan in pairs(df.global.plotinfo.caravans) do
            if caravan.time_remaining > 0 then
                return true
            end
        end
    end
end
depot_remove.title = "Confirm depot removal"
depot_remove.message = "Are you sure you want to remove this depot?\n" ..
    "Merchants are present and will lose profits."

squad_disband = defconf('squad-disband')
function squad_disband.intercept_key(key)
    return key == MOUSE_LEFT and df.global.game.main_interface.current_hover == 341
end
squad_disband.title = "Disband squad"
squad_disband.message = "Are you sure you want to disband this squad?"

order_remove = defconf('order-remove')
function order_remove.intercept_key(key)
    return key == MOUSE_LEFT and df.global.game.main_interface.current_hover == 222
end
order_remove.title = "Remove manager order"
order_remove.message = "Are you sure you want to remove this order?"

zone_remove = defconf('zone-remove')
function zone_remove.intercept_key(key)
    return key == MOUSE_LEFT and df.global.game.main_interface.current_hover == 130
end
zone_remove.title = "Remove zone"
zone_remove.message = "Are you sure you want to remove this zone?"

burrow_remove = defconf('burrow-remove')
function burrow_remove.intercept_key(key)
    return key == MOUSE_LEFT and df.global.game.main_interface.current_hover == 171
end
burrow_remove.title = "Remove burrow"
burrow_remove.message = "Are you sure you want to remove this burrow?"

stockpile_remove = defconf('stockpile-remove')
function stockpile_remove.intercept_key(key)
    return key == MOUSE_LEFT and df.global.game.main_interface.current_hover == 118
end
stockpile_remove.title = "Remove stockpile"
stockpile_remove.message = "Are you sure you want to remove this stockpile?"

-- these confirmations have more complex button detection requirements
--[[
trade = defconf('trade')
function trade.intercept_key(key)
    dfhack.gui.matchFocusString("dwarfmode/Trade") and key == MOUSE_LEFT and hovering over trade button?
end
trade.title = "Confirm trade"
function trade.get_message()
    if trader_goods_selected() and broker_goods_selected() then
        return "Are you sure you want to trade the selected goods?"
    elseif trader_goods_selected() then
        return "You are not giving any items. This is likely\n" ..
            "to irritate the merchants.\n" ..
            "Attempt to trade anyway?"
    elseif broker_goods_selected() then
        return "You are not receiving any items. You may want to\n" ..
            "offer these items instead or choose items to receive.\n" ..
            "Attempt to trade anyway?"
    else
        return "No items are selected. This is likely\n" ..
            "to irritate the merchants.\n" ..
            "Attempt to trade anyway?"
    end
end

trade_seize = defconf('trade-seize')
function trade_seize.intercept_key(key)
    return screen.in_edit_count == 0 and
        trader_goods_selected() and
        key == keys.TRADE_SEIZE
end
trade_seize.title = "Confirm seize"
trade_seize.message = "Are you sure you want to seize these goods?"

trade_offer = defconf('trade-offer')
function trade_offer.intercept_key(key)
    return screen.in_edit_count == 0 and
        broker_goods_selected() and
        key == keys.TRADE_OFFER
end
trade_offer.title = "Confirm offer"
trade_offer.message = "Are you sure you want to offer these goods?\nYou will receive no payment."

trade_select_all = defconf('trade-select-all')
function trade_select_all.intercept_key(key)
    if screen.in_edit_count == 0 and key == keys.SEC_SELECT then
        if screen.in_right_pane and broker_goods_selected() and not broker_goods_all_selected() then
            return true
        elseif not screen.in_right_pane and trader_goods_selected() and not trader_goods_all_selected() then
            return true
        end
    end
    return false
end
trade_select_all.title = "Confirm selection"
trade_select_all.message = "Selecting all goods will overwrite your current selection\n" ..
        "and cannot be undone. Continue?"

uniform_delete = defconf('uniform-delete')
function uniform_delete.intercept_key(key)
    return key == keys.D_MILITARY_DELETE_UNIFORM and
        screen.page == screen._type.T_page.Uniforms and
        #screen.equip.uniforms > 0 and
        not screen.equip.in_name_uniform
end
uniform_delete.title = "Delete uniform"
uniform_delete.message = "Are you sure you want to delete this uniform?"

note_delete = defconf('note-delete')
function note_delete.intercept_key(key)
    return key == keys.D_NOTE_DELETE and
        ui.main.mode == df.ui_sidebar_mode.NotesPoints and
        not ui.waypoints.in_edit_name_mode and
        not ui.waypoints.in_edit_text_mode
end
note_delete.title = "Delete note"
note_delete.message = "Are you sure you want to delete this note?"

route_delete = defconf('route-delete')
function route_delete.intercept_key(key)
    return key == keys.D_NOTE_ROUTE_DELETE and
        ui.main.mode == df.ui_sidebar_mode.NotesRoutes and
        not ui.waypoints.in_edit_name_mode
end
route_delete.title = "Delete route"
route_delete.message = "Are you sure you want to delete this route?"

convict = defconf('convict')
convict.title = "Confirm conviction"
function convict.intercept_key(key)
    return key == keys.SELECT and
        screen.cur_column == df.viewscreen_justicest.T_cur_column.ConvictChoices
end
function convict.get_message()
    name = dfhack.TranslateName(dfhack.units.getVisibleName(screen.convict_choices[screen.cursor_right]))
    if name == "" then
        name = "this creature"
    end
    return "Are you sure you want to convict " .. name .. "?\n" ..
        "This action is irreversible."
end
]]--

-- locations cannot be retired currently
--[[
location_retire = defconf('location-retire')
function location_retire.intercept_key(key)
    return key == keys.LOCATION_RETIRE and
        (screen.menu == df.viewscreen_locationsst.T_menu.Locations or
            screen.menu == df.viewscreen_locationsst.T_menu.Occupations) and
        screen.in_edit == df.viewscreen_locationsst.T_in_edit.None and
        screen.locations[screen.location_idx]
end
location_retire.title = "Retire location"
location_retire.message = "Are you sure you want to retire this location?"
]]--

-- End of confirmation definitions

function check()
    local undefined = {}
    for id in pairs(get_ids()) do
        if not confs[id] then
            table.insert(undefined, id)
        end
    end
    if #undefined > 0 then
        error('Confirmation definitions missing: ' .. table.concat(undefined, ', '))
    end
end

--[[
The C++ plugin invokes methods of individual confirmations through four
functions (corresponding to method names) which receive the relevant screen,
the confirmation ID, and extra arguments in some cases, but these don't have to
do aything unique.
]]

function define_wrapper(name)
    _ENV[name] = function(scr, id, ...)
        _ENV.screen = scr
        if not confs[id] then
            error('Bad confirmation ID: ' .. id)
        end
        return confs[id][name](...)
    end
end
define_wrapper('intercept_key')
define_wrapper('get_title')
define_wrapper('get_message')
define_wrapper('get_color')
return _ENV
