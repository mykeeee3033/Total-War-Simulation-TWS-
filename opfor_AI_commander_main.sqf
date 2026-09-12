/*
 * opfor_AI_commander_main.sqf
 *
 * OPFOR commander logic shell:
 * 1) Consume recon intel from recon_intelligence_opf.sqf
 * 2) Decide which commander actions should execute this cycle
 * 3) Dispatch executable action scripts/functions
 */

if (!isServer) exitWith {
    diag_log "[OPFCOM] Script runs on server only";
};

if (isNil "OPFCOM_enabled") then { OPFCOM_enabled = true; };
if (isNil "OPFCOM_running") then { OPFCOM_running = false; };
if (isNil "OPFCOM_loopInterval") then { OPFCOM_loopInterval = 60; };
if (isNil "OPFCOM_cachedSightings") then { OPFCOM_cachedSightings = createHashMap; };
if (isNil "OPFCOM_intelMaxAge") then { OPFCOM_intelMaxAge = 120; };
if (isNil "OPFCOM_cycleCounter") then { OPFCOM_cycleCounter = 0; };
if (isNil "OPFCOM_forceSupportForTesting") then { OPFCOM_forceSupportForTesting = true; };
if (isNil "OPFCOM_supportStatusCooldownSeconds") then { OPFCOM_supportStatusCooldownSeconds = 20; };
if (isNil "OPFCOM_lastSupportExecutedAt") then { OPFCOM_lastSupportExecutedAt = -9999; };
if (isNil "OPFCOM_lastSupportEventGameTime") then { OPFCOM_lastSupportEventGameTime = -9999; };
if (isNil "OPFCOM_lastLogisticsEventGameTime") then { OPFCOM_lastLogisticsEventGameTime = -9999; };
if (isNil "OPFCOM_cycleEndSystemTimeUTC") then { OPFCOM_cycleEndSystemTimeUTC = []; };

// Commander action toggles
if (isNil "OPFCOM_action_logistics_enabled") then { OPFCOM_action_logistics_enabled = true; };
if (isNil "OPFCOM_action_arty_enabled") then { OPFCOM_action_arty_enabled = true; };
if (isNil "OPFCOM_action_resupply_enabled") then { OPFCOM_action_resupply_enabled = false; };
if (isNil "OPFCOM_action_resupply_started") then { OPFCOM_action_resupply_started = false; };
if (isNil "OPFCOM_action_airportLogi_started") then { OPFCOM_action_airportLogi_started = false; };

// Load artillery executable once; this defines OPFCOM_fnc_execArtyAction.
call compile preprocessFileLineNumbers "opfor_commander_action_arty.sqf";
call compile preprocessFileLineNumbers "opfor_commander_export_inidbi2.sqf";

if (OPFCOM_forceSupportForTesting) then {
    OPFCOM_supportCooldown = 0;
    OPFCOM_minContactPersistence = 0;
    OPFCOM_baseScoreThreshold = 0;
    OPFCOM_requireLossesForIndirect = false;
    diag_log "[OPFCOM] Testing mode active: artillery gates relaxed (cooldown/persistence/threshold/loss-trigger).";
};

if (isNil "OPFCOM_export_endMissionEH") then {
    OPFCOM_export_endMissionEH = addMissionEventHandler ["Ended", {
        if (!isNil "OPFCOM_fnc_exportClearCyclePlan") then {
            [] call OPFCOM_fnc_exportClearCyclePlan;
        };
    }];
};

OPFCOM_fnc_collectSightings = {
    private _raw = missionNamespace getVariable ["RECON_OPF_spottedTargets", createHashMap];
    private _normalized = createHashMap;
    private _list = [];
    private _now = time;

    {
        private _key = _x;
        private _entry = _raw get _key;

        if (!isNil "_entry" && {count _entry >= 3}) then {
            _entry params ["_group", "_markerName", "_lastSeen"];

            if (!isNull _group && {{alive _x} count (units _group) > 0}) then {
                private _pos = getMarkerPos _markerName;
                if (_pos distance2D [0, 0, 0] > 0 && {(_now - _lastSeen) <= OPFCOM_intelMaxAge}) then {
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

                    private _norm = [_group, _pos, _lastSeen, _class, _size, _status, _mix, _markerName];
                    _normalized set [_key, _norm];
                    _list pushBack _norm;
                };
            };
        };
    } forEach (keys _raw);

    OPFCOM_cachedSightings = _normalized;
    publicVariable "OPFCOM_cachedSightings";

    _list
};

