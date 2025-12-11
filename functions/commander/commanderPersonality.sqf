/*
 * commanderPersonality.sqf
 * Commander Personality Layer
 * 
 * Purpose: Add personality logic on top of ALiVE OPCOM:
 * - Cautious: Defensive, preserves resources
 * - Balanced: Standard operations
 * - Aggressive: Offensive, high tempo
 * - Recovery: After heavy losses, rebuild focus
 * - Logistics-first: Prioritize supply build-up
 * - Blitz: When resources abundant, maximum aggression
 * 
 * OPCOM executes missions, personality decides WHEN and WHY
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    // Commander personality system
    TWS_commanderPersonalities = createHashMap;
    
    // Initialize commanders for each faction
    TWS_commanders = createHashMap;
    TWS_commanders set ["BLUFOR", createHashMap];
    TWS_commanders set ["OPFOR", createHashMap];
    
    // Set initial personalities
    (TWS_commanders get "BLUFOR") set ["personality", "balanced"];
    (TWS_commanders get "BLUFOR") set ["aggressiveness", 0.5];
    (TWS_commanders get "BLUFOR") set ["lastPersonalityChange", 0];
    (TWS_commanders get "BLUFOR") set ["casualtyCount", 0];
    (TWS_commanders get "BLUFOR") set ["victoriesCount", 0];
    
    (TWS_commanders get "OPFOR") set ["personality", "balanced"];
    (TWS_commanders get "OPFOR") set ["aggressiveness", 0.5];
    (TWS_commanders get "OPFOR") set ["lastPersonalityChange", 0];
    (TWS_commanders get "OPFOR") set ["casualtyCount", 0];
    (TWS_commanders get "OPFOR") set ["victoriesCount", 0];
    
    // Define personality parameters
    TWS_fnc_definePersonalities = {
        // Cautious personality
        private _cautious = createHashMap;
        _cautious set ["aggressiveness", 0.2];
        _cautious set ["offensiveThreshold", 0.8]; // Only attack when tempo >= 0.8
        _cautious set ["retreatThreshold", 0.5]; // Retreat when tempo < 0.5
        _cautious set ["resourceBuffer", 1.5]; // Maintain 1.5x normal resources
        _cautious set ["description", "Defensive operations, resource preservation"];
        TWS_commanderPersonalities set ["cautious", _cautious];
        
        // Balanced personality
        private _balanced = createHashMap;
        _balanced set ["aggressiveness", 0.5];
        _balanced set ["offensiveThreshold", 0.6];
        _balanced set ["retreatThreshold", 0.4];
        _balanced set ["resourceBuffer", 1.0];
        _balanced set ["description", "Standard operations, balanced approach"];
        TWS_commanderPersonalities set ["balanced", _balanced];
        
        // Aggressive personality
        private _aggressive = createHashMap;
        _aggressive set ["aggressiveness", 0.8];
        _aggressive set ["offensiveThreshold", 0.4]; // Attack even at lower tempo
        _aggressive set ["retreatThreshold", 0.2]; // Rarely retreat
        _aggressive set ["resourceBuffer", 0.7]; // Accept lower resource levels
        _aggressive set ["description", "Offensive operations, high tempo"];
        TWS_commanderPersonalities set ["aggressive", _aggressive];
        
        // Recovery personality
        private _recovery = createHashMap;
        _recovery set ["aggressiveness", 0.1];
        _recovery set ["offensiveThreshold", 1.2]; // Only attack when well-supplied
        _recovery set ["retreatThreshold", 0.6];
        _recovery set ["resourceBuffer", 2.0]; // Build up reserves
        _recovery set ["description", "Rebuilding after losses, defensive posture"];
        TWS_commanderPersonalities set ["recovery", _recovery];
        
        // Logistics-first personality
        private _logisticsFirst = createHashMap;
        _logisticsFirst set ["aggressiveness", 0.3];
        _logisticsFirst set ["offensiveThreshold", 1.0];
        _logisticsFirst set ["retreatThreshold", 0.5];
        _logisticsFirst set ["resourceBuffer", 2.5]; // Maximum stockpiling
        _logisticsFirst set ["description", "Supply build-up focus, limited operations"];
        TWS_commanderPersonalities set ["logisticsFirst", _logisticsFirst];
        
        // Blitz personality
        private _blitz = createHashMap;
        _blitz set ["aggressiveness", 1.0];
        _blitz set ["offensiveThreshold", 0.3]; // Attack almost always
        _blitz set ["retreatThreshold", 0.1]; // Almost never retreat
        _blitz set ["resourceBuffer", 0.5]; // Spend resources freely
        _blitz set ["description", "Maximum aggression, rapid operations"];
        TWS_commanderPersonalities set ["blitz", _blitz];
    };
    
    [] call TWS_fnc_definePersonalities;
    
    // Function to set commander personality
    TWS_fnc_setCommanderPersonality = {
        params ["_faction", "_personality"];
        
        private _commander = TWS_commanders get _faction;
        private _personalityData = TWS_commanderPersonalities get _personality;
        
        if (isNil "_personalityData") exitWith {
            diag_log format ["[TWS] Invalid personality: %1", _personality];
        };
        
        _commander set ["personality", _personality];
        _commander set ["aggressiveness", _personalityData get "aggressiveness"];
        _commander set ["lastPersonalityChange", diag_tickTime];
        
        systemChat format ["[TWS] %1 commander personality: %2 - %3", 
            _faction, _personality, _personalityData get "description"];
        diag_log format ["[TWS] %1 commander personality changed to %2", _faction, _personality];
    };
    
    // Function to auto-adjust personality based on situation
    TWS_fnc_autoAdjustPersonality = {
        params ["_faction"];
        
        private _commander = TWS_commanders get _faction;
        private _currentPersonality = _commander get "personality";
        private _resources = [_faction] call TWS_fnc_getResources;
        private _tempo = [_faction] call TWS_fnc_getTempo;
        
        private _ammo = _resources getOrDefault ["ammunition", 0];
        private _fuel = _resources getOrDefault ["fuel", 0];
        private _minResource = _ammo min _fuel;
        
        private _newPersonality = _currentPersonality;
        
        // Check for critical situations
        if (_minResource < (TWS_resourceThresholds get "critical")) then {
            _newPersonality = "recovery";
        } else {
            if (_minResource < (TWS_resourceThresholds get "low")) then {
                if (_currentPersonality in ["aggressive", "blitz"]) then {
                    _newPersonality = "cautious";
                };
            } else {
                if (_minResource > (TWS_resourceThresholds get "abundant")) then {
                    if (_tempo > 1.2 && _currentPersonality != "blitz") then {
                        _newPersonality = "blitz";
                    } else {
                        if (_currentPersonality == "recovery") then {
                            _newPersonality = "balanced";
                        };
                    };
                } else {
                    // Normal resources - balance based on tempo
                    if (_currentPersonality == "recovery" && _tempo > 0.8) then {
                        _newPersonality = "balanced";
                    };
                };
            };
        };
        
        // Apply personality change if different
        if (_newPersonality != _currentPersonality) then {
            [_faction, _newPersonality] call TWS_fnc_setCommanderPersonality;
        };
    };
    
    // Function to get commander's operational decision
    TWS_fnc_getCommanderDecision = {
        params ["_faction", "_operationType"];
        
        private _commander = TWS_commanders get _faction;
        private _personality = _commander get "personality";
        private _personalityData = TWS_commanderPersonalities get _personality;
        private _tempo = [_faction] call TWS_fnc_getTempo;
        
        private _decision = createHashMap;
        _decision set ["approved", false];
        _decision set ["reason", ""];
        
        switch (_operationType) do {
            case "offensive": {
                private _threshold = _personalityData get "offensiveThreshold";
                if (_tempo >= _threshold) then {
                    _decision set ["approved", true];
                    _decision set ["reason", "Resources adequate for offensive"];
                } else {
                    _decision set ["reason", format ["Tempo %1 below threshold %2", _tempo, _threshold]];
                };
            };
            case "defensive": {
                _decision set ["approved", true];
                _decision set ["reason", "Defensive operations always approved"];
            };
            case "retreat": {
                private _threshold = _personalityData get "retreatThreshold";
                if (_tempo < _threshold) then {
                    _decision set ["approved", true];
                    _decision set ["reason", "Resources critical, retreat advised"];
                };
            };
        };
        
        _decision
    };
    
    // Function to get recommended OPCOM settings
    TWS_fnc_getOPCOMRecommendations = {
        params ["_faction"];
        
        private _commander = TWS_commanders get _faction;
        private _personality = _commander get "personality";
        private _personalityData = TWS_commanderPersonalities get _personality;
        
        private _recommendations = createHashMap;
        _recommendations set ["aggressiveness", _personalityData get "aggressiveness"];
        _recommendations set ["personality", _personality];
        _recommendations set ["description", _personalityData get "description"];
        
        // Get current situation
        private _tempo = [_faction] call TWS_fnc_getTempo;
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Adjust recommendations based on current state
        private _adjustedAggro = (_personalityData get "aggressiveness") * _tempo;
        _recommendations set ["adjustedAggressiveness", _adjustedAggro max 0.1 min 1.0];
        
        _recommendations
    };
    
    // Personality monitoring and auto-adjustment loop
    TWS_fnc_commanderPersonalityLoop = {
        while {true} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_autoAdjustPersonality;
                
                // Log commander status periodically
                private _commander = TWS_commanders get _faction;
                private _personality = _commander get "personality";
                private _recommendations = [_faction] call TWS_fnc_getOPCOMRecommendations;
                
                diag_log format ["[TWS] %1 Commander: Personality=%2, Aggro=%3, Tempo=%4",
                    _faction, 
                    _personality,
                    _recommendations get "adjustedAggressiveness",
                    [_faction] call TWS_fnc_getTempo
                ];
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep 600; // Check every 10 minutes
        };
    };
    
    // Start personality monitoring
    [] spawn TWS_fnc_commanderPersonalityLoop;
    
    publicVariable "TWS_commanderPersonalities";
    publicVariable "TWS_commanders";
    publicVariable "TWS_fnc_setCommanderPersonality";
    publicVariable "TWS_fnc_autoAdjustPersonality";
    publicVariable "TWS_fnc_getCommanderDecision";
    publicVariable "TWS_fnc_getOPCOMRecommendations";
    
    systemChat "[TWS] Commander Personality System initialized";
    diag_log "[TWS] Commander Personality System initialized";
};
