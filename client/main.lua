--- FORGE: Client Main Entry Point
--- Orchestrates all client systems

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared/config'
local UTILS = require 'shared/utils'

local EditorState = require 'client/editor_state'
local EntityManager = require 'client/entity_manager'
local History = require 'client/history'
local Selection = require 'client/selection'
local Streaming = require 'client/streaming'
local TransformTools = require 'client/transform_tools'
local InputHandler = require 'client/input_handler'
local UI = require 'client/ui'

--- Global state
local isRunning = true
local lastFpsTime = GetGameTimer()
local fpsCounter = 0
local lastResmonTime = 0

--- Initialize all systems
local function init()
    print('^2[Forge]^7 Initializing client systems...')
    
    UI.init()
    Streaming.init()
    InputHandler.initHotkeys()
    
    print('^2[Forge]^7 Client initialized successfully')
end

--- Main game loop
local function mainLoop()
    while isRunning do
        -- Update streaming
        Streaming.mainLoop()
        
        -- Process input
        if EditorState.isOpen then
            InputHandler.processEditorHotkeys(EditorState, History, Selection)
            InputHandler.processMouseInput(Selection, EntityManager)
        else
            -- Check only for toggle hotkey
            if InputHandler.isKeyJustReleased('F5') then
                EditorState.toggleEditor()
                if EditorState.isOpen then
                    UI.setNuiFocus(true)
                    UI.updateEditorState(EditorState)
                else
                    UI.setNuiFocus(false)
                end
            end
        end
        
        -- Update performance monitoring
        local now = GetGameTimer()
        fpsCounter = fpsCounter + 1
        
        if (now - lastFpsTime) >= 1000 then
            local fps = fpsCounter
            fpsCounter = 0
            lastFpsTime = now
            
            local resmon = 0.0
            local objectCount = EntityManager.getObjectCount()
            
            UI.updatePerformance(fps, resmon, objectCount)
            EditorState.updatePerformance(fps, resmon, objectCount)
        end
        
        Wait(0)
    end
end

--- Event: Editor opened
AddEventHandler('forge:editorOpened', function()
    EditorState.isOpen = true
    UI.setNuiFocus(true)
    UI.updateEditorState(EditorState)
    UI.showNotification('Editor', 'World editor opened', 'success', 2000)
end)

--- Event: Editor closed
AddEventHandler('forge:editorClosed', function()
    EditorState.isOpen = false
    UI.setNuiFocus(false)
    EditorState.clearSelection()
    UI.showNotification('Editor', 'World editor closed', 'info', 1500)
end)

--- Event: Object selected
AddEventHandler('forge:objectSelected', function(objectID)
    local objectData = EntityManager.getObject(objectID)
    if objectData then
        EditorState.selectObject(objectID)
        UI.updateSelectedObject(objectID, objectData)
        UI.updateInspectorProperties(objectData)
    end
end)

--- Event: Object deselected
AddEventHandler('forge:objectDeselected', function(objectID)
    EditorState.deselectObject(objectID)
end)

--- Event: Selection cleared
AddEventHandler('forge:selectionCleared', function()
    EditorState.clearSelection()
end)

--- Event: Server created object
RegisterNetEvent(CONSTANTS.EVENTS.SERVER_OBJECT_CREATED, function(objectData)
    if objectData then
        EntityManager.createEntity(objectData)
        UI.notifyObjectCreated(objectData)
        History.recordObjectCreated(objectData.id, objectData)
    end
end)

--- Event: Server updated object
RegisterNetEvent(CONSTANTS.EVENTS.SERVER_OBJECT_UPDATED, function(objectData)
    if objectData then
        EntityManager.updateTransform(
            objectData.id,
            objectData.x, objectData.y, objectData.z,
            objectData.rx, objectData.ry, objectData.rz
        )
        EntityManager.updateScale(objectData.id, objectData.sx, objectData.sy, objectData.sz)
        EntityManager.markSynced(objectData.id)
    end
end)

--- Event: Server deleted object
RegisterNetEvent(CONSTANTS.EVENTS.SERVER_OBJECT_DELETED, function(objectID)
    if objectID then
        EntityManager.deleteEntity(objectID)
        UI.notifyObjectDeleted(objectID)
        History.recordObjectDeleted(objectID, {})
    end
end)

--- Event: Server error
RegisterNetEvent(CONSTANTS.EVENTS.SERVER_ERROR, function(errorMessage)
    print('^1[Forge Error]^7 ' .. errorMessage .. '^0')
    UI.showNotification('Error', errorMessage, 'error', 3000)
end)

--- Event: Chunk loaded from server
RegisterNetEvent(CONSTANTS.EVENTS.SERVER_CHUNK_LOADED, function(chunkData)
    if chunkData and chunkData.objects then
        Streaming.markChunkLoaded(chunkData.chunkID, chunkData.objects)
        
        -- Create entities for all objects in chunk
        for i = 1, #chunkData.objects do
            local objectData = chunkData.objects[i]
            EntityManager.createEntity(objectData)
        end
    end
end)

--- Event: Map loaded from server
RegisterNetEvent('forge:mapLoaded', function(mapData)
    if mapData then
        EntityManager.clearAll()
        
        -- Create entities for all objects
        for i = 1, #mapData.objects do
            local objectData = mapData.objects[i]
            EntityManager.createEntity(objectData)
        end
        
        EditorState.setCurrentMap(mapData.mapName)
        UI.showNotification('Map', 'Loaded: ' .. mapData.mapName, 'success', 2000)
        UI.setStatusMessage('Map loaded: ' .. mapData.mapName)
    end
end)

--- Event: Map saved
RegisterNetEvent('forge:mapSaved', function(saveData)
    if saveData then
        EditorState.setCurrentMap(saveData.mapName)
        UI.showNotification('Map', 'Saved: ' .. saveData.mapName .. ' (' .. saveData.objectCount .. ' objects)', 'success', 2000)
        UI.setStatusMessage('Map saved')
    end
end)

--- Event: Collaborator joined
RegisterNetEvent('forge:collaboratorJoined', function(collabData)
    if collabData then
        UI.notifyCollaboratorJoined(collabData.playerID, collabData.playerName, collabData.sessionID)
        UI.showNotification('Collaborator', collabData.playerName .. ' joined', 'info', 2000)
    end
end)

--- Event: Collaborator left
RegisterNetEvent('forge:collaboratorLeft', function(collabData)
    if collabData then
        UI.notifyCollaboratorLeft(collabData.playerID)
        UI.showNotification('Collaborator', 'Player left', 'info', 1500)
    end
end)

--- Export: Check if editor is open
exports('isEditorOpen', function()
    return EditorState.isOpen
end)

--- Export: Get selected objects
exports('getSelectedObjects', function()
    return EditorState.getSelectedObjects()
end)

--- Export: Get object data
exports('getObjectData', function(objectID)
    return EntityManager.getObject(objectID)
end)

--- Resource lifecycle
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    init()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    isRunning = false
    EntityManager.clearAll()
    print('^2[Forge]^7 Client resource stopped')
end)

--- Start main loop
mainLoop()

print('^2[Forge]^7 Client resource loaded successfully')
print('^2[Forge]^7 Press F5 to open the editor')
