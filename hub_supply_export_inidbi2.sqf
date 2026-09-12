/*
 * hub_supply_export_inidbi2.sqf
 *
 * Periodically scans communication hubs and exports cargo-net supply status
 * to TWS_ReconIntel INIDBI2 data for external viewers.
 */

if (!isServer) exitWith {};

if (isNil "TWS_HUBSUP_export_dbName") then { TWS_HUBSUP_export_dbName = "TWS_LogisticsIntel"; };
if (isNil "TWS_HUBSUP_export_sectionMeta") then { TWS_HUBSUP_export_sectionMeta = "HubSupplyMeta"; };
if (isNil "TWS_HUBSUP_export_sectionHubs") then { TWS_HUBSUP_export_sectionHubs = "HubSupplies"; };
if (isNil "TWS_HUBSUP_export_interval") then { TWS_HUBSUP_export_interval = 180; };
if (isNil "TWS_HUBSUP_export_running") then { TWS_HUBSUP_export_running = false; };
if (isNil "TWS_HUBSUP_debug") then { TWS_HUBSUP_debug = false; };
if (isNil "TWS_HUBSUP_cargoNetClass") then { TWS_HUBSUP_cargoNetClass = "O_CargoNet_01_ammo_F"; };
if (isNil "TWS_HUBSUP_cargoNetClassList") then {
    TWS_HUBSUP_cargoNetClassList = [
        "O_CargoNet_01_ammo_F",
        "CargoNet_01_box_F",
        "Box_East_Ammo_F",
        "Box_East_Wps_F",
        "ReammoBox_F",
        "O_supplyCrate_F"
    ];
};
if (isNil "TWS_HUBSUP_hubClass") then { TWS_HUBSUP_hubClass = "RuggedTerminal_01_communications_hub_F"; };
if (isNil "TWS_HUBSUP_hubClassList") then {
    TWS_HUBSUP_hubClassList = [
        TWS_HUBSUP_hubClass,
        "Land_DataTerminal_01_F",
        "Land_DataTerminal_01_sand_F",
        "Land_DataTerminal_01_olive_F"
    ];
};
if (isNil "TWS_HUBSUP_capacity") then { TWS_HUBSUP_capacity = 500; };
if (isNil "TWS_HUBSUP_thresholdPct") then { TWS_HUBSUP_thresholdPct = 0.5; };

TWS_HUBSUP_fnc_log = {
    params ["_msg"];
    if (TWS_HUBSUP_debug) then {
        diag_log _msg;
    };
};

TWS_HUBSUP_fnc_initIniDB = {
    if (!isNil "TWS_HUBSUP_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        ["[TWS_HUBSUP] OO_INIDBI not found. Hub supply export disabled."] call TWS_HUBSUP_fnc_log;
        false
    };

    TWS_HUBSUP_iniDB = ["new", TWS_HUBSUP_export_dbName] call OO_INIDBI;
    if (isNil "TWS_HUBSUP_iniDB") exitWith {
        [format ["[TWS_HUBSUP] Failed to open INIDBI2 DB: %1", TWS_HUBSUP_export_dbName]] call TWS_HUBSUP_fnc_log;
        false
    };

    true
};

TWS_HUBSUP_fnc_write = {
    params ["_section", "_key", "_value"];
    if (isNil "TWS_HUBSUP_iniDB") exitWith {false};
    ["write", [_section, _key, _value]] call TWS_HUBSUP_iniDB;
    true
};

TWS_HUBSUP_fnc_getSectorControlAtPos = {
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

    switch (_dominatingSide) do {
        case "EAST": {"OPFOR"};
        case "WEST": {"BLUFOR"};
        case "GUER": {"INDEP"};
        default {"NONE"};
    }
};

