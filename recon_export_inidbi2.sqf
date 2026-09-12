/*
 * recon_export_inidbi2.sqf
 *
 * INIDBI2 export helper for recon_intelligence_opf.sqf.
 * Exposes RECON_OPF_fnc_exportToIniDBI2, which writes current recon snapshot
 * into an INIDBI2 database file.
 *
 * Requires INIDBI2 and OO_INIDBI to be loaded by the server.
 */

if (!isServer) exitWith {};

if (isNil "RECON_OPF_export_dbName") then { RECON_OPF_export_dbName = "TWS_BattleIntel"; };
if (isNil "RECON_OPF_export_sectionMeta") then { RECON_OPF_export_sectionMeta = "Meta"; };
if (isNil "RECON_OPF_export_sectionTargets") then { RECON_OPF_export_sectionTargets = "Targets"; };
if (isNil "RECON_OPF_export_sectionTargetStats") then { RECON_OPF_export_sectionTargetStats = "TargetStats"; };
if (isNil "RECON_OPF_export_lastWritten") then { RECON_OPF_export_lastWritten = createHashMap; };
if (isNil "RECON_OPF_export_knownTargetKeys") then { RECON_OPF_export_knownTargetKeys = []; };

RECON_OPF_fnc_exportTypeFromMarkerText = {
    params ["_markerText"];

    private _text = toLower _markerText;
    if (_text find "combined arms" > -1) exitWith {"combined arms"};
    if (_text find "air assault" > -1) exitWith {"air assault"};
    if (_text find "mech infantry" > -1) exitWith {"mech infantry"};
    if (_text find "armour-mech" > -1) exitWith {"armour-mech"};
    if (_text find "armour" > -1) exitWith {"armour"};
    if (_text find "mech" > -1) exitWith {"mech"};
    if (_text find "air" > -1) exitWith {"air"};
    if (_text find "naval" > -1) exitWith {"naval"};
    if (_text find "static support" > -1) exitWith {"static support"};
    if (_text find "static" > -1) exitWith {"static"};
    if (_text find "infantry" > -1) exitWith {"infantry"};
    "unknown"
};

RECON_OPF_fnc_exportInitIniDB = {
    if (!isNil "RECON_OPF_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        diag_log "[RECON][EXPORT] OO_INIDBI not found. INIDBI2 export disabled.";
        false
    };

    RECON_OPF_iniDB = ["new", RECON_OPF_export_dbName] call OO_INIDBI;

    if (isNil "RECON_OPF_iniDB") exitWith {
        diag_log format ["[RECON][EXPORT] Failed to open INIDBI2 DB: %1", RECON_OPF_export_dbName];
        false
    };

    diag_log format ["[RECON][EXPORT] INIDBI2 DB ready: %1", RECON_OPF_export_dbName];
    true
};

RECON_OPF_fnc_exportWrite = {
    params ["_section", "_key", "_value"];

    if (isNil "RECON_OPF_iniDB") exitWith {false};

    private _cacheKey = format ["%1|%2", _section, _key];
    private _newValue = str _value;
    private _oldValue = RECON_OPF_export_lastWritten getOrDefault [_cacheKey, "<nil>"];
    if (_newValue isEqualTo _oldValue) exitWith {false};

    ["write", [_section, _key, _value]] call RECON_OPF_iniDB;
    RECON_OPF_export_lastWritten set [_cacheKey, _newValue];
    true
};