OPFCOM_fnc_hasDepotSupplies = {
    params ["_depotPos", ["_radius", 200]];

    private _supplyClasses = [
        "O_supplyCrate_F",
        "CargoNet_01_box_F",
        "Box_East_Ammo_F",
        "Box_East_Wps_F"
    ];

    private _supplyObjects = [];
    {
        _supplyObjects append (_depotPos nearObjects [_x, _radius]);
    } forEach _supplyClasses;

    (count _supplyObjects) > 0
};

OPFCOM_fnc_decideLogisticsActions = {
    private _actions = [];

    if (!OPFCOM_action_logistics_enabled) exitWith {_actions};

    private _depotPos = getMarkerPos "cargo_depot_o";
    private _hasSupplies = [_depotPos, 200] call OPFCOM_fnc_hasDepotSupplies;

    if (!_hasSupplies && {!OPFCOM_action_airportLogi_started}) then {
        _actions pushBack "START_AIRPORT_LOGI";
    } else {
        if (_hasSupplies) then {
            _actions pushBack "START_RESUPPLY_LOOP";
        };
    };

    _actions
};

OPFCOM_fnc_decideCombatSupportActions = {
    params ["_sightings"];

    private _actions = [];
    private _hqAvailableCount = count ([] call OPFCOM_fnc_getAvailableHQMarkers);

    // Current combat support integration: artillery is the only enabled support
    // executable, so when valid intel exists the commander can choose it here.
    if (
        OPFCOM_action_arty_enabled &&
        {!isNil "OPFCOM_fnc_execArtyAction"} &&
        {(count _sightings) > 0} &&
        {_hqAvailableCount > 0}
    ) then {
        _actions pushBack "ARTY_SUPPORT";
    };

    _actions
};

OPFCOM_fnc_decideActions = {
    params ["_sightings"];

    private _cyclePlan = createHashMapFromArray [
        ["SUPPLY_LOGISTICS", []],
        ["COMBAT_SUPPORT", []],
        ["MOBILIZATION", []],
        ["TROOP_MOVEMENTS", []],
        ["OFFENSIVE_OPERATIONS", []],
        ["DEFENSIVE_OPERATIONS", []],
        ["STRATEGIC_OPERATIONS", []],
        ["RECOVERY_RECONSTITUTION", []],
        ["RESERVE_MANAGEMENT", []],
        ["NO_ACTION_CONDITIONS", []]
    ];

    private _hasSightings = (count _sightings) > 0;
    private _logisticsActions = [] call OPFCOM_fnc_decideLogisticsActions;
    private _combatSupportActions = [_sightings] call OPFCOM_fnc_decideCombatSupportActions;

    // 1. SUPPLY / LOGISTICS
    (_cyclePlan get "SUPPLY_LOGISTICS") append _logisticsActions;

    // 2. COMBAT SUPPORT
    (_cyclePlan get "COMBAT_SUPPORT") append _combatSupportActions;

    // 3. MOBILIZATION
    // Placeholder for future mobilization executables.

    // 4. TROOP MOVEMENTS
    // Placeholder for future troop movement executables.

    // 5. OFFENSIVE OPERATIONS
    // Placeholder for future offensive executables.

    // 6. DEFENSIVE OPERATIONS
    // Placeholder for future defensive executables.

    // 7. STRATEGIC OPERATIONS
    // Placeholder for future strategic executables.

    // 8. RECOVERY / RECONSTITUTION
    // Placeholder for future recovery executables.

    // 9. RESERVE MANAGEMENT
    // Placeholder for future reserve executables.

    // 10. NO ACTION CONDITIONS
    if (!_hasSightings && {!OPFCOM_action_logistics_enabled}) then {
        (_cyclePlan get "NO_ACTION_CONDITIONS") pushBack "HOLD";
    };

    _cyclePlan
};

