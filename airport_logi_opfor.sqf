// Simple Arma 3 OPFOR logistics crate drop script
// Spawns an ammo helicopter at logi_spawn_opfor, flies to cargo_depot, drops 3 crates, returns, deletes itself, repeats every hour

TWS_OPFLOGI_fnc_getSectorOwnership = {
    params ["_position"];

    if (isNil "ALiVE_sectorGrid") exitWith {"Neutral"};

    private _ownership = "Neutral";
    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {_ownership};

    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (count _sectorData == 0) exitWith {_ownership};

    private _dominatingSide = "None";
    private _maxCount = 0;

    if ("entitiesBySide" in (_sectorData select 1)) then {
        private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALIVE_fnc_hashGet;
        {
            private _side = _x;
            if (_side in (_entitiesBySide select 1)) then {
                private _sideEntities = [_entitiesBySide, _side] call ALIVE_fnc_hashGet;
                private _entityCount = count _sideEntities;
                if (_entityCount > _maxCount) then {
                    _maxCount = _entityCount;
                    _dominatingSide = _side;
                };
            };
        } forEach ["EAST", "WEST", "GUER", "CIV"];
    };

    if ("vehiclesBySide" in (_sectorData select 1)) then {
        private _vehiclesBySide = [_sectorData, "vehiclesBySide"] call ALIVE_fnc_hashGet;
        {
            private _side = _x;
            if (_side in (_vehiclesBySide select 1)) then {
                private _sideVehicles = [_vehiclesBySide, _side] call ALIVE_fnc_hashGet;
                private _vehicleCount = count _sideVehicles;
                if (_side == _dominatingSide) then {
                    _maxCount = _maxCount + _vehicleCount;
                } else {
                    if (_vehicleCount > _maxCount) then {
                        _maxCount = _vehicleCount;
                        _dominatingSide = _side;
                    };
                };
            };
        } forEach ["EAST", "WEST", "GUER", "CIV"];
    };

    if (_maxCount > 0) then {
        switch (_dominatingSide) do {
            case "WEST": {_ownership = "BLUFOR"};
            case "EAST": {_ownership = "OPFOR"};
            case "GUER": {_ownership = "INDEP"};
            default {_ownership = "Neutral"};
        };
    };

    _ownership
};

TWS_OPFLOGI_fnc_hasDepotSupplies = {
    params ["_depotPos", ["_radius", 200]];

    private _supplyClasses = [
        "O_supplyCrate_F",
        "CargoNet_01_box_F",
        "Box_East_Ammo_F",
        "Box_East_Wps_F"
    ];

    private _supplyObjects = [];
    {
        _supplyObjects append (_depotPos nearObjects [_x, _radius]);
    } forEach _supplyClasses;

    (count _supplyObjects) > 0
};

if (isServer) then {
    while {true} do {
        private _depotPos = getMarkerPos "cargo_depot_o";
        private _ownership = [_depotPos] call TWS_OPFLOGI_fnc_getSectorOwnership;

        if !(_ownership isEqualTo "OPFOR") then {
            systemChat format ["[OPFOR Logistics] Skipping run: depot sector is %1 (needs OPFOR)", _ownership];
            sleep 3600;
            continue;
        };

        if ([_depotPos, 200] call TWS_OPFLOGI_fnc_hasDepotSupplies) then {
            systemChat "[OPFOR Logistics] Skipping run: supplies already present near depot (200m).";
            sleep 3600;
            continue;
        };

        // Spawn ammo helicopter and crew at logi_spawn_opfor marker
        private _crewGrp = createGroup east;
        private _spawnPos = getMarkerPos "logi_spawn_opfor";
        private _heliArr = [_spawnPos, 500, "O_Heli_Transport_04_ammo_F", _crewGrp] call BIS_fnc_spawnVehicle;
    private _heli = _heliArr select 0;
    _heli flyInHeight 120;

        // Waypoint 1: Fly to depot and drop crates
        private _wp1 = _crewGrp addWaypoint [_depotPos, 0];
        _wp1 setWaypointType "GETOUT";
        _wp1 setWaypointSpeed "FULL";
            _wp1 setWaypointStatements ["true", "
                private _depotPos = getMarkerPos 'cargo_depot_o';
                for '_i' from 1 to 3 do {
                    private _offset = [random 40 - 20, random 40 - 20, 0];
                    private _cratePos = _depotPos vectorAdd _offset;
                    private _crate = createVehicle ['O_supplyCrate_F', _cratePos, [], 0, 'NONE'];
                    clearItemCargoGlobal _crate;
                    clearWeaponCargoGlobal _crate;
                    clearMagazineCargoGlobal _crate;
                    _crate addItemCargoGlobal ['FirstAidKit', 10];
                    _crate addWeaponCargoGlobal ['arifle_Katiba_F', 5];
                    _crate addMagazineCargoGlobal ['30Rnd_65x39_caseless_green', 30];
                    _crate addItemCargoGlobal ['HandGrenade', 8];
                };
                private _taskID = 'cargoDelivery';
                [_taskID, 'Ammo Heli Resupply', 'Cargo has been delivered.', objNull, 'CREATED', 1, true] call BIS_fnc_taskCreate;
                [_taskID, 'SUCCEEDED'] call BIS_fnc_taskSetState;
                hint 'Ammo helicopter resupply complete';
            "];

        // Waypoint 2: Crew gets back in helicopter
        private _wp2 = _crewGrp addWaypoint [_depotPos, 0];
        _wp2 setWaypointType "GETIN NEAREST";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointStatements ["true", "hint 'Crew re-boarding ammo helicopter for return flight.';"];

        // Waypoint 3: Return to base and delete helicopter
        private _basePos = getMarkerPos "logi_spawn_opfor";
        private _wp3 = _crewGrp addWaypoint [_basePos, 0];
        _wp3 setWaypointType "MOVE";
        _wp3 setWaypointSpeed "FULL";
        _wp3 setWaypointStatements ["true", "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this]; hint 'Ammo helicopter deleted, next flight in 1 hour.';"];

        // Wait 1 hour before next flight
        sleep 3600;
    };
};
