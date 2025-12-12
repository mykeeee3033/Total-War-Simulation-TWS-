/*
 * communicationEnhanced.sqf
 * Enhanced Communication/Electrical Grid System
 * 
 * Features:
 * - Ownership detection based on sector control
 * - AI performance degradation when comm/power destroyed
 * - Integration with reinforcement and support systems
 * - Electricity requirements for factories
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_objectRoles"};
    
    diag_log "[TWS] Initializing enhanced communication/electrical grid...";
    systemChat "[TWS] Initializing enhanced communication/electrical grid...";
    
    // Communication grid state
    TWS_commGrid = createHashMap;
    TWS_commGrid set ["enabled", true];
    TWS_commGrid set ["checkInterval", 60]; // Check every minute
    
    // Faction grid status
    TWS_commGrid set ["BLUFOR_status", createHashMap];
    TWS_commGrid set ["OPFOR_status", createHashMap];
    
    {
        private _faction = _x;
        private _status = TWS_commGrid get format ["%1_status", _faction];
        _status set ["antennas", 0];
        _status set ["powerStations", 0];
        _status set ["hqNodes", 0];
        _status set ["gridIntegrity", 1.0]; // 0.0-1.0
        _status set ["performancePenalty", 0.0]; // 0.0-1.0 (higher = worse performance)
    } forEach ["BLUFOR", "OPFOR"];
    
    // Function to update grid status for faction
    TWS_fnc_updateCommGrid = {
        params ["_faction"];
        
        private _status = TWS_commGrid get format ["%1_status", _faction];
        
        // Count operational objects
        private _antennas = count (["antenna", _faction] call TWS_fnc_getOperationalObjects);
        private _powerStations = count (["powerStation", _faction] call TWS_fnc_getOperationalObjects);
        private _hqNodes = count (["hqNode", _faction] call TWS_fnc_getOperationalObjects);
        
        _status set ["antennas", _antennas];
        _status set ["powerStations", _powerStations];
        _status set ["hqNodes", _hqNodes];
        
        // Calculate grid integrity (0-1 scale)
        // Need at least 1 antenna, 1 power station, 1 HQ for full integrity
        private _integrity = 0.0;
        
        if (_antennas > 0 && _powerStations > 0 && _hqNodes > 0) then {
            _integrity = 1.0;
        } else {
            // Partial integrity based on what's available
            private _antennaScore = (_antennas min 3) / 3.0 * 0.4;
            private _powerScore = (_powerStations min 2) / 2.0 * 0.3;
            private _hqScore = (_hqNodes min 1) / 1.0 * 0.3;
            _integrity = _antennaScore + _powerScore + _hqScore;
        };
        
        _status set ["gridIntegrity", _integrity];
        
        // Calculate performance penalty (inverse of integrity)
        private _penalty = 1.0 - _integrity;
        _status set ["performancePenalty", _penalty];
        
        diag_log format ["[TWS] %1 grid status: Antennas=%2, Power=%3, HQ=%4, Integrity=%.2f, Penalty=%.2f", 
            _faction, _antennas, _powerStations, _hqNodes, _integrity, _penalty];
    };
    
    // Function to check if faction can operate effectively
    TWS_fnc_canOperateEffectively = {
        params ["_faction"];
        
        private _status = TWS_commGrid get format ["%1_status", _faction];
        private _integrity = _status getOrDefault ["gridIntegrity", 1.0];
        
        // Can operate if integrity > 0.3
        _integrity > 0.3
    };
    
    // Function to apply performance degradation
    TWS_fnc_applyPerformanceDegradation = {
        params ["_faction"];
        
        if (!([_faction] call TWS_fnc_canOperateEffectively)) then {
            // Faction cannot operate effectively
            systemChat format ["[TWS] WARNING: %1 communication grid compromised!", _faction];
            systemChat format ["[TWS] %1 reinforcements and support systems degraded", _faction];
            
            // Increase cooldowns for reinforcements
            if (!isNil "TWS_reinforcements") then {
                private _normalCooldown = 180;
                private _status = TWS_commGrid get format ["%1_status", _faction];
                private _penalty = _status getOrDefault ["performancePenalty", 0.0];
                
                // Increase cooldown by up to 300% when grid is down
                private _newCooldown = _normalCooldown * (1.0 + (_penalty * 3.0));
                TWS_reinforcements set ["cooldown", _newCooldown];
                
                diag_log format ["[TWS] %1 reinforcement cooldown increased to %2 seconds due to grid damage", _faction, _newCooldown];
            };
        };
    };
    
    // Communication grid update loop
    TWS_fnc_commGridLoop = {
        while {TWS_commGrid get "enabled"} do {
            // Update grid status for each faction
            {
                private _faction = _x;
                [_faction] call TWS_fnc_updateCommGrid;
                [_faction] call TWS_fnc_applyPerformanceDegradation;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (TWS_commGrid get "checkInterval");
        };
    };
    
    // Start grid monitoring
    [] spawn TWS_fnc_commGridLoop;
    
    // Function to get grid status
    TWS_fnc_getGridStatus = {
        params ["_faction"];
        
        TWS_commGrid get format ["%1_status", _faction]
    };
    
    // Function to toggle comm grid
    TWS_fnc_toggleCommGrid = {
        params ["_enable"];
        
        TWS_commGrid set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Communication grid monitoring enabled";
            [] spawn TWS_fnc_commGridLoop;
        } else {
            systemChat "[TWS] Communication grid monitoring disabled";
        };
    };
    
    // Make public
    publicVariable "TWS_commGrid";
    publicVariable "TWS_fnc_updateCommGrid";
    publicVariable "TWS_fnc_canOperateEffectively";
    publicVariable "TWS_fnc_applyPerformanceDegradation";
    publicVariable "TWS_fnc_getGridStatus";
    publicVariable "TWS_fnc_toggleCommGrid";
    
    systemChat "[TWS] Enhanced communication/electrical grid initialized";
    diag_log "[TWS] Enhanced communication/electrical grid system initialized";
};
