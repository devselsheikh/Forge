--- FORGE: Client Input Handler
--- Keyboard, mouse, and hotkey management

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local InputHandler = {
    _hotkeys = {},
    _keyBindings = {},
    _mouseState = {
        x = 0, y = 0,
        leftPressed = false,
        rightPressed = false,
        middlePressed = false,
    },
}

--- Initialize default hotkeys
function InputHandler.initHotkeys()
    InputHandler._hotkeys = {
        toggleEditor = { key = CONFIG.HOTKEYS.TOGGLE_EDITOR, callback = nil },
        moveMode = { key = CONFIG.HOTKEYS.MOVE_MODE, callback = nil },
        rotateMode = { key = CONFIG.HOTKEYS.ROTATE_MODE, callback = nil },
        scaleMode = { key = CONFIG.HOTKEYS.SCALE_MODE, callback = nil },
        delete = { key = CONFIG.HOTKEYS.DELETE, callback = nil },
        duplicate = { key = CONFIG.HOTKEYS.DUPLICATE, callback = nil },
        undo = { key = CONFIG.HOTKEYS.UNDO, callback = nil },
        redo = { key = CONFIG.HOTKEYS.REDO, callback = nil },
        save = { key = CONFIG.HOTKEYS.SAVE, callback = nil },
        snapGrid = { key = CONFIG.HOTKEYS.SNAP_GRID, callback = nil },
        snapAngle = { key = CONFIG.HOTKEYS.SNAP_ANGLE, callback = nil },
    }
end

--- Register a hotkey
---@param name string Hotkey name
---@param key string Key name (e.g., 'F5', 'CTRL+S')
---@param callback function Function to call when pressed
function InputHandler.registerHotkey(name, key, callback)
    InputHandler._hotkeys[name] = {
        key = key,
        callback = callback,
    }
end

--- Get hotkey info
---@param name string Hotkey name
---@return table|nil
function InputHandler.getHotkey(name)
    return InputHandler._hotkeys[name]
end

--- Check if key is pressed
---@param keyName string
---@return boolean
function InputHandler.isKeyPressed(keyName)
    if keyName:find('CTRL') then
        return IsControlPressed(0, GetHashKey(keyName))
    end
    return IsKeyPressed(GetHashKey(keyName))
end

--- Check if key is just released
---@param keyName string
---@return boolean
function InputHandler.isKeyJustReleased(keyName)
    return IsKeyJustReleased(GetHashKey(keyName))
end

--- Get mouse position (0-1 normalized)
---@return number, number
function InputHandler.getMousePosition()
    return GetNuiFocus()
end

--- Set mouse focus
---@param hasFocus boolean
function InputHandler.setMouseFocus(hasFocus)
    SetNuiFocus(hasFocus, hasFocus)
end

--- Get keyboard input
---@return string|nil Character or key name
function InputHandler.getKeyboardInput()
    local keyFound, key = GetCurrentKeyPressed()
    if keyFound then
        return string.char(key)
    end
    return nil
end

