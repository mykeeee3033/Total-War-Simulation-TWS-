/*
 * opfor_commander_export_inidbi2.sqf
 *
 * INIDBI2 export helper for opfor_AI_commander_main.sqf.
 * Writes commander cycle metadata and selected actions into the same
 * TWS_ReconIntel database used by the recon viewer.
 */

if (!isServer) exitWith {};

if (isNil "OPFCOM_export_dbName") then { OPFCOM_export_dbName = "TWS_CommanderIntel"; };
if (isNil "OPFCOM_export_sectionMeta") then { OPFCOM_export_sectionMeta = "CommanderMeta"; };
if (isNil "OPFCOM_export_sectionActions") then { OPFCOM_export_sectionActions = "CommanderActions"; };
if (isNil "OPFCOM_export_lastWritten") then { OPFCOM_export_lastWritten = createHashMap; };

OPFCOM_fnc_exportInitIniDB = {
    if (!isNil "OPFCOM_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        diag_log "[OPFCOM][EXPORT] OO_INIDBI not found. Commander export disabled.";
        false
    };

    OPFCOM_iniDB = ["new", OPFCOM_export_dbName] call OO_INIDBI;

    if (isNil "OPFCOM_iniDB") exitWith {
        diag_log format ["[OPFCOM][EXPORT] Failed to open INIDBI2 DB: %1", OPFCOM_export_dbName];
        false
    };

    diag_log format ["[OPFCOM][EXPORT] INIDBI2 DB ready: %1", OPFCOM_export_dbName];
    true
};

OPFCOM_fnc_exportWrite = {
    params ["_section", "_key", "_value"];

    if (isNil "OPFCOM_iniDB") exitWith {false};

    private _cacheKey = format ["%1|%2", _section, _key];
    private _newValue = str _value;
    private _oldValue = OPFCOM_export_lastWritten getOrDefault [_cacheKey, "<nil>"];
    if (_newValue isEqualTo _oldValue) exitWith {false};

    ["write", [_section, _key, _value]] call OPFCOM_iniDB;
    OPFCOM_export_lastWritten set [_cacheKey, _newValue];
    true
};

OPFCOM_fnc_exportActionLabel = {
    params ["_actionId"];

    switch (_actionId) do {
        case "START_AIRPORT_LOGI": {"AIRPORT LOGISTICS REQUESTED"};
        case "START_RESUPPLY_LOOP": {"RESUPPLY REQUESTED"};
        case "ARTY_SUPPORT_LIGHT_REQUESTED": {"ARTILLERY SUPPORT (LIGHT) REQUESTED"};
        case "ARTY_SUPPORT_MEDIUM_REQUESTED": {"ARTILLERY SUPPORT (MEDIUM) REQUESTED"};
        case "ARTY_SUPPORT_HEAVY_REQUESTED": {"ARTILLERY SUPPORT (HEAVY) REQUESTED"};
        case "ARTY_SUPPORT_REQUESTED": {"ARTILLERY SUPPORT REQUESTED"};
        case "SUPPORT_NONE": {"NONE"};
        case "HOLD": {"HOLD"};
        default {_actionId};
    };
};

OPFCOM_fnc_exportActionsForCategory = {
    params ["_actions"];

    if ((count _actions) == 0) exitWith {"NONE"};

    private _labels = [];
    {
        _labels pushBack ([_x] call OPFCOM_fnc_exportActionLabel);
    } forEach _actions;

    _labels joinString ", "
};

OPFCOM_fnc_exportCyclePlan = {
    params ["_cyclePlan", "_cycleIndex", "_sightingsCount", "_loopInterval", ["_supportStateActionId", "SUPPORT_NONE"], ["_cycleEndUtc", []], ["_supportEventGameTime", -1], ["_logisticsEventGameTime", -1]];

    private _ready = [] call OPFCOM_fnc_exportInitIniDB;
    if (!_ready) exitWith {false};

    private _categoryPairs = [
        ["SUPPLY_LOGISTICS", "LOGISTICS"],
        ["COMBAT_SUPPORT", "SUPPORT"],
        ["MOBILIZATION", "MOBILIZATION"],
        ["TROOP_MOVEMENTS", "MOVEMENTS"],
        ["OFFENSIVE_OPERATIONS", "OFFENSIVE"],
        ["DEFENSIVE_OPERATIONS", "DEFENSIVE"],
        ["STRATEGIC_OPERATIONS", "STRATEGIC"],
        ["RECOVERY_RECONSTITUTION", "RECOVERY"],
        ["RESERVE_MANAGEMENT", "RESERVES"],
        ["NO_ACTION_CONDITIONS", "NO_ACTION"]
    ];

    [OPFCOM_export_sectionMeta, "CycleIndex", _cycleIndex] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LoopInterval", _loopInterval] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "SightingsCount", _sightingsCount] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastCycleGameTime", time] call OPFCOM_fnc_exportWrite;
    private _cycleUtcToWrite = if ((count _cycleEndUtc) >= 6) then {_cycleEndUtc} else {systemTimeUTC};
    [OPFCOM_export_sectionMeta, "LastCycleSystemTimeUTC", str _cycleUtcToWrite] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "CycleAnchorSystemTimeUTC", str _cycleUtcToWrite] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "CycleEndSystemTimeUTC", str _cycleUtcToWrite] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "SupportState", [_supportStateActionId] call OPFCOM_fnc_exportActionLabel] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastSupportEventGameTime", _supportEventGameTime] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastLogisticsEventGameTime", _logisticsEventGameTime] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "ScenarioClosed", 0] call OPFCOM_fnc_exportWrite;

    {
        _x params ["_planKey", "_exportKey"];
        private _actions = _cyclePlan getOrDefault [_planKey, []];
        private _display = [_actions] call OPFCOM_fnc_exportActionsForCategory;
        [OPFCOM_export_sectionActions, _exportKey, _display] call OPFCOM_fnc_exportWrite;
    } forEach _categoryPairs;

    true
};

OPFCOM_fnc_exportClearCyclePlan = {
    private _ready = [] call OPFCOM_fnc_exportInitIniDB;
    if (!_ready) exitWith {false};

    [OPFCOM_export_sectionMeta, "CycleIndex", 0] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LoopInterval", 0] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "SightingsCount", 0] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastCycleGameTime", -1] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastCycleSystemTimeUTC", "[]"] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "CycleAnchorSystemTimeUTC", "[]"] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "CycleEndSystemTimeUTC", "[]"] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "SupportState", "NONE"] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastSupportEventGameTime", -1] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "LastLogisticsEventGameTime", -1] call OPFCOM_fnc_exportWrite;
    [OPFCOM_export_sectionMeta, "ScenarioClosed", 1] call OPFCOM_fnc_exportWrite;

    {
        [OPFCOM_export_sectionActions, _x, "NONE"] call OPFCOM_fnc_exportWrite;
    } forEach [
        "LOGISTICS",
        "SUPPORT",
        "MOBILIZATION",
        "MOVEMENTS",
        "OFFENSIVE",
        "DEFENSIVE",
        "STRATEGIC",
        "RECOVERY",
        "RESERVES",
        "NO_ACTION"
    ];

    diag_log "[OPFCOM][EXPORT] Commander cycle export cleared.";
    true
};