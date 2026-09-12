/*
 * opfor_commander_action_arty.sqf
 *
 * OPFOR commander executable: artillery support action.
 *
 * Loaded by opfor_AI_commander_main.sqf and called per-cycle with normalized
 * recon sightings.
 */

if (isNil "OPFCOM_fnc_initArtyAction") then {
    OPFCOM_fnc_initArtyAction = {
        if (isNil "OPFCOM_supportCooldown") then { OPFCOM_supportCooldown = 1; };
        if (isNil "OPFCOM_lastSupportTime") then { OPFCOM_lastSupportTime = -9999; };
        if (isNil "OPFCOM_hqPrefix") then { OPFCOM_hqPrefix = "O_HQ_"; };
        if (isNil "OPFCOM_lightArtyClass") then { OPFCOM_lightArtyClass = "EF_O_Gyra_Mortar_OPF"; };
        OPFCOM_mediumArtyClass = "O_MBT_02_arty_F";
        if (isNil "OPFCOM_heavyArtyClass") then { OPFCOM_heavyArtyClass = "O_MBT_02_arty_F"; };
        if (isNil "OPFCOM_lightTargetMax") then { OPFCOM_lightTargetMax = 4; };
        if (isNil "OPFCOM_mediumTargetMax") then { OPFCOM_mediumTargetMax = 10; };
        if (isNil "OPFCOM_fireRounds") then { OPFCOM_fireRounds = 15; };
        if (isNil "OPFCOM_fireSpread") then { OPFCOM_fireSpread = 50; };
        if (isNil "OPFCOM_mediumFireRounds") then { OPFCOM_mediumFireRounds = 25; };
        if (isNil "OPFCOM_mediumFireSpread") then { OPFCOM_mediumFireSpread = 40; };
        if (isNil "OPFCOM_heavyFireRounds") then { OPFCOM_heavyFireRounds = 10; };
        if (isNil "OPFCOM_heavyFireSpread") then { OPFCOM_heavyFireSpread = 50; };
        if (isNil "OPFCOM_lastSupportTier") then { OPFCOM_lastSupportTier = "NONE"; };
        if (isNil "OPFCOM_crewRetainTime") then { OPFCOM_crewRetainTime = 90; };
        if (isNil "OPFCOM_crewClass") then { OPFCOM_crewClass = "O_crew_F"; };
        if (isNil "OPFCOM_hqArtillery") then { OPFCOM_hqArtillery = createHashMap; };

        if (isNil "OPFCOM_contactMemory") then { OPFCOM_contactMemory = createHashMap; };
        if (isNil "OPFCOM_minContactPersistence") then { OPFCOM_minContactPersistence = 30; };
        if (isNil "OPFCOM_contactMemoryMaxAge") then { OPFCOM_contactMemoryMaxAge = 300; };

        if (isNil "OPFCOM_baseScoreThreshold") then { OPFCOM_baseScoreThreshold = 95; };
        if (isNil "OPFCOM_escalationPoints") then { OPFCOM_escalationPoints = 0; };
        if (isNil "OPFCOM_escalationIncreaseOnStrike") then { OPFCOM_escalationIncreaseOnStrike = 18; };
        if (isNil "OPFCOM_escalationDecayPerMinute") then { OPFCOM_escalationDecayPerMinute = 8; };
        if (isNil "OPFCOM_lastEscalationUpdate") then { OPFCOM_lastEscalationUpdate = time; };

        if (isNil "OPFCOM_recentOpforLosses") then { OPFCOM_recentOpforLosses = []; };
        if (isNil "OPFCOM_lossWindowSeconds") then { OPFCOM_lossWindowSeconds = 300; };
        if (isNil "OPFCOM_lossRadiusMeters") then { OPFCOM_lossRadiusMeters = 350; };
        if (isNil "OPFCOM_minLossesForIndirect") then { OPFCOM_minLossesForIndirect = 2; };
        if (isNil "OPFCOM_requireLossesForIndirect") then { OPFCOM_requireLossesForIndirect = false; };
        if (isNil "OPFCOM_lossEHAdded") then { OPFCOM_lossEHAdded = false; };

        if (!OPFCOM_lossEHAdded) then {
            OPFCOM_lossEHAdded = true;
            addMissionEventHandler ["EntityKilled", {
                params ["_unit"];
                if (!isNull _unit && {side _unit == east || {side (group _unit) == east}}) then {
                    OPFCOM_recentOpforLosses pushBack [getPosATL _unit, time];
                };
            }];
        };

        if (isNil "OPFCOM_fnc_getHQMarkers") then {
            OPFCOM_fnc_getHQMarkers = {
                allMapMarkers select {
                    (_x find OPFCOM_hqPrefix == 0) &&
                    {(getMarkerPos _x) distance2D [0, 0, 0] > 0}
                }
            };
        };

        if (isNil "OPFCOM_fnc_getHQOwnership") then {
            OPFCOM_fnc_getHQOwnership = {
                params ["_hqMarker"];

                private _hqPos = getMarkerPos _hqMarker;
                if (_hqPos distance2D [0, 0, 0] <= 0) exitWith {"NONE"};

                if (!isNil "RES_fnc_getSectorControl") exitWith {
                    [_hqPos] call RES_fnc_getSectorControl
                };

                if (isNil "ALiVE_sectorGrid") exitWith {"NONE"};
                private _sector = [ALiVE_sectorGrid, "positionToSector", _hqPos] call ALIVE_fnc_sectorGrid;
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

                switch (_dominatingSide) do {
                    case "EAST": {"OPFOR"};
                    case "WEST": {"BLUFOR"};
                    case "GUER": {"INDEP"};
                    default {"NONE"};
                }
            };
        };

        if (isNil "OPFCOM_fnc_isHQAvailable") then {
            OPFCOM_fnc_isHQAvailable = {
                params ["_hqMarker"];
                ([_hqMarker] call OPFCOM_fnc_getHQOwnership) == "OPFOR"
            };
        };

        if (isNil "OPFCOM_fnc_getAvailableHQMarkers") then {
            OPFCOM_fnc_getAvailableHQMarkers = {
                private _hqMarkers = [] call OPFCOM_fnc_getHQMarkers;
                _hqMarkers select { [_x] call OPFCOM_fnc_isHQAvailable }
            };
        };

        if (isNil "OPFCOM_fnc_updateContactMemory") then {
            OPFCOM_fnc_updateContactMemory = {
                params ["_sightings"];

                private _now = time;
                {
                    _x params ["_group", "_pos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];
                    private _key = str _group;
                    private _entry = OPFCOM_contactMemory getOrDefault [_key, []];

                    if (count _entry == 0) then {
                        OPFCOM_contactMemory set [_key, [_lastSeen, _lastSeen]];
                    } else {
                        _entry params ["_firstSeen", "_memLastSeen"];
                        if ((_lastSeen - _memLastSeen) > (OPFCOM_contactMemoryMaxAge * 0.5)) then {
                            _firstSeen = _lastSeen;
                        };
                        OPFCOM_contactMemory set [_key, [_firstSeen, _lastSeen max _memLastSeen]];
                    };
                } forEach _sightings;

                {
                    private _k = _x;
                    private _v = OPFCOM_contactMemory get _k;
                    if (!isNil "_v" && {count _v >= 2}) then {
                        private _last = _v select 1;
                        if ((_now - _last) > OPFCOM_contactMemoryMaxAge) then {
                            OPFCOM_contactMemory deleteAt _k;
                        };
                    };
                } forEach (keys OPFCOM_contactMemory);
            };
        };

        if (isNil "OPFCOM_fnc_getPersistenceSeconds") then {
            OPFCOM_fnc_getPersistenceSeconds = {
                params ["_targetData"];
                _targetData params ["_group", "_pos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];

                private _entry = OPFCOM_contactMemory getOrDefault [str _group, []];
                if (count _entry < 2) exitWith {0};
                private _firstSeen = _entry select 0;
                (_lastSeen - _firstSeen) max 0
            };
        };

        if (isNil "OPFCOM_fnc_cleanupRecentLosses") then {
            OPFCOM_fnc_cleanupRecentLosses = {
                private _now = time;
                OPFCOM_recentOpforLosses = OPFCOM_recentOpforLosses select {
                    (_now - (_x select 1)) <= OPFCOM_lossWindowSeconds
                };
            };
        };

        if (isNil "OPFCOM_fnc_countRecentOpforLossesNearTarget") then {
            OPFCOM_fnc_countRecentOpforLossesNearTarget = {
                params ["_pos"];
                [] call OPFCOM_fnc_cleanupRecentLosses;

                private _count = 0;
                {
                    private _lossPos = _x select 0;
                    if ((_lossPos distance2D _pos) <= OPFCOM_lossRadiusMeters) then {
                        _count = _count + 1;
                    };
                } forEach OPFCOM_recentOpforLosses;

                _count
            };
        };

        if (isNil "OPFCOM_fnc_updateEscalation") then {
            OPFCOM_fnc_updateEscalation = {
                private _now = time;
                private _elapsed = (_now - OPFCOM_lastEscalationUpdate) max 0;
                private _decay = (_elapsed / 60) * OPFCOM_escalationDecayPerMinute;
                OPFCOM_escalationPoints = (OPFCOM_escalationPoints - _decay) max 0;
                OPFCOM_lastEscalationUpdate = _now;
            };
        };

        if (isNil "OPFCOM_fnc_getDynamicScoreThreshold") then {
            OPFCOM_fnc_getDynamicScoreThreshold = {
                OPFCOM_baseScoreThreshold + OPFCOM_escalationPoints
            };
        };

        if (isNil "OPFCOM_fnc_passesThreatSizeGate") then {
            OPFCOM_fnc_passesThreatSizeGate = {
                params ["_class", "_size"];

                switch (_class) do {
                    case "infantry": { _size >= 8 };
                    case "static": { _size >= 8 };
                    case "static support": { _size >= 7 };
                    case "mech infantry": { _size >= 6 };
                    case "mech": { _size >= 5 };
                    case "naval": { _size >= 4 };
                    case "armour": { true };
                    case "armour-mech": { true };
                    case "combined arms": { true };
                    default { _size >= 8 };
                }
            };
        };

        if (isNil "OPFCOM_fnc_getStrikeProbability") then {
            OPFCOM_fnc_getStrikeProbability = {
                params ["_class", "_size"];

                private _base = switch (_class) do {
                    case "combined arms": {0.95};
                    case "armour": {0.90};
                    case "armour-mech": {0.88};
                    case "mech infantry": {0.65};
                    case "mech": {0.58};
                    case "static support": {0.35};
                    case "static": {0.30};
                    case "naval": {0.40};
                    case "infantry": {0.28};
                    default {0.25};
                };

                (_base + ((_size min 20) * 0.01)) min 1
            };
        };

        if (isNil "OPFCOM_fnc_isArmourTarget") then {
            OPFCOM_fnc_isArmourTarget = {
                params ["_targetData"];
                _targetData params ["_group", "_pos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];

                _mix params ["_inf", "_sta", "_arm", "_mech", "_air", "_nav"];
                (_arm > 0) || {_class in ["armour", "armour-mech", "combined arms"]}
            };
        };

        if (isNil "OPFCOM_fnc_selectPrimaryTarget") then {
            OPFCOM_fnc_selectPrimaryTarget = {
                params ["_sightings"];

                if (count _sightings == 0) exitWith {[]};

                private _now = time;
                private _scored = [];
                private _scoredArmour = [];

                {
                    private _t = _x;
                    _t params ["_group", "_pos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];

                    if !(_class isEqualTo "air") then {
                        private _persistence = [_t] call OPFCOM_fnc_getPersistenceSeconds;
                        if (_persistence < OPFCOM_minContactPersistence) then { continue; };

                        if !([_class, _size] call OPFCOM_fnc_passesThreatSizeGate) then { continue; };

                        private _lossesNear = [_pos] call OPFCOM_fnc_countRecentOpforLossesNearTarget;
                        private _needsLossTrigger = _class in ["infantry", "static", "static support", "mech", "mech infantry", "naval"];
                        if (OPFCOM_requireLossesForIndirect && {_needsLossTrigger && {_lossesNear < OPFCOM_minLossesForIndirect}}) then { continue; };

                        _mix params ["_inf", "_sta", "_arm", "_mech", "_air", "_nav"];

                        private _base = switch (_class) do {
                            case "combined arms": {95};
                            case "armour": {92};
                            case "armour-mech": {90};
                            case "mech infantry": {82};
                            case "mech": {75};
                            case "static support": {62};
                            case "static": {55};
                            case "naval": {50};
                            case "infantry": {45};
                            default {40};
                        };

                        private _sizeScore = (_size min 20) * 2;
                        private _mixScore = ((_arm * 10) + (_mech * 7) + (_sta * 4) + (_inf * 2)) min 30;
                        private _statusScore = if (_status isEqualTo "full health") then {5} else {0};
                        private _agePenalty = (((_now - _lastSeen) max 0) min 120) / 4;

                        private _lossBias = (_lossesNear min 6) * 3;
                        private _score = _base + _sizeScore + _mixScore + _statusScore + _lossBias - _agePenalty;

                        private _threshold = [] call OPFCOM_fnc_getDynamicScoreThreshold;
                        if (_score < _threshold) then { continue; };

                        private _prob = [_class, _size] call OPFCOM_fnc_getStrikeProbability;
                        if ((random 1) > _prob) then { continue; };

                        _scored pushBack [_score, _t];
                        if ([_t] call OPFCOM_fnc_isArmourTarget) then {
                            _scoredArmour pushBack [_score, _t];
                        };
                    };
                } forEach _sightings;

                if (count _scoredArmour > 0) then {
                    private _sortedArmour = [_scoredArmour, [], {_x select 0}, "DESCEND"] call BIS_fnc_sortBy;
                    (_sortedArmour select 0) select 1
                } else {
                if (count _scored == 0) exitWith {[]};
                private _sorted = [_scored, [], {_x select 0}, "DESCEND"] call BIS_fnc_sortBy;
                (_sorted select 0) select 1
                }
            };
        };

        if (isNil "OPFCOM_fnc_findClosestHQ") then {
            OPFCOM_fnc_findClosestHQ = {
                params ["_targetPos", "_hqMarkers"];

                private _bestMarker = "";
                private _bestDist = 1e10;

                {
                    private _mPos = getMarkerPos _x;
                    private _d = _mPos distance2D _targetPos;
                    if (_d < _bestDist) then {
                        _bestDist = _d;
                        _bestMarker = _x;
                    };
                } forEach _hqMarkers;

                _bestMarker
            };
        };

        if (isNil "OPFCOM_fnc_getOrCreateHQArtillery") then {
            OPFCOM_fnc_getOrCreateHQArtillery = {
                params ["_hqMarker", "_artilleryClass"];

                private _cacheKey = format ["%1|%2", _hqMarker, _artilleryClass];
                private _existing = OPFCOM_hqArtillery getOrDefault [_cacheKey, objNull];
                if (!isNull _existing && {alive _existing}) exitWith {_existing};

                private _hqPos = getMarkerPos _hqMarker;
                if (_hqPos distance2D [0, 0, 0] <= 0) exitWith {objNull};

                private _spawnPos = [_hqPos, 20, 80, 8, 0, 0.4, 0, [], [_hqPos, _hqPos]] call BIS_fnc_findSafePos;
                if (_spawnPos distance2D [0, 0, 0] <= 0) then {
                    _spawnPos = _hqPos;
                };

                private _gun = createVehicle [_artilleryClass, _spawnPos, [], 0, "NONE"];
                _gun setDir (random 360);
                _gun setVehicleAmmo 1;
                _gun setFuel 1;
                _gun setDamage 0;

                OPFCOM_hqArtillery set [_cacheKey, _gun];
                publicVariable "OPFCOM_hqArtillery";

                _gun
            };
        };

        if (isNil "OPFCOM_fnc_selectArtilleryClassForTarget") then {
            OPFCOM_fnc_selectArtilleryClassForTarget = {
                params ["_targetData"];

                _targetData params ["_group", "_targetPos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];

                if (_class isEqualTo "air") exitWith {""};
                if ([_targetData] call OPFCOM_fnc_isArmourTarget) exitWith {OPFCOM_heavyArtyClass};
                if (_size <= OPFCOM_lightTargetMax) exitWith {OPFCOM_lightArtyClass};
                OPFCOM_mediumArtyClass
            };
        };

        if (isNil "OPFCOM_fnc_getFireProfileForTarget") then {
            OPFCOM_fnc_getFireProfileForTarget = {
                params ["_targetData"];

                _targetData params ["_group", "_targetPos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];

                if ([_targetData] call OPFCOM_fnc_isArmourTarget) exitWith {[OPFCOM_heavyFireRounds, OPFCOM_heavyFireSpread, "heavy"]};
                if (_size <= OPFCOM_lightTargetMax) exitWith {[OPFCOM_fireRounds, OPFCOM_fireSpread, "light"]};
                [OPFCOM_mediumFireRounds, OPFCOM_mediumFireSpread, "medium"]
            };
        };

        if (isNil "OPFCOM_fnc_spawnCrewInArtillery") then {
            OPFCOM_fnc_spawnCrewInArtillery = {
                params ["_gun"];

                private _grp = createGroup east;
                private _spawned = [];

                private _gunner = _grp createUnit [OPFCOM_crewClass, getPosATL _gun, [], 0, "NONE"];
                if (_gun emptyPositions "Gunner" > 0) then {
                    _gunner moveInGunner _gun;
                } else {
                    if (_gun emptyPositions "Commander" > 0) then {
                        _gunner moveInCommander _gun;
                    } else {
                        if (_gun emptyPositions "Driver" > 0) then {
                            _gunner moveInDriver _gun;
                        };
                    };
                };

                if (vehicle _gunner != _gun) then {
                    deleteVehicle _gunner;
                    deleteGroup _grp;
                    [grpNull, []]
                } else {
                    _spawned pushBack _gunner;
                    [_grp, _spawned]
                }
            };
        };

        if (isNil "OPFCOM_fnc_fireMission") then {
            OPFCOM_fnc_fireMission = {
                params ["_gun", "_targetPos", ["_rounds", OPFCOM_fireRounds], ["_spread", OPFCOM_fireSpread], ["_threatLevel", "light"], ["_targetClass", "unknown"], ["_forceCluster", false]];

                private _ammoOptions = getArtilleryAmmo [_gun];
                if (count _ammoOptions == 0) exitWith {false};

                private _magInfo = magazinesAmmo _gun;
                private _clusterExact = "2Rnd_155mm_Mo_Cluster_O";
                private _bestOverallAmmo = _ammoOptions select 0;
                private _bestOverallCount = -1;
                private _bestClusterAmmo = "";
                private _bestClusterCount = -1;
                private _bestRegularAmmo = "";
                private _bestRegularCount = -1;
                private _exactClusterCount = 0;
                {
                    private _ammoClass = _x;
                    private _available = 0;
                    {
                        private _magClass = _x select 0;
                        private _r = _x select 1;
                        if (_magClass == _ammoClass) then {
                            _available = _available + _r;
                        };
                    } forEach _magInfo;

                    if (_available > _bestOverallCount) then {
                        _bestOverallCount = _available;
                        _bestOverallAmmo = _ammoClass;
                    };

                    private _upper = toUpper _ammoClass;
                    private _isCluster = ((_upper find "CLUSTER") >= 0) || {(_upper find "DPICM") >= 0};

                    if (_isCluster) then {
                        if (_available > _bestClusterCount) then {
                            _bestClusterCount = _available;
                            _bestClusterAmmo = _ammoClass;
                        };
                    } else {
                        if (_available > _bestRegularCount) then {
                            _bestRegularCount = _available;
                            _bestRegularAmmo = _ammoClass;
                        };
                    };

                    if (_ammoClass == _clusterExact) then {
                        _exactClusterCount = _available;
                    };
                } forEach _ammoOptions;

                private _useClusterHeavy = (_threatLevel isEqualTo "heavy") && {_forceCluster};
                private _bestAmmo = _bestOverallAmmo;
                private _bestCount = _bestOverallCount;

                if (_useClusterHeavy) then {
                    if (_exactClusterCount > 0) then {
                        _bestAmmo = _clusterExact;
                        _bestCount = _exactClusterCount;
                    } else {
                        diag_log format ["[OPFCOM] Heavy armour mission cancelled: required cluster ammo %1 unavailable on %2", _clusterExact, typeOf _gun];
                        false
                    };
                    if (_exactClusterCount <= 0) exitWith {false};
                } else {
                    if (_bestRegularAmmo != "") then {
                        _bestAmmo = _bestRegularAmmo;
                        _bestCount = _bestRegularCount;
                    };
                };

                private _toFire = if (_bestCount > 0) then { _rounds min _bestCount } else { _rounds };
                if (_toFire <= 0) exitWith {false};

                private _remaining = _toFire;
                while {_remaining > 0} do {
                    private _batch = _remaining min 2;
                    private _rndPos = [
                        (_targetPos select 0) + (random (_spread * 2) - _spread),
                        (_targetPos select 1) + (random (_spread * 2) - _spread),
                        0
                    ];

                    // Avoid parser/runtime edge-cases with temporary boolean scope.
                    if !(_gun doArtilleryFire [_rndPos, _bestAmmo, _batch]) then {
                        _gun commandArtilleryFire [_rndPos, _bestAmmo, _batch];
                    };

                    _remaining = _remaining - _batch;
                    sleep 6;
                };

                true
            };
        };

        if (isNil "OPFCOM_fnc_deleteSupportAssets") then {
            OPFCOM_fnc_deleteSupportAssets = {
                params ["_grp", "_spawnedUnits", "_gun"];

                {
                    if (!isNull _x) then { deleteVehicle _x; };
                } forEach _spawnedUnits;

                if (!isNull _grp) then { deleteGroup _grp; };

                if (!isNull _gun) then {
                    deleteVehicleCrew _gun;
                    deleteVehicle _gun;

                    {
                        if ((OPFCOM_hqArtillery get _x) isEqualTo _gun) then {
                            OPFCOM_hqArtillery deleteAt _x;
                        };
                    } forEach (keys OPFCOM_hqArtillery);

                    publicVariable "OPFCOM_hqArtillery";
                };
            };
        };

        if (isNil "OPFCOM_fnc_scheduleCrewCleanup") then {
            OPFCOM_fnc_scheduleCrewCleanup = {
                params ["_grp", "_spawnedUnits", "_gun", ["_delay", OPFCOM_crewRetainTime]];

                [_grp, _spawnedUnits, _gun, _delay] spawn {
                    params ["_cGrp", "_cUnits", "_cGun", "_cDelay"];
                    sleep _cDelay;
                    [_cGrp, _cUnits, _cGun] call OPFCOM_fnc_deleteSupportAssets;
                };
            };
        };

        if (isNil "OPFCOM_fnc_executeSupportAction") then {
            OPFCOM_fnc_executeSupportAction = {
                params ["_targetData", "_hqMarker"];

                _targetData params ["_group", "_targetPos", "_lastSeen", "_class", "_size", "_status", "_mix", "_markerName"];
                private _artyClass = [_targetData] call OPFCOM_fnc_selectArtilleryClassForTarget;
                private _fireProfile = [_targetData] call OPFCOM_fnc_getFireProfileForTarget;
                private _isArmourTarget = [_targetData] call OPFCOM_fnc_isArmourTarget;
                _fireProfile params ["_rounds", "_spread", "_threatLevel"];

                if (_artyClass isEqualTo "") exitWith {
                    diag_log format ["[OPFCOM] Skipping artillery mission for air target at marker %1", _markerName];
                    false
                };

                private _gun = [_hqMarker, _artyClass] call OPFCOM_fnc_getOrCreateHQArtillery;
                if (isNull _gun || {!alive _gun}) exitWith {
                    diag_log format ["[OPFCOM] Failed to spawn HQ artillery (%1) at %2", _artyClass, _hqMarker];
                    false
                };

                diag_log format ["[OPFCOM] Support action: HQ=%1, targetClass=%2, size=%3, status=%4, threat=%5, arty=%6, rounds=%7, spread=%8", _hqMarker, _class, _size, _status, _threatLevel, typeOf _gun, _rounds, _spread];

                private _crewData = [_gun] call OPFCOM_fnc_spawnCrewInArtillery;
                _crewData params ["_grp", "_units"];

                if (!isNull _grp && {count _units > 0}) then {
                    sleep 1.5;
                    OPFCOM_lastSupportTier = toUpper _threatLevel;
                    publicVariable "OPFCOM_lastSupportTier";
                    private _fired = [_gun, _targetPos, _rounds, _spread, _threatLevel, _class, _isArmourTarget] call OPFCOM_fnc_fireMission;
                    [_grp, _units, _gun, OPFCOM_crewRetainTime] call OPFCOM_fnc_scheduleCrewCleanup;
                    if (!_fired) exitWith {false};
                };

                true
            };
        };
    };
};

if (isNil "OPFCOM_fnc_execArtyAction") then {
    OPFCOM_fnc_execArtyAction = {
        params ["_sightings"];

        if (isNil "OPFCOM_fnc_updateContactMemory") then {
            [] call OPFCOM_fnc_initArtyAction;
        };

        [_sightings] call OPFCOM_fnc_updateContactMemory;
        [] call OPFCOM_fnc_updateEscalation;

        private _hqMarkers = [] call OPFCOM_fnc_getHQMarkers;
        if ((count _sightings) == 0 || {(count _hqMarkers) == 0}) exitWith {false};

        private _now = time;
        private _cooldownReady = (_now - OPFCOM_lastSupportTime) >= OPFCOM_supportCooldown;
        if (!_cooldownReady) exitWith {false};

        private _target = [_sightings] call OPFCOM_fnc_selectPrimaryTarget;
        if (count _target == 0) exitWith {false};

        private _targetPos = _target select 1;
        private _availableHQMarkers = [] call OPFCOM_fnc_getAvailableHQMarkers;
        private _hqMarker = [_targetPos, _availableHQMarkers] call OPFCOM_fnc_findClosestHQ;
        if (_hqMarker == "") exitWith {false};

        private _success = [_target, _hqMarker] call OPFCOM_fnc_executeSupportAction;
        if (_success) then {
            OPFCOM_lastSupportTime = _now;
            OPFCOM_escalationPoints = OPFCOM_escalationPoints + OPFCOM_escalationIncreaseOnStrike;
            publicVariable "OPFCOM_lastSupportTime";
        };

        _success
    };
};

if (isNil "OPFCOM_fnc_collectSightingsFallback") then {
    OPFCOM_fnc_collectSightingsFallback = {
        private _raw = missionNamespace getVariable ["RECON_OPF_spottedTargets", createHashMap];
        private _list = [];
        private _now = time;

        {
            private _entry = _raw get _x;
            if (!isNil "_entry" && {count _entry >= 3}) then {
                _entry params ["_group", "_markerName", "_lastSeen"];

                if (!isNull _group && {{alive _x} count (units _group) > 0}) then {
                    private _pos = getMarkerPos _markerName;
                    if (_pos distance2D [0, 0, 0] > 0) then {
                        private _class = "unknown";
                        private _size = ({alive _x} count (units _group)) max 1;
                        private _status = "full health";
                        private _mix = [0, 0, 0, 0, 0, 0];

                        if (!isNil "RECON_OPF_fnc_getGroupComposition") then {
                            private _comp = [_group] call RECON_OPF_fnc_getGroupComposition;
                            if (count _comp >= 9) then {
                                _comp params ["_class", "_size", "_status", "_inf", "_sta", "_arm", "_mech", "_air", "_nav"];
                                _mix = [_inf, _sta, _arm, _mech, _air, _nav];
                            };
                        };

                        _list pushBack [_group, _pos, _lastSeen, _class, _size, _status, _mix, _markerName];
                    };
                };
            };
        } forEach (keys _raw);

        _list
    };
};

if (isNil "OPFCOM_fnc_runArtyOnce") then {
    OPFCOM_fnc_runArtyOnce = {
        private _sightings = [];

        if (!isNil "OPFCOM_fnc_collectSightings") then {
            _sightings = [] call OPFCOM_fnc_collectSightings;
        } else {
            _sightings = [] call OPFCOM_fnc_collectSightingsFallback;
        };

        if ((count _sightings) == 0) exitWith {
            diag_log "[OPFCOM][ARTY] No eligible sightings available for standalone artillery run.";
            false
        };

        private _ok = [_sightings] call OPFCOM_fnc_execArtyAction;
        if (_ok) then {
            diag_log "[OPFCOM][ARTY] Standalone artillery run executed.";
        } else {
            diag_log "[OPFCOM][ARTY] Standalone artillery run failed gate checks (cooldown/target/HQ).";
        };
        _ok
    };
};

[] call OPFCOM_fnc_initArtyAction;

// Compatibility mode: if this file is launched directly with execVM,
// attempt one immediate artillery action. When loaded via preprocess/compile,
// canSuspend is false, so no automatic fire attempt is made.
if (canSuspend) then {
    [] spawn {
        sleep 0.1;
        [] call OPFCOM_fnc_runArtyOnce;
    };
};
