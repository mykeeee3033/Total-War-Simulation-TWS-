// Monitor BLUFOR squads: only one truck dispatched at a time, driver returns to base and is deleted, cooldown added
[] spawn {
    private _lastDispatch = 0;
    while {true} do {
        private _hq = bluf_HQ;
        private _truckTypes = ["B_Truck_01_ammo_F", "O_Truck_02_Ammo_F", "O_T_Truck_02_Ammo_F", "O_T_Truck_03_ammo_ghex_F", "O_Truck_03_ammo_F"];
        private _ammoTrucks = [];
        {
            private _found = (_hq getPos [0,0]) nearEntities [_x, 200];
            _ammoTrucks append _found;
        } forEach _truckTypes;
        //systemChat format ["[LOGISTICS] Detected ammo trucks: %1", count _ammoTrucks];
        // Only dispatch if ALL trucks are empty (no driver currently assigned) and cooldown expired
        private _activeTrucks = _ammoTrucks select {count crew _x > 0};
        private _now = time;
        if (count _activeTrucks == 0 && (_now - _lastDispatch > 300)) then {
            private _bluforGroups = allGroups select {side _x == west};
            private _priorityGrp = objNull;
            private _priorityAmmo = 9999;
            private _prioritySize = 0;
            {
                private _grp = _x;
                private _units = units _grp;
                if (count _units == 0) exitWith {};
                private _ammoCount = 0;
                {
                    _ammoCount = _ammoCount + (count magazines _x);
                } forEach _units;
                private _avgAmmo = _ammoCount / count _units;
                private _size = count _units;
                // Find squad with lowest avg ammo, prefer larger squads if tied
                if (_avgAmmo < _priorityAmmo || (_avgAmmo == _priorityAmmo && _size > _prioritySize)) then {
                    _priorityGrp = _grp;
                    _priorityAmmo = _avgAmmo;
                    _prioritySize = _size;
                };
            } forEach _bluforGroups;
            if (!isNull _priorityGrp && _priorityAmmo < 3) then {
                systemChat format ["[LOGISTICS] Priority squad: %1 | Size: %2 | Avg Ammo: %3", groupId _priorityGrp, _prioritySize, _priorityAmmo];
                private _emptyTrucks = _ammoTrucks select {count crew _x == 0};
                //systemChat format ["[LOGISTICS] Empty trucks: %1", count _emptyTrucks];
                if (count _emptyTrucks > 0) then {
                    private _veh = _emptyTrucks select 0;
                    private _crewGrp = createGroup west;
                    private _driver = _crewGrp createUnit ["B_Soldier_F", getPos _veh, [], 0, "NONE"];
                    _driver moveInDriver _veh;
                    //systemChat format ["[LOGISTICS] Driver spawned in %1, heading to %2", typeOf _veh, groupId _priorityGrp];
                    // Move to squad
                    private _destPos = getPos leader _priorityGrp;
                    private _wp1 = _crewGrp addWaypoint [_destPos, 0];
                    _wp1 setWaypointType "MOVE";
                    // Create temporary marker at destination
                    private _markerName = format ["logi_dest_%1", str random 100000];
                    private _marker = createMarker [_markerName, _destPos];
                    _marker setMarkerType "mil_dot";
                    _marker setMarkerColor "ColorYellow";
                    _marker setMarkerText "Resupply";
                    [_markerName] spawn {
                        params ["_mName"];
                        sleep 30;
                        deleteMarker _mName;
                    };
                    // Return to HQ and get out
                    private _wp2 = _crewGrp addWaypoint [getPos _hq, 0];
                    _wp2 setWaypointType "GETOUT";
                    // Delete driver when he gets out at HQ
                    _driver addEventHandler ["GetOutMan", {
                        params ["_unit", "_role", "_vehicle", "_turret"];
                        deleteVehicle _unit;
                    }];
                    _lastDispatch = _now;
                } else {
                    systemChat "[LOGISTICS] No empty trucks available!";
                };
            };
        } else {
            if (_now - _lastDispatch <= 300) then {
                //systemChat format ["[LOGISTICS] Cooldown active: %1 seconds left", 300 - (_now - _lastDispatch)];
            } else {
                //systemChat format ["[LOGISTICS] Truck(s) already dispatched: %1", count _activeTrucks];
            };
        };
        sleep 30;
    };
};