TWS_HUBSUP_fnc_getBoxSupplies = {
    params ["_supplyBox"];

    private _magCargo = getMagazineCargo _supplyBox;
    private _wpnCargo = getWeaponCargo _supplyBox;
    private _itemCargo = getItemCargo _supplyBox;

    private _magCounts = _magCargo select 1;
    private _wpnCounts = _wpnCargo select 1;
    private _itemTypes = _itemCargo select 0;
    private _itemCounts = _itemCargo select 1;

    private _filteredItemCounts = [];
    {
        private _itemType = _itemTypes select _forEachIndex;
        private _itemCount = _itemCounts select _forEachIndex;
        if (
            (_itemType find "FirstAid" >= 0) || (_itemType find "Medikit" >= 0) ||
            (_itemType find "Explosive" >= 0) || (_itemType find "Mine" >= 0) ||
            (_itemType find "Grenade" >= 0) || (_itemType find "SmokeShell" >= 0)
        ) then {
            _filteredItemCounts pushBack _itemCount;
        };
    } forEach _itemTypes;

    private _totalMags = 0;
    { _totalMags = _totalMags + _x; } forEach _magCounts;
    private _totalWpns = 0;
    { _totalWpns = _totalWpns + _x; } forEach _wpnCounts;
    private _totalItems = 0;
    { _totalItems = _totalItems + _x; } forEach _filteredItemCounts;

    _totalMags + _totalWpns + _totalItems
};

TWS_HUBSUP_fnc_getBoxSupplyMetrics = {
    params ["_supplyBox"];

    private _fallbackTotal = [_supplyBox] call TWS_HUBSUP_fnc_getBoxSupplies;
    private _cap = maxLoad _supplyBox;
    private _currentLoad = loadAbs _supplyBox;

    if (_cap <= 0) then {
        _cap = (TWS_HUBSUP_capacity max 1);
        _currentLoad = _fallbackTotal;
    };

    private _rawPct = (_currentLoad / (_cap max 1)) min 1;
    [_currentLoad, _cap, _rawPct, _fallbackTotal]
};

TWS_HUBSUP_fnc_getLowestCargoNet = {
    params ["_hubPos", ["_radius", 220]];

    private _nets = [];
    {
        _nets append (_hubPos nearObjects [_x, _radius]);
    } forEach TWS_HUBSUP_cargoNetClassList;
    _nets = _nets arrayIntersect _nets;
    _nets = _nets select {alive _x};
    if ((count _nets) == 0) exitWith {objNull};

    private _lowest = objNull;
    private _lowestRaw = 1e10;
    private _nearest = objNull;
    private _bestDist = 1e10;
    {
        private _d = _hubPos distance2D (getPosATL _x);
        if (_d < _bestDist) then {
            _bestDist = _d;
            _nearest = _x;
        };

        private _m = [_x] call TWS_HUBSUP_fnc_getBoxSupplyMetrics;
        _m params ["_curLoad", "_cap", "_raw", "_fallbackTotal"];
        if (_raw < _lowestRaw) then {
            _lowestRaw = _raw;
            _lowest = _x;
        };
    } forEach _nets;

    if (isNull _lowest) then {_nearest} else {_lowest}
};

TWS_HUBSUP_fnc_collectHubCandidates = {
    private _candidates = [];

    {
        private _hubs = allMissionObjects _x;
        {
            _candidates pushBack [
                _x,
                getPosATL _x,
                format ["COMM_HUB_%1", mapGridPosition _x],
                true
            ];
        } forEach _hubs;
    } forEach TWS_HUBSUP_hubClassList;

    if ((count _candidates) == 0) then {
        private _nets = [];
        {
            _nets append (allMissionObjects _x);
        } forEach TWS_HUBSUP_cargoNetClassList;
        _nets = _nets arrayIntersect _nets;
        {
            private _grid = mapGridPosition _x;
            _candidates pushBack [
                objNull,
                getPosATL _x,
                format ["COMM_HUB_NET_%1_%2", _grid, _forEachIndex],
                false
            ];
        } forEach _nets;
    };

    _candidates
};

