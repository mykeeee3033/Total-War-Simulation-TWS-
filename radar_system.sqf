/*
    Complete Radar System
    
    All-in-one radar detection and monitoring system for Arma 3 ALiVE missions
    
    Usage:
    [] execVM "radar_system.sqf";           // Start monitoring
    ["status"] execVM "radar_system.sqf";   // Check status
    ["stop"] execVM "radar_system.sqf";     // Stop monitoring
    
    Features:
    - Automatic faction-based airbase monitoring
    - Real-time aircraft detection (empty planes only)
    - Radar coverage analysis
    - OPFOR auto-response system
    - Simple status reporting
*/

params [["_mode", "start"]];

// Initialize global variables
if (isNil "radar_monitoring_active") then { radar_monitoring_active = false; };
if (isNil "radar_monitoring_interval") then { radar_monitoring_interval = 5; }; // 5 seconds
if (isNil "radar_response_interval") then { radar_response_interval = 15; }; // 15 seconds
if (isNil "radar_east_assignedPlanes") then { radar_east_assignedPlanes = []; };
if (isNil "radar_east_opforCoefficient") then { radar_east_opforCoefficient = 2; };

// Function: Pool detection around radar objects (like the working script)
radar_fnc_poolDetection = {
    params ["_radar"];
    private _range = 200; // Increased range for other airports
    private _nearPlanes = (_radar getPos [0,0]) nearEntities ["Plane", _range];
    private _emptyPlanes = _nearPlanes select {count crew _x == 0}; // Use proven detection logic
    _emptyPlanes
};

// Function: Clean up assigned planes list
radar_fnc_cleanupAssignedPlanes = {
    // Remove destroyed or landed planes from assigned list
    radar_east_assignedPlanes = radar_east_assignedPlanes select {
        alive _x && 
        !isNull _x && 
        (getPosATL _x select 2) > 10 // Still airborne
    };
};

// Core function: Scan position for faction control and aircraft
radar_fnc_scanAirbase = {
    params ["_position", "_markerName"];
    
    // Find radars near position first
    private _allRadars = allUnits + (entities "All");
    private _radars = _allRadars select {
        (typeOf _x find "Radar" >= 0 || typeOf _x find "SAM" >= 0 || typeOf _x find "AAA" >= 0) &&
        (_position distance (getPosATL _x)) < 1000
    };
    
    private _bluforRadars = _radars select {side _x == west};
    private _opforRadars = _radars select {side _x == east};
    
    // Get empty planes around each radar using the proven method
    private _bluforPlanes = [];
    private _opforPlanes = [];
    
    {
        private _radarPlanes = [_x] call radar_fnc_poolDetection;
        private _radarSide = side _x;
        
        if (_radarSide == west) then {
            _bluforPlanes append _radarPlanes;
        } else {
            if (_radarSide == east) then {
                _opforPlanes append _radarPlanes;
            };
        };
    } forEach _radars;
    
    // Determine control
    private _controller = "NEUTRAL";
    if (count _bluforRadars > count _opforRadars) then {
        _controller = "BLUFOR";
    } else {
        if (count _opforRadars > 0) then {
            _controller = "OPFOR";
        };
    };
    
    [_position, _markerName, _controller, count _radars, _bluforPlanes, _opforPlanes, _bluforRadars, _opforRadars]
};

// Function: Get all faction airbases and aircraft
radar_fnc_getFactionData = {
    params ["_faction"];
    
    private _factionAirbases = [];
    private _factionAircraft = [];
    
    for "_i" from 1 to 6 do {
        private _markerName = format ["air_marker_%1", _i];
        private _markerPos = getMarkerPos _markerName;
        
        if (_markerPos distance [0,0,0] > 0) then {
            private _scanResult = [_markerPos, _markerName] call radar_fnc_scanAirbase;
            _scanResult params ["_pos", "_marker", "_controller", "_radarCount", "_bluPlanes", "_opfPlanes", "_bluRadars", "_opfRadars"];
            
            if (_controller == _faction) then {
                private _hasRadar = _radarCount > 0;
                _factionAirbases pushBack [_pos, _hasRadar];
                
                if (_faction == "BLUFOR") then {
                    _factionAircraft append _bluPlanes;
                } else {
                    _factionAircraft append _opfPlanes;
                };
            };
        };
    };
    
    [_factionAircraft, _factionAirbases]
};

