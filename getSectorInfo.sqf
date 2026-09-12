/*
 * ALiVE Sector Information Script
 * 
 * Description: Gets detailed information about the ALiVE sector the player is currently in
 * Usage: Execute this script in-game to get sector information
 * 
 * Run with: execVM "getSectorInfo.sqf" or [] execVM "getSectorInfo.sqf"
 * 
 * Author: GitHub Copilot Assistant
 * Version: 1.0
 */

// Wait for ALiVE to initialize
if (isNil "ALiVE_sectorGrid") then {
    systemChat "ALiVE Sector Grid not found! Make sure ALiVE is loaded and initialized.";
    hint "ALiVE Sector Grid not found! Make sure ALiVE is loaded and initialized.";
    exitWith {};
};

// Get player position
private _playerPos = getPosATL player;
systemChat format ["Getting sector info for position: %1", _playerPos];

// Get the sector the player is in
private _sector = [ALiVE_sectorGrid, "positionToSector", _playerPos] call ALIVE_fnc_sectorGrid;

// Check if we found a valid sector
if (count _sector == 0 || {count (_sector select 1) == 0}) then {
    systemChat "No valid sector found at player position!";
    hint "No valid sector found at player position!";
    exitWith {};
};

// Extract basic sector information
private _sectorID = [_sector, "id"] call ALIVE_fnc_sector;
private _sectorCenter = [_sector, "center"] call ALIVE_fnc_sector;
private _sectorBounds = [_sector, "bounds"] call ALIVE_fnc_sector;
private _sectorDimensions = [_sector, "dimensions"] call ALIVE_fnc_sector;
private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;

// Basic sector info
systemChat "=== SECTOR INFORMATION ===";
systemChat format ["Sector ID: %1", _sectorID];
systemChat format ["Sector Center: %1", _sectorCenter];
systemChat format ["Sector Dimensions: %1 x %2", (_sectorDimensions select 0) * 2, (_sectorDimensions select 1) * 2];

// Calculate distance to sector center
private _distanceToCenter = _playerPos distance2D _sectorCenter;
systemChat format ["Distance to Center: %1m", round _distanceToCenter];

// Check sector data for various information
if (count _sectorData > 0) then {
    systemChat "=== SECTOR DATA ===";
    
    // Check for terrain type
    if ("terrain" in (_sectorData select 1)) then {
        private _terrainType = [_sectorData, "terrain"] call ALIVE_fnc_hashGet;
        systemChat format ["Terrain Type: %1", _terrainType];
    };
    
    // Check for elevation data
    if ("elevation" in (_sectorData select 1)) then {
        private _elevationData = [_sectorData, "elevation"] call ALIVE_fnc_hashGet;
        if (count _elevationData > 0) then {
            private _avgElevation = 0;
            {
                _avgElevation = _avgElevation + (_x select 1);
            } forEach _elevationData;
            _avgElevation = _avgElevation / (count _elevationData);
            systemChat format ["Average Elevation: %1m", round _avgElevation];
        };
    };
    
    // Check for military clusters/infrastructure
    if ("clustersMil" in (_sectorData select 1)) then {
        private _milClusters = [_sectorData, "clustersMil"] call ALIVE_fnc_hashGet;
        if (count _milClusters > 0) then {
            systemChat format ["Military Infrastructure: %1 clusters found", count _milClusters];
        } else {
            systemChat "Military Infrastructure: None";
        };
    } else {
        systemChat "Military Infrastructure: No data";
    };
    
    // Check for civilian clusters/infrastructure
    if ("clustersCiv" in (_sectorData select 1)) then {
        private _civClusters = [_sectorData, "clustersCiv"] call ALIVE_fnc_hashGet;
        if (count _civClusters > 0) then {
            systemChat format ["Civilian Infrastructure: %1 clusters found", count _civClusters];
        } else {
            systemChat "Civilian Infrastructure: None";
        };
    } else {
        systemChat "Civilian Infrastructure: No data";
    };
    
    // Check for roads
    if ("roads" in (_sectorData select 1)) then {
        private _roadData = [_sectorData, "roads"] call ALIVE_fnc_hashGet;
        if (count _roadData > 0) then {
            systemChat format ["Roads: %1 road segments found", count _roadData];
        } else {
            systemChat "Roads: None";
        };
    } else {
        systemChat "Roads: No data";
    };
    
    // Check for units (if any)
    if ("units" in (_sectorData select 1)) then {
        private _unitData = [_sectorData, "units"] call ALIVE_fnc_hashGet;
        systemChat "=== UNIT PRESENCE ===";
        
        // Check for each side
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        {
            private _side = _x;
            if (_side in (_unitData select 1)) then {
                private _sideUnits = [_unitData, _side] call ALIVE_fnc_hashGet;
                if (count _sideUnits > 0) then {
                    systemChat format ["%1 Forces: %2 units", _side, count _sideUnits];
                };
            };
        } forEach _sides;
    };
    
    // Check for active players
    if ("active" in (_sectorData select 1)) then {
        private _activeData = [_sectorData, "active"] call ALIVE_fnc_hashGet;
        if (count _activeData > 0) then {
            systemChat format ["Active Players in Sector: %1", count _activeData];
        };
    };
    
} else {
    systemChat "No detailed sector data available.";
};

