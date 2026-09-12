/*
 * resource_export_inidbi2.sqf
 *
 * Exports faction resources from basicResources.sqf to INIDBI2 every 60 seconds
 * for external monitoring apps.
 */

if (!isServer) exitWith {};

if (isNil "TWS_RES_export_dbName") then { TWS_RES_export_dbName = "TWS_LogisticsIntel"; };
if (isNil "TWS_RES_export_sectionMeta") then { TWS_RES_export_sectionMeta = "ResourceMeta"; };
if (isNil "TWS_RES_export_sectionData") then { TWS_RES_export_sectionData = "Resources"; };
if (isNil "TWS_RES_export_interval") then { TWS_RES_export_interval = 60; };
if (isNil "TWS_RES_export_running") then { TWS_RES_export_running = false; };
if (isNil "TWS_RES_export_cycle") then { TWS_RES_export_cycle = 0; };

TWS_RES_fnc_initIniDB = {
    if (!isNil "TWS_RES_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        diag_log "[TWS_RES_EXPORT] OO_INIDBI not found. Resource export disabled.";
        false
    };

    TWS_RES_iniDB = ["new", TWS_RES_export_dbName] call OO_INIDBI;
    if (isNil "TWS_RES_iniDB") exitWith {
        diag_log format ["[TWS_RES_EXPORT] Failed to open INIDBI2 DB: %1", TWS_RES_export_dbName];
        false
    };

    true
};

TWS_RES_fnc_write = {
    params ["_section", "_key", "_value"];
    if (isNil "TWS_RES_iniDB") exitWith {false};
    ["write", [_section, _key, _value]] call TWS_RES_iniDB;
    true
};

TWS_RES_fnc_getFactionResources = {
    params ["_faction"];

    if (isNil "RES_factionResources") exitWith {[0, 0, 0, 0, 0]};
    RES_factionResources getOrDefault [_faction, [0, 0, 0, 0, 0]]
};

if (TWS_RES_export_running) exitWith {
    diag_log "[TWS_RES_EXPORT] Resource exporter already running";
};

TWS_RES_export_running = true;
publicVariable "TWS_RES_export_running";

[] spawn {
    diag_log "[TWS_RES_EXPORT] Resource exporter started";

    while {TWS_RES_export_running} do {
        private _ready = [] call TWS_RES_fnc_initIniDB;
        if (_ready) then {
            private _factions = ["BLUFOR", "OPFOR"];
            if (!isNil "RES_factionResources") then {
                private _keys = keys RES_factionResources;
                if ((count _keys) > 0) then {
                    _factions = _keys;
                };
            };

            private _activeFactions = [];
            {
                private _faction = _x;
                private _res = [_faction] call TWS_RES_fnc_getFactionResources;

                private _fuel = _res param [0, 0];
                private _supplies = _res param [1, 0];
                private _fabrication = _res param [2, 0];
                private _manpower = _res param [3, 0];
                private _electricity = _res param [4, 0];

                private _record = [_fuel, _supplies, _fabrication, _manpower, _electricity, time];
                [TWS_RES_export_sectionData, _faction, str _record] call TWS_RES_fnc_write;
                _activeFactions pushBack _faction;
            } forEach _factions;

            TWS_RES_export_cycle = TWS_RES_export_cycle + 1;

            [TWS_RES_export_sectionMeta, "LastExportTime", time] call TWS_RES_fnc_write;
            [TWS_RES_export_sectionMeta, "UpdateInterval", TWS_RES_export_interval] call TWS_RES_fnc_write;
            [TWS_RES_export_sectionMeta, "FactionCount", count _activeFactions] call TWS_RES_fnc_write;
            [TWS_RES_export_sectionMeta, "ActiveFactions", str _activeFactions] call TWS_RES_fnc_write;
            [TWS_RES_export_sectionMeta, "ExportCycle", TWS_RES_export_cycle] call TWS_RES_fnc_write;
            [TWS_RES_export_sectionMeta, "ScenarioClosed", 0] call TWS_RES_fnc_write;
        };

        sleep TWS_RES_export_interval;
    };

    diag_log "[TWS_RES_EXPORT] Resource exporter stopped";
};

if (isNil "TWS_RES_export_endMissionEH") then {
    TWS_RES_export_endMissionEH = addMissionEventHandler ["Ended", {
        TWS_RES_export_running = false;
        if (!isNil "TWS_RES_iniDB") then {
            ["write", [TWS_RES_export_sectionMeta, "ScenarioClosed", 1]] call TWS_RES_iniDB;
        };
    }];
};

publicVariable "TWS_RES_export_interval";
publicVariable "TWS_RES_export_running";
