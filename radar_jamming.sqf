params [["_mode", "init"], ["_args", []]];

if (isNil "WAR_RADAR_JAM_DURATION") then {
    WAR_RADAR_JAM_DURATION = 300;
};

if (isNil "WAR_RADAR_JAM_SUCCESS_CHANCE") then {
    WAR_RADAR_JAM_SUCCESS_CHANCE = 0.8;
};

if (isNil "WAR_RADAR_JAM_TIER_CONFIG") then {
    WAR_RADAR_JAM_TIER_CONFIG = createHashMapFromArray [
        [1, [5000, "TIER 1", "ColorRed", 5000]],
        [2, [1000, "TIER 2", "ColorRed", 1000]]
    ];
};

if (isNil "WAR_RADAR_JAM_fnc_getTierConfig") then {
    WAR_RADAR_JAM_fnc_getTierConfig = {
        params ["_tier"];
        WAR_RADAR_JAM_TIER_CONFIG getOrDefault [_tier, []]
    };
};

if (isServer && {isNil "WAR_RADAR_JAM_SERVER_READY"}) then {
    WAR_RADAR_JAM_SERVER_READY = true;

    if (isNil "WAR_RADAR_JAM_ZONES") then {
        WAR_RADAR_JAM_ZONES = [];
    };

    if (isNil "WAR_RADAR_JAM_NEXT_ID") then {
        WAR_RADAR_JAM_NEXT_ID = 1;
    };

    WAR_RADAR_JAM_fnc_isPositionJammed = {
        params ["_position"];

        private _zones = missionNamespace getVariable ["WAR_RADAR_JAM_ZONES", []];
        private _jammed = false;
        private _now = time;

        {
            _x params ["_zoneID", "_centerPos", "_radius", "_expiresAt", "_markerName", "_centerMarkerName", "_tier", "_effective"];

            if (_effective && {_expiresAt > _now} && {_centerPos distance2D _position <= _radius}) exitWith {
                _jammed = true;
            };
        } forEach _zones;

        _jammed
    };

    WAR_RADAR_JAM_fnc_createZone = {
        params ["_centerPos", "_tier", ["_requestedBy", "UNKNOWN"], ["_faction", "BLUFOR"]];

        if (!isServer) exitWith {};

        private _tierConfig = [_tier] call WAR_RADAR_JAM_fnc_getTierConfig;
        if (_tierConfig isEqualTo []) exitWith {};

        _tierConfig params ["_radius", "_tierLabel", "_markerColor", "_electricityCost"];

        private _zoneID = WAR_RADAR_JAM_NEXT_ID;
        WAR_RADAR_JAM_NEXT_ID = WAR_RADAR_JAM_NEXT_ID + 1;

        private _effective = (random 1) < WAR_RADAR_JAM_SUCCESS_CHANCE;

        private _expiresAt = time + WAR_RADAR_JAM_DURATION;
        private _markerName = format ["WAR_RADAR_JAM_%1", _zoneID];
        private _centerMarkerName = format ["WAR_RADAR_JAM_CENTER_%1", _zoneID];

        createMarker [_markerName, _centerPos];
        _markerName setMarkerShape "ELLIPSE";
        _markerName setMarkerBrush "DiagGrid";
        _markerName setMarkerColor _markerColor;
        _markerName setMarkerSize [_radius, _radius];
        _markerName setMarkerAlpha 0.85;
        _markerName setMarkerText format ["RADAR JAM %1", _tierLabel];

        createMarker [_centerMarkerName, _centerPos];
        _centerMarkerName setMarkerShape "ICON";
        _centerMarkerName setMarkerType "mil_warning";
        _centerMarkerName setMarkerColor _markerColor;
        _centerMarkerName setMarkerAlpha 0.9;
        _centerMarkerName setMarkerText format ["RADAR JAM %1", _tierLabel];

        WAR_RADAR_JAM_ZONES pushBack [_zoneID, _centerPos, _radius, _expiresAt, _markerName, _centerMarkerName, _tier, _effective];
        missionNamespace setVariable ["WAR_RADAR_JAM_ZONES", WAR_RADAR_JAM_ZONES, true];

        if (!isNil "RES_fnc_modifyResource") then {
            [_faction, 4, -_electricityCost] call RES_fnc_modifyResource;
        };

        diag_log format [
            "[RADAR_JAM] %1 (%2) placed %3 at %4 radius=%5 cost=%6e effective=%7 expiresAt=%8",
            _requestedBy,
            _faction,
            _tierLabel,
            _centerPos,
            _radius,
            _electricityCost,
            _effective,
            _expiresAt
        ];
    };

    if (isNil "WAR_RADAR_JAM_cleanupLoopStarted") then {
        WAR_RADAR_JAM_cleanupLoopStarted = true;

        [] spawn {
            while {true} do {
                private _now = time;
                private _zones = missionNamespace getVariable ["WAR_RADAR_JAM_ZONES", []];
                private _activeZones = [];

                {
                    _x params ["_zoneID", "_centerPos", "_radius", "_expiresAt", "_markerName", "_centerMarkerName", "_tier", "_effective"];

                    if (_expiresAt <= _now) then {
                        deleteMarker _markerName;
                        deleteMarker _centerMarkerName;
                    } else {
                        _activeZones pushBack _x;
                    };
                } forEach _zones;

                if !(_activeZones isEqualTo _zones) then {
                    WAR_RADAR_JAM_ZONES = _activeZones;
                    missionNamespace setVariable ["WAR_RADAR_JAM_ZONES", WAR_RADAR_JAM_ZONES, true];
                };

                sleep 5;
            };
        };
    };
};

