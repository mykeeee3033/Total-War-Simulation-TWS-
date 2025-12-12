/*
 * enhancedRadarSystem.sqf
 * Enhanced Radar and Air Sortie Management
 * 
 * Features:
 * - Integration with existing radar_opf and radar_pool_detection
 * - Airspace violation notifications
 * - Scramble order tracking
 * - Sortie management and logging
 * - Communication grid integration
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    diag_log "[TWS] Initializing enhanced radar system...";
    systemChat "[TWS] Initializing enhanced radar system...";
    
    // Radar system configuration
    TWS_radarSystem = createHashMap;
    TWS_radarSystem set ["enabled", true];
    TWS_radarSystem set ["detectionRange", 5000]; // 5km detection range
    TWS_radarSystem set ["responseCoefficient", 2]; // 2:1 response ratio
    TWS_radarSystem set ["activeSorties", []];
    TWS_radarSystem set ["totalSorties", 0];
    
    // Function to register radar site
    TWS_fnc_registerRadarSite = {
        params ["_radarObject", "_faction", ["_range", 5000]];
        
        if (isNull _radarObject) exitWith {
            diag_log "[TWS] Cannot register null radar object";
        };
        
        private _radarID = format ["radar_%1_%2", _faction, str _radarObject];
        private _radarData = createHashMap;
        _radarData set ["id", _radarID];
        _radarData set ["object", _radarObject];
        _radarData set ["faction", _faction];
        _radarData set ["range", _range];
        _radarData set ["operational", true];
        _radarData set ["assignedPlanes", []];
        _radarData set ["sortiesLaunched", 0];
        
        // Store in world state
        private _radarSites = TWS_worldState getOrDefault ["radarSites", createHashMap];
        _radarSites set [str _radarObject, _radarData];
        TWS_worldState set ["radarSites", _radarSites];
        
        // Start monitoring for this radar
        [_radarObject, _faction] spawn TWS_fnc_radarMonitoringLoop;
        
        diag_log format ["[TWS] Registered radar site: %1 for %2", _radarID, _faction];
        systemChat format ["[TWS] Radar site %1 online", _radarID];
        
        _radarData
    };
    
    // Function to detect airspace violations
    TWS_fnc_detectAirspaceViolation = {
        params ["_radarObject", "_faction"];
        
        private _radarPos = getPosASL _radarObject;
        private _range = TWS_radarSystem get "detectionRange";
        
        // Find nearby enemy aircraft
        private _nearPlanes = _radarPos nearEntities ["Plane", _range];
        private _enemySide = if (_faction == "OPFOR") then {west} else {east};
        private _enemyPlanes = _nearPlanes select {side _x == _enemySide && alive _x};
        
        // Also check for player if in aircraft
        private _playerInRange = false;
        if (isPlayer player && vehicle player isKindOf "Plane") then {
            private _playerDist = _radarPos distance player;
            if (_playerDist <= _range && side player == _enemySide) then {
                _playerInRange = true;
            };
        };
        
        [_enemyPlanes, _playerInRange]
    };
    
    // Function to scramble interceptors
    TWS_fnc_scrambleInterceptors = {
        params ["_radarObject", "_faction", "_enemyPlanes"];
        
        if (count _enemyPlanes == 0) exitWith {
            diag_log "[TWS] No enemy planes to intercept";
        };
        
        // Check if communication grid is operational
        if (!isNil "TWS_fnc_canOperateEffectively") then {
            if (!([_faction] call TWS_fnc_canOperateEffectively)) exitWith {
                systemChat format ["[TWS] %1 cannot scramble interceptors - communication grid down!", _faction];
                diag_log format ["[TWS] %1 scramble aborted due to communication failure", _faction];
            };
        };
        
        private _radarPos = getPosASL _radarObject;
        
        // Get available aircraft from pool
        private _pool = if (!isNil "radar_fnc_poolDetection") then {
            [_radarObject] call radar_fnc_poolDetection
        } else {
            []
        };
        
        if (count _pool == 0) exitWith {
            diag_log format ["[TWS] No aircraft available for %1", _faction];
            systemChat format ["[TWS] No interceptors available at radar site"];
        };
        
        // Get radar data
        private _radarSites = TWS_worldState getOrDefault ["radarSites", createHashMap];
        private _radarData = _radarSites getOrDefault [str _radarObject, createHashMap];
        private _assignedPlanes = _radarData getOrDefault ["assignedPlanes", []];
        
        // Calculate how many interceptors to scramble
        private _enemyCount = count _enemyPlanes;
        private _coefficient = TWS_radarSystem get "responseCoefficient";
        private _desiredCount = _enemyCount * _coefficient;
        private _alreadyAssigned = count _assignedPlanes;
        private _unassignedPool = _pool select {!(_x in _assignedPlanes)};
        private _toAssign = (_desiredCount - _alreadyAssigned) min (count _unassignedPool);
        
        if (_toAssign <= 0) exitWith {
            diag_log "[TWS] No additional aircraft needed for scramble";
        };
        
        // Scramble aircraft
        private _sortieID = format ["sortie_%1_%2", _faction, TWS_radarSystem get "totalSorties"];
        private _sortieData = createHashMap;
        _sortieData set ["id", _sortieID];
        _sortieData set ["faction", _faction];
        _sortieData set ["aircraft", []];
        _sortieData set ["targets", _enemyPlanes];
        _sortieData set ["launchTime", diag_tickTime];
        
        for "_i" from 0 to (_toAssign - 1) do {
            private _aircraft = _unassignedPool select _i;
            
            // Create pilot
            private _side = if (_faction == "OPFOR") then {east} else {west};
            private _pilotClass = if (_faction == "OPFOR") then {"O_Pilot_F"} else {"B_Pilot_F"};
            private _pilotGrp = createGroup _side;
            private _pilot = _pilotGrp createUnit [_pilotClass, getPosASL _aircraft, [], 0, "NONE"];
            _pilot moveInDriver _aircraft;
            
            // Make airborne
            private _pos = getPosASL _aircraft;
            _aircraft setPosASL [_pos select 0, _pos select 1, 100];
            _aircraft setVelocityModelSpace [0, 200, 0];
            _aircraft engineOn true;
            
            // Add to assigned planes
            _assignedPlanes pushBack _aircraft;
            _sortieData get "aircraft" pushBack _aircraft;
            
            // Set waypoint to intercept nearest enemy
            if (count _enemyPlanes > 0) then {
                private _target = _enemyPlanes select 0;
                private _wp1 = _pilotGrp addWaypoint [getPosASL _target, 0];
                _wp1 setWaypointType "DESTROY";
            };
            
            // Return to base waypoint
            private _wp2 = _pilotGrp addWaypoint [_radarPos, 0];
            _wp2 setWaypointType "GETOUT";
            
            // Despawn pilot on landing
            _pilot addEventHandler ["GetOutMan", {
                params ["_unit"];
                deleteVehicle _unit;
            }];
            
            sleep 0.5; // Small delay between aircraft
        };
        
        // Update radar data
        _radarData set ["assignedPlanes", _assignedPlanes];
        private _sortiesLaunched = _radarData getOrDefault ["sortiesLaunched", 0];
        _radarData set ["sortiesLaunched", _sortiesLaunched + 1];
        
        // Track sortie
        private _activeSorties = TWS_radarSystem get "activeSorties";
        _activeSorties pushBack _sortieData;
        
        private _totalSorties = TWS_radarSystem get "totalSorties";
        TWS_radarSystem set ["totalSorties", _totalSorties + 1];
        
        // Notify
        if (!isNil "TWS_fnc_notify") then {
            ["combat", format ["%1 scrambled %2 interceptors", _faction, _toAssign], _radarPos, true, 300] call TWS_fnc_notify;
        };
        
        systemChat format ["[TWS] %1 scrambled %2 interceptors to engage %3 enemy aircraft", _faction, _toAssign, _enemyCount];
        diag_log format ["[TWS] Sortie %1: %2 scrambled %3 aircraft from %4", _sortieID, _faction, _toAssign, _radarObject];
        
        _sortieID
    };
    
    // Function to monitor radar site
    TWS_fnc_radarMonitoringLoop = {
        params ["_radarObject", "_faction"];
        
        while {alive _radarObject} do {
            // Detect airspace violations
            private _detection = [_radarObject, _faction] call TWS_fnc_detectAirspaceViolation;
            private _enemyPlanes = _detection select 0;
            private _playerInRange = _detection select 1;
            
            // Scramble if enemies detected
            if (count _enemyPlanes > 0 || _playerInRange) then {
                [_radarObject, _faction, _enemyPlanes] call TWS_fnc_scrambleInterceptors;
            };
            
            sleep 5; // Check every 5 seconds
        };
        
        // Radar destroyed
        systemChat format ["[TWS] Radar site destroyed - air defense offline"];
        diag_log format ["[TWS] Radar %1 destroyed", _radarObject];
        
        if (!isNil "TWS_fnc_notify") then {
            ["combat", format ["%1 radar destroyed - air defense compromised", _faction], getPosASL _radarObject, true] call TWS_fnc_notify;
        };
    };
    
    // Function to clean up completed sorties
    TWS_fnc_cleanupSorties = {
        private _activeSorties = TWS_radarSystem get "activeSorties";
        private _newSorties = [];
        
        {
            private _sortieData = _x;
            private _aircraft = _sortieData get "aircraft";
            
            // Keep if at least one aircraft still active
            private _anyActive = false;
            {
                if (!isNull _x && alive _x) then {
                    _anyActive = true;
                };
            } forEach _aircraft;
            
            if (_anyActive) then {
                _newSorties pushBack _sortieData;
            };
        } forEach _activeSorties;
        
        TWS_radarSystem set ["activeSorties", _newSorties];
    };
    
    // Sortie cleanup loop
    TWS_fnc_sortieCleanupLoop = {
        while {TWS_radarSystem get "enabled"} do {
            [] call TWS_fnc_cleanupSorties;
            sleep 30; // Clean up every 30 seconds
        };
    };
    
    // Start cleanup loop
    [] spawn TWS_fnc_sortieCleanupLoop;
    
    // Function to get active sorties
    TWS_fnc_getActiveSorties = {
        TWS_radarSystem get "activeSorties"
    };
    
    // Function to get sortie statistics
    TWS_fnc_getSortieStats = {
        params [["_faction", ""]];
        
        private _activeSorties = TWS_radarSystem get "activeSorties";
        
        if (_faction == "") then {
            // Return all stats
            private _stats = createHashMap;
            _stats set ["total", TWS_radarSystem get "totalSorties"];
            _stats set ["active", count _activeSorties];
            _stats
        } else {
            // Filter by faction
            private _factionSorties = _activeSorties select {(_x get "faction") == _faction};
            count _factionSorties
        };
    };
    
    // Make public
    publicVariable "TWS_radarSystem";
    publicVariable "TWS_fnc_registerRadarSite";
    publicVariable "TWS_fnc_detectAirspaceViolation";
    publicVariable "TWS_fnc_scrambleInterceptors";
    publicVariable "TWS_fnc_radarMonitoringLoop";
    publicVariable "TWS_fnc_cleanupSorties";
    publicVariable "TWS_fnc_getActiveSorties";
    publicVariable "TWS_fnc_getSortieStats";
    
    systemChat "[TWS] Enhanced radar system initialized";
    diag_log "[TWS] Enhanced radar system initialized with sortie management";
};
