/*
 * Resource Persistence Loader
 * ----------------------------
 * Restores faction resources saved in a previous session from the
 * INIDBI2 database so progress carries over day-to-day.
 *
 * IMPORTANT - execution order matters:
 * This must run on the server, and it must FINISH before basicResources.sqf
 * starts, otherwise basicResources.sqf's default-init block will run first
 * and RES_factionResources won't be nil anymore by the time this loads,
 * OR (if this runs after) it will overwrite freshly-loaded data with zeros.
 *
 * Because basicResources.sqf only sets defaults "if (isNil RES_factionResources)",
 * the safest pattern is to run this file SYNCHRONOUSLY first, THEN execVM
 * basicResources.sqf. Do this in init.sqf:
 *
 *   if (isServer) then {
 *       call compile preprocessFileLineNumbers "initPersistentResources.sqf";
 *       [] execVM "basicResources.sqf";
 *   };
 *
 * Using "call compile preprocessFileLineNumbers" (not execVM) guarantees
 * this script completes before the next line runs.
 */

if (!isServer) exitWith {};

diag_log "[Resources][PERSIST] Attempting to load saved resource state...";

// These must match the values used in basicResources.sqf exactly
private _dbName      = "TWS_LogisticsIntel";
private _sectionData = "Resources";

RES_factionResources_preloaded = false;

if (isNil "OO_INIDBI") then {
    diag_log "[Resources][PERSIST] OO_INIDBI not found - starting with default resources.";
} else {
    private _db = ["new", _dbName] call OO_INIDBI;

    if (isNil "_db") then {
        diag_log "[Resources][PERSIST] Could not open INIDBI2 database - starting with default resources.";
    } else {
        private _loaded = createHashMap;

        {
            private _faction = _x;

            // NOTE: your export writes with ["write", [_section, _key, str _record]] call RES_iniDB.
            // The symmetrical read call in most INIDBI2 builds is:
            //     ["read", [_section, _key]] call _db;
            // If your INIDBI2 version uses a different function name/params
            // (check the header/docs that shipped with it), swap this one line.
            private _raw = ["read", [_sectionData, _faction]] call _db;

            if (!isNil "_raw" && {_raw isEqualType ""} && {_raw != ""}) then {
                private _record = call compile _raw;

                // Stored record shape is [fuel, supplies, fabrication, manpower, electricity, time]
                if (_record isEqualType [] && {count _record >= 5}) then {
                    private _resVector = [
                        _record select 0,
                        _record select 1,
                        _record select 2,
                        _record select 3,
                        _record select 4
                    ];
                    _loaded set [_faction, _resVector];
                    diag_log format ["[Resources][PERSIST] Loaded %1 resources: %2", _faction, _resVector];
                } else {
                    diag_log format ["[Resources][PERSIST] Unexpected data shape for %1, ignoring: %2", _faction, _record];
                };
            } else {
                diag_log format ["[Resources][PERSIST] No saved record found for %1.", _faction];
            };
        } forEach ["BLUFOR", "OPFOR"];

        if (count (keys _loaded) > 0) then {
            RES_factionResources = createHashMap;
            RES_factionResources set ["BLUFOR", _loaded getOrDefault ["BLUFOR", [0, 0, 0, 0, 0]]];
            RES_factionResources set ["OPFOR",  _loaded getOrDefault ["OPFOR",  [0, 0, 0, 0, 0]]];
            publicVariable "RES_factionResources";

            RES_factionResources_preloaded = true;
            diag_log "[Resources][PERSIST] Faction resources restored from previous session.";
        } else {
            diag_log "[Resources][PERSIST] No saved data found in DB - this looks like a first run, defaults will apply.";
        };
    };
};
