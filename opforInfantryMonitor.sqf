/*
 * OPFOR Infantry Monitor (Split, Cached)
 *
 * Usage:
 * [] execVM "scripts\opforInfantryMonitor.sqf";
 *
 * A3DJS command types:
 * - opfor-inf-summary  -> compact summary payload
 * - opfor-inf-squads   -> compact per-squad payload
 * - opfor-inf-detail   -> one squad detail payload (target = squad id)
 * - opfor-infantry-status -> backward-compatible discord summary view
 */

if (!isServer) exitWith {
    diag_log "[OpforInfantryMonitor] Script runs on server only";
};

if (isNil "OPFOR_INF_MONITOR_history") then { OPFOR_INF_MONITOR_history = createHashMap; };
if (isNil "OPFOR_INF_MONITOR_cachedSummary") then { OPFOR_INF_MONITOR_cachedSummary = "timestamp:0,totalSquads:0,totalAlive:0,totalWounded:0,totalKia:0,inCombat:0,criticalHealth:0,lowAmmo:0,totalRecentLosses:0"; };
if (isNil "OPFOR_INF_MONITOR_cachedSquads") then { OPFOR_INF_MONITOR_cachedSquads = "squads:"; };
if (isNil "OPFOR_INF_MONITOR_cachedDetails") then { OPFOR_INF_MONITOR_cachedDetails = createHashMap; };
if (isNil "OPFOR_INF_MONITOR_lastSummaryArray") then { OPFOR_INF_MONITOR_lastSummaryArray = [0,0,0,0,0,0,0,0,0]; };
if (isNil "OPFOR_INF_MONITOR_lastSquadsArray") then { OPFOR_INF_MONITOR_lastSquadsArray = []; };
if (isNil "OPFOR_INF_MONITOR_allowedSides") then { OPFOR_INF_MONITOR_allowedSides = [east, resistance]; };

OPFOR_INF_MONITOR_fnc_getSquadAmmoStatus = {
    params ["_group"];

    private _totalAmmo = 0;
    private _maxAmmo = 0;

    {
        if (alive _x && {_x isKindOf "Man"}) then {
            private _weapon = primaryWeapon _x;
            if (_weapon != "") then {
                private _magTypes = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
                if (count _magTypes > 0) then {
                    private _magType = _magTypes select 0;
                    private _magSize = getNumber (configFile >> "CfgMagazines" >> _magType >> "count");
                    private _currentMags = {_x == _magType} count magazines _x;
                    _totalAmmo = _totalAmmo + (_currentMags * _magSize);
                    _maxAmmo = _maxAmmo + (_magSize * 6);
                };
            };
        };
    } forEach (units _group);

    private _ammoPercentage = if (_maxAmmo > 0) then { round((_totalAmmo / _maxAmmo) * 100) } else { 0 };
    [_ammoPercentage, _totalAmmo]
};

OPFOR_INF_MONITOR_fnc_getSquadHealthStatus = {
    params ["_group"];

    private _totalHealth = 0;
    private _aliveCount = 0;
    private _woundedCount = 0;
    private _kiaCount = 0;

    {
        if (_x isKindOf "Man") then {
            if (alive _x) then {
                private _damage = damage _x;
                _totalHealth = _totalHealth + ((1 - _damage) * 100);
                _aliveCount = _aliveCount + 1;
                if (_damage > 0.25) then { _woundedCount = _woundedCount + 1; };
            } else {
                _kiaCount = _kiaCount + 1;
            };
        };
    } forEach (units _group);

    private _avgHealth = if (_aliveCount > 0) then { round(_totalHealth / _aliveCount) } else { 0 };
    [_avgHealth, _aliveCount, _woundedCount, _kiaCount]
};

OPFOR_INF_MONITOR_fnc_getCombatStatus = {
    params ["_group"];
    private _inCombat = false;

    {
        if (alive _x && {_x isKindOf "Man"} && {behaviour _x in ["COMBAT", "STEALTH"]}) exitWith {
            _inCombat = true;
        };
    } forEach (units _group);

    if (!_inCombat && {combatMode _group in ["RED", "YELLOW"]}) then { _inCombat = true; };
    if (_inCombat) then {"COMBAT"} else {"SAFE"}
};

