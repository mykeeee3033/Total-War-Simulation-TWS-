/*
 * BLUFOR Death Counter - Simple BLUFOR Death Tracking System
 * 
 * Description: Tracks total death count of BLUFOR units only
 * Usage: [] execVM "bluforDeathCounter.sqf"
 * 
 * Features:
 * - Tracks BLUFOR deaths only (no other factions)
 * - Simple counter - no killer analysis or breakdown
 * - Integrates with A3DJS system for web interface updates
 * - Live updates via web polling like basicResources
 * 
 * Data Structure: BLUFOR_deathCount (simple number)
 */

if (!isServer) exitWith {
    diag_log "[BluforDeathCounter] Only runs on server";
};

diag_log "[BluforDeathCounter] Initializing BLUFOR death tracking system...";

// ============================================================================
// BLUFOR DEATH STORAGE
// ============================================================================

// Initialize BLUFOR death counter
if (isNil "BLUFOR_deathCount") then {
    BLUFOR_deathCount = 0;
    publicVariable "BLUFOR_deathCount";
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

// Get BLUFOR death count
BLUFOR_fnc_getCount = {
    BLUFOR_deathCount
};

// Add to BLUFOR death count
BLUFOR_fnc_addDeath = {
    BLUFOR_deathCount = BLUFOR_deathCount + 1;
    publicVariable "BLUFOR_deathCount";
    
    systemChat format ["[BluforDeathCounter] BLUFOR deaths: %1", BLUFOR_deathCount];
    diag_log format ["[BluforDeathCounter] BLUFOR death registered - Total: %1", BLUFOR_deathCount];
};

// Reset BLUFOR death counter (for testing)
BLUFOR_fnc_resetCount = {
    BLUFOR_deathCount = 0;
    publicVariable "BLUFOR_deathCount";
    
    systemChat "[BluforDeathCounter] BLUFOR death count reset to 0";
    diag_log "[BluforDeathCounter] BLUFOR death count manually reset";
};

// ============================================================================
// EVENT HANDLER
// ============================================================================

// Function: Track BLUFOR death (using battlefield intelligence logic)
BLUFOR_fnc_trackBluforDeath = {
    params ["_unit", "_killer", "_instigator"];
    
    // Check multiple ways to determine if unit is BLUFOR (exact logic from battlefield intel)
    private _unitSide = side _unit;
    private _groupSide = side group _unit;
    private _isBlufor = (_unitSide == west || _groupSide == west);
    
    // Only track BLUFOR deaths
    if (!_isBlufor) exitWith {};
    
    // Only count actual units (not objects/structures)
    if (!(_unit isKindOf "Man" || _unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship")) exitWith {};
    
    // Add to BLUFOR death count
    [] call BLUFOR_fnc_addDeath;
    
    // Debug info
    diag_log format ["[BluforDeathCounter] BLUFOR death tracked: %1 (Type: %2, Side: %3, GroupSide: %4)", name _unit, typeOf _unit, _unitSide, _groupSide];
};

// Track all deaths and filter for BLUFOR (same as battlefield intelligence)
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Track BLUFOR deaths using battlefield intelligence logic
    [_unit, _killer, _instigator] call BLUFOR_fnc_trackBluforDeath;
}];

// ============================================================================
// INTEGRATION WITH A3DJS SYSTEM (like deathCounter)
// ============================================================================

// Wait for A3DJS to initialize (same pattern as customA3DJSCommands.sqf)
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    systemChat "[BluforDeathCounter] A3DJS detected, registering blufor-deaths command...";
    
    // Define BLUFOR death count status function (follows A3DJS pattern)
    BLUFOR_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", "execute"]];
        
        diag_log format ["[BluforDeathCounter] BLUFOR death count requested: %1", _this];
        
        // Get current BLUFOR death count
        private _bluforDeathCount = [] call BLUFOR_fnc_getCount;
        
        // Build response message (simple format for web interface)
        private _response = format ["%1", _bluforDeathCount];
        
        // Send response to Discord/Web (using A3DJS response system)
        [_RequestId, _response] call A3DJS_fnc_respondCall;
        
        // Also show in game chat
        [format["[Discord] BLUFOR death count checked by %1: %2 total BLUFOR deaths", _sender, _bluforDeathCount]] remoteExecCall ["systemChat", 0];
        
        true;
    };
    
    // Register command with A3DJS system
    ["blufor-deaths", BLUFOR_fnc_getStatus] call A3DJS_fnc_addCommandType;
    
    systemChat "[BluforDeathCounter] blufor-deaths command registered with A3DJS!";
    diag_log "[BluforDeathCounter] Successfully integrated with A3DJS system";
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "BLUFOR_fnc_getCount";
publicVariable "BLUFOR_fnc_addDeath";
publicVariable "BLUFOR_fnc_resetCount";
publicVariable "BLUFOR_fnc_getStatus";
publicVariable "BLUFOR_fnc_trackBluforDeath";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[BluforDeathCounter] BLUFOR death tracking system initialized!";
systemChat "[BluforDeathCounter] Tracking: BLUFOR unit deaths only";
systemChat "[BluforDeathCounter] Current BLUFOR death count: " + str BLUFOR_deathCount;
systemChat "Commands: [] call BLUFOR_fnc_getCount | [] call BLUFOR_fnc_resetCount";

diag_log "[BluforDeathCounter] BLUFOR death counter system fully initialized";
diag_log format ["[BluforDeathCounter] Current BLUFOR count: %1", BLUFOR_deathCount];