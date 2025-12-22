/*
 * ALiVE Quick Sector Info
 * 
 * Description: Lightweight sector information script for quick reference
 * Usage: Add to player init, radio trigger, or execute directly
 * 
 * Add to player init:
 * player addAction ["Get Sector Info", {execVM "quickSectorInfo.sqf";}];
 * 
 * Or run directly:
 * [] execVM "quickSectorInfo.sqf"
 * 
 * Author: GitHub Copilot Assistant
 * Version: 1.0
 */

// Quick sector info function
private _fnc_quickSectorInfo = {
    // Check if ALiVE is available
    if (isNil "ALiVE_sectorGrid") exitWith {
        hint "ALiVE not loaded!";
        false
    };
    
    private _playerPos = getPosATL player;
    private _sector = [ALiVE_sectorGrid, "positionToSector", _playerPos] call ALIVE_fnc_sectorGrid;
    
    // Check for valid sector
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {
        hint "No sector found!";
        false
    };
    
    // Get basic info with error checking
    private _sectorID = [_sector, "id"] call ALIVE_fnc_sector;
    if (isNil "_sectorID" || _sectorID == "") then { _sectorID = "Unknown" };
    
    private _sectorCenter = [_sector, "center"] call ALIVE_fnc_sector;
    if (isNil "_sectorCenter") then { _sectorCenter = _playerPos };
    
    private _sectorDimensions = [_sector, "dimensions"] call ALIVE_fnc_sector;
    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (isNil "_sectorData") then { _sectorData = [] };
    
    // Quick analysis with safety check
    private _terrainType = if (count _sectorData > 0 && {"terrain" in (_sectorData select 1)}) then {
        private _terrain = [_sectorData, "terrain"] call ALIVE_fnc_hashGet;
        if (isNil "_terrain" || _terrain == "") then { "Unknown" } else { _terrain }
    } else {
        "Unknown"
    };
    
    // Check for OPCOM control AND ALiVE profile-based sector domination
    private _controlInfo = "Neutral";
    private _objectiveCount = 0;
    
    // First check ALiVE profile-based sector control (this is the real sector domination)
    if (count _sectorData > 0) then {
        private _dominatingSide = "None";
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
                        // If this side has more total presence, it becomes the new dominating side
                        if (_vehicleCount > _maxCount) then {
                            _maxCount = _vehicleCount;
                            _dominatingSide = _side;
                        };
                    };
                };
            } forEach _sides;
        };
        
        if (_maxCount > 0) then {
            _controlInfo = format ["%1 Controlled", _dominatingSide];
        };
    };
    
    // Fallback: Check OPCOM objectives if no profile-based control found
    if (_controlInfo == "Neutral" && !isNil "OPCOM_instances") then {
        {
            private _opcom = _x;
            private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
            private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                
                // Check if objective is in this sector
                if ([_sector, "within", _objCenter] call ALIVE_fnc_sector) then {
                    private _objType = [_objective, "objectiveType", "unknown"] call ALIVE_fnc_hashGet;
                    private _objSize = [_objective, "size", 0] call ALIVE_fnc_hashGet;
                    private _objOrders = [_objective, "opcom_orders", "none"] call ALIVE_fnc_hashGet;
                    private _objPriority = [_objective, "priority", 0] call ALIVE_fnc_hashGet;
                    private _objID = [_objective, "objectiveID", "unknown"] call ALIVE_fnc_hashGet;
                    
                    _objectiveCount = _objectiveCount + 1;
                    
                    // Get detailed objective installation info
                    private _installations = [];
                    private _factory = [_objective, "factory", []] call ALIVE_fnc_hashGet;
                    private _HQ = [_objective, "HQ", []] call ALIVE_fnc_hashGet;
                    private _depot = [_objective, "depot", []] call ALIVE_fnc_hashGet;
                    private _ambush = [_objective, "ambush", []] call ALIVE_fnc_hashGet;
                    private _sabotage = [_objective, "sabotage", []] call ALIVE_fnc_hashGet;
                    private _ied = [_objective, "ied", []] call ALIVE_fnc_hashGet;
                    private _roadblocks = [_objective, "roadblocks", []] call ALIVE_fnc_hashGet;
                    
                    if (count _factory > 0) then { _installations pushBack "Factory" };
                    if (count _HQ > 0) then { _installations pushBack "HQ" };
                    if (count _depot > 0) then { _installations pushBack "Depot" };
                    if (count _ambush > 0) then { _installations pushBack "Ambush" };
                    if (count _sabotage > 0) then { _installations pushBack "Sabotage" };
                    if (count _ied > 0) then { _installations pushBack "IED" };
                    if (count _roadblocks > 0) then { _installations pushBack "Roadblocks" };
                    
                    private _installationText = if (count _installations > 0) then {
                        _installations joinString ", "
                    } else {
                        "None"
                    };
                    
                    // Determine strategic importance level
                    private _strategicLevel = "Low";
                    if (_objPriority > 50) then {
                        _strategicLevel = "Critical";
                    } else {
                        if (_objPriority > 30) then {
                            _strategicLevel = "High";
                        } else {
                            if (_objPriority > 10) then {
                                _strategicLevel = "Medium";
                            };
                        };
                    };
                    
                    systemChat "=== OPCOM OBJECTIVE DEBUG ===";
                    systemChat format ["Objective ID: %1", _objID];
                    systemChat format ["Owner: %1 (%2)", _opcomSide, _opcomFactions joinString ", "];
                    systemChat format ["Type: %1 | Size: %2m", _objType, _objSize];
                    systemChat format ["State: %1 | Orders: %2", _objState, _objOrders];
                    systemChat format ["Strategic Priority: %1 (%2)", _objPriority, _strategicLevel];
                    systemChat format ["Installations: %1", _installationText];
                    systemChat format ["Distance: %1m", round (_playerPos distance2D _objCenter)];
                    
                    _controlInfo = format ["%1 Controlled (OPCOM)", _opcomSide];
                };
            } forEach _objectives;
        } forEach OPCOM_instances;
    };
    
    // Check for infrastructure
    private _infraInfo = "";
    if (count _sectorData > 0) then {
        private _hasMil = if ("clustersMil" in (_sectorData select 1)) then {
            private _milClusters = [_sectorData, "clustersMil"] call ALIVE_fnc_hashGet;
            count _milClusters > 0
        } else {
            false
        };
        
        private _hasCiv = if ("clustersCiv" in (_sectorData select 1)) then {
            private _civClusters = [_sectorData, "clustersCiv"] call ALIVE_fnc_hashGet;
            count _civClusters > 0
        } else {
            false
        };
        
        private _hasRoads = if ("roads" in (_sectorData select 1)) then {
            private _roadData = [_sectorData, "roads"] call ALIVE_fnc_hashGet;
            count _roadData > 0
        } else {
            false
        };
        
        private _infraTypes = [];
        if (_hasMil) then { _infraTypes pushBack "Military" };
        if (_hasCiv) then { _infraTypes pushBack "Civilian" };
        if (_hasRoads) then { _infraTypes pushBack "Roads" };
        
        _infraInfo = if (count _infraTypes > 0) then {
            _infraTypes joinString ", "
        } else {
            "None"
        };
    } else {
        _infraInfo = "No data";
    };
    
    // Calculate distance to center
    private _distance = round (_playerPos distance2D _sectorCenter);
    
    // Display quick info
    private _hintText = format [
        "<t size='1.4' color='#00ff00'>SECTOR %1</t><br/><br/>" +
        "<t size='1.0'>Grid: %2</t><br/>" +
        "<t size='1.0'>Control: %3</t><br/>" +
        "<t size='1.0'>Terrain: %4</t><br/>" +
        "<t size='1.0'>Infrastructure: %5</t><br/>" +
        "<t size='1.0'>Distance to Center: %6m</t>",
        _sectorID,
        mapGridPosition _playerPos,
        _controlInfo,
        _terrainType,
        _infraInfo,
        _distance
    ];
    
    if (_objectiveCount > 0) then {
        _hintText = _hintText + format ["<br/><t size='1.0' color='#ffaa00'>Objectives: %1</t>", _objectiveCount];
    };
    
    hint parseText _hintText;
    
    // Also log to chat for quick reference
    systemChat format ["Sector %1 | %2 | %3 | %4m to center", _sectorID, _controlInfo, _terrainType, _distance];
    
    true
;};

// Execute the function
[] call _fnc_quickSectorInfo;