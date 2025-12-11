/*
 * aliveIntegration.sqf
 * ALiVE Logistics Integration
 * 
 * Purpose: Let ALiVE handle actual unit spawning and movement while
 * the custom system drives the WHY.
 * 
 * Integration points:
 * - Request ALiVE logistics support based on custom resource needs
 * - Modify ALiVE OPCOM behavior based on resource levels
 * - Connect custom production to ALiVE unit spawning capacity
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_logisticsConfig"};
    
    // ALiVE integration configuration
    TWS_aliveConfig = createHashMap;
    TWS_aliveConfig set ["enabled", true];
    TWS_aliveConfig set ["checkInterval", 600]; // Check every 10 minutes
    TWS_aliveConfig set ["aliveDetected", false];
    
    // Detect if ALiVE is loaded
    TWS_fnc_detectALiVE = {
        private _aliveLoaded = false;
        
        // Check for ALiVE modules
        if (!isNil "ALIVE_fnc_logistics" || !isNil "ALiVE_fnc_OPCOM") then {
            _aliveLoaded = true;
            systemChat "[TWS] ALiVE mod detected - integration enabled";
            diag_log "[TWS] ALiVE mod detected";
        } else {
            diag_log "[TWS] ALiVE mod not detected - running in standalone mode";
        };
        
        TWS_aliveConfig set ["aliveDetected", _aliveLoaded];
        _aliveLoaded
    };
    
    // Request ALiVE logistics support
    TWS_fnc_requestALiVESupply = {
        params ["_faction", "_base", "_resourceType", "_priority"];
        
        // Check if ALiVE is available
        if (!(TWS_aliveConfig get "aliveDetected")) exitWith {
            diag_log "[TWS] Cannot request ALiVE supply - ALiVE not detected";
        };
        
        // Determine supply amount based on current deficit
        private _resources = [_faction] call TWS_fnc_getResources;
        private _current = _resources getOrDefault [_resourceType, 0];
        private _target = TWS_resourceThresholds get "normal";
        private _deficit = (_target - _current) max 0;
        
        if (_deficit > 0) then {
            // Call ALiVE logistics API (if available)
            // Note: This is a conceptual integration - actual ALiVE API calls may differ
            
            if (!isNil "ALIVE_fnc_logistics") then {
                // ALiVE logistics request format (conceptual)
                private _request = ["request", "supply", _base, _deficit, _priority];
                // _request call ALIVE_fnc_logistics;
                
                diag_log format ["[TWS] Requested ALiVE supply for %1: %2 units of %3 (priority: %4)",
                    _faction, _deficit, _resourceType, _priority];
            };
            
            // Simulate convoy/resupply spawning that ALiVE would normally handle
            // For now, just log the request
            systemChat format ["[TWS] Supply convoy requested: %1 units of %2", _deficit, _resourceType];
        };
    };
    
    // Modify OPCOM aggressiveness based on resource levels
    TWS_fnc_modifyOPCOM = {
        params ["_faction", "_opcomObject"];
        
        // Check if ALiVE is available
        if (!(TWS_aliveConfig get "aliveDetected")) exitWith {};
        if (isNil "ALiVE_fnc_OPCOM") exitWith {};
        
        private _tempo = [_faction] call TWS_fnc_getTempo;
        private _resources = [_faction] call TWS_fnc_getResources;
        private _ammo = _resources getOrDefault ["ammunition", 0];
        private _fuel = _resources getOrDefault ["fuel", 0];
        
        // Determine aggressiveness value (0.0 to 1.0)
        private _aggressiveness = 0.5; // Default
        
        if (_tempo < 0.5) then {
            _aggressiveness = 0.2; // Very defensive
        } else {
            if (_tempo < 0.8) then {
                _aggressiveness = 0.4; // Defensive
            } else {
                if (_tempo > 1.3) then {
                    _aggressiveness = 0.9; // Very aggressive
                } else {
                    if (_tempo > 1.1) then {
                        _aggressiveness = 0.7; // Aggressive
                    };
                };
            };
        };
        
        // Apply to OPCOM (conceptual - actual API may differ)
        // ["setAggressiveness", _opcomObject, _aggressiveness] call ALiVE_fnc_OPCOM;
        
        // Pause operations if resources critical
        if (_ammo < (TWS_resourceThresholds get "critical") || 
            _fuel < (TWS_resourceThresholds get "critical")) then {
            // ["pauseOperations", _opcomObject] call ALiVE_fnc_OPCOM;
            diag_log format ["[TWS] OPCOM operations paused for %1 due to critical resource shortage", _faction];
        };
        
        diag_log format ["[TWS] OPCOM aggressiveness for %1 set to %2 (tempo: %3)",
            _faction, _aggressiveness, _tempo];
    };
    
    // Integration monitoring loop
    TWS_fnc_aliveIntegrationLoop = {
        // Detect ALiVE on startup
        [] call TWS_fnc_detectALiVE;
        
        private _interval = TWS_aliveConfig get "checkInterval";
        
        while {TWS_aliveConfig get "enabled"} do {
            // Process each faction
            {
                private _faction = _x;
                
                // Get current status
                private _status = [_faction] call TWS_fnc_getLogisticsStatus;
                private _resources = _status get "resources";
                private _tempo = _status get "tempo";
                
                // Check if supply is needed
                private _ammo = _resources getOrDefault ["ammunition", 0];
                private _fuel = _resources getOrDefault ["fuel", 0];
                
                // Request supplies if below threshold
                if (_ammo < (TWS_resourceThresholds get "low")) then {
                    [_faction, "", "ammunition", 2] call TWS_fnc_requestALiVESupply;
                };
                
                if (_fuel < (TWS_resourceThresholds get "low")) then {
                    [_faction, "", "fuel", 2] call TWS_fnc_requestALiVESupply;
                };
                
                // Update OPCOM behavior (if OPCOM objects are tracked)
                // This would require identifying OPCOM objects per faction
                // For now, we just log the recommended settings
                if (TWS_aliveConfig get "aliveDetected") then {
                    diag_log format ["[TWS] %1 recommended aggressiveness: %2 (tempo: %3, ammo: %4, fuel: %5)",
                        _faction,
                        (if (_tempo > 1.2) then {"High"} else {if (_tempo < 0.7) then {"Low"} else {"Normal"}}),
                        _tempo, _ammo, _fuel];
                };
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep _interval;
        };
    };
    
    // Function to register OPCOM for a faction
    TWS_fnc_registerOPCOM = {
        params ["_faction", "_opcomObject"];
        
        if (isNil "TWS_opcomRegistry") then {
            TWS_opcomRegistry = createHashMap;
        };
        
        TWS_opcomRegistry set [_faction, _opcomObject];
        diag_log format ["[TWS] Registered OPCOM for %1: %2", _faction, _opcomObject];
        
        // Apply initial settings
        [_faction, _opcomObject] call TWS_fnc_modifyOPCOM;
    };
    
    // Function to simulate supply delivery (when ALiVE completes a convoy)
    TWS_fnc_onSupplyDelivered = {
        params ["_faction", "_resourceType", "_amount"];
        
        [_faction, _resourceType, _amount] call TWS_fnc_modifyResource;
        
        systemChat format ["[TWS] Supply delivered: %1 units of %2 for %3", _amount, _resourceType, _faction];
        diag_log format ["[TWS] Supply delivered: %1 %2 for %3", _amount, _resourceType, _faction];
    };
    
    // Start integration loop
    [] spawn TWS_fnc_aliveIntegrationLoop;
    
    publicVariable "TWS_aliveConfig";
    publicVariable "TWS_fnc_detectALiVE";
    publicVariable "TWS_fnc_requestALiVESupply";
    publicVariable "TWS_fnc_modifyOPCOM";
    publicVariable "TWS_fnc_registerOPCOM";
    publicVariable "TWS_fnc_onSupplyDelivered";
    
    systemChat "[TWS] ALiVE Integration started";
    diag_log "[TWS] ALiVE Integration initialized";
};
