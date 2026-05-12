fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'forge'
author 'Forge Development'
description 'Enterprise-grade in-game world editor for FiveM - Zero-trust architecture with anti-exploit & collaborative editing'
version '1.0.0'

--- Shared initialization
shared_scripts {
    'shared/constants.lua',
    'shared/config.lua',
    'shared/utils.lua',
}

--- Client-side scripts
client_scripts {
    'client/editor_state.lua',
    'client/entity_manager.lua',
    'client/history.lua',
    'client/selection.lua',
    'client/streaming.lua',
    'client/transform_tools.lua',
    'client/input_handler.lua',
    'client/ui.lua',
    'client/main.lua',
}

--- Server-side scripts
server_scripts {
    'server/permissions.lua',
    'server/validation.lua',
    'server/entity_manager.lua',
    'server/persistence.lua',
    'server/collaboration.lua',
    'server/main.lua',
}

--- UI files
files {
    'client/nui/index.html',
    'client/nui/styles.css',
    'client/nui/app.js',
}

ui_page 'client/nui/index.html'

--- Client exports
exports {
    'isEditorOpen',
    'getSelectedObjects',
    'getObjectData',
}

--- Server exports
server_exports {
    'getMapData',
    'saveMapData',
    'loadMapData',
}