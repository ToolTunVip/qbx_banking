-- ==============================================================================
-- SETUP DATABASE
-- ==============================================================================

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `qbx_banking_transactions` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `receiver_identifier` varchar(64) NOT NULL,
          `receiver_name` varchar(255) NOT NULL DEFAULT '',
          `sender_identifier` varchar(64) NOT NULL,
          `sender_name` varchar(255) NOT NULL DEFAULT '',
          `date` timestamp NOT NULL DEFAULT current_timestamp(),
          `value` bigint(20) NOT NULL,
          `type` varchar(32) NOT NULL,
          PRIMARY KEY (`id`),
          KEY `receiver_identifier` (`receiver_identifier`),
          KEY `sender_identifier` (`sender_identifier`),
          KEY `date` (`date`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])

    local hasColumn = MySQL.scalar.await([[
        SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'pincode'
    ]])
    if tonumber(hasColumn) == 0 then
        MySQL.query.await('ALTER TABLE `players` ADD COLUMN `pincode` varchar(4) DEFAULT NULL')
    end
end)

-- ==============================================================================
-- HELPERS
-- ==============================================================================

local function getPlayer(src)
    if not src or src == 0 then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function notify(src, description, notifyType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'NGÂN HÀNG',
        description = description,
        type = notifyType or 'inform',
        position = 'top-right',
    })
end

-- Chỉ nhận số nguyên dương (chặn số âm / NaN / inf)
local function toAmount(value)
    value = tonumber(value)
    if not value or value ~= value or value <= 0 or value == math.huge then return nil end
    value = math.floor(value)
    if value < 1 then return nil end
    return value
end

local function playerFullName(player)
    local ci = player.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):match('^%s*(.-)%s*$')
end

local function nameFromCharinfo(charinfo)
    local info = charinfo
    if type(charinfo) == 'string' then
        local ok, decoded = pcall(json.decode, charinfo)
        info = ok and decoded or {}
    end
    info = info or {}
    return ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
end

-- Cột cũ kiểu int có thể mất số 0 đứng đầu -> chuẩn hóa về 4 ký tự
local function normPin(value)
    if value == nil or value == '' then return nil end
    value = tostring(value)
    if #value < 4 then value = ('0'):rep(4 - #value) .. value end
    return value
end

local function logTransaction(receiverId, receiverName, senderId, senderName, amount, trType)
    MySQL.insert('INSERT INTO qbx_banking_transactions (receiver_identifier, receiver_name, sender_identifier, sender_name, value, type) VALUES (?, ?, ?, ?, ?, ?)', {
        tostring(receiverId), tostring(receiverName or ''), tostring(senderId), tostring(senderName or ''), amount, trType,
    })
end

local function refresh(src)
    TriggerClientEvent('qbx_banking:client:refresh', src)
end

local function getStoredPin(citizenid)
    return normPin(MySQL.scalar.await('SELECT pincode FROM players WHERE citizenid = ?', { citizenid }))
end

-- ==============================================================================
-- CALLBACKS
-- ==============================================================================

local ALLOWED_DAYS = { [7] = true, [30] = true, [90] = true, [0] = true }

lib.callback.register('qbx_banking:getData', function(source, days)
    local player = getPlayer(source)
    if not player then return nil end

    days = tonumber(days) or 7
    if not ALLOWED_DAYS[days] then days = 7 end
    if days == 0 then days = 36500 end

    local cid = player.PlayerData.citizenid
    local rows = MySQL.query.await([[
        SELECT id, receiver_identifier, receiver_name, sender_identifier, sender_name,
               UNIX_TIMESTAMP(date) AS ts, value, type
        FROM qbx_banking_transactions
        WHERE (receiver_identifier = ? OR sender_identifier = ?)
          AND date >= (NOW() - INTERVAL ? DAY)
        ORDER BY id DESC
        LIMIT ?
    ]], { cid, cid, days, Config.TransactionLimit }) or {}

    return {
        name = playerFullName(player),
        citizenid = cid,
        serverId = source,
        bank = player.PlayerData.money.bank or 0,
        cash = player.PlayerData.money.cash or 0,
        hasPin = getStoredPin(cid) ~= nil,
        pinCost = Config.PINChangeCost,
        transactions = rows,
    }
end)

lib.callback.register('qbx_banking:hasPin', function(source)
    local player = getPlayer(source)
    if not player then return false end
    return getStoredPin(player.PlayerData.citizenid) ~= nil
end)

-- Xác thực PIN ở server (không gửi PIN xuống client) + khóa tạm khi nhập sai
local attempts = {}

lib.callback.register('qbx_banking:verifyPin', function(source, pin)
    local player = getPlayer(source)
    if not player then return false end

    local a = attempts[source]
    if a and a.lockUntil and a.lockUntil > os.time() then
        return false, 'locked'
    end

    local stored = getStoredPin(player.PlayerData.citizenid)
    if stored and tostring(pin) == stored then
        attempts[source] = nil
        return true
    end

    a = a or { count = 0 }
    a.count = a.count + 1
    if a.count >= 3 then
        a.lockUntil = os.time() + 30
        a.count = 0
    end
    attempts[source] = a
    return false
end)