// Check sector ownership through ALiVE profile system
systemChat "=== SECTOR OWNERSHIP ===";

// Check for profile-based sector control
private _sectorOwnership = "Neutral";
private _dominatingSide = "None";
private _entityCounts = [] call ALIVE_fnc_hashCreate;
private _vehicleCounts = [] call ALIVE_fnc_hashCreate;

if (count _sectorData > 0) then {
    // Check entities by side (ALiVE profiles)
    if ("entitiesBySide" in (_sectorData select 1)) then {
        private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_entitiesBySide select 1)) then {
                private _sideEntities = [_entitiesBySide, _side] call ALIVE_fnc_hashGet;
                [_entityCounts, _side, count _sideEntities] call ALIVE_fnc_hashSet;
                systemChat format ["%1 Entities: %2", _side, count _sideEntities];
            };
        } forEach _sides;
    };
    
    // Check vehicles by side
    if ("vehiclesBySide" in (_sectorData select 1)) then {
        private _vehiclesBySide = [_sectorData, "vehiclesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_vehiclesBySide select 1)) then {
                private _sideVehicles = [_vehiclesBySide, _side] call ALIVE_fnc_hashGet;
                [_vehicleCounts, _side, count _sideVehicles] call ALIVE_fnc_hashSet;
                systemChat format ["%1 Vehicles: %2", _side, count _sideVehicles];
            };
        } forEach _sides;
    };
    
    // Determine dominating side based on total presence
    private _sides = ["EAST", "WEST", "GUER", "CIV"];
    private _maxCount = 0;
    private _totalCounts = [] call ALIVE_fnc_hashCreate;
    
    {
        private _side = _x;
        private _entityCount = [_entityCounts, _side, 0] call ALIVE_fnc_hashGet;
        private _vehicleCount = [_vehicleCounts, _side, 0] call ALIVE_fnc_hashGet;
        private _totalCount = _entityCount + _vehicleCount;
        
        [_totalCounts, _side, _totalCount] call ALIVE_fnc_hashSet;
        
        if (_totalCount > _maxCount) then {
            _maxCount = _totalCount;
            _dominatingSide = _side;
        };
    } forEach _sides;
    
    if (_maxCount > 0) then {
        _sectorOwnership = format ["%1 Controlled", _dominatingSide];
        systemChat format ["Sector dominated by: %1 (Total: %2 units)", _dominatingSide, _maxCount];
    };
};

// Also check for OPCOM objectives in this sector
private _objectiveFound = false;
if (!isNil "OPCOM_instances") then {
    {
        private _opcom = _x;
        private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
        private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;
        private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
        
        {
            private _objective = _x;
            private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
            private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
            private _objType = [_objective, "objectiveType", "unknown"] call ALIVE_fnc_hashGet;
            private _objSize = [_objective, "size", 0] call ALIVE_fnc_hashGet;
            
            // Check if objective is in this sector
            if ([_sector, "within", _objCenter] call ALIVE_fnc_sector) then {
                _objectiveFound = true;
                systemChat format ["OPCOM Objective: %1 (%2)", _objType, _objState];
                systemChat format ["Assigned to: %1 (%2)", _opcomSide, _opcomFactions joinString ", "];
                systemChat format ["Distance: %1m", round (_playerPos distance2D _objCenter)];
            };
        } forEach _objectives;
    } forEach OPCOM_instances;
};

systemChat format ["Sector Control Status: %1", _sectorOwnership];

// Show comprehensive hint with key information
private _hintText = format [
    "SECTOR: %1<br/>Position: %2<br/>Center: %3<br/>Size: %4x%5m<br/>Distance to Center: %6m",
    _sectorID,
    mapGridPosition _playerPos,
    mapGridPosition _sectorCenter,
    round ((_sectorDimensions select 0) * 2),
    round ((_sectorDimensions select 1) * 2),
    round _distanceToCenter
];

// Add terrain info if available
if (count _sectorData > 0 && {"terrain" in (_sectorData select 1)}) then {
    private _terrainType = [_sectorData, "terrain"] call ALIVE_fnc_hashGet;
    _hintText = _hintText + format ["<br/>Terrain: %1", _terrainType];
};

hint parseText _hintText;

systemChat "=== END SECTOR INFO ===";