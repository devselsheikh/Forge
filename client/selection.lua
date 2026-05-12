--- FORGE: Client Selection System
--- Multiselect, drag select, radius select, group operations

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Selection = {
    _selected = {},
    _selectionMode = 'single', -- 'single', 'multi', 'dragBox', 'radius'
    _dragStart = nil,
    _selectionBox = nil,
}

--- Set selection mode
---@param mode string 'single', 'multi', 'dragBox', 'radius'
function Selection.setSelectionMode(mode)
    Selection._selectionMode = mode
end

--- Get selection mode
---@return string
function Selection.getSelectionMode()
    return Selection._selectionMode
end

--- Raycast to find object under cursor
---@param screenX number Screen X coordinate (0-1)
---@param screenY number Screen Y coordinate (0-1)
---@return table|nil Object data or nil
function Selection.raycastObject(screenX, screenY)
    -- Raycast from camera through screen coordinate
    local camCoords = GetGameplayCamCoord()
    local camDir = GetGameplayCamRot(2)
    
    -- Simple raycast using GetShapeTestResult
    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z,
                                        camCoords.x + 1000 * math.cos(camDir.z),
                                        camCoords.y + 1000 * math.sin(camDir.z),
                                        camCoords.z, 10, PlayerPedId(), 7)
    
    local hit, entityHit = GetShapeTestResult(rayHandle)
    
    if hit == 1 and DoesEntityExist(entityHit) then
        -- Try to get object from entity handle
        local EntityManager = require 'client.entity_manager'
        return EntityManager.getObjectByEntity(entityHit)
    end
    
    return nil
end

--- Select single object
---@param objectID string Object UUID
function Selection.selectSingle(objectID)
    Selection._selected = {}
    Selection._selected[objectID] = true
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Toggle object selection
---@param objectID string Object UUID
function Selection.toggleSelect(objectID)
    if Selection._selected[objectID] then
        Selection._selected[objectID] = nil
    else
        Selection._selected[objectID] = true
    end
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Add object to selection
---@param objectID string Object UUID
function Selection.addToSelection(objectID)
    Selection._selected[objectID] = true
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Remove object from selection
---@param objectID string Object UUID
function Selection.removeFromSelection(objectID)
    Selection._selected[objectID] = nil
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Select multiple objects
---@param objectIDs table Array of object IDs
---@param additive boolean If true, add to selection instead of replacing
function Selection.selectMultiple(objectIDs, additive)
    if not additive then
        Selection._selected = {}
    end
    
    for i = 1, #objectIDs do
        Selection._selected[objectIDs[i]] = true
    end
    
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Clear selection
function Selection.clear()
    Selection._selected = {}
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Get selected objects
---@return table Array of object IDs
function Selection.getSelectedObjects()
    local objects = {}
    for objectID in pairs(Selection._selected) do
        objects[#objects + 1] = objectID
    end
    return objects
end

--- Get selection count
---@return number
function Selection.getSelectionCount()
    local count = 0
    for _ in pairs(Selection._selected) do
        count = count + 1
    end
    return count
end

--- Check if object is selected
---@param objectID string Object UUID
---@return boolean
function Selection.isSelected(objectID)
    return Selection._selected[objectID] or false
end

--- Start drag selection box
---@param startX number World X
---@param startY number World Y
---@param startZ number World Z
function Selection.startDragBox(startX, startY, startZ)
    Selection._dragStart = {
        x = startX,
        y = startY,
        z = startZ,
        time = GetGameTimer(),
    }
    Selection._selectionBox = {
        x1 = startX, y1 = startY,
        x2 = startX, y2 = startY,
    }
end

--- Update drag selection box
---@param endX number World X
---@param endY number World Y
function Selection.updateDragBox(endX, endY)
    if Selection._dragStart then
        Selection._selectionBox.x1 = math.min(Selection._dragStart.x, endX)
        Selection._selectionBox.y1 = math.min(Selection._dragStart.y, endY)
        Selection._selectionBox.x2 = math.max(Selection._dragStart.x, endX)
        Selection._selectionBox.y2 = math.max(Selection._dragStart.y, endY)
    end
end

--- End drag selection and select objects in box
---@param EntityManager table Entity manager instance
function Selection.endDragBox(EntityManager)
    if not Selection._dragStart or not Selection._selectionBox then
        return
    end
    
    local box = Selection._selectionBox
    local selected = {}
    
    local allObjects = EntityManager.getAllObjects()
    for objectID, objData in pairs(allObjects) do
        if objData.x >= box.x1 and objData.x <= box.x2 and
           objData.y >= box.y1 and objData.y <= box.y2 then
            selected[objectID] = true
        end
    end
    
    Selection._selected = selected
    Selection._dragStart = nil
    Selection._selectionBox = nil
    
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Select objects in radius
---@param cx number Center X
---@param cy number Center Y
---@param radius number Radius
---@param EntityManager table Entity manager instance
---@param additive boolean If true, add to selection
function Selection.selectRadius(cx, cy, radius, EntityManager, additive)
    if not additive then
        Selection._selected = {}
    end
    
    local radiusSq = radius * radius
    local allObjects = EntityManager.getAllObjects()
    
    for objectID, objData in pairs(allObjects) do
        local dx = objData.x - cx
        local dy = objData.y - cy
        local distSq = dx * dx + dy * dy
        
        if distSq <= radiusSq then
            Selection._selected[objectID] = true
        end
    end
    
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Select all objects in layer
---@param layerName string Layer identifier
---@param EntityManager table Entity manager instance
function Selection.selectLayer(layerName, EntityManager)
    Selection._selected = {}
    
    local allObjects = EntityManager.getAllObjects()
    for objectID, objData in pairs(allObjects) do
        if objData.layer == layerName then
            Selection._selected[objectID] = true
        end
    end
    
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Invert selection
---@param EntityManager table Entity manager instance
function Selection.invertSelection(EntityManager)
    local allObjects = EntityManager.getAllObjects()
    local inverted = {}
    
    for objectID in pairs(allObjects) do
        if not Selection._selected[objectID] then
            inverted[objectID] = true
        end
    end
    
    Selection._selected = inverted
    TriggerEvent('forge:selectionChanged', Selection._selected)
end

--- Group selected objects (create parent)
---@param groupName string Group name
---@return string Group ID
function Selection.groupSelected(groupName)
    local groupID = UTILS.generateUUID()
    local selectedObjects = Selection.getSelectedObjects()
    
    for i = 1, #selectedObjects do
        -- Mark objects as belonging to group
        TriggerEvent('forge:objectGrouped', selectedObjects[i], groupID)
    end
    
    return groupID
end

--- Duplicate selected objects
---@param EntityManager table Entity manager instance
---@param offset table {x, y, z} Offset for duplicates
---@return table Array of new object IDs
function Selection.duplicateSelected(EntityManager, offset)
    offset = offset or {x = 1, y = 1, z = 0}
    
    local selectedObjects = Selection.getSelectedObjects()
    local newObjects = {}
    
    for i = 1, #selectedObjects do
        local objData = EntityManager.getObject(selectedObjects[i])
        if objData then
            local newObjData = UTILS.deepCopy(objData)
            newObjData.id = UTILS.generateUUID()
            newObjData.x = newObjData.x + offset.x
            newObjData.y = newObjData.y + offset.y
            newObjData.z = newObjData.z + offset.z
            
            newObjects[#newObjects + 1] = newObjData.id
            
            -- Request server to create
            TriggerServerEvent('forge:client:placeObject', newObjData)
        end
    end
    
    return newObjects
end

return Selection
