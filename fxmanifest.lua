fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'qbx_banking'
description 'Hệ thống ngân hàng & ATM cho Qbox (số tài khoản = Citizen ID)'
version '2.0.0'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/logo.png', -- (tùy chọn) bỏ logo của bạn vào đây, không có thì dùng logo chữ
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
