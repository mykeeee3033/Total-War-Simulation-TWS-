/*
 * worldState_custom.sqf
 * Custom World State Model for ALiVE Integration
 * 
 * Purpose: Store only what ALiVE does NOT handle:
 * - Factory output and production rates
 * - Resource stockpiles (ammo, fuel, materials)
 * - Custom supply levels
 * - Radar site operational states
 * - Command center states
 * - Geopolitical parameters
 *
 * ALiVE already handles: frontlines, positions, units, threats, persistent combat
 */

if (isServer) then {
    // Initialize global world state if not already initialized
    if (isNil "TWS_worldState") then {
        TWS_worldState = createHashMap;
        
        // Factory system
        TWS_worldState set ["factories", createHashMap];
        TWS_worldState set ["factoryProduction", createHashMap];
        
        // Resource stockpiles (global per faction)
        TWS_worldState set ["resources", createHashMap];
        (TWS_worldState get "resources") set ["BLUFOR", createHashMap];
        (TWS_worldState get "resources") set ["OPFOR", createHashMap];
        
        // Initialize BLUFOR resources
        private _bluforRes = (TWS_worldState get "resources") get "BLUFOR";
        _bluforRes set ["ammunition", 10000];
        _bluforRes set ["fuel", 5000];
        _bluforRes set ["materials", 2000];
        _bluforRes set ["vehicles", 50];
        _bluforRes set ["aircraft", 20];
        
        // Initialize OPFOR resources
        private _opforRes = (TWS_worldState get "resources") get "OPFOR";
        _opforRes set ["ammunition", 10000];
        _opforRes set ["fuel", 5000];
        _opforRes set ["materials", 2000];
        _opforRes set ["vehicles", 50];
        _opforRes set ["aircraft", 20];
        
        // Radar sites state
        TWS_worldState set ["radarSites", createHashMap];
        
        // Command centers state
        TWS_worldState set ["commandCenters", createHashMap];
        
        // Geopolitical parameters
        TWS_worldState set ["geopolitics", createHashMap];
        private _geoPol = TWS_worldState get "geopolitics";
        _geoPol set ["tension", 0.5]; // 0.0 to 1.0
        _geoPol set ["foreignSupport_BLUFOR", 1.0];
        _geoPol set ["foreignSupport_OPFOR", 1.0];
        _geoPol set ["sanctions_BLUFOR", 0.0];
        _geoPol set ["sanctions_OPFOR", 0.0];
        
        // Operational tempo tracking
        TWS_worldState set ["tempo", createHashMap];
        (TWS_worldState get "tempo") set ["BLUFOR", 1.0]; // 0.0 to 2.0
        (TWS_worldState get "tempo") set ["OPFOR", 1.0];
        
        systemChat "[TWS] World State initialized";
        diag_log "[TWS] World State initialized";
    };
    
    // Function to get faction resources
    TWS_fnc_getResources = {
        params ["_faction"];
        private _resources = TWS_worldState get "resources";
        _resources get _faction
    };
    
    // Function to modify faction resources
    TWS_fnc_modifyResource = {
        params ["_faction", "_resourceType", "_amount"];
        private _resources = [_faction] call TWS_fnc_getResources;
        private _current = _resources getOrDefault [_resourceType, 0];
        private _new = (_current + _amount) max 0;
        _resources set [_resourceType, _new];
        _new
    };
    
    // Function to consume resources
    TWS_fnc_consumeResource = {
        params ["_faction", "_resourceType", "_amount"];
        private _resources = [_faction] call TWS_fnc_getResources;
        private _current = _resources getOrDefault [_resourceType, 0];
        if (_current >= _amount) then {
            _resources set [_resourceType, _current - _amount];
            true
        } else {
            false
        }
    };
    
    // Function to get operational tempo
    TWS_fnc_getTempo = {
        params ["_faction"];
        private _tempo = TWS_worldState get "tempo";
        _tempo getOrDefault [_faction, 1.0]
    };
    
    // Function to set operational tempo
    TWS_fnc_setTempo = {
        params ["_faction", "_value"];
        private _tempo = TWS_worldState get "tempo";
        _tempo set [_faction, (_value max 0.1) min 2.0];
    };
    
    // Function to register a factory
    TWS_fnc_registerFactory = {
        params ["_factoryObject", "_faction", "_type", "_productionRate"];
        private _factories = TWS_worldState get "factories";
        private _factoryData = createHashMap;
        _factoryData set ["object", _factoryObject];
        _factoryData set ["faction", _faction];
        _factoryData set ["type", _type];
        _factoryData set ["baseProductionRate", _productionRate];
        _factoryData set ["currentProductionRate", _productionRate];
        _factoryData set ["operational", true];
        _factoryData set ["damage", 0];
        _factories set [str _factoryObject, _factoryData];
        
        diag_log format ["[TWS] Registered factory: %1 (%2) for %3", _type, _factoryObject, _faction];
    };
    
    // Function to register a radar site
    TWS_fnc_registerRadar = {
        params ["_radarObject", "_faction", "_range"];
        private _radarSites = TWS_worldState get "radarSites";
        private _radarData = createHashMap;
        _radarData set ["object", _radarObject];
        _radarData set ["faction", _faction];
        _radarData set ["range", _range];
        _radarData set ["operational", true];
        _radarData set ["damage", 0];
        _radarSites set [str _radarObject, _radarData];
        
        diag_log format ["[TWS] Registered radar: %1 for %2 (range: %3m)", _radarObject, _faction, _range];
    };
    
    // Function to register a command center
    TWS_fnc_registerCommandCenter = {
        params ["_ccObject", "_faction"];
        private _commandCenters = TWS_worldState get "commandCenters";
        private _ccData = createHashMap;
        _ccData set ["object", _ccObject];
        _ccData set ["faction", _faction];
        _ccData set ["operational", true];
        _ccData set ["damage", 0];
        _commandCenters set [str _ccObject, _ccData];
        
        diag_log format ["[TWS] Registered command center: %1 for %2", _ccObject, _faction];
    };
    
    // Function to get world state summary
    TWS_fnc_getWorldStateSummary = {
        private _summary = createHashMap;
        
        // Get resource counts
        private _resources = TWS_worldState get "resources";
        _summary set ["resources", _resources];
        
        // Get factory status
        private _factories = TWS_worldState get "factories";
        private _factoryStatus = createHashMap;
        {
            private _data = _y;
            if (_data get "operational") then {
                private _faction = _data get "faction";
                private _type = _data get "type";
                private _count = _factoryStatus getOrDefault [_faction + "_" + _type, 0];
                _factoryStatus set [_faction + "_" + _type, _count + 1];
            };
        } forEach _factories;
        _summary set ["factoryStatus", _factoryStatus];
        
        // Get tempo
        private _tempo = TWS_worldState get "tempo";
        _summary set ["tempo", _tempo];
        
        _summary
    };
    
    publicVariable "TWS_worldState";
    publicVariable "TWS_fnc_getResources";
    publicVariable "TWS_fnc_modifyResource";
    publicVariable "TWS_fnc_consumeResource";
    publicVariable "TWS_fnc_getTempo";
    publicVariable "TWS_fnc_setTempo";
    publicVariable "TWS_fnc_registerFactory";
    publicVariable "TWS_fnc_registerRadar";
    publicVariable "TWS_fnc_registerCommandCenter";
    publicVariable "TWS_fnc_getWorldStateSummary";
    
    diag_log "[TWS] World State functions published";
};
