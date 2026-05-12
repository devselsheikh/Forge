--- FORGE: Shared Constants
--- Enterprise-grade world editor for FiveM

local CONSTANTS = {
    --- Editor configuration
    EDITOR = {
        NAME = 'Forge',
        VERSION = '1.0.0',
        MAX_ENTITIES = 5000,
        MAX_SELECTION = 1000,
        CHUNK_SIZE = 256.0,
        STREAMING_DISTANCE = 500.0,
        UNLOAD_DISTANCE = 600.0,
    },

    --- Permissions
    PERMISSIONS = {
        ADMIN = 'group.admin',
        MODERATOR = 'group.moderator',
        EDITOR = 'group.editor',
        VIEWER = 'group.viewer',
    },

    --- Object properties
    OBJECT = {
        MODEL_TIMEOUT = 5000,
        PHYSICS_ENABLED = true,
        PHYSICS_SCALE = 1.0,
        MIN_SCALE = 0.1,
        MAX_SCALE = 100.0,
        GRID_SNAP = 0.25,
        ANGLE_SNAP = 15.0,
    },

    --- Network events
    EVENTS = {
        --- Client → Server
        CLIENT_PLACE_OBJECT = 'forge:client:placeObject',
        CLIENT_MOVE_OBJECT = 'forge:client:moveObject',
        CLIENT_DELETE_OBJECT = 'forge:client:deleteObject',
        CLIENT_UPDATE_PROPERTIES = 'forge:client:updateProperties',
        CLIENT_LOAD_CHUNK = 'forge:client:loadChunk',
        CLIENT_SAVE_MAP = 'forge:client:saveMap',
        CLIENT_LOAD_MAP = 'forge:client:loadMap',

        --- Server → Client
        SERVER_OBJECT_CREATED = 'forge:server:objectCreated',
        SERVER_OBJECT_UPDATED = 'forge:server:objectUpdated',
        SERVER_OBJECT_DELETED = 'forge:server:objectDeleted',
        SERVER_CHUNK_LOADED = 'forge:server:chunkLoaded',
        SERVER_ERROR = 'forge:server:error',
    },

    --- Validation rules
    VALIDATION = {
        MODEL_BLACKLIST = {
            'a_m_m_business_1',
            'a_f_y_business_1',
        },
        MAX_PAYLOAD = 4096,
        MAX_COORDINATE = 9999.0,
        MIN_COORDINATE = -9999.0,
        RATE_LIMIT = {
            EVENTS_PER_SEC = 10,
            OBJECTS_PER_SEC = 5,
        },
    },

    --- UI modes
    UI_MODES = {
        CLOSED = 0,
        EDITOR = 1,
        BROWSER = 2,
        SETTINGS = 3,
        COLLABORATION = 4,
    },

    --- Transform space
    TRANSFORM = {
        WORLD_SPACE = 1,
        LOCAL_SPACE = 2,
    },

    --- Axis
    AXIS = {
        X = 1,
        Y = 2,
        Z = 3,
    },

    --- Entity states
    ENTITY_STATE = {
        LOCAL = 1,
        PENDING = 2,
        SYNCED = 3,
        DELETED = 4,
    },
}

return CONSTANTS
