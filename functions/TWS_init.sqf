/*
 * Total War Simulation - ALiVE Integration System
 * Initialize core TWS functionality
 */

diag_log "[TWS] Initializing Total War Simulation core systems...";

// This file is called from initServer.sqf
// Core systems will be initialized by individual scripts

if (isServer) then {
    // Set up basic TWS variables if they don't exist
    if (isNil "TWS_initialized") then {
        TWS_initialized = false;
        publicVariable "TWS_initialized";
    };
    
    // Wait for ALiVE to be ready
    waitUntil {!isNil "ALiVE_sectorGrid"};
    
    diag_log "[TWS] ALiVE detected, TWS core ready";
    
    TWS_initialized = true;
    publicVariable "TWS_initialized";
    
    systemChat "[TWS] Core systems initialized";
};