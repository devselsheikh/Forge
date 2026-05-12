--- FORGE: Client UI Module
--- NUI communication and UI state management

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local UI = {
    _isNuiFocused = false,
    _lastUpdate = 0,
}

--- Initialize UI
function UI.init()
    print('^2[Forge]^7 UI initialized')
end

--- Send message to NUI
---@param action string Action name
---@param data table Data payload
function UI.sendNuiMessage(action, data)
    SendNUIMessage({
        action = action,
        payload = data,
    })
end

--- Toggle NUI focus
---@param hasFocus boolean
function UI.setNuiFocus(hasFocus)
    UI._isNuiFocused = hasFocus
    SetNuiFocus(hasFocus, hasFocus)
end

--- Update editor state in NUI
---@param editorState table Editor state
function UI.updateEditorState(editorState)
    UI.sendNuiMessage('editorStateChanged', {
        isOpen = editorState.isOpen,
        mode = editorState.mode,
    })
end

--- Update selected object in NUI
---@param objectID string
---@param objectData table
function UI.updateSelectedObject(objectID, objectData)
    UI.sendNuiMessage('objectSelected', {
        objectID = objectID,
        object = objectData,
    })
end

--- Notify object created
---@param objectData table
function UI.notifyObjectCreated(objectData)
    UI.sendNuiMessage('objectCreated', {
        object = objectData,
    })
end

--- Notify object deleted
---@param objectID string
function UI.notifyObjectDeleted(objectID)
    UI.sendNuiMessage('objectDeleted', {
        objectID = objectID,
    })
end

--- Update history in NUI
---@param historyInfo table {current, total, canUndo, canRedo}
function UI.updateHistory(historyInfo)
    UI.sendNuiMessage('historyChanged', historyInfo)
end

--- Notify collaborator joined
---@param playerID number
---@param playerName string
---@param sessionID string
function UI.notifyCollaboratorJoined(playerID, playerName, sessionID)
    UI.sendNuiMessage('collaboratorJoined', {
        playerID = playerID,
        playerName = playerName,
        sessionID = sessionID,
    })
end

--- Notify collaborator left
---@param playerID number
function UI.notifyCollaboratorLeft(playerID)
    UI.sendNuiMessage('collaboratorLeft', {
        playerID = playerID,
    })
end

--- Update performance metrics
---@param fps number
---@param resmon number
---@param objectCount number
function UI.updatePerformance(fps, resmon, objectCount)
    UI.sendNuiMessage('performanceUpdate', {
        fps = fps,
        resmon = resmon,
        objectCount = objectCount,
    })
end

--- Show notification
---@param title string
---@param message string
---@param type string 'info', 'success', 'warning', 'error'
---@param duration number Milliseconds
function UI.showNotification(title, message, type, duration)
    UI.sendNuiMessage('showNotification', {
        title = title,
        message = message,
        type = type or 'info',
        duration = duration or 3000,
    })
end

--- Request UI action
---@param action string
---@param callback function Callback when user responds
function UI.requestAction(action, callback)
    -- This would be used for dialogs, file pickers, etc.
    -- For now, we'll use simple prompts
    if action == 'saveMap' then
        local mapName = string.lower(input('Enter map name:', 'my_map'))
        if mapName and mapName ~= '' then
            callback(mapName)
        end
    elseif action == 'loadMap' then
        local mapName = string.lower(input('Enter map name to load:', ''))
        if mapName and mapName ~= '' then
            callback(mapName)
        end
    end
end

--- Update status bar message
---@param message string
function UI.setStatusMessage(message)
    UI.sendNuiMessage('setStatus', {
        message = message,
    })
end

--- Update coordinate display
---@param x number
---@param y number
---@param z number
function UI.updateCoordinateDisplay(x, y, z)
    UI.sendNuiMessage('updateCoords', {
        x = UTILS.round(x, 2),
        y = UTILS.round(y, 2),
        z = UTILS.round(z, 2),
    })
end

--- Update inspector properties
---@param objectData table
function UI.updateInspectorProperties(objectData)
    if objectData then
        UI.sendNuiMessage('updateInspector', {
            x = objectData.x,
            y = objectData.y,
            z = objectData.z,
            rx = objectData.rx,
            ry = objectData.ry,
            rz = objectData.rz,
            sx = objectData.sx,
            sy = objectData.sy,
            sz = objectData.sz,
        })
    end
end

--- Get NUI focus state
---@return boolean
function UI.getNuiFocus()
    return UI._isNuiFocused
end

--- Handle NUI callback
---@param action string Action from NUI
---@param data table Data from NUI
function UI.handleNuiCallback(action, data)
    -- This is called when NUI sends data back to Lua
    local EditorState = require 'client.editor_state'
    local EntityManager = require 'client.entity_manager'
    local History = require 'client.history'
    local Selection = require 'client.selection'
    local TransformTools = require 'client.transform_tools'
    
    if action == 'setTransformMode' then
        EditorState.setTransformMode(data.mode)
    elseif action == 'toggleSnapGrid' then
        EditorState.toggleGridSnap()
        UI.showNotification('Grid', 'Grid snap ' .. (EditorState.gridEnabled and 'enabled' or 'disabled'), 'info', 1500)
    elseif action == 'toggleSnapAngle' then
        EditorState.toggleAngleSnap()
        UI.showNotification('Angle', 'Angle snap ' .. (EditorState.angleSnapEnabled and 'enabled' or 'disabled'), 'info', 1500)
    elseif action == 'toggleTransformSpace' then
        local space = EditorState.toggleTransformSpace()
        local spaceName = space == CONSTANTS.TRANSFORM.WORLD_SPACE and 'World' or 'Local'
        UI.showNotification('Transform Space', spaceName .. ' space', 'info', 1500)
    elseif action == 'deleteSelected' then
        local selected = Selection.getSelectedObjects()
        for i = 1, #selected do
            TriggerServerEvent(CONSTANTS.EVENTS.CLIENT_DELETE_OBJECT, selected[i])
        end
    elseif action == 'duplicateSelected' then
        Selection.duplicateSelected(EntityManager, {x = 1, y = 1, z = 0})
    elseif action == 'saveMap' then
        TriggerServerEvent(CONSTANTS.EVENTS.CLIENT_SAVE_MAP, data.mapName or 'default', {})
    elseif action == 'loadMap' then
        TriggerServerEvent(CONSTANTS.EVENTS.CLIENT_LOAD_MAP, data.mapName or 'default')
    elseif action == 'undo' then
        if History.canUndo() then
            History.undo()
        end
    elseif action == 'redo' then
        if History.canRedo() then
            History.redo()
        end
    elseif action == 'updateObjectProperty' then
        local objectID = data.objectID
        local object = EntityManager.getObject(objectID)
        if object then
            if data.property:startsWith('prop-') then
                local prop = data.property:sub(6)
                object[prop] = data.value
                EntityManager.updateTransform(objectID, object.x, object.y, object.z, object.rx, object.ry, object.rz)
            end
        end
    end
end

return UI
