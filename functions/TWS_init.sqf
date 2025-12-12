/*
 * TWS_init.sqf
 * Total War Simulation - ALiVE Integration System
 * Master Initialization File
 * 
 * This file initializes all TWS modules in the correct order
 * Execute this from initServer.sqf: [] execVM "functions\TWS_init.sqf";
 */

if (isServer) then {
    systemChat "[TWS] Initializing Total War Simulation system...";
    diag_log "[TWS] ========== TWS Initialization Start ==========";
    
    // Phase 0: Configuration and Intervals
    diag_log "[TWS] Phase 0: Loading Configuration";
    [] execVM "functions\TWS_intervals.sqf";
    waitUntil {!isNil "TWS_intervals"};
    systemChat "[TWS] ✓ Intervals loaded";
    
    [] execVM "functions\TWS_config.sqf";
    sleep 1; // Allow config to load
    systemChat "[TWS] ✓ Configuration loaded";
    
    // Phase 1: Core Systems
    diag_log "[TWS] Phase 1: Loading Core Systems";
    [] execVM "functions\core\worldState_custom.sqf";
    waitUntil {!isNil "TWS_worldState"};
    systemChat "[TWS] ✓ World State loaded";
    
    [] execVM "functions\core\objectRoles.sqf";
    waitUntil {!isNil "TWS_objectRoles"};
    systemChat "[TWS] ✓ Object Roles loaded";
    
    [] execVM "functions\core\extendedResources.sqf";
    sleep 1; // Allow extended resources to initialize
    systemChat "[TWS] ✓ Extended Resources loaded";
    
    // Phase 2: Logistics System
    diag_log "[TWS] Phase 2: Loading Logistics System";
    [] execVM "functions\logistics\customLogistics.sqf";
    waitUntil {!isNil "TWS_logisticsConfig"};
    systemChat "[TWS] ✓ Custom Logistics loaded";
    
    // Phase 3: ALiVE Integration
    diag_log "[TWS] Phase 3: Loading ALiVE Integration";
    [] execVM "functions\aliveHooks\aliveIntegration.sqf";
    waitUntil {!isNil "TWS_aliveConfig"};
    systemChat "[TWS] ✓ ALiVE Integration loaded";
    
    // Phase 4: Radar & Air Defense
    diag_log "[TWS] Phase 4: Loading Radar & Air Defense";
    [] execVM "functions\radarAir\radarDefense_custom.sqf";
    waitUntil {!isNil "TWS_radarDefenseConfig"};
    systemChat "[TWS] ✓ Radar Defense loaded";
    
    // Phase 5: Commander AI
    diag_log "[TWS] Phase 5: Loading Commander AI";
    [] execVM "functions\commander\commanderPersonality.sqf";
    waitUntil {!isNil "TWS_commanders"};
    systemChat "[TWS] ✓ Commander Personality loaded";
    
    [] execVM "functions\commander\moraleAndTraining.sqf";
    sleep 1; // Allow morale system to initialize
    systemChat "[TWS] ✓ Morale and Training loaded";
    
    // Phase 6: Strategic Reporting
    diag_log "[TWS] Phase 6: Loading Strategic Reporting";
    [] execVM "functions\reports\chatGPTIntegration.sqf";
    waitUntil {!isNil "TWS_chatGPTConfig"};
    systemChat "[TWS] ✓ ChatGPT Integration loaded";
    
    // Phase 7: Optional Systems (disabled by default)
    diag_log "[TWS] Phase 7: Loading Optional Systems";
    [] execVM "functions\core\geopolitics.sqf";
    [] execVM "functions\core\civilianEconomy.sqf";
    sleep 2;
    systemChat "[TWS] ✓ Optional systems loaded (disabled)";
    
    // Phase 8: Enhanced Monitoring
    diag_log "[TWS] Phase 8: Loading Enhanced Monitoring";
    [] execVM "functions\core\enhancedMonitoring.sqf";
    sleep 1;
    systemChat "[TWS] ✓ Enhanced Monitoring loaded";
    
    // Wait a moment for all systems to stabilize
    sleep 3;
    
    // Apply configuration assignments
    diag_log "[TWS] Applying configuration assignments";
    if (!isNil "TWS_fnc_applyManualAssignments") then {
        [] call TWS_fnc_applyManualAssignments;
    };
    if (!isNil "TWS_fnc_applyMarkerAssignments") then {
        [] call TWS_fnc_applyMarkerAssignments;
    };
    
    // Auto-assign roles to objects (optional - can be customized)
    diag_log "[TWS] Running auto-assignment of object roles";
    [] call TWS_fnc_autoAssignRoles;
    
    // Integration with existing radar systems
    diag_log "[TWS] Integrating with existing radar systems";
    if (!isNil "radar_2") then {
        [radar_2, "BLUFOR"] call TWS_fnc_enhanceRadarScript;
        systemChat "[TWS] ✓ Integrated with radar_2 (BLUFOR)";
    };
    
    // Display initialization complete
    systemChat "========================================";
    systemChat "[TWS] TOTAL WAR SIMULATION INITIALIZED";
    systemChat "========================================";
    systemChat "[TWS] All systems operational";
    systemChat "[TWS] Enhanced monitoring every 2 minutes";
    systemChat "[TWS] Strategic reports every 30 minutes";
    systemChat "[TWS] Production/consumption active";
    systemChat "[TWS] Commander AI active";
    systemChat "[TWS] Extended resources active";
    systemChat "========================================";
    
    diag_log "[TWS] ========== TWS Initialization Complete ==========";
    diag_log "[TWS] System Status:";
    diag_log "[TWS]   - Configuration: Active";
    diag_log "[TWS]   - Intervals: Configurable";
    diag_log "[TWS]   - World State: Active";
    diag_log "[TWS]   - Extended Resources: Active (manpower, munitions, fabrications, rnd, electricity, construction)";
    diag_log "[TWS]   - Logistics: Active";
    diag_log "[TWS]   - ALiVE Integration: Active";
    diag_log "[TWS]   - Radar Defense: Active";
    diag_log "[TWS]   - Commander AI: Active";
    diag_log "[TWS]   - Strategic Reporting: Active";
    diag_log "[TWS]   - Enhanced Monitoring: Active (2-min updates)";
    diag_log "[TWS]   - Geopolitics: Standby (use TWS_fnc_toggleGeopolitics)";
    diag_log "[TWS]   - Civilian Economy: Standby (use TWS_fnc_toggleCivilianEconomy)";
    diag_log "[TWS] =================================================";
    
    // Set global flag
    TWS_initialized = true;
    publicVariable "TWS_initialized";
};
