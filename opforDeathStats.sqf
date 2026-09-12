/*
 * OPFOR Death Statistics - Independent Killer Type Analysis System
 * 
 * Description: Standalone system that tracks what killed OPFOR units (infantry, tanks, air, etc.)
 * Usage: [] execVM "opforDeathStats.sqf"
 * 
 * Features:
 * - Independent death tracking with optimized event handling
 * - Shows breakdown by killer type: infantry, tank, apc, air, naval, unknown
 * - Simple format for web interface parsing
 * - Integrates with A3DJS system
 * - Optimized for performance - single script handling
 * 
 * Dependencies: NONE - completely standalone
 */

if (!isServer) exitWith {
    diag_log "[OpforDeathStats] Only runs on server";
};

diag_log "[OpforDeathStats] Initializing standalone OPFOR death statistics system...";

// ============================================================================
// DATA STORAGE (Optimized)
// ============================================================================

// Initialize OPFOR death statistics storage
if (isNil "OPFOR_STATS_deathData") then {
    OPFOR_STATS_deathData = createHashMap;
    
    // Simple death counters by killer type
    OPFOR_STATS_deathData set ["infantry", 0];
    OPFOR_STATS_deathData set ["tank", 0];
    OPFOR_STATS_deathData set ["apc", 0];
    OPFOR_STATS_deathData set ["air", 0];
    OPFOR_STATS_deathData set ["naval", 0];
    OPFOR_STATS_deathData set ["unknown", 0];
    OPFOR_STATS_deathData set ["totalDeaths", 0];
    
    publicVariable "OPFOR_STATS_deathData";
};

// ============================================================================
// KILLER ANALYSIS FUNCTIONS (Optimized from battlefield intelligence reference)
// ============================================================================

// Function: Analyze what killed the OPFOR unit (optimized version)
OPFOR_STATS_fnc_analyzeKiller = {
    params ["_unit", "_killer", "_instigator"];
    
    // Quick null check
    if (isNull _killer) exitWith {"unknown"};
    
    private _killerVehicle = vehicle _killer;
    
    // Fast killer type analysis (optimized categories)
    if (_killer isKindOf "Man") exitWith {"infantry"};
    if (_killerVehicle isKindOf "Tank") exitWith {"tank"};
    if (_killerVehicle isKindOf "Wheeled_APC_F" || _killerVehicle isKindOf "Tracked_APC_F") exitWith {"apc"};
    if (_killerVehicle isKindOf "Helicopter" || _killerVehicle isKindOf "Plane") exitWith {"air"};
    if (_killerVehicle isKindOf "Ship" || _killerVehicle isKindOf "Boat") exitWith {"naval"};
    
    "unknown"
};

