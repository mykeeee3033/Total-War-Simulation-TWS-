/*
 * BLUFOR Death Statistics - Independent Killer Type Analysis System
 * 
 * Description: Standalone system that tracks what killed BLUFOR units (infantry, tanks, air, etc.)
 * Usage: [] execVM "bluforDeathStats.sqf"
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
    diag_log "[BluforDeathStats] Only runs on server";
};

diag_log "[BluforDeathStats] Initializing standalone BLUFOR death statistics system...";

// ============================================================================
// DATA STORAGE (Optimized)
// ============================================================================

// Initialize BLUFOR death statistics storage
if (isNil "BLUFOR_STATS_deathData") then {
    BLUFOR_STATS_deathData = createHashMap;
    
    // Simple death counters by killer type
    BLUFOR_STATS_deathData set ["infantry", 0];
    BLUFOR_STATS_deathData set ["tank", 0];
    BLUFOR_STATS_deathData set ["apc", 0];
    BLUFOR_STATS_deathData set ["air", 0];
    BLUFOR_STATS_deathData set ["naval", 0];
    BLUFOR_STATS_deathData set ["unknown", 0];
    BLUFOR_STATS_deathData set ["totalDeaths", 0];
    
    publicVariable "BLUFOR_STATS_deathData";
};

// ============================================================================
// KILLER ANALYSIS FUNCTIONS (Optimized from battlefield intelligence reference)
// ============================================================================

// Function: Analyze what killed the BLUFOR unit (optimized version)
BLUFOR_STATS_fnc_analyzeKiller = {
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

// Function: Track BLUFOR death (optimized detection logic from battlefield intelligence)
BLUFOR_STATS_fnc_trackBluforDeath = {
    params ["_unit", "_killer", "_instigator"];
    
    // Optimized BLUFOR detection (from battlefield intelligence reference)
    private _unitSide = side _unit;
    private _groupSide = side group _unit;
    private _isBlufor = (_unitSide == west || _groupSide == west);
    
    // Only track BLUFOR deaths
    if (!_isBlufor) exitWith {};
    
    // Only count actual units (not objects/structures) - optimized check
    if (!(_unit isKindOf "Man" || _unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship")) exitWith {};
    
    // Analyze killer type
    private _killerType = [_unit, _killer, _instigator] call BLUFOR_STATS_fnc_analyzeKiller;
    
    // Update death counters (optimized)
    private _currentCount = BLUFOR_STATS_deathData getOrDefault [_killerType, 0];
    BLUFOR_STATS_deathData set [_killerType, _currentCount + 1];
    
    // Update total deaths
    private _totalDeaths = BLUFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    BLUFOR_STATS_deathData set ["totalDeaths", _totalDeaths + 1];
    
    // Publish update
    publicVariable "BLUFOR_STATS_deathData";
    
    // Simple logging
    diag_log format ["[BluforDeathStats] BLUFOR killed by %1 (Total: %2)", _killerType, _totalDeaths + 1];
};

// ============================================================================
// CORE FUNCTIONS (Optimized)
// ============================================================================

// Get BLUFOR death statistics in simple format for web interface
BLUFOR_STATS_fnc_getDeathStats = {
    // Extract counts directly from optimized storage
    private _infantry = BLUFOR_STATS_deathData getOrDefault ["infantry", 0];
    private _tank = BLUFOR_STATS_deathData getOrDefault ["tank", 0];
    private _apc = BLUFOR_STATS_deathData getOrDefault ["apc", 0];
    private _air = BLUFOR_STATS_deathData getOrDefault ["air", 0];
    private _naval = BLUFOR_STATS_deathData getOrDefault ["naval", 0];
    private _unknown = BLUFOR_STATS_deathData getOrDefault ["unknown", 0];
    private _totalDeaths = BLUFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    
    // Return simple format for easy parsing: "total:X,infantry:X,tank:X,apc:X,air:X,naval:X,unknown:X"
    private _response = format ["total:%1,infantry:%2,tank:%3,apc:%4,air:%5,naval:%6,unknown:%7", 
        _totalDeaths, _infantry, _tank, _apc, _air, _naval, _unknown];
    
    diag_log format ["[BluforDeathStats] Death stats requested - Response: %1", _response];
    
    _response
};

// Get detailed breakdown with percentages (for in-game use)
BLUFOR_STATS_fnc_getDetailedStats = {
    private _totalDeaths = BLUFOR_STATS_deathData getOrDefault ["totalDeaths", 0];
    
    if (_totalDeaths == 0) exitWith {
        systemChat "[BluforDeathStats] No BLUFOR deaths recorded yet";
        false
    };
    
    systemChat "=== BLUFOR DEATH STATISTICS ===";
    systemChat format ["Total BLUFOR Deaths: %1", _totalDeaths];
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
        private _count = BLUFOR_STATS_deathData getOrDefault [_type, 0];
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
BLUFOR_STATS_fnc_resetStats = {
    systemChat "[BluforDeathStats] Resetting BLUFOR death statistics...";
    
    // Reset all counters
    BLUFOR_STATS_deathData set ["infantry", 0];
    BLUFOR_STATS_deathData set ["tank", 0];
    BLUFOR_STATS_deathData set ["apc", 0];
    BLUFOR_STATS_deathData set ["air", 0];
    BLUFOR_STATS_deathData set ["naval", 0];
    BLUFOR_STATS_deathData set ["unknown", 0];
    BLUFOR_STATS_deathData set ["totalDeaths", 0];
    
    publicVariable "BLUFOR_STATS_deathData";
    
    systemChat "[BluforDeathStats] Statistics reset complete";
    
    true
};

// ============================================================================
// EVENT HANDLER (Optimized Single Handler)
// ============================================================================

// Set up optimized entity killed event handler
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Track BLUFOR deaths with optimized detection
    [_unit, _killer, _instigator] call BLUFOR_STATS_fnc_trackBluforDeath;
}];

// ============================================================================
// INTEGRATION WITH A3DJS SYSTEM
// ============================================================================

// Wait for A3DJS to initialize
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    systemChat "[BluforDeathStats] A3DJS detected, registering blufor-death-stats command...";
    
    // Define BLUFOR death statistics function (follows A3DJS pattern)
    BLUFOR_STATS_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", "execute"]];
        
        diag_log format ["[BluforDeathStats] BLUFOR death stats requested: %1", _this];
        
        // Get current BLUFOR death statistics
        private _statsResponse = [] call BLUFOR_STATS_fnc_getDeathStats;
        
        // Send response to Discord/Web (using A3DJS response system)
        [_RequestId, _statsResponse] call A3DJS_fnc_respondCall;
        
        // Also show in game chat
        [format["[Discord] BLUFOR death stats checked by %1", _sender]] remoteExecCall ["systemChat", 0];
        
        true;
    };
    
    // Register command with A3DJS system
    ["blufor-death-stats", BLUFOR_STATS_fnc_getStatus] call A3DJS_fnc_addCommandType;
    
    systemChat "[BluforDeathStats] blufor-death-stats command registered with A3DJS!";
    diag_log "[BluforDeathStats] Successfully integrated with A3DJS system";
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "BLUFOR_STATS_fnc_analyzeKiller";
publicVariable "BLUFOR_STATS_fnc_trackBluforDeath";
publicVariable "BLUFOR_STATS_fnc_getDeathStats";
publicVariable "BLUFOR_STATS_fnc_getDetailedStats";
publicVariable "BLUFOR_STATS_fnc_resetStats";
publicVariable "BLUFOR_STATS_fnc_getStatus";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[BluforDeathStats] Standalone BLUFOR death statistics system initialized!";
systemChat "[BluforDeathStats] Optimized tracking: Infantry | Tank | APC | Air | Naval | Unknown";
systemChat "[BluforDeathStats] Independent system - no external dependencies required";
systemChat "Commands: [] call BLUFOR_STATS_fnc_getDetailedStats | [] call BLUFOR_STATS_fnc_resetStats";

diag_log "[BluforDeathStats] Standalone BLUFOR death statistics system fully initialized";
diag_log "[BluforDeathStats] Optimized for performance - single event handler processing";