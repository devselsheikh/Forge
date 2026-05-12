--- FORGE: Server Collaboration Module
--- Multi-admin editing, live presence, object locking

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Collaboration = {
    _activeSessions = {},
    _lockedObjects = {},
    _collaborators = {},
}

--- Start a collaborative editing session
---@param source number Player server ID
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.startSession(source, sessionID)
    if not CONFIG.FEATURES.ENABLE_COLLABORATION then
        return false
    end
    
    local playerName = GetPlayerName(source)
    
    -- Create session
    Collaboration._activeSessions[sessionID] = {
        id = sessionID,
        owner = source,
        ownerName = playerName,
        startTime = GetGameTimer(),
        collaborators = { [source] = playerName },
        objectLocks = {},
    }
    
    -- Track collaborator
    if not Collaboration._collaborators[source] then
        Collaboration._collaborators[source] = {}
    end
    Collaboration._collaborators[source][sessionID] = true
    
    -- Broadcast session start
    TriggerClientEvent('forge:sessionStarted', -1, Collaboration._activeSessions[sessionID])
    
    return true
end

--- End a collaborative session
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.endSession(sessionID)
    if not Collaboration._activeSessions[sessionID] then
        return false
    end
    
    local session = Collaboration._activeSessions[sessionID]
    
    -- Unlock all objects in session
    for objectID, lockData in pairs(session.objectLocks) do
        Collaboration._lockedObjects[objectID] = nil
    end
    
    -- Remove collaborators
    for collaboratorID in pairs(session.collaborators) do
        if Collaboration._collaborators[collaboratorID] then
            Collaboration._collaborators[collaboratorID][sessionID] = nil
        end
    end
    
    -- Remove session
    Collaboration._activeSessions[sessionID] = nil
    
    -- Broadcast session end
    TriggerClientEvent('forge:sessionEnded', -1, sessionID)
    
    return true
end

--- Join a collaboration session
---@param source number Player server ID
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.joinSession(source, sessionID)
    if not CONFIG.FEATURES.ENABLE_COLLABORATION then
        return false
    end
    
    local session = Collaboration._activeSessions[sessionID]
    if not session then
        return false
    end
    
    local playerName = GetPlayerName(source)
    session.collaborators[source] = playerName
    
    if not Collaboration._collaborators[source] then
        Collaboration._collaborators[source] = {}
    end
    Collaboration._collaborators[source][sessionID] = true
    
    -- Broadcast collaborator join
    TriggerClientEvent('forge:collaboratorJoined', -1, {
        sessionID = sessionID,
        playerID = source,
        playerName = playerName,
    })
    
    return true
end

--- Leave a collaboration session
---@param source number Player server ID
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.leaveSession(source, sessionID)
    local session = Collaboration._activeSessions[sessionID]
    if not session then
        return false
    end
    
    -- Release all locks held by player in this session
    for objectID, lockData in pairs(session.objectLocks) do
        if lockData.owner == source then
            Collaboration._lockedObjects[objectID] = nil
            TriggerClientEvent('forge:objectUnlocked', -1, objectID)
        end
    end
    
    session.collaborators[source] = nil
    
    if Collaboration._collaborators[source] then
        Collaboration._collaborators[source][sessionID] = nil
    end
    
    -- End session if owner left
    if session.owner == source then
        Collaboration.endSession(sessionID)
    end
    
    -- Broadcast collaborator leave
    TriggerClientEvent('forge:collaboratorLeft', -1, {
        sessionID = sessionID,
        playerID = source,
    })
    
    return true
end

--- Lock object for editing (prevent conflicts)
---@param source number Player server ID
---@param objectID string Object UUID
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.lockObject(source, objectID, sessionID)
    local session = Collaboration._activeSessions[sessionID]
    if not session then
        return false
    end
    
    -- Check if already locked by someone else
    if Collaboration._lockedObjects[objectID] then
        local lockData = Collaboration._lockedObjects[objectID]
        if lockData.owner ~= source then
            return false
        end
    end
    
    -- Lock it
    Collaboration._lockedObjects[objectID] = {
        owner = source,
        sessionID = sessionID,
        lockTime = GetGameTimer(),
    }
    
    session.objectLocks[objectID] = Collaboration._lockedObjects[objectID]
    
    -- Broadcast lock
    TriggerClientEvent('forge:objectLocked', -1, {
        objectID = objectID,
        lockedBy = GetPlayerName(source),
        sessionID = sessionID,
    })
    
    return true
end

--- Unlock object (finished editing)
---@param source number Player server ID
---@param objectID string Object UUID
---@param sessionID string Session identifier
---@return boolean Success
function Collaboration.unlockObject(source, objectID, sessionID)
    local lockData = Collaboration._lockedObjects[objectID]
    if not lockData or lockData.owner ~= source then
        return false
    end
    
    Collaboration._lockedObjects[objectID] = nil
    
    local session = Collaboration._activeSessions[sessionID]
    if session then
        session.objectLocks[objectID] = nil
    end
    
    -- Broadcast unlock
    TriggerClientEvent('forge:objectUnlocked', -1, objectID)
    
    return true
end

--- Check if object is locked
---@param objectID string Object UUID
---@return boolean, string|nil locked, lockedByName
function Collaboration.isObjectLocked(objectID)
    local lockData = Collaboration._lockedObjects[objectID]
    if lockData then
        local ownerName = GetPlayerName(lockData.owner)
        return true, ownerName
    end
    return false, nil
end

--- Get active session info
---@param sessionID string Session identifier
---@return table|nil Session data or nil
function Collaboration.getSessionInfo(sessionID)
    return Collaboration._activeSessions[sessionID]
end

--- Get player's sessions
---@param source number Player server ID
---@return table Array of session IDs
function Collaboration.getPlayerSessions(source)
    local sessions = {}
    if Collaboration._collaborators[source] then
        for sessionID in pairs(Collaboration._collaborators[source]) do
            sessions[#sessions + 1] = sessionID
        end
    end
    return sessions
end

--- Get active collaborators
---@return table Array of {playerID, playerName, sessionID}
function Collaboration.getActiveCollaborators()
    local collab = {}
    for sessionID, session in pairs(Collaboration._activeSessions) do
        for playerID, playerName in pairs(session.collaborators) do
            collab[#collab + 1] = {
                playerID = playerID,
                playerName = playerName,
                sessionID = sessionID,
            }
        end
    end
    return collab
end

--- Broadcast player activity (for live presence)
---@param source number Player server ID
---@param action string Action performed
---@param sessionID string Session identifier
---@param data table Additional data
function Collaboration.broadcastActivity(source, action, sessionID, data)
    local session = Collaboration._activeSessions[sessionID]
    if session then
        TriggerClientEvent('forge:collaboratorActivity', -1, {
            sessionID = sessionID,
            playerID = source,
            playerName = GetPlayerName(source),
            action = action,
            data = data,
        })
    end
end

return Collaboration