AddEventHandler('playerDropped', function()
    attempts[source] = nil
end)

-- ==============================================================================
-- TÀI KHOẢN CÁ NHÂN
-- ==============================================================================

RegisterNetEvent('qbx_banking:server:deposit', function(amount)
    local src = source
    local player = getPlayer(src)
    amount = toAmount(amount)
    if not player or not amount then return end

    if (player.PlayerData.money.cash or 0) < amount then
        return notify(src, 'Bạn không có đủ tiền mặt', 'error')
    end
    if not player.Functions.RemoveMoney('cash', amount, 'bank-deposit') then return end
    player.Functions.AddMoney('bank', amount, 'bank-deposit')

    logTransaction('bank', 'Tài khoản ngân hàng', player.PlayerData.citizenid, playerFullName(player), amount, 'deposit')
    notify(src, ('Đã gửi $%s vào tài khoản'):format(amount), 'success')
    refresh(src)
end)

RegisterNetEvent('qbx_banking:server:withdraw', function(amount)
    local src = source
    local player = getPlayer(src)
    amount = toAmount(amount)
    if not player or not amount then return end

    if (player.PlayerData.money.bank or 0) < amount then
        return notify(src, 'Số dư tài khoản không đủ', 'error')
    end
    if not player.Functions.RemoveMoney('bank', amount, 'bank-withdraw') then return end
    player.Functions.AddMoney('cash', amount, 'bank-withdraw')

    logTransaction(player.PlayerData.citizenid, playerFullName(player), 'bank', 'Tài khoản ngân hàng', amount, 'withdraw')
    notify(src, ('Đã rút $%s tiền mặt'):format(amount), 'success')
    refresh(src)
end)

RegisterNetEvent('qbx_banking:server:transfer', function(amount, targetCid)
    local src = source
    local player = getPlayer(src)
    amount = toAmount(amount)
    targetCid = tostring(targetCid or ''):gsub('%s', ''):upper()
    if not player or not amount or targetCid == '' or #targetCid > 20 then return end

    local cid = player.PlayerData.citizenid
    if targetCid == cid then
        return notify(src, 'Không thể tự chuyển tiền cho bản thân', 'error')
    end

    local target = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { targetCid })
    if not target then
        return notify(src, 'Không tìm thấy tài khoản (Citizen ID) này', 'error')
    end
    if (player.PlayerData.money.bank or 0) < amount then
        return notify(src, 'Số dư tài khoản không đủ', 'error')
    end
    if not player.Functions.RemoveMoney('bank', amount, 'bank-transfer') then return end

    local senderName = playerFullName(player)
    local targetName = nameFromCharinfo(target.charinfo)
    local xTarget = exports.qbx_core:GetPlayerByCitizenId(target.citizenid)

    if xTarget then
        xTarget.Functions.AddMoney('bank', amount, 'bank-transfer-received')
        TriggerClientEvent('qbx_banking:client:incoming', xTarget.PlayerData.source,
            ('Bạn nhận được $%s từ %s'):format(amount, senderName))
        refresh(xTarget.PlayerData.source)
    else
        -- Người nhận đang offline: cộng thẳng vào JSON money (nguyên tử)
        MySQL.update.await([[
            UPDATE players
            SET money = JSON_SET(money, '$.bank', COALESCE(JSON_EXTRACT(money, '$.bank'), 0) + ?)
            WHERE citizenid = ?
        ]], { amount, target.citizenid })
    end

    logTransaction(target.citizenid, targetName, cid, senderName, amount, 'transfer')
    notify(src, ('Đã chuyển $%s tới %s'):format(amount, targetName), 'success')
    refresh(src)
end)

-- ==============================================================================
-- ĐỔI PIN
-- ==============================================================================

RegisterNetEvent('qbx_banking:server:changePin', function(pin)
    local src = source
    local player = getPlayer(src)
    if not player then return end

    pin = tostring(pin or '')
    if not pin:match('^%d%d%d%d$') then
        return notify(src, 'Mã PIN phải gồm đúng 4 chữ số', 'error')
    end

    local cid = player.PlayerData.citizenid
    local hasPin = getStoredPin(cid) ~= nil
    local cost = hasPin and (tonumber(Config.PINChangeCost) or 0) or 0

    if cost > 0 then
        if (player.PlayerData.money.bank or 0) < cost then
            return notify(src, ('Bạn cần có $%s trong tài khoản để đổi PIN'):format(cost), 'error')
        end
        if not player.Functions.RemoveMoney('bank', cost, 'bank-pin-change') then return end
        logTransaction('bank', 'Ngân hàng (Phí đổi PIN)', cid, playerFullName(player), cost, 'transfer')
    end

    MySQL.update.await('UPDATE players SET pincode = ? WHERE citizenid = ?', { pin, cid })
    notify(src, 'Đổi mã PIN thành công!', 'success')
    refresh(src)
end)
