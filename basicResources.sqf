/*
 * Basic Resource System - Ground Zero Version
 * 
 * Resource Types:
 * 1. Fuel
 * 2. Supplies/Ammo  
 * 3. Fabrication
 * 4. Manpower
 * 5. Electricity
 * 
 * Usage: [] execVM "basicResources.sqf"
 */

if (!isServer) exitWith {
    diag_log "[Resources] Only runs on server";
};

diag_log "[Resources] Initializing Basic Resource System...";

// ============================================================================
// RESOURCE STORAGE
// ============================================================================

// Initialize faction resources: [fuel, supplies, fabrication, manpower, electricity]
if (isNil "RES_factionResources") then {
    RES_factionResources = createHashMap;
    RES_factionResources set ["BLUFOR", [0, 0, 0, 0, 0]];
    RES_factionResources set ["OPFOR", [0, 0, 0, 0, 0]];
    publicVariable "RES_factionResources";
};

// Resource names for display
RES_resourceNames = ["Fuel", "Supplies", "Fabrication", "Manpower", "Electricity"];
publicVariable "RES_resourceNames";

// ============================================================================
// DIRECT INIDBI2 RESOURCE EXPORT (LOGISTICS PIPELINE)
// ============================================================================

if (isNil "RES_export_dbName") then { RES_export_dbName = "TWS_LogisticsIntel"; };
if (isNil "RES_export_sectionMeta") then { RES_export_sectionMeta = "ResourceMeta"; };
if (isNil "RES_export_sectionData") then { RES_export_sectionData = "Resources"; };
if (isNil "RES_export_sectionObjects") then { RES_export_sectionObjects = "ResourceObjects"; };
if (isNil "RES_export_sectionEvents") then { RES_export_sectionEvents = "ResourceEvents"; };
if (isNil "RES_export_interval") then { RES_export_interval = 300; };
if (isNil "RES_export_cycle") then { RES_export_cycle = 0; };
if (isNil "RES_export_running") then { RES_export_running = false; };
if (isNil "RES_export_objectKeyMap") then { RES_export_objectKeyMap = createHashMap; };
if (isNil "RES_export_objectCounter") then { RES_export_objectCounter = 0; };
if (isNil "RES_resourceObjectsSnapshot") then { RES_resourceObjectsSnapshot = createHashMap; };
if (isNil "RES_lastCycleEvents") then { RES_lastCycleEvents = []; };
if (isNil "RES_lastCycleObjectDelta") then { RES_lastCycleObjectDelta = createHashMap; };
if (isNil "RES_lastCycleResourceDelta") then { RES_lastCycleResourceDelta = createHashMap; };

RES_fnc_exportInitIniDB = {
    if (!isNil "RES_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        diag_log "[Resources][EXPORT] OO_INIDBI not found. Direct resource export disabled.";
        false
    };

    RES_iniDB = ["new", RES_export_dbName] call OO_INIDBI;
    if (isNil "RES_iniDB") exitWith {
        diag_log format ["[Resources][EXPORT] Failed to open INIDBI2 DB: %1", RES_export_dbName];
        false
    };

    true
};

RES_fnc_exportWrite = {
    params ["_section", "_key", "_value"];
    if (isNil "RES_iniDB") exitWith {false};
    ["write", [_section, _key, _value]] call RES_iniDB;
    true
};

RES_fnc_zeroResourceVector = {
    [0, 0, 0, 0, 0]
};

RES_fnc_addDelta = {
    params ["_deltaMap", "_faction", "_resourceIndex", "_amount"];
    if !(_faction in ["BLUFOR", "OPFOR"]) exitWith {};

    private _vec = _deltaMap getOrDefault [_faction, [] call RES_fnc_zeroResourceVector];
    private _cur = _vec param [_resourceIndex, 0];
    _vec set [_resourceIndex, _cur + _amount];
    _deltaMap set [_faction, _vec];
};

RES_fnc_getObjectExportKey = {
    params ["_object"];

    private _ref = str _object;
    private _existing = RES_export_objectKeyMap getOrDefault [_ref, ""];
    if (_existing != "") exitWith {_existing};

    RES_export_objectCounter = RES_export_objectCounter + 1;
    private _key = format ["RESOBJ_%1", RES_export_objectCounter];
    RES_export_objectKeyMap set [_ref, _key];
    _key
};

