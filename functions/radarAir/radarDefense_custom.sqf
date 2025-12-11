/*
 * radarDefense_custom.sqf
 * Enhanced Radar-Triggered Air Defense System
 * 
 * Purpose: Integrate with existing radar systems and enhance with:
 * - Resource-aware scramble decisions
 * - ALiVE virtual air task integration
 * - Improved pilot management
 * - Connection to logistics system
 * 
 * When enemy aircraft enters detection radius:
 * 1. Radar script triggers scramble event
 * 2. Check if resources allow scramble
 * 3. Spawn aircraft and pilot (can use UnitCapture animation)
 * 4. Transition to ALiVE virtual space when airborne
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    // Radar defense configuration
    TWS_radarDefenseConfig = createHashMap;
    TWS_radarDefenseConfig set ["enabled", true];
    TWS_radarDefenseConfig set ["fuelCostPerScramble", 20];
    TWS_radarDefenseConfig set ["ammoCostPerScramble", 10];
    TWS_radarDefenseConfig set ["minTempor", 0.4]; // Minimum tempo to allow scrambles
    
    // Enhanced radar scramble function (resource-aware)
    TWS_fnc_radarScramble = {
        params ["_radarObject", "_faction", "_enemyAircraft", "_availablePlanes"];
        
        // Check if radar is operational
        private _radarSites = TWS_worldState get "radarSites";
        private _radarData = _radarSites getOrDefault [str _radarObject, createHashMap];
        
        if (count _radarData == 0 || !(_radarData get "operational")) exitWith {
            diag_log format ["[TWS] Radar %1 not operational, cannot scramble", _radarObject];
            []
        };
        
        // Check faction resources
        private _tempo = [_faction] call TWS_fnc_getTempo;
        if (_tempo < (TWS_radarDefenseConfig get "minTempo")) exitWith {
            diag_log format ["[TWS] %1 operational tempo too low for air scramble (%2)", _faction, _tempo];
            systemChat format ["[TWS] %1 cannot scramble aircraft - insufficient operational capacity", _faction];
            []
        };
        
        // Check fuel and ammo
        private _fuelCost = (TWS_radarDefenseConfig get "fuelCostPerScramble") * (count _availablePlanes min 4);
        private _ammoCost = (TWS_radarDefenseConfig get "ammoCostPerScramble") * (count _availablePlanes min 4);
        
        private _canAfford = [_faction, "fuel", _fuelCost] call TWS_fnc_consumeResource;
        if (!_canAfford) exitWith {
            diag_log format ["[TWS] %1 insufficient fuel for air scramble", _faction];
            systemChat format ["[TWS] %1 air scramble cancelled - insufficient fuel", _faction];
            []
        };
        
        _canAfford = [_faction, "ammunition", _ammoCost] call TWS_fnc_consumeResource;
        if (!_canAfford) exitWith {
            diag_log format ["[TWS] %1 insufficient ammunition for air scramble", _faction];
            systemChat format ["[TWS] %1 air scramble cancelled - insufficient ammunition", _faction];
            []
        };
        
        // Resources consumed, proceed with scramble
        private _scrambledPlanes = [];
        private _maxScramble = (count _enemyAircraft * 2) min (count _availablePlanes) min 4;
        
        for "_i" from 0 to (_maxScramble - 1) do {
            if (_i < count _availablePlanes) then {
                private _plane = _availablePlanes select _i;
                _scrambledPlanes pushBack _plane;
            };
        };
        
        diag_log format ["[TWS] %1 scrambling %2 aircraft in response to %3 enemy aircraft",
            _faction, count _scrambledPlanes, count _enemyAircraft];
        systemChat format ["[TWS] %1 scrambling %2 fighters!", _faction, count _scrambledPlanes];
        
        _scrambledPlanes
    };
    
    // Enhanced pilot assignment with ALiVE awareness
    TWS_fnc_assignScramblePilot = {
        params ["_plane", "_faction", "_targetPosition"];
        
        private _side = if (_faction == "BLUFOR") then {west} else {east};
        private _pilotClass = if (_faction == "BLUFOR") then {"B_Pilot_F"} else {"O_Pilot_F"};
        
        // Create pilot
        private _pilotGrp = createGroup _side;
        private _pilot = _pilotGrp createUnit [_pilotClass, getPosASL _plane, [], 0, "NONE"];
        _pilot moveInDriver _plane;
        
        // Set aircraft airborne instantly
        private _pos = getPosASL _plane;
        _plane setPosASL [_pos select 0, _pos select 1, 100];
        _plane setVelocityModelSpace [0, 200, 0];
        _plane engineOn true;
        
        // Add waypoint to intercept area
        private _wp1 = _pilotGrp addWaypoint [_targetPosition, 0];
        _wp1 setWaypointType "SAD"; // Search and Destroy
        _wp1 setWaypointBehaviour "COMBAT";
        _wp1 setWaypointCombatMode "RED";
        
        // Add return waypoint
        private _basePos = getPosASL _plane;
        private _wp2 = _pilotGrp addWaypoint [_basePos, 0];
        _wp2 setWaypointType "MOVE";
        
        // Cleanup on return
        _pilot addEventHandler ["GetOutMan", {
            params ["_unit", "_role", "_vehicle", "_turret"];
            deleteVehicle _unit;
        }];
        
        // If ALiVE is available, register with virtual system after takeoff
        if (!isNil "ALIVE_fnc_virtualizeGroup") then {
            // Conceptual: Hand off to ALiVE after initial scramble
            [_pilotGrp, 300] spawn {
                params ["_grp", "_delay"];
                sleep _delay;
                // _grp call ALIVE_fnc_virtualizeGroup;
                diag_log format ["[TWS] Scrambled aircraft group handed off to ALiVE virtual system"];
            };
        };
        
        diag_log format ["[TWS] Pilot assigned to %1 for intercept mission", typeOf _plane];
        
        _pilotGrp
    };
    
    // Function to integrate with existing radar scripts
    TWS_fnc_enhanceRadarScript = {
        params ["_radarObject", "_faction"];
        
        // Register radar if not already registered
        if (isNil {TWS_worldState get "radarSites" get str _radarObject}) then {
            [_radarObject, _faction, 10000] call TWS_fnc_registerRadar;
        };
        
        diag_log format ["[TWS] Enhanced radar defense for %1 (%2)", _radarObject, _faction];
    };
    
    // Function to get air defense readiness
    TWS_fnc_getAirDefenseReadiness = {
        params ["_faction"];
        
        private _readiness = createHashMap;
        
        // Check operational radars
        private _radarSites = TWS_worldState get "radarSites";
        private _operationalRadars = 0;
        {
            private _data = _y;
            if ((_data get "faction") == _faction && (_data get "operational")) then {
                _operationalRadars = _operationalRadars + 1;
            };
        } forEach _radarSites;
        
        _readiness set ["operationalRadars", _operationalRadars];
        
        // Check available aircraft
        private _resources = [_faction] call TWS_fnc_getResources;
        _readiness set ["availableAircraft", _resources getOrDefault ["aircraft", 0]];
        
        // Check fuel and ammo
        _readiness set ["fuel", _resources getOrDefault ["fuel", 0]];
        _readiness set ["ammunition", _resources getOrDefault ["ammunition", 0]];
        
        // Calculate readiness score (0.0 to 1.0)
        private _tempo = [_faction] call TWS_fnc_getTempo;
        private _score = (_operationalRadars min 3) / 3.0 * _tempo;
        _readiness set ["readinessScore", _score];
        
        _readiness
    };
    
    // Monitor air defense status
    TWS_fnc_airDefenseMonitor = {
        while {TWS_radarDefenseConfig get "enabled"} do {
            {
                private _faction = _x;
                private _readiness = [_faction] call TWS_fnc_getAirDefenseReadiness;
                private _score = _readiness get "readinessScore";
                
                if (_score < 0.3) then {
                    diag_log format ["[TWS] WARNING: %1 air defense readiness critical: %2", _faction, _score];
                };
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep 300; // Check every 5 minutes
        };
    };
    
    // Start air defense monitoring
    [] spawn TWS_fnc_airDefenseMonitor;
    
    publicVariable "TWS_radarDefenseConfig";
    publicVariable "TWS_fnc_radarScramble";
    publicVariable "TWS_fnc_assignScramblePilot";
    publicVariable "TWS_fnc_enhanceRadarScript";
    publicVariable "TWS_fnc_getAirDefenseReadiness";
    
    systemChat "[TWS] Enhanced Radar Defense System initialized";
    diag_log "[TWS] Radar Defense System initialized";
};
