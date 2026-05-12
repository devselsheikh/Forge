--- FORGE: Server Entity Manager
--- Manages object lifecycle, ownership, networking, and persistence

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'
local Permissions = require 'server.permissions'
local Validation = require 'server.validation'

local EntityManager = {
    _objects = {},
    _objectsByChunk = {},
    _objectsByOwner = {},
    _entityHandles = {},
    _clientCache = {},
}

--- Create and register an object on the server
---@param source number Player server ID
---@param objectData table Object data with model, coords, rotation, scale
---@return string|nil objectID UUID or nil on failure
function EntityManager.createObject(source, objectData)
    -- Validate request
    local ok, err = Validation.validatePlacement(source, objectData)
    if not ok then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, err)
        return nil
    end
    
    -- Check permissions
    if not Permissions.canPlace(source) then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'No permission to place objects')
        return nil
    end
    
    -- Generate UUID and get owner
    local objectID = UTILS.generateUUID()
    local ownerID = Permissions.getIdentifier(source)
    
    -- Get chunk ID for spatial partitioning
    local chunkID = UTILS.getChunkID(objectData.x, objectData.y)
    
    -- Create object record
    local object = {
        id = objectID,
        model = objectData.model,
        x = objectData.x,
        y = objectData.y,
        z = objectData.z,
        rx = objectData.rotation and objectData.rotation[1] or 0,
        ry = objectData.rotation and objectData.rotation[2] or 0,
        rz = objectData.rotation and objectData.rotation[3] or 0,
        sx = objectData.scale and objectData.scale[1] or 1,
        sy = objectData.scale and objectData.scale[2] or 1,
        sz = objectData.scale and objectData.scale[3] or 1,
        owner = ownerID,
        creator = source,
        created = GetGameTimer(),
        updated = GetGameTimer(),
        state = CONSTANTS.ENTITY_STATE.SYNCED,
    }
    
    -- Store in local registry
    EntityManager._objects[objectID] = object
    
    -- Index by chunk
    if not EntityManager._objectsByChunk[chunkID] then
        EntityManager._objectsByChunk[chunkID] = {}
    end
    EntityManager._objectsByChunk[chunkID][objectID] = true
    
    -- Index by owner
    if not EntityManager._objectsByOwner[ownerID] then
        EntityManager._objectsByOwner[ownerID] = {}
    end
    EntityManager._objectsByOwner[ownerID][objectID] = true
    
    -- Broadcast to all clients
    TriggerClientEvent(CONSTANTS.EVENTS.SERVER_OBJECT_CREATED, -1, object)
    
    if CONFIG.DEBUG.ENABLED then
        TriggerEvent('chat:addMessage', {
            args = {'Forge', 'Object created: ' .. objectID},
            color = {0, 255, 0}
        })
    end
    
    return objectID
end

--- Update an object
---@param source number Player server ID
---@param objectID string Object UUID
---@param updates table Updates to apply
---@return boolean Success
function EntityManager.updateObject(source, objectID, updates)
    local object = EntityManager._objects[objectID]
    if not object then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'Object not found')
        return false
    end
    
    -- Permission check
    local playerID = Permissions.getIdentifier(source)
    if object.owner ~= playerID and not Permissions.canEditOthers(source) then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'Cannot edit this object')
        return false
    end
    
    -- Validate transform if included
    if updates.rotation or updates.scale then
        local ok, err = Validation.validateTransform(updates.rotation, updates.scale)
        if not ok then
            TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, err)
            return false
        end
    end
    
    -- Apply updates
    if updates.x and updates.y and updates.z then
        local ok, err = Validation.validateCoordinates(updates.x, updates.y, updates.z, source)
        if not ok then
            TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, err)
            return false
        end
        object.x, object.y, object.z = updates.x, updates.y, updates.z
    end
    
    if updates.rotation then
        object.rx = updates.rotation[1]
        object.ry = updates.rotation[2]
        object.rz = updates.rotation[3]
    end
    
    if updates.scale then
        object.sx = updates.scale[1]
        object.sy = updates.scale[2]
        object.sz = updates.scale[3]
    end
    
    object.updated = GetGameTimer()
    
    -- Broadcast update
    TriggerClientEvent(CONSTANTS.EVENTS.SERVER_OBJECT_UPDATED, -1, object)
    
    return true
