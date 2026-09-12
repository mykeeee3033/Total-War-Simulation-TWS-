params [['_mode', 'init'], ['_args', []]];

if (isNil "WAR_EMP_DURATION") then { WAR_EMP_DURATION = 300; };
if (isNil "WAR_EMP_RADIUS") then { WAR_EMP_RADIUS = 2000; };
if (isNil "WAR_EMP_ELECTRICITY_COST") then { WAR_EMP_ELECTRICITY_COST = 10000; };

if (isNil "WAR_EMP_fnc_isInEMP") then {
    WAR_EMP_fnc_isInEMP = {
        params [['_position', [0, 0, 0]]];

        private _zones = missionNamespace getVariable ["WAR_EMP_ZONES", []];
        private _now = time;
        private _inZone = false;

        {
            _x params ["_zoneID", "_centerPos", "_radius", "_expiresAt"];
            if (_expiresAt > _now && {_centerPos distance2D _position <= _radius}) exitWith {
                _inZone = true;
            };
        } forEach _zones;

        _inZone
    };
};

if (hasInterface && {isNil "WAR_EMP_CLIENT_READY"}) then {
    WAR_EMP_CLIENT_READY = true;

    WAR_EMP_fnc_cleanupPlacement = {
        onMapSingleClick "";

        private _display = findDisplay 46;
        private _keyDownEH = missionNamespace getVariable ["WAR_EMP_KeyDownEH", -1];
        if (!isNull _display && {_keyDownEH >= 0}) then {
            _display displayRemoveEventHandler ["KeyDown", _keyDownEH];
        };

        missionNamespace setVariable ["WAR_EMP_KeyDownEH", -1];
        missionNamespace setVariable ["WAR_EMP_PLACEMENT_ACTIVE", false];

        hintSilent "";
        if (visibleMap) then {
            openMap [false, false];
        };
    };

    WAR_EMP_fnc_applyNVGLocal = {
        params ["_unit", "_enable"];
        if (isNull _unit) exitWith {};
        if (!local _unit) exitWith {};

        if (_enable) then {
            private _stored = _unit getVariable ["WAR_EMP_STORED_HMD", ""];
            if (_stored != "") then {
                _unit linkItem _stored;
                _unit setVariable ["WAR_EMP_STORED_HMD", "", false];
            };
        } else {
            private _hmd = hmd _unit;
            if (_hmd != "") then {
                _unit setVariable ["WAR_EMP_STORED_HMD", _hmd, false];
                _unit unlinkItem _hmd;
            };
        };
    };

    WAR_EMP_fnc_disconnectUAVLocal = {
        params ["_uav"];
        if (isNull _uav) exitWith {};
        if (isNull player) exitWith {};

        private _connected = getConnectedUAV player;
        if (_connected isEqualTo _uav) then {
            player connectTerminalToUAV objNull;
            hint "EMP interference: UAV signal lost";
        };
    };

    WAR_EMP_fnc_setLocalEffectsState = {
        params ["_enabled"];
        missionNamespace setVariable ["WAR_EMP_LOCAL_EFFECTS_ACTIVE", _enabled];

        if (!_enabled) then {
            [player, true] call WAR_EMP_fnc_applyNVGLocal;
            hintSilent "";
            missionNamespace setVariable ["WAR_EMP_localInZone", false];
            missionNamespace setVariable ["WAR_EMP_localLastUAVHintAt", -9999];
            missionNamespace setVariable ["WAR_EMP_localLastVehicleHintAt", -9999];
            if (!isNil "WAR_EMP_localLoop") then {
                terminate WAR_EMP_localLoop;
                WAR_EMP_localLoop = scriptNull;
            };
            true
        } else {
            if (!isNil "WAR_EMP_localLoop" && {!scriptDone WAR_EMP_localLoop}) exitWith {true};

            WAR_EMP_localLoop = [] spawn {
                while {missionNamespace getVariable ["WAR_EMP_LOCAL_EFFECTS_ACTIVE", false]} do {
                    if (isNull player) then {
                        sleep 0.5;
                        continue;
                    };

                    private _isInZone = [getPosATL player] call WAR_EMP_fnc_isInEMP;
                    private _wasInZone = missionNamespace getVariable ["WAR_EMP_localInZone", false];

                    if (_isInZone && !_wasInZone) then {
                        [player, false] call WAR_EMP_fnc_applyNVGLocal;
                    };

                    if (!_isInZone && _wasInZone) then {
                        [player, true] call WAR_EMP_fnc_applyNVGLocal;
                    };

                    missionNamespace setVariable ["WAR_EMP_localInZone", _isInZone];

                    private _uav = getConnectedUAV player;
                    if (!isNull _uav) then {
                        private _uavBlocked = [getPosATL _uav] call WAR_EMP_fnc_isInEMP;
                        if (_uavBlocked || _isInZone) then {
                            player connectTerminalToUAV objNull;
                            private _lastHintAt = missionNamespace getVariable ["WAR_EMP_localLastUAVHintAt", -9999];
                            if ((time - _lastHintAt) > 5) then {
                                hint "EMP interference: UAV signal lost";
                                missionNamespace setVariable ["WAR_EMP_localLastUAVHintAt", time];
                            };
                        };
                    };

                    sleep 0.5;
                };
            };

            true
        };
    };

    if (isNil "WAR_EMP_GetInEH") then {
        WAR_EMP_GetInEH = player addEventHandler ["GetInMan", {
            params ["_unit", "_role", "_vehicle"];

            if (isNull _vehicle) exitWith {};
            if !([getPosATL _vehicle] call WAR_EMP_fnc_isInEMP) exitWith {};

            _unit action ["GetOut", _vehicle];

            private _lastHintAt = missionNamespace getVariable ["WAR_EMP_localLastVehicleHintAt", -9999];
            if ((time - _lastHintAt) > 3) then {
                hint "EMP blackout: vehicle electronics offline in this area";
                missionNamespace setVariable ["WAR_EMP_localLastVehicleHintAt", time];
            };
        }];
    };

    WAR_EMP_fnc_promptPlacement = {
        if (missionNamespace getVariable ["WAR_EMP_PLACEMENT_ACTIVE", false]) exitWith {};

        private _faction = switch (true) do {
            case (side group player == west):       {"BLUFOR"};
            case (side group player == east):       {"OPFOR"};
            case (side group player == resistance): {"INDEP"};
            default {"BLUFOR"};
        };

        if (!isNil "RES_fnc_getResources") then {
            private _resources = [_faction] call RES_fnc_getResources;
            private _electricity = _resources select 4;
            if (_electricity < WAR_EMP_ELECTRICITY_COST) exitWith {
                hint format ["Insufficient electricity!\nNeed: %1\nAvailable: %2", WAR_EMP_ELECTRICITY_COST, _electricity];
            };
        };

        missionNamespace setVariable ["WAR_EMP_PLACEMENT_ACTIVE", true];

        hintSilent format [
            "EMP BLACKOUT\n\nRadius: %1m\nDuration: %2s\nCost: %3 Electricity\n\nLeft click the map to deploy EMP.\nPress Esc or close map to cancel.",
            WAR_EMP_RADIUS,
            WAR_EMP_DURATION,
            WAR_EMP_ELECTRICITY_COST
        ];

        openMap [true, false];

        private _display = findDisplay 46;
        if (!isNull _display) then {
            private _keyDownEH = _display displayAddEventHandler ["KeyDown", {
                params ["_displayCtrl", "_keyCode"];

                if !(missionNamespace getVariable ["WAR_EMP_PLACEMENT_ACTIVE", false]) exitWith {false};

                if (_keyCode == 1) then {
                    [] call WAR_EMP_fnc_cleanupPlacement;
                    true
                } else {
                    false
                };
            }];

            missionNamespace setVariable ["WAR_EMP_KeyDownEH", _keyDownEH];
        };

        onMapSingleClick {
            if !(missionNamespace getVariable ["WAR_EMP_PLACEMENT_ACTIVE", false]) exitWith {false};

            private _playerFaction = switch (true) do {
                case (side group player == west):       {"BLUFOR"};
                case (side group player == east):       {"OPFOR"};
                case (side group player == resistance): {"INDEP"};
                default {"BLUFOR"};
            };

            [_pos, name player, _playerFaction] remoteExecCall ["WAR_EMP_fnc_createZone", 2];
            systemChat format ["EMP deployment requested at %1", mapGridPosition _pos];
            [] call WAR_EMP_fnc_cleanupPlacement;
            true
        };

        [] spawn {
            while {missionNamespace getVariable ["WAR_EMP_PLACEMENT_ACTIVE", false]} do {
                if (!visibleMap) exitWith {
                    [] call WAR_EMP_fnc_cleanupPlacement;
                };
                sleep 0.25;
            };
        };
    };
};

