--- FORGE: Server Main
--- Event handlers and main server logic

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'
local Permissions = require 'server.permissions'
local Validation = require 'server.validation'
local EntityManager = require 'server.entity_manager'
local Persistence = require 'server.persistence'
local Collaboration = require 'server.collaboration'

--- Initialize server
local function init()
    Persistence.init()
    
    print('^2[Forge] ^7Server initialized successfully.^0')
    print('^2[Forge] ^7Max entities: ' .. CONSTANTS.EDITOR.MAX_ENTITIES .. '^0')
    print('^2[Forge] ^7Collaboration enabled: ' .. tostring(CONFIG.FEATURES.ENABLE_COLLABORATION) .. '^0')
    print('^2[Forge] ^7Autosave enabled: ' .. tostring(CONFIG.PERSISTENCE.AUTOSAVE_ENABLED) .. '^0')
end

--- Event: Client requests to place object
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_PLACE_OBJECT, function(objectData)
    local source = source
    
    if CONFIG.DEBUG.ENABLED then
        print('^3[Forge Debug]^7 Place request from player ' .. source)
    end
    
    local objectID = EntityManager.createObject(source, objectData)
    if objectID then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_OBJECT_CREATED, source, {
            id = objectID,
            status = 'success',
        })
    end
end)

--- Event: Client requests to move/update object
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_MOVE_OBJECT, function(objectID, updates)
    local source = source
    
    if CONFIG.DEBUG.ENABLED then
        print('^3[Forge Debug]^7 Update request from player ' .. source .. ' for object ' .. objectID)
    end
    
    EntityManager.updateObject(source, objectID, updates)
end)

--- Event: Client requests to delete object
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_DELETE_OBJECT, function(objectID)
    local source = source
    
    if CONFIG.DEBUG.ENABLED then
        print('^3[Forge Debug]^7 Delete request from player ' .. source .. ' for object ' .. objectID)
    end
    
    EntityManager.deleteObject(source, objectID)
end)

--- Event: Client requests properties update
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_UPDATE_PROPERTIES, function(objectID, properties)
    local source = source
    EntityManager.updateObject(source, objectID, properties)
end)

--- Event: Client loads chunk
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_LOAD_CHUNK, function(x, y)
    local source = source
    local chunkID = UTILS.getChunkID(x, y)
    
    local objects = EntityManager.getChunkObjects(chunkID)
    TriggerClientEvent(CONSTANTS.EVENTS.SERVER_CHUNK_LOADED, source, {
        chunkID = chunkID,
        objects = objects,
    })
end)

--- Event: Client saves map
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_SAVE_MAP, function(mapName, metadata)
    local source = source
    
    if not Permissions.canManageMaps(source) then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'No permission to save maps')
        return
    end
    
    local objects = EntityManager.getAllObjects()
    local ok, err = Validation.validateMapSave(source, mapName, #objects)
    
    if not ok then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, err)
        return
    end
    
    if Persistence.saveMap(mapName, objects, metadata) then
        TriggerClientEvent('forge:mapSaved', source, {
            mapName = mapName,
            objectCount = #objects,
        })
        
        print('^2[Forge]^7 Map saved: ' .. mapName .. ' with ' .. #objects .. ' objects')
    else
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'Failed to save map')
    end
end)

--- Event: Client loads map
RegisterNetEvent(CONSTANTS.EVENTS.CLIENT_LOAD_MAP, function(mapName)
    local source = source
    
    if not Permissions.canManageMaps(source) then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'No permission to load maps')
        return
    end
    
    local mapData = Persistence.loadMap(mapName)
    if not mapData then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'Map not found: ' .. mapName)
        return
    end
    
    -- Clear and load objects
    EntityManager.clearAllObjects()
    EntityManager.loadObjects(mapData.objects)
    
    -- Broadcast to all clients
    TriggerClientEvent('forge:mapLoaded', -1, {
        mapName = mapName,
        objectCount = mapData.objectCount,
        objects = mapData.objects,
    })
    
    print('^2[Forge]^7 Map loaded: ' .. mapName)
end)

--- Collaboration Events

RegisterNetEvent('forge:startSession', function(sessionID)
    local source = source
    Collaboration.startSession(source, sessionID)
end)

RegisterNetEvent('forge:endSession', function(sessionID)
    local source = source
    Collaboration.endSession(sessionID)
end)

RegisterNetEvent('forge:joinSession', function(sessionID)
    local source = source
    Collaboration.joinSession(source, sessionID)
end)

RegisterNetEvent('forge:leaveSession', function(sessionID)
    local source = source
    Collaboration.leaveSession(source, sessionID)
end)

RegisterNetEvent('forge:lockObject', function(objectID, sessionID)
    local source = source
    Collaboration.lockObject(source, objectID, sessionID)
end)

RegisterNetEvent('forge:unlockObject', function(objectID, sessionID)
    local source = source
    Collaboration.unlockObject(source, objectID, sessionID)
end)

--- Player disconnect cleanup
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    -- End all sessions for player
    local sessions = Collaboration.getPlayerSessions(source)
    for i = 1, #sessions do
        Collaboration.leaveSession(source, sessions[i])
    end
    
    -- Clear permission cache
    Permissions.clearCache(source)
end)

--- Server exports

--- Get all map data
exports('getMapData', function()
    return EntityManager.getAllObjects()
end)

--- Save map data
exports('saveMapData', function(mapName, objects, metadata)
    return Persistence.saveMap(mapName, objects, metadata)
end)

--- Load map data
exports('loadMapData', function(mapName)
    return Persistence.loadMap(mapName)
end)

--- Initialize when resource starts
init()

print('^2[Forge]^7 Server resource loaded successfully')