end

--- Delete an object
---@param source number Player server ID
---@param objectID string Object UUID
---@return boolean Success
function EntityManager.deleteObject(source, objectID)
    local object = EntityManager._objects[objectID]
    if not object then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, 'Object not found')
        return false
    end
    
    -- Validate deletion
    local playerID = Permissions.getIdentifier(source)
    local ok, err = Validation.validateDeletion(source, objectID, object.owner)
    if not ok then
        TriggerClientEvent(CONSTANTS.EVENTS.SERVER_ERROR, source, err)
        return false
    end
    
    -- Get chunk ID
    local chunkID = UTILS.getChunkID(object.x, object.y)
    
    -- Remove from indices
    EntityManager._objects[objectID] = nil
    
    if EntityManager._objectsByChunk[chunkID] then
        EntityManager._objectsByChunk[chunkID][objectID] = nil
    end
    
    if EntityManager._objectsByOwner[playerID] then
        EntityManager._objectsByOwner[playerID][objectID] = nil
    end
    
    -- Broadcast deletion
    TriggerClientEvent(CONSTANTS.EVENTS.SERVER_OBJECT_DELETED, -1, objectID)
    
    return true
end

--- Get object by ID
---@param objectID string Object UUID
---@return table|nil
function EntityManager.getObject(objectID)
    return EntityManager._objects[objectID]
end

--- Get all objects in chunk
---@param chunkID number Chunk identifier
---@return table Array of objects
function EntityManager.getChunkObjects(chunkID)
    local objects = {}
    if EntityManager._objectsByChunk[chunkID] then
        for objectID in pairs(EntityManager._objectsByChunk[chunkID]) do
            local obj = EntityManager._objects[objectID]
            if obj then
                objects[#objects + 1] = obj
            end
        end
    end
    return objects
end

--- Get objects owned by player
---@param ownerID string Owner identifier
---@return table Array of objects
function EntityManager.getOwnerObjects(ownerID)
    local objects = {}
    if EntityManager._objectsByOwner[ownerID] then
        for objectID in pairs(EntityManager._objectsByOwner[ownerID]) do
            local obj = EntityManager._objects[objectID]
            if obj then
                objects[#objects + 1] = obj
            end
        end
    end
    return objects
end

--- Get all objects
---@return table Array of all objects
function EntityManager.getAllObjects()
    local objects = {}
    for _, obj in pairs(EntityManager._objects) do
        objects[#objects + 1] = obj
    end
    return objects
end

--- Get object count
---@return number
function EntityManager.getObjectCount()
    local count = 0
    for _ in pairs(EntityManager._objects) do
        count = count + 1
    end
    return count
end

--- Load objects from persistence
---@param objects table Array of object data
function EntityManager.loadObjects(objects)
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj.id then
            EntityManager._objects[obj.id] = obj
            
            local chunkID = UTILS.getChunkID(obj.x, obj.y)
            if not EntityManager._objectsByChunk[chunkID] then
                EntityManager._objectsByChunk[chunkID] = {}
            end
            EntityManager._objectsByChunk[chunkID][obj.id] = true
            
            if not EntityManager._objectsByOwner[obj.owner] then
                EntityManager._objectsByOwner[obj.owner] = {}
            end
            EntityManager._objectsByOwner[obj.owner][obj.id] = true
        end
    end
end

--- Clear all objects
function EntityManager.clearAllObjects()
    EntityManager._objects = {}
    EntityManager._objectsByChunk = {}
    EntityManager._objectsByOwner = {}
end

return EntityManager