RES_fnc_exportResourcesSnapshot = {
    private _ready = [] call RES_fnc_exportInitIniDB;
    if (!_ready) exitWith {false};

    private _keys = keys RES_factionResources;
    private _activeFactions = [];

    {
        private _faction = _x;
        private _res = RES_factionResources getOrDefault [_faction, [0,0,0,0,0]];
        private _record = [
            _res param [0, 0],
            _res param [1, 0],
            _res param [2, 0],
            _res param [3, 0],
            _res param [4, 0],
            time
        ];

        [RES_export_sectionData, _faction, str _record] call RES_fnc_exportWrite;
        _activeFactions pushBack _faction;
    } forEach _keys;

    private _objDeltaOpfor = RES_lastCycleObjectDelta getOrDefault ["OPFOR", [] call RES_fnc_zeroResourceVector];
    private _objDeltaBlufor = RES_lastCycleObjectDelta getOrDefault ["BLUFOR", [] call RES_fnc_zeroResourceVector];
    private _resDeltaOpfor = RES_lastCycleResourceDelta getOrDefault ["OPFOR", [] call RES_fnc_zeroResourceVector];
    private _resDeltaBlufor = RES_lastCycleResourceDelta getOrDefault ["BLUFOR", [] call RES_fnc_zeroResourceVector];

    [RES_export_sectionMeta, "LastCycleObjectDelta_OPFOR", str _objDeltaOpfor] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "LastCycleObjectDelta_BLUFOR", str _objDeltaBlufor] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "LastCycleResourceDelta_OPFOR", str _resDeltaOpfor] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "LastCycleResourceDelta_BLUFOR", str _resDeltaBlufor] call RES_fnc_exportWrite;

    private _activeObjectKeys = [];
    {
        private _objKey = _x;
        private _record = RES_resourceObjectsSnapshot get _objKey;
        if (!isNil "_record") then {
            [RES_export_sectionObjects, _objKey, str _record] call RES_fnc_exportWrite;
            _activeObjectKeys pushBack _objKey;
        };
    } forEach (keys RES_resourceObjectsSnapshot);

    [RES_export_sectionMeta, "ActiveResourceObjectKeys", str _activeObjectKeys] call RES_fnc_exportWrite;

    private _eventKeys = [];
    {
        private _event = _x;
        private _eventKey = format ["EVT_%1_%2", RES_export_cycle, _forEachIndex + 1];
        [RES_export_sectionEvents, _eventKey, str _event] call RES_fnc_exportWrite;
        _eventKeys pushBack _eventKey;
    } forEach RES_lastCycleEvents;

    [RES_export_sectionMeta, "ActiveResourceEventKeys", str _eventKeys] call RES_fnc_exportWrite;

    RES_export_cycle = RES_export_cycle + 1;
    [RES_export_sectionMeta, "LastExportTime", time] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "UpdateInterval", RES_export_interval] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "FactionCount", count _activeFactions] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "ActiveFactions", str _activeFactions] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "ExportCycle", RES_export_cycle] call RES_fnc_exportWrite;
    [RES_export_sectionMeta, "ScenarioClosed", 0] call RES_fnc_exportWrite;

    true
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

// Get faction resources
RES_fnc_getResources = {
    params ["_faction"];
    RES_factionResources getOrDefault [_faction, [0, 0, 0, 0, 0]]
};

// Set specific resource amount
RES_fnc_setResource = {
    params ["_faction", "_resourceIndex", "_amount"];
    
    private _resources = [_faction] call RES_fnc_getResources;
    _resources set [_resourceIndex, _amount max 0]; // Prevent negative
    
    RES_factionResources set [_faction, _resources];
    publicVariable "RES_factionResources";
    
    private _resourceName = RES_resourceNames select _resourceIndex;
    systemChat format ["[Resources] %1 %2 set to %3", _faction, _resourceName, _amount];

    [] call RES_fnc_exportResourcesSnapshot;
};

// Add/subtract resources
RES_fnc_modifyResource = {
    params ["_faction", "_resourceIndex", "_amount"];
    
    private _resources = [_faction] call RES_fnc_getResources;
    private _current = _resources select _resourceIndex;
    private _new = (_current + _amount) max 0; // Prevent negative
    
    _resources set [_resourceIndex, _new];
    RES_factionResources set [_faction, _resources];
    publicVariable "RES_factionResources";
    
    private _resourceName = RES_resourceNames select _resourceIndex;
    private _change = if (_amount >= 0) then {format ["+%1", _amount]} else {format ["%1", _amount]};
    systemChat format ["[Resources] %1 %2 %3 (now %4)", _faction, _resourceName, _change, _new];

    [] call RES_fnc_exportResourcesSnapshot;
};

