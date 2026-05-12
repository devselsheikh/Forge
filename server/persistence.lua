--- FORGE: Server Persistence Module
--- Map storage, backup, and version control

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Persistence = {
    _saveQueue = {},
    _autosaveTimer = nil,
}

--- Initialize persistence system
function Persistence.init()
    -- Create data directory if needed
    if CONFIG.DATABASE.ENABLED and CONFIG.DATABASE.TYPE == 'json' then
        if not DirExists(CONFIG.DATABASE.PATH) then
            CreateDirectory(CONFIG.DATABASE.PATH)
        end
    end
    
    -- Start autosave timer if enabled
    if CONFIG.PERSISTENCE.AUTOSAVE_ENABLED then
        Persistence._autosaveTimer = SetInterval(function()
            Persistence.processAutosave()
        end, CONFIG.PERFORMANCE.AUTOSAVE_INTERVAL)
    end
end

--- Get map file path
---@param mapName string Map identifier
---@return string
function Persistence.getMapPath(mapName)
    return CONFIG.DATABASE.PATH .. 'map_' .. mapName .. '.json'
end

--- Save map to disk
---@param mapName string Map identifier
---@param objects table Array of objects to save
---@param metadata table Optional metadata
---@return boolean Success
function Persistence.saveMap(mapName, objects, metadata)
    if not CONFIG.DATABASE.ENABLED then
        return false
    end
    
    if CONFIG.DATABASE.TYPE == 'json' then
        local mapData = {
            name = mapName,
            version = CONSTANTS.EDITOR.VERSION,
            timestamp = GetGameTimer(),
            objectCount = #objects,
            metadata = metadata or {},
            objects = objects,
        }
        
        local json = UTILS.toJSON(mapData)
        local path = Persistence.getMapPath(mapName)
        
        -- Create backup if exists
        if FileExists(path) and CONFIG.PERSISTENCE.AUTO_BACKUP then
            local backupPath = path .. '.backup'
            if FileExists(backupPath) then
                os.remove(backupPath)
            end
            os.rename(path, backupPath)
        end
        
        -- Write file
        local f = io.open(path, 'w')
        if f then
            f:write(json)
            f:close()
            return true
        end
    end
    
    return false
end