if (TWS_HUBSUP_export_running) exitWith {
    ["[TWS_HUBSUP] Hub supply exporter already running"] call TWS_HUBSUP_fnc_log;
};

TWS_HUBSUP_export_running = true;
publicVariable "TWS_HUBSUP_export_running";

[] spawn {
    ["[TWS_HUBSUP] Hub supply exporter started"] call TWS_HUBSUP_fnc_log;

    while {TWS_HUBSUP_export_running} do {
        private _ready = [] call TWS_HUBSUP_fnc_initIniDB;
        if (_ready) then {
            private _hubCandidates = [] call TWS_HUBSUP_fnc_collectHubCandidates;
            private _activeKeys = [];

            {
                _x params ["_hub", "_hubPos", "_hubId", "_isRealHub"];
                private _grid = mapGridPosition _hubPos;
                private _control = [_hubPos] call TWS_HUBSUP_fnc_getSectorControlAtPos;
                private _net = [_hubPos, 220] call TWS_HUBSUP_fnc_getLowestCargoNet;

                private _total = 0;
                private _rawPct = 0;
                private _normPct = 0;
                private _hasNet = false;
                private _itemTotal = 0;

                if (!isNull _net) then {
                    _hasNet = true;
                    private _metrics = [_net] call TWS_HUBSUP_fnc_getBoxSupplyMetrics;
                    _metrics params ["_curLoad", "_maxLoad", "_raw", "_fallbackTotal"];
                    _total = round _curLoad;
                    _itemTotal = _fallbackTotal;
                    _rawPct = _raw;
                    _normPct = if (_rawPct >= TWS_HUBSUP_thresholdPct) then {1} else {(_rawPct / (TWS_HUBSUP_thresholdPct max 0.01)) min 1};
                };

                private _pctInt = round (_normPct * 100);
                private _rawPctInt = round (_rawPct * 100);
                private _status = if (_rawPctInt >= 70) then {"GREEN"} else { if (_rawPctInt >= 50) then {"YELLOW"} else {"RED"} };

                private _record = [_grid, _total, _pctInt, _rawPctInt, _status, _control, _hasNet, time, _itemTotal, _isRealHub];
                [TWS_HUBSUP_export_sectionHubs, _hubId, str _record] call TWS_HUBSUP_fnc_write;
                _activeKeys pushBack _hubId;
            } forEach _hubCandidates;

            [TWS_HUBSUP_export_sectionMeta, "LastScanGameTime", time] call TWS_HUBSUP_fnc_write;
            [TWS_HUBSUP_export_sectionMeta, "ScanInterval", TWS_HUBSUP_export_interval] call TWS_HUBSUP_fnc_write;
            [TWS_HUBSUP_export_sectionMeta, "HubCount", count _activeKeys] call TWS_HUBSUP_fnc_write;
            [TWS_HUBSUP_export_sectionMeta, "ActiveHubKeys", str _activeKeys] call TWS_HUBSUP_fnc_write;
            [TWS_HUBSUP_export_sectionMeta, "ScenarioClosed", 0] call TWS_HUBSUP_fnc_write;
        };

        sleep TWS_HUBSUP_export_interval;
    };

    ["[TWS_HUBSUP] Hub supply exporter stopped"] call TWS_HUBSUP_fnc_log;
};

if (isNil "TWS_HUBSUP_export_endMissionEH") then {
    TWS_HUBSUP_export_endMissionEH = addMissionEventHandler ["Ended", {
        TWS_HUBSUP_export_running = false;
        if (!isNil "TWS_HUBSUP_iniDB") then {
            ["write", [TWS_HUBSUP_export_sectionMeta, "ScenarioClosed", 1]] call TWS_HUBSUP_iniDB;
        };
    }];
};

publicVariable "TWS_HUBSUP_export_interval";
publicVariable "TWS_HUBSUP_export_running";
publicVariable "TWS_HUBSUP_debug";
