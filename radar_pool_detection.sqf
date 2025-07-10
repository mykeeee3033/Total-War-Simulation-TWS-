/*
    radar_pool_detection.sqf
    Usage: _pool = [radar_1] call radar_fnc_poolDetection;
*/

radar_fnc_poolDetection = {
    params ["_radar"];
    private _range = 100;
    private _nearPlanes = (_radar getPos [0,0]) nearEntities ["Plane", _range];
    private _emptyPlanes = _nearPlanes select {count crew _x == 0};
    _emptyPlanes
};