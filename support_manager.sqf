// Initialize variables if not already defined
if (isNil "opforKillCount") then { opforKillCount = 0; };
if (isNil "opforDeathPositions") then { opforDeathPositions = []; };
if (isNil "reinforcementCount") then { reinforcementCount = 0; };
if (isNil "lastResetTime") then { lastResetTime = time; };

// Set up event handler to track OPFOR deaths
addMissionEventHandler ["EntityKilled", {
    params ["_unit"];
    _side = side group _unit;

    // Track only OPFOR deaths
    if (_side == east) then {
        // Increment OPFOR death count and store death location
        opforKillCount = opforKillCount + 1;
        opforDeathPositions pushBack (getPos _unit);
    };
}];

// Threshold check loop with cap on reinforcements within 30 minutes
[] spawn {
    // Manpower costs for different reinforcement types
    private _manpowerCosts = createHashMap;
    _manpowerCosts set ["s1", 20];  // Light reinforcements: 2 trucks + infantry
    _manpowerCosts set ["s2", 40];  // Medium reinforcements: 2 APCs + infantry  
    _manpowerCosts set ["s3", 80];  // Heavy reinforcements: trucks, APCs, tanks, helis + infantry

    // Function to check and consume OPFOR manpower
    private _fnc_checkManpower = {
        params ["_scriptType"];
        
        // Check if resource system is available
        if (isNil "RES_fnc_getResources" || isNil "RES_fnc_modifyResource") exitWith {
            systemChat "[Support] Resource system not available - spawning reinforcements anyway";
            true
        };
        
        private _requiredManpower = _manpowerCosts get _scriptType;
        private _opforResources = ["OPFOR"] call RES_fnc_getResources;
        private _currentManpower = _opforResources select 3; // Manpower is index 3
        
        if (_currentManpower >= _requiredManpower) then {
            // Deduct manpower cost
            ["OPFOR", 3, -_requiredManpower] call RES_fnc_modifyResource;
            // systemChat format ["[Support] Deploying %1 reinforcements - %2 manpower consumed (%3 remaining)", 
                _scriptType, _requiredManpower, _currentManpower - _requiredManpower];
            true
        } else {
            systemChat format ["[Support] INSUFFICIENT MANPOWER: %1 required, only %2 available - reinforcements denied!", 
                _requiredManpower, _currentManpower];
            hint format ["Reinforcements Denied!\nRequired: %1 manpower\nAvailable: %2 manpower", _requiredManpower, _currentManpower];
            false
        };
    };
    
    while {true} do {
        sleep 60; // Check every 60 seconds (optimized from 20)

        // Reset the reinforcement count every 30 minutes
        if (time - lastResetTime >= 1800) then {
            reinforcementCount = 0;
            lastResetTime = time;
        };

        // Only deploy reinforcements if count is below cap
        if (reinforcementCount < 100) then {
            // Check if OPFOR kills are above or equal to thresholds
            if (opforKillCount >= 30) then {
                // Check manpower before spawning heavy reinforcements
                if (["s3"] call _fnc_checkManpower) then {
                    [] execVM "s3.sqf"; // Execute s3.sqf for 30 or more kills
                    hint "Executing s3.sqf: 30+ OPFOR kills - Heavy reinforcements deployed!";
                    opforKillCount = 0; // Reset kill count after executing
                    reinforcementCount = reinforcementCount + 30; // Increment reinforcement count
                } else {
                    // Keep kill count to try again later when more manpower is available
                    // systemChat "[Support] Waiting for manpower to deploy heavy reinforcements...";
                };
            } else {
                if (opforKillCount >= 20) then {
                    // Check manpower before spawning medium reinforcements
                    if (["s2"] call _fnc_checkManpower) then {
                        [] execVM "s2.sqf"; // Execute s2.sqf for 20 or more kills
                        hint "Executing s2.sqf: 20+ OPFOR kills - Medium reinforcements deployed!";
                        opforKillCount = 0; // Reset kill count after executing
                        reinforcementCount = reinforcementCount + 20; // Increment reinforcement count
                    } else {
                        // Keep kill count to try again later when more manpower is available
                        systemChat "[Support] Waiting for manpower to deploy medium reinforcements...";
                    };
                } else {
                    if (opforKillCount >= 5) then {
                        // Check manpower before spawning light reinforcements
                        if (["s1"] call _fnc_checkManpower) then {
                            [] execVM "s1.sqf"; // Execute s1.sqf for 5 or more kills
                            hint "Executing s1.sqf: 5+ OPFOR kills - Light reinforcements deployed!";
                            opforKillCount = 0; // Reset kill count after executing
                            reinforcementCount = reinforcementCount + 5; // Increment reinforcement count
                        } else {
                            // Keep kill count to try again later when more manpower is available
                            systemChat "[Support] Waiting for manpower to deploy light reinforcements...";
                        };
                    };
                };
            };
        } else {
            hint "Reinforcement cap reached: 100 reinforcements in the last 30 minutes.";
        };
    };
};