--- Load map from disk
---@param mapName string Map identifier
---@return table|nil Map data or nil on failure
function Persistence.loadMap(mapName)
    if not CONFIG.DATABASE.ENABLED then
        return nil
    end
    
    if CONFIG.DATABASE.TYPE == 'json' then
        local path = Persistence.getMapPath(mapName)
        
        if not FileExists(path) then
            return nil
        end
        
        local f = io.open(path, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            
            local mapData = UTILS.fromJSON(content)
            return mapData
        end
    end
    
    return nil
end

--- List all saved maps
---@return table Array of map names
function Persistence.listMaps()
    if not CONFIG.DATABASE.ENABLED then
        return {}
    end
    
    local maps = {}
    if CONFIG.DATABASE.TYPE == 'json' then
        -- Scan directory
        local handle = io.popen('dir "' .. CONFIG.DATABASE.PATH .. 'map_*.json" /b')
        if handle then
            for filename in handle:lines() do
                local mapName = filename:gsub('^map_', ''):gsub('%.json$', '')
                maps[#maps + 1] = mapName
            end
            handle:close()
        end
    end
    return maps
end

--- Delete map
---@param mapName string Map identifier
---@return boolean Success
function Persistence.deleteMap(mapName)
    if not CONFIG.DATABASE.ENABLED then
        return false
    end
    
    if CONFIG.DATABASE.TYPE == 'json' then
        local path = Persistence.getMapPath(mapName)
        if FileExists(path) then
            return os.remove(path) == 0
        end
    end
    
    return false
end

--- Create a snapshot/checkpoint
---@param mapName string Map identifier
---@param snapshot string Snapshot name/ID
---@param objects table Objects to snapshot
---@return boolean Success
function Persistence.createSnapshot(mapName, snapshot, objects)
    if not CONFIG.DATABASE.ENABLED or not CONFIG.PERSISTENCE.KEEP_HISTORY then
        return false
    end
    
    if CONFIG.DATABASE.TYPE == 'json' then
        local mapData = {
            name = mapName,
            snapshot = snapshot,
            version = CONSTANTS.EDITOR.VERSION,
            timestamp = GetGameTimer(),
            objectCount = #objects,
            objects = objects,
        }
        
        local json = UTILS.toJSON(mapData)
        local path = CONFIG.DATABASE.PATH .. 'snapshot_' .. mapName .. '_' .. snapshot .. '.json'
        
        local f = io.open(path, 'w')
        if f then
            f:write(json)
            f:close()
            return true
        end
    end
    
    return false
end

--- List snapshots for map
---@param mapName string Map identifier
---@return table Array of snapshot IDs
function Persistence.listSnapshots(mapName)
    if not CONFIG.DATABASE.ENABLED or not CONFIG.PERSISTENCE.KEEP_HISTORY then
        return {}
    end
    
    local snapshots = {}
    if CONFIG.DATABASE.TYPE == 'json' then
        local handle = io.popen('dir "' .. CONFIG.DATABASE.PATH .. 'snapshot_' .. mapName .. '_*.json" /b')
        if handle then
            for filename in handle:lines() do
                local snapshotID = filename:gsub('^snapshot_' .. mapName .. '_', ''):gsub('%.json$', '')
                snapshots[#snapshots + 1] = snapshotID
            end
            handle:close()
        end
    end
    return snapshots
end

--- Restore from snapshot
---@param mapName string Map identifier
---@param snapshot string Snapshot name/ID
---@return table|nil Restored objects or nil on failure
function Persistence.restoreSnapshot(mapName, snapshot)
    if not CONFIG.DATABASE.ENABLED or not CONFIG.PERSISTENCE.KEEP_HISTORY then
        return nil
    end
    
    if CONFIG.DATABASE.TYPE == 'json' then
        local path = CONFIG.DATABASE.PATH .. 'snapshot_' .. mapName .. '_' .. snapshot .. '.json'
        
        if FileExists(path) then
            local f = io.open(path, 'r')
            if f then
                local content = f:read('*a')
                f:close()
                
                local mapData = UTILS.fromJSON(content)
                return mapData.objects
            end
        end
    end
    
    return nil
end

--- Process autosave
function Persistence.processAutosave()
    -- This is called periodically to save any queued maps
    -- Implementation depends on how EntityManager tracks dirty state
end

--- Add map to save queue
---@param mapName string Map identifier
---@param objects table Objects to save
function Persistence.queueMapSave(mapName, objects)
    Persistence._saveQueue[mapName] = {
        objects = UTILS.deepCopy(objects),
        queueTime = GetGameTimer(),
    }
end

--- Process save queue (batched)
function Persistence.processSaveQueue()
    for mapName, data in pairs(Persistence._saveQueue) do
        local timeSinceQueued = GetGameTimer() - data.queueTime
        
        -- Save if queued for at least 5 seconds (debounce)
        if timeSinceQueued > 5000 then
            Persistence.saveMap(mapName, data.objects)
            Persistence._saveQueue[mapName] = nil
        end
    end
end

--- Export map as resource
---@param mapName string Map identifier
---@param resourceName string FiveM resource name
---@param objects table Objects to export
---@return boolean Success
function Persistence.exportAsResource(mapName, resourceName, objects)
    if not CONFIG.DATABASE.ENABLED then
        return false
    end
    
    -- Create resource structure
    local resourcePath = 'resources/' .. resourceName .. '/'
    
    -- Generate client.lua with object spawning
    local clientLua = string.format([[
-- Generated by Forge World Editor
-- Map: %s

local OBJECTS = %s

function SpawnMap()
    for i = 1, #OBJECTS do
        local obj = OBJECTS[i]
        RequestModel(GetHashKey(obj.model))
        while not HasModelLoaded(GetHashKey(obj.model)) do
            Wait(0)
        end
        
        local entity = CreateObject(GetHashKey(obj.model), obj.x, obj.y, obj.z, false, false, false)
        SetEntityRotation(entity, obj.rx, obj.ry, obj.rz, 2, true)
        SetObjectScale(entity, math.max(obj.sx, obj.sy, obj.sz))
        PlaceObjectOnGroundProperly(entity)
    end
end

-- Auto-spawn on resource start
SpawnMap()
]], mapName, UTILS.toJSON(objects))
    
    -- Write client.lua
    local clientPath = resourcePath .. 'client.lua'
    local f = io.open(clientPath, 'w')
    if f then
        f:write(clientLua)
        f:close()
    else
        return false
    end
    
    -- Generate fxmanifest.lua
    local manifestLua = string.format([[
fx_version 'cerulean'
game 'gta5'

author '%s'
description 'Map exported from Forge World Editor'
version '1.0.0'

client_scripts {
    'client.lua'
}
]], mapName)
    
    local manifestPath = resourcePath .. 'fxmanifest.lua'
    f = io.open(manifestPath, 'w')
    if f then
        f:write(manifestLua)
        f:close()
    else
        return false
    end
    
    return true
end

return Persistence
