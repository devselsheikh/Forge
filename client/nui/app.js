// FORGE: Client NUI Application
// Communication bridge between Lua backend and HTML UI

class ForgeUI {
    constructor() {
        this.state = {
            editorOpen: false,
            currentTab: 'inspector',
            selectedObjects: [],
            objects: {},
            history: [],
            historyIndex: 0,
            collaborators: [],
            mapName: null,
        };

        this.initialize();
    }

    initialize() {
        // Hard-hide UI on boot; it should only appear after explicit editor open state.
        document.body.style.background = 'transparent';
        const app = document.getElementById('app');
        if (app) {
            app.style.display = 'none';
            app.style.pointerEvents = 'none';
        }

        this.setupEventListeners();
        this.setupNuiListeners();
        this.updateUI();
    }

    setupEventListeners() {
        // Toolbar buttons
        document.getElementById('btn-save').addEventListener('click', () => this.saveMap());
        document.getElementById('btn-load').addEventListener('click', () => this.loadMap());
        document.getElementById('btn-export').addEventListener('click', () => this.exportMap());
        
        document.getElementById('btn-undo').addEventListener('click', () => this.undo());
        document.getElementById('btn-redo').addEventListener('click', () => this.redo());
        
        document.getElementById('btn-move').addEventListener('click', () => this.setTransformMode('move'));
        document.getElementById('btn-rotate').addEventListener('click', () => this.setTransformMode('rotate'));
        document.getElementById('btn-scale').addEventListener('click', () => this.setTransformMode('scale'));
        
        document.getElementById('btn-snap-grid').addEventListener('click', () => this.toggleSnapGrid());
        document.getElementById('btn-snap-angle').addEventListener('click', () => this.toggleSnapAngle());
        document.getElementById('btn-local-space').addEventListener('click', () => this.toggleTransformSpace());
        
        document.getElementById('btn-delete').addEventListener('click', () => this.deleteSelected());
        document.getElementById('btn-duplicate').addEventListener('click', () => this.duplicateSelected());
        
        document.getElementById('btn-settings').addEventListener('click', () => this.openSettings());
        document.getElementById('btn-help').addEventListener('click', () => this.openHelp());

        // Tabs
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
                document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
                e.target.classList.add('active');
                document.getElementById('tab-' + e.target.getAttribute('data-tab')).classList.add('active');
            });
        });

        // Property inputs
        ['x', 'y', 'z', 'rx', 'ry', 'rz', 'sx', 'sy', 'sz'].forEach(prop => {
            const input = document.getElementById(`prop-${prop}`);
            if (input) {
                input.addEventListener('change', (e) => this.updateObjectProperty(prop, parseFloat(e.target.value)));
            }
        });

        // Asset search
        const assetSearch = document.getElementById('asset-search');
        if (assetSearch) {
            assetSearch.addEventListener('input', (e) => this.searchAssets(e.target.value));
        }
    }

    setupNuiListeners() {
        // Listen for Lua events via postMessage
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch(data.action) {
                case 'editorStateChanged':
                    this.onEditorStateChanged(data.payload);
                    break;
                case 'objectSelected':
                    this.onObjectSelected(data.payload);
                    break;
                case 'objectCreated':
                    this.onObjectCreated(data.payload);
                    break;
                case 'objectDeleted':
                    this.onObjectDeleted(data.payload);
                    break;
                case 'historyChanged':
                    this.onHistoryChanged(data.payload);
                    break;
                case 'collaboratorJoined':
                    this.onCollaboratorJoined(data.payload);
                    break;
                case 'collaboratorLeft':
                    this.onCollaboratorLeft(data.payload);
                    break;
                case 'performanceUpdate':
                    this.onPerformanceUpdate(data.payload);
                    break;
            }
        });
    }

    // NUI Message sending
    sendToLua(action, payload) {
        fetch(`https://${GetParentResourceName()}/lua_action`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, payload })
        }).catch(err => console.error('NUI Communication Error:', err));
    }

    // Transform modes
    setTransformMode(mode) {
        document.querySelectorAll('[data-mode]').forEach(btn => btn.classList.remove('active'));
        document.getElementById(`btn-${mode}`).classList.add('active');
        this.sendToLua('setTransformMode', { mode });
    }

    // Snap toggles
    toggleSnapGrid() {
        const btn = document.getElementById('btn-snap-grid');
        btn.classList.toggle('active');
        this.sendToLua('toggleSnapGrid', {});
    }

    toggleSnapAngle() {
        const btn = document.getElementById('btn-snap-angle');
        btn.classList.toggle('active');
        this.sendToLua('toggleSnapAngle', {});
    }

    toggleTransformSpace() {
        const btn = document.getElementById('btn-local-space');
        btn.classList.toggle('active');
        this.sendToLua('toggleTransformSpace', {});
    }

    // Object operations
    deleteSelected() {
        if (confirm('Delete selected objects?')) {
            this.sendToLua('deleteSelected', {});
        }
    }

    duplicateSelected() {
        this.sendToLua('duplicateSelected', {});
    }

    // Map operations
    saveMap() {
        const mapName = prompt('Enter map name:');
        if (mapName) {
            this.sendToLua('saveMap', { mapName });
        }
    }

    loadMap() {
        const mapName = prompt('Enter map name to load:');
        if (mapName) {
            this.sendToLua('loadMap', { mapName });
        }
    }

    exportMap() {
        const resourceName = prompt('Enter resource name for export:');
        if (resourceName) {
            this.sendToLua('exportMap', { resourceName });
        }
    }

    // History operations
    undo() {
        this.sendToLua('undo', {});
    }

    redo() {
        this.sendToLua('redo', {});
    }

    // Property updates
    updateObjectProperty(prop, value) {
        if (this.state.selectedObjects.length > 0) {
            this.sendToLua('updateObjectProperty', {
                objectID: this.state.selectedObjects[0],
                property: prop,
                value
            });
        }
    }

    // Asset management
    searchAssets(query) {
        this.sendToLua('searchAssets', { query });
    }

    // UI Updates
    onEditorStateChanged(data) {
        this.state.editorOpen = data.isOpen;
        const app = document.getElementById('app');
        if (data.isOpen) {
            app.style.display = 'flex';
            app.style.pointerEvents = 'auto';
        } else {
            app.style.display = 'none';
            app.style.pointerEvents = 'none';
        }
    }

    onObjectSelected(data) {
        this.state.selectedObjects = [data.objectID];
        this.updateInspector(data.object);
        this.updateHierarchy();
    }

    onObjectCreated(data) {
        this.state.objects[data.object.id] = data.object;
        this.updateHierarchy();
    }

    onObjectDeleted(data) {
        delete this.state.objects[data.objectID];
        this.updateHierarchy();
    }

    onHistoryChanged(data) {
        this.state.historyIndex = data.current;
        this.updateHistoryUI();
        document.getElementById('btn-undo').disabled = !data.canUndo;
        document.getElementById('btn-redo').disabled = !data.canRedo;
    }

    onCollaboratorJoined(data) {
        this.state.collaborators.push(data);
        this.updateCollaboratorsUI();
    }

    onCollaboratorLeft(data) {
        this.state.collaborators = this.state.collaborators.filter(c => c.playerID !== data.playerID);
        this.updateCollaboratorsUI();
    }

    onPerformanceUpdate(data) {
        document.getElementById('fps-counter').textContent = `FPS: ${data.fps}`;
        document.getElementById('resmon-counter').textContent = `ResMan: ${data.resmon.toFixed(2)}`;
        document.getElementById('object-counter').textContent = `Objects: ${data.objectCount}`;
    }

    // UI Rendering
    updateInspector(object) {
        if (!object) return;
        
        document.getElementById('prop-x').value = object.x.toFixed(2);
        document.getElementById('prop-y').value = object.y.toFixed(2);
        document.getElementById('prop-z').value = object.z.toFixed(2);
        document.getElementById('prop-rx').value = object.rx.toFixed(1);
        document.getElementById('prop-ry').value = object.ry.toFixed(1);
        document.getElementById('prop-rz').value = object.rz.toFixed(1);
        document.getElementById('prop-sx').value = object.sx.toFixed(2);
        document.getElementById('prop-sy').value = object.sy.toFixed(2);
        document.getElementById('prop-sz').value = object.sz.toFixed(2);
    }

    updateHierarchy() {
        const tree = document.getElementById('hierarchy-tree');
        tree.innerHTML = '';
        
        for (const [id, obj] of Object.entries(this.state.objects)) {
            const item = document.createElement('div');
            item.className = 'hierarchy-item';
            if (this.state.selectedObjects.includes(id)) {
                item.classList.add('selected');
            }
            item.textContent = `${obj.model} #${id.substring(0, 8)}`;
            item.addEventListener('click', () => {
                this.sendToLua('selectObject', { objectID: id });
            });
            tree.appendChild(item);
        }
    }

    updateHistoryUI() {
        const list = document.getElementById('history-list');
        list.innerHTML = '';
        
        this.state.history.forEach((entry, idx) => {
            const item = document.createElement('div');
            item.className = 'history-entry';
            if (idx === this.state.historyIndex) {
                item.classList.add('current');
            }
            item.textContent = entry.description;
            item.addEventListener('click', () => {
                this.sendToLua('jumpToHistoryEntry', { index: idx });
            });
            list.appendChild(item);
        });
    }

    updateCollaboratorsUI() {
        const list = document.getElementById('collaborators-list');
        list.innerHTML = '';
        
        this.state.collaborators.forEach(collab => {
            const item = document.createElement('div');
            item.className = 'collaborator';
            item.innerHTML = `
                <div class="collaborator-avatar">${collab.playerName.substring(0, 1)}</div>
                <div>
                    <div>${collab.playerName}</div>
                    <div style="font-size: 10px; opacity: 0.7;">${collab.action}</div>
                </div>
            `;
            list.appendChild(item);
        });
    }

    updateUI() {
        this.updateHierarchy();
        this.updateHistoryUI();
        this.updateCollaboratorsUI();
    }

    // Dialogs
    openSettings() {
        alert('Settings dialog would open here');
    }

    openHelp() {
        alert(`
FORGE World Editor - Help

Hotkeys:
- F5: Toggle Editor
- M: Move tool
- R: Rotate tool
- S: Scale tool
- G: Toggle Grid Snap
- A: Toggle Angle Snap
- Delete: Remove selected
- Ctrl+D: Duplicate
- Ctrl+Z: Undo
- Ctrl+Y: Redo
- Ctrl+S: Save

Tips:
- Shift+Click to multi-select
- Drag to move objects
- Middle mouse to rotate camera
- Scroll to zoom
        `);
    }
}

// Initialize UI when page loads
document.addEventListener('DOMContentLoaded', () => {
    new ForgeUI();
});
