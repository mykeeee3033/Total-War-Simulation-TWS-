/*
 * game_time_export_inidbi2.sqf
 *
 * Dedicated INIDBI2 game-time clock exporter.
 * Writes Arma game time to a separate DB so external tools can
 * track countdowns independently from recon/commander export cadence.
 */

if (!isServer) exitWith {};

if (isNil "TWS_CLOCK_export_dbName") then { TWS_CLOCK_export_dbName = "TWS_GameClock"; };
if (isNil "TWS_CLOCK_export_section") then { TWS_CLOCK_export_section = "Clock"; };
if (isNil "TWS_CLOCK_export_interval") then { TWS_CLOCK_export_interval = 1; };
if (isNil "TWS_CLOCK_export_running") then { TWS_CLOCK_export_running = false; };

TWS_CLOCK_fnc_initIniDB = {
    if (!isNil "TWS_CLOCK_iniDB") exitWith {true};

    if (isNil "OO_INIDBI") exitWith {
        diag_log "[TWS_CLOCK] OO_INIDBI not found. Game-time export disabled.";
        false
    };

    TWS_CLOCK_iniDB = ["new", TWS_CLOCK_export_dbName] call OO_INIDBI;
    if (isNil "TWS_CLOCK_iniDB") exitWith {
        diag_log format ["[TWS_CLOCK] Failed to open INIDBI2 DB: %1", TWS_CLOCK_export_dbName];
        false
    };

    diag_log format ["[TWS_CLOCK] INIDBI2 DB ready: %1", TWS_CLOCK_export_dbName];
    true
};

TWS_CLOCK_fnc_write = {
    params ["_key", "_value"];

    if (isNil "TWS_CLOCK_iniDB") exitWith {false};
    ["write", [TWS_CLOCK_export_section, _key, _value]] call TWS_CLOCK_iniDB;
    true
};

if (TWS_CLOCK_export_running) exitWith {
    diag_log "[TWS_CLOCK] Game-time exporter already running";
};

TWS_CLOCK_export_running = true;
publicVariable "TWS_CLOCK_export_running";

[] spawn {
    diag_log "[TWS_CLOCK] Game-time exporter started";

    while {TWS_CLOCK_export_running} do {
        private _ready = [] call TWS_CLOCK_fnc_initIniDB;
        if (_ready) then {
            ["GameTime", time] call TWS_CLOCK_fnc_write;
            ["SystemTimeUTC", str systemTimeUTC] call TWS_CLOCK_fnc_write;
            ["ScenarioClosed", 0] call TWS_CLOCK_fnc_write;
        };

        sleep TWS_CLOCK_export_interval;
    };

    diag_log "[TWS_CLOCK] Game-time exporter stopped";
};

if (isNil "TWS_CLOCK_export_endMissionEH") then {
    TWS_CLOCK_export_endMissionEH = addMissionEventHandler ["Ended", {
        TWS_CLOCK_export_running = false;
        if (!isNil "TWS_CLOCK_iniDB") then {
            ["write", [TWS_CLOCK_export_section, "ScenarioClosed", 1]] call TWS_CLOCK_iniDB;
        };
    }];
};

publicVariable "TWS_CLOCK_export_dbName";
publicVariable "TWS_CLOCK_export_section";
publicVariable "TWS_CLOCK_export_interval";
