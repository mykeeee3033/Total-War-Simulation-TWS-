/*
 * TWS_initEnhanced.sqf
 * Enhanced TWS Initialization - Includes All New Systems
 * 
 * This file initializes all enhanced TWS modules including:
 * - Marker system
 * - Notification system  
 * - Enhanced combat monitoring
 * - Sector area system
 * - Dynamic resupply
 * - Manpower resupply
 * - Enhanced production
 * - Dynamic reinforcements
 * - Communication grid enhancements
 */

if (isServer) then {
    systemChat "[TWS] Initializing Enhanced Total War Simulation system...";
    diag_log "[TWS] ========== Enhanced TWS Initialization Start ==========";
    
    // Wait for core TWS systems (if loading after base TWS_init.sqf)
    waitUntil {sleep 1; !isNil "TWS_worldState" && !isNil "TWS_objectRoles" && !isNil "TWS_sectors"};
    
    diag_log "[TWS] Core systems detected, loading enhancements...";
    
    // ===============================================================
    // PHASE 1: MARKER AND NOTIFICATION SYSTEMS
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 1: Marker & Notification Systems";
    
    [] execVM "functions\markers\markerSystem.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_markers"};
    systemChat "[TWS] ✓ Marker System loaded";
    
    [] execVM "functions\markers\notificationSystem.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_notifications"};
    systemChat "[TWS] ✓ Notification System loaded";
    
    // Create initial markers for all objects
    sleep 2;
    if (!isNil "TWS_fnc_createAllObjectMarkers") then {
        [] call TWS_fnc_createAllObjectMarkers;
        systemChat "[TWS] ✓ Initial object markers created";
    };
    
    // ===============================================================
    // PHASE 2: ENHANCED COMBAT MONITORING
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 2: Combat Monitoring";
    
    [] execVM "functions\combat\enhancedCombatMonitor.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_combat"};
    systemChat "[TWS] ✓ Enhanced Combat Monitor loaded";
    
    // ===============================================================
    // PHASE 3: SECTOR AREA SYSTEM
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 3: Sector Area System";
    
    [] execVM "functions\sectors\sectorAreaSystem.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_sectorAreas"};
    systemChat "[TWS] ✓ Sector Area System loaded";
    
    // Register initial sector areas from existing sectors
    sleep 1;
    if (!isNil "TWS_fnc_registerSectorArea") then {
        // Auto-register sectors from sector management system
        private _allSectorData = TWS_sectors getOrDefault ["sectorData", createHashMap];
        {
            private _sectorID = _x;
            private _sectorData = _y;
            private _position = _sectorData getOrDefault ["position", [0,0,0]];
            
            if (!(_position isEqualTo [0,0,0])) then {
                [_sectorID, _position, objNull, "OPFOR"] call TWS_fnc_registerSectorArea;
            };
        } forEach _allSectorData;
        
        systemChat "[TWS] ✓ Sector areas registered";
    };
    
    // ===============================================================
    // PHASE 4: LOGISTICS ENHANCEMENTS
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 4: Logistics Systems";
    
    [] execVM "functions\logistics\dynamicResupply.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_resupply"};
    systemChat "[TWS] ✓ Dynamic Resupply System loaded";
    
    [] execVM "functions\logistics\manpowerResupply.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_manpowerResupply"};
    systemChat "[TWS] ✓ Manpower Resupply System loaded";
    
    [] execVM "functions\logistics\enhancedProduction.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_enhancedProduction"};
    systemChat "[TWS] ✓ Enhanced Production System loaded";
    
    // ===============================================================
    // PHASE 5: DYNAMIC REINFORCEMENTS
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 5: Reinforcement Systems";
    
    [] execVM "functions\reinforcements\dynamicReinforcements.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_reinforcements"};
    systemChat "[TWS] ✓ Dynamic Reinforcement System loaded";
    
    // ===============================================================
    // PHASE 6: COMMUNICATION GRID ENHANCEMENTS
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 6: Communication Grid";
    
    [] execVM "functions\core\communicationEnhanced.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_commGrid"};
    systemChat "[TWS] ✓ Enhanced Communication Grid loaded";
    
    // ===============================================================
    // PHASE 7: ENHANCED RADAR AND AIR DEFENSE
    // ===============================================================
    diag_log "[TWS] Enhanced Phase 7: Radar & Air Defense";
    
    [] execVM "functions\radarAir\enhancedRadarSystem.sqf";
    waitUntil {sleep 0.5; !isNil "TWS_radarSystem"};
    systemChat "[TWS] ✓ Enhanced Radar System loaded";
    
    // Register existing radar objects
    sleep 1;
    if (!isNil "TWS_fnc_registerRadarSite") then {
        // Register OPFOR radar if it exists
        if (!isNil "radar_1") then {
            [radar_1, "OPFOR", 5000] call TWS_fnc_registerRadarSite;
            systemChat "[TWS] ✓ Registered radar_1 (OPFOR)";
        };
        
        // Register BLUFOR radar if it exists
        if (!isNil "radar_2") then {
            [radar_2, "BLUFOR", 5000] call TWS_fnc_registerRadarSite;
            systemChat "[TWS] ✓ Registered radar_2 (BLUFOR)";
        };
    };
    
    // ===============================================================
    // FINALIZATION
    // ===============================================================
    sleep 2;
    
    // Display initialization summary
    systemChat "========================================";
    systemChat "[TWS] ENHANCED SYSTEMS INITIALIZED";
    systemChat "========================================";
    systemChat "[TWS] Marker System: Active";
    systemChat "[TWS] Notification System: Active";
    systemChat "[TWS] Enhanced Combat Monitor: Active";
    systemChat "[TWS]   - Casualty summaries every 2 minutes";
    systemChat "[TWS]   - Combat markers with squad IDs";
    systemChat "[TWS] Sector Area System: Active";
    systemChat "[TWS]   - Scanning every 60 seconds";
    systemChat "[TWS]   - 3-state control tracking";
    systemChat "[TWS] Dynamic Resupply: Active";
    systemChat "[TWS]   - Convoy dispatch every 5 minutes";
    systemChat "[TWS] Manpower Resupply: Active";
    systemChat "[TWS]   - Triggers every 100 casualties";
    systemChat "[TWS] Enhanced Production: Active";
    systemChat "[TWS]   - Vehicle loss tracking";
    systemChat "[TWS]   - Production cycles every 10 minutes";
    systemChat "[TWS] Dynamic Reinforcements: Active";
    systemChat "[TWS]   - FOB and main base spawning";
    systemChat "[TWS]   - Manpower-based deployment";
    systemChat "[TWS] Communication Grid: Active";
    systemChat "[TWS]   - Performance degradation on damage";
    systemChat "[TWS] Enhanced Radar System: Active";
    systemChat "[TWS]   - Airspace monitoring and scramble orders";
    systemChat "[TWS]   - Sortie management and tracking";
    systemChat "========================================";
    
    diag_log "[TWS] ========== Enhanced TWS Initialization Complete ==========";
    diag_log "[TWS] All enhanced systems operational";
    diag_log "[TWS] Marker system active with object tracking";
    diag_log "[TWS] Notification system active with event tracking";
    diag_log "[TWS] Combat monitor active with 2-minute summaries";
    diag_log "[TWS] Sector system active with per-minute scanning";
    diag_log "[TWS] Resupply systems active (ground and air)";
    diag_log "[TWS] Production system active with loss tracking";
    diag_log "[TWS] Reinforcement system active with FOB support";
    diag_log "[TWS] Communication grid active with degradation";
    diag_log "[TWS] Enhanced radar system active with sortie management";
    diag_log "[TWS] ==========================================================";
    
    // Set global flag
    TWS_enhancedInitialized = true;
    publicVariable "TWS_enhancedInitialized";
    
    // Initial notification
    if (!isNil "TWS_fnc_notify") then {
        ["general", "Total War Simulation Enhanced Systems Online", [0,0,0], false] call TWS_fnc_notify;
    };
};
