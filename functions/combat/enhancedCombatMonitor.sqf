/*
 * enhancedCombatMonitor.sqf
 * Enhanced Combat Monitoring with Markers and Casualty Summaries
 * 
 * Features:
 * - Markers for troops in contact with squad identification
 * - 2-minute casualty summary system
 * - Integration with notification system
 * - Per-faction casualty tracking
 * - Combat event markers
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    diag_log "[TWS] Initializing enhanced combat monitor...";
    systemChat "[TWS] Initializing enhanced combat monitor...";
    
    // Combat tracking
    TWS_combat = createHashMap;
    TWS_combat set ["enabled", true];
    TWS_combat set ["summaryInterval", 120]; // 2 minutes
    TWS_combat set ["lastSummaryTime", 0];
    
    // Faction casualties since last summary
    TWS_combat set ["BLUFOR_casualties", 0];
    TWS_combat set ["OPFOR_casualties", 0];
    TWS_combat set ["INDEPENDENT_casualties", 0];
    
    // Total casualties
    TWS_combat set ["BLUFOR_total", 0];
    TWS_combat set ["OPFOR_total", 0];
    TWS_combat set ["INDEPENDENT_total", 0];
    
    // Recent combat positions
    TWS_combat set ["recentCombat", []];
    
    // Function to get squad name from unit
    TWS_fnc_getSquadName = {
        params ["_unit"];
        
        private _group = group _unit;
        private _groupID = groupId _group;
        
        if (_groupID == "") then {
            format ["Squad_%1", _group]
        } else {
            _groupID
        };
    };
    
    // Function to track casualty
    TWS_fnc_trackCasualty = {
        params ["_unit", "_killer"];
        
        private _side = side group _unit;
        private _faction = switch (_side) do {
            case west: {"BLUFOR"};
            case east: {"OPFOR"};
            case resistance: {"INDEPENDENT"};
            default {"UNKNOWN"};
        };
        
        if (_faction == "UNKNOWN") exitWith {};
        
        private _position = getPosATL _unit;
        private _squad = [_unit] call TWS_fnc_getSquadName;
        
        // Increment casualty counters
        private _currentKey = format ["%1_casualties", _faction];
        private _totalKey = format ["%1_total", _faction];
        
        private _current = TWS_combat getOrDefault [_currentKey, 0];
        private _total = TWS_combat getOrDefault [_totalKey, 0];
        
        TWS_combat set [_currentKey, _current + 1];
        TWS_combat set [_totalKey, _total + 1];
        
        // Create combat marker
        if (!isNil "TWS_fnc_createCombatMarker") then {
            [_position, _squad, _faction, 300] call TWS_fnc_createCombatMarker;
        };
        
        // Track for production queue if vehicle
        if (_unit isKindOf "LandVehicle" || _unit isKindOf "Air") then {
            if (!isNil "TWS_fnc_trackVehicleLoss") then {
                [_faction, _unit] call TWS_fnc_trackVehicleLoss;
            };
        };
        
        // Add to recent combat
        private _recentCombat = TWS_combat get "recentCombat";
        _recentCombat pushBack [_faction, _squad, _position, diag_tickTime];
        
        // Keep only last 50 entries
        if (count _recentCombat > 50) then {
            _recentCombat deleteAt 0;
        };
        
        diag_log format ["[TWS] Casualty: %1 from %2 at %3", _faction, _squad, _position];
    };
    
    // Function to generate casualty summary
    TWS_fnc_generateCasualtySummary = {
        private _blufor = TWS_combat getOrDefault ["BLUFOR_casualties", 0];
        private _opfor = TWS_combat getOrDefault ["OPFOR_casualties", 0];
        private _independent = TWS_combat getOrDefault ["INDEPENDENT_casualties", 0];
        
        private _bluforTotal = TWS_combat getOrDefault ["BLUFOR_total", 0];
        private _opforTotal = TWS_combat getOrDefault ["OPFOR_total", 0];
        private _independentTotal = TWS_combat getOrDefault ["INDEPENDENT_total", 0];
        
        // Display summary
        systemChat "========================================";
        systemChat "[TWS] CASUALTY SUMMARY (Last 2 Minutes)";
        systemChat "========================================";
        systemChat format ["BLUFOR: %1 casualties (Total: %2)", _blufor, _bluforTotal];
        systemChat format ["OPFOR: %1 casualties (Total: %2)", _opfor, _opforTotal];
        systemChat format ["INDEPENDENT: %1 casualties (Total: %2)", _independent, _independentTotal];
        systemChat "========================================";
        
        // Log to diag
        diag_log "========================================";
        diag_log "[TWS] CASUALTY SUMMARY (Last 2 Minutes)";
        diag_log format ["BLUFOR: %1 casualties (Total: %2)", _blufor, _bluforTotal];
        diag_log format ["OPFOR: %1 casualties (Total: %2)", _opfor, _opforTotal];
        diag_log format ["INDEPENDENT: %1 casualties (Total: %2)", _independent, _independentTotal];
        diag_log "========================================";
        
        // Reset interval counters
        TWS_combat set ["BLUFOR_casualties", 0];
        TWS_combat set ["OPFOR_casualties", 0];
        TWS_combat set ["INDEPENDENT_casualties", 0];
        TWS_combat set ["lastSummaryTime", diag_tickTime];
        
        // Trigger manpower resupply if needed (every 100 OPFOR casualties)
        if (_opforTotal > 0 && (_opforTotal mod 100) < _opfor) then {
            if (!isNil "TWS_fnc_triggerManpowerResupply") then {
                ["OPFOR"] call TWS_fnc_triggerManpowerResupply;
            };
        };
    };
    
    // Function to get recent combat positions
    TWS_fnc_getRecentCombat = {
        params [["_faction", ""], ["_timeWindow", 300]];
        
        private _recentCombat = TWS_combat get "recentCombat";
        private _currentTime = diag_tickTime;
        
        private _filtered = _recentCombat select {
            (_currentTime - (_x select 3)) <= _timeWindow &&
            (_faction == "" || (_x select 0) == _faction)
        };
        
        _filtered
    };
    
    // Set up entity killed event handler
    addMissionEventHandler ["EntityKilled", {
        params ["_unit", "_killer", "_instigator", "_useEffects"];
        
        // Track the casualty
        [_unit, _killer] call TWS_fnc_trackCasualty;
    }];
    
    // Casualty summary loop
    TWS_fnc_casualtySummaryLoop = {
        while {TWS_combat get "enabled"} do {
            sleep (TWS_combat get "summaryInterval");
            
            [] call TWS_fnc_generateCasualtySummary;
        };
    };
    
    // Start summary loop
    [] spawn TWS_fnc_casualtySummaryLoop;
    
    // Function to toggle combat monitoring
    TWS_fnc_toggleCombatMonitoring = {
        params ["_enable"];
        
        TWS_combat set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Combat monitoring enabled";
            [] spawn TWS_fnc_casualtySummaryLoop;
        } else {
            systemChat "[TWS] Combat monitoring disabled";
        };
    };
    
    // Function to get casualty statistics
    TWS_fnc_getCasualtyStats = {
        params [["_faction", ""]];
        
        if (_faction == "") then {
            // Return all stats
            private _stats = createHashMap;
            _stats set ["BLUFOR", TWS_combat getOrDefault ["BLUFOR_total", 0]];
            _stats set ["OPFOR", TWS_combat getOrDefault ["OPFOR_total", 0]];
            _stats set ["INDEPENDENT", TWS_combat getOrDefault ["INDEPENDENT_total", 0]];
            _stats
        } else {
            // Return specific faction
            TWS_combat getOrDefault [format ["%1_total", _faction], 0]
        };
    };
    
    // Make public
    publicVariable "TWS_combat";
    publicVariable "TWS_fnc_getSquadName";
    publicVariable "TWS_fnc_trackCasualty";
    publicVariable "TWS_fnc_generateCasualtySummary";
    publicVariable "TWS_fnc_getRecentCombat";
    publicVariable "TWS_fnc_toggleCombatMonitoring";
    publicVariable "TWS_fnc_getCasualtyStats";
    
    systemChat "[TWS] Enhanced combat monitor initialized";
    systemChat "[TWS] Casualty summaries every 2 minutes";
    diag_log "[TWS] Enhanced combat monitor initialized with 2-minute summaries";
};
