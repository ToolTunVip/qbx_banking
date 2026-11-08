Config = {}

Config.BankName = 'TOOLUN CITY BANK'

Config.PINChangeCost = 100        -- Phí đổi PIN (lần đặt PIN đầu tiên miễn phí)
Config.AnimTime = 2000            -- Thời gian animation ATM (ms)
Config.TransactionLimit = 200     -- Số giao dịch tối đa tải về mỗi lần

Config.ShowBankBlips = true

-- blip: https://docs.fivem.net/docs/game-references/blips/
Config.BankLocations = {
    { coords = vec3(150.266, -1040.203, 29.374),   blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(-1212.980, -330.841, 37.787),  blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(-2962.582, 482.627, 15.703),   blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(-112.202, 6469.295, 31.626),   blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(314.187, -278.621, 54.170),    blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(-351.534, -49.529, 49.042),    blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(252.33, 218.11, 106.29),       blip = 108, color = 2, scale = 0.9, distance = 2.5 },
    { coords = vec3(1175.064, 2706.643, 38.094),   blip = 108, color = 2, scale = 0.9, distance = 2.5 },
}

Config.ATMDistance = 1.5
Config.ATMModels = { -870868698, -1126227515, -1264697528, 506770882 }