if (!RES_export_running) then {
    RES_export_running = true;
    [] spawn {
        while {RES_export_running} do {
            [] call RES_fnc_exportResourcesSnapshot;
            sleep RES_export_interval;
        };
    };
};

if (isNil "RES_export_endMissionEH") then {
    RES_export_endMissionEH = addMissionEventHandler ["Ended", {
        RES_export_running = false;
        if (!isNil "RES_iniDB") then {
            ["write", [RES_export_sectionMeta, "ScenarioClosed", 1]] call RES_iniDB;
        };
    }];
};

// ============================================================================
// BUILDING RESOURCE PRODUCTION SYSTEM
// ============================================================================

// Building types and their resource production
RES_buildingProduction = createHashMap;
RES_buildingProduction set ["Land_dp_transformer_F", [4, 10]];        // Electricity, 10 points
RES_buildingProduction set ["Land_DPP_01_smallFactory_F", [1, 8]];    // Supplies, 8 points
RES_buildingProduction set ["Land_Factory_Main_F", [0, 12]];          // Fuel, 12 points
RES_buildingProduction set ["Land_Factory_02_F", [2, 6]];             // Fabrication, 6 points
RES_buildingProduction set ["Land_i_Barracks_V2_F", [3, 20]];         // Manpower, 20 points

// Optional per-building destruction penalties (defaults to pointsPerBuilding * 10)
RES_buildingDestructionPenalty = createHashMap;
RES_buildingDestructionPenalty set ["Land_dp_transformer_F", 100];
RES_buildingDestructionPenalty set ["Land_DPP_01_smallFactory_F", 80];
RES_buildingDestructionPenalty set ["Land_Factory_Main_F", 120];
RES_buildingDestructionPenalty set ["Land_Factory_02_F", 60];
RES_buildingDestructionPenalty set ["Land_i_Barracks_V2_F", 200];

// Debug marker controls for resource objects
if (isNil "RES_debugObjectMarkers") then {
    RES_debugObjectMarkers = true;
};

if (isNil "RES_debugMarkerPrefix") then {
    RES_debugMarkerPrefix = "RES_OBJDBG_";
};

if (isNil "RES_debugMarkerDuration") then {
    RES_debugMarkerDuration = 20;
};

// Track building states (alive/destroyed)
if (isNil "RES_buildingStates") then {
    RES_buildingStates = createHashMap;
    publicVariable "RES_buildingStates";
};

// Get sector control using ALiVE (using proven logic from sectorMonitor.sqf)
RES_fnc_getSectorControl = {
    params ["_position"];
    
    // Check if ALiVE is available
    if (isNil "ALiVE_sectorGrid") exitWith {
        systemChat "[Resources] ALiVE Sector Grid not found!";
        "NONE"
    };
    
    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;
    
    // Check for valid sector
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {
        "NONE"
    };
    
    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (isNil "_sectorData" || count _sectorData == 0) exitWith {
        "NONE"
    };
    
    // Use the same logic as quickSectorInfo.sqf - check entities by side
    private _dominatingSide = "NONE";
    private _maxCount = 0;
    
    // Check entities by side (ALiVE profiles)
    if ("entitiesBySide" in (_sectorData select 1)) then {
        private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_entitiesBySide select 1)) then {
                private _sideEntities = [_entitiesBySide, _side] call ALIVE_fnc_hashGet;
                private _entityCount = count _sideEntities;
                
                if (_entityCount > _maxCount) then {
                    _maxCount = _entityCount;
                    _dominatingSide = _side;
                };
            };
        } forEach _sides;
    };
    
    // Also check vehicles by side
    if ("vehiclesBySide" in (_sectorData select 1)) then {
        private _vehiclesBySide = [_sectorData, "vehiclesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_vehiclesBySide select 1)) then {
                private _sideVehicles = [_vehiclesBySide, _side] call ALIVE_fnc_hashGet;
                private _vehicleCount = count _sideVehicles;
                
                // If this side already has entities, add vehicles to the count
                if (_side == _dominatingSide) then {
                    _maxCount = _maxCount + _vehicleCount;
                } else {
                    // If this side has more vehicles than current max, it takes control
                    if (_vehicleCount > _maxCount) then {
                        _maxCount = _vehicleCount;
                        _dominatingSide = _side;
                    };
                };
            };
        } forEach _sides;
    };
    
    // Convert ALiVE side names to our faction names
    private _result = switch (_dominatingSide) do {
        case "WEST": {"BLUFOR"};
        case "EAST": {"OPFOR"};
        case "GUER": {"INDEP"};
        default {"NONE"};
    };
    
    _result
};

