/*
 * civilianEconomy.sqf
 * Optional Civilian Economy Simulation
 * 
 * Purpose: Simulate civilian economic systems that can affect military operations:
 * - Power grid status
 * - Fuel distribution to civilians
 * - Infrastructure damage effects
 * - Civilian morale
 * 
 * Only implement if you want depth beyond military simulation
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    // Civilian economy configuration
    TWS_civilianEconomyConfig = createHashMap;
    TWS_civilianEconomyConfig set ["enabled", false]; // Optional - disabled by default
    TWS_civilianEconomyConfig set ["updateInterval", 600]; // 10 minutes
    
    // Civilian economy state
    TWS_civilianEconomy = createHashMap;
    
    // Initialize per faction
    {
        private _faction = _x;
        private _economy = createHashMap;
        
        _economy set ["powerGridStatus", 1.0]; // 0.0 to 1.0
        _economy set ["fuelAvailability", 1.0];
        _economy set ["foodSecurity", 1.0];
        _economy set ["civilianMorale", 0.7]; // 0.0 to 1.0
        _economy set ["infrastructureDamage", 0.0]; // 0.0 to 1.0
        
        TWS_civilianEconomy set [_faction, _economy];
    } forEach ["BLUFOR", "OPFOR"];
    
    // Function to update civilian economy
    TWS_fnc_updateCivilianEconomy = {
        params ["_faction"];
        
        private _economy = TWS_civilianEconomy get _faction;
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Power grid affected by power stations
        private _powerStations = ["powerStation", _faction] call TWS_fnc_getOperationalObjects;
        private _powerStatus = ((count _powerStations) min 3) / 3.0;
        _economy set ["powerGridStatus", _powerStatus];
        
        // Fuel availability
        private _fuel = _resources getOrDefault ["fuel", 0];
        private _fuelStatus = (_fuel / (TWS_resourceThresholds get "normal")) min 1.0;
        _economy set ["fuelAvailability", _fuelStatus];
        
        // Infrastructure damage from combat
        private _infrastructureDamage = _economy getOrDefault ["infrastructureDamage", 0.0];
        
        // Civilian morale calculation
        private _morale = 0.5; // Base
        _morale = _morale + (_powerStatus * 0.2);
        _morale = _morale + (_fuelStatus * 0.1);
        _morale = _morale - (_infrastructureDamage * 0.3);
        _morale = (_morale max 0.0) min 1.0;
        _economy set ["civilianMorale", _morale];
        
        // Civilian economy affects military
        // Low morale reduces production efficiency
        if (_morale < 0.4) then {
            private _factories = TWS_worldState get "factories";
            {
                private _data = _y;
                if ((_data get "faction") == _faction) then {
                    private _baseRate = _data get "baseProductionRate";
                    _data set ["currentProductionRate", _baseRate * 0.8];
                };
            } forEach _factories;
        };
        
        // Log significant changes
        if (_morale < 0.3 || _powerStatus < 0.5) then {
            diag_log format ["[TWS] %1 civilian economy: Morale=%2, Power=%3, Fuel=%4",
                _faction, _morale, _powerStatus, _fuelStatus];
        };
    };
    
    // Function to apply infrastructure damage
    TWS_fnc_applyInfrastructureDamage = {
        params ["_faction", "_amount"];
        
        private _economy = TWS_civilianEconomy get _faction;
        private _current = _economy getOrDefault ["infrastructureDamage", 0.0];
        private _new = (_current + _amount) min 1.0;
        _economy set ["infrastructureDamage", _new];
        
        if (_amount > 0.1) then {
            systemChat format ["[TWS] %1 infrastructure damaged", _faction];
        };
    };
    
    // Civilian economy update loop
    TWS_fnc_civilianEconomyLoop = {
        while {TWS_civilianEconomyConfig get "enabled"} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_updateCivilianEconomy;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (TWS_civilianEconomyConfig get "updateInterval");
        };
    };
    
    // Function to get civilian economy status
    TWS_fnc_getCivilianEconomyStatus = {
        params ["_faction"];
        
        private _economy = TWS_civilianEconomy get _faction;
        private _status = createHashMap;
        
        _status set ["powerGrid", _economy get "powerGridStatus"];
        _status set ["fuelAvailability", _economy get "fuelAvailability"];
        _status set ["morale", _economy get "civilianMorale"];
        _status set ["infrastructureDamage", _economy get "infrastructureDamage"];
        
        _status
    };
    
    // Function to enable/disable civilian economy
    TWS_fnc_toggleCivilianEconomy = {
        params ["_enable"];
        
        TWS_civilianEconomyConfig set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Civilian economy simulation enabled";
            [] spawn TWS_fnc_civilianEconomyLoop;
        } else {
            systemChat "[TWS] Civilian economy simulation disabled";
        };
    };
    
    publicVariable "TWS_civilianEconomyConfig";
    publicVariable "TWS_civilianEconomy";
    publicVariable "TWS_fnc_updateCivilianEconomy";
    publicVariable "TWS_fnc_applyInfrastructureDamage";
    publicVariable "TWS_fnc_getCivilianEconomyStatus";
    publicVariable "TWS_fnc_toggleCivilianEconomy";
    
    diag_log "[TWS] Civilian Economy system initialized (disabled by default)";
    diag_log "[TWS] Use '[true] call TWS_fnc_toggleCivilianEconomy' to enable";
};
