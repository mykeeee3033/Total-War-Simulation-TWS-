/*
 * customLogistics.sqf
 * Production & Supply Logic
 * 
 * Purpose: Extend ALiVE's limited logistics with:
 * - Ammunition production
 * - Fuel production
 * - Vehicle fabrication rates
 * - Aircraft generation/repair
 * - Supply deficits that affect ALiVE OPCOM's operational capacity
 * 
 * Mechanics:
 * - If ammo < threshold → OPCOM offensive tempo decreases
 * - If fuel < threshold → vehicle usage reduced
 * - Destroyed factories = reduced operational tempo
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_objectRoles"};
    
    // Logistics configuration
    TWS_logisticsConfig = createHashMap;
    TWS_logisticsConfig set ["productionInterval", 300]; // 5 minutes (300 seconds)
    TWS_logisticsConfig set ["consumptionInterval", 600]; // 10 minutes
    TWS_logisticsConfig set ["enabled", true];
    
    // Resource thresholds that affect operational tempo
    TWS_resourceThresholds = createHashMap;
    TWS_resourceThresholds set ["critical", 500]; // Below this: tempo = 0.3
    TWS_resourceThresholds set ["low", 2000]; // Below this: tempo = 0.6
    TWS_resourceThresholds set ["normal", 5000]; // Above this: tempo = 1.0
    TWS_resourceThresholds set ["abundant", 10000]; // Above this: tempo = 1.5
    
    // Consumption rates per interval (passive drain)
    TWS_consumptionRates = createHashMap;
    TWS_consumptionRates set ["BLUFOR", createHashMap];
    TWS_consumptionRates set ["OPFOR", createHashMap];
    
    (TWS_consumptionRates get "BLUFOR") set ["ammunition", 50]; // Units consumed per interval
    (TWS_consumptionRates get "BLUFOR") set ["fuel", 30];
    (TWS_consumptionRates get "BLUFOR") set ["materials", 10];
    
    (TWS_consumptionRates get "OPFOR") set ["ammunition", 50];
    (TWS_consumptionRates get "OPFOR") set ["fuel", 30];
    (TWS_consumptionRates get "OPFOR") set ["materials", 10];
    
    // Production loop
    TWS_fnc_productionLoop = {
        private _interval = TWS_logisticsConfig get "productionInterval";
        
        while {TWS_logisticsConfig get "enabled"} do {
            // Process each faction
            {
                private _faction = _x;
                [_faction] call TWS_fnc_processProduction;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep _interval;
        };
    };
    
    // Process production for a faction
    TWS_fnc_processProduction = {
        params ["_faction"];
        
        private _factories = TWS_worldState get "factories";
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Track production this cycle
        private _produced = createHashMap;
        _produced set ["ammunition", 0];
        _produced set ["fuel", 0];
        _produced set ["vehicles", 0];
        _produced set ["aircraft", 0];
        
        // Process each factory
        {
            private _factoryData = _y;
            
            if ((_factoryData get "faction") == _faction && 
                (_factoryData get "operational")) then {
                
                private _type = _factoryData get "type";
                private _rate = _factoryData get "currentProductionRate";
                
                // Calculate production (rate is per hour, interval is in seconds)
                private _productionAmount = _rate * ((TWS_logisticsConfig get "productionInterval") / 3600);
                
                // Check if we have materials for production
                private _materialCost = 0;
                private _fuelCost = 0;
                
                private _roleDef = TWS_roleDefinitions getOrDefault [_type + "Factory", createHashMap];
                if (count _roleDef == 0) then {
                    _roleDef = TWS_roleDefinitions getOrDefault [_type + "Refinery", createHashMap];
                };
                if (count _roleDef == 0) then {
                    _roleDef = TWS_roleDefinitions getOrDefault [_type + "Plant", createHashMap];
                };
                
                if (count _roleDef > 0) then {
                    _materialCost = (_roleDef getOrDefault ["materialCost", 0]) * _productionAmount;
                    _fuelCost = (_roleDef getOrDefault ["fuelCost", 0]) * _productionAmount;
                    
                    // Check if we can afford production
                    private _canProduce = true;
                    if (_materialCost > 0) then {
                        private _materials = _resources getOrDefault ["materials", 0];
                        if (_materials < _materialCost) then {
                            _canProduce = false;
                        };
                    };
                    
                    if (_canProduce && _fuelCost > 0 && _type != "fuel") then {
                        private _fuel = _resources getOrDefault ["fuel", 0];
                        if (_fuel < _fuelCost) then {
                            _canProduce = false;
                        };
                    };
                    
                    if (_canProduce) then {
                        // Consume materials
                        if (_materialCost > 0) then {
                            [_faction, "materials", -_materialCost] call TWS_fnc_modifyResource;
                        };
                        if (_fuelCost > 0 && _type != "fuel") then {
                            [_faction, "fuel", -_fuelCost] call TWS_fnc_modifyResource;
                        };
                        
                        // Add production
                        switch (_type) do {
                            case "munitions": {
                                [_faction, "ammunition", _productionAmount] call TWS_fnc_modifyResource;
                                private _current = _produced getOrDefault ["ammunition", 0];
                                _produced set ["ammunition", _current + _productionAmount];
                            };
                            case "fuel": {
                                [_faction, "fuel", _productionAmount] call TWS_fnc_modifyResource;
                                private _current = _produced getOrDefault ["fuel", 0];
                                _produced set ["fuel", _current + _productionAmount];
                            };
                            case "vehicles": {
                                [_faction, "vehicles", _productionAmount] call TWS_fnc_modifyResource;
                                private _current = _produced getOrDefault ["vehicles", 0];
                                _produced set ["vehicles", _current + _productionAmount];
                            };
                            case "aircraft": {
                                [_faction, "aircraft", _productionAmount] call TWS_fnc_modifyResource;
                                private _current = _produced getOrDefault ["aircraft", 0];
                                _produced set ["aircraft", _current + _productionAmount];
                            };
                        };
                    };
                };
            };
        } forEach _factories;
        
        // Log production summary
        if (_produced get "ammunition" > 0 || _produced get "fuel" > 0 || 
            _produced get "vehicles" > 0 || _produced get "aircraft" > 0) then {
            diag_log format ["[TWS] %1 Production - Ammo: %2, Fuel: %3, Vehicles: %4, Aircraft: %5",
                _faction, 
                _produced get "ammunition",
                _produced get "fuel",
                _produced get "vehicles",
                _produced get "aircraft"
            ];
        };
    };
    
    // Consumption loop
    TWS_fnc_consumptionLoop = {
        private _interval = TWS_logisticsConfig get "consumptionInterval";
        
        while {TWS_logisticsConfig get "enabled"} do {
            // Process each faction
            {
                private _faction = _x;
                [_faction] call TWS_fnc_processConsumption;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep _interval;
        };
    };
    
    // Process resource consumption for a faction
    TWS_fnc_processConsumption = {
        params ["_faction"];
        
        private _rates = TWS_consumptionRates get _faction;
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Consume resources
        {
            private _resourceType = _x;
            private _amount = _y;
            
            // Scale consumption by current operational tempo
            private _tempo = [_faction] call TWS_fnc_getTempo;
            private _scaledAmount = _amount * _tempo;
            
            [_faction, _resourceType, -_scaledAmount] call TWS_fnc_modifyResource;
        } forEach _rates;
        
        // Update operational tempo based on resource levels
        [_faction] call TWS_fnc_updateTempo;
    };
    
    // Update operational tempo based on current resource levels
    TWS_fnc_updateTempo = {
        params ["_faction"];
        
        private _resources = [_faction] call TWS_fnc_getResources;
        private _thresholds = TWS_resourceThresholds;
        
        // Check critical resources (ammo and fuel)
        private _ammo = _resources getOrDefault ["ammunition", 0];
        private _fuel = _resources getOrDefault ["fuel", 0];
        
        private _newTempo = 1.0;
        
        // Determine tempo based on lowest critical resource
        private _minResource = _ammo min _fuel;
        
        if (_minResource < (_thresholds get "critical")) then {
            _newTempo = 0.3;
        } else {
            if (_minResource < (_thresholds get "low")) then {
                _newTempo = 0.6;
            } else {
                if (_minResource > (_thresholds get "abundant")) then {
                    _newTempo = 1.5;
                } else {
                    if (_minResource > (_thresholds get "normal")) then {
                        _newTempo = 1.2;
                    } else {
                        _newTempo = 1.0;
                    };
                };
            };
        };
        
        // Apply tempo
        [_faction, _newTempo] call TWS_fnc_setTempo;
        
        // Log significant tempo changes
        if (_newTempo < 0.7 || _newTempo > 1.3) then {
            diag_log format ["[TWS] %1 operational tempo changed to %2 (Ammo: %3, Fuel: %4)",
                _faction, _newTempo, _ammo, _fuel];
        };
    };
    
    // Function to get logistics status report
    TWS_fnc_getLogisticsStatus = {
        params ["_faction"];
        
        private _status = createHashMap;
        private _resources = [_faction] call TWS_fnc_getResources;
        
        _status set ["resources", _resources];
        _status set ["tempo", [_faction] call TWS_fnc_getTempo];
        
        // Count operational factories
        private _factories = TWS_worldState get "factories";
        private _factoryCounts = createHashMap;
        {
            private _data = _y;
            if ((_data get "faction") == _faction && (_data get "operational")) then {
                private _type = _data get "type";
                private _count = _factoryCounts getOrDefault [_type, 0];
                _factoryCounts set [_type, _count + 1];
            };
        } forEach _factories;
        _status set ["operationalFactories", _factoryCounts];
        
        _status
    };
    
    // Start production and consumption loops
    [] spawn TWS_fnc_productionLoop;
    [] spawn TWS_fnc_consumptionLoop;
    
    publicVariable "TWS_logisticsConfig";
    publicVariable "TWS_resourceThresholds";
    publicVariable "TWS_consumptionRates";
    publicVariable "TWS_fnc_processProduction";
    publicVariable "TWS_fnc_processConsumption";
    publicVariable "TWS_fnc_updateTempo";
    publicVariable "TWS_fnc_getLogisticsStatus";
    
    systemChat "[TWS] Custom Logistics system started";
    diag_log "[TWS] Custom Logistics system initialized and running";
};
