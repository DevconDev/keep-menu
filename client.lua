local QBCore = nil
if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local Promise, ActiveMenu = nil, false
local inventoryName = 'qb-inventory' -- @swkeep: make sure script using correct name

-- if you're not using qbcore change this where your inventory's images are
local img = "nui://" .. inventoryName .. "/html/images/"

RegisterNUICallback("dataPost", function(data, cb)
    local id = tonumber(data.id) + 1 or nil
    -- @swkeep: added PlaySoundFrontend to play menu sfx
    PlaySoundFrontend(-1, 'Highlight_Cancel', 'DLC_HEIST_PLANNING_BOARD_SOUNDS', 1)
    if not ActiveMenu then CloseMenu() return end
    local rData = ActiveMenu[id]
    if rData then
        if Promise ~= nil then
            if rData.args then
                rData.args['range'] = data.other_inputs
            else
                rData.args = {
                    range = data.other_inputs
                }
            end
            Promise:resolve(rData.args)
            Promise = nil
        end

        if rData.leave then
            CloseMenu()
            return
        end

        if rData.action then
            -- @swkeep: added action to trigger a function
            if rData.unpack then
                rData.action(table.unpack(rData.args or {}))
            else
                rData.action(rData.args)
            end
        end

        -- this part should not triggered at all!
        if not rData.event and rData.server then
            assert(rData.event, 'The Server event was called but no event name was passed!')
        elseif not rData.event and rData.client then
            assert(rData.event, 'The Client event was called but no event name was passed!')
        end

        if rData.event and Promise == nil then
            -- @swkeep: added qbcore/fivem command
            if rData.server then
                if rData.unpack then
                    TriggerServerEvent(rData.event, table.unpack(rData.args or {}))
                else
                    TriggerServerEvent(rData.event, rData.args)
                end
            elseif not rData.server then
                if rData.unpack then
                    TriggerEvent(rData.event, table.unpack(rData.args or {}))
                else
                    TriggerEvent(rData.event, rData.args)
                end

            elseif rData.client then
                if rData.unpack then
                    TriggerEvent(rData.event, table.unpack(rData.args or {}))
                else
                    TriggerEvent(rData.event, rData.args)
                end
            end

            if rData.command then
                ExecuteCommand(rData.event)
            end

            if QBCore and rData.QBCommand then
                if rData.unpack then
                    TriggerServerEvent('QBCore:CallCommand', rData.event, table.unpack(rData.args or {}))
                    TriggerEvent(rData.event, rData.args)
                else
                    TriggerServerEvent('QBCore:CallCommand', rData.event, rData.args)
                    TriggerEvent(rData.event, rData.args)
                end
            end
        end
    end
    CloseMenu()
    cb("ok")
end)

RegisterNUICallback("cancel", function(data, cb)
    if Promise ~= nil then
        Promise:resolve(nil)
        Promise = nil
    end
    CloseMenu()
    cb("ok")
end)

CreateMenu = function(data)
    ActiveMenu = ProcessParams(data)

    SendNUIMessage({
        action = "OPEN_MENU",
        data = data
    })
    SetNuiFocus(true, true)
end

ContextMenu = function(data)
    Wait(1)
    if not data or Promise ~= nil then return end
    if ActiveMenu then
        CloseMenu()
        while ActiveMenu do
            Wait(10)
        end
    end

    Promise = promise.new()

    CreateMenu(data)
    return table.unpack(Citizen.Await(Promise) or {})
end

-- @swkeep: overlay
Overlay = function(data)
    if not data then return end
    SendNUIMessage({
        action = "OPEN_OVERLAY",
        data = data
    })
end

-- @swkeep: overlay
CloseOverlay = function()
    SendNUIMessage({
        action = "CLOSE_OVERLAY",
    })
end

CloseMenu = function(cb)
    if Promise ~= nil then
        Promise:resolve(nil)
        Promise = nil
    end
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "CLOSE_MENU",
    })
    ActiveMenu = false
end

CancelMenu = function()
    SendNUIMessage({
        action = "CANCEL_MENU",
    })
end

ProcessParams = function(data)
    for _, v in pairs(data) do
        if v.args and type(v.args) == "table" and next(v.args) ~= nil then
            if not v.hide then
                v.args = PackParams(v.args)
            end
        end
        -- @swkeep: get images from user inventory
        if v.image then
            local i, j = string.find(v.image, "http")
            if i and j then
                -- it a http or https
                v.image = v.image -- do nothing :)
            else
                if QBCore then
                    if QBCore.Shared.Items[tostring(v.image)] then
                        v.image = img .. QBCore.Shared.Items[tostring(v.image)].image
                    end
                else
                    v.image = img .. v.image
                end
            end
        end
    end
    return data
