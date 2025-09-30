// Air Assault Phase: Detect and assign planes for CAS
private _hq = bluf_HQ;
private _targetMarker = "target_1";
private _targetPos = getMarkerPos _targetMarker;
private _basePos = _hq getPos [500, 0];

// Detect empty planes near HQ
private _nearPlanes = (_hq getPos [0,0]) nearEntities ["Plane", 500];
private _emptyPlanes = _nearPlanes select {count crew _x == 0};
systemChat format ["[AIR ASSAULT] Found empty planes: %1", _emptyPlanes];

{
    private _plane = _x;
    private _crewGrp = createGroup west;
    private _pilot = _crewGrp createUnit ["B_Pilot_F", getPos _plane, [], 0, "NONE"];
    _pilot moveInDriver _plane;
    systemChat format ["[AIR ASSAULT] Pilot spawned for %1", typeOf _plane];
    // Assign waypoints: SAD at target, then GETOUT at base
    private _wp1 = _crewGrp addWaypoint [_targetPos, 0];
    _wp1 setWaypointType "SAD";
    private _wp2 = _crewGrp addWaypoint [_basePos, 0];
    _wp2 setWaypointType "GETOUT";
    // Wait 5 minutes, then force RTB
    [_crewGrp, _wp2] spawn {
        params ["_grp", "_rtbWp"];
        sleep 300;
        systemChat "[AIR ASSAULT] Forcing planes to return to base!";
        _grp setCurrentWaypoint _rtbWp;
    };
    // Delete pilot and plane when they get out at base
    _pilot addEventHandler ["GetOutMan", {
        params ["_unit", "_role", "_vehicle", "_turret"];
        deleteVehicle _unit;
        deleteVehicle _vehicle;
    }];

} forEach _emptyPlanes;

// After planes are assigned SAD waypoints, wait 5 minutes then start main assault
[] spawn {
    sleep 300;
    systemChat "[AIR ASSAULT] Air phase complete. Starting main assault...";
    [] execVM "main_assault.sqf";
};

// OPFOR ticket-based reinforcement system at target_1
private _maxTickets = 50; // Change as needed (100-300)
private _tickets = _maxTickets;
private _maxAlive = 20;
private _spawnDelay = 300;
private _groupType = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad_Weapons";
private _spawnPos = getMarkerPos "target_1";

systemChat format ["[REINFORCEMENT] Starting OPFOR ticket system: %1 tickets, %2 max alive, %3s spawn delay.", _maxTickets, _maxAlive, _spawnDelay];

[] spawn {
    private _tickets = 50; // Set to same as above
    private _maxAlive = 20;
    private _spawnDelay = 300;
    private _groupType = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad_Weapons";
    private _spawnPos = getMarkerPos "target_1";
    // Gather all statics and vehicles near target_1 (pool, no overlap)
    private _searchTypes = ["StaticWeapon", "Car", "Tank", "Truck", "APC_Wheeled_01_cannon_F"];
    private _targetsPool = [];
    {
        _targetsPool append (_spawnPos nearEntities [_x, 400]);
    } forEach _searchTypes;

    while {_tickets > 0} do {
        // Count alive OPFOR soldiers in area
        private _aliveUnits = (allUnits select {
            side _x == east && alive _x && (_spawnPos distance _x < 500)
        });
        private _numAlive = count _aliveUnits;
        if (_numAlive < _maxAlive) then {
            private _toSpawn = (_maxAlive - _numAlive) min _tickets;
            for [{_i = 0}, {_i < _toSpawn}, {_i = _i + 1}] do {
                // Spawn a full OPFOR squad using BIS_fnc_spawnGroup
                private _group = [_spawnPos, east, _groupType] call BIS_fnc_spawnGroup;
                _tickets = _tickets - (count units _group);
                // Find nearest available static/vehicle from pool
                private _nearest = objNull;
                private _nearestDist = 1e6;
                private _nearestIdx = -1;
                {
                    private _obj = _x;
                    private _dist = _spawnPos distance _obj;
                    if (_dist < _nearestDist) then {
                        _nearest = _obj;
                        _nearestDist = _dist;
                        _nearestIdx = _forEachIndex;
                    };
                } forEach _targetsPool;
                if (!isNull _nearest) then {
                    private _wp = _group addWaypoint [getPos _nearest, 0];
                    _wp setWaypointType "MOVE";
                    systemChat format ["[REINFORCEMENT] OPFOR squad assigned waypoint to unique static/vehicle at %1.", typeOf _nearest];
                    // Remove this target from pool so next squad doesn't use it
                    _targetsPool deleteAt _nearestIdx;
                } else {
                    private _wp = _group addWaypoint [_spawnPos, 0];
                    _wp setWaypointType "GUARD";
                    systemChat "[REINFORCEMENT] No statics/vehicles found, OPFOR squad assigned GUARD waypoint at target_1.";
                };
                systemChat format ["[REINFORCEMENT] OPFOR squad spawned at target_1. Tickets left: %1", _tickets];
                sleep _spawnDelay;
                if (_tickets <= 0) exitWith {};
            };
        };
        sleep 5;
    };
    systemChat "[REINFORCEMENT] OPFOR tickets exhausted. No more reinforcements will spawn.";
};
