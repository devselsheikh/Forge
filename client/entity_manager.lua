--- FORGE: Client Entity Manager
--- Manages local object representations, ghosting, and entity lifecycle

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local ClientEntityManager = {
    _objects = {},
    _entityHandles = {},
    _ghostEntities = {},
    _pendingCreation = {},
}

--- Create a ghost preview entity (local only)
---@param model number|string Model hash or name
---@param x number
---@param y number
---@param z number
---@param rx number
---@param ry number
---@param rz number
---@return number|nil Entity handle or nil on failure
function ClientEntityManager.createGhost(model, x, y, z, rx, ry, rz)
    local modelHash = UTILS.getModelHash(model)
    
    -- Request model
    RequestModel(modelHash)
    local timeout = GetGameTimer() + CONFIG.MODELS.TIMEOUT
    
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timeout then
            print('^1[Forge]^7 Model timeout: ' .. tostring(model) .. '^0')
            return nil
        end
        Wait(0)
    end
    
    -- Create entity
    local entity = CreateObject(modelHash, x, y, z, false, true, false)
    
    if entity and entity ~= 0 then
        SetEntityRotation(entity, rx, ry, rz, 2, true)
        SetEntityAsMissionEntity(entity, true, false)
        
        return entity
    end
    
    return nil
end

--- Create a networked object entity (after server validation)
---@param objectData table Object data
---@return number|nil Entity handle or nil on failure
function ClientEntityManager.createEntity(objectData)
    if not objectData or not objectData.model then
        return nil
    end
    
    local entity = ClientEntityManager.createGhost(
        objectData.model,
        objectData.x, objectData.y, objectData.z,
        UTILS.toRadians(objectData.rx),
        UTILS.toRadians(objectData.ry),
        UTILS.toRadians(objectData.rz)
    )
    
    if entity and entity ~= 0 then
        -- Store reference
        ClientEntityManager._objects[objectData.id] = {
            id = objectData.id,
            model = objectData.model,
            entity = entity,
            x = objectData.x,
            y = objectData.y,
            z = objectData.z,
            rx = objectData.rx,
            ry = objectData.ry,
            rz = objectData.rz,
            sx = objectData.sx or 1,
            sy = objectData.sy or 1,
            sz = objectData.sz or 1,
            owner = objectData.owner,
            state = CONSTANTS.ENTITY_STATE.SYNCED,
        }
        
        ClientEntityManager._entityHandles[entity] = objectData.id
        
        return entity
    end
    
    return nil
end

--- Update entity transform
---@param objectID string
---@param x number
---@param y number
---@param z number
---@param rx number
---@param ry number
---@param rz number
---@return boolean
function ClientEntityManager.updateTransform(objectID, x, y, z, rx, ry, rz)
    local object = ClientEntityManager._objects[objectID]
    if not object then return false end
    
    local entity = object.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    
    SetEntityCoords(entity, x, y, z, false, false, false, false)
    SetEntityRotation(entity, UTILS.toRadians(rx), UTILS.toRadians(ry), UTILS.toRadians(rz), 2, true)
    
    -- Update local record
    object.x = x
    object.y = y
    object.z = z
    object.rx = rx
    object.ry = ry
    object.rz = rz
    
    return true
end

--- Update entity scale
---@param objectID string
---@param sx number
---@param sy number
---@param sz number
---@return boolean
function ClientEntityManager.updateScale(objectID, sx, sy, sz)
    local object = ClientEntityManager._objects[objectID]
    if not object then return false end
    
    local entity = object.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false end
    
    local scale = math.max(sx, sy, sz)
    SetObjectScale(entity, scale)
    
    object.sx = sx
    object.sy = sy
    object.sz = sz
    
    return true
end

--- Delete entity
---@param objectID string
---@return boolean
function ClientEntityManager.deleteEntity(objectID)
    local object = ClientEntityManager._objects[objectID]
    if not object then return false end
    
    local entity = object.entity
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
        ClientEntityManager._entityHandles[entity] = nil
    end
    
    ClientEntityManager._objects[objectID] = nil
    return true
end

--- Get object by ID
---@param objectID string
---@return table|nil
function ClientEntityManager.getObject(objectID)
    return ClientEntityManager._objects[objectID]
end

--- Get all objects
---@return table
function ClientEntityManager.getAllObjects()
    return UTILS.deepCopy(ClientEntityManager._objects)
end

--- Get object by entity handle
---@param entity number Entity handle
---@return table|nil
function ClientEntityManager.getObjectByEntity(entity)
    local objectID = ClientEntityManager._entityHandles[entity]
    if objectID then
        return ClientEntityManager._objects[objectID]
    end
    return nil
end

--- Get entity by object ID
---@param objectID string
---@return number|nil
function ClientEntityManager.getEntity(objectID)
    local object = ClientEntityManager._objects[objectID]
    if object then
        return object.entity
    end
    return nil
end

--- Get object count
---@return number
function ClientEntityManager.getObjectCount()
    local count = 0
    for _ in pairs(ClientEntityManager._objects) do
        count = count + 1
    end
    return count
end

--- Clear all entities
function ClientEntityManager.clearAll()
    for objectID, object in pairs(ClientEntityManager._objects) do
        if object.entity and object.entity ~= 0 and DoesEntityExist(object.entity) then
            DeleteEntity(object.entity)
        end
    end
    
    ClientEntityManager._objects = {}
    ClientEntityManager._entityHandles = {}
end

--- Mark entity as dirty (needs server sync)
---@param objectID string
function ClientEntityManager.markDirty(objectID)
    local object = ClientEntityManager._objects[objectID]
    if object then
        object.state = CONSTANTS.ENTITY_STATE.PENDING
    end
end

--- Get dirty objects (need server sync)
---@return table
function ClientEntityManager.getDirtyObjects()
    local dirty = {}
    for objectID, object in pairs(ClientEntityManager._objects) do
        if object.state == CONSTANTS.ENTITY_STATE.PENDING then
            dirty[#dirty + 1] = object
        end
    end
    return dirty
end

--- Mark object as synced
---@param objectID string
function ClientEntityManager.markSynced(objectID)
    local object = ClientEntityManager._objects[objectID]
    if object then
        object.state = CONSTANTS.ENTITY_STATE.SYNCED
    end
end

return ClientEntityManager
