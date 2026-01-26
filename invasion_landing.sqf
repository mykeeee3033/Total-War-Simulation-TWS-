/*
    Amphibious Invasion System - Carrier Detection Module
    Author: GitHub Copilot
    Date: 2026-01-24
    
    Description: Scans the map for aircraft carriers (Land_Carrier_01_base_F) and uses them
    as spawn points for amphibious invasion waves.
*/

// Global variables for invasion system
INVASION_carriers = [];
INVASION_debugEnabled = true;
INVASION_debugMarkers = [];
INVASION_spawnedUnits = [];
INVASION_spawnedVehicles = [];

/*
    Function: INVASION_findCarriers
    Description: Scans the entire map for aircraft carriers
    Returns: Array of carrier objects
*/
INVASION_findCarriers = {
    private _carriers = [];
    private _allObjects = allMissionObjects "All";
    
    {
        if (typeOf _x isKindOf "Land_EF_LPD_base") then {
            _carriers pushBack _x;
            if (INVASION_debugEnabled) then {
                systemChat format ["[INVASION] Found carrier: %1 at position %2", typeOf _x, getPos _x];
            };
        };
    } forEach _allObjects;
    
    if (INVASION_debugEnabled) then {
        systemChat format ["[INVASION] Total carriers found: %1", count _carriers];
    };
    
    _carriers
};

/*
    Function: INVASION_getCarrierInfo
    Description: Gets detailed information about a carrier including distance from player
    Parameters: _carrier - The carrier object
    Returns: Array [carrier, position, distance, typeOf]
*/
INVASION_getCarrierInfo = {
    params ["_carrier"];
    
    private _pos = getPos _carrier;
    private _distance = player distance _carrier;
    private _type = typeOf _carrier;
    
    [_carrier, _pos, _distance, _type]
};

/*
    Function: INVASION_createDebugMarkers
    Description: Creates map markers for all found carriers
*/
INVASION_createDebugMarkers = {
    // Clear existing markers
    {
        deleteMarker _x;
    } forEach INVASION_debugMarkers;
    INVASION_debugMarkers = [];
    
    // Create new markers for each carrier
    {
        private _markerName = format ["invasion_carrier_%1", _forEachIndex];
        private _marker = createMarker [_markerName, getPos _x];
        _marker setMarkerType "b_naval";
        _marker setMarkerSize [1, 1];
        _marker setMarkerColor "ColorBlue";
        _marker setMarkerText format ["Carrier %1 (%.0fm)", _forEachIndex + 1, player distance _x];
        
        INVASION_debugMarkers pushBack _markerName;
        
        if (INVASION_debugEnabled) then {
            systemChat format ["[INVASION] Created debug marker for carrier %1", _forEachIndex + 1];
        };
    } forEach INVASION_carriers;
};

/*
    Function: INVASION_showCarrierInfo
    Description: Displays detailed information about all carriers
*/
INVASION_showCarrierInfo = {
    systemChat "=== INVASION CARRIER REPORT ===";
    
    if (count INVASION_carriers == 0) then {
        systemChat "[INVASION] No carriers found on the map!";
        systemChat "[INVASION] Make sure you have placed Land_EF_LPD_base objects in the editor.";
    } else {
        {
            private _info = [_x] call INVASION_getCarrierInfo;
            _info params ["_carrier", "_pos", "_distance", "_type"];
            
            systemChat format ["[INVASION] Carrier %1:", _forEachIndex + 1];
            systemChat format ["  Type: %1", _type];
            systemChat format ["  Position: [%1, %2, %3]", _pos select 0, _pos select 1, _pos select 2];
            systemChat format ["  Distance from player: %.1f meters", _distance];
            systemChat format ["  Object ID: %1", _carrier];
            systemChat "---";
        } forEach INVASION_carriers;
        
        systemChat format ["[INVASION] Total carriers available for invasion: %1", count INVASION_carriers];
    };
    
    systemChat "=== END REPORT ===";
};

/*
    Function: INVASION_updateDistances
    Description: Updates carrier distances and marker texts (useful for continuous monitoring)
*/
INVASION_updateDistances = {
    {
        private _distance = player distance _x;
        private _markerName = format ["invasion_carrier_%1", _forEachIndex];
        _markerName setMarkerText format ["Carrier %1 (%.0fm)", _forEachIndex + 1, _distance];
    } forEach INVASION_carriers;
};

