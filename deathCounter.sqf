/*
 * Death Counter - Simple Death Tracking System
 * 
 * Description: Tracks total death count of all units in game
 * Usage: [] execVM "deathCounter.sqf"
 * 
 * Features:
 * - Tracks ALL deaths (no side discrimination)  
 * - Simple counter - no killer analysis or breakdown
 * - Integrates with A3DJS system for web interface updates
 * - Live updates via web polling like basicResources
 * 
 * Data Structure: DEATH_totalCount (simple number)
 */

if (!isServer) exitWith {
    diag_log "[DeathCounter] Only runs on server";
};

diag_log "[DeathCounter] Initializing simple death tracking system...";

// ============================================================================
// DEATH STORAGE
// ============================================================================

// Initialize death counter
if (isNil "DEATH_totalCount") then {
    DEATH_totalCount = 0;
    publicVariable "DEATH_totalCount";
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

// Get total death count
DEATH_fnc_getCount = {
    DEATH_totalCount
};

// Add to death count
DEATH_fnc_addDeath = {
    DEATH_totalCount = DEATH_totalCount + 1;
    publicVariable "DEATH_totalCount";
    
    systemChat format ["[DeathCounter] Total deaths: %1", DEATH_totalCount];
    diag_log format ["[DeathCounter] Death registered - Total: %1", DEATH_totalCount];
};

// Reset death counter (for testing)
DEATH_fnc_resetCount = {
    DEATH_totalCount = 0;
    publicVariable "DEATH_totalCount";
    
    systemChat "[DeathCounter] Death count reset to 0";
    diag_log "[DeathCounter] Death count manually reset";
};

// ============================================================================
// EVENT HANDLER
// ============================================================================

// Track ALL deaths - no discrimination
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Only count actual units (not objects/structures)
    if (_unit isKindOf "Man" || _unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship") then {
        [] call DEATH_fnc_addDeath;
        
        // Debug info
        diag_log format ["[DeathCounter] Death tracked: %1 (Type: %2)", name _unit, typeOf _unit];
    };
}];

// ============================================================================
// INTEGRATION WITH A3DJS SYSTEM (like basicResources)
// ============================================================================

// Wait for A3DJS to initialize (same pattern as customA3DJSCommands.sqf)
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    systemChat "[DeathCounter] A3DJS detected, registering death-count command...";
    
    // Define death count status function (follows A3DJS pattern)
    DEATH_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", "execute"]];
        
        diag_log format ["[DeathCounter] Death count requested: %1", _this];
        
        // Get current death count
        private _deathCount = [] call DEATH_fnc_getCount;
        
        // Build response message (simple format for web interface)
        private _response = format ["%1", _deathCount];
        
        // Send response to Discord/Web (using A3DJS response system)
        [_RequestId, _response] call A3DJS_fnc_respondCall;
        
        // Also show in game chat
        [format["[Discord] Death count checked by %1: %2 total deaths", _sender, _deathCount]] remoteExecCall ["systemChat", 0];
        
        true;
    };
    
    // Register command with A3DJS system
    ["death-count", DEATH_fnc_getStatus] call A3DJS_fnc_addCommandType;
    
    systemChat "[DeathCounter] death-count command registered with A3DJS!";
    diag_log "[DeathCounter] Successfully integrated with A3DJS system";
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "DEATH_fnc_getCount";
publicVariable "DEATH_fnc_addDeath";
publicVariable "DEATH_fnc_resetCount";
publicVariable "DEATH_fnc_getStatus";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[DeathCounter] Simple death tracking system initialized!";
systemChat "[DeathCounter] Tracking: ALL unit deaths (no side discrimination)";
systemChat "[DeathCounter] Current death count: " + str DEATH_totalCount;
systemChat "Commands: [] call DEATH_fnc_getCount | [] call DEATH_fnc_resetCount";

diag_log "[DeathCounter] Simple death counter system fully initialized";
diag_log format ["[DeathCounter] Current count: %1", DEATH_totalCount];