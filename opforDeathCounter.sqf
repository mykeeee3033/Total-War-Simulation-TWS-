/*
 * OPFOR Death Counter - Simple OPFOR Death Tracking System
 * 
 * Description: Tracks total death count of OPFOR units only
 * Usage: [] execVM "opforDeathCounter.sqf"
 * 
 * Features:
 * - Tracks OPFOR deaths only (no other factions)
 * - Simple counter - no killer analysis or breakdown
 * - Integrates with A3DJS system for web interface updates
 * - Live updates via web polling like basicResources
 * 
 * Data Structure: OPFOR_deathCount (simple number)
 */

if (!isServer) exitWith {
    diag_log "[OpforDeathCounter] Only runs on server";
};

diag_log "[OpforDeathCounter] Initializing OPFOR death tracking system...";

// ============================================================================
// OPFOR DEATH STORAGE
// ============================================================================

// Initialize OPFOR death counter
if (isNil "OPFOR_deathCount") then {
    OPFOR_deathCount = 0;
    publicVariable "OPFOR_deathCount";
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

// Get OPFOR death count
OPFOR_fnc_getCount = {
    OPFOR_deathCount
};

// Add to OPFOR death count
OPFOR_fnc_addDeath = {
    OPFOR_deathCount = OPFOR_deathCount + 1;
    publicVariable "OPFOR_deathCount";
    
    systemChat format ["[OpforDeathCounter] OPFOR deaths: %1", OPFOR_deathCount];
    diag_log format ["[OpforDeathCounter] OPFOR death registered - Total: %1", OPFOR_deathCount];
};

// Reset OPFOR death counter (for testing)
OPFOR_fnc_resetCount = {
    OPFOR_deathCount = 0;
    publicVariable "OPFOR_deathCount";
    
    systemChat "[OpforDeathCounter] OPFOR death count reset to 0";
    diag_log "[OpforDeathCounter] OPFOR death count manually reset";
};

// ============================================================================
// EVENT HANDLER
// ============================================================================

// Function: Track OPFOR death (using battlefield intelligence logic)
OPFOR_fnc_trackOpforDeath = {
    params ["_unit", "_killer", "_instigator"];
    
    // Check multiple ways to determine if unit is OPFOR (exact logic from battlefield intel)
    private _unitSide = side _unit;
    private _groupSide = side group _unit;
    private _isOpfor = (_unitSide == east || _groupSide == east);
    
    // Only track OPFOR deaths
    if (!_isOpfor) exitWith {};
    
    // Only count actual units (not objects/structures)
    if (!(_unit isKindOf "Man" || _unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship")) exitWith {};
    
    // Add to OPFOR death count
    [] call OPFOR_fnc_addDeath;
    
    // Debug info
    diag_log format ["[OpforDeathCounter] OPFOR death tracked: %1 (Type: %2, Side: %3, GroupSide: %4)", name _unit, typeOf _unit, _unitSide, _groupSide];
};

// Track all deaths and filter for OPFOR (same as battlefield intelligence)
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Track OPFOR deaths using battlefield intelligence logic
    [_unit, _killer, _instigator] call OPFOR_fnc_trackOpforDeath;
}];

// ============================================================================
// INTEGRATION WITH A3DJS SYSTEM (like deathCounter)
// ============================================================================

// Wait for A3DJS to initialize (same pattern as customA3DJSCommands.sqf)
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    systemChat "[OpforDeathCounter] A3DJS detected, registering opfor-deaths command...";
    
    // Define OPFOR death count status function (follows A3DJS pattern)
    OPFOR_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", "execute"]];
        
        diag_log format ["[OpforDeathCounter] OPFOR death count requested: %1", _this];
        
        // Get current OPFOR death count
        private _opforDeathCount = [] call OPFOR_fnc_getCount;
        
        // Build response message (simple format for web interface)
        private _response = format ["%1", _opforDeathCount];
        
        // Send response to Discord/Web (using A3DJS response system)
        [_RequestId, _response] call A3DJS_fnc_respondCall;
        
        // Also show in game chat
        [format["[Discord] OPFOR death count checked by %1: %2 total OPFOR deaths", _sender, _opforDeathCount]] remoteExecCall ["systemChat", 0];
        
        true;
    };
    
    // Register command with A3DJS system
    ["opfor-deaths", OPFOR_fnc_getStatus] call A3DJS_fnc_addCommandType;
    
    systemChat "[OpforDeathCounter] opfor-deaths command registered with A3DJS!";
    diag_log "[OpforDeathCounter] Successfully integrated with A3DJS system";
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "OPFOR_fnc_getCount";
publicVariable "OPFOR_fnc_addDeath";
publicVariable "OPFOR_fnc_resetCount";
publicVariable "OPFOR_fnc_getStatus";
publicVariable "OPFOR_fnc_trackOpforDeath";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[OpforDeathCounter] OPFOR death tracking system initialized!";
systemChat "[OpforDeathCounter] Tracking: OPFOR unit deaths only";
systemChat "[OpforDeathCounter] Current OPFOR death count: " + str OPFOR_deathCount;
systemChat "Commands: [] call OPFOR_fnc_getCount | [] call OPFOR_fnc_resetCount";

diag_log "[OpforDeathCounter] OPFOR death counter system fully initialized";
diag_log format ["[OpforDeathCounter] Current OPFOR count: %1", OPFOR_deathCount];