/*
    Function: INVASION_getPlayerSideSpawnPos
    Description: Calculates spawn positions on the side of carrier facing the player
    Parameters: _carrier - The carrier object, _distance - Distance from carrier to spawn
    Returns: Array of spawn positions
*/
INVASION_getPlayerSideSpawnPos = {
    params ["_carrier", "_distance"];
    
    private _carrierPos = getPos _carrier;
    private _playerPos = getPos player;
    
    // Calculate direction from carrier to player
    private _dirToPlayer = _carrierPos getDir _playerPos;
    
    // Create spawn positions spread in an arc on player's side
    private _spawnPositions = [];
    private _baseAngles = [-30, -10, 10, 30]; // Spread positions in 60-degree arc
    
    {
        private _spawnAngle = _dirToPlayer + _x;
        private _spawnPos = _carrierPos getPos [_distance, _spawnAngle];
        
        // Ensure spawn position is over water (set Z to 0)
        _spawnPos set [2, 0];
        _spawnPositions pushBack _spawnPos;
        
        if (INVASION_debugEnabled) then {
            systemChat format ["[INVASION] Calculated spawn position %1: %2 (angle: %3°)", _forEachIndex + 1, _spawnPos, _spawnAngle];
        };
    } forEach _baseAngles;
    
    _spawnPositions
};

/*
    Function: INVASION_createNATOSquad
    Description: Creates a NATO infantry squad
    Parameters: _spawnPos - Position to spawn the squad
    Returns: Group object
*/
INVASION_createNATOSquad = {
    params ["_spawnPos"];
    
    private _group = createGroup [west, true];
    
    // Marine Squad composition
    private _unitTypes = [
        "EF_B_Marine_SL_Wdl",    // Squad Leader
        "EF_B_Marine_Medic_Wdl", // Medic
        "EF_B_Marine_AR_Wdl",    // Autorifleman
        "EF_B_Marine_AT_Wdl",    // Anti-Tank
        "EF_B_Marine_Mark_Wdl",  // Marksman
        "EF_B_Marine_LAT_Wdl",   // Light AT
        "EF_B_Marine_AR_Wdl",    // Autorifleman 2
        "EF_B_Marine_AT_Wdl"    // Anti-Tank 2
    ];
    
    {
        private _unit = _group createUnit [_x, _spawnPos, [], 0, "NONE"];
        _unit setSkill ["aimingAccuracy", 0.3 + random 0.4];
        _unit setSkill ["spotDistance", 0.4 + random 0.3];
        _unit setSkill ["spotTime", 0.3 + random 0.3];
        _unit setSkill ["courage", 0.6 + random 0.4];
        
        INVASION_spawnedUnits pushBack _unit;
    } forEach _unitTypes;
    
    if (INVASION_debugEnabled) then {
        systemChat format ["[INVASION] Created Marine squad with %1 units at %2", count units _group, _spawnPos];
    };
    
    _group
};

