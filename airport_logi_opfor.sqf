// Simple Arma 3 OPFOR logistics crate drop script
// Spawns a C-130 at logi_spawn_opfor, flies to cargo_depot, drops 5 crates, returns, deletes itself, repeats every hour

if (isServer) then {
    while {true} do {
        // Spawn C-130 and crew at logi_spawn_opfor marker
        private _crewGrp = createGroup east;
        private _spawnPos = getMarkerPos "logi_spawn_opfor";
        private _planeArr = [_spawnPos, 500, "RHS_C130J_Cargo", _crewGrp] call BIS_fnc_spawnVehicle;
    private _plane = _planeArr select 0;
    _plane flyInHeight 500;

        // Waypoint 1: Fly to depot and drop crates
        private _depotPos = getMarkerPos "cargo_depot_o";
        private _wp1 = _crewGrp addWaypoint [_depotPos, 0];
        _wp1 setWaypointType "GETOUT";
        _wp1 setWaypointSpeed "FULL";
            _wp1 setWaypointStatements ["true", "
                private _depotPos = getMarkerPos 'cargo_depot_o';
                private _crate1 = createVehicle ['O_supplyCrate_F', _depotPos, [], 0, 'NONE'];
                private _crate2 = createVehicle ['Box_East_Ammo_F', _depotPos, [], 0, 'NONE'];
                private _crate3 = createVehicle ['Box_East_Wps_F', _depotPos, [], 0, 'NONE'];
                private _crate4 = createVehicle ['CargoNet_01_box_F', _depotPos, [], 0, 'NONE'];
                _crate4 addItemCargoGlobal ['nfextra_logistics_Material', 10];
                _crate4 addItemCargoGlobal ['nfextra_logistics_MechPart', 10];
                _crate4 addItemCargoGlobal ['nfextra_respawn_RespawnItem', 10];
                private _taskID = 'cargoDelivery';
                [_taskID, 'C130 Resupply', 'Cargo has been delivered.', objNull, 'CREATED', 1, true] call BIS_fnc_taskCreate;
                [_taskID, 'SUCCEEDED'] call BIS_fnc_taskSetState;
                hint 'C130 resupply complete';
            "];

        // Waypoint 2: Crew gets back in plane
        private _wp2 = _crewGrp addWaypoint [_depotPos, 0];
        _wp2 setWaypointType "GETIN NEAREST";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointStatements ["true", "hint 'Crew re-boarding C130 for return flight.';"];

        // Waypoint 3: Return to base and delete plane
        private _basePos = getMarkerPos "logi_spawn_opfor";
        private _wp3 = _crewGrp addWaypoint [_basePos, 0];
        _wp3 setWaypointType "MOVE";
        _wp3 setWaypointSpeed "FULL";
        _wp3 setWaypointStatements ["true", "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this]; hint 'C130 deleted, next flight in 1 hour.';"];

        // Wait 1 hour before next flight
        sleep 3600;
    };
};
