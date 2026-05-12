--- FORGE: Client Editor State
--- Manages editor modes, settings, and global state

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local EditorState = {
    --- Editor operational state
    isOpen = false,
    mode = CONSTANTS.UI_MODES.CLOSED,
    currentMap = nil,
    sessionID = UTILS.generateUUID(),
    
    --- Camera state
    camera = {
        x = 0, y = 0, z = 0,
        rx = 0, ry = 0, rz = 0,
        fov = 50.0,
        distance = 50.0,
    },
    
    --- Grid and snapping
    gridEnabled = true,
    gridSize = CONSTANTS.OBJECT.GRID_SNAP,
    angleSnapEnabled = true,
    angleSnapValue = CONSTANTS.OBJECT.ANGLE_SNAP,
    
    --- Transform space
    transformSpace = CONSTANTS.TRANSFORM.WORLD_SPACE,
    transformMode = nil, -- 'move', 'rotate', 'scale'
    constrainAxis = nil, -- 1=X, 2=Y, 3=Z, nil=free
    
    --- Selection state
    selection = {},
    lastSelected = nil,
    selectionCount = 0,
    
    --- UI state
    uiScale = 1.0,
    showHierarchy = true,
    showInspector = true,
    showAssetBrowser = true,
    showHistory = true,
    
    --- Performance monitoring
    performance = {
        fps = 0,
        resmon = 0.0,
        objectCount = 0,
    },
}

--- Toggle editor open/closed
function EditorState.toggleEditor()
    EditorState.isOpen = not EditorState.isOpen
    EditorState.mode = EditorState.isOpen and CONSTANTS.UI_MODES.EDITOR or CONSTANTS.UI_MODES.CLOSED
    
    print('^2[Forge]^7 Editor ' .. (EditorState.isOpen and 'opened' or 'closed') .. '^0')
    
    if EditorState.isOpen then
        TriggerEvent('forge:editorOpened')
    else
        TriggerEvent('forge:editorClosed')
    end
end

--- Set editor mode
---@param newMode number UI mode constant
function EditorState.setMode(newMode)
    EditorState.mode = newMode
    TriggerEvent('forge:modeChanged', newMode)
end

--- Get is editor open
---@return boolean
function EditorState.getIsOpen()
    return EditorState.isOpen
end

--- Set transform mode
---@param mode string 'move', 'rotate', 'scale', or nil
function EditorState.setTransformMode(mode)
    EditorState.transformMode = mode
    TriggerEvent('forge:transformModeChanged', mode)
end

--- Set axis constraint
---@param axis number 1=X, 2=Y, 3=Z, nil=free
function EditorState.setAxisConstraint(axis)
    EditorState.constrainAxis = axis
end

--- Toggle grid snapping
function EditorState.toggleGridSnap()
    EditorState.gridEnabled = not EditorState.gridEnabled
    return EditorState.gridEnabled
end

--- Toggle angle snapping
function EditorState.toggleAngleSnap()
    EditorState.angleSnapEnabled = not EditorState.angleSnapEnabled
    return EditorState.angleSnapEnabled
end

--- Toggle transform space
function EditorState.toggleTransformSpace()
    EditorState.transformSpace = EditorState.transformSpace == CONSTANTS.TRANSFORM.WORLD_SPACE and
                                  CONSTANTS.TRANSFORM.LOCAL_SPACE or CONSTANTS.TRANSFORM.WORLD_SPACE
    return EditorState.transformSpace
end

--- Set camera position
---@param x number
---@param y number
---@param z number
function EditorState.setCameraPos(x, y, z)
    EditorState.camera.x = x
    EditorState.camera.y = y
    EditorState.camera.z = z
end

--- Set camera rotation
---@param rx number
---@param ry number
---@param rz number
function EditorState.setCameraRot(rx, ry, rz)
    EditorState.camera.rx = rx
    EditorState.camera.ry = ry
    EditorState.camera.rz = rz
end

--- Add object to selection
---@param objectID string Object UUID
function EditorState.selectObject(objectID)
    EditorState.selection[objectID] = true
    EditorState.lastSelected = objectID
    EditorState.selectionCount = EditorState.selectionCount + 1
    TriggerEvent('forge:objectSelected', objectID)
end

--- Remove object from selection
---@param objectID string Object UUID
function EditorState.deselectObject(objectID)
    EditorState.selection[objectID] = nil
    if EditorState.lastSelected == objectID then
        EditorState.lastSelected = nil
    end
    EditorState.selectionCount = EditorState.selectionCount - 1
    TriggerEvent('forge:objectDeselected', objectID)
end

--- Clear all selection
function EditorState.clearSelection()
    EditorState.selection = {}
    EditorState.lastSelected = nil
    EditorState.selectionCount = 0
    TriggerEvent('forge:selectionCleared')
end

--- Check if object is selected
---@param objectID string Object UUID
---@return boolean
function EditorState.isObjectSelected(objectID)
    return EditorState.selection[objectID] or false
end

--- Get selected objects
---@return table Array of object IDs
function EditorState.getSelectedObjects()
    local selected = {}
    for objectID in pairs(EditorState.selection) do
        selected[#selected + 1] = objectID
    end
    return selected
end

--- Multi-select objects
---@param objectIDs table Array of object IDs
---@param additive boolean If true, add to existing selection
function EditorState.selectMultiple(objectIDs, additive)
    if not additive then
        EditorState.clearSelection()
    end
    
    for i = 1, #objectIDs do
        EditorState.selectObject(objectIDs[i])
    end
end

--- Get last selected object
---@return string|nil
function EditorState.getLastSelected()
    return EditorState.lastSelected
end

--- Set current map
---@param mapName string
function EditorState.setCurrentMap(mapName)
    EditorState.currentMap = mapName
    TriggerEvent('forge:mapChanged', mapName)
end

--- Get current map
---@return string|nil
function EditorState.getCurrentMap()
    return EditorState.currentMap
end

--- Update performance metrics
---@param fps number
---@param resmon number
---@param objectCount number
function EditorState.updatePerformance(fps, resmon, objectCount)
    EditorState.performance.fps = fps
    EditorState.performance.resmon = resmon
    EditorState.performance.objectCount = objectCount
end

--- Get performance data
---@return table
function EditorState.getPerformance()
    return EditorState.performance
end

--- Set UI scale
---@param scale number
function EditorState.setUIScale(scale)
    EditorState.uiScale = UTILS.clamp(scale, 0.5, 2.0)
end

--- Toggle UI panel
---@param panelName string 'hierarchy', 'inspector', 'assetbrowser', 'history'
function EditorState.toggleUIPanel(panelName)
    if panelName == 'hierarchy' then
        EditorState.showHierarchy = not EditorState.showHierarchy
    elseif panelName == 'inspector' then
        EditorState.showInspector = not EditorState.showInspector
    elseif panelName == 'assetbrowser' then
        EditorState.showAssetBrowser = not EditorState.showAssetBrowser
    elseif panelName == 'history' then
        EditorState.showHistory = not EditorState.showHistory
    end
    
    TriggerEvent('forge:uiPanelToggled', panelName, EditorState['show' .. panelName:gsub('^%l', string.upper)])
end

return EditorState