/*
    Function: INVASION_spawnBoatWithSquad
    Description: Spawns a boat with a NATO squad and gives them waypoint to player
    Parameters: _spawnPos - Position to spawn the boat
    Returns: Array [vehicle, group]
*/
INVASION_spawnBoatWithSquad = {
    params ["_spawnPos"];
    
    // Spawn the boat
    private _boat = createVehicle ["B_Boat_Armed_01_minigun_F", _spawnPos, [], 0, "CAN_COLLIDE"];
    _boat setDir (getPos _boat getDir getPos player);
    INVASION_spawnedVehicles pushBack _boat;
    
    // Create squad and put them in the boat
    private _group = [_spawnPos] call INVASION_createNATOSquad;
    
    // Create boat crew (driver and gunner)
    private _driver = _group createUnit ["B_crew_F", _spawnPos, [], 0, "NONE"];
    private _gunner = _group createUnit ["B_crew_F", _spawnPos, [], 0, "NONE"];
    
    _driver assignAsDriver _boat;
    _driver moveInDriver _boat;
    _gunner assignAsGunner _boat;
    _gunner moveInGunner _boat;
    
    INVASION_spawnedUnits pushBack _driver;
    INVASION_spawnedUnits pushBack _gunner;
    
    // Load squad into boat
    {
        if (alive _x) then {
            _x assignAsCargo _boat;
            _x moveInCargo _boat;
        };
    } forEach units _group;
    
    // Find nearest beach marker
    private _nearestBeach = "";
    private _shortestDistance = 99999;
    private _beachPos = _spawnPos;
    
    // Search for beach markers (beach_0, beach_1, beach_2, etc.)
    for "_i" from 0 to 20 do {
        private _markerName = format ["beach_%1", _i];
        private _markerPos = getMarkerPos _markerName;
        
        // Check if marker exists (getMarkerPos returns [0,0,0] for non-existent markers)
        if !(_markerPos isEqualTo [0,0,0]) then {
            private _distance = _spawnPos distance _markerPos;
            
            if (_distance < _shortestDistance) then {
                _shortestDistance = _distance;
                _nearestBeach = _markerName;
                _beachPos = _markerPos;
            };
        };
    };
    
    // If no beach markers found, use player position as fallback
    if (_nearestBeach == "") then {
        _beachPos = getPos player;
        if (INVASION_debugEnabled) then {
            systemChat "[INVASION] No beach markers found, using player position as target";
        };
    } else {
        if (INVASION_debugEnabled) then {
            systemChat format ["[INVASION] Boat targeting nearest beach: %1 (%.0fm away)", _nearestBeach, _shortestDistance];
        };
    };
    
    // Create waypoint to nearest beach (for boat to reach shore)
    private _shoreDistance = 50; // Distance from beach marker where boat should stop
    private _randomDistance = 20 + random 30; // 20-50 meters from beach center
    private _randomAngle = random 360;
    private _randomBeachPos = _beachPos getPos [_randomDistance, _randomAngle];
    private _unloadPos = _randomBeachPos getPos [_shoreDistance, _randomBeachPos getDir _spawnPos];
    
    // First waypoint: Get out at random unload position within beach area
    private _wp1 = _group addWaypoint [_unloadPos, 0];
    _wp1 setWaypointType "GETOUT";
    _wp1 setWaypointSpeed "FULL";
    _wp1 setWaypointBehaviour "COMBAT";
    _wp1 setWaypointFormation "WEDGE";
    _wp1 setWaypointCompletionRadius 75;
    
    // Second waypoint: Infantry move to beach marker center after getting out
    private _wp2 = _group addWaypoint [_beachPos, 0];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointSpeed "FULL";
    _wp2 setWaypointBehaviour "COMBAT";
    _wp2 setWaypointFormation "WEDGE";
    _wp2 setWaypointCompletionRadius 50;
    
    // FORCED DISEMBARKATION SYSTEM - Ensure ALL units get out of boat (including crew)
    [_boat, _group, _unloadPos] spawn {
        params ["_boat", "_group", "_unloadPos"];
        
        // Wait for boat to reach unload area
        waitUntil {sleep 1; (_boat distance _unloadPos) < 150};
        
        // Force ALL units out of the boat (including driver and gunner)
        {
            if (alive _x && vehicle _x == _boat) then {
                unassignVehicle _x;
                [_x] orderGetIn false;
                _x leaveVehicle _boat;
                _x action ["GetOut", _boat];
                systemChat format ["[INVASION] Forcing %1 out of boat", name _x];
            };
        } forEach (units _group);
        
        // Double-check after 10 seconds and force out ANY remaining units
        sleep 10;
        {
            if (alive _x && vehicle _x == _boat) then {
                _x setPosATL ((getPosATL _boat) getPos [10 + random 20, random 360]);
                systemChat format ["[INVASION] Emergency teleport %1 out of boat", name _x];
            };
        } forEach (units _group);
        
        systemChat "[INVASION] ALL units (including crew) have disembarked from boat!";
    };
    
    if (INVASION_debugEnabled) then {
        systemChat format ["[INVASION] Spawned boat %1 with squad at %2", typeOf _boat, _spawnPos];
    };
    
    [_boat, _group]
};

