--- FORGE: Shared Utilities
--- Helper functions for both client and server

local UTILS = {}

--- Generate UUID v4
---@return string
function UTILS.generateUUID()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--- Hash model string to valid GTA model hash
---@param modelName string
---@return number
function UTILS.getModelHash(modelName)
    if type(modelName) == 'number' then
        return modelName
    end
    return GetHashKey(modelName)
end

--- Validate coordinate is within bounds
---@param x number
---@param y number
---@param z number
---@return boolean
function UTILS.isValidCoordinate(x, y, z)
    local MAX = 9999.0
    local MIN = -9999.0
    return x >= MIN and x <= MAX and
           y >= MIN and y <= MAX and
           z >= MIN and z <= MAX
end

--- Calculate chunk ID from coordinates
---@param x number
---@param y number
---@return number
function UTILS.getChunkID(x, y)
    local CHUNK_SIZE = 256
    local chunkX = math.floor(x / CHUNK_SIZE)
    local chunkY = math.floor(y / CHUNK_SIZE)
    return chunkX * 1000000 + chunkY
end

--- Get chunk coordinates from ID
---@param chunkID number
---@return number, number
function UTILS.getChunkCoords(chunkID)
    local CHUNK_SIZE = 256
    local chunkX = math.floor(chunkID / 1000000)
    local chunkY = chunkID % 1000000
    return chunkX * CHUNK_SIZE, chunkY * CHUNK_SIZE
end

--- Distance between two vectors
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function UTILS.getDistance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

--- Distance 2D (X, Y only)
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function UTILS.getDistance2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

--- Clamp value between min and max
---@param value number
---@param min number
---@param max number
---@return number
function UTILS.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Round number to N decimals
---@param value number
---@param decimals number
---@return number
function UTILS.round(value, decimals)
    local multiplier = 10 ^ (decimals or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

--- Deep copy table
---@param tbl table
---@return table
function UTILS.deepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            copy[k] = UTILS.deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--- Merge two tables (right overwrites left)
---@param left table
---@param right table
---@return table
function UTILS.mergeTables(left, right)
    local result = UTILS.deepCopy(left)
    if not right then return result end
    
    for k, v in pairs(right) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = UTILS.mergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--- Check if table contains value
---@param tbl table
---@param value any
---@return boolean
function UTILS.tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

--- Get table size/length
---@param tbl table
---@return number
function UTILS.tableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

--- Convert table to array (ordered)
---@param tbl table
---@return table
function UTILS.tableToArray(tbl)
    local array = {}
    for _, v in pairs(tbl) do
        array[#array + 1] = v
    end
    return array
end

--- Create matrix/rotation from angles (radians)
---@param rx number
---@param ry number
---@param rz number
---@return table
function UTILS.createRotationMatrix(rx, ry, rz)
    local cosx, sinx = math.cos(rx), math.sin(rx)
    local cosy, siny = math.cos(ry), math.sin(ry)
    local cosz, sinz = math.cos(rz), math.sin(rz)
    
    return {
        {cosy*cosz, -cosy*sinz, siny, 0},
        {sinx*siny*cosz + cosx*sinz, -sinx*siny*sinz + cosx*cosz, -sinx*cosy, 0},
        {-cosx*siny*cosz + sinx*sinz, cosx*siny*sinz + sinx*cosz, cosx*cosy, 0},
        {0, 0, 0, 1}
    }
end

--- Radians to degrees
---@param rad number
---@return number
function UTILS.toDegrees(rad)
    return rad * (180 / math.pi)
end

--- Degrees to radians
---@param deg number
---@return number
function UTILS.toRadians(deg)
    return deg * (math.pi / 180)
end

--- Serialize table to JSON string
---@param tbl table
---@return string
function UTILS.toJSON(tbl)
    local function serialize(obj, indent)
        indent = indent or ""
        
        if type(obj) == "number" then
            return tostring(obj)
        elseif type(obj) == "string" then
            return '"' .. obj:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
        elseif type(obj) == "boolean" then
            return obj and "true" or "false"
        elseif type(obj) == "table" then
            local isArray = true
            for k in pairs(obj) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
            
            if isArray then
                local result = "["
                for i, v in ipairs(obj) do
                    if i > 1 then result = result .. "," end
                    result = result .. serialize(v, indent .. "  ")
                end
                return result .. "]"
            else
                local result = "{"
                local first = true
                for k, v in pairs(obj) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. k .. '":' .. serialize(v, indent .. "  ")
                    first = false
                end
                return result .. "}"
            end
        else
            return "null"
        end
    end
    
    return serialize(tbl)
end

--- Parse JSON string to table
---@param json string
---@return table|nil
function UTILS.fromJSON(json)
    local function parse(str, pos)
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
        
        local char = str:sub(pos, pos)
        
        if char == "{" then
            local obj = {}
            pos = pos + 1
            
            while pos <= #str do
                while pos <= #str and str:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) == "}" then return obj, pos + 1 end
                
                local key, newPos = parse(str, pos)
                pos = newPos
                
                while pos <= #str and str:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) ~= ":" then return nil end
                pos = pos + 1
                
                local value
                value, pos = parse(str, pos)
                obj[key] = value
                
                while pos <= #str and str:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) == "," then pos = pos + 1 end
            end
        elseif char == "[" then
            local arr = {}
            pos = pos + 1
            
            while pos <= #str do
                while pos <= #str and str:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) == "]" then return arr, pos + 1 end
                
                local value
                value, pos = parse(str, pos)
                arr[#arr + 1] = value
                
                while pos <= #str and str:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end
                
                if str:sub(pos, pos) == "," then pos = pos + 1 end
            end
        elseif char == '"' then
            pos = pos + 1
            local str_start = pos
            while pos <= #str and str:sub(pos, pos) ~= '"' do
                if str:sub(pos, pos) == "\\" then pos = pos + 2 else pos = pos + 1 end
            end
            return str:sub(str_start, pos - 1), pos + 1
        else
            local word_match = str:match("(true|false|null|%-?%d+%.?%d*[eE]?%-?%d*)", pos)
            if word_match == "true" then return true, pos + 4
            elseif word_match == "false" then return false, pos + 5
            elseif word_match == "null" then return nil, pos + 4
            else
                local num = tonumber(str:match("%-?%d+%.?%d*[eE]?%-?%d*", pos))
                if num then return num, pos + #tostring(num) end
            end
        end
        
        return nil, pos
    end
    
    local result, _ = parse(json, 1)
    return result
end

return UTILS