end

local function length(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

PackParams = function(arguments)
    local args, pack = arguments, {}

    for i = 1, 15, 1 do
        pack[i] = args[i]
    end
    if not (#pack == length(args)) then
        local index = #pack + 1
        pack[index] = {}
        for key, value in pairs(args) do
            if not (type(key) == "number") then
                pack[index][key] = value
            end
        end
    end
    return pack
end

exports("createMenu", ContextMenu)
exports("closeMenu", CancelMenu)
-- @swkeep: overlay
exports("Overlay", Overlay)
exports("CloseOverlay", CloseOverlay)

RegisterNetEvent("keep-menu:createMenu", ContextMenu)
RegisterNetEvent("keep-menu:closeMenu", CancelMenu)
-- @swkeep: overlay
RegisterNetEvent("keep-menu:Overlay", Overlay)
RegisterNetEvent("keep-menu:closeOverlay", CloseOverlay)


local function qb(menu)
    local converted = {}

    for key, item in pairs(menu) do
        local temp_btn = {}
        if item.header then
            temp_btn.header = item.header
        end

        if item.txt then
            temp_btn.subheader = item.txt
        end

        if item.icon then
            temp_btn.icon = item.icon
        end

        if item.disabled then
            temp_btn.disabled = item.disabled
        end

        if item.hidden then
            temp_btn.hide = item.hidden
        end

        if item.isMenuHeader then
            temp_btn.is_header = item.isMenuHeader
        end

        if item.params then
            if item.params.args then
                temp_btn.args = item.params.args
                temp_btn.unpack = true
            end

            if item.params.event then
                temp_btn.event = item.params.event
            end

            if item.params.event and item.params.type then
                temp_btn.type = item.params.type
                temp_btn.event = item.params.event
            end

            if temp_btn.event == 'qb-menu:closeMenu' then
                temp_btn.event = 'keep-menu:closeMenu'
            end
        end
        converted[key] = temp_btn
    end

    ContextMenu(converted)
end

exports("openMenu", qb)

local function landing()
    local menu = {
        {
            header = 'Creator',
            subheader = 'test test as subheader',
            icon = 'fa-solid fa-industry',
            disabled = true,
            -- spacer = true
        },
        {
            search = true,
            disabled = false
        },
        {
            pervious = true,
            disabled = true,
            action = function()
                print('pervious')
            end
        },
        {
            next = true,
            action = function()
                print('next')
            end
        },
        {
            header = 'Exit Creator',
            subheader = 'reset & close creator',
            icon = 'fa-solid fa-trash',
        },
        {
            header = 'Hover Url',
            icon = 'fa-solid fa-trash',
            image = 'https://avatars.githubusercontent.com/u/49286776?v=4'
        },
        {
            header = 'Hover Inventory',
            icon = 'fa-solid fa-trash',
            image = 'lockpick',
            action = function(args)

            end,
            event = 'test:test',
            args = { { test = 'test' }, 2 }
        },
        {
            header = 'Creator',
            subheader = 'test test as subheader',
            range_slider = true,
            name = 'money',
            range = {
                min = 0,
                max = 10,
                step = 2,
                multiplier = 20,
            }
        },
        {
            header = 'Creator',
            subheader = 'test test as subheader',
            icon = 'fa-solid fa-sliders',
            range_slider = true,
            name = 'money2',
            range = {
                min = 0,
                max = 100,
                step = 25,
                multiplier = 20,
                currency = true
            }
        },
    }

    -- for i = 1, 15, 1 do
    --     menu[#menu + 1] = {
    --         header = 'search for (' .. i .. ')',
    --         subheader = 'reset & close creator',
    --         icon = 'fa-solid fa-trash',
    --         searchable = true
    --     }
    -- end
    exports['keep-menu']:createMenu(menu)
end

RegisterKeyMapping('+testmenu', 'test menu', 'keyboard', 'o')
RegisterCommand('+testmenu', function()
    if not IsPauseMenuActive() then
        landing()
    end
end, false)

CreateThread(function()

    Wait(500)
    landing()
end)

AddEventHandler('test:test', function(args)
    print_table(args)
end)

function print_table(node)
    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k, v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k, v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str, "}", output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str, "\n", output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output, output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "[" .. tostring(k) .. "]"
                else
                    key = "['" .. tostring(k) .. "']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = " .. tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = {\n"
                    table.insert(stack, node)
                    table.insert(stack, v)
                    cache[node] = cur_index + 1
                    break
                else
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = '" .. tostring(v) .. "'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str)
    output_str = table.concat(output)

    print(output_str)
end