RECON_OPF_fnc_exportToIniDBI2 = {
    private _ready = [] call RECON_OPF_fnc_exportInitIniDB;
    if (!_ready) exitWith {false};

    private _targets = missionNamespace getVariable ["RECON_OPF_spottedTargets", createHashMap];
    private _keys = keys _targets;
    private _now = time;
    private _cycleId = round (_now * 10);

    // Meta section for external readers.
    [RECON_OPF_export_sectionMeta, "LastExportTime", _now] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "TargetCount", count _keys] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "ActiveGroupKeys", str _keys] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "ExportCycle", _cycleId] call RECON_OPF_fnc_exportWrite;

    {
        private _targetKey = _x;
        private _entry = _targets get _targetKey;

        if (!isNil "_entry" && {count _entry >= 3}) then {
            _entry params ["_group", "_markerName", "_lastSeen"];

            private _groupSize = if (!isNull _group) then {{alive _x} count (units _group)} else {0};
            private _markerPos = getMarkerPos _markerName;
            private _markerDir = markerDir _markerName;
            private _markerText = markerText _markerName;
            private _sideName = if (!isNull _group) then {str (side _group)} else {"UNKNOWN"};

            private _classification = "unknown";
            private _status = "unknown";
            private _comp = [0,0,0,0,0,0];

            private _allUnits = if (!isNull _group) then {units _group} else {[]};
            private _totalUnits = count _allUnits;
            private _aliveUnits = _allUnits select {alive _x};
            private _aliveCount = count _aliveUnits;
            private _casualties = (_totalUnits - _aliveCount) max 0;
            private _woundedAlive = {damage _x > 0.25} count _aliveUnits;

            private _avgHealthPct = 0;
            if (_aliveCount > 0) then {
                private _sumHealth = 0;
                {
                    _sumHealth = _sumHealth + (1 - damage _x);
                } forEach _aliveUnits;
                _avgHealthPct = round (((_sumHealth / _aliveCount) max 0 min 1) * 100);
            };

            private _strengthPct = 0;
            if (_totalUnits > 0) then {
                _strengthPct = round ((_aliveCount / _totalUnits) * 100);
            };

            private _strengthLabel = "combat ineffective";
            if (_strengthPct >= 80) then {
                _strengthLabel = "combat effective";
            } else {
                if (_strengthPct >= 50) then {
                    _strengthLabel = "degraded";
                };
            };

            if (!isNull _group && {!isNil "RECON_OPF_fnc_getGroupComposition"}) then {
                private _gc = [_group] call RECON_OPF_fnc_getGroupComposition;
                if (count _gc >= 9) then {
                    _gc params ["_classification", "_sz", "_status", "_inf", "_sta", "_arm", "_mech", "_air", "_nav"];
                    _comp = [_inf, _sta, _arm, _mech, _air, _nav];
                };
            };

            if (_classification isEqualTo "unknown") then {
                _classification = [_markerText] call RECON_OPF_fnc_exportTypeFromMarkerText;
            };

            private _record = [
                _targetKey,
                _markerName,
                _markerPos,
                _markerDir,
                _markerText,
                _lastSeen,
                _groupSize,
                _classification,
                _status,
                _comp,
                _sideName
            ];

            [RECON_OPF_export_sectionTargets, _targetKey, str _record] call RECON_OPF_fnc_exportWrite;

            // Detailed stats for external readers who need direct squad fields.
            private _statsPrefix = _targetKey + "_";
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadSizeAlive", _aliveCount] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadSizeTotal", _totalUnits] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadCasualties", _casualties] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadType", _classification] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadHealthStatus", _status] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadWoundedAlive", _woundedAlive] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadAvgHealthPct", _avgHealthPct] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadStrengthPct", _strengthPct] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadStrengthLabel", _strengthLabel] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "MarkerText", _markerText] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "LastSeen", _lastSeen] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "Cycle", _cycleId] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "InfantryCount", _comp select 0] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "StaticCount", _comp select 1] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "ArmourCount", _comp select 2] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "MechCount", _comp select 3] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "AirCount", _comp select 4] call RECON_OPF_fnc_exportWrite;
            [RECON_OPF_export_sectionTargetStats, _statsPrefix + "NavalCount", _comp select 5] call RECON_OPF_fnc_exportWrite;
        };
    } forEach _keys;

    RECON_OPF_export_knownTargetKeys = +_keys;

    true
};

RECON_OPF_fnc_exportClearOnScenarioEnd = {
    private _ready = [] call RECON_OPF_fnc_exportInitIniDB;
    if (!_ready) exitWith {false};

    private _knownKeys = missionNamespace getVariable ["RECON_OPF_export_knownTargetKeys", []];

    {
        private _targetKey = _x;
        private _statsPrefix = _targetKey + "_";

        [RECON_OPF_export_sectionTargets, _targetKey, ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadSizeAlive", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadSizeTotal", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadCasualties", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadType", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadHealthStatus", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadWoundedAlive", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadAvgHealthPct", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadStrengthPct", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "SquadStrengthLabel", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "MarkerText", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "LastSeen", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "Cycle", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "InfantryCount", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "StaticCount", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "ArmourCount", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "MechCount", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "AirCount", ""] call RECON_OPF_fnc_exportWrite;
        [RECON_OPF_export_sectionTargetStats, _statsPrefix + "NavalCount", ""] call RECON_OPF_fnc_exportWrite;
    } forEach _knownKeys;

    RECON_OPF_export_knownTargetKeys = [];
    RECON_OPF_export_lastWritten = createHashMap;

    [RECON_OPF_export_sectionMeta, "LastExportTime", -1] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "TargetCount", 0] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "ActiveGroupKeys", "[]"] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "ExportCycle", -1] call RECON_OPF_fnc_exportWrite;
    [RECON_OPF_export_sectionMeta, "ScenarioClosed", 1] call RECON_OPF_fnc_exportWrite;

    diag_log "[RECON][EXPORT] INIDBI2 recon data cleared for scenario end.";
    true
};