OPFOR_INF_MONITOR_fnc_getGridLocation = {
    params ["_position"];

    private _gridRef = mapGridPosition _position;
    private _surfaceType = toLower (surfaceType _position);
    private _terrainDescription = "Open Ground";

    if (_surfaceType find "water" >= 0) then {
        _terrainDescription = "Water";
    } else {
        if (_surfaceType find "concrete" >= 0 || {_surfaceType find "tarmac" >= 0}) then {
            _terrainDescription = "Urban/Road";
        } else {
            if (_surfaceType find "forest" >= 0 || {_surfaceType find "tree" >= 0}) then {
                _terrainDescription = "Forest";
            } else {
                if (_surfaceType find "rock" >= 0 || {_surfaceType find "stone" >= 0}) then {
                    _terrainDescription = "Rocky";
                };
            };
        };
    };

    private _elevation = round (getTerrainHeightASL _position);
    [_gridRef, _terrainDescription, _elevation]
};

OPFOR_INF_MONITOR_fnc_collect = {
    private _allGroups = [];
    private _processedGroups = [];

    // Match infantry_monitor_test.sqf discovery approach for reliability
    private _mapCenter = [worldSize / 2, worldSize / 2, 0];
    private _searchRadius = worldSize;
    private _allInfantry = _mapCenter nearEntities [["Man"], _searchRadius];

    {
        private _unit = _x;
        private _group = group _unit;

        private _unitSide = side _unit;
        private _groupSide = side _group;
        private _isOpfor = (_unitSide in OPFOR_INF_MONITOR_allowedSides || {_groupSide in OPFOR_INF_MONITOR_allowedSides});

        if (
            _isOpfor &&
            {alive _unit} &&
            {!isPlayer _unit} &&
            {!(_group in _processedGroups)}
        ) then {
            _processedGroups pushBack _group;
            _allGroups pushBack _group;
        };
    } forEach _allInfantry;

    diag_log format ["[OpforInfantryMonitor] scan: infantry=%1 groups=%2", count _allInfantry, count _allGroups];

    private _currentTime = time;
    private _squads = [];

    private _totalAlive = 0;
    private _totalWounded = 0;
    private _totalKia = 0;
    private _combatSquads = 0;
    private _criticalHealthSquads = 0;
    private _lowAmmoSquads = 0;
    private _totalRecentLosses = 0;

    {
        private _group = _x;
        private _leader = leader _group;
        if (!isNull _leader) then {
            private _groupPos = getPos _leader;
            private _groupName = groupId _group;
            if (_groupName == "") then { _groupName = format ["OPFOR Group %1", _forEachIndex + 1]; };

            private _ammoStatus = [_group] call OPFOR_INF_MONITOR_fnc_getSquadAmmoStatus;
            _ammoStatus params ["_ammoPercent", "_totalAmmo"];

            private _healthStatus = [_group] call OPFOR_INF_MONITOR_fnc_getSquadHealthStatus;
            _healthStatus params ["_avgHealth", "_aliveCount", "_woundedCount", "_kiaCount"];

            private _combatText = [_group] call OPFOR_INF_MONITOR_fnc_getCombatStatus;
            private _locationInfo = [_groupPos] call OPFOR_INF_MONITOR_fnc_getGridLocation;
            _locationInfo params ["_gridRef", "_terrainDesc", "_elevation"];

            private _groupKey = str _group;
            private _historicalData = OPFOR_INF_MONITOR_history getOrDefault [_groupKey, []];
            private _currentTotal = _aliveCount + _kiaCount;
            _historicalData pushBack [_currentTime, _currentTotal];
            private _cutoff = _currentTime - 300;
            _historicalData = _historicalData select {(_x select 0) >= _cutoff};
            OPFOR_INF_MONITOR_history set [_groupKey, _historicalData];

            private _recentLosses = 0;
            if (count _historicalData > 1) then {
                private _oldest = _historicalData select 0;
                _recentLosses = (_oldest select 1) - _currentTotal;
                if (_recentLosses < 0) then { _recentLosses = 0; };
            };

            _squads pushBack [
                _groupName,
                "EAST",
                _ammoPercent,
                _totalAmmo,
                _avgHealth,
                _aliveCount,
                _woundedCount,
                _kiaCount,
                _recentLosses,
                _combatText,
                _gridRef,
                _terrainDesc,
                _elevation
            ];

            _totalAlive = _totalAlive + _aliveCount;
            _totalWounded = _totalWounded + _woundedCount;
            _totalKia = _totalKia + _kiaCount;
            _totalRecentLosses = _totalRecentLosses + _recentLosses;
            if (_combatText == "COMBAT") then { _combatSquads = _combatSquads + 1; };
            if (_avgHealth < 50) then { _criticalHealthSquads = _criticalHealthSquads + 1; };
            if (_ammoPercent < 30) then { _lowAmmoSquads = _lowAmmoSquads + 1; };
        };
    } forEach _allGroups;

    private _summary = [
        floor diag_tickTime,
        count _squads,
        _totalAlive,
        _totalWounded,
        _totalKia,
        _combatSquads,
        _criticalHealthSquads,
        _lowAmmoSquads,
        _totalRecentLosses
    ];

    [_summary, _squads]
};

