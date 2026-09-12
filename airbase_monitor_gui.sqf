/*
    TWS Airbase Ownership Monitor

    Uses the air markers from radar_system.sqf and the sector ownership logic
    from quickSectorInfo.sqf to show a visual airbase overview in a dialog.

    Usage:
    [] execVM "airbase_monitor_gui.sqf";
*/

if (isNull player) exitWith {};
if (isNil "ALiVE_sectorGrid") exitWith {
    systemChat "[AIRBASE MON] ALiVE sector grid not ready.";
};

if (isNil "OPCOM_instances") then { OPCOM_instances = []; };

if (isNil "TWS_airbaseMonitor_running") then { TWS_airbaseMonitor_running = false; };
if (isNil "TWS_airbaseMonitor_data") then { TWS_airbaseMonitor_data = []; };
if (isNil "TWS_airbaseMonitor_refreshInterval") then { TWS_airbaseMonitor_refreshInterval = 10; };

TWS_fnc_airbaseMonitor_getRadarMarkers = {
    private _markers = [];
    {
        private _markerName = format ["air_marker_%1", _x];
        private _markerPos = getMarkerPos _markerName;
        if (_markerPos distance2D [0, 0, 0] > 0) then {
            _markers pushBack [_markerName, _markerPos];
        };
    } forEach [1, 2, 3, 4, 5, 6];
    _markers
};

TWS_fnc_airbaseMonitor_getSectorOwnership = {
    params ["_position"];

    private _ownership = "Neutral";
    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;

    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith { _ownership };

    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (count _sectorData == 0) exitWith { _ownership };

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
            case "WEST": { _ownership = "BLUFOR"; };
            case "EAST": { _ownership = "OPFOR"; };
            case "GUER": { _ownership = "INDEP"; };
            default { _ownership = "Neutral"; };
        };
    };

    if (_ownership isEqualTo "Neutral" && {!isNil "OPCOM_instances"}) then {
        {
            private _opcom = _x;
            private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                if ([_sector, "within", _objCenter] call ALIVE_fnc_sector) then {
                    if (_objState in ["defend", "defending", "reserve"] || {_objState isEqualTo "assigned"}) then {
                        switch (_opcomSide) do {
                            case "WEST": { _ownership = "BLUFOR"; };
                            case "EAST": { _ownership = "OPFOR"; };
                            case "GUER": { _ownership = "INDEP"; };
                        };
                    };
                };
            } forEach _objectives;
        } forEach OPCOM_instances;
    };

    _ownership
};

TWS_fnc_airbaseMonitor_getLocationName = {
    params ["_position", ["_locationTypes", ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "NameMarine"]]];

    private _nearest = objNull;
    private _bestDist = 1e10;

    {
        private _locs = nearestLocations [_position, [_x], 8000];
        {
            private _dist = _position distance2D (locationPosition _x);
            if (_dist < _bestDist) then {
                _bestDist = _dist;
                _nearest = _x;
            };
        } forEach _locs;
    } forEach _locationTypes;

    if (_bestDist isEqualTo 1e10) exitWith { mapGridPosition _position };
    text _nearest
};

TWS_fnc_airbaseMonitor_getNearestObjective = {
    params ["_position"];

    private _bestName = "None";
    private _bestDist = 1e10;

    if (!isNil "OPCOM_instances") then {
        {
            private _opcom = _x;
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                private _objType = [_objective, "objectiveType", "unknown"] call ALIVE_fnc_hashGet;
                private _objID = [_objective, "objectiveID", "unknown"] call ALIVE_fnc_hashGet;
                private _dist = _position distance2D _objCenter;

                if (_dist < _bestDist) then {
                    _bestDist = _dist;
                    _bestName = format ["%1 (%2)", _objID, _objType];
                };
            } forEach _objectives;
        } forEach OPCOM_instances;
    };

    _bestName
};