/*
    Function: INVASION_spawnAPC
    Description: Spawns an APC and gives it waypoint to player
    Parameters: _spawnPos - Position to spawn the APC
    Returns: Vehicle object
*/
INVASION_spawnAPC = {
    params ["_spawnPos"];
    
    // Find suitable land position near spawn point with better collision avoidance
    private _landPos = _spawnPos findEmptyPosition [100, 500, "B_APC_Wheeled_01_cannon_F"];
    if (count _landPos == 0) then {
        // If no empty position found, try multiple random positions
        for "_i" from 0 to 5 do {
            private _testPos = _spawnPos getPos [200 + (random 200), random 360];
            private _testLandPos = _testPos findEmptyPosition [50, 150, "B_APC_Wheeled_01_cannon_F"];
            if (count _testLandPos > 0) then {
                _landPos = _testLandPos;
                break;
            };
        };
        
        // Final fallback
        if (count _landPos == 0) then {
            _landPos = _spawnPos getPos [300, random 360];
        };
    };
    
    // Spawn the APC with collision avoidance
    private _apc = createVehicle ["B_APC_Wheeled_01_cannon_F", _landPos, [], 0, "NONE"];
    _apc setDir (getPos _apc getDir getPos player);
    INVASION_spawnedVehicles pushBack _apc;
    
    // Create crew
    private _group = createGroup [west, true];
    private _driver = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    private _gunner = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    private _commander = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    
    _driver assignAsDriver _apc;
    _driver moveInDriver _apc;
    _gunner assignAsGunner _apc;
    _gunner moveInGunner _apc;
    _commander assignAsCommander _apc;
    _commander moveInCommander _apc;
    
    INVASION_spawnedUnits pushBack _driver;
    INVASION_spawnedUnits pushBack _gunner;
    INVASION_spawnedUnits pushBack _commander;
    
    // Find nearest beach marker (same logic as boats)
    private _nearestBeach = "";
    private _shortestDistance = 99999;
    private _beachPos = _landPos;
    
    // Search for beach markers (beach_0, beach_1, beach_2, etc.)
    for "_i" from 0 to 20 do {
        private _markerName = format ["beach_%1", _i];
        private _markerPos = getMarkerPos _markerName;
        
        if (_markerPos distance [0,0,0] > 0) then {
            private _distance = _landPos distance _markerPos;
            if (_distance < _shortestDistance) then {
                _shortestDistance = _distance;
                _nearestBeach = _markerName;
                _beachPos = _markerPos;
            };
        };
    };
    
    // If no beach markers found, use player position as fallback
    if (_nearestBeach == "") then {
        _beachPos = getPos player;
    };
    
    // Create waypoint to beach marker
    private _wp = _group addWaypoint [_beachPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointFormation "COLUMN";
    _wp setWaypointCompletionRadius 100;
    
    // Make crew more aggressive and fearless
    {
        _x setSkill ["courage", 1.0];
        _x setSkill ["general", 0.8];
        _x setBehaviour "CARELESS";
        _x setCombatMode "RED";
        _x disableAI "AUTOCOMBAT";
        _x disableAI "TARGET";
        _x disableAI "AUTOTARGET";
        _x disableAI "SUPPRESSION";
    } forEach [_driver, _gunner, _commander];
    
    // Disable vehicle combat AI and force movement
    _apc disableAI "AUTOCOMBAT";
    _apc disableAI "TARGET";
    _apc disableAI "AUTOTARGET";
    _apc setBehaviour "CARELESS";
    _apc setCombatMode "BLUE"; // Will not engage unless directly ordered
    
    // Force continuous movement to waypoint
    [_group, _apc] spawn {
        params ["_group", "_vehicle"];
        while {alive _vehicle && count (waypoints _group) > 1} do {
            sleep 3;
            if (speed _vehicle < 5) then { // If vehicle is nearly stopped
                _group setBehaviour "CARELESS";
                _group setCombatMode "BLUE";
                {
                    _x doMove (getWPPos [_group, 1]); // Force move to waypoint
                } forEach units _group;
            };
        };
    };
    
    if (INVASION_debugEnabled) then {
        systemChat format ["[INVASION] Spawned APC %1 at %2", typeOf _apc, _landPos];
    };
    
    _apc
};

/*
    Function: INVASION_spawnAAV
    Description: Spawns an AAV with crew and gives it waypoint to player
    Parameters: _spawnPos - Position to spawn the AAV
    Returns: Vehicle object
*/
INVASION_spawnAAV = {
    params ["_spawnPos"];
    
    // Find suitable land position near spawn point
    private _landPos = _spawnPos findEmptyPosition [75, 300, "EF_B_AAV9_50mm_MJTF_Wdl"];
    if (count _landPos == 0) then {
        _landPos = _spawnPos getPos [150, random 360];
    };
    
    // Spawn the AAV
    private _aav = createVehicle ["EF_B_AAV9_50mm_MJTF_Wdl", _landPos, [], 0, "CAN_COLLIDE"];
    _aav setDir (getPos _aav getDir getPos player);
    INVASION_spawnedVehicles pushBack _aav;
    
    // Create crew
    private _group = createGroup [west, true];
    private _driver = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    private _gunner = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    private _commander = _group createUnit ["B_crew_F", _landPos, [], 0, "NONE"];
    
    _driver assignAsDriver _aav;
    _driver moveInDriver _aav;
    _gunner assignAsGunner _aav;
    _gunner moveInGunner _aav;
    _commander assignAsCommander _aav;
    _commander moveInCommander _aav;
    
    INVASION_spawnedUnits pushBack _driver;
    INVASION_spawnedUnits pushBack _gunner;
    INVASION_spawnedUnits pushBack _commander;
    
    // Find nearest beach marker (same logic as boats)
    private _nearestBeach = "";
    private _shortestDistance = 99999;
    private _beachPos = _landPos;
    
    // Search for beach markers (beach_0, beach_1, beach_2, etc.)
    for "_i" from 0 to 20 do {
        private _markerName = format ["beach_%1", _i];
        private _markerPos = getMarkerPos _markerName;
        
        if (_markerPos distance [0,0,0] > 0) then {
            private _distance = _landPos distance _markerPos;
            if (_distance < _shortestDistance) then {
                _shortestDistance = _distance;
                _nearestBeach = _markerName;
                _beachPos = _markerPos;
            };
        };
    };
    
    // If no beach markers found, use player position as fallback
    if (_nearestBeach == "") then {
        _beachPos = getPos player;
    };
    
    // Create waypoint to beach marker
    private _wp = _group addWaypoint [_beachPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointFormation "COLUMN";
    _wp setWaypointCompletionRadius 100;
    
    // Make crew more aggressive and fearless
    {
        _x setSkill ["courage", 1.0];
        _x setSkill ["general", 0.8];
        _x setBehaviour "CARELESS";
        _x setCombatMode "RED";
        _x disableAI "AUTOCOMBAT";
        _x disableAI "TARGET";
        _x disableAI "AUTOTARGET";
        _x disableAI "SUPPRESSION";
    } forEach [_driver, _gunner, _commander];
    
    // Disable vehicle combat AI and force movement
    _aav disableAI "AUTOCOMBAT";
    _aav disableAI "TARGET";
    _aav disableAI "AUTOTARGET";
    _aav setBehaviour "CARELESS";
    _aav setCombatMode "BLUE"; // Will not engage unless directly ordered
    
    // Force continuous movement to waypoint
    [_group, _aav] spawn {
        params ["_group", "_vehicle"];
        while {alive _vehicle && count (waypoints _group) > 1} do {
            sleep 3;
            if (speed _vehicle < 5) then { // If vehicle is nearly stopped
                _group setBehaviour "CARELESS";
                _group setCombatMode "BLUE";
                {
                    _x doMove (getWPPos [_group, 1]); // Force move to waypoint
                } forEach units _group;
            };
        };
    };
    
    if (INVASION_debugEnabled) then {
        systemChat format ["[INVASION] Spawned AAV %1 at %2", typeOf _aav, _landPos];
    };
    
    _aav
};

/*
    Function: INVASION_launchInvasion
    Description: Launches the amphibious invasion from all carriers
*/
INVASION_launchInvasion = {
    if (count INVASION_carriers == 0) then {
        systemChat "[INVASION] ERROR: No carriers found! Cannot launch invasion.";
        false
    };
    
    systemChat "[INVASION] Launching amphibious invasion!";
    
    {
        private _carrier = _x;
        private _spawnDistance = 300; // meters from carrier
        
        systemChat format ["[INVASION] Launching invasion wave from carrier %1", _forEachIndex + 1];
        
        // Get spawn positions on player's side of carrier
        private _spawnPositions = [_carrier, _spawnDistance] call INVASION_getPlayerSideSpawnPos;
        
        // Spawn 3 boats with squads
        for "_i" from 0 to 2 do {
            if (_i < count _spawnPositions) then {
                private _boatData = [_spawnPositions select _i] call INVASION_spawnBoatWithSquad;
                systemChat format ["[INVASION] Boat %1 deployed with squad", _i + 1];
            };
        };
        
        // Spawn 1 APC (use a closer position for head start)
        if (count _spawnPositions > 0) then {
            // Use carrier position and spawn closer to shore for head start
            private _carrierPos = getPos _carrier;
            private _apcSpawnAngle = (_carrierPos getDir getPos player) + 90; // 90 degrees from player direction
            private _apcRefPos = _carrierPos getPos [150, _apcSpawnAngle]; // Much closer than boats for head start
            
            private _apc = [_apcRefPos] call INVASION_spawnAPC;
            systemChat "[INVASION] APC deployed (head start position)";
        };
        
        // Spawn 2 AAVs (use closer distances for head start)
        if (count _spawnPositions > 0) then {
            private _carrierPos = getPos _carrier;
            
            // First AAV at -60 degrees from player direction (closer for head start)
            private _aav1SpawnAngle = (_carrierPos getDir getPos player) - 60;
            private _aav1RefPos = _carrierPos getPos [180, _aav1SpawnAngle]; // Closer than boats
            private _aav1 = [_aav1RefPos] call INVASION_spawnAAV;
            systemChat "[INVASION] AAV 1 deployed (head start position)";
            
            // Second AAV at +120 degrees from player direction (closer for head start)
            private _aav2SpawnAngle = (_carrierPos getDir getPos player) + 120;
            private _aav2RefPos = _carrierPos getPos [180, _aav2SpawnAngle]; // Closer than boats
            private _aav2 = [_aav2RefPos] call INVASION_spawnAAV;
            systemChat "[INVASION] AAV 2 deployed (head start position)";
        };
        
    } forEach INVASION_carriers;
    
    systemChat format ["[INVASION] Invasion launched! %1 vehicles and %2 units deployed", count INVASION_spawnedVehicles, count INVASION_spawnedUnits];
    true
};

/*
    Function: INVASION_clearInvasion
    Description: Cleans up all spawned invasion units and vehicles
*/
INVASION_clearInvasion = {
    systemChat "[INVASION] Clearing invasion forces...";
    
    // Delete all spawned vehicles
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach INVASION_spawnedVehicles;
    
    // Delete all spawned units
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach INVASION_spawnedUnits;
    
    INVASION_spawnedVehicles = [];
    INVASION_spawnedUnits = [];
    
    systemChat format "[INVASION] Invasion forces cleared!";
};

/*
    Main Execution
*/
systemChat "[INVASION] Initializing amphibious invasion system...";

// Find all carriers on the map
INVASION_carriers = call INVASION_findCarriers;

// Create debug markers if debug is enabled
if (INVASION_debugEnabled) then {
    call INVASION_createDebugMarkers;
};

// Show initial carrier information
call INVASION_showCarrierInfo;

// Set up periodic distance updates (every 5 seconds)
if (INVASION_debugEnabled) then {
    [] spawn {
        while {true} do {
            sleep 5;
            call INVASION_updateDistances;
        };
    };
    
    systemChat "[INVASION] Debug mode active - carrier distances will update every 5 seconds.";
    systemChat "[INVASION] Use 'call INVASION_showCarrierInfo' to display detailed carrier information.";
    systemChat "[INVASION] Use 'call INVASION_createDebugMarkers' to refresh debug markers.";
    systemChat "[INVASION] Use 'call INVASION_launchInvasion' to start the amphibious assault!";
    systemChat "[INVASION] Use 'call INVASION_clearInvasion' to clear all invasion forces.";
};

systemChat "[INVASION] Carrier detection system initialized successfully!";

// Auto-launch invasion after initialization
if (count INVASION_carriers > 0) then {
    systemChat "[INVASION] Auto-launching invasion in 3 seconds...";
    [] spawn {
        sleep 3;
        call INVASION_launchInvasion;
    };
} else {
    systemChat "[INVASION] No carriers found - invasion cannot be launched automatically.";
    systemChat "[INVASION] Place Land_Carrier_01_base_F objects in the editor and restart the mission.";
};