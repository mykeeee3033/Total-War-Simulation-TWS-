// Custom composition spawn at marker beach_1
private _composition = [
    ["Land_HBarrier_5_F", [0,0,0], 0],
    ["Land_HBarrier_5_F", [5,0,0], 90],
    ["Land_BagFence_Long_F", [2,3,0], 45]
];

private _markerName = "beach_1";
private _pos = getMarkerPos _markerName;
private _dir = markerDir _markerName;

{
    private _type = _x select 0;
    private _relPos = _x select 1;
    private _objDir = _x select 2;
    // Rotate relative position by marker direction
    private _rotRelPos = [
        (_relPos select 0) * cos _dir - (_relPos select 1) * sin _dir,
        (_relPos select 0) * sin _dir + (_relPos select 1) * cos _dir,
        (_relPos select 2)
    ];
    private _finalPos = _pos vectorAdd _rotRelPos;
    private _obj = createVehicle [_type, _finalPos, [], 0, "NONE"];
    _obj setDir (_dir + _objDir);
} forEach _composition;

// Grab objects near beach_1_ref and spawn them at beach_1_spawn
private _sourceMarker = "beach_1_ref";
private _sourcePos = getMarkerPos _sourceMarker;
private _radius = 500; // Adjust as needed
private _grabbedArray = [_sourcePos, _radius] call BIS_fnc_objectsGrabber;

private _destMarker = "beach_1_spawn";
private _destPos = getMarkerPos _destMarker;
private _destDir = markerDir _destMarker;

[_destPos, _destDir, _grabbedArray] call BIS_fnc_objectsMapper;

// Dynamic bunker and APC composition around marker beach_1_spawn
private _centerMarker = "beach_1_spawn";
private _centerPos = getMarkerPos _centerMarker;
private _radius = 200;

// Spawn 6 bunkers with MGs
for "_i" from 1 to 6 do {
    private _angle = random 360;
    private _dist = 50 + random (_radius - 50); // keep bunkers at least 50m from center
    private _bunkerPos = [
        (_centerPos select 0) + _dist * cos _angle,
        (_centerPos select 1) + _dist * sin _angle,
        0
    ];
    private _bunkerDir = random 360;
    private _bunker = createVehicle ["Land_PillboxBunker_01_big_F", _bunkerPos, [], 0, "NONE"];
    _bunker setDir _bunkerDir;
    // Spawn MG inside bunker
    private _mgPos = _bunker modelToWorld [0,0,1.2];
    private _mg = createVehicle ["O_HMG_01_high_F", _mgPos, [], 0, "NONE"];
    _mg setDir _bunkerDir;
};

// Spawn 3 OPFOR APCs with H-barriers in front
for "_i" from 1 to 3 do {
    private _angle = random 360;
    private _dist = 100 + random (_radius - 100); // keep APCs at least 100m from center
    private _apcPos = [
        (_centerPos select 0) + _dist * cos _angle,
        (_centerPos select 1) + _dist * sin _angle,
        0
    ];
    private _apcDir = random 360;
    private _apc = createVehicle ["O_APC_Wheeled_02_rcws_v2_F", _apcPos, [], 0, "NONE"];
    _apc setDir _apcDir;
    // Spawn 3 H-barriers in front of APC
    for "_j" from -1 to 1 do {
        private _offset = [3, _j * 3, 0]; // 3m in front, spread left/right
        private _barrierPos = _apc modelToWorld _offset;
        private _barrier = createVehicle ["Land_HBarrier_5_F", _barrierPos, [], 0, "NONE"];
        _barrier setDir _apcDir;
    };
};
