--- FORGE: Server Permissions Module
--- ACE-based permission system for zero-trust access control

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Permissions = {
    _cache = {},
    _cacheTimeout = 60000, -- 1 minute
}

--- Check if player has permission
---@param source number Player server ID
---@param permission string Permission ACE identifier
---@return boolean
function Permissions.hasPermission(source, permission)
    if not source or source == 0 then return false end
    
    -- Cache check
    local cacheKey = source .. ':' .. permission
    if Permissions._cache[cacheKey] then
        local cached = Permissions._cache[cacheKey]
        if (GetGameTimer() - cached.time) < Permissions._cacheTimeout then
            return cached.result
        end
        Permissions._cache[cacheKey] = nil
    end
    
    -- Check ACE
    local result = IsPlayerAceAllowed(source, permission)
    
    -- Cache result
    Permissions._cache[cacheKey] = {
        result = result,
        time = GetGameTimer()
    }
    
    return result
end

--- Clear permission cache for player
---@param source number Player server ID
function Permissions.clearCache(source)
    for key in pairs(Permissions._cache) do
        if key:startsWith(source .. ':') then
            Permissions._cache[key] = nil
        end
    end
end

--- Require permission, kick if denied
---@param source number Player server ID
---@param permission string Permission ACE identifier
---@param actionName string Name of action for logs
---@return boolean
function Permissions.requirePermission(source, permission, actionName)
    if not Permissions.hasPermission(source, permission) then
        TriggerEvent('txAdmin:log', ('Forge: Permission denied for %s - %s'):format(GetPlayerName(source), actionName))
        DropPlayer(source, 'Access denied: ' .. actionName)
        return false
    end
    return true
end

--- Check if player can place objects
---@param source number Player server ID
---@return boolean
function Permissions.canPlace(source)
    return Permissions.hasPermission(source, CONFIG.PERMISSIONS.PLACE_OBJECTS) or
           Permissions.hasPermission(source, 'group.admin')
end

--- Check if player can delete objects
---@param source number Player server ID
---@return boolean
function Permissions.canDelete(source)
    return Permissions.hasPermission(source, CONFIG.PERMISSIONS.DELETE_OBJECTS) or
           Permissions.hasPermission(source, 'group.admin')
end

--- Check if player can edit others' objects
---@param source number Player server ID
---@return boolean
function Permissions.canEditOthers(source)
    return Permissions.hasPermission(source, CONFIG.PERMISSIONS.EDIT_OTHERS) or
           Permissions.hasPermission(source, 'group.admin')
end

--- Check if player can manage maps
---@param source number Player server ID
---@return boolean
function Permissions.canManageMaps(source)
    return Permissions.hasPermission(source, CONFIG.PERMISSIONS.MANAGE_MAPS) or
           Permissions.hasPermission(source, 'group.admin')
end

--- Check if player can open editor
---@param source number Player server ID
---@return boolean
function Permissions.canOpenEditor(source)
    return Permissions.hasPermission(source, CONFIG.PERMISSIONS.OPEN_EDITOR) or
           Permissions.hasPermission(source, CONFIG.PERMISSIONS.PLACE_OBJECTS) or
           Permissions.hasPermission(source, 'group.admin')
end

--- Get permission level
---@param source number Player server ID
---@return number 0=none, 1=viewer, 2=editor, 3=admin
function Permissions.getLevel(source)
    if Permissions.hasPermission(source, 'group.admin') then return 3 end
    if Permissions.canEditOthers(source) then return 3 end
    if Permissions.canPlace(source) then return 2 end
    if Permissions.hasPermission(source, CONFIG.PERMISSIONS.VIEW_ONLY) then return 1 end
    return 0
end

--- Get player identifier (for object ownership)
---@param source number Player server ID
---@return string
function Permissions.getIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:startsWith('license:') or id:startsWith('char:') or id:startsWith('steam:') then
            return id
        end
    end
    return 'player:' .. source
end

return Permissions