// Find resource buildings around RES markers only (1km radius)
RES_fnc_findResourceBuildings = {
    private _resourceBuildings = createHashMap;
    private _scanRadius = 1000; // 1km radius
    
    // Initialize building type arrays
    {
        _resourceBuildings set [_x, []];
    } forEach (keys RES_buildingProduction);
    
    // Find all RES markers
    private _resMarkers = allMapMarkers select {_x find "RES" >= 0};
    
    if (count _resMarkers == 0) then {
        systemChat "[Resources] WARNING: No RES markers found! Please place RES markers near resource areas.";
    } else {
        systemChat format ["[Resources] Scanning around %1 RES markers (1km radius)...", count _resMarkers];
        
        // Scan around each RES marker
        {
            private _markerName = _x;
            private _markerPos = getMarkerPos _markerName;
            
            if (_markerPos distance [0,0,0] > 0) then {
                systemChat format ["[Resources] Scanning %1 at %2", _markerName, _markerPos];
                
                {
                    private _buildingType = _x;
                    private _nearBuildings = _markerPos nearObjects [_buildingType, _scanRadius];
                    
                    // Add to existing array (avoid duplicates)
                    private _existingBuildings = _resourceBuildings get _buildingType;
                    {
                        if (!(_x in _existingBuildings)) then {
                            _existingBuildings pushBack _x;
                        };
                    } forEach _nearBuildings;
                    
                    _resourceBuildings set [_buildingType, _existingBuildings];
                    
                } forEach (keys RES_buildingProduction);
            } else {
                systemChat format ["[Resources] WARNING: %1 marker has no position!", _markerName];
            };
            
        } forEach _resMarkers;
        
        // Show final counts
        {
            private _buildingType = _x;
            private _buildings = _resourceBuildings get _buildingType;
            systemChat format ["[Resources] Total %1 %2 buildings in RES areas", count _buildings, _buildingType];
        } forEach (keys RES_buildingProduction);
    };
    
    _resourceBuildings
};

// Remove all resource debug markers created by this script
RES_fnc_clearResourceDebugMarkers = {
    {
        if (_x find RES_debugMarkerPrefix == 0) then {
            deleteMarker _x;
        };
    } forEach allMapMarkers;
};

// Create or update a debug marker for a resource object with ownership info
RES_fnc_markResourceObject = {
    params ["_building", "_buildingType", "_owner", "_sourceMarker"];

    private _pos = getPosATL _building;
    private _markerName = format ["%1%2", RES_debugMarkerPrefix, str _building];

    // Recreate marker each tick after cleanup; deterministic name helps avoid duplicates per tick.
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_dot";
    _marker setMarkerSize [0.6, 0.6];

    private _markerColor = switch (_owner) do {
        case "BLUFOR": {"ColorBlue"};
        case "OPFOR": {"ColorRed"};
        case "INDEP": {"ColorGreen"};
        default {"ColorWhite"};
    };
    _marker setMarkerColor _markerColor;

    private _status = if ((damage _building < 0.9) && !isNull _building) then {"ALIVE"} else {"DESTROYED"};
    _marker setMarkerText format ["%1 | %2 | %3", _owner, _status, _sourceMarker];
};

