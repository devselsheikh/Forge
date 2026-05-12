--- FORGE: Client Transform Tools
--- Move, rotate, scale with gizmo and snap modes

local CONSTANTS = require 'shared/constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local TransformTools = {
    _transformMode = nil,
    _axisConstraint = nil,
    _startPos = nil,
    _startRot = nil,
    _startScale = nil,
    _dragDelta = nil,
    _gizmoVisible = false,
    _transformSpace = CONSTANTS.TRANSFORM.WORLD_SPACE,
}

--- Apply grid snapping
---@param value number
---@param gridSize number
---@return number
function TransformTools.snapToGrid(value, gridSize)
    if gridSize == 0 then return value end
    return math.floor(value / gridSize + 0.5) * gridSize
end

--- Apply angle snapping
---@param angle number Degrees
---@param snapValue number Snap value in degrees
---@return number
function TransformTools.snapAngle(angle, snapValue)
    if snapValue == 0 then return angle end
    local snapped = math.floor(angle / snapValue + 0.5) * snapValue
    -- Normalize to 0-360
    return ((snapped % 360) + 360) % 360
end

--- Normalize angle to 0-360
---@param angle number
---@return number
function TransformTools.normalizeAngle(angle)
    return ((angle % 360) + 360) % 360
end

--- Start move operation
---@param objectData table Current object data
---@param startWorldPos vector3 Start world position
function TransformTools.startMove(objectData, startWorldPos)
    TransformTools._transformMode = 'move'
    TransformTools._startPos = vector3(objectData.x, objectData.y, objectData.z)
    TransformTools._dragDelta = vector3(0, 0, 0)
end

--- Update move operation
---@param objectData table Object being moved
---@param currentWorldPos vector3 Current world position
---@param constrainAxis number|nil 1=X, 2=Y, 3=Z, nil=free
---@return table Updated position {x, y, z}
function TransformTools.updateMove(objectData, currentWorldPos, constrainAxis)
    local delta = currentWorldPos - TransformTools._startPos
    
    -- Apply axis constraint
    if constrainAxis == CONSTANTS.AXIS.X then
        delta = vector3(delta.x, 0, 0)
    elseif constrainAxis == CONSTANTS.AXIS.Y then
        delta = vector3(0, delta.y, 0)
    elseif constrainAxis == CONSTANTS.AXIS.Z then
        delta = vector3(0, 0, delta.z)
    end
    
    local newX = TransformTools._startPos.x + delta.x
    local newY = TransformTools._startPos.y + delta.y
    local newZ = TransformTools._startPos.z + delta.z
    
    -- Apply grid snapping
    if CONFIG.PERFORMANCE.ENABLE_STREAMING then  -- Using as placeholder for grid config
        newX = TransformTools.snapToGrid(newX, CONFIG.STREAMING.CHUNK_SIZE / 100)
        newY = TransformTools.snapToGrid(newY, CONFIG.STREAMING.CHUNK_SIZE / 100)
        newZ = TransformTools.snapToGrid(newZ, 0.25)
    end
    
    return {x = newX, y = newY, z = newZ}
end

--- End move operation
function TransformTools.endMove()
    TransformTools._transformMode = nil
    TransformTools._startPos = nil
    TransformTools._dragDelta = nil
end

--- Start rotate operation
---@param objectData table Current object data
---@param startInput table Initial mouse/input position
function TransformTools.startRotate(objectData, startInput)
    TransformTools._transformMode = 'rotate'
    TransformTools._startRot = {
        x = UTILS.toRadians(objectData.rx),
        y = UTILS.toRadians(objectData.ry),
        z = UTILS.toRadians(objectData.rz),
    }
    TransformTools._dragDelta = startInput or {x = 0, y = 0}
end

--- Update rotate operation
---@param objectData table Object being rotated
---@param currentInput table Current mouse/input position
---@param constrainAxis number|nil 1=X, 2=Y, 3=Z, nil=free
---@return table Updated rotation {x, y, z}
function TransformTools.updateRotate(objectData, currentInput, constrainAxis)
    local deltaX = (currentInput.x - TransformTools._dragDelta.x) * 0.5
    local deltaY = (currentInput.y - TransformTools._dragDelta.y) * 0.5
    
    local newRx = UTILS.toDegrees(TransformTools._startRot.x) + deltaY
    local newRy = UTILS.toDegrees(TransformTools._startRot.y) + deltaX
    local newRz = UTILS.toDegrees(TransformTools._startRot.z)
    
    -- Apply axis constraint
    if constrainAxis == CONSTANTS.AXIS.X then
        newRy = UTILS.toDegrees(TransformTools._startRot.y)
        newRz = UTILS.toDegrees(TransformTools._startRot.z)
    elseif constrainAxis == CONSTANTS.AXIS.Y then
        newRx = UTILS.toDegrees(TransformTools._startRot.x)
        newRz = UTILS.toDegrees(TransformTools._startRot.z)
    elseif constrainAxis == CONSTANTS.AXIS.Z then
        newRx = UTILS.toDegrees(TransformTools._startRot.x)
        newRy = UTILS.toDegrees(TransformTools._startRot.y)
    end
    
    -- Apply angle snapping
    newRx = TransformTools.snapAngle(newRx, CONFIG.PERFORMANCE.HISTORY_MAX_ENTRIES)
    newRy = TransformTools.snapAngle(newRy, CONFIG.PERFORMANCE.HISTORY_MAX_ENTRIES)
    newRz = TransformTools.snapAngle(newRz, CONFIG.PERFORMANCE.HISTORY_MAX_ENTRIES)
    
    return {
        x = TransformTools.normalizeAngle(newRx),
        y = TransformTools.normalizeAngle(newRy),
        z = TransformTools.normalizeAngle(newRz),
    }
