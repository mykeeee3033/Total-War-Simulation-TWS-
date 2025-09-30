// Check for HQ object
if (!isNull bluf_HQ) then {
    systemChat "[INVASION] HQ found, scanning for artillery vehicles...";
    private _artilleryTypes = ["B_MBT_01_arty_F", "B_MBT_01_mlrs_F", "O_MBT_02_arty_F", "O_MBT_01_mlrs_F"];
    private _artilleryPool = (bluf_HQ getPos [0,0]) nearEntities [_artilleryTypes, 500];
    systemChat format ["[INVASION] Found artillery vehicles: %1", _artilleryPool];
    // Spawn crew in empty artillery vehicles
    {
        if (count crew _x == 0) then {
            private _crewGrp = createGroup west;
            private _driver = _crewGrp createUnit ["B_Soldier_F", getPos _x, [], 0, "NONE"];
            _driver moveInDriver _x;
            if (_x emptyPositions "Gunner" > 0) then {
                private _gunner = _crewGrp createUnit ["B_Soldier_F", getPos _x, [], 0, "NONE"];
                _gunner moveInGunner _x;
            };
            if (_x emptyPositions "Commander" > 0) then {
                private _commander = _crewGrp createUnit ["B_Soldier_F", getPos _x, [], 0, "NONE"];
                _commander moveInCommander _x;
            };
            systemChat format ["[INVASION] Crew spawned for %1", typeOf _x];
        };
    } forEach _artilleryPool;
    sleep 5; // Give AI time to initialize
    // Order each artillery vehicle to fire randomized rounds on target_1 marker
    private _targetPos = getMarkerPos "target_1";
    private _radius = 150; // Random impact radius around marker
    {
        private _veh = _x;
        private _ammo = getArtilleryAmmo [_veh] select 0;
        //select how many rounds to fire
        for "_i" from 1 to 20 do {
            private _rndPos = [
                (_targetPos select 0) - _radius + (2 * random _radius),
                (_targetPos select 1) - _radius + (2 * random _radius),
                0
            ];
            systemChat format ["[INVASION] Artillery %1 commandArtilleryFire at %2 with ammo %3", typeOf _veh, _rndPos, _ammo];
            _veh commandArtilleryFire [_rndPos, _ammo, 1];
            sleep 2; // Delay between rounds
        };
        systemChat format ["[INVASION] Artillery %1 finished firing.", typeOf _veh];
    } forEach _artilleryPool;
    // Spawn 4 OPFOR assault groups with garrison waypoints
    private _opforSpawnPos = getMarkerPos "target_1";
    private _numGroups = 4;
    // Gather all statics and vehicles near target_1
    private _searchTypes = ["StaticWeapon", "Car", "Tank", "Truck", "APC_Wheeled_01_cannon_F"];
    private _targetsPool = [];
    {
        _targetsPool append (_opforSpawnPos nearEntities [_x, 400]);
    } forEach _searchTypes;

    for [{_i = 0}, {_i < _numGroups}, {_i = _i + 1}] do {
        // Spawn OPFOR infantry group at target_1 using BIS_fnc_spawnGroup
        private _group = [_opforSpawnPos, east, configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad_Weapons"] call BIS_fnc_spawnGroup;
        systemChat format ["[INVASION] OPFOR group %1 spawned at target_1.", _i + 1];

        // Find nearest available static/vehicle from pool
        private _nearest = objNull;
        private _nearestDist = 1e6;
        private _nearestIdx = -1;
        {
            private _obj = _x;
            private _dist = _opforSpawnPos distance _obj;
            if (_dist < _nearestDist) then {
                _nearest = _obj;
                _nearestDist = _dist;
                _nearestIdx = _forEachIndex;
            };
        } forEach _targetsPool;

        if (!isNull _nearest) then {
            private _wp = _group addWaypoint [getPos _nearest, 0];
            _wp setWaypointType "MOVE";
            systemChat format ["[INVASION] OPFOR group %1 ordered to unique static/vehicle at %2.", _i + 1, typeOf _nearest];
            // Remove this target from pool so next group doesn't use it
            _targetsPool deleteAt _nearestIdx;
        } else {
            private _wp = _group addWaypoint [_opforSpawnPos, 0];
            _wp setWaypointType "GUARD";
            systemChat format ["[INVASION] OPFOR group %1: No statics/vehicles found, ordered to GUARD at target_1.", _i + 1];
        };
    };

    // Start air assault phase after artillery finishes
    systemChat "[INVASION] Artillery phase complete. Starting air assault phase...";
    [] execVM "air_assault_phase.sqf";
} else {
    systemChat "[INVASION] HQ object not found!";
};




