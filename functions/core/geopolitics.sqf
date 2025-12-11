/*
 * geopolitics.sqf
 * Optional Geopolitical Event System
 * 
 * Purpose: Simulate external factors affecting the war:
 * - Foreign pressure and support
 * - Escalation mechanics
 * - Sanctions
 * - UN actions
 * - Foreign military aid
 * - Random crisis events
 * 
 * These modify factory output, OPCOM behavior, resources, and tempo
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    // Geopolitics configuration
    TWS_geopoliticsConfig = createHashMap;
    TWS_geopoliticsConfig set ["enabled", false]; // Optional - disabled by default
    TWS_geopoliticsConfig set ["eventInterval", 900]; // 15 minutes
    TWS_geopoliticsConfig set ["eventChance", 0.3]; // 30% chance per check
    
    // Geopolitical event definitions
    TWS_geopoliticalEvents = [];
    
    // Define events
    TWS_fnc_defineGeopoliticalEvents = {
        TWS_geopoliticalEvents = [];
        
        // Foreign military aid
        TWS_geopoliticalEvents pushBack [
            "foreignAid",
            "Foreign Military Aid Package",
            {
                params ["_faction"];
                [_faction, "ammunition", 2000] call TWS_fnc_modifyResource;
                [_faction, "fuel", 1000] call TWS_fnc_modifyResource;
                [_faction, "materials", 500] call TWS_fnc_modifyResource;
                systemChat format ["[TWS] %1 received foreign military aid package", _faction];
                diag_log format ["[TWS] Geopolitics: %1 foreign aid delivered", _faction];
            }
        ];
        
        // Economic sanctions
        TWS_geopoliticalEvents pushBack [
            "sanctions",
            "International Sanctions Imposed",
            {
                params ["_faction"];
                private _geoPol = TWS_worldState get "geopolitics";
                private _currentSanctions = _geoPol getOrDefault ["sanctions_" + _faction, 0];
                _geoPol set ["sanctions_" + _faction, (_currentSanctions + 0.3) min 1.0];
                
                // Reduce production rates
                private _factories = TWS_worldState get "factories";
                {
                    private _data = _y;
                    if ((_data get "faction") == _faction) then {
                        private _baseRate = _data get "baseProductionRate";
                        _data set ["currentProductionRate", _baseRate * 0.7];
                    };
                } forEach _factories;
                
                systemChat format ["[TWS] Economic sanctions imposed on %1", _faction];
                diag_log format ["[TWS] Geopolitics: Sanctions on %1", _faction];
            }
        ];
        
        // Foreign support increase
        TWS_geopoliticalEvents pushBack [
            "supportIncrease",
            "Increased Foreign Support",
            {
                params ["_faction"];
                private _geoPol = TWS_worldState get "geopolitics";
                private _currentSupport = _geoPol getOrDefault ["foreignSupport_" + _faction, 1.0];
                _geoPol set ["foreignSupport_" + _faction, (_currentSupport + 0.2) min 2.0];
                
                // Increase production rates
                private _factories = TWS_worldState get "factories";
                {
                    private _data = _y;
                    if ((_data get "faction") == _faction) then {
                        private _baseRate = _data get "baseProductionRate";
                        private _support = _geoPol get ("foreignSupport_" + _faction);
                        _data set ["currentProductionRate", _baseRate * _support];
                    };
                } forEach _factories;
                
                systemChat format ["[TWS] %1 receives increased foreign support", _faction];
                diag_log format ["[TWS] Geopolitics: Support increase for %1", _faction];
            }
        ];
        
        // Regional crisis
        TWS_geopoliticalEvents pushBack [
            "crisis",
            "Regional Crisis",
            {
                params ["_faction"];
                [_faction, "materials", -500] call TWS_fnc_modifyResource;
                
                private _tempo = [_faction] call TWS_fnc_getTempo;
                [_faction, _tempo * 0.8] call TWS_fnc_setTempo;
                
                systemChat format ["[TWS] Regional crisis affects %1 operations", _faction];
                diag_log format ["[TWS] Geopolitics: Crisis affects %1", _faction];
            }
        ];
        
        // Peace negotiations (reduces aggression)
        TWS_geopoliticalEvents pushBack [
            "negotiations",
            "Peace Negotiations",
            {
                params ["_faction"];
                [_faction, "cautious"] call TWS_fnc_setCommanderPersonality;
                
                private _geoPol = TWS_worldState get "geopolitics";
                private _tension = _geoPol getOrDefault ["tension", 0.5];
                _geoPol set ["tension", (_tension - 0.2) max 0.0];
                
                systemChat format ["[TWS] Peace negotiations affect %1 strategy", _faction];
                diag_log format ["[TWS] Geopolitics: Negotiations affecting %1", _faction];
            }
        ];
        
        // Escalation
        TWS_geopoliticalEvents pushBack [
            "escalation",
            "Conflict Escalation",
            {
                params ["_faction"];
                private _geoPol = TWS_worldState get "geopolitics";
                private _tension = _geoPol getOrDefault ["tension", 0.5];
                _geoPol set ["tension", (_tension + 0.3) min 1.0];
                
                [_faction, "aggressive"] call TWS_fnc_setCommanderPersonality;
                
                systemChat format ["[TWS] Conflict escalation - %1 increases aggression", _faction];
                diag_log format ["[TWS] Geopolitics: Escalation for %1", _faction];
            }
        ];
        
        // Resource discovery
        TWS_geopoliticalEvents pushBack [
            "resourceDiscovery",
            "Resource Discovery",
            {
                params ["_faction"];
                [_faction, "materials", 1000] call TWS_fnc_modifyResource;
                [_faction, "fuel", 500] call TWS_fnc_modifyResource;
                
                systemChat format ["[TWS] %1 discovers new resource deposits", _faction];
                diag_log format ["[TWS] Geopolitics: Resource discovery for %1", _faction];
            }
        ];
    };
    
    [] call TWS_fnc_defineGeopoliticalEvents;
    
    // Function to trigger random geopolitical event
    TWS_fnc_triggerGeopoliticalEvent = {
        private _faction = selectRandom ["BLUFOR", "OPFOR"];
        private _event = selectRandom TWS_geopoliticalEvents;
        
        private _eventID = _event select 0;
        private _eventName = _event select 1;
        private _eventCode = _event select 2;
        
        // Execute event
        [_faction] call _eventCode;
        
        // Log event
        diag_log format ["[TWS] Geopolitical Event: %1 for %2", _eventName, _faction];
    };
    
    // Geopolitics event loop
    TWS_fnc_geopoliticsLoop = {
        while {TWS_geopoliticsConfig get "enabled"} do {
            // Random chance of event
            private _chance = TWS_geopoliticsConfig get "eventChance";
            if (random 1 < _chance) then {
                [] call TWS_fnc_triggerGeopoliticalEvent;
            };
            
            sleep (TWS_geopoliticsConfig get "eventInterval");
        };
    };
    
    // Function to enable/disable geopolitics
    TWS_fnc_toggleGeopolitics = {
        params ["_enable"];
        
        TWS_geopoliticsConfig set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Geopolitical simulation enabled";
            [] spawn TWS_fnc_geopoliticsLoop;
        } else {
            systemChat "[TWS] Geopolitical simulation disabled";
        };
    };
    
    publicVariable "TWS_geopoliticsConfig";
    publicVariable "TWS_geopoliticalEvents";
    publicVariable "TWS_fnc_triggerGeopoliticalEvent";
    publicVariable "TWS_fnc_toggleGeopolitics";
    
    diag_log "[TWS] Geopolitics system initialized (disabled by default)";
    diag_log "[TWS] Use '[true] call TWS_fnc_toggleGeopolitics' to enable";
};
