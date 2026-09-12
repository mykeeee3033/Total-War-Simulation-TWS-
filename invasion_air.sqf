/*
    Invasion Air Support System - Integrated MIL_CAS
    Author: GitHub Copilot
    Date: 2026-01-25
    
    Description: Self-contained air support system with integrated MIL_CAS functionality
    for realistic A-10 airstrikes on player position.
*/

// Global variables for air support system
INVASION_airDebugEnabled = true;

/*
    Function: INVASION_milCAS
    Description: Integrated MIL_CAS functionality - creates logic and executes CAS
    Parameters: _position, _direction, _vehicle, _type
*/
INVASION_milCAS = {
    params [
        "_position",
        "_direction", 
        ["_vehicle","JS_JC_FA18E"],
        ["_type",2]
    ];
    
    private _logic = "Logic" createVehicleLocal _position;
    _logic setDir _direction;
    _logic setVariable ["vehicle",_vehicle];
    _logic setVariable ["type",_type];
    
    [_logic,nil,true] call BIS_fnc_moduleCAS;
    
    deleteVehicle _logic;
};

/*
    Function: INVASION_getRandomBeachPosition
    Description: Gets a random position within the beach_0 marker area
    Returns: Random position array or player position as fallback
*/
INVASION_getRandomBeachPosition = {
    private _beachMarker = "beach_0";
    private _markerPos = getMarkerPos _beachMarker;
    
    // Check if beach_0 marker exists
    if (_markerPos isEqualTo [0,0,0]) then {
        systemChat "[AIR] beach_0 marker not found, using player position as fallback";
        (getPos player)
    };
    
    // Get marker size and shape
    private _markerSize = getMarkerSize _beachMarker;
    private _markerShape = markerShape _beachMarker;
    
    private _randomPos = [];
    
    if (_markerShape == "RECTANGLE") then {
        // Generate random position within 400m radius of marker center (ignore marker size)
        private _angle = random 360;
        private _distance = random 400;
        _randomPos = _markerPos getPos [_distance, _angle];
    } else {
        // Generate random position within 400m radius of marker center (ignore marker size)
        private _angle = random 360;
        private _distance = random 400;
        _randomPos = _markerPos getPos [_distance, _angle];
    };
    
    if (INVASION_airDebugEnabled) then {
        systemChat format ["[AIR] Random beach position generated: %1", _randomPos];
    };
    
    _randomPos
};

/*
    Function: INVASION_detectOpforTargets
    Description: Scans beach_0 marker area for OPFOR targets (vehicles, statics, infantry)
    Returns: Array of OPFOR target positions or empty array if none found
*/
INVASION_detectOpforTargets = {
    private _beachMarker = "beach_0";
    private _markerPos = getMarkerPos _beachMarker;
    private _opforTargets = [];
    
    // Check if beach_0 marker exists
    if (_markerPos isEqualTo [0,0,0]) then {
        systemChat "[AIR] beach_0 marker not found for target detection";
        []
    };
    
    // Get marker size for search radius
    private _markerSize = getMarkerSize _beachMarker;
    private _searchRadius = (_markerSize select 0) max (_markerSize select 1);
    
    // Find all units and vehicles in the area
    private _allUnits = _markerPos nearEntities [["Man", "Car", "Tank", "StaticWeapon", "Ship"], _searchRadius];
    
    // Filter for OPFOR (East side) targets
    private _opforUnits = _allUnits select {
        side _x == east && 
        alive _x && 
        damage _x < 0.8
    };
    
    // Get positions of OPFOR targets
    {
        _opforTargets pushBack (getPos _x);
    } forEach _opforUnits;
    
    if (INVASION_airDebugEnabled) then {
        systemChat format ["[AIR] OPFOR targets detected in beach_0: %1", count _opforTargets];
        if (count _opforTargets > 0) then {
            systemChat "[AIR] Priority targeting: OPFOR forces";
        } else {
            systemChat "[AIR] No OPFOR targets found, will use random targeting";
        };
    };
    
    _opforTargets
};

/*
    Function: INVASION_getTargetPosition
    Description: Gets optimal target position - prioritizes OPFOR, falls back to random
    Returns: Target position array
*/
INVASION_getTargetPosition = {
    private _opforTargets = call INVASION_detectOpforTargets;
    
    // If OPFOR targets found, select one randomly
    if (count _opforTargets > 0) then {
        private _targetPos = selectRandom _opforTargets;
        systemChat "[AIR] Targeting OPFOR forces in beach area";
        _targetPos
    };
    
    // Fallback to random position in beach area
    systemChat "[AIR] No OPFOR targets, using random beach targeting";
    call INVASION_getRandomBeachPosition
};

/*
    Function: INVASION_executeMilCAS
    Description: Executes Close Air Support using integrated MIL_CAS function
    Parameters: _targetPos - Position to attack, _direction - Approach direction
*/
INVASION_executeMilCAS = {
    params ["_targetPos", ["_direction", 240]];
    
    // Create visual marker for the strike
    private _markerName = format ["mil_cas_strike_%1", round(time)];
    private _marker = createMarkerLocal [_markerName, _targetPos];
    _marker setMarkerAlphaLocal 1;
    _marker setMarkerColorLocal "ColorRed";
    _marker setMarkerShapeLocal "ELLIPSE";
    _marker setMarkerBrushLocal "Solid";
    _marker setMarkerSizeLocal [100, 100];
    _marker setMarkerText "F/A-18E CAS INBOUND";
    
    if (INVASION_airDebugEnabled) then {
        systemChat format ["[AIR] F/A-18E strike incoming at %1, approach: %2°", _targetPos, _direction];
    };
    
    // Execute integrated CAS function with F/A-18E and mixed weapons
    [_targetPos, _direction, "JS_JC_FA18E", 2] call INVASION_milCAS;
    
    // Clean up marker after strike
    [] spawn {
        sleep 25;
        deleteMarkerLocal _markerName;
    };
    
    systemChat "[AIR] F/A-18E strike executed - Guns & Missiles!";
};

/*
    Main Air Support Execution - AUTO EXECUTE WITH INTELLIGENT TARGETING
*/
systemChat "[AIR] Initializing Integrated Air Support system...";
systemChat "[AIR] Target: OPFOR priority, beach_0 fallback";
systemChat "[AIR] Aircraft: F/A-18E Super Hornet";
systemChat "[AIR] Ordnance: Guns & Missiles";

// Execute F/A-18E CAS on optimal target position automatically
systemChat "[AIR] F/A-18E Close Air Support - 10 strikes incoming at beach_0 area...";
[] spawn {
    for "_i" from 1 to 10 do {
        systemChat format ["[AIR] Strike %1/10 launching in 3 seconds...", _i];
        sleep 3;
        
        private _targetPos = call INVASION_getTargetPosition;
        private _randomHeading = random 360;  // Randomize approach direction
        [_targetPos, _randomHeading] call INVASION_executeMilCAS;
        systemChat format ["[AIR] Strike %1/10 launched! Approach: %2°", _i, _randomHeading];
        
        // Wait between strikes (except for the last one)
        if (_i < 10) then {
            sleep (5 + random 5); // 5-10 second delay between strikes for rapid bombardment
        };
    };
    
    systemChat "[AIR] All 10 F/A-18E strikes completed! Beach bombardment finished.";
};

systemChat "[AIR] Integrated Air Support system ACTIVE - 10 F/A-18E strikes launching at beach_0!";