/*
 * ALiVE Sector Monitor - Advanced Version
 * 
 * Description: Advanced sector monitoring script with visual markers and continuous updates
 * Usage: Execute this script in-game for enhanced sector information with markers
 * 
 * Run with: [] execVM "sectorMonitor.sqf"
 * 
 * Features:
 * - Visual markers for sector boundaries
 * - Continuous monitoring (optional)
 * - Detailed OPCOM information
 * - Surrounding sector analysis
 * 
 * Author: GitHub Copilot Assistant
 * Version: 1.0
 */

params [
    ["_continuous", false], // Set to true for continuous monitoring
    ["_showMarkers", true], // Set to false to disable visual markers
    ["_updateInterval", 5]  // Update interval in seconds for continuous mode
];

// Function to clean up markers
private _fnc_cleanupMarkers = {
    {
        if (markerText _x find "SECTOR_INFO_" == 0) then {
            deleteMarker _x;
        };
    } forEach allMapMarkers;
};

// Function to get detailed sector information
private _fnc_getSectorInfo = {
    params ["_playerPos"];
    
    // Wait for ALiVE to initialize
    if (isNil "ALiVE_sectorGrid") exitWith {
        systemChat "ALiVE Sector Grid not found! Make sure ALiVE is loaded and initialized.";
        false
    };
    
    // Get the sector the player is in
    private _sector = [ALiVE_sectorGrid, "positionToSector", _playerPos] call ALIVE_fnc_sectorGrid;
    
    // Check if we found a valid sector
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {
        systemChat "No valid sector found at player position!";
        false
    };
    
    // Extract basic sector information
    private _sectorID = [_sector, "id"] call ALIVE_fnc_sector;
    private _sectorCenter = [_sector, "center"] call ALIVE_fnc_sector;
    private _sectorBounds = [_sector, "bounds"] call ALIVE_fnc_sector;
    private _sectorDimensions = [_sector, "dimensions"] call ALIVE_fnc_sector;
    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    
    // Create visual markers if requested
    if (_showMarkers) then {
        // Clean up old markers first
        call _fnc_cleanupMarkers;
        
        // Create sector boundary marker
        private _markerName = format ["SECTOR_INFO_BOUNDARY_%1", _sectorID];
        private _marker = createMarker [_markerName, _sectorCenter];
        _marker setMarkerShape "RECTANGLE";
        _marker setMarkerSize [(_sectorDimensions select 0), (_sectorDimensions select 1)];
        _marker setMarkerColor "ColorYellow";
        _marker setMarkerBrush "Border";
        _marker setMarkerAlpha 0.8;
        
        // Create sector center marker
        private _centerMarker = createMarker [format ["SECTOR_INFO_CENTER_%1", _sectorID], _sectorCenter];
        _centerMarker setMarkerType "mil_dot";
        _centerMarker setMarkerColor "ColorYellow";
        _centerMarker setMarkerText format ["Sector %1", _sectorID];
        _centerMarker setMarkerSize [0.8, 0.8];
        
        // Create player position marker
        private _playerMarker = createMarker [format ["SECTOR_INFO_PLAYER_%1", time], _playerPos];
        _playerMarker setMarkerType "mil_triangle";
        _playerMarker setMarkerColor "ColorBlue";
        _playerMarker setMarkerText "YOU";
        _playerMarker setMarkerSize [1, 1];
    };
    
    // Display information
    systemChat "=== ALIVE SECTOR MONITOR ===";
    systemChat format ["Sector ID: %1", _sectorID];
    systemChat format ["Grid Position: %1", mapGridPosition _playerPos];
    systemChat format ["Sector Center: %1 (%2)", mapGridPosition _sectorCenter, _sectorCenter];
    
    // Calculate sector size and player position within it
    private _sectorWidth = (_sectorDimensions select 0) * 2;
    private _sectorHeight = (_sectorDimensions select 1) * 2;
    private _distanceToCenter = _playerPos distance2D _sectorCenter;
    systemChat format ["Sector Size: %1m x %2m", round _sectorWidth, round _sectorHeight];
    systemChat format ["Distance to Center: %1m", round _distanceToCenter];
    
    // Analyze sector data
    private _terrainType = "Unknown";
    private _hasInfrastructure = false;
    private _hasRoads = false;
    private _unitPresence = "";
    
    if (count _sectorData > 0) then {
        systemChat "=== SECTOR ANALYSIS ===";
        
        // Terrain analysis
        if ("terrain" in (_sectorData select 1)) then {
            _terrainType = [_sectorData, "terrain"] call ALIVE_fnc_hashGet;
            systemChat format ["Terrain Type: %1", _terrainType];
        };
        
        // Infrastructure analysis
        private _infraCount = 0;
        if ("clustersMil" in (_sectorData select 1)) then {
            private _milClusters = [_sectorData, "clustersMil"] call ALIVE_fnc_hashGet;
            if (count _milClusters > 0) then {
                _hasInfrastructure = true;
                _infraCount = _infraCount + count _milClusters;
                systemChat format ["Military Infrastructure: %1 installations", count _milClusters];
                
                // Show details of military installations
                private _installationTypes = [];
                {
                    private _clusterData = _x;
                    if (typeName _clusterData == "ARRAY" && count _clusterData > 0) then {
                        private _type = if (count _clusterData > 2) then { _clusterData select 2 } else { "Unknown" };
                        if (!(_type in _installationTypes)) then {
                            _installationTypes pushBack _type;
                        };
                    };
                } forEach _milClusters;
                if (count _installationTypes > 0) then {
                    systemChat format ["Installation Types: %1", _installationTypes joinString ", "];
                };
            };
        };
        
        if ("clustersCiv" in (_sectorData select 1)) then {
            private _civClusters = [_sectorData, "clustersCiv"] call ALIVE_fnc_hashGet;
            if (count _civClusters > 0) then {
                _hasInfrastructure = true;
                _infraCount = _infraCount + count _civClusters;
                systemChat format ["Civilian Infrastructure: %1 settlements", count _civClusters];
            };
        };
        
        // Road analysis
        if ("roads" in (_sectorData select 1)) then {
            private _roadData = [_sectorData, "roads"] call ALIVE_fnc_hashGet;
            if (count _roadData > 0) then {
                _hasRoads = true;
                systemChat format ["Road Network: %1 segments", count _roadData];
            };
        };
        
        // Unit presence analysis
        if ("units" in (_sectorData select 1)) then {
            private _unitData = [_sectorData, "units"] call ALIVE_fnc_hashGet;
            private _sides = ["EAST", "WEST", "GUER", "CIV"];
            private _presenceList = [];
            
            {
                private _side = _x;
                if (_side in (_unitData select 1)) then {
                    private _sideUnits = [_unitData, _side] call ALIVE_fnc_hashGet;
                    if (count _sideUnits > 0) then {
                        _presenceList pushBack format ["%1:%2", _side, count _sideUnits];
                    };
                };
            } forEach _sides;
            
            if (count _presenceList > 0) then {
                _unitPresence = _presenceList joinString " | ";
                systemChat format ["Unit Presence: %1", _unitPresence];
            };
        };
        
        // Strategic value assessment
        private _strategicValue = "Low";
        if (_hasInfrastructure && _hasRoads) then {
            _strategicValue = "High";
        } else {
            if (_hasInfrastructure || _hasRoads) then {
                _strategicValue = "Medium";
            };
        };
        systemChat format ["Strategic Value: %1", _strategicValue];
    };
    
    // OPCOM Analysis
    systemChat "=== OPCOM CONTROL ANALYSIS ===";
    private _controllingFaction = "None";
    private _controlStatus = "Neutral";
    private _objectiveCount = 0;
    
    if (!isNil "OPCOM_instances" && count OPCOM_instances > 0) then {
        private _objectivesInSector = [];
        
        {
            private _opcom = _x;
            private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
            private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                
                // Check if objective is in this sector
                if ([_sector, "within", _objCenter] call ALIVE_fnc_sector) then {
                    private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                    private _objType = [_objective, "objectiveType", "unknown"] call ALIVE_fnc_hashGet;
                    private _objSize = [_objective, "size", 0] call ALIVE_fnc_hashGet;
                    private _objID = [_objective, "objectiveID", "unknown"] call ALIVE_fnc_hashGet;
                    
                    _objectivesInSector pushBack _objective;
                    _objectiveCount = _objectiveCount + 1;
                    
                    systemChat format ["Objective %1: %2 (%3)", _objID, _objType, _objState];
                    systemChat format ["  Controlled by: %1 (%2)", _opcomSide, _opcomFactions joinString ", "];
                    systemChat format ["  Size: %1m | Distance: %2m", _objSize, round (_playerPos distance2D _objCenter)];
                    
                    // Determine controlling faction (last one wins for simplicity)
                    if (_objState in ["defend", "defending", "reserve"]) then {
                        _controllingFaction = _opcomFactions joinString ", ";
                        _controlStatus = format ["%1 Controlled", _opcomSide];
                    };
                    
                    // Create marker for objective if markers are enabled
                    if (_showMarkers) then {
                        private _objMarker = createMarker [format ["SECTOR_INFO_OBJ_%1_%2", _objID, time], _objCenter];
                        _objMarker setMarkerType "mil_objective";
                        _objMarker setMarkerColor (switch (_opcomSide) do {
                            case "WEST": {"ColorBlue"};
                            case "EAST": {"ColorRed"};
                            case "GUER": {"ColorGreen"};
                            default {"ColorOrange"};
                        });
                        _objMarker setMarkerText format ["%1 (%2)", _objID, _objState];
                        _objMarker setMarkerSize [1.2, 1.2];
                    };
                };
            } forEach _objectives;
        } forEach OPCOM_instances;
        
        if (_objectiveCount == 0) then {
            systemChat "No OPCOM objectives in this sector";
        };
    } else {
        systemChat "No OPCOM instances found";
    };
    
    // Summary
    systemChat "=== SECTOR SUMMARY ===";
    systemChat format ["Control: %1", _controlStatus];
    systemChat format ["Terrain: %1", _terrainType];
    systemChat format ["Objectives: %1", _objectiveCount];
    if (_unitPresence != "") then {
        systemChat format ["Forces: %1", _unitPresence];
    };
    
    // Create comprehensive hint
    private _hintText = format [
        "<t size='1.2' color='#ffff00'>SECTOR %1</t><br/>" +
        "<t size='0.9'>Grid: %2</t><br/>" +
        "<t size='0.9'>Control: %3</t><br/>" +
        "<t size='0.9'>Terrain: %4</t><br/>" +
        "<t size='0.9'>Size: %5x%6m</t><br/>" +
        "<t size='0.9'>Distance to Center: %7m</t>",
        _sectorID,
        mapGridPosition _playerPos,
        _controlStatus,
        _terrainType,
        round _sectorWidth,
        round _sectorHeight,
        round _distanceToCenter
    ];
    
    if (_objectiveCount > 0) then {
        _hintText = _hintText + format ["<br/><t size='0.9' color='#ff9900'>Objectives: %1</t>", _objectiveCount];
    };
    
    hint parseText _hintText;
    
    true
};

// Main execution
systemChat "ALiVE Sector Monitor initialized...";

if (_continuous) then {
    systemChat format ["Continuous monitoring enabled (update every %1s)", _updateInterval];
    systemChat "To stop monitoring, restart the mission or execute: missionNamespace setVariable ['SECTOR_MONITOR_STOP', true];";
    
    // Continuous monitoring loop
    [] spawn {
        while {isNil {missionNamespace getVariable "SECTOR_MONITOR_STOP"}} do {
            [getPosATL player] call _fnc_getSectorInfo;
            sleep _updateInterval;
        };
        
        // Cleanup on stop
        call _fnc_cleanupMarkers;
        systemChat "Sector monitoring stopped.";
    };
} else {
    // Single execution
    [getPosATL player] call _fnc_getSectorInfo;
    
    // Auto cleanup markers after 2 minutes if not continuous
    if (_showMarkers) then {
        [] spawn {
            sleep 120;
            call _fnc_cleanupMarkers;
            systemChat "Sector markers cleaned up.";
        };
    };
};

systemChat "=== SECTOR MONITOR COMPLETE ===";