// Production tick - assign buildings based on RES marker sector control
RES_fnc_productionTick = {
    systemChat "[Resources] Starting production tick - RES marker based...";

    // Refresh debug markers each tick so current ownership/status is visible.
    if (RES_debugObjectMarkers) then {
        [] call RES_fnc_clearResourceDebugMarkers;
    };
    
    // Get all RES markers and their sector control
    private _resMarkers = allMapMarkers select {_x find "RES" >= 0};
    
    if (count _resMarkers == 0) exitWith {
        systemChat "[Resources] No RES markers found - no production!";
    };
    
    // Initialize faction building counts
    private _factionBuildings = createHashMap;
    _factionBuildings set ["BLUFOR", createHashMap];
    _factionBuildings set ["OPFOR", createHashMap];

    // Per-cycle telemetry
    RES_lastCycleEvents = [];
    RES_lastCycleObjectDelta = createHashMap;
    RES_lastCycleResourceDelta = createHashMap;
    RES_lastCycleObjectDelta set ["BLUFOR", [] call RES_fnc_zeroResourceVector];
    RES_lastCycleObjectDelta set ["OPFOR", [] call RES_fnc_zeroResourceVector];
    RES_lastCycleResourceDelta set ["BLUFOR", [] call RES_fnc_zeroResourceVector];
    RES_lastCycleResourceDelta set ["OPFOR", [] call RES_fnc_zeroResourceVector];
    RES_resourceObjectsSnapshot = createHashMap;

    private _processedBuildings = createHashMap;
    
    {
        private _resourceType = _x;
        (_factionBuildings get "BLUFOR") set [_resourceType, 0];
        (_factionBuildings get "OPFOR") set [_resourceType, 0];
    } forEach (keys RES_buildingProduction);
    
    // Check each RES marker
    {
        private _markerName = _x;
        private _markerPos = getMarkerPos _markerName;
        
        if (_markerPos distance [0,0,0] > 0) then {
            // Get sector control for this RES marker
            private _sectorControl = [_markerPos] call RES_fnc_getSectorControl;
            systemChat format ["[Resources] %1 controlled by %2", _markerName, _sectorControl];
            
            // Only process if controlled by a faction
            if (_sectorControl in ["BLUFOR", "OPFOR"]) then {
                // Scan buildings around this marker
                {
                    private _buildingType = _x;
                    private _productionInfo = RES_buildingProduction get _buildingType;
                    _productionInfo params ["_resourceIndex", "_pointsPerBuilding"];
                    
                    private _buildings = _markerPos nearObjects [_buildingType, 1000];
                    private _aliveBuildings = 0;
                    private _destroyedBuildings = 0;
                    
                    // Check each building
                    {
                        private _building = _x;
                        private _buildingKey = str _building;
                        if (_processedBuildings getOrDefault [_buildingKey, false]) then { continue; };
                        _processedBuildings set [_buildingKey, true];

                        private _wasAlive = RES_buildingStates getOrDefault [_buildingKey, true];
                        private _isAlive = (damage _building < 0.9) && !isNull _building;
                        private _grid = mapGridPosition _building;

                        private _objExportKey = [_building] call RES_fnc_getObjectExportKey;
                        RES_resourceObjectsSnapshot set [_objExportKey, [
                            _buildingType,
                            _grid,
                            _sectorControl,
                            _isAlive,
                            _markerName,
                            _resourceIndex,
                            _pointsPerBuilding,
                            damage _building,
                            time
                        ]];

                        if (RES_debugObjectMarkers) then {
                            [_building, _buildingType, _sectorControl, _markerName] call RES_fnc_markResourceObject;
                        };
                        
                        // Check if building was just destroyed
                        if (_wasAlive && !_isAlive) then {
                            systemChat format ["[Resources] BUILDING DESTROYED: %1 at %2 (controlled by %3)", _buildingType, _markerName, _sectorControl];

                            // Penalize the controlling faction
                            private _deductAmount = RES_buildingDestructionPenalty getOrDefault [_buildingType, _pointsPerBuilding * 3];
                            [_sectorControl, _resourceIndex, -_deductAmount] call RES_fnc_modifyResource;
                            [RES_lastCycleResourceDelta, _sectorControl, _resourceIndex, -_deductAmount] call RES_fnc_addDelta;
                            [RES_lastCycleObjectDelta, _sectorControl, _resourceIndex, -_pointsPerBuilding] call RES_fnc_addDelta;

                            RES_lastCycleEvents pushBack [
                                "DESTROYED",
                                _sectorControl,
                                RES_resourceNames select _resourceIndex,
                                -_deductAmount,
                                _buildingType,
                                _grid,
                                _markerName,
                                time
                            ];
                            
                            _destroyedBuildings = _destroyedBuildings + 1;
                        };

                        if (!_wasAlive && _isAlive) then {
                            [RES_lastCycleObjectDelta, _sectorControl, _resourceIndex, _pointsPerBuilding] call RES_fnc_addDelta;
                            RES_lastCycleEvents pushBack [
                                "RESTORED",
                                _sectorControl,
                                RES_resourceNames select _resourceIndex,
                                _pointsPerBuilding,
                                _buildingType,
                                _grid,
                                _markerName,
                                time
                            ];
                        };
                        
                        // Update building state
                        RES_buildingStates set [_buildingKey, _isAlive];
                        
                        // Count alive buildings
                        if (_isAlive) then {
                            _aliveBuildings = _aliveBuildings + 1;
                        };
                        
                    } forEach _buildings;
                    
                    // Add to faction building count
                    if (_aliveBuildings > 0) then {
                        private _factionBuildingMap = _factionBuildings get _sectorControl;
                        private _currentCount = _factionBuildingMap get _buildingType;
                        _factionBuildingMap set [_buildingType, _currentCount + _aliveBuildings];
                        
                        systemChat format ["[Resources] %1: %2 x%3 %4 buildings assigned to %5", _markerName, _aliveBuildings, _buildingType, _pointsPerBuilding, _sectorControl];
                    };
                    
                } forEach (keys RES_buildingProduction);
            };
        };
    } forEach _resMarkers;
    
    // Generate resources based on faction building assignments
    {
        private _faction = _x;
        private _buildingMap = _factionBuildings get _faction;
        
        {
            private _buildingType = _x;
            private _buildingCount = _buildingMap get _buildingType;
            
            if (_buildingCount > 0) then {
                private _productionInfo = RES_buildingProduction get _buildingType;
                _productionInfo params ["_resourceIndex", "_pointsPerBuilding"];
                
                private _totalProduction = _buildingCount * _pointsPerBuilding;
                [_faction, _resourceIndex, _totalProduction] call RES_fnc_modifyResource;
                [RES_lastCycleResourceDelta, _faction, _resourceIndex, _totalProduction] call RES_fnc_addDelta;
            };
        } forEach (keys RES_buildingProduction);
        
    } forEach ["BLUFOR", "OPFOR"];

    if (RES_debugObjectMarkers) then {
        [RES_debugMarkerDuration] spawn {
            params ["_duration"];
            sleep _duration;
            [] call RES_fnc_clearResourceDebugMarkers;
        };
    };
    
    systemChat "[Resources] Production tick completed - RES marker based";

    // Export immediate post-cycle snapshot including events and deltas.
    [] call RES_fnc_exportResourcesSnapshot;
};

