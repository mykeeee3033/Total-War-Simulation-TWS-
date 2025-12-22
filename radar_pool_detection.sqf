/*
    radar_pool_detection.sqf
    Usage: _result = [_side] call radar_fnc_poolDetection;
    Returns: [_availableAircraft, _activeAirbases] where each airbase entry is [position, hasRadar]
    
    _side: "WEST" or "EAST"
    
    Finds ALiVE airbases for the side, checks for nearby radars, 
    and returns available aircraft at radar-equipped airbases
*/

radar_fnc_poolDetection = {
    params ["_targetSide"];
    
    // Check if ALiVE is available
    if (isNil "ALiVE_sectorGrid" || isNil "OPCOM_instances") exitWith {
        ["Radar Pool Detection: ALiVE not available"] call ALiVE_fnc_dump;
        [[], []]
    };
    
    // Define radar types by side
    private _radarTypes = createHashMapFromArray [
        ["WEST", ["B_Radar_System_01_F"]],
        ["EAST", ["O_Radar_System_02_F"]]
    ];
    
    if (!(_targetSide in _radarTypes)) exitWith {
        ["Radar Pool Detection: Invalid side %1", _targetSide] call ALiVE_fnc_dump;
        [[], []]
    };
    
    private _availableAircraft = [];
    private _activeAirbases = [];
    
    // Find OPCOM airbases for the target side
    {
        private _opcom = _x;
        private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
        
        // Only check OPCOM instances of our target side
        if (_opcomSide == _targetSide) then {
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                
                // Check if this objective has airport/airbase characteristics
                private _hasAirport = false;
                
                // Method 1: Check for airbase buildings nearby
                private _nearAirports = _objCenter nearEntities [["Land_Runway_PAPI", "Land_Runway_PAPI_2", "Land_Airport_Tower_F", "Land_Hangar_F", "Land_TentHangar_V1_F"], 1500];
                if (count _nearAirports > 0) then {
                    _hasAirport = true;
                };
                
                // Method 2: Check OPCOM installations for airbase-related facilities
                if (!_hasAirport) then {
                    private _installations = ["factory", "HQ", "depot"];
                    {
                        private _installation = [_objective, _x, []] call ALIVE_fnc_hashGet;
                        if (count _installation > 0) then {
                            // If installation exists, check for aircraft nearby (indicates airbase)
                            private _nearAircraft = _objCenter nearEntities ["Plane", 2000];
                            if (count _nearAircraft > 0) then {
                                _hasAirport = true;
                            };
                        };
                    } forEach _installations;
                };
                
                if (_hasAirport) then {
                    // Check for radars near this airbase (2km radius)
                    private _nearRadars = _objCenter nearEntities [(_radarTypes get _targetSide), 2000];
                    private _hasActiveRadar = false;
                    
                    {
                        if (alive _x && damage _x < 0.8) then {
                            _hasActiveRadar = true;
                        };
                    } forEach _nearRadars;
                    
                    // Only include airbases with active radars
                    if (_hasActiveRadar) then {
                        _activeAirbases pushBack [_objCenter, true];
                        
                        // Find aircraft at this radar-equipped airbase
                        private _nearAircraft = _objCenter nearEntities ["Plane", 1500];
                        private _availableForScramble = _nearAircraft select {
                            alive _x && 
                            damage _x < 0.3 && 
                            count crew _x == 0 &&
                            fuel _x > 0.5 &&
                            side _x == ([_targetSide] call ALIVE_fnc_sideTextToObject)
                        };
                        
                        _availableAircraft append _availableForScramble;
                    };
                };
            } forEach _objectives;
        };
    } forEach OPCOM_instances;
    
    // Remove duplicates
    _availableAircraft = _availableAircraft arrayIntersect _availableAircraft;
    
    // Debug output
    ["Radar Pool Detection Results for %1:", _targetSide] call ALiVE_fnc_dump;
    ["  Radar-equipped Airbases: %1", count _activeAirbases] call ALiVE_fnc_dump;
    ["  Available Aircraft: %1", count _availableAircraft] call ALiVE_fnc_dump;
    
    // Return [aircraft, airbases]
    [_availableAircraft, _activeAirbases]
};