--- Process editor hotkeys
---@param EditorState table Editor state module
---@param History table History module
---@param Selection table Selection module
function InputHandler.processEditorHotkeys(EditorState, History, Selection)
    if not EditorState.isOpen then
        -- Check toggle hotkey
        if InputHandler.isKeyPressed('F5') then
            EditorState.toggleEditor()
        end
        return
    end
    
    -- Hotkeys only active when editor is open
    
    -- Transform modes
    if InputHandler.isKeyPressed('M') then
        EditorState.setTransformMode('move')
    elseif InputHandler.isKeyPressed('R') then
        EditorState.setTransformMode('rotate')
    elseif InputHandler.isKeyPressed('S') then
        EditorState.setTransformMode('scale')
    end
    
    -- Delete
    if InputHandler.isKeyJustReleased('DELETE') then
        local selected = Selection.getSelectedObjects()
        for i = 1, #selected do
            TriggerServerEvent(CONSTANTS.EVENTS.CLIENT_DELETE_OBJECT, selected[i])
            History.recordObjectDeleted(selected[i], {})
        end
        Selection.clear()
    end
    
    -- Duplicate
    if InputHandler.isKeyPressed('D') and InputHandler.isKeyPressed('CTRL') then
        local duplicated = Selection.duplicateSelected(require 'client.entity_manager')
        TriggerEvent('forge:objectsDuplicated', duplicated)
    end
    
    -- Undo
    if InputHandler.isKeyPressed('Z') and InputHandler.isKeyPressed('CTRL') then
        if History.canUndo() then
            local entry = History.undo()
            -- Apply undo logic
        end
    end
    
    -- Redo
    if InputHandler.isKeyPressed('Y') and InputHandler.isKeyPressed('CTRL') then
        if History.canRedo() then
            local entry = History.redo()
            -- Apply redo logic
        end
    end
    
    -- Save
    if InputHandler.isKeyPressed('S') and InputHandler.isKeyPressed('CTRL') then
        TriggerEvent('forge:requestSaveMap')
    end
    
    -- Toggle snap grid
    if InputHandler.isKeyPressed('G') then
        EditorState.toggleGridSnap()
    end
    
    -- Toggle angle snap
    if InputHandler.isKeyPressed('A') then
        EditorState.toggleAngleSnap()
    end
end

--- Process mouse input for object selection
---@param Selection table Selection module
---@param EntityManager table Entity manager module
function InputHandler.processMouseInput(Selection, EntityManager)
    if not GetNuiFocus() then
        local screenX, screenY = GetNuiCursorPosition()
        screenX = screenX / GetScreenResolutionKeepingRatio()
        screenY = screenY / GetScreenResolutionKeepingRatio()
        
        if IsMouseButtonDown(0) then -- Left click
            if not InputHandler._mouseState.leftPressed then
                InputHandler._mouseState.leftPressed = true
                
                -- Raycast for object selection
                local selectedObject = Selection.raycastObject(screenX, screenY)
                if selectedObject then
                    if InputHandler.isKeyPressed('LSHIFT') then
                        Selection.addToSelection(selectedObject.id)
                    else
                        Selection.selectSingle(selectedObject.id)
                    end
                else
                    -- Deselect all if clicked empty space
                    if not InputHandler.isKeyPressed('LSHIFT') then
                        Selection.clear()
                    end
                end
            end
        else
            InputHandler._mouseState.leftPressed = false
        end
        
        if IsMouseButtonDown(1) then -- Right click
            InputHandler._mouseState.rightPressed = true
        else
            InputHandler._mouseState.rightPressed = false
        end
    end
end

--- Get key name from code
---@param keyCode number
---@return string
function InputHandler.getKeyName(keyCode)
    local keyNames = {
        [0] = 'BACK',
        [1] = 'TAB',
        [13] = 'RETURN',
        [16] = 'SHIFT',
        [17] = 'CTRL',
        [18] = 'ALT',
        [19] = 'PAUSE',
        [20] = 'CAPS',
        [27] = 'ESC',
        [32] = 'SPACE',
        [45] = 'INSERT',
        [46] = 'DELETE',
        [112] = 'F1',
        [113] = 'F2',
        [114] = 'F3',
        [115] = 'F4',
        [116] = 'F5',
        [117] = 'F6',
    }
    
    return keyNames[keyCode] or string.char(keyCode)
end

--- Convert key string to code
---@param keyName string
---@return number
function InputHandler.getKeyCode(keyName)
    local keyCodes = {
        ['BACK'] = 0,
        ['TAB'] = 1,
        ['RETURN'] = 13,
        ['SHIFT'] = 16,
        ['CTRL'] = 17,
        ['ALT'] = 18,
        ['ESC'] = 27,
        ['SPACE'] = 32,
        ['DELETE'] = 46,
        ['F1'] = 112,
        ['F5'] = 116,
    }
    
    return keyCodes[keyName] or string.byte(keyName)
end

return InputHandler