OPFCOM_fnc_executeActions = {
    params ["_cyclePlan", "_sightings"];

    private _results = createHashMapFromArray [
        ["START_AIRPORT_LOGI", false],
        ["ARTY_SUPPORT", false],
        ["START_RESUPPLY_LOOP", false]
    ];

    private _categoryOrder = [
        "SUPPLY_LOGISTICS",
        "COMBAT_SUPPORT",
        "MOBILIZATION",
        "TROOP_MOVEMENTS",
        "OFFENSIVE_OPERATIONS",
        "DEFENSIVE_OPERATIONS",
        "STRATEGIC_OPERATIONS",
        "RECOVERY_RECONSTITUTION",
        "RESERVE_MANAGEMENT",
        "NO_ACTION_CONDITIONS"
    ];

    {
        private _category = _x;
        private _actions = _cyclePlan getOrDefault [_category, []];

        {
            switch (_x) do {
                case "START_AIRPORT_LOGI": {
                    OPFCOM_action_airportLogi_started = true;
                    _results set ["START_AIRPORT_LOGI", true];
                    [] execVM "airport_logi_opfor.sqf";
                    OPFCOM_lastLogisticsEventGameTime = time;
                    diag_log "[OPFCOM] Started airport logistics executable: airport_logi_opfor.sqf";
                };

                case "ARTY_SUPPORT": {
                    if (!isNil "OPFCOM_fnc_execArtyAction") then {
                        private _didFire = [_sightings] call OPFCOM_fnc_execArtyAction;
                        _results set ["ARTY_SUPPORT", _didFire];
                        if (_didFire) then {
                            OPFCOM_lastSupportExecutedAt = time;
                            OPFCOM_lastSupportEventGameTime = time;
                            diag_log "[OPFCOM] ARTY_SUPPORT executed this cycle.";
                        } else {
                            diag_log "[OPFCOM] ARTY_SUPPORT evaluated but did not fire this cycle.";
                        };
                    };
                };

                case "START_RESUPPLY_LOOP": {
                    OPFCOM_action_resupply_started = true;
                    _results set ["START_RESUPPLY_LOOP", true];
                    [true] execVM "s_opfor_resuply_heli_SIMPLE.sqf";
                    OPFCOM_lastLogisticsEventGameTime = time;
                    diag_log "[OPFCOM] Triggered cycle resupply scan: s_opfor_resuply_heli_SIMPLE.sqf (single-pass)";
                };

                case "HOLD": {
                    diag_log format ["[OPFCOM] No action this cycle (%1)", _category];
                };
            };
        } forEach _actions;
    } forEach _categoryOrder;

    _results
};

OPFCOM_fnc_logCycleSummary = {
    params ["_cyclePlan"];

    private _summary = [];
    {
        private _actions = _cyclePlan getOrDefault [_x, []];
        if ((count _actions) > 0) then {
            _summary pushBack format ["%1=%2", _x, _actions];
        };
    } forEach [
        "SUPPLY_LOGISTICS",
        "COMBAT_SUPPORT",
        "MOBILIZATION",
        "TROOP_MOVEMENTS",
        "OFFENSIVE_OPERATIONS",
        "DEFENSIVE_OPERATIONS",
        "STRATEGIC_OPERATIONS",
        "RECOVERY_RECONSTITUTION",
        "RESERVE_MANAGEMENT",
        "NO_ACTION_CONDITIONS"
    ];

    diag_log format ["[OPFCOM] Cycle plan: %1", _summary];
};

OPFCOM_fnc_getSupportStateActionId = {
    params ["_cyclePlan", "_sightings", "_executionResults"];

    private _now = time;
    private _artyExecuted = _executionResults getOrDefault ["ARTY_SUPPORT", false];
    private _hasArtyPlanned = "ARTY_SUPPORT" in (_cyclePlan getOrDefault ["COMBAT_SUPPORT", []]);
    private _inCooldown = (_now - OPFCOM_lastSupportExecutedAt) < OPFCOM_supportStatusCooldownSeconds;
    private _supportTier = toUpper (missionNamespace getVariable ["OPFCOM_lastSupportTier", "NONE"]);

    if (_artyExecuted) exitWith {
        if (_supportTier in ["LIGHT", "MEDIUM", "HEAVY"]) then {
            format ["ARTY_SUPPORT_%1_REQUESTED", _supportTier]
        } else {
            "ARTY_SUPPORT_REQUESTED"
        }
    };
    if (_hasArtyPlanned && {(count _sightings) > 0}) exitWith {"ARTY_SUPPORT_REQUESTED"};
    "SUPPORT_NONE"
};

