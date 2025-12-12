/*
 * moraleAndTraining.sqf
 * Morale and Training System
 * 
 * Features:
 * - Dynamic morale based on casualties, victories, and supplies
 * - Training system that increases unit skill
 * - Morale affects reinforcement decisions and aggression
 * - Training requires time and resources
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing morale and training system...";
    
    // Initialize morale for each faction
    TWS_morale = createHashMap;
    TWS_morale set ["BLUFOR", 0.7]; // Start at 70% morale
    TWS_morale set ["OPFOR", 0.7];
    
    // Training state
    TWS_trainingState = createHashMap;
    TWS_trainingState set ["BLUFOR", createHashMap];
    TWS_trainingState set ["OPFOR", createHashMap];
    
    {
        private _faction = _x;
        private _state = TWS_trainingState get _faction;
        _state set ["active", false];
        _state set ["completed", 0];
        _state set ["skillBonus", 0.0]; // Accumulated skill bonus
        _state set ["lastTraining", 0];
    } forEach ["BLUFOR", "OPFOR"];
    
    // ============================================================
    // MORALE FUNCTIONS
    // ============================================================
    
    // Function to calculate morale
    TWS_fnc_calculateMorale = {
        params ["_faction"];
        
        private _currentMorale = TWS_morale getOrDefault [_faction, 0.7];
        private _newMorale = 0.5; // Base morale
        
        // Get resources
        private _resources = [_faction] call TWS_fnc_getResources;
        private _ammo = _resources getOrDefault ["ammunition", 0];
        private _fuel = _resources getOrDefault ["fuel", 0];
        private _tempo = [_faction] call TWS_fnc_getTempo;
        
        // Resource abundance boosts morale
        if (_ammo > (TWS_resourceThresholds get "abundant") && 
            _fuel > (TWS_resourceThresholds get "abundant")) then {
            _newMorale = _newMorale + (TWS_moraleModifiers get "supplyAbundant");
        };
        
        // Critical supplies hurt morale
        if (_ammo < (TWS_resourceThresholds get "critical") || 
            _fuel < (TWS_resourceThresholds get "critical")) then {
            _newMorale = _newMorale + (TWS_moraleModifiers get "supplyCritical");
        };
        
        // Casualties affect morale
        if (!isNil "factionStats") then {
            {
                if (_x select 0 == _faction) then {
                    private _casualties = _x select 1;
                    // If casualties are high, morale decreases
                    if (_casualties > 100) then {
                        private _casualtyImpact = ((_casualties - 100) / 500) min 0.3;
                        _newMorale = _newMorale - _casualtyImpact;
                    };
                };
            } forEach factionStats;
        };
        
        // Training completed boosts morale
        private _trainingState = TWS_trainingState get _faction;
        if ((_trainingState get "completed") > 0) then {
            _newMorale = _newMorale + (TWS_moraleModifiers get "trainingBonus");
        };
        
        // Smooth morale changes (don't jump instantly)
        _newMorale = (_currentMorale * 0.7) + (_newMorale * 0.3);
        
        // Clamp between 0 and 1
        _newMorale = (_newMorale max 0.0) min 1.0;
        
        // Update morale
        TWS_morale set [_faction, _newMorale];
        
        diag_log format ["[TWS] %1 morale: %2", _faction, _newMorale];
        
        _newMorale
    };
    
    // Function to get morale status
    TWS_fnc_getMoraleStatus = {
        params ["_faction"];
        
        private _morale = TWS_morale getOrDefault [_faction, 0.7];
        private _status = "normal";
        
        if (_morale < (TWS_moraleThresholds get "broken")) then {
            _status = "broken";
        } else {
            if (_morale < (TWS_moraleThresholds get "low")) then {
                _status = "low";
            } else {
                if (_morale > (TWS_moraleThresholds get "excellent")) then {
                    _status = "excellent";
                } else {
                    if (_morale > (TWS_moraleThresholds get "good")) then {
                        _status = "good";
                    };
                };
            };
        };
        
        [_morale, _status]
    };
    
    // Function to apply morale effects
    TWS_fnc_applyMoraleEffects = {
        params ["_faction"];
        
        private _moraleData = [_faction] call TWS_fnc_getMoraleStatus;
        private _morale = _moraleData select 0;
        private _status = _moraleData select 1;
        
        // Adjust commander personality based on morale
        if (_status == "broken") then {
            ["_faction", "recovery"] call TWS_fnc_setCommanderPersonality;
        } else {
            if (_status == "low") then {
                if (random 1 < 0.3) then {
                    [_faction, "cautious"] call TWS_fnc_setCommanderPersonality;
                };
            } else {
                if (_status == "excellent") then {
                    if (random 1 < 0.3) then {
                        [_faction, "aggressive"] call TWS_fnc_setCommanderPersonality;
                    };
                };
            };
        };
        
        // Log significant morale changes
        if (_status in ["broken", "low", "excellent"]) then {
            systemChat format ["[TWS] %1 morale: %2 (%3)", _faction, _morale, _status];
        };
    };
    
    // ============================================================
    // TRAINING FUNCTIONS
    // ============================================================
    
    // Function to check if training can start
    TWS_fnc_canStartTraining = {
        params ["_faction"];
        
        private _moraleData = [_faction] call TWS_fnc_getMoraleStatus;
        private _morale = _moraleData select 0;
        private _status = _moraleData select 1;
        
        // Morale must be reasonable (OK or better)
        if !(_status in ["normal", "good", "excellent"]) exitWith {false};
        
        // Check if training is already active
        private _trainingState = TWS_trainingState get _faction;
        if (_trainingState get "active") exitWith {false};
        
        // Check if enough time has passed since last training
        private _lastTraining = _trainingState get "lastTraining";
        private _timeSince = time - _lastTraining;
        if (_timeSince < 600) exitWith {false}; // Min 10 minutes between training
        
        // Check if we have manpower to train
        private _resources = [_faction] call TWS_fnc_getResources;
        private _manpower = _resources getOrDefault ["manpower", 0];
        private _trainingCost = TWS_manpowerConfig get "trainingManpowerCost";
        
        if (_manpower < _trainingCost) exitWith {false};
        
        true
    };
    
    // Function to start training
    TWS_fnc_startTraining = {
        params ["_faction"];
        
        if !([_faction] call TWS_fnc_canStartTraining) exitWith {
            diag_log format ["[TWS] %1 cannot start training", _faction];
            false
        };
        
        // Deduct manpower
        private _trainingCost = TWS_manpowerConfig get "trainingManpowerCost";
        if !([_faction, _trainingCost] call TWS_fnc_deductManpower) exitWith {false};
        
        // Mark training as active
        private _trainingState = TWS_trainingState get _faction;
        _trainingState set ["active", true];
        _trainingState set ["startTime", time];
        
        diag_log format ["[TWS] %1 started training cycle", _faction];
        systemChat format ["[TWS] %1 training started", _faction];
        
        // Spawn training completion handler
        [_faction] spawn {
            params ["_faction"];
            
            // Wait for training duration
            private _duration = ["TrainingCycleDuration"] call TWS_fnc_getInterval;
            sleep _duration;
            
            // Complete training
            [_faction] call TWS_fnc_completeTraining;
        };
        
        true
    };
    
    // Function to complete training
    TWS_fnc_completeTraining = {
        params ["_faction"];
        
        private _trainingState = TWS_trainingState get _faction;
        
        // Mark as not active
        _trainingState set ["active", false];
        _trainingState set ["lastTraining", time];
        
        // Increment completed count
        private _completed = (_trainingState get "completed") + 1;
        _trainingState set ["completed", _completed];
        
        // Increase skill bonus
        private _currentBonus = _trainingState get "skillBonus";
        private _newBonus = (_currentBonus + 0.1) min 0.5; // Max +0.5 skill
        _trainingState set ["skillBonus", _newBonus];
        
        // Add manpower back (trained units)
        private _manpowerGain = TWS_manpowerConfig get "trainingManpowerGain";
        [_faction, _manpowerGain, "training"] call TWS_fnc_addManpower;
        
        // Boost morale
        private _currentMorale = TWS_morale getOrDefault [_faction, 0.7];
        TWS_morale set [_faction, (_currentMorale + 0.05) min 1.0];
        
        diag_log format ["[TWS] %1 completed training cycle #%2 (skill bonus: +%3)", _faction, _completed, _newBonus];
        systemChat format ["[TWS] %1 training complete! Skill bonus: +%2", _faction, _newBonus];
    };
    
    // Function to get training bonus for reinforcements
    TWS_fnc_getTrainingBonus = {
        params ["_faction"];
        
        private _trainingState = TWS_trainingState get _faction;
        _trainingState getOrDefault ["skillBonus", 0.0]
    };
    
    // ============================================================
    // UPDATE LOOPS
    // ============================================================
    
    // Morale update loop
    TWS_fnc_moraleUpdateLoop = {
        while {true} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_calculateMorale;
                [_faction] call TWS_fnc_applyMoraleEffects;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["MoraleUpdateInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Training check loop
    TWS_fnc_trainingCheckLoop = {
        while {true} do {
            {
                private _faction = _x;
                
                // Attempt to start training if conditions are met
                if ([_faction] call TWS_fnc_canStartTraining) then {
                    [_faction] call TWS_fnc_startTraining;
                };
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["TrainingCheckInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Start loops
    [] spawn TWS_fnc_moraleUpdateLoop;
    [] spawn TWS_fnc_trainingCheckLoop;
    
    // Make public
    publicVariable "TWS_morale";
    publicVariable "TWS_trainingState";
    publicVariable "TWS_fnc_calculateMorale";
    publicVariable "TWS_fnc_getMoraleStatus";
    publicVariable "TWS_fnc_applyMoraleEffects";
    publicVariable "TWS_fnc_canStartTraining";
    publicVariable "TWS_fnc_startTraining";
    publicVariable "TWS_fnc_completeTraining";
    publicVariable "TWS_fnc_getTrainingBonus";
    
    systemChat "[TWS] Morale and Training system initialized";
    diag_log "[TWS] Morale and Training system initialized";
};
