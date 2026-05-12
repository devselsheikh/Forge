# FORGE Installation & Setup Guide

## Prerequisites

- FiveM Server (updated)
- ox_lib (for future integration)
- Admin/Staff with ACE permissions
- Basic understanding of FiveM server structure

## Installation Steps

### Step 1: Extract Resource

```bash
cd /path/to/server/resources
# Copy forge folder here
ls -la forge/  # Verify structure
```

### Step 2: Add to server.cfg

```
# Recommended: before any jobs/scripts that need the editor
ensure ox_lib
ensure forge
```

### Step 3: Configure ACE Permissions

Add to your **server.cfg** or permissions file:

```lua
-- Administrators can use all features
add_ace group.admin forge.open allow
add_ace group.admin forge.place allow
add_ace group.admin forge.delete allow
add_ace group.admin forge.editothers allow
add_ace group.admin forge.managemaps allow

-- Moderators can place but not delete others' objects
add_ace group.moderator forge.open allow
add_ace group.moderator forge.place allow
add_ace group.moderator forge.delete allow

-- Editors can only view/place (limited)
add_ace group.editor forge.open allow
add_ace group.editor forge.place allow
add_ace group.editor forge.viewonly allow

-- Or use direct player identifiers
add_ace player.license:abc123def456 forge.open allow
add_ace player.license:abc123def456 forge.place allow
```

### Step 4: Database Setup (Optional)

If using SQL persistence (future feature):

```sql
CREATE TABLE IF NOT EXISTS forge_maps (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) UNIQUE,
    object_count INT,
    creator VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data LONGTEXT
);

CREATE TABLE IF NOT EXISTS forge_objects (
    id VARCHAR(36) PRIMARY KEY,
    map_name VARCHAR(255),
    model INT,
    x FLOAT, y FLOAT, z FLOAT,
    rx FLOAT, ry FLOAT, rz FLOAT,
    sx FLOAT, sy FLOAT, sz FLOAT,
    owner VARCHAR(50),
    created_at TIMESTAMP,
    FOREIGN KEY (map_name) REFERENCES forge_maps(name)
);
```

### Step 5: Start Server

```bash
# Server console output should show:
# [Forge] Server initialized successfully
# [Forge] Client resource loaded successfully
# [Forge] Press F5 to open the editor
```

## Configuration

### Basic Settings (shared/config.lua)

```lua
CONFIG = {
    -- Enable/disable features
    FEATURES = {
        ENABLE_COLLABORATION = true,    -- Multi-admin editing
        ENABLE_AUTOSAVE = true,         -- Auto-save maps
        ENABLE_STREAMING = true,        -- Chunk-based loading
        ENABLE_UNDO_REDO = true,        -- History system
        ENABLE_ASSET_BROWSER = true,    -- Prop browser
        ENABLE_BRUSH_MODE = true,       -- Painting mode
    },
    
    -- Performance tweaking
    PERFORMANCE = {
        AUTOSAVE_INTERVAL = 300000,          -- 5 minutes
        CHUNK_LOAD_BATCH_SIZE = 10,          -- Objects per batch
        ENTITY_CREATION_DELAY = 10,          -- Delay between creates (ms)
        STREAMING_UPDATE_FREQUENCY = 100,    -- Update frequency (ms)
        HISTORY_MAX_ENTRIES = 500,           -- Undo/redo depth
    },
    
    -- Storage
    DATABASE = {
        ENABLED = true,
        TYPE = 'json',  -- 'json' or 'sql'
        PATH = 'resources/forge/data/',
        AUTO_BACKUP = true,
        BACKUP_INTERVAL = 600000,  -- 10 minutes
    },
    
    -- Model filtering
    MODELS = {
        WHITELIST_ENABLED = false,  -- If true, only allow listed models
        BLACKLIST_ENABLED = true,   -- If true, block listed models
        WHITELIST = {},
        BLACKLIST = {
            'crash1',
            'crash2',
            'invalid_model',
        },
    },
    
    -- Streaming
    STREAMING = {
        CHUNK_SIZE = 256,           -- Units per chunk
        LOAD_DISTANCE = 500,        -- Load radius (units)
        UNLOAD_DISTANCE = 600,      -- Unload radius
        MAX_CHUNKS_LOADED = 10,     -- Max concurrent chunks
    },
}
```

