fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'RideGo AI'
description 'Aplicativo de corridas estilo Uber para FiveM'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/styles.css',
    'ui/app.js'
}