// ============================================================================
// HINT DISPLAY SYSTEM
// ============================================================================

// Display resource status using hint (like monitor_supplies_testbed)
RES_fnc_showResourceStatus = {
    private _bluResources = ["BLUFOR"] call RES_fnc_getResources;
    private _opfResources = ["OPFOR"] call RES_fnc_getResources;
    
    // Create formatted hint text
    private _hintText = "<t size='1.4' color='#ffff00'>FACTION RESOURCE STATUS</t><br/><br/>";
    
    // BLUFOR Resources
    _hintText = _hintText + "<t size='1.2' color='#0080ff'>BLUFOR RESOURCES</t><br/>";
    {
        private _resourceName = RES_resourceNames select _forEachIndex;
        private _amount = _x;
        private _color = if (_amount < 100) then {"#ff4040"} else {"#ffffff"};
        _hintText = _hintText + format ["<t size='0.9' color='%1'>%2: %3</t><br/>", _color, _resourceName, _amount];
    } forEach _bluResources;
    
    _hintText = _hintText + "<br/>";
    
    // OPFOR Resources
    _hintText = _hintText + "<t size='1.2' color='#ff4040'>OPFOR RESOURCES</t><br/>";
    {
        private _resourceName = RES_resourceNames select _forEachIndex;
        private _amount = _x;
        private _color = if (_amount < 100) then {"#ff4040"} else {"#ffffff"};
        _hintText = _hintText + format ["<t size='0.9' color='%1'>%2: %3</t><br/>", _color, _resourceName, _amount];
    } forEach _opfResources;
    
    // Add summary
    _hintText = _hintText + "<br/><t size='1.0' color='#00ff00'>RESOURCE SUMMARY</t><br/>";
    
    private _bluTotal = 0;
    private _opfTotal = 0;
    {_bluTotal = _bluTotal + _x} forEach _bluResources;
    {_opfTotal = _opfTotal + _x} forEach _opfResources;
    
    _hintText = _hintText + format ["<t size='0.9'>BLUFOR Total: %1</t><br/>", _bluTotal];
    _hintText = _hintText + format ["<t size='0.9'>OPFOR Total: %1</t><br/>", _opfTotal];
    
    // Show who has advantage
    if (_bluTotal > _opfTotal) then {
        _hintText = _hintText + "<t size='0.9' color='#0080ff'>BLUFOR Advantage</t>";
    } else {
        if (_opfTotal > _bluTotal) then {
            _hintText = _hintText + "<t size='0.9' color='#ff4040'>OPFOR Advantage</t>";
        } else {
            _hintText = _hintText + "<t size='0.9' color='#ffff00'>Equal Resources</t>";
        };
    };
    
    // Display the hint
    hint parseText _hintText;
    
    // Also output to console for logging
    systemChat "=== RESOURCE STATUS ===";
    systemChat format ["BLUFOR: Fuel=%1, Supplies=%2, Fabrication=%3, Manpower=%4, Electricity=%5", 
        _bluResources select 0, _bluResources select 1, _bluResources select 2, 
        _bluResources select 3, _bluResources select 4];
    systemChat format ["OPFOR: Fuel=%1, Supplies=%2, Fabrication=%3, Manpower=%4, Electricity=%5", 
        _opfResources select 0, _opfResources select 1, _opfResources select 2, 
        _opfResources select 3, _opfResources select 4];
};