end

--- End rotate operation
function TransformTools.endRotate()
    TransformTools._transformMode = nil
    TransformTools._startRot = nil
end

--- Start scale operation
---@param objectData table Current object data
---@param startValue number Initial scale value (usually 1.0)
function TransformTools.startScale(objectData, startValue)
    TransformTools._transformMode = 'scale'
    TransformTools._startScale = {
        x = objectData.sx or 1,
        y = objectData.sy or 1,
        z = objectData.sz or 1,
        baseValue = startValue or 1.0,
    }
    TransformTools._dragDelta = 0
end

--- Update scale operation
---@param objectData table Object being scaled
---@param scaleFactor number Scale multiplier
---@param constrainAxis number|nil 1=X, 2=Y, 3=Z, nil=free
---@return table Updated scale {x, y, z}
function TransformTools.updateScale(objectData, scaleFactor, constrainAxis)
    local newSx = TransformTools._startScale.x * scaleFactor
    local newSy = TransformTools._startScale.y * scaleFactor
    local newSz = TransformTools._startScale.z * scaleFactor
    
    -- Apply axis constraint
    if constrainAxis == CONSTANTS.AXIS.X then
        newSy = TransformTools._startScale.y
        newSz = TransformTools._startScale.z
    elseif constrainAxis == CONSTANTS.AXIS.Y then
        newSx = TransformTools._startScale.x
        newSz = TransformTools._startScale.z
    elseif constrainAxis == CONSTANTS.AXIS.Z then
        newSx = TransformTools._startScale.x
        newSy = TransformTools._startScale.y
    end
    
    -- Clamp to valid range
    newSx = UTILS.clamp(newSx, CONSTANTS.OBJECT.MIN_SCALE, CONSTANTS.OBJECT.MAX_SCALE)
    newSy = UTILS.clamp(newSy, CONSTANTS.OBJECT.MIN_SCALE, CONSTANTS.OBJECT.MAX_SCALE)
    newSz = UTILS.clamp(newSz, CONSTANTS.OBJECT.MIN_SCALE, CONSTANTS.OBJECT.MAX_SCALE)
    
    return {x = newSx, y = newSy, z = newSz}
end

--- End scale operation
function TransformTools.endScale()
    TransformTools._transformMode = nil
    TransformTools._startScale = nil
end

--- Get current transform mode
---@return string|nil
function TransformTools.getMode()
    return TransformTools._transformMode
end

--- Check if transforming
---@return boolean
function TransformTools.isTransforming()
    return TransformTools._transformMode ~= nil
end

--- Set gizmo visibility
---@param visible boolean
function TransformTools.setGizmoVisible(visible)
    TransformTools._gizmoVisible = visible
end

--- Get gizmo visibility
---@return boolean
function TransformTools.getGizmoVisible()
    return TransformTools._gizmoVisible
end

--- Set transform space
---@param space number WORLD_SPACE or LOCAL_SPACE
function TransformTools.setTransformSpace(space)
    TransformTools._transformSpace = space
end

--- Get transform space
---@return number
function TransformTools.getTransformSpace()
    return TransformTools._transformSpace
end

--- Align to surface (raycasting)
---@param x number
---@param y number
---@param z number
---@return number Z coordinate on ground
function TransformTools.alignToSurface(x, y, z)
    local rayHandle = StartShapeTestRay(x, y, z + 10, x, y, z - 100, 1, PlayerPedId(), 1)
    local hit, _, hitPos = GetShapeTestResult(rayHandle)
    
    if hit then
        return hitPos.z
    end
    
    return z
end

--- Mirror objects
---@param objectList table Array of object data
---@param mirrorAxis number 1=X, 2=Y, 3=Z
---@param origin number Mirror plane origin coordinate
---@return table Mirrored objects
function TransformTools.mirrorObjects(objectList, mirrorAxis, origin)
    local mirrored = {}
    
    for i = 1, #objectList do
        local obj = UTILS.deepCopy(objectList[i])
        
        if mirrorAxis == CONSTANTS.AXIS.X then
            obj.x = 2 * origin - obj.x
            obj.ry = TransformTools.normalizeAngle(180 - obj.ry)
        elseif mirrorAxis == CONSTANTS.AXIS.Y then
            obj.y = 2 * origin - obj.y
            obj.rx = TransformTools.normalizeAngle(180 - obj.rx)
        elseif mirrorAxis == CONSTANTS.AXIS.Z then
            -- Z-axis mirror (less common)
            obj.rz = TransformTools.normalizeAngle(360 - obj.rz)
        end
        
        mirrored[#mirrored + 1] = obj
    end
    
    return mirrored
end

return TransformTools