// Function: Display status
radar_fnc_showStatus = {
    systemChat "=== RADAR SYSTEM STATUS ===";
    
    if (!isNil "radar_monitoring_active" && radar_monitoring_active) then {
        systemChat "✓ Active monitoring running";
    } else {
        systemChat "✗ Active monitoring stopped";
    };
    
    // Scan each air marker
    for "_i" from 1 to 6 do {
        private _markerName = format ["air_marker_%1", _i];
        private _markerPos = getMarkerPos _markerName;
        
        if (_markerPos distance [0,0,0] > 0) then {
            private _scanResult = [_markerPos, _markerName] call radar_fnc_scanAirbase;
            _scanResult params ["_pos", "_marker", "_controller", "_radarCount", "_bluPlanes", "_opfPlanes", "_bluRadars", "_opfRadars"];
            
            systemChat format ["%1: %2 control | BLU: %3 planes, %4 radars | OPF: %5 planes, %6 radars", 
                _marker, _controller, count _bluPlanes, count _bluRadars, count _opfPlanes, count _opfRadars];
        } else {
            systemChat format ["%1: Marker not found", _markerName];
        };
    };
    
    // Show totals
    private _bluforData = ["BLUFOR"] call radar_fnc_getFactionData;
    private _opforData = ["OPFOR"] call radar_fnc_getFactionData;
    
    _bluforData params ["_bluAircraft", "_bluAirbases"];
    _opforData params ["_opfAircraft", "_opfAirbases"];
    
    systemChat format ["TOTALS - BLUFOR: %1 aircraft, %2 bases | OPFOR: %3 aircraft, %4 bases", 
        count _bluAircraft, count _bluAirbases, count _opfAircraft, count _opfAirbases];
};

