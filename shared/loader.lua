--- FORGE: Lightweight module loader for FiveM
--- Provides Lua `require` semantics using resource files.

local _resource = GetCurrentResourceName()
local _loaded = {}

local function normalizePath(moduleName)
    local path = moduleName:gsub('%.', '/')
    if not path:match('%.lua$') then
        path = path .. '.lua'
    end
    return path
end

local function loadModule(moduleName)
    if _loaded[moduleName] ~= nil then
        return _loaded[moduleName]
    end

    local filePath = normalizePath(moduleName)
    local source = LoadResourceFile(_resource, filePath)
    if not source then
        error(("module '%s' not found (resource '%s', path '%s')"):format(moduleName, _resource, filePath), 2)
    end

    local chunk, loadErr = load(source, ('@@%s/%s'):format(_resource, filePath), 't')
    if not chunk then
        error(("error loading module '%s': %s"):format(moduleName, loadErr), 2)
    end

    local ok, result = pcall(chunk)
    if not ok then
        error(("error running module '%s': %s"):format(moduleName, result), 2)
    end

    if result == nil then
        result = true
    end

    _loaded[moduleName] = result
    return result
end

_G.require = loadModule
