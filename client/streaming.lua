--- FORGE: Client Streaming System
--- Chunk-based loading, distance culling, entity pooling, performance optimization

local CONSTANTS = require 'shared.constants'
local CONFIG = require 'shared.config'
local UTILS = require 'shared.utils'

local Streaming = {
    _loadedChunks = {},
    _loadingChunks = {},
    _playerPos = vector3(0, 0, 0),
    _lastStreamUpdate = 0,
    _streamUpdateInterval = CONFIG.PERFORMANCE.STREAMING_UPDATE_FREQUENCY,
    _entityPool = {},
    _poolSize = 0,
}

--- Initialize streaming system
function Streaming.init()
    -- Preload entity pool if needed
    if CONFIG.PERFORMANCE.CHUNK_LOAD_BATCH_SIZE > 0 then
        print('^2[Forge]^7 Streaming system initialized')
    end
end

--- Get chunk ID for coordinates
---@param x number
---@param y number
---@return number
function Streaming.getChunkID(x, y)
    return UTILS.getChunkID(x, y)
end

--- Load chunk from server
---@param chunkID number
function Streaming.loadChunk(chunkID)
    if Streaming._loadedChunks[chunkID] or Streaming._loadingChunks[chunkID] then
        return
    end
    
    Streaming._loadingChunks[chunkID] = true
    
    -- Request chunk from server
    TriggerServerEvent(CONSTANTS.EVENTS.CLIENT_LOAD_CHUNK,
        math.floor(chunkID / 1000000) * CONFIG.STREAMING.CHUNK_SIZE,
        (chunkID % 1000000) * CONFIG.STREAMING.CHUNK_SIZE
    )
end

--- Mark chunk as loaded
---@param chunkID number
---@param objects table Array of objects in chunk
function Streaming.markChunkLoaded(chunkID, objects)
    Streaming._loadingChunks[chunkID] = nil
    Streaming._loadedChunks[chunkID] = {
        id = chunkID,
        objects = objects or {},
        loadedTime = GetGameTimer(),
    }
end

--- Unload chunk
---@param chunkID number
function Streaming.unloadChunk(chunkID)
    local chunk = Streaming._loadedChunks[chunkID]
    if chunk then
        -- Delete entities in chunk
        local EntityManager = require 'client.entity_manager'
        for i = 1, #chunk.objects do
            local obj = chunk.objects[i]
            EntityManager.deleteEntity(obj.id)
        end
        
        Streaming._loadedChunks[chunkID] = nil
    end
end

--- Update streaming (called periodically)
---@param playerX number Player X coordinate
---@param playerY number Player Y coordinate
---@param playerZ number Player Z coordinate
function Streaming.update(playerX, playerY, playerZ)
    local now = GetGameTimer()
    if (now - Streaming._lastStreamUpdate) < Streaming._streamUpdateInterval then
        return
    end
    
    Streaming._lastStreamUpdate = now
    Streaming._playerPos = vector3(playerX, playerY, playerZ)
    
    local currentChunkID = Streaming.getChunkID(playerX, playerY)
    local loadDistance = CONFIG.STREAMING.LOAD_DISTANCE
    local unloadDistance = CONFIG.STREAMING.UNLOAD_DISTANCE
    
    -- Load nearby chunks
    for dx = -2, 2 do
        for dy = -2, 2 do
            local chunkX = math.floor(playerX / CONFIG.STREAMING.CHUNK_SIZE) + dx
            local chunkY = math.floor(playerY / CONFIG.STREAMING.CHUNK_SIZE) + dy
            local chunkID = chunkX * 1000000 + chunkY
            
            local chunkCenterX = chunkX * CONFIG.STREAMING.CHUNK_SIZE + CONFIG.STREAMING.CHUNK_SIZE / 2
            local chunkCenterY = chunkY * CONFIG.STREAMING.CHUNK_SIZE + CONFIG.STREAMING.CHUNK_SIZE / 2
            
            local distance = UTILS.getDistance2D(playerX, playerY, chunkCenterX, chunkCenterY)
            
            if distance < loadDistance then
                Streaming.loadChunk(chunkID)
            elseif distance > unloadDistance then
                Streaming.unloadChunk(chunkID)
            end
        end
    end
end

--- Get loaded chunks
---@return table
function Streaming.getLoadedChunks()
    return UTILS.deepCopy(Streaming._loadedChunks)
end

--- Get chunk info
---@param chunkID number
---@return table|nil
function Streaming.getChunkInfo(chunkID)
    return Streaming._loadedChunks[chunkID]
end

--- Get all loaded objects
---@return table
function Streaming.getAllLoadedObjects()
    local allObjects = {}
    for chunkID, chunk in pairs(Streaming._loadedChunks) do
        for i = 1, #chunk.objects do
            allObjects[#allObjects + 1] = chunk.objects[i]
        end
    end
    return allObjects
end

--- Get loaded object count
---@return number
function Streaming.getLoadedObjectCount()
    local count = 0
    for chunkID, chunk in pairs(Streaming._loadedChunks) do
        count = count + #chunk.objects
    end
    return count
end

--- Get player position
---@return vector3
function Streaming.getPlayerPos()
    return Streaming._playerPos
end

--- Pool an entity for reuse
---@param entity number Entity handle
function Streaming.poolEntity(entity)
    if entity and entity ~= 0 then
        Streaming._entityPool[#Streaming._entityPool + 1] = entity
        Streaming._poolSize = Streaming._poolSize + 1
    end
end

--- Get entity from pool or create new one
---@param model number Model hash
---@param x number
---@param y number
---@param z number
---@return number Entity handle
function Streaming.getPooledEntity(model, x, y, z)
    -- For now, simple entity creation (full pooling would be more complex)
    RequestModel(model)
    local timeout = GetGameTimer() + CONFIG.MODELS.TIMEOUT
    
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then break end
        Wait(0)
    end
    
    return CreateObject(model, x, y, z, false, true, false)
end

--- Clear entity pool
function Streaming.clearPool()
    for i = 1, #Streaming._entityPool do
        local entity = Streaming._entityPool[i]
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    Streaming._entityPool = {}
    Streaming._poolSize = 0
end

--- Get pool stats
---@return table {pooledEntities, chunkCount, objectCount}
function Streaming.getStats()
    return {
        pooledEntities = Streaming._poolSize,
        chunkCount = UTILS.tableSize(Streaming._loadedChunks),
        objectCount = Streaming.getLoadedObjectCount(),
        loadingChunks = UTILS.tableSize(Streaming._loadingChunks),
    }
end

--- Main streaming loop (called from main thread)
function Streaming.mainLoop()
    local playerPed = PlayerPedId()
    if playerPed and playerPed ~= 0 then
        local coords = GetEntityCoords(playerPed)
        Streaming.update(coords.x, coords.y, coords.z)
    end
end

return Streaming