// Function: OPFOR response system
radar_fnc_opforResponse = {
    while {radar_monitoring_active} do {
        // Clean up assigned planes list first
        [] call radar_fnc_cleanupAssignedPlanes;
        
        // Find all OPFOR radars across all airbases
        private _allOpforRadars = [];
        
        for "_i" from 1 to 6 do {
            private _markerName = format ["air_marker_%1", _i];
            private _markerPos = getMarkerPos _markerName;
            
            if (_markerPos distance [0,0,0] > 0) then {
                private _scanResult = [_markerPos, _markerName] call radar_fnc_scanAirbase;
                _scanResult params ["_pos", "_marker", "_controller", "_radarCount", "_bluPlanes", "_opfPlanes", "_bluRadars", "_opfRadars"];
                
                if (_controller == "OPFOR" && count _opfRadars > 0) then {
                    _allOpforRadars append _opfRadars;
                };
            };
        };
        
        if (count _allOpforRadars == 0) then {
            sleep 10;
            continue;
        };
        
        // Check each OPFOR radar for threats (like the working script)
        {
            private _radar = _x;
            private _radarPos = getPosASL _radar;
            
            // Find nearby BLUFOR planes
            private _nearPlanes = _radarPos nearEntities ["Plane", 5000];
            private _enemyPlanes = _nearPlanes select {side _x == west};
            
            // Check for player threat
            private _playerDist = _radarPos distance player;
            private _playerIsPlane = vehicle player isKindOf "Plane";
            private _playerThreat = (_playerDist <= 5000 && side player == west && _playerIsPlane);
            
            // Get available aircraft pool for this radar
            private _pool = [_radar] call radar_fnc_poolDetection;
            
            // Debug info for this radar
            // systemChat format ["[DEBUG] %1: Pool=%2, Enemies=%3, Player=%4", _radar, count _pool, count _enemyPlanes, _playerThreat];
            
            if ((count _enemyPlanes > 0) || _playerThreat) then {
                // systemChat format ["BLUFOR threat detected near %1!", typeOf _radar];
                
                // Only assign pilots to planes that haven't been assigned yet
                private _unassignedPlanes = _pool select {!(_x in radar_east_assignedPlanes)};
                private _alreadyAssigned = count radar_east_assignedPlanes;
                private _bluforCount = (count _enemyPlanes) + (if (_playerThreat) then {1} else {0});
                private _desiredOpfor = _bluforCount * radar_east_opforCoefficient;
                private _numToAssign = (_desiredOpfor - _alreadyAssigned) min (count _unassignedPlanes);
                
                // systemChat format ["[DEBUG] Pool=%1, Unassigned=%2, Already=%3, Need=%4", count _pool, count _unassignedPlanes, _alreadyAssigned, _numToAssign];
                
                if (_numToAssign > 0) then {
                    {
                        private _selectedPlane = _x;
                        private _pilotGrp = createGroup east;
                        private _pilot = _pilotGrp createUnit ["O_Pilot_F", getPosASL _selectedPlane, [], 0, "NONE"];
                        _pilot moveInDriver _selectedPlane;
                        
                        // Instantly set the plane airborne at 100m and give forward speed
                        private _pos = getPosASL _selectedPlane;
                        _selectedPlane setPosASL [_pos select 0, _pos select 1, 100];
                        _selectedPlane setVelocityModelSpace [0, 200, 0];
                        _selectedPlane engineOn true;
                        radar_east_assignedPlanes pushBack _selectedPlane;
                        // systemChat format ["OPFOR pilot spawned and placed in %1!", typeOf _selectedPlane];

                        // Find the nearest BLUFOR plane to target
                        private _target = objNull;
                        if (count _enemyPlanes > 0) then {
                            _target = _enemyPlanes select 0;
                        } else {
                            if (_playerThreat) then {
                                _target = vehicle player;
                            };
                        };
                        
                        // Add seek and destroy waypoint
                        if (!isNull _target) then {
                            private _wp1 = _pilotGrp addWaypoint [getPosASL _target, 0];
                            _wp1 setWaypointType "DESTROY";
                        };
                        
                        // Add return to base waypoint
                        private _wp2 = _pilotGrp addWaypoint [_radarPos, 0];
                        _wp2 setWaypointType "GETOUT";
                        
                        // Delete pilot when they get out at base and remove from assigned list
                        _pilot addEventHandler ["GetOutMan", {
                            params ["_unit", "_role", "_vehicle", "_turret"];
                            // Remove vehicle from assigned list when pilot gets out
                            radar_east_assignedPlanes = radar_east_assignedPlanes - [_vehicle];
                            deleteVehicle _unit;
                        }];
                        
                        // Also remove from list if plane is destroyed
                        _selectedPlane addEventHandler ["Killed", {
                            params ["_unit"];
                            radar_east_assignedPlanes = radar_east_assignedPlanes - [_unit];
                        }];
                        
                        sleep 5;
                    } forEach (_unassignedPlanes select [0, _numToAssign]);
                } else {
                    if (count _unassignedPlanes == 0) then {
                        // systemChat "No unassigned aircraft available at this radar position!";
                    } else {
                        // systemChat "Already matched BLUFOR count with assigned aircraft!";
                    };
                };
            };
        } forEach _allOpforRadars;

        sleep radar_response_interval;
    };
};

// Function: Main monitoring loop
radar_fnc_monitorLoop = {
    // systemChat format ["Starting radar monitoring (interval: %1s)", radar_monitoring_interval];
    // systemChat "Commands: ['status'] execVM 'radar_system.sqf' | ['stop'] execVM 'radar_system.sqf'";
    
    // Start OPFOR response in background
    [] spawn radar_fnc_opforResponse;
    
    while {radar_monitoring_active} do {
        [] call radar_fnc_showStatus;
        sleep radar_monitoring_interval;
    };
    
    // systemChat "Radar monitoring stopped.";
};

// Main execution logic
switch (_mode) do {
    case "start": {
        if (radar_monitoring_active) then {
            // systemChat "Radar monitoring already active!";
        } else {
            radar_monitoring_active = true;
            [] spawn radar_fnc_monitorLoop;
        };
    };
    
    case "status": {
        [] call radar_fnc_showStatus;
    };
    
    case "stop": {
        radar_monitoring_active = false;
        // systemChat "Radar monitoring will stop after current cycle.";
    };
    
    default {
        // systemChat "Invalid mode. Use: start, status, or stop";
    };
};