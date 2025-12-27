call compile preprocessFileLineNumbers "radar_pool_detection.sqf";
// Only run once for WEST side
if (isNil "radar_west_monitor") then {
    radar_west_monitor = true;

    [] spawn {
        private _cooldown = false;

        // Initialize assigned planes variable if not already
        if (isNil "radar_west_assignedPlanes") then { radar_west_assignedPlanes = []; };

        // Set the BLUFOR response coefficient (change this value to adjust force ratio)
        if (isNil "radar_west_bluforCoefficient") then { radar_west_bluforCoefficient = 2; };

        while {true} do {
            // Get radar-equipped airbases for WEST side
            private _radarData = ["WEST"] call radar_fnc_poolDetection;
            _radarData params ["_availableAircraft", "_activeAirbases"];
            
            // Skip if no radar-equipped airbases
            if (count _activeAirbases == 0) then {
                sleep 10; // Wait longer if no radar airbases
                continue;
            };
            
            // Check for enemy aircraft near any of our radar-equipped airbases
            private _enemyPlanes = [];
            private _playerDetected = false;
            
            {
                _x params ["_airbasePos", "_hasRadar"];
                
                if (_hasRadar) then {
                    // Use 3km detection radius from radar-equipped airbase (optimized)
                    private _nearPlanes = _airbasePos nearEntities ["Plane", 3000];
                    private _enemyNear = _nearPlanes select {side _x == east};
                    _enemyPlanes append _enemyNear;
                    
                    // Check if player is enemy plane nearby
                    private _playerDist = _airbasePos distance player;
                    if (_playerDist <= 3000 && side player == east && (vehicle player isKindOf "Plane")) then {
                        _playerDetected = true;
                    };
                };
            } forEach _activeAirbases;
            
            // Remove duplicates
            _enemyPlanes = _enemyPlanes arrayIntersect _enemyPlanes;
            
            if ((count _enemyPlanes > 0) || _playerDetected) then {
                systemChat "OPFOR plane detected near BLUFOR radar!";

                // Only assign pilots to planes that haven't been assigned yet
                private _unassignedPlanes = _availableAircraft select {!( _x in radar_west_assignedPlanes )};
                private _alreadyAssigned = count radar_west_assignedPlanes;
                private _opforCount = (count _enemyPlanes) + (if (_playerDetected) then {1} else {0});
                private _desiredBlufor = _opforCount * radar_west_bluforCoefficient;
                private _numToAssign = (_desiredBlufor - _alreadyAssigned) min (count _unassignedPlanes);

                if (_numToAssign > 0) then {
                    {
                        private _selectedPlane = _x;
                        private _pilotGrp = createGroup west;
                        private _pilot = _pilotGrp createUnit ["B_Pilot_F", getPosASL _selectedPlane, [], 0, "NONE"];
                        _pilot moveInDriver _selectedPlane;
                        // Instantly set the plane airborne at 100m and give forward speed
                        private _pos = getPosASL _selectedPlane;
                        _selectedPlane setPosASL [_pos select 0, _pos select 1, 100];
                        _selectedPlane setVelocityModelSpace [0, 200, 0];
                        _selectedPlane engineOn true;
                        radar_west_assignedPlanes pushBack _selectedPlane;
                        systemChat format ["BLUFOR pilot spawned and placed in %1!", typeOf _selectedPlane];

                        // Find the nearest OPFOR plane to target
                        private _target = objNull;
                        if (count _enemyPlanes > 0) then {
                            _target = _enemyPlanes select 0;
                        } else {
                            if (_playerDetected) then {
                                _target = vehicle player;
                            };
                        };
                        // Add seek and destroy waypoint
                        if (!isNull _target) then {
                            private _wp1 = _pilotGrp addWaypoint [getPosASL _target, 0];
                            _wp1 setWaypointType "DESTROY";
                        };
                        // Add return to nearest airbase waypoint
                        if (count _activeAirbases > 0) then {
                            private _nearestBase = (_activeAirbases select 0) select 0;
                            private _wp2 = _pilotGrp addWaypoint [_nearestBase, 0];
                            _wp2 setWaypointType "GETOUT";
                        };
                        // Delete pilot when they get out at base
                        _pilot addEventHandler ["GetOutMan", {
                            params ["_unit", "_role", "_vehicle", "_turret"];
                            deleteVehicle _unit;
                        }];
                        sleep 5;
                    } forEach (_unassignedPlanes select [0, _numToAssign]);
                } else {
                    systemChat "No available unassigned aircraft to assign a pilot or already matched OPFOR count!";
                };
            };

            sleep 10; // Check every 10 seconds (optimized for performance)
        };
    };
};