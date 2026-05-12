--- FORGE: Configuration
--- User-configurable settings and feature flags

local CONFIG = {
    --- Feature flags
    FEATURES = {
        ENABLE_COLLABORATION = true,
        ENABLE_AUTOSAVE = true,
        ENABLE_STREAMING = true,
        ENABLE_UNDO_REDO = true,
        ENABLE_ASSET_BROWSER = true,
        ENABLE_BRUSH_MODE = true,
        ENABLE_PREFABS = true,
    },

    --- Performance tuning
    PERFORMANCE = {
        AUTOSAVE_INTERVAL = 300000, -- 5 minutes
        CHUNK_LOAD_BATCH_SIZE = 10,
        ENTITY_CREATION_DELAY = 10,
        STREAMING_UPDATE_FREQUENCY = 100,
        HISTORY_MAX_ENTRIES = 500,
    },

    --- Database
    DATABASE = {
        ENABLED = true,
        TYPE = 'json', -- 'json' or 'sql'
        PATH = 'resources/forge/data/',
        AUTO_BACKUP = true,
        BACKUP_INTERVAL = 600000, -- 10 minutes
    },

    --- UI defaults
    UI = {
        OPACITY = 0.95,
        FONT_SIZE = 12,
        THEME = 'dark',
        LAYOUT = 'classic',
    },

    --- Hotkeys (rebindable)
    HOTKEYS = {
        TOGGLE_EDITOR = 'F5',
        MOVE_MODE = 'M',
        ROTATE_MODE = 'R',
        SCALE_MODE = 'S',
        DELETE = 'DELETE',
        DUPLICATE = 'D',
        UNDO = 'Z',
        REDO = 'Y',
        SAVE = 'CTRL+S',
        SNAP_GRID = 'G',
        SNAP_ANGLE = 'A',
    },

    --- ACE permissions (require for features)
    PERMISSIONS = {
        OPEN_EDITOR = 'forge.open',
        PLACE_OBJECTS = 'forge.place',
        DELETE_OBJECTS = 'forge.delete',
        EDIT_OTHERS = 'forge.editothers',
        MANAGE_MAPS = 'forge.managemaps',
        VIEW_ONLY = 'forge.viewonly',
    },

    --- Model restrictions
    MODELS = {
        WHITELIST_ENABLED = false,
        BLACKLIST_ENABLED = true,
        WHITELIST = {},
        BLACKLIST = {
            'crash1',
            'crash2',
            'invalid_model',
        },
        ASYNC_LOAD = true,
        TIMEOUT = 5000,
    },

    --- Streaming configuration
    STREAMING = {
        CHUNK_SIZE = 256,
        LOAD_DISTANCE = 500,
        UNLOAD_DISTANCE = 600,
        MAX_CHUNKS_LOADED = 10,
        PRIORITIZE_NEAR = true,
    },

    --- Persistence
    PERSISTENCE = {
        SAVE_ON_EXIT = true,
        AUTOSAVE_ENABLED = true,
        AUTOSAVE_INTERVAL = 300000,
        DIFF_SAVES = true,
        KEEP_HISTORY = true,
        MAX_RESTORE_POINTS = 20,
    },

    --- Debug and logging
    DEBUG = {
        ENABLED = false,
        LOG_EVENTS = false,
        LOG_STREAMING = false,
        LOG_VALIDATION = false,
        PROFILING = false,
    },
}

return CONFIG
