/*
 * manpowerResupply.sqf
 * Automatic Manpower Resupply System
 * 
 * Features:
 * - Automatic trigger every 100 casualties
 * - Aircraft spawning for manpower delivery
 * - Airport landing and takeoff logic
 * - 200 manpower points per delivery
 * - Based on airport_logi_opfor.sqf logic
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_combat"};
    
    diag_log "[TWS] Initializing manpower resupply system...";
    systemChat "[TWS] Initializing manpower resupply system...";
    
    // Manpower resupply configuration
    TWS_manpowerResupply = createHashMap;
    TWS_manpowerResupply set ["enabled", true];
    TWS_manpowerResupply set ["casualtyThreshold", 100]; // Trigger every 100 casualties
    TWS_manpowerResupply set ["manpowerPerDelivery", 200];
    TWS_manpowerResupply set ["lastTriggerCount", 0];
    TWS_manpowerResupply set ["activeFlights", []];
    
    // Faction-specific configuration
    TWS_manpowerResupply set ["OPFOR_spawnMarker", "logi_spawn_opfor"];
    TWS_manpowerResupply set ["OPFOR_airportMarker", "cargo_depot_o"];
    TWS_manpowerResupply set ["OPFOR_aircraftClass", "RHS_C130J_Cargo"];
    
    TWS_manpowerResupply set ["BLUFOR_spawnMarker", "logi_spawn_blufor"];
    TWS_manpowerResupply set ["BLUFOR_airportMarker", "cargo_depot_b"];
    TWS_manpowerResupply set ["BLUFOR_aircraftClass", "B_T_VTOL_01_infantry_F"];
    
    // Function to trigger manpower resupply
    TWS_fnc_triggerManpowerResupply = {
        params ["_faction"];
        
        if (!(TWS_manpowerResupply get "enabled")) exitWith {
            diag_log format ["[TWS] Manpower resupply disabled for %1", _faction];
        };
        
        private _spawnMarkerKey = format ["%1_spawnMarker", _faction];
        private _airportMarkerKey = format ["%1_airportMarker", _faction];
        private _aircraftClassKey = format ["%1_aircraftClass", _faction];
        
        private _spawnMarker = TWS_manpowerResupply getOrDefault [_spawnMarkerKey, ""];
        private _airportMarker = TWS_manpowerResupply getOrDefault [_airportMarkerKey, ""];
        private _aircraftClass = TWS_manpowerResupply getOrDefault [_aircraftClassKey, "RHS_C130J_Cargo"];
        
        if (_spawnMarker == "" || _airportMarker == "") exitWith {
            diag_log format ["[TWS] Manpower resupply markers not configured for %1", _faction];
        };
        
        // Spawn the aircraft
        [_faction, _spawnMarker, _airportMarker, _aircraftClass] call TWS_fnc_spawnManpowerAircraft;
        
        diag_log format ["[TWS] Triggered manpower resupply for %1", _faction];
        systemChat format ["[TWS] %1 manpower resupply inbound!", _faction];
    };
    
    // Function to spawn manpower aircraft
    TWS_fnc_spawnManpowerAircraft = {
        params ["_faction", "_spawnMarker", "_airportMarker", "_aircraftClass"];
        
        private _spawnPos = getMarkerPos _spawnMarker;
        private _airportPos = getMarkerPos _airportMarker;
        
        if (_spawnPos isEqualTo [0,0,0] || _airportPos isEqualTo [0,0,0]) exitWith {
            diag_log format ["[TWS] Invalid marker positions for manpower resupply: spawn=%1, airport=%2", _spawnMarker, _airportMarker];
        };
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        
        // Create crew group
        private _crewGrp = createGroup _side;
        
        // Spawn aircraft
        private _planeArr = [_spawnPos, 500, _aircraftClass, _crewGrp] call BIS_fnc_spawnVehicle;
        private _plane = _planeArr select 0;
        _plane flyInHeight 500;
        
        // Waypoint 1: Fly to airport
        private _wp1 = _crewGrp addWaypoint [_airportPos, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        _wp1 setWaypointCompletionRadius 100;
        
        // Waypoint statement: deliver manpower
        private _manpowerAmount = TWS_manpowerResupply get "manpowerPerDelivery";
        _wp1 setWaypointStatements ["true", format [
            "[%1, %2] call TWS_fnc_deliverManpower;",
            str _faction,
            _manpowerAmount
        ]];
        
        // Waypoint 2: Return to spawn point
        private _wp2 = _crewGrp addWaypoint [_spawnPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointCompletionRadius 100;
        
        // Waypoint statement: despawn aircraft
        _wp2 setWaypointStatements ["true", format [
            "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this]; systemChat '[TWS] Manpower aircraft returned and despawned';"
        ]];
        
        // Track active flight
        private _activeFlights = TWS_manpowerResupply get "activeFlights";
        _activeFlights pushBack [_plane, _faction, diag_tickTime];
        
        // Notify
        ["OPFOR", _airportPos, "manpower resupply", ""] call TWS_fnc_notifyOrderExecution;
        [_airportPos, format ["%1 Manpower Delivery", _faction], "ColorGreen", 600] call TWS_fnc_createEventMarker;
        
        diag_log format ["[TWS] Spawned manpower aircraft for %1 (class: %2)", _faction, _aircraftClass];
        
        _plane
    };
    
    // Function to deliver manpower
    TWS_fnc_deliverManpower = {
        params ["_faction", "_amount"];
        
        // Add manpower to faction resources
        if (!isNil "TWS_fnc_modifyResource") then {
            [_faction, "manpower", _amount] call TWS_fnc_modifyResource;
        };
        
        // Notify
        if (!isNil "TWS_fnc_notifyResupply") then {
            private _airportMarkerKey = format ["%1_airportMarker", _faction];
            private _airportMarker = TWS_manpowerResupply getOrDefault [_airportMarkerKey, ""];
            private _airportPos = getMarkerPos _airportMarker;
            
            [_faction, _airportPos, "manpower", _amount] call TWS_fnc_notifyResupply;
        };
        
        systemChat format ["[TWS] %1 received %2 manpower reinforcements", _faction, _amount];
        diag_log format ["[TWS] Delivered %1 manpower to %2", _amount, _faction];
    };
    
    // Function to check and trigger manpower resupply
    TWS_fnc_checkManpowerResupplyTrigger = {
        params ["_faction"];
        
        // Get total casualties for faction
        private _casualties = if (!isNil "TWS_fnc_getCasualtyStats") then {
            [_faction] call TWS_fnc_getCasualtyStats
        } else {
            0
        };
        
        private _lastTrigger = TWS_manpowerResupply get "lastTriggerCount";
        private _threshold = TWS_manpowerResupply get "casualtyThreshold";
        
        // Check if we've crossed a threshold
        private _currentThreshold = floor (_casualties / _threshold);
        private _lastThreshold = floor (_lastTrigger / _threshold);
        
        if (_currentThreshold > _lastThreshold) then {
            // Trigger resupply
            [_faction] call TWS_fnc_triggerManpowerResupply;
            
            // Update last trigger count
            TWS_manpowerResupply set ["lastTriggerCount", _casualties];
        };
    };
    
    // Function to clean up completed flights
    TWS_fnc_cleanupManpowerFlights = {
        private _activeFlights = TWS_manpowerResupply get "activeFlights";
        private _newFlights = [];
        
        {
            private _plane = _x select 0;
            
            // Keep if aircraft still exists
            if (!isNull _plane && alive _plane) then {
                _newFlights pushBack _x;
            };
        } forEach _activeFlights;
        
        TWS_manpowerResupply set ["activeFlights", _newFlights];
    };
    
    // Manpower check loop
    TWS_fnc_manpowerCheckLoop = {
        while {TWS_manpowerResupply get "enabled"} do {
            // Clean up completed flights
            [] call TWS_fnc_cleanupManpowerFlights;
            
            // Check OPFOR
            ["OPFOR"] call TWS_fnc_checkManpowerResupplyTrigger;
            
            // Check BLUFOR
            ["BLUFOR"] call TWS_fnc_checkManpowerResupplyTrigger;
            
            // Wait 60 seconds before next check
            sleep 60;
        };
    };
    
    // Start check loop
    [] spawn TWS_fnc_manpowerCheckLoop;
    
    // Function to toggle manpower resupply
    TWS_fnc_toggleManpowerResupply = {
        params ["_enable"];
        
        TWS_manpowerResupply set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Manpower resupply system enabled";
            [] spawn TWS_fnc_manpowerCheckLoop;
        } else {
            systemChat "[TWS] Manpower resupply system disabled";
        };
    };
    
    // Function to get active flights
    TWS_fnc_getActiveManpowerFlights = {
        TWS_manpowerResupply get "activeFlights"
    };
    
    // Make public
    publicVariable "TWS_manpowerResupply";
    publicVariable "TWS_fnc_triggerManpowerResupply";
    publicVariable "TWS_fnc_spawnManpowerAircraft";
    publicVariable "TWS_fnc_deliverManpower";
    publicVariable "TWS_fnc_checkManpowerResupplyTrigger";
    publicVariable "TWS_fnc_cleanupManpowerFlights";
    publicVariable "TWS_fnc_toggleManpowerResupply";
    publicVariable "TWS_fnc_getActiveManpowerFlights";
    
    systemChat "[TWS] Manpower resupply system initialized";
    systemChat format ["[TWS] Manpower resupply triggers every %1 casualties", TWS_manpowerResupply get "casualtyThreshold"];
    diag_log "[TWS] Manpower resupply system initialized";
};