OPFOR_INF_MONITOR_fnc_buildSummaryText = {
    params ["_summary"];
    _summary params ["_timestamp", "_totalSquads", "_totalAlive", "_totalWounded", "_totalKia", "_inCombat", "_criticalHealth", "_lowAmmo", "_totalRecentLosses"];

    format [
        "timestamp:%1,totalSquads:%2,totalAlive:%3,totalWounded:%4,totalKia:%5,inCombat:%6,criticalHealth:%7,lowAmmo:%8,totalRecentLosses:%9",
        _timestamp, _totalSquads, _totalAlive, _totalWounded, _totalKia, _inCombat, _criticalHealth, _lowAmmo, _totalRecentLosses
    ]
};

OPFOR_INF_MONITOR_fnc_buildSquadsText = {
    params ["_squads"];
    private _rows = [];
    {
        _x params ["_groupName", "_sideText", "_ammoPercent", "_totalAmmo", "_avgHealth", "_aliveCount", "_woundedCount", "_kiaCount", "_recentLosses", "_combatText", "_gridRef", "_terrainDesc", "_elevation"];
        _rows pushBack format ["%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11|%12|%13", _groupName, _sideText, _ammoPercent, _totalAmmo, _avgHealth, _aliveCount, _woundedCount, _kiaCount, _recentLosses, _combatText, _gridRef, _terrainDesc, _elevation];
    } forEach _squads;
    format ["squads:%1", _rows joinString "~"]
};

OPFOR_INF_MONITOR_fnc_refreshCache = {
    private _collected = [] call OPFOR_INF_MONITOR_fnc_collect;
    _collected params ["_summary", "_squads"];

    OPFOR_INF_MONITOR_lastSummaryArray = _summary;
    OPFOR_INF_MONITOR_lastSquadsArray = _squads;
    OPFOR_INF_MONITOR_cachedSummary = [_summary] call OPFOR_INF_MONITOR_fnc_buildSummaryText;
    OPFOR_INF_MONITOR_cachedSquads = [_squads] call OPFOR_INF_MONITOR_fnc_buildSquadsText;

    private _details = createHashMap;
    {
        _x params ["_groupName", "_sideText", "_ammoPercent", "_totalAmmo", "_avgHealth", "_aliveCount", "_woundedCount", "_kiaCount", "_recentLosses", "_combatText", "_gridRef", "_terrainDesc", "_elevation"];
        _details set [_groupName, format ["id:%1,side:%2,health:%3,ammo:%4,totalAmmo:%5,alive:%6,wounded:%7,kia:%8,recentLosses:%9,combat:%10,grid:%11,terrain:%12,elevation:%13", _groupName, _sideText, _avgHealth, _ammoPercent, _totalAmmo, _aliveCount, _woundedCount, _kiaCount, _recentLosses, _combatText, _gridRef, _terrainDesc, _elevation]];
    } forEach _squads;
    OPFOR_INF_MONITOR_cachedDetails = _details;

    true
};

OPFOR_INF_MONITOR_fnc_getDiscordSummary = {
    private _summary = OPFOR_INF_MONITOR_lastSummaryArray;
    private _squads = OPFOR_INF_MONITOR_lastSquadsArray;
    _summary params ["_timestamp", "_totalSquads", "_totalAlive", "_totalWounded", "_totalKia", "_inCombat", "_criticalHealth", "_lowAmmo", "_totalRecentLosses"];

    private _lines = [];
    _lines pushBack "📡 **OPFOR INFANTRY STATUS**";
    _lines pushBack format ["SQUADS: %1 | ALIVE: %2 | WOUNDED: %3 | KIA: %4", _totalSquads, _totalAlive, _totalWounded, _totalKia];
    _lines pushBack format ["IN COMBAT: %1 | CRITICAL HP: %2 | LOW AMMO: %3 | LOSSES(5m): %4", _inCombat, _criticalHealth, _lowAmmo, _totalRecentLosses];
    _lines pushBack "";

    private _shown = 0;
    {
        if (_shown < 5) then {
            _x params ["_groupName", "_sideText", "_ammoPercent", "_totalAmmo", "_avgHealth", "_aliveCount", "_woundedCount", "_kiaCount", "_recentLosses", "_combatText", "_gridRef", "_terrainDesc", "_elevation"];
            _lines pushBack format ["%1 (%2) | HP %3%% | AMMO %4%% | A/W/K %5/%6/%7 | %8 | %9 (%10, %11m)", _groupName, _sideText, _avgHealth, _ammoPercent, _aliveCount, _woundedCount, _kiaCount, _combatText, _gridRef, _terrainDesc, _elevation];
            _shown = _shown + 1;
        };
    } forEach _squads;

    _lines joinString "\n"
};