// ============================================================================
// TEST COMMANDS
// ============================================================================

// Test command: Add resources
// Usage: ["BLUFOR", 0, 100] call RES_fnc_testAdd; // Add 100 fuel to BLUFOR
RES_fnc_testAdd = {
    params ["_faction", "_resourceIndex", "_amount"];
    [_faction, _resourceIndex, _amount] call RES_fnc_modifyResource;
    [] call RES_fnc_showResourceStatus;
};

// Test command: Subtract resources  
// Usage: ["OPFOR", 1, 50] call RES_fnc_testSub; // Remove 50 supplies from OPFOR
RES_fnc_testSub = {
    params ["_faction", "_resourceIndex", "_amount"];
    [_faction, _resourceIndex, -_amount] call RES_fnc_modifyResource;
    [] call RES_fnc_showResourceStatus;
};

// Test command: Set resource to specific amount
// Usage: ["BLUFOR", 2, 500] call RES_fnc_testSet; // Set BLUFOR fabrication to 500
RES_fnc_testSet = {
    params ["_faction", "_resourceIndex", "_amount"];
    [_faction, _resourceIndex, _amount] call RES_fnc_setResource;
    [] call RES_fnc_showResourceStatus;
};

// Quick status display
RES_fnc_showStatus = {
    [] call RES_fnc_showResourceStatus;
};

// ============================================================================
// INITIALIZATION
// ============================================================================

// Make functions public
publicVariable "RES_fnc_getResources";
publicVariable "RES_fnc_setResource";
publicVariable "RES_fnc_modifyResource";
publicVariable "RES_fnc_showResourceStatus";
publicVariable "RES_fnc_testAdd";
publicVariable "RES_fnc_testSub";
publicVariable "RES_fnc_testSet";
publicVariable "RES_fnc_showStatus";
publicVariable "RES_fnc_findResourceBuildings";
publicVariable "RES_fnc_productionTick";
publicVariable "RES_fnc_getSectorControl";
publicVariable "RES_fnc_clearResourceDebugMarkers";
publicVariable "RES_fnc_markResourceObject";
publicVariable "RES_fnc_exportResourcesSnapshot";
publicVariable "RES_buildingProduction";
publicVariable "RES_buildingDestructionPenalty";

// Start production loop (every 5 minutes)
[] spawn {
    while {true} do {
        sleep 300; // 5 minutes
        [] call RES_fnc_productionTick;
    };
};

// Show initial status
[] call RES_fnc_showResourceStatus;

systemChat "[Resources] Basic Resource System initialized!";
systemChat "[Resources] RES marker-based production active - 5 minute intervals";
systemChat "[Resources] Place RES markers near industrial areas for resource generation";
systemChat "Use [] call RES_fnc_showStatus to view resources";
systemChat "Resource indices: 0=Fuel, 1=Supplies, 2=Fabrication, 3=Manpower, 4=Electricity";
systemChat "Buildings assigned to factions based on RES marker sector control";

diag_log "[Resources] Basic Resource System fully initialized";

// Show initial status and run first production tick after 10 seconds
[] spawn {
    sleep 10;
    [] call RES_fnc_productionTick;
    [] call RES_fnc_showStatus;
};