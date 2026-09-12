if (!isServer) exitWith {};

private _commTowerSmallType = "Land_Communication_F";
private _commTowerSmallRadius = 5000;
private _commTowerLargeType = "Land_TTowerBig_2_F";
private _commTowerLargeRadius = 10000;
private _commTowerRefreshInterval = 60;

private _commTowerEntries = [];
private _commTowerMarkerMap = createHashMap;

private _fnc_safeMarkerToken = {
    params ["_text"];

    private _out = [];
    {
        if (
            (_x >= 48 && _x <= 57) ||
            (_x >= 65 && _x <= 90) ||
            (_x >= 97 && _x <= 122)
        ) then {
            _out pushBack _x;
        } else {
            _out pushBack 95;
        };
    } forEach (toArray _text);

    toString _out
};

private _fnc_getSectorControlAt = {
    params ["_position"];

    if (!isNil "RES_fnc_getSectorControl") exitWith {
        [_position] call RES_fnc_getSectorControl
    };

    if (isNil "ALiVE_sectorGrid") exitWith {"NONE"};

    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {"NONE"};

    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (isNil "_sectorData" || count _sectorData == 0) exitWith {"NONE"};

    private _dominatingSide = "NONE";
    private _maxCount = 0;
    private _sides = ["EAST", "WEST", "GUER", "CIV"];

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
        } forEach _sides;
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
        } forEach _sides;
    };

    switch (_dominatingSide) do {
        case "WEST": {"BLUFOR"};
        case "EAST": {"OPFOR"};
        case "GUER": {"INDEP"};
        default {"NONE"};
    }
};

private _fnc_factionToSide = {
    params ["_faction"];

    switch (toUpper _faction) do {
        case "BLUFOR";
        case "WEST": {west};
        case "OPFOR";
        case "EAST": {east};
        case "INDEP";
        case "GUER": {resistance};
        default {sideUnknown};
    }
};

private _fnc_factionToMarkerColor = {
    params ["_faction"];

    switch (toUpper _faction) do {
        case "BLUFOR";
        case "WEST": {"ColorBLUFOR"};
        case "OPFOR";
        case "EAST": {"ColorOPFOR"};
        case "INDEP";
        case "GUER": {"ColorIndependent"};
        default {"ColorWhite"};
    }
};

private _fnc_refreshCommTowers = {
    private _entries = [];
    private _activeTowerKeys = [];
    private _smallTowers = allMissionObjects _commTowerSmallType;
    private _largeTowers = allMissionObjects _commTowerLargeType;

    {
        private _tower = _x;
        if (isNull _tower) then { continue };

        private _isOperational = (damage _tower) < 0.9;
        if (!_isOperational) then { continue };

        private _radius = _commTowerSmallRadius;
        if ((typeOf _tower) == _commTowerLargeType) then {
            _radius = _commTowerLargeRadius;
        };

        private _towerId = netId _tower;
        if (_towerId isEqualTo "") then {
            _towerId = str _tower;
        };

        private _towerKey = [_towerId] call _fnc_safeMarkerToken;
        _activeTowerKeys pushBack _towerKey;

        private _ownerFaction = [getPosATL _tower] call _fnc_getSectorControlAt;
        private _ownerSide = [_ownerFaction] call _fnc_factionToSide;
        private _ownerColor = [_ownerFaction] call _fnc_factionToMarkerColor;

        private _towerTypeLabel = "STD";
        if ((typeOf _tower) == _commTowerLargeType) then {
            _towerTypeLabel = "INDUSTRIAL";
        };

        private _objMarkerName = format ["WAR_COMM_OBJ_%1", _towerKey];
        private _radiusMarkerName = format ["WAR_COMM_RAD_%1", _towerKey];

        private _existingMarkerData = _commTowerMarkerMap getOrDefault [_towerKey, []];
        if (_existingMarkerData isEqualTo []) then {
            createMarker [_objMarkerName, getPosATL _tower];
            createMarker [_radiusMarkerName, getPosATL _tower];
        };

        _objMarkerName setMarkerShape "ICON";
        _objMarkerName setMarkerType "mil_dot";
        _objMarkerName setMarkerColor _ownerColor;
        _objMarkerName setMarkerSize [0.75, 0.75];
        _objMarkerName setMarkerPos (getPosATL _tower);
        _objMarkerName setMarkerAlpha 0.9;
        _objMarkerName setMarkerText format ["COMM %1 (%2)", _towerTypeLabel, _ownerFaction];

        _radiusMarkerName setMarkerShape "ELLIPSE";
        _radiusMarkerName setMarkerBrush "Border";
        _radiusMarkerName setMarkerColor _ownerColor;
        _radiusMarkerName setMarkerSize [_radius, _radius];
        _radiusMarkerName setMarkerPos (getPosATL _tower);
        _radiusMarkerName setMarkerAlpha 0.4;

        _commTowerMarkerMap set [_towerKey, [_objMarkerName, _radiusMarkerName]];

        if (_ownerSide isEqualTo sideUnknown) then { continue };

        _entries pushBack [_tower, _radius, _ownerSide, _ownerFaction];
    } forEach (_smallTowers + _largeTowers);

    {
        private _towerKey = _x;
        if (_towerKey in _activeTowerKeys) then { continue };

        private _markerData = _commTowerMarkerMap getOrDefault [_towerKey, []];
        if !(_markerData isEqualTo []) then {
            _markerData params ["_objMarkerName", "_radiusMarkerName"];
            deleteMarker _objMarkerName;
            deleteMarker _radiusMarkerName;
        };

        _commTowerMarkerMap deleteAt _towerKey;
    } forEach (keys _commTowerMarkerMap);

    _commTowerEntries = _entries;
    missionNamespace setVariable ["WAR_COMM_ENTRIES", _commTowerEntries];
};

private _fnc_hasFriendlyCoverage = {
    params ["_reporter"];

    if (isNull _reporter || {!alive _reporter}) exitWith {false};
    private _entries = missionNamespace getVariable ["WAR_COMM_ENTRIES", []];
    if (_entries isEqualTo []) exitWith {false};

    private _reporterSide = side (group _reporter);
    private _reporterPos = getPosATL _reporter;
    private _hasFriendlyCoverage = false;

    {
        _x params ["_tower", "_radius", "_ownerSide", "_ownerFaction"];

        if (isNull _tower) then { continue };
        if ((damage _tower) >= 0.9) then { continue };
        if (!(_ownerSide isEqualTo _reporterSide)) then { continue };

        if ((_tower distance2D _reporterPos) <= _radius) exitWith {
            _hasFriendlyCoverage = true;
        };
    } forEach _entries;

    _hasFriendlyCoverage
};

missionNamespace setVariable ["WAR_COMM_fnc_refreshTowers", _fnc_refreshCommTowers];
missionNamespace setVariable ["WAR_RECON_fnc_refreshCommTowers", _fnc_refreshCommTowers];
missionNamespace setVariable ["WAR_COMM_fnc_hasFriendlyCoverage", _fnc_hasFriendlyCoverage];

diag_log "[WAR_COMM] Communication network monitor initialized";

[] call _fnc_refreshCommTowers;

while {true} do {
    private _forceCommRefresh =
        missionNamespace getVariable ["WAR_COMM_FORCE_REFRESH", false] ||
        missionNamespace getVariable ["WAR_RECON_FORCE_COMM_REFRESH", false];

    if (_forceCommRefresh) then {
        missionNamespace setVariable ["WAR_COMM_FORCE_REFRESH", false];
        missionNamespace setVariable ["WAR_RECON_FORCE_COMM_REFRESH", false];
    };

    if (_forceCommRefresh) then {
        [] call _fnc_refreshCommTowers;
    } else {
        sleep _commTowerRefreshInterval;
        [] call _fnc_refreshCommTowers;
    };
};