OPFOR_INF_MONITOR_fnc_getSummary = {
    params ["_target", "_sender", "_RequestId", ["_action", ""]];
    [_RequestId, OPFOR_INF_MONITOR_cachedSummary] call A3DJS_fnc_respondCall;
    diag_log format ["[OpforInfantryMonitor] summary served to %1", _sender];
    true
};

OPFOR_INF_MONITOR_fnc_getSquads = {
    params ["_target", "_sender", "_RequestId", ["_action", ""]];
    [_RequestId, OPFOR_INF_MONITOR_cachedSquads] call A3DJS_fnc_respondCall;
    diag_log format ["[OpforInfantryMonitor] squads served to %1", _sender];
    true
};

OPFOR_INF_MONITOR_fnc_getDetail = {
    params ["_target", "_sender", "_RequestId", ["_action", ""]];

    private _detailKey = _target;
    if (_detailKey == "" && {count OPFOR_INF_MONITOR_lastSquadsArray > 0}) then {
        _detailKey = (OPFOR_INF_MONITOR_lastSquadsArray select 0) select 0;
    };

    private _response = OPFOR_INF_MONITOR_cachedDetails getOrDefault [_detailKey, format ["error:detail_not_found,id:%1", _detailKey]];
    [_RequestId, _response] call A3DJS_fnc_respondCall;
    diag_log format ["[OpforInfantryMonitor] detail served to %1 (id=%2)", _sender, _detailKey];
    true
};

OPFOR_INF_MONITOR_fnc_getStatusDiscord = {
    params ["_target", "_sender", "_RequestId", ["_action", ""]];
    private _response = [] call OPFOR_INF_MONITOR_fnc_getDiscordSummary;
    [_RequestId, _response] call A3DJS_fnc_respondCall;
    diag_log format ["[OpforInfantryMonitor] discord summary served to %1", _sender];
    true
};

[] spawn {
    [] call OPFOR_INF_MONITOR_fnc_refreshCache;
    while {true} do {
        [] call OPFOR_INF_MONITOR_fnc_refreshCache;
        private _s = OPFOR_INF_MONITOR_lastSummaryArray;
        diag_log format ["[OpforInfantryMonitor] cache refreshed: squads=%1 alive=%2 wounded=%3 kia=%4", _s select 1, _s select 2, _s select 3, _s select 4];
        sleep 5;
    };
};

[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};

    ["opfor-inf-summary", OPFOR_INF_MONITOR_fnc_getSummary] call A3DJS_fnc_addCommandType;
    ["opfor-inf-squads", OPFOR_INF_MONITOR_fnc_getSquads] call A3DJS_fnc_addCommandType;
    ["opfor-inf-detail", OPFOR_INF_MONITOR_fnc_getDetail] call A3DJS_fnc_addCommandType;

    // Backward compatible command name
    ["opfor-infantry-status", OPFOR_INF_MONITOR_fnc_getStatusDiscord] call A3DJS_fnc_addCommandType;

    systemChat "[OpforInfantryMonitor] Commands registered: opfor-inf-summary / opfor-inf-squads / opfor-inf-detail";
    diag_log "[OpforInfantryMonitor] A3DJS commands registered";
};

publicVariable "OPFOR_INF_MONITOR_fnc_getSummary";
publicVariable "OPFOR_INF_MONITOR_fnc_getSquads";
publicVariable "OPFOR_INF_MONITOR_fnc_getDetail";
publicVariable "OPFOR_INF_MONITOR_fnc_getStatusDiscord";

systemChat "[OpforInfantryMonitor] Initialized (split/cached OPFOR monitor)";
diag_log "[OpforInfantryMonitor] Initialized (split/cached OPFOR monitor)";
