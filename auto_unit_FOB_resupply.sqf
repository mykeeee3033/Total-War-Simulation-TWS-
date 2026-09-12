/*
 * auto_unit_FOB_resupply.sqf
 *
 * Purpose:
 * - Gives FOB cargo nets active gameplay purpose for nearby OPFOR AI.
 * - Every 3 minutes, scans cargo nets and sends nearby OPFOR AI groups to rearm.
 *
 * Scope:
 * - Only affects AI units near cargo nets (FOB context).
 * - Does not affect field/city units away from FOB supply nodes.
 */

if (!isServer) exitWith {
    diag_log "[AUTO_FOB_RESUPPLY] Script runs on server only.";
};

if (isNil "TWS_AUTO_FOB_RESUPPLY_running") then { TWS_AUTO_FOB_RESUPPLY_running = false; };
if (isNil "TWS_AUTO_FOB_RESUPPLY_interval") then { TWS_AUTO_FOB_RESUPPLY_interval = 180; };
if (isNil "TWS_AUTO_FOB_RESUPPLY_radius") then { TWS_AUTO_FOB_RESUPPLY_radius = 50; };
if (isNil "TWS_AUTO_FOB_RESUPPLY_cargoNetClass") then { TWS_AUTO_FOB_RESUPPLY_cargoNetClass = "O_CargoNet_01_ammo_F"; };

if (TWS_AUTO_FOB_RESUPPLY_running) exitWith {
    diag_log "[AUTO_FOB_RESUPPLY] Already running.";
};

TWS_AUTO_FOB_RESUPPLY_running = true;
publicVariable "TWS_AUTO_FOB_RESUPPLY_running";

[] spawn {
    diag_log "[AUTO_FOB_RESUPPLY] Started.";

    while {TWS_AUTO_FOB_RESUPPLY_running} do {
        private _cargoNets = entities TWS_AUTO_FOB_RESUPPLY_cargoNetClass;
        _cargoNets = _cargoNets select {alive _x};

        {
            private _cargoNet = _x;
            private _netPos = getPosATL _cargoNet;

            // Find OPFOR AI infantry near this cargo net (FOB-local only).
            private _nearbyUnits = _netPos nearEntities [["Man"], TWS_AUTO_FOB_RESUPPLY_radius];
            private _opforUnits = _nearbyUnits select {
                alive _x &&
                !isPlayer _x &&
                (side _x == east || {side (group _x) == east})
            };

            if ((count _opforUnits) == 0) then {
                continue;
            };

            // Build unique groups.
            private _opforGroups = [];
            {
                private _grp = group _x;
                if (!isNull _grp && {count units _grp > 0} && {!(_grp in _opforGroups)}) then {
                    _opforGroups pushBack _grp;
                };
            } forEach _opforUnits;

            {
                private _grp = _x;
                private _ldr = leader _grp;
                if (isNull _ldr || {!alive _ldr}) then {
                    continue;
                };

                // Route each group to its nearest available cargo net, not just the one that discovered it.
                private _grpPos = getPosATL _ldr;
                private _nearestNet = objNull;
                private _bestDist = 1e10;
                {
                    private _d = _grpPos distance2D (getPosATL _x);
                    if (_d < _bestDist) then {
                        _bestDist = _d;
                        _nearestNet = _x;
                    };
                } forEach _cargoNets;

                if (isNull _nearestNet) then {
                    continue;
                };

                private _targetPos = getPosATL _nearestNet;

                // Reset waypoints to enforce a rearm run.
                while {count waypoints _grp > 0} do {
                    deleteWaypoint ((waypoints _grp) select 0);
                };

                private _wp = _grp addWaypoint [_targetPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius 12;
                _wp setWaypointSpeed "FULL";

                // Rearm once nearby.
                [_grp, _nearestNet] spawn {
                    params ["_group", "_net"];
                    private _cargoPos = getPosATL _net;

                    waitUntil {
                        sleep 3;
                        isNull _group ||
                        isNull _net ||
                        !alive (leader _group) ||
                        ((leader _group) distance2D _cargoPos < 25)
                    };

                    if (isNull _group || isNull _net || !alive (leader _group)) exitWith {};

                    {
                        if (alive _x) then {
                            _x action ["Rearm", _net];
                            sleep 0.5;
                        };
                    } forEach units _group;
                };
            } forEach _opforGroups;
        } forEach _cargoNets;

        sleep TWS_AUTO_FOB_RESUPPLY_interval;
    };

    diag_log "[AUTO_FOB_RESUPPLY] Stopped.";
};