if (hasInterface && {isNil "WAR_RADAR_JAM_CLIENT_READY"}) then {
    WAR_RADAR_JAM_CLIENT_READY = true;

    WAR_RADAR_JAM_fnc_cleanupPlacement = {
        onMapSingleClick "";

        private _display = findDisplay 46;
        private _keyDownEH = missionNamespace getVariable ["WAR_RADAR_JAM_KeyDownEH", -1];
        if (!isNull _display && {_keyDownEH >= 0}) then {
            _display displayRemoveEventHandler ["KeyDown", _keyDownEH];
        };

        missionNamespace setVariable ["WAR_RADAR_JAM_KeyDownEH", -1];
        missionNamespace setVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", false];
        missionNamespace setVariable ["WAR_RADAR_JAM_PENDING_TIER", -1];

        hintSilent "";
        if (visibleMap) then {
            openMap [false, false];
        };
    };

    WAR_RADAR_JAM_fnc_updatePrompt = {
        private _pendingTier = missionNamespace getVariable ["WAR_RADAR_JAM_PENDING_TIER", -1];
        private _tierConfig = [_pendingTier] call WAR_RADAR_JAM_fnc_getTierConfig;

        private _selectionText = "No tier selected";
        if !(_tierConfig isEqualTo []) then {
            _tierConfig params ["_radius", "_tierLabel"];
            _selectionText = format ["Selected: %1 (%2m radius)", _tierLabel, _radius];
        };

        hintSilent format [
            "Radar Jamming\n\nPress 1 for Tier 1 (5000m radius)\nPress 2 for Tier 2 (1000m radius)\n\n%1\n\nLeft click the map to place the jammer.\nPress Esc or close the map to cancel.",
            _selectionText
        ];
    };

    WAR_RADAR_JAM_fnc_promptPlacement = {
        if (missionNamespace getVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", false]) exitWith {};

        missionNamespace setVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", true];
        missionNamespace setVariable ["WAR_RADAR_JAM_PENDING_TIER", -1];

        [] call WAR_RADAR_JAM_fnc_updatePrompt;
        openMap [true, false];

        private _display = findDisplay 46;
        if (!isNull _display) then {
            private _keyDownEH = _display displayAddEventHandler ["KeyDown", {
                params ["_displayCtrl", "_keyCode"];

                if !(missionNamespace getVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", false]) exitWith {false};

                switch (_keyCode) do {
                    case 1: {
                        [] call WAR_RADAR_JAM_fnc_cleanupPlacement;
                        true
                    };
                    case 2: {
                        missionNamespace setVariable ["WAR_RADAR_JAM_PENDING_TIER", 1];
                        [] call WAR_RADAR_JAM_fnc_updatePrompt;
                        true
                    };
                    case 3: {
                        missionNamespace setVariable ["WAR_RADAR_JAM_PENDING_TIER", 2];
                        [] call WAR_RADAR_JAM_fnc_updatePrompt;
                        true
                    };
                    default {false};
                };
            }];

            missionNamespace setVariable ["WAR_RADAR_JAM_KeyDownEH", _keyDownEH];
        };

        onMapSingleClick {
            if !(missionNamespace getVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", false]) exitWith {false};

            private _selectedTier = missionNamespace getVariable ["WAR_RADAR_JAM_PENDING_TIER", -1];
            if (_selectedTier < 0) exitWith {
                [] call WAR_RADAR_JAM_fnc_updatePrompt;
                false
            };

            private _playerFaction = switch (true) do {
                case (side group player == west):       {"BLUFOR"};
                case (side group player == east):       {"OPFOR"};
                case (side group player == resistance): {"INDEP"};
                default {"BLUFOR"};
            };

            [_pos, _selectedTier, name player, _playerFaction] remoteExecCall ["WAR_RADAR_JAM_fnc_createZone", 2];
            systemChat format ["Radar jam queued at %1.", mapGridPosition _pos];
            [] call WAR_RADAR_JAM_fnc_cleanupPlacement;
            true
        };

        [] spawn {
            while {missionNamespace getVariable ["WAR_RADAR_JAM_PLACEMENT_ACTIVE", false]} do {
                if (!visibleMap) exitWith {
                    [] call WAR_RADAR_JAM_fnc_cleanupPlacement;
                };

                sleep 0.25;
            };
        };
    };

    WAR_RADAR_JAM_fnc_promptPlacementTier = {
        params ["_tier"];

        [] call WAR_RADAR_JAM_fnc_promptPlacement;
        missionNamespace setVariable ["WAR_RADAR_JAM_PENDING_TIER", _tier];
        [] call WAR_RADAR_JAM_fnc_updatePrompt;
    };
};

switch (toLower _mode) do {
    case "prompt": {
        if (hasInterface) then {
            [] call WAR_RADAR_JAM_fnc_promptPlacement;
        };
    };
    case "tier1": {
        if (hasInterface) then {
            [1] call WAR_RADAR_JAM_fnc_promptPlacementTier;
        };
    };
    case "tier2": {
        if (hasInterface) then {
            [2] call WAR_RADAR_JAM_fnc_promptPlacementTier;
        };
    };
    case "cancel": {
        if (hasInterface && {!isNil "WAR_RADAR_JAM_fnc_cleanupPlacement"}) then {
            [] call WAR_RADAR_JAM_fnc_cleanupPlacement;
        };
    };
};