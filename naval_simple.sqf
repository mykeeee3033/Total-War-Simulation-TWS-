/*
    Fixed Naval Virtualization for ALiVE
    
    Execute with: execVM "naval_simple.sqf"
    
    This script creates naval profiles manually and bypasses ALiVE's broken functions.
*/

// Wait for ALiVE to initialize
if (isNil "ALIVE_profileHandler") then {
    systemChat "Waiting for ALiVE to initialize...";
    waitUntil {!isNil "ALIVE_profileHandler"};
    sleep 2;
};

systemChat "Creating naval profiles manually...";

// Find naval groups and create profiles manually
private _navalCount = 0;

{
    private _vehicle = _x;
    
    if ((_vehicle isKindOf "Ship" || _vehicle isKindOf "Boat") && count crew _vehicle > 0) then {
        if ((_vehicle getVariable ["profileID", ""]) == "") then {
            
            private _group = group (crew _vehicle select 0);
            if (!isPlayer leader _group && !isNull leader _group) then {
                
                private _leader = leader _group;
                private _units = units _group;
                private _position = getPosATL _leader;
                
                // Create entity profile manually
                private _entityID = [ALIVE_profileHandler, "getNextInsertEntityID"] call ALIVE_fnc_profileHandler;
                
                private _unitClasses = [];
                private _positions = [];
                private _ranks = [];
                private _damages = [];
                
                {
                    _unitClasses pushBack (typeOf _x);
                    _positions pushBack (getPosATL _x);
                    _ranks pushBack (rank _x);
                    _damages pushBack (damage _x);
                } forEach _units;
                
                private _profileEntity = [nil, "create"] call ALIVE_fnc_profileEntity;
                [_profileEntity, "init"] call ALIVE_fnc_profileEntity;
                [_profileEntity, "profileID", _entityID] call ALIVE_fnc_profileEntity;
                [_profileEntity, "unitClasses", _unitClasses] call ALIVE_fnc_profileEntity;
                [_profileEntity, "position", _position] call ALIVE_fnc_profileEntity;
                [_profileEntity, "despawnPosition", _position] call ALIVE_fnc_profileEntity;
                [_profileEntity, "positions", _positions] call ALIVE_fnc_profileEntity;
                [_profileEntity, "damages", _damages] call ALIVE_fnc_profileEntity;
                [_profileEntity, "ranks", _ranks] call ALIVE_fnc_profileEntity;
                [_profileEntity, "side", str(side _group)] call ALIVE_fnc_profileEntity;
                [_profileEntity, "faction", faction _leader] call ALIVE_fnc_profileEntity;
                [_profileEntity, "isPlayer", false] call ALIVE_fnc_profileEntity;
                [_profileEntity, "objectType", "ship"] call ALIVE_fnc_profileEntity;
                
                // Copy waypoints from original group
                private _waypoints = waypoints _group;
                if (currentWaypoint _group < count _waypoints) then {
                    for "_i" from (currentWaypoint _group) to (count _waypoints - 1) do {
                        private _profileWaypoint = [(_waypoints select _i)] call ALIVE_fnc_waypointToProfileWaypoint;
                        [_profileEntity, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;
                    };
                };
                
                // If no waypoints, add basic patrol pattern
                if (count waypoints _group <= 1) then {
                    for "_i" from 0 to 3 do {
                        private _patrolPos = [_position, 500 + (random 1000), _i * 90 + (random 45)] call BIS_fnc_relPos;
                        
                        // Ensure waypoint is over water
                        if (!surfaceIsWater _patrolPos) then {
                            private _nearestSea = [_patrolPos] call ALiVE_fnc_getClosestSea;
                            if (!isNil "_nearestSea" && count _nearestSea > 0) then {
                                _patrolPos = _nearestSea;
                            };
                        };
                        
                        private _waypoint = [_patrolPos, 200, "MOVE", "LIMITED", 100, [], "LINE"] call ALIVE_fnc_createProfileWaypoint;
                        [_profileEntity, "addWaypoint", _waypoint] call ALIVE_fnc_profileEntity;
                    };
                    
                    // Add cycle waypoint
                    private _cycleWaypoint = [_position, 200, "CYCLE", "LIMITED", 100, [], "LINE"] call ALIVE_fnc_createProfileWaypoint;
                    [_profileEntity, "addWaypoint", _cycleWaypoint] call ALIVE_fnc_profileEntity;
                };
                
                // Register profile
                [ALIVE_profileHandler, "registerProfile", _profileEntity] call ALIVE_fnc_profileHandler;
                
                // Create vehicle profile
                private _vehicleID = [ALIVE_profileHandler, "getNextInsertVehicleID"] call ALIVE_fnc_profileHandler;
                
                private _profileVehicle = [nil, "create"] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "init"] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "profileID", _vehicleID] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "vehicleClass", typeOf _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "position", _position] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "despawnPosition", _position] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "direction", getDir _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "damage", _vehicle call ALIVE_fnc_vehicleGetDamage] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "fuel", fuel _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "ammo", _vehicle call ALIVE_fnc_vehicleGetAmmo] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "side", str(side _vehicle)] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "faction", faction _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "objectType", "ship"] call ALIVE_fnc_profileVehicle;
                
                [ALIVE_profileHandler, "registerProfile", _profileVehicle] call ALIVE_fnc_profileHandler;
                
                // Create vehicle assignment
                private _assignments = [_vehicle, _group] call ALIVE_fnc_vehicleAssignmentToProfileVehicleAssignment;
                private _vehicleAssignments = [_vehicleID, _entityID, _assignments];
                
                [_profileEntity, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileEntity;
                [_profileVehicle, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileVehicle;
                
                // Mark vehicle
                _vehicle setVariable ["profileID", _vehicleID];
                
                // Delete originals
                {
                    deleteVehicle _x;
                } forEach _units;
                deleteVehicle _vehicle;
                
                _navalCount = _navalCount + 1;
            };
        };
    };
} forEach vehicles;

systemChat format ["Created %1 naval profiles - they will spawn over water normally", _navalCount];