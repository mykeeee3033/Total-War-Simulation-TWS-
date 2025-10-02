call compile preprocessFileLineNumbers "radar_pool_detection.sqf";
// Only run once per radar
if (isNil "radar_2_monitor") then {
    radar_2_monitor = true;

    [] spawn {
        private _cooldown = false;

        // Initialize assigned planes variable if not already
        if (isNil "radar_2_assignedPlanes") then { radar_2_assignedPlanes = []; };

        // Set the BLUFOR response coefficient (change this value to adjust force ratio)
        if (isNil "radar_2_bluforCoefficient") then { radar_2_bluforCoefficient = 2; };

        // Define the base position for BLUFOR planes to return to (edit as needed)
        if (isNil "radar_2_basePos") then { radar_2_basePos = getPosASL radar_2; };

        while {alive radar_2} do {
            // Debug: confirm script is running
            //systemChat "Radar script running...";

            // Find nearby OPFOR planes only
            private _nearPlanes = (getPosASL radar_2) nearEntities ["Plane", 10000];
            private _enemyPlanes = _nearPlanes select {side _x == east};

            // For player testing: also check if player is in a plane and within 10km
            private _playerDist = radar_2 distance player;
            private _playerIsPlane = vehicle player isKindOf "Plane";
            private _pool = [radar_2] call radar_fnc_poolDetection;
            private _poolCount = count _pool;
            //private _poolClasses = _pool apply {typeOf _x}; - tells you what kind of planes are available
            //systemChat format ["Player distance to radar: %1, Player in plane: %2, Available aircraft: %3 (%4)", _playerDist, _playerIsPlane, _poolCount]; // debug messages activation

            if ((count _enemyPlanes > 0) || {_playerDist <= 10000 && side player == east && _playerIsPlane}) then {
                systemChat "OPFOR plane detected near radar!";

                // Only assign pilots to planes that haven't been assigned yet
                private _unassignedPlanes = _pool select {!( _x in radar_2_assignedPlanes )};
                private _alreadyAssigned = count radar_2_assignedPlanes;
                private _opforCount = (count _enemyPlanes) + (if (_playerDist <= 10000 && side player == east && _playerIsPlane) then {1} else {0});
                private _desiredBlufor = _opforCount * radar_2_bluforCoefficient;
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
                        radar_2_assignedPlanes pushBack _selectedPlane;
                        systemChat format ["BLUFOR pilot spawned and placed in %1!", typeOf _selectedPlane];

                        // Find the nearest OPFOR plane to target
                        private _target = objNull;
                        if (count _enemyPlanes > 0) then {
                            _target = _enemyPlanes select 0;
                        } else {
                            if (_playerDist <= 10000 && side player == east && _playerIsPlane) then {
                                _target = vehicle player;
                            };
                        };
                        // Add seek and destroy waypoint
                        if (!isNull _target) then {
                            private _wp1 = _pilotGrp addWaypoint [getPosASL _target, 0];
                            _wp1 setWaypointType "DESTROY";
                        };
                        // Add return to base (get out) waypoint
                        private _wp2 = _pilotGrp addWaypoint [radar_2_basePos, 0];
                        _wp2 setWaypointType "GETOUT";
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

            sleep 2; // Check every 2 seconds for faster response
        };
    };
};