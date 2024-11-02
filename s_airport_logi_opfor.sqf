 _crew1 = [];
_airframe1 = [];
_cargo = [];

if (isServer) then {
	while {true} do {
		_crew1 = createGroup east; 
		_airframe1 = [getMarkerPos "logi_spawn_opfor", 140, "RHS_C130J_Cargo", _crew1] call BIS_fnc_spawnVehicle;

		// Waypoint 1: Plane reaches destination and drops resources at the depot
		_wp1 = _crew1 addWaypoint [(getMarkerPos "military_2"), 0];
		_wp1 setWaypointType "GETOUT";
		_wp1 setWaypointSpeed "FULL";

		_wp1 setWaypointStatements ["true", "
    private _spawnPos = getMarkerPos 'cargo_depot_2';
    private _crateAmount = 10;
    for '_i' from 1 to _crateAmount do {
        private _crateType = selectRandom KPLIB_crates;
        [_crateType, 100, _spawnPos] call KPLIB_fnc_createCrate;
    };
    hint 'C130 resupply complete';
    [east, 50] call BIS_fnc_respawnTickets;
"];


		// Waypoint 2: Plane prepares for takeoff back to spawn
		_wp2 = _crew1 addWaypoint [(getMarkerPos "military_2"), 0];
		_wp2 setWaypointType "GETIN NEAREST";
		_wp2 setWaypointSpeed "FULL";
		_wp2 setWaypointStatements ["true", "hint 'C17 Egressing: Next flight will be in 1 hour.';"];

		// Waypoint 3: Plane returns to spawn, then deletes itself
		_wp3 = _crew1 addWaypoint [(getMarkerPos "logi_spawn_opfor"), 0];
		_wp3 setWaypointType "MOVE";
		_wp3 setWaypointSpeed "FULL";
		_wp3 setWaypointStatements ["true", "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this];"];

		// Delay before the next plane spawns
		sleep 3600;
	};
};