TWS_fnc_airbaseMonitor_collectData = {
    private _results = [];
    {
        _x params ["_markerName", "_markerPos"];
        private _ownership = [_markerPos] call TWS_fnc_airbaseMonitor_getSectorOwnership;
        private _nearestTown = [_markerPos] call TWS_fnc_airbaseMonitor_getLocationName;
        private _nearestAirport = [_markerPos, ["Airport"]] call TWS_fnc_airbaseMonitor_getLocationName;
        private _nearestObjective = [_markerPos] call TWS_fnc_airbaseMonitor_getNearestObjective;
        private _sector = [ALiVE_sectorGrid, "positionToSector", _markerPos] call ALIVE_fnc_sectorGrid;
        private _sectorId = "Unknown";
        if (count _sector > 0 && {count (_sector select 1) > 0}) then {
            _sectorId = [_sector, "id"] call ALIVE_fnc_sector;
        };

        private _entry = [
            _markerName,
            _markerPos,
            _ownership,
            _nearestTown,
            _nearestAirport,
            _nearestObjective,
            _sectorId
        ];
        _results pushBack _entry;
    } forEach ([] call TWS_fnc_airbaseMonitor_getRadarMarkers);

    TWS_airbaseMonitor_data = _results;
    _results
};

TWS_fnc_airbaseMonitor_updateDialog = {
    private _display = findDisplay 9300;
    if (isNull _display) exitWith {};

    private _list = _display displayCtrl 9301;
    private _detail = _display displayCtrl 9302;
    private _status = _display displayCtrl 9305;

    lbClear _list;

    private _data = [] call TWS_fnc_airbaseMonitor_collectData;
    {
        _x params ["_markerName", "_markerPos", "_ownership", "_nearestTown", "_nearestAirport", "_nearestObjective", "_sectorId"];
        private _rowText = format ["%1 | %2 | %3", _markerName, _ownership, _nearestTown];
        private _rowIndex = _list lbAdd _rowText;
        _list lbSetData [_rowIndex, _markerName];
        private _rowColor = switch (_ownership) do {
            case "BLUFOR": {[0.2, 0.5, 1, 1]};
            case "OPFOR": {[1, 0.25, 0.25, 1]};
            case "INDEP": {[0.3, 0.9, 0.3, 1]};
            default {[0.9, 0.9, 0.4, 1]};
        };
        _list lbSetColor [_rowIndex, _rowColor];
    } forEach _data;

    if ((lbSize _list) > 0) then {
        _list lbSetCurSel 0;
    };

    private _selectedIndex = lbCurSel _list;
    private _selectedName = if (_selectedIndex >= 0) then { _list lbData _selectedIndex } else { "" };
    private _selectedEntry = [];
    {
        if ((_x select 0) isEqualTo _selectedName) exitWith { _selectedEntry = _x; };
    } forEach _data;

    if (count _selectedEntry == 0 && {count _data > 0}) then {
        _selectedEntry = _data select 0;
    };

    private _detailText = "<t size='1.25' color='#00ff88'>AIRBASE REPORT</t><br/><br/>";
    if (count _selectedEntry > 0) then {
        _selectedEntry params ["_markerName", "_markerPos", "_ownership", "_nearestTown", "_nearestAirport", "_nearestObjective", "_sectorId"];
        private _color = switch (_ownership) do {
            case "BLUFOR": {"#4da3ff"};
            case "OPFOR": {"#ff5a5a"};
            case "INDEP": {"#6fff6f"};
            default {"#ffff88"};
        };
        _detailText = _detailText + format [
            "<t size='1.1' color='%1'>%2</t><br/>Town: %3<br/>Airport: %4<br/>Objective: %5<br/>Sector: %6<br/>Marker Pos: %7",
            _color,
            _markerName,
            _nearestTown,
            _nearestAirport,
            _nearestObjective,
            _sectorId,
            mapGridPosition _markerPos
        ];
    } else {
        _detailText = _detailText + "No airbases detected.";
    };

    _detail ctrlSetStructuredText parseText _detailText;
    _status ctrlSetText format ["Airbases: %1 | Refresh OK", count _data];
};

TWS_fnc_airbaseMonitor_open = {
    if (dialog) then { closeDialog 0; };
    createDialog "TWS_AirbaseMonitorDialog";
    [] spawn {
        uiSleep 0.05;
        [] call TWS_fnc_airbaseMonitor_updateDialog;
    };
};

TWS_fnc_airbaseMonitor_refresh = {
    [] call TWS_fnc_airbaseMonitor_updateDialog;
};

[] call TWS_fnc_airbaseMonitor_open;

if (!TWS_airbaseMonitor_running) then {
    TWS_airbaseMonitor_running = true;
    [] spawn {
        while {dialog} do {
            [] call TWS_fnc_airbaseMonitor_updateDialog;
            uiSleep TWS_airbaseMonitor_refreshInterval;
        };
        TWS_airbaseMonitor_running = false;
    };
};
