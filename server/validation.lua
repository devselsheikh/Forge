--- FORGE: Server Validation Module
--- Zero-trust validation layer for all client requests

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Validation = {
    _rateLimits = {},
}

--- Rate limiting check
---@param source number Player server ID
---@param action string Action type (place, delete, etc)
---@return boolean, string|nil
function Validation.checkRateLimit(source, action)
    local key = source .. ':' .. action
    local now = GetGameTimer()
    
    if not Validation._rateLimits[key] then
        Validation._rateLimits[key] = { count = 0, resetTime = now + 1000 }
    end
    
    local limit = Validation._rateLimits[key]
    
    if now >= limit.resetTime then
        limit.count = 0
        limit.resetTime = now + 1000
    end
    
    limit.count = limit.count + 1
    
    -- Rate limits from config
    local maxPerSec = CONSTANTS.VALIDATION.RATE_LIMIT.EVENTS_PER_SEC
    if action == 'place' then
        maxPerSec = CONSTANTS.VALIDATION.RATE_LIMIT.OBJECTS_PER_SEC
    end
    
    if limit.count > maxPerSec then
        return false, 'Rate limited: ' .. action
    end
    
    return true, nil
end

--- Validate model hash
---@param modelHash number|string GTA model hash
---@return boolean, string|nil
function Validation.validateModel(modelHash)
    if type(modelHash) == 'string' then
        modelHash = UTILS.getModelHash(modelHash)
    end
    
    if type(modelHash) ~= 'number' or modelHash == 0 then
        return false, 'Invalid model hash'
    end
    
    -- Check blacklist
    if CONFIG.MODELS.BLACKLIST_ENABLED then
        for _, blocked in ipairs(CONFIG.MODELS.BLACKLIST) do
            if UTILS.getModelHash(blocked) == modelHash then
                return false, 'Model is blacklisted: ' .. blocked
            end
        end
    end
    
    -- Check whitelist
    if CONFIG.MODELS.WHITELIST_ENABLED then
        local found = false
        for _, allowed in ipairs(CONFIG.MODELS.WHITELIST) do
            if UTILS.getModelHash(allowed) == modelHash then
                found = true
                break
            end
        end
        if not found then
            return false, 'Model not in whitelist'
        end
    end
    
    return true, nil
end

--- Validate object placement coordinates
---@param x number
---@param y number
---@param z number
---@param source number Player server ID (for distance check)
---@return boolean, string|nil
function Validation.validateCoordinates(x, y, z, source)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return false, 'Invalid coordinates'
    end
    
    -- Sanity check bounds
    if not UTILS.isValidCoordinate(x, y, z) then
        return false, 'Coordinates out of bounds'
    end
    
    -- Distance check from player (prevent remote placement exploits)
    if source then
        local player = GetPlayerPed(source)
        if player and player ~= 0 then
            local px, py, pz = table.unpack(GetEntityCoords(player))
            local distance = UTILS.getDistance(x, y, z, px, py, pz)
            
            -- Allow 500 units from player
            if distance > 500.0 then
                return false, 'Too far from player: ' .. math.floor(distance) .. 'm'
            end
        end
    end
    
    return true, nil
end

--- Validate transform properties
---@param rotation table Rotation as {x, y, z} in degrees
---@param scale table Scale as {x, y, z}
---@return boolean, string|nil
function Validation.validateTransform(rotation, scale)
    if rotation then
        if type(rotation) ~= 'table' or #rotation ~= 3 then
            return false, 'Invalid rotation'
        end
        for i = 1, 3 do
            if type(rotation[i]) ~= 'number' then
                return false, 'Rotation values must be numbers'
            end
        end
    end
    
    if scale then
        if type(scale) ~= 'table' or #scale ~= 3 then
            return false, 'Invalid scale'
        end
        for i = 1, 3 do
            local s = scale[i]
            if type(s) ~= 'number' or s < CONSTANTS.OBJECT.MIN_SCALE or s > CONSTANTS.OBJECT.MAX_SCALE then
                return false, 'Scale out of range: ' .. CONSTANTS.OBJECT.MIN_SCALE .. ' to ' .. CONSTANTS.OBJECT.MAX_SCALE
            end
        end
    end
    
    return true, nil
end

--- Validate object payload size
---@param payload string|table Serialized object data
---@return boolean, string|nil
function Validation.validatePayloadSize(payload)
    local size = 0
    if type(payload) == 'string' then
        size = #payload
    elseif type(payload) == 'table' then
        size = #UTILS.toJSON(payload)
    end
    
    if size > CONSTANTS.VALIDATION.MAX_PAYLOAD then
        return false, 'Payload too large: ' .. size .. ' bytes (max ' .. CONSTANTS.VALIDATION.MAX_PAYLOAD .. ')'
    end
    
    return true, nil
end

--- Validate entire object placement request
---@param source number Player server ID
---@param objectData table Object data with model, coords, rotation, scale
---@return boolean, string|nil
function Validation.validatePlacement(source, objectData)
    if not objectData or type(objectData) ~= 'table' then
        return false, 'Invalid object data'
    end
    
    -- Validate payload size first
    local ok, err = Validation.validatePayloadSize(objectData)
    if not ok then return false, err end
    
    -- Rate limit
    ok, err = Validation.checkRateLimit(source, 'place')
    if not ok then return false, err end
    
    -- Validate model
    ok, err = Validation.validateModel(objectData.model)
    if not ok then return false, err end
    
    -- Validate coordinates
    ok, err = Validation.validateCoordinates(objectData.x, objectData.y, objectData.z, source)
    if not ok then return false, err end
    
    -- Validate transform
    ok, err = Validation.validateTransform(objectData.rotation, objectData.scale)
    if not ok then return false, err end
    
    return true, nil
end

--- Validate deletion request
---@param source number Player server ID
---@param objectID string Object UUID
---@param ownerID string Expected owner identifier
---@return boolean, string|nil
function Validation.validateDeletion(source, objectID, ownerID)
    if not objectID or type(objectID) ~= 'string' then
        return false, 'Invalid object ID'
    end
    
    -- Rate limit
    local ok, err = Validation.checkRateLimit(source, 'delete')
    if not ok then return false, err end
    
    -- Owner check - either owner or admin can delete
    local playerID = require 'server.permissions'.getIdentifier(source)
    if ownerID ~= playerID then
        if not require 'server.permissions'.canEditOthers(source) then
            return false, 'Object is owned by someone else'
        end
    end
    
    return true, nil
end

--- Validate map save request
---@param source number Player server ID
---@param mapName string Map identifier
---@param objectCount number Number of objects being saved
---@return boolean, string|nil
function Validation.validateMapSave(source, mapName, objectCount)
    if not mapName or type(mapName) ~= 'string' or #mapName < 1 then
        return false, 'Invalid map name'
    end
    
    if type(objectCount) ~= 'number' or objectCount < 0 or objectCount > CONSTANTS.EDITOR.MAX_ENTITIES then
        return false, 'Invalid object count'
    end
    
    return true, nil
end

return Validation
