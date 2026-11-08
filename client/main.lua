local isOpen = false
local currentDays = 7

local function fetchData(days)
    return lib.callback.await('qbx_banking:getData', false, days or currentDays)
end

local function notifyEnabled()
    return GetResourceKvpString('qbx_banking:notify') ~= '0'
end

local function sendOpen(data)
    SendNUIMessage({
        action = 'open',
        mode = 'bank',
        bankName = Config.BankName,
        notify = notifyEnabled(),
        data = data,
    })
end

local function closeUI()
    isOpen = false
    SetNuiFocus(false, false)
end

-- ==============================================================================
-- MỞ QUẦY NGÂN HÀNG
-- ==============================================================================

local function openBank()
    if isOpen then return end
    local data = fetchData(7)
    if not data then return end

    currentDays = 7
    isOpen = true
    SetNuiFocus(true, true)
    sendOpen(data)
end

-- ==============================================================================
-- MỞ ATM (nhập PIN -> xác thực ở server -> mở giao diện)
-- ==============================================================================

local function openATM()
    if isOpen then return end

    if not lib.callback.await('qbx_banking:hasPin', false) then
        return lib.notify({
            title = 'NGÂN HÀNG',
            description = 'Hãy đến quầy ngân hàng để cài đặt mã PIN cho thẻ của bạn.',
            type = 'inform',
            position = 'top-right',
            duration = 5000,
        })
    end

    isOpen = true

    local dict = 'anim@amb@prop_human_atm@interior@male@enter'
    local ped = cache.ped
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, 'enter', 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(Config.AnimTime)
    ClearPedTasks(ped)

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', mode = 'atm', bankName = Config.BankName })
end

-- ==============================================================================
-- NUI CALLBACKS
-- ==============================================================================

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

RegisterNUICallback('getData', function(data, cb)
    currentDays = tonumber(data and data.days) or 7
    cb(fetchData(currentDays) or {})
end)

RegisterNUICallback('verifyPin', function(data, cb)
    local ok, reason = lib.callback.await('qbx_banking:verifyPin', false, tostring(data and data.pin or ''))
    cb({ ok = ok and true or false, locked = reason == 'locked' })

    if ok then
        currentDays = 7
        local info = fetchData(7)
        if info then
            Wait(400)
            sendOpen(info)
        else
            closeUI()
        end
    end
end)

local function invalid()
    lib.notify({ title = 'NGÂN HÀNG', description = 'Dữ liệu nhập vào không hợp lệ', type = 'error', position = 'top-right' })
end

RegisterNUICallback('deposit', function(data, cb)
    local value = tonumber(data and data.value)
    if value and value >= 1 then
        TriggerServerEvent('qbx_banking:server:deposit', math.floor(value))
    else
        invalid()
    end
    cb({})
end)

RegisterNUICallback('withdraw', function(data, cb)
    local value = tonumber(data and data.value)
    if value and value >= 1 then
        TriggerServerEvent('qbx_banking:server:withdraw', math.floor(value))
    else
        invalid()
    end
    cb({})
end)

RegisterNUICallback('transfer', function(data, cb)
    local value = tonumber(data and data.value)
    local cid = type(data and data.citizenid) == 'string' and data.citizenid:gsub('%s', ''):upper() or ''
    if value and value >= 1 and cid ~= '' then
        TriggerServerEvent('qbx_banking:server:transfer', math.floor(value), cid)
    else
        invalid()
    end
    cb({})
end)

RegisterNUICallback('changePin', function(data, cb)
    local pin = tostring(data and data.pin or '')
    if pin:match('^%d%d%d%d$') then
        TriggerServerEvent('qbx_banking:server:changePin', pin)
    else
        lib.notify({ title = 'NGÂN HÀNG', description = 'Mã PIN phải gồm đúng 4 chữ số', type = 'error', position = 'top-right' })
    end
    cb({})
end)

RegisterNUICallback('setNotify', function(data, cb)
    SetResourceKvp('qbx_banking:notify', (data and data.enabled) and '1' or '0')
    cb({})
end)

-- ==============================================================================
-- EVENTS TỪ SERVER
-- ==============================================================================

RegisterNetEvent('qbx_banking:client:refresh', function()
    if not isOpen then return end
    Wait(150)
    local data = fetchData(currentDays)
    if data then
        SendNUIMessage({ action = 'update', data = data })
    end
end)

RegisterNetEvent('qbx_banking:client:incoming', function(message)
    if not notifyEnabled() then return end
    lib.notify({ title = 'NGÂN HÀNG', description = message, type = 'success', position = 'top-right' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

-- ==============================================================================
-- BLIP + OX_TARGET
-- ==============================================================================

CreateThread(function()
    if Config.ShowBankBlips then
        for _, v in ipairs(Config.BankLocations) do
            local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, v.blip)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, v.scale)
            SetBlipColour(blip, v.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('Ngân Hàng')
            EndTextCommandSetBlipName(blip)
        end
    end

    for i, v in ipairs(Config.BankLocations) do
        exports.ox_target:addBoxZone({
            coords = v.coords,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0.0,
            options = {
                {
                    name = 'qbx_banking_open_' .. i,
                    icon = 'fa-solid fa-building-columns',
                    label = 'Giao dịch Ngân Hàng',
                    distance = v.distance or 2.5,
                    onSelect = openBank,
                },
            },
        })
    end

    exports.ox_target:addModel(Config.ATMModels, {
        {
            name = 'qbx_banking_atm',
            icon = 'fa-solid fa-credit-card',
            label = 'Sử dụng cây ATM',
            distance = Config.ATMDistance or 1.5,
            onSelect = openATM,
        },
    })
end)
