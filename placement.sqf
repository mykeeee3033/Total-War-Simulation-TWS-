// Place bunkers at bunker_ markers within the radius of target_1
private _centerMarker = "target_1";
private _centerPos = getMarkerPos _centerMarker;
private _radius = getMarkerSize _centerMarker select 0; // Assumes ellipse, use select 0 for X radius

// Find all markers whose names start with 'bunker_'
private _allMarkers = allMapMarkers;
private _bunkerMarkers = _allMarkers select {(_x find "bunker_") == 0};
private _commMarkers = _allMarkers select {(_x find "comm_") == 0};
private _powerMarkers = _allMarkers select {(_x find "power_station_") == 0};

// Place bunkers
{
    private _marker = _x;
    private _pos = getMarkerPos _marker;
    if (_centerPos distance _pos <= _radius) then {
        private _dir = markerDir _marker;
        private _bunker = createVehicle ["Land_Bunker_01_big_F", _pos, [], 0, "NONE"];
        _bunker setDir _dir;
        systemChat format ["Placed bunker at %1 with direction %2", _pos, _dir];
    };
} forEach _bunkerMarkers;

// Place comms towers
{
    private _marker = _x;
    private _pos = getMarkerPos _marker;
    private _dir = markerDir _marker;
    private _comms = createVehicle ["Land_Communication_F", _pos, [], 0, "NONE"];
    _comms setDir _dir;
    systemChat format ["Placed comms tower at %1 with direction %2", _pos, _dir];
    // Create destroy task for comms tower
    private _taskId = format ["destroy_comms_%1", _marker];
    [
        player, // or use group player for MP
        _taskId,
        [format ["Destroy the comms tower at %1.", _marker], "Destroy Comms Tower", _marker],
        _pos,
        "ASSIGNED",
        1,
        true,
        "destroy"
    ] call BIS_fnc_taskCreate;
    // Complete task when comms tower is destroyed
    _comms addEventHandler ["Killed", {
        params ["_unit", "_killer", "_instigator", "_useEffects"];
        private _taskId = format ["destroy_comms_%1", markerText (_unit getVariable ["markerName", ""])];
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
    }];
    _comms setVariable ["markerName", _marker];
} forEach _commMarkers;

// Place power generators
{
    private _marker = _x;
    private _pos = getMarkerPos _marker;
    private _dir = markerDir _marker;
    private _power = createVehicle ["Land_DPP_01_mainFactory_F", _pos, [], 0, "NONE"];
    _power setDir _dir;
    systemChat format ["Placed power generator at %1 with direction %2", _pos, _dir];
    // Create destroy task for power generator
    private _taskId = format ["destroy_power_%1", _marker];
    [
        player,
        _taskId,
        [format ["Destroy the power station at %1.", _marker], "Destroy Power Station", _marker],
        _pos,
        "ASSIGNED",
        1,
        true,
        "destroy"
    ] call BIS_fnc_taskCreate;
    // Complete task when power generator is destroyed
    _power addEventHandler ["Killed", {
        params ["_unit", "_killer", "_instigator", "_useEffects"];
        private _taskId = format ["destroy_power_%1", markerText (_unit getVariable ["markerName", ""])];
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
    }];
    _power setVariable ["markerName", _marker];
} forEach _powerMarkers;
