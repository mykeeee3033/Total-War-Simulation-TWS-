// Ground invasion: detect available assault vehicles near HQ, spawn crew, and send to target_1

systemChat "[INVASION] Starting ground invasion phase.";
private _hq = bluf_HQ;
systemChat format ["[INVASION] HQ position: %1", getPos _hq];
private _vehicleTypes = [
    "B_APC_Wheeled_01_cannon_F",
    "EF_B_AAV9_MJTF_Des",
    "EF_B_AAV9_50mm_MJTF_Des",
    "EF_B_CombatBoat_AT_MJTF_Des",
    "EF_B_CombatBoat_HMG_NATO"
];
systemChat format ["[INVASION] Vehicle types to detect: %1", _vehicleTypes];
private _assaultVehicles = [];
{
    private _found = getPos _hq nearEntities [_x, 500];
    systemChat format ["[INVASION] Found %1 vehicles of type %2 near HQ.", count _found, _x];
    _assaultVehicles append _found;
} forEach _vehicleTypes;
systemChat format ["[INVASION] Total assault vehicles detected: %1", count _assaultVehicles];

private _targetPos = getMarkerPos "target_1";
systemChat format ["[INVASION] Target position: %1", _targetPos];

// Wave logic
private _waveSize = 4;
private _waveDelay = 300; // 5 minutes in seconds
private _totalVehicles = count _assaultVehicles;
private _waves = ceil (_totalVehicles / _waveSize);
systemChat format ["[INVASION] Dispatching %1 vehicles in %2 waves (wave size: %3, delay: %4s)", _totalVehicles, _waves, _waveSize, _waveDelay];

for [{_wave = 0}, {_wave < _waves}, {_wave = _wave + 1}] do {
    private _startIdx = _wave * _waveSize;
    private _endIdx = (_startIdx + _waveSize) min _totalVehicles;
    private _waveVehicles = _assaultVehicles select [_startIdx, _endIdx - _startIdx];
    systemChat format ["[INVASION] Wave %1: Dispatching vehicles %2 to %3", _wave + 1, _startIdx + 1, _endIdx];
    {
        private _veh = _x;
        if (isNull _veh) exitWith { systemChat "[INVASION] Vehicle is null, skipping."; };
        if (count crew _veh == 0) then {
            private _crewGrp = createGroup west;
            private _driver = _crewGrp createUnit ["B_Soldier_F", getPos _veh, [], 0, "NONE"];
            waitUntil { !isNull _driver && alive _driver };
            _driver assignAsDriver _veh;
            _driver moveInDriver _veh;
            systemChat format ["[INVASION] Crew spawned for %1.", typeOf _veh];
        } else {
            systemChat format ["[INVASION] Vehicle %1 already has crew.", typeOf _veh];
        };
        private _grp = group driver _veh;

        // Add infantry squad to vehicle
        private _infSquad = [];
        private _squadSize = 5;
        for [{_i = 0}, {_i < _squadSize}, {_i = _i + 1}] do {
            private _unit = _grp createUnit ["B_Soldier_F", getPos _veh, [], 0, "NONE"];
            waitUntil { !isNull _unit && alive _unit };
            _infSquad pushBack _unit;
        };
        // Move infantry into cargo seats only
        {
            private _unit = _x;
            _unit moveInCargo _veh;
            systemChat format ["[INVASION] Infantry %1 moved into cargo of %2.", name _unit, typeOf _veh];
        } forEach _infSquad;

        private _wp = _grp addWaypoint [_targetPos, 0];
        _wp setWaypointType "MOVE";
        // Dismount infantry at destination
        _wp setWaypointStatements ["true", "{if (alive _x && _x != driver (vehicle _x)) then {_x action ['GetOut', vehicle _x];}} forEach units group this; systemChat '[INVASION] Infantry dismounting at target_1.';"];
        systemChat format ["[INVASION] Vehicle %1 proceeding to target_1 with infantry squad.", typeOf _veh];
    } forEach _waveVehicles;
    if (_wave < _waves - 1) then {
        systemChat format ["[INVASION] Waiting %1 seconds before next wave...", _waveDelay];
        sleep _waveDelay;
    };
};
systemChat "[INVASION] All ground invasion orders issued.";