// Function: Track OPFOR death (optimized detection logic from battlefield intelligence)
OPFOR_STATS_fnc_trackOpforDeath = {
    params ["_unit", "_killer", "_instigator"];
    
    // Optimized OPFOR detection (from battlefield intelligence reference)
    private _unitSide = side _unit;
    private _groupSide = side group _unit;
    private _isOpfor = (_unitSide == east || _groupSide == east);
    
    // Only track OPFOR deaths
    if (!_isOpfor) exitWith {};
    
    // Only count actual units (not objects/structures) - optimized check
    if (!(_unit isKindOf "Man" || _unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship")) exitWith {};
    
    // Analyze killer type
    private _killerType = [_unit, _killer, _instigator] call OPFOR_STATS_fnc_analyzeKiller;
    
    // Update death counters (optimized)
    private _currentCount = OPFOR_STATS_deathData getOrDefault [_killerType, 0];
    OPFOR_STATS_deathData set [_killerType, _currentCount + 1];
    
    // Update total deaths
    private _totalDeaths = OPFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    OPFOR_STATS_deathData set ["totalDeaths", _totalDeaths + 1];
    
    // Publish update
    publicVariable "OPFOR_STATS_deathData";
    
    // Simple logging
    diag_log format ["[OpforDeathStats] OPFOR killed by %1 (Total: %2)", _killerType, _totalDeaths + 1];
};

// ============================================================================
// CORE FUNCTIONS (Optimized)
// ============================================================================

// Get OPFOR death statistics in simple format for web interface
OPFOR_STATS_fnc_getDeathStats = {
    // Extract counts directly from optimized storage
    private _infantry = OPFOR_STATS_deathData getOrDefault ["infantry", 0];
    private _tank = OPFOR_STATS_deathData getOrDefault ["tank", 0];
    private _apc = OPFOR_STATS_deathData getOrDefault ["apc", 0];
    private _air = OPFOR_STATS_deathData getOrDefault ["air", 0];
    private _naval = OPFOR_STATS_deathData getOrDefault ["naval", 0];
    private _unknown = OPFOR_STATS_deathData getOrDefault ["unknown", 0];
    private _totalDeaths = OPFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    
    // Return simple format for easy parsing: "total:X,infantry:X,tank:X,apc:X,air:X,naval:X,unknown:X"
    private _response = format ["total:%1,infantry:%2,tank:%3,apc:%4,air:%5,naval:%6,unknown:%7", 
        _totalDeaths, _infantry, _tank, _apc, _air, _naval, _unknown];
    
    diag_log format ["[OpforDeathStats] Death stats requested - Response: %1", _response];
    
    _response
};

// Get detailed breakdown with percentages (for in-game use)
OPFOR_STATS_fnc_getDetailedStats = {
    private _totalDeaths = OPFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    
    if (_totalDeaths == 0) exitWith {
        systemChat "[OpforDeathStats] No OPFOR deaths recorded yet";
        false
    };
    
    systemChat "=== OPFOR DEATH STATISTICS ===";
    systemChat format ["Total OPFOR Deaths: %1", _totalDeaths];
    systemChat "--- Killed By ---";
    
    private _categories = [
        ["infantry", "Infantry"], 
        ["tank", "Tanks"], 
        ["apc", "APCs"], 
        ["air", "Aircraft"], 
        ["naval", "Naval"], 
        ["unknown", "Unknown"]
    ];
    
    {
        private _type = _x select 0;
        private _name = _x select 1;
        private _count = OPFOR_STATS_deathData getOrDefault [_type, 0];
        private _percentage = if (_totalDeaths > 0) then {
            round((_count / _totalDeaths) * 100)
        } else {
            0
        };
        
        systemChat format ["%1: %2 deaths (%3%%)", _name, _count, _percentage];
    } forEach _categories;
    
    systemChat "================================";
    
    true
};

// Reset statistics
OPFOR_STATS_fnc_resetStats = {
    systemChat "[OpforDeathStats] Resetting OPFOR death statistics...";
    
    // Reset all counters
    OPFOR_STATS_deathData set ["infantry", 0];
    OPFOR_STATS_deathData set ["tank", 0];
    OPFOR_STATS_deathData set ["apc", 0];
    OPFOR_STATS_deathData set ["air", 0];
    OPFOR_STATS_deathData set ["naval", 0];
    OPFOR_STATS_deathData set ["unknown", 0];
    OPFOR_STATS_deathData set ["totalDeaths", 0];
    
    publicVariable "OPFOR_STATS_deathData";
    
    systemChat "[OpforDeathStats] Statistics reset complete";
    
    true
};

// ============================================================================
// EVENT HANDLER (Optimized Single Handler)
// ============================================================================

// Set up optimized entity killed event handler
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Track OPFOR deaths with optimized detection
    [_unit, _killer, _instigator] call OPFOR_STATS_fnc_trackOpforDeath;
}];

// ============================================================================
// INTEGRATION WITH A3DJS SYSTEM
// ============================================================================

// Wait for A3DJS to initialize
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    systemChat "[OpforDeathStats] A3DJS detected, registering opfor-death-stats command...";
    
    // Define OPFOR death statistics function (follows A3DJS pattern)
    OPFOR_STATS_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", "execute"]];
        
        diag_log format ["[OpforDeathStats] OPFOR death stats requested: %1", _this];
        
        // Get current OPFOR death statistics
        private _statsResponse = [] call OPFOR_STATS_fnc_getDeathStats;
        
        // Send response to Discord/Web (using A3DJS response system)
        [_RequestId, _statsResponse] call A3DJS_fnc_respondCall;
        
        // Also show in game chat
        [format["[Discord] OPFOR death stats checked by %1", _sender]] remoteExecCall ["systemChat", 0];
        
        true;
    };
    
    // Register command with A3DJS system
    ["opfor-death-stats", OPFOR_STATS_fnc_getStatus] call A3DJS_fnc_addCommandType;
    
    systemChat "[OpforDeathStats] opfor-death-stats command registered with A3DJS!";
    diag_log "[OpforDeathStats] Successfully integrated with A3DJS system";
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "OPFOR_STATS_fnc_analyzeKiller";
publicVariable "OPFOR_STATS_fnc_trackOpforDeath";
publicVariable "OPFOR_STATS_fnc_getDeathStats";
publicVariable "OPFOR_STATS_fnc_getDetailedStats";
publicVariable "OPFOR_STATS_fnc_resetStats";
publicVariable "OPFOR_STATS_fnc_getStatus";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[OpforDeathStats] Standalone OPFOR death statistics system initialized!";
systemChat "[OpforDeathStats] Optimized tracking: Infantry | Tank | APC | Air | Naval | Unknown";
systemChat "[OpforDeathStats] Independent system - no external dependencies required";
systemChat "Commands: [] call OPFOR_STATS_fnc_getDetailedStats | [] call OPFOR_STATS_fnc_resetStats";

diag_log "[OpforDeathStats] Standalone OPFOR death statistics system fully initialized";
diag_log "[OpforDeathStats] Optimized for performance - single event handler processing";