--- FORGE: Client History System
--- Unlimited undo/redo with state snapshots

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local History = {
    _entries = {},
    _currentIndex = 0,
    _maxEntries = CONFIG.PERFORMANCE.HISTORY_MAX_ENTRIES,
}

--- Action types
local ACTION_TYPES = {
    OBJECT_CREATED = 'objectCreated',
    OBJECT_DELETED = 'objectDeleted',
    OBJECT_MOVED = 'objectMoved',
    OBJECT_ROTATED = 'objectRotated',
    OBJECT_SCALED = 'objectScaled',
    OBJECTS_MULTISELECT = 'objectsMultiselect',
    BATCH_OPERATION = 'batchOperation',
}

--- Record an action
---@param actionType string Action type constant
---@param objectID string|table Object ID or array of IDs
---@param oldState table Previous state
---@param newState table New state
---@param description string Human-readable description
function History.recordAction(actionType, objectID, oldState, newState, description)
    -- Remove any redo history if we're making a new action
    while #History._entries > History._currentIndex do
        table.remove(History._entries)
    end
    
    -- Ensure we don't exceed max entries
    if History._currentIndex >= History._maxEntries then
        table.remove(History._entries, 1)
        History._currentIndex = History._currentIndex - 1
    end
    
    -- Create history entry
    local entry = {
        type = actionType,
        objectID = objectID,
        timestamp = GetGameTimer(),
        description = description or actionType,
        oldState = UTILS.deepCopy(oldState),
        newState = UTILS.deepCopy(newState),
    }
    
    History._currentIndex = History._currentIndex + 1
    History._entries[History._currentIndex] = entry
    
    TriggerEvent('forge:historyChanged', {
        current = History._currentIndex,
        total = #History._entries,
    })
end

--- Undo last action
---@return table|nil Entry that was undone or nil if at beginning
function History.undo()
    if History._currentIndex <= 0 then
        return nil
    end
    
    local entry = History._entries[History._currentIndex]
    History._currentIndex = History._currentIndex - 1
    
    TriggerEvent('forge:actionUndone', entry)
    TriggerEvent('forge:historyChanged', {
        current = History._currentIndex,
        total = #History._entries,
    })
    
    return entry
end

--- Redo last undone action
---@return table|nil Entry that was redone or nil if at end
function History.redo()
    if History._currentIndex >= #History._entries then
        return nil
    end
    
    History._currentIndex = History._currentIndex + 1
    local entry = History._entries[History._currentIndex]
    
    TriggerEvent('forge:actionRedone', entry)
    TriggerEvent('forge:historyChanged', {
        current = History._currentIndex,
        total = #History._entries,
    })
    
    return entry
end

--- Check if can undo
---@return boolean
function History.canUndo()
    return History._currentIndex > 0
end

--- Check if can redo
---@return boolean
function History.canRedo()
    return History._currentIndex < #History._entries
end

--- Get current entry
---@return table|nil
function History.getCurrent()
    if History._currentIndex > 0 then
        return History._entries[History._currentIndex]
    end
    return nil
end

--- Get history entries
---@return table Array of history entries
function History.getEntries()
    return UTILS.deepCopy(History._entries)
end

--- Clear history
function History.clear()
    History._entries = {}
    History._currentIndex = 0
    TriggerEvent('forge:historyCleared')
end

--- Get history info
---@return table {current, total}
function History.getInfo()
    return {
        current = History._currentIndex,
        total = #History._entries,
        canUndo = History.canUndo(),
        canRedo = History.canRedo(),
    }
end

--- Jump to specific history entry
---@param index number
---@return boolean
function History.jumpToEntry(index)
    if index < 0 or index > #History._entries then
        return false
    end
    
    History._currentIndex = index
    TriggerEvent('forge:historyJumped', index)
    return true
end

--- Record object creation
---@param objectID string
---@param objectData table
function History.recordObjectCreated(objectID, objectData)
    History.recordAction(
        ACTION_TYPES.OBJECT_CREATED,
        objectID,
        nil,
        objectData,
        'Created object'
    )
end

--- Record object deletion
---@param objectID string
---@param objectData table
function History.recordObjectDeleted(objectID, objectData)
    History.recordAction(
        ACTION_TYPES.OBJECT_DELETED,
        objectID,
        objectData,
        nil,
        'Deleted object'
    )
end

--- Record object move
---@param objectID string
---@param oldPos table {x, y, z}
---@param newPos table {x, y, z}
function History.recordObjectMoved(objectID, oldPos, newPos)
    History.recordAction(
        ACTION_TYPES.OBJECT_MOVED,
        objectID,
        { pos = oldPos },
        { pos = newPos },
        'Moved object'
    )
end

--- Record object rotation
---@param objectID string
---@param oldRot table {x, y, z}
---@param newRot table {x, y, z}
function History.recordObjectRotated(objectID, oldRot, newRot)
    History.recordAction(
        ACTION_TYPES.OBJECT_ROTATED,
        objectID,
        { rot = oldRot },
        { rot = newRot },
        'Rotated object'
    )
end

--- Record object scale
---@param objectID string
---@param oldScale table {x, y, z}
---@param newScale table {x, y, z}
function History.recordObjectScaled(objectID, oldScale, newScale)
    History.recordAction(
        ACTION_TYPES.OBJECT_SCALED,
        objectID,
        { scale = oldScale },
        { scale = newScale },
        'Scaled object'
    )
end

--- Record batch operation
---@param objectIDs table Array of object IDs
---@param description string
---@param oldStates table
---@param newStates table
function History.recordBatchOperation(objectIDs, description, oldStates, newStates)
    History.recordAction(
        ACTION_TYPES.BATCH_OPERATION,
        objectIDs,
        oldStates,
        newStates,
        description
    )
end

--- Create a save point (snapshot)
---@param name string Snapshot name
---@param allObjects table All current objects
function History.createSavePoint(name, allObjects)
    local entry = {
        type = 'SAVE_POINT',
        name = name,
        timestamp = GetGameTimer(),
        description = 'Save Point: ' .. name,
        snapshot = UTILS.deepCopy(allObjects),
    }
    
    History._currentIndex = History._currentIndex + 1
    History._entries[History._currentIndex] = entry
    
    -- Trim redo history
    while #History._entries > History._currentIndex do
        table.remove(History._entries)
    end
    
    -- Limit total entries
    if #History._entries > History._maxEntries then
        local toRemove = #History._entries - History._maxEntries
        for _ = 1, toRemove do
            table.remove(History._entries, 1)
        end
        History._currentIndex = History._currentIndex - toRemove
    end
end

return History