OPFCOM_fnc_buildExportPlan = {
    params ["_cyclePlan", "_supportStateActionId"];

    private _exportPlan = createHashMap;
    {
        _exportPlan set [_x, +(_cyclePlan getOrDefault [_x, []])];
    } forEach [
        "SUPPLY_LOGISTICS",
        "COMBAT_SUPPORT",
        "MOBILIZATION",
        "TROOP_MOVEMENTS",
        "OFFENSIVE_OPERATIONS",
        "DEFENSIVE_OPERATIONS",
        "STRATEGIC_OPERATIONS",
        "RECOVERY_RECONSTITUTION",
        "RESERVE_MANAGEMENT",
        "NO_ACTION_CONDITIONS"
    ];

    _exportPlan set ["COMBAT_SUPPORT", [_supportStateActionId]];
    _exportPlan
};

if (OPFCOM_running) exitWith {
    diag_log "[OPFCOM] Commander loop already running";
};

OPFCOM_running = true;
publicVariable "OPFCOM_running";

[] spawn {
    diag_log "[OPFCOM] OPFOR AI commander logic started";
    systemChat "[OPFCOM] OPFOR AI commander logic online";

    while {OPFCOM_enabled} do {
        OPFCOM_cycleCounter = OPFCOM_cycleCounter + 1;
        private _sightings = [] call OPFCOM_fnc_collectSightings;
        private _cyclePlan = [_sightings] call OPFCOM_fnc_decideActions;
        [_cyclePlan] call OPFCOM_fnc_logCycleSummary;
        private _executionResults = [_cyclePlan, _sightings] call OPFCOM_fnc_executeActions;

        private _supportStateActionId = [_cyclePlan, _sightings, _executionResults] call OPFCOM_fnc_getSupportStateActionId;
        if (_supportStateActionId isEqualTo "ARTY_SUPPORT_REQUESTED") then {
            OPFCOM_lastSupportEventGameTime = time;
        };
        private _logisticsEventGameTime = OPFCOM_lastLogisticsEventGameTime;
        private _exportPlan = [_cyclePlan, _supportStateActionId] call OPFCOM_fnc_buildExportPlan;
        OPFCOM_cycleEndSystemTimeUTC = systemTimeUTC;
        publicVariable "OPFCOM_cycleEndSystemTimeUTC";

        if (!isNil "OPFCOM_fnc_exportCyclePlan") then {
            [_exportPlan, OPFCOM_cycleCounter, count _sightings, OPFCOM_loopInterval, _supportStateActionId, OPFCOM_cycleEndSystemTimeUTC, OPFCOM_lastSupportEventGameTime, _logisticsEventGameTime] call OPFCOM_fnc_exportCyclePlan;
        };

        sleep OPFCOM_loopInterval;
    };

    if (!isNil "OPFCOM_fnc_exportClearCyclePlan") then {
        [] call OPFCOM_fnc_exportClearCyclePlan;
    };
    OPFCOM_running = false;
    publicVariable "OPFCOM_running";
    diag_log "[OPFCOM] OPFOR AI commander logic stopped";
};

publicVariable "OPFCOM_enabled";
publicVariable "OPFCOM_loopInterval";
publicVariable "OPFCOM_cachedSightings";
publicVariable "OPFCOM_intelMaxAge";
publicVariable "OPFCOM_cycleCounter";
publicVariable "OPFCOM_action_arty_enabled";
publicVariable "OPFCOM_action_resupply_enabled";
publicVariable "OPFCOM_forceSupportForTesting";
publicVariable "OPFCOM_supportStatusCooldownSeconds";
publicVariable "OPFCOM_lastSupportExecutedAt";
publicVariable "OPFCOM_lastSupportEventGameTime";
publicVariable "OPFCOM_lastLogisticsEventGameTime";
publicVariable "OPFCOM_cycleEndSystemTimeUTC";