if (isServer && {isNil "WAR_EMP_SERVER_READY"}) then {
    WAR_EMP_SERVER_READY = true;

    if (isNil "WAR_EMP_ZONES") then {
        WAR_EMP_ZONES = [];
        missionNamespace setVariable ["WAR_EMP_ZONES", WAR_EMP_ZONES, true];
    };

    if (isNil "WAR_EMP_NEXT_ID") then {
        WAR_EMP_NEXT_ID = 1;
    };

    WAR_EMP_fnc_setDroneDenied = {
        params ["_uav", "_state"];
        if (isNull _uav) exitWith {};

        _uav setVehicleReportRemoteTargets (!_state);
        _uav setVehicleReceiveRemoteTargets (!_state);

        if (_state && {isUavConnected _uav}) then {
            [_uav] remoteExecCall ["WAR_EMP_fnc_disconnectUAVLocal", 0];
        };
    };

    WAR_EMP_fnc_updateUnitNVG = {
        params ["_unit", "_state"];
        if (isNull _unit || {!alive _unit}) exitWith {};

        if (_state) then {
            private _stored = _unit getVariable ["WAR_EMP_STORED_HMD", ""];
            if (_stored != "") then {
                if (isPlayer _unit) then {
                    [_unit, true] remoteExecCall ["WAR_EMP_fnc_applyNVGLocal", owner _unit];
                } else {
                    _unit linkItem _stored;
                    _unit setVariable ["WAR_EMP_STORED_HMD", "", false];
                };
            };
        } else {
            private _current = hmd _unit;
            if (_current != "") then {
                if (isPlayer _unit) then {
                    [_unit, false] remoteExecCall ["WAR_EMP_fnc_applyNVGLocal", owner _unit];
                } else {
                    _unit setVariable ["WAR_EMP_STORED_HMD", _current, false];
                    _unit unlinkItem _current;
                };
            };
        };
    };

    WAR_EMP_fnc_updateVehicleState = {
        params ["_veh", "_disabled"];
        if (isNull _veh || {!alive _veh}) exitWith {};

        if (_disabled) then {
            if !(_veh getVariable ["WAR_EMP_DISABLED", false]) then {
                _veh setVariable ["WAR_EMP_DISABLED", true, true];
                _veh setVariable ["WAR_EMP_PRE_FUEL", fuel _veh, false];
                _veh setVariable ["WAR_EMP_PRE_LOCK", locked _veh, false];
            };

            _veh engineOn false;
            _veh setFuel 0;
            _veh lock 2;

            {
                if (!isPlayer _x) then {
                    unassignVehicle _x;
                    moveOut _x;
                };
            } forEach crew _veh;

            if (unitIsUAV _veh) then {
                [_veh, true] call WAR_EMP_fnc_setDroneDenied;
            };
        } else {
            if (_veh getVariable ["WAR_EMP_DISABLED", false]) then {
                _veh setVariable ["WAR_EMP_DISABLED", false, true];
                private _fuelBefore = _veh getVariable ["WAR_EMP_PRE_FUEL", 0.3];
                private _lockBefore = _veh getVariable ["WAR_EMP_PRE_LOCK", 0];
                _veh setFuel _fuelBefore;
                _veh lock _lockBefore;
                _veh setVariable ["WAR_EMP_PRE_FUEL", nil, false];
                _veh setVariable ["WAR_EMP_PRE_LOCK", nil, false];
            };

            if (unitIsUAV _veh) then {
                [_veh, false] call WAR_EMP_fnc_setDroneDenied;
            };
        };
    };

    WAR_EMP_fnc_cleanupExpiredZones = {
        private _now = time;
        private _zones = missionNamespace getVariable ["WAR_EMP_ZONES", []];
        private _active = [];

        {
            _x params ["_zoneID", "_centerPos", "_radius", "_expiresAt", "_areaMarker", "_centerMarker"];
            if (_expiresAt <= _now) then {
                deleteMarker _areaMarker;
                deleteMarker _centerMarker;
            } else {
                _active pushBack _x;
            };
        } forEach _zones;

        if !(_active isEqualTo _zones) then {
            WAR_EMP_ZONES = _active;
            missionNamespace setVariable ["WAR_EMP_ZONES", WAR_EMP_ZONES, true];
        };

        _active
    };

    WAR_EMP_fnc_startEffectLoop = {
        if (missionNamespace getVariable ["WAR_EMP_EFFECT_LOOP_RUNNING", false]) exitWith {};

        missionNamespace setVariable ["WAR_EMP_EFFECT_LOOP_RUNNING", true, true];
        [true] remoteExecCall ["WAR_EMP_fnc_setLocalEffectsState", -2];

        [] spawn {
            while {missionNamespace getVariable ["WAR_EMP_EFFECT_LOOP_RUNNING", false]} do {
                private _activeZones = [] call WAR_EMP_fnc_cleanupExpiredZones;

                if ((count _activeZones) <= 0) exitWith {
                    missionNamespace setVariable ["WAR_EMP_EFFECT_LOOP_RUNNING", false, true];
                    [false] remoteExecCall ["WAR_EMP_fnc_setLocalEffectsState", -2];
                };

                {
                    private _veh = _x;
                    if (isNull _veh || {!alive _veh}) then { continue };
                    private _isInZone = [getPosATL _veh] call WAR_EMP_fnc_isInEMP;
                    [_veh, _isInZone] call WAR_EMP_fnc_updateVehicleState;
                } forEach vehicles;

                {
                    private _unit = _x;
                    if (isNull _unit || {!alive _unit}) then { continue };
                    private _isInZone = [getPosATL _unit] call WAR_EMP_fnc_isInEMP;
                    [_unit, !_isInZone] call WAR_EMP_fnc_updateUnitNVG;
                } forEach allUnits;

                sleep 1;
            };

            {
                [_x, false] call WAR_EMP_fnc_updateVehicleState;
            } forEach vehicles;

            {
                [_x, true] call WAR_EMP_fnc_updateUnitNVG;
            } forEach allUnits;
        };
    };

    WAR_EMP_fnc_createZone = {
        params ["_centerPos", ["_requestedBy", "UNKNOWN"], ["_faction", "BLUFOR"]];
        if (!isServer) exitWith {};

        private _ownerID = if (isNil "remoteExecutedOwner") then {-1} else {remoteExecutedOwner};

        if (!isNil "RES_fnc_getResources") then {
            private _resources = [_faction] call RES_fnc_getResources;
            private _electricity = _resources select 4;
            if (_electricity < WAR_EMP_ELECTRICITY_COST) exitWith {
                if (_ownerID > 0) then {
                    [format ["EMP denied: insufficient electricity (%1/%2)", _electricity, WAR_EMP_ELECTRICITY_COST]] remoteExecCall ["systemChat", _ownerID];
                };
            };
        };

        private _zoneID = WAR_EMP_NEXT_ID;
        WAR_EMP_NEXT_ID = WAR_EMP_NEXT_ID + 1;

        private _expiresAt = time + WAR_EMP_DURATION;
        private _areaMarker = format ["WAR_EMP_ZONE_%1", _zoneID];
        private _centerMarker = format ["WAR_EMP_CENTER_%1", _zoneID];

        createMarker [_areaMarker, _centerPos];
        _areaMarker setMarkerShape "ELLIPSE";
        _areaMarker setMarkerBrush "DiagGrid";
        _areaMarker setMarkerColor "ColorOrange";
        _areaMarker setMarkerSize [WAR_EMP_RADIUS, WAR_EMP_RADIUS];
        _areaMarker setMarkerAlpha 0.75;
        _areaMarker setMarkerText "EMP BLACKOUT";

        createMarker [_centerMarker, _centerPos];
        _centerMarker setMarkerShape "ICON";
        _centerMarker setMarkerType "mil_warning";
        _centerMarker setMarkerColor "ColorOrange";
        _centerMarker setMarkerAlpha 0.95;
        _centerMarker setMarkerText "EMP";

        WAR_EMP_ZONES pushBack [_zoneID, _centerPos, WAR_EMP_RADIUS, _expiresAt, _areaMarker, _centerMarker];
        missionNamespace setVariable ["WAR_EMP_ZONES", WAR_EMP_ZONES, true];

        if (!isNil "RES_fnc_modifyResource") then {
            [_faction, 4, -WAR_EMP_ELECTRICITY_COST] call RES_fnc_modifyResource;
        };

        [] call WAR_EMP_fnc_startEffectLoop;

        diag_log format [
            "[EMP] %1 (%2) placed EMP at %3 radius=%4 duration=%5 cost=%6 expiresAt=%7",
            _requestedBy,
            _faction,
            _centerPos,
            WAR_EMP_RADIUS,
            WAR_EMP_DURATION,
            WAR_EMP_ELECTRICITY_COST,
            _expiresAt
        ];

        if (_ownerID > 0) then {
            [format ["EMP deployed at %1", mapGridPosition _centerPos]] remoteExecCall ["systemChat", _ownerID];
        };
    };
};

switch (toLower _mode) do {
    case "prompt": {
        if (hasInterface) then {
            [] call WAR_EMP_fnc_promptPlacement;
        };
    };
    case "cancel": {
        if (hasInterface && {!isNil "WAR_EMP_fnc_cleanupPlacement"}) then {
            [] call WAR_EMP_fnc_cleanupPlacement;
        };
    };
    case "status": {
        private _zones = missionNamespace getVariable ["WAR_EMP_ZONES", []];
        systemChat format ["EMP status: activeZones=%1, duration=%2, radius=%3", count _zones, WAR_EMP_DURATION, WAR_EMP_RADIUS];
    };
    default {};
};
