if (isServer) then {
    while { true } do {
        // Create the helicopter and its group
        private _heliGroup = createGroup east; 
        private _heli = [getMarkerPos "heli_spawn_2", 0, "O_Heli_Light_02_dynamicloadout_F", _heliGroup] call BIS_fnc_spawnVehicle;

        // Wait a moment for the helicopter to initialize
        sleep 1;

        // Get the position of the cargo depot and spawn position
        private _cargoDepotPos = getMarkerPos "cargo_depot_2";
        private _spawnPos = getMarkerPos "heli_spawn_2";

        // Create a waypoint to the cargo depot
        private _wpLoad = _heliGroup addWaypoint [_cargoDepotPos, 0];
        _wpLoad setWaypointType "HOOK";
        _wpLoad setWaypointCompletionRadius 5;
        _wpLoad setWaypointSpeed "NORMAL";

        // Get all military markers within a specified radius (6000 meters)
        private _militaryMarkers = sectors_military select {
            private _markerPos = markerPos _x;
            (_markerPos distance _spawnPos) <= 6000 // Check if the marker position is within 7000 meters
        };

        // Check if there are any military markers available
        if (count _militaryMarkers > 0) then {
            // Select a random military marker
            private _randomIndex = floor random count _militaryMarkers;
            private _targetMarker = _militaryMarkers select _randomIndex;

            // Get the position of the selected marker
            private _targetPos = markerPos _targetMarker;

            // Check the ownership of the selected military sector
            private _ownership = [_targetPos] call KPLIB_fnc_getSectorOwnership;

            // Allow delivery to OPFOR and Civilian sectors
            if (_ownership == GRLIB_side_enemy || _ownership == GRLIB_side_civilian) then {
                // Create a waypoint to the military marker
                private _wpMove = _heliGroup addWaypoint [_targetPos, 0];
                _wpMove setWaypointType "MOVE";
                _wpMove setWaypointCompletionRadius 10;
                _wpMove setWaypointSpeed "FULL";

                // Create a waypoint to unhook the cargo at the military marker
                private _wpUnload = _heliGroup addWaypoint [_targetPos, 0];
                _wpUnload setWaypointType "UNHOOK";
                _wpUnload setWaypointCompletionRadius 10;
                _wpUnload setWaypointSpeed "FULL";

                // Optionally, add a return waypoint to the heli spawn position
                private _returnWp = _heliGroup addWaypoint [_spawnPos, 0];
                _returnWp setWaypointType "MOVE";
                _returnWp setWaypointCompletionRadius 10;
                _returnWp setWaypointSpeed "FULL";
                _returnWp setWaypointStatements ["true", "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this];"];

                // Set the behavior and combat mode if needed
                _heliGroup setBehaviour "SAFE";
                _heliGroup setCombatMode "GREEN";
            } else {
                diag_log format ["Helicopter won't proceed: %1 is controlled by %2", _targetMarker, _ownership];
                hint format ["Helicopter won't proceed: %1 is controlled by %2", _targetMarker, _ownership];
            };
        } else {
            diag_log "No military markers found within 6000 meters!";
        };

        // Wait for 20 minutes before repeating the process
        sleep 1200; // 20 minutes in seconds
    };
};