### Advanced: Custom Model Whitelist

```lua
-- For specific themed servers
CONFIG.MODELS.WHITELIST_ENABLED = true
CONFIG.MODELS.WHITELIST = {
    'prop_shop_counter',
    'prop_shop_shelf_01',
    'prop_shop_shelf_02',
    'prop_chair_office',
    'prop_table_office',
    'prop_desk_01',
    'prop_blinds_01',
    'prop_door_01',
    -- ... etc
}
```

## First Run

### Admin User Setup

```
1. Login as admin
2. Press F5 to open editor
3. You should see:
   - Clean editor interface
   - Empty hierarchy
   - Asset browser with props
   - Empty map
4. Try placing a single object:
   - Search for "prop_tree_birch_01"
   - Click to place in world
   - Use Move tool to position
   - Save with Ctrl+S
5. Give map a name like "test_map_001"
```

### Testing Features

```lua
-- In admin command or console
-- Get all saved maps
TriggerServerEvent('forge:requestMapList')

-- Load a specific map
TriggerServerEvent('forge:requestLoadMap', 'test_map_001')

-- Export as resource
TriggerServerEvent('forge:requestExport', 'my_map_resource')
```

## File Structure After Installation

```
forge/
├── fxmanifest.lua                 # Resource manifest
├── README.md                       # Documentation
├── SETUP.md                        # This file
│
├── shared/
│   ├── constants.lua              # Game constants
│   ├── config.lua                 # User configuration
│   └── utils.lua                  # Shared utilities
│
├── server/
│   ├── main.lua                   # Server entry point
│   ├── permissions.lua            # ACE permission system
│   ├── validation.lua             # Zero-trust validation
│   ├── entity_manager.lua         # Object lifecycle
│   ├── persistence.lua            # Storage layer
│   ├── collaboration.lua          # Multi-admin features
│   └── data/                      # Saved maps
│       └── maps/
│           ├── map_test_001.json
│           └── snapshot_*.json
│
├── client/
│   ├── main.lua                   # Client entry point
│   ├── editor_state.lua           # Global state
│   ├── entity_manager.lua         # Local entities
│   ├── history.lua                # Undo/redo
│   ├── selection.lua              # Multi-select
│   ├── streaming.lua              # Chunk loading
│   ├── transform_tools.lua        # Transform logic
│   ├── input_handler.lua          # Input system
│   ├── ui.lua                     # NUI bridge
│   └── nui/
│       ├── index.html             # UI layout
│       ├── styles.css             # Styling
│       └── app.js                 # NUI app
│
└── data/
    └── maps/                      # Default map location
        └── (auto-created)
```

## Verification Checklist

- [ ] Resource starts without errors
- [ ] F5 opens editor in-game
- [ ] Admin can place objects
- [ ] Objects appear in world
- [ ] Ctrl+Z undo works
- [ ] Ctrl+S saves map
- [ ] Map file created in data/maps/
- [ ] No frame drops during editing
- [ ] Resmon under 0.20ms

## Troubleshooting

### Editor won't open (F5 doesn't work)

**Cause:** NUI not loaded or permissions denied

**Fix:**
```lua
-- Server console:
setr debug 1
# Check for NUI errors

# Or check client F8 console for JavaScript errors
```

### Objects don't appear

**Cause:** Model not loaded or permission denied

**Fix:**
```lua
-- Verify model hash is valid
local hash = GetHashKey('prop_shop_counter')
print(hash)  -- Should be non-zero

-- Check permissions
add_ace player.YOUR_LICENSE forge.place allow
add_ace player.YOUR_LICENSE forge.open allow

# Restart resource: restart forge
```

### High resmon (over 0.20ms)

**Cause:** Too many entities or streaming lag

**Fix:**
```lua
-- In config.lua:
PERFORMANCE = {
    STREAMING_UPDATE_FREQUENCY = 500,  -- Increase from 100
    CHUNK_LOAD_BATCH_SIZE = 5,         -- Decrease from 10
}
```

### Map won't save

**Cause:** Directory doesn't exist or permission denied

**Fix:**
```bash
# Verify directory exists and is writable
mkdir -p resources/forge/data/maps/
chmod 755 resources/forge/data/maps/
```

## Commands

### Server Commands

```lua
-- Force save current map
TriggerEvent('forge:forceMapSave', 'map_name')

-- Load map to server
TriggerEvent('forge:loadMapToServer', 'map_name')

-- Clear all objects from world
TriggerEvent('forge:clearAllObjects')

-- List all saved maps
TriggerEvent('forge:listMaps')
```

### Client Commands (Console)

```lua
-- Force editor open
TriggerEvent('forge:openEditor')

-- Close editor
TriggerEvent('forge:closeEditor')

-- Select all objects
TriggerEvent('forge:selectAll')

-- Deselect all
TriggerEvent('forge:clearSelection')
```

## Performance Tuning

### For 1000+ Objects

```lua
CONFIG.PERFORMANCE = {
    STREAMING_UPDATE_FREQUENCY = 200,
    CHUNK_LOAD_BATCH_SIZE = 5,
    ENTITY_CREATION_DELAY = 20,
    HISTORY_MAX_ENTRIES = 200,
}

CONFIG.STREAMING = {
    CHUNK_SIZE = 512,  -- Larger chunks
    LOAD_DISTANCE = 300,  -- Reduce load distance
    UNLOAD_DISTANCE = 400,
}
```

### For 100 Objects (Light Usage)

```lua
CONFIG.PERFORMANCE = {
    STREAMING_UPDATE_FREQUENCY = 50,
    CHUNK_LOAD_BATCH_SIZE = 20,
    HISTORY_MAX_ENTRIES = 1000,
}

CONFIG.STREAMING = {
    CHUNK_SIZE = 128,
    LOAD_DISTANCE = 1000,
}
```

## Security Hardening

### Recommended ACE Setup

```lua
-- Principle of least privilege
add_ace group.admin forge.open allow
add_ace group.admin forge.place allow
add_ace group.admin forge.delete allow
add_ace group.admin forge.editothers allow
add_ace group.admin forge.managemaps allow

-- Moderators limited
add_ace group.moderator forge.open allow
add_ace group.moderator forge.place allow

-- Deny everyone else by default
add_ace builtin.everyone forge.open deny
add_ace builtin.everyone forge.place deny
add_ace builtin.everyone forge.delete deny
```

### Disable Features for Performance

```lua
CONFIG.FEATURES.ENABLE_COLLABORATION = false  -- Reduce overhead
CONFIG.PERSISTENCE.AUTO_BACKUP = false        -- Speed up saves
CONFIG.DEBUG.ENABLED = false                  -- Always disable in prod
```

## Backup & Recovery

### Manual Backup

```bash
# Backup all maps
cp -r resources/forge/data/maps /path/to/backup/forge_maps_$(date +%s)

# Restore from backup
cp /path/to/backup/forge_maps_*/* resources/forge/data/maps/
```

### Auto-Restore from Crash

```lua
-- Maps auto-backup to .backup files
-- If map corruption detected, rename to restore:
os.rename('map_corrupted.json.backup', 'map_corrupted.json')
```

## Next Steps

1. ✅ Complete this guide
2. ✅ Configure shared/config.lua
3. ✅ Set up ACE permissions
4. ✅ Start server and test
5. ✅ Create initial maps
6. ✅ Train staff on usage
7. ✅ Monitor performance
8. ✅ Scale as needed

---

**Setup complete! Happy mapping!**
