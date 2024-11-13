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

// Threshold check loop with cap on reinforcements within 5 minutes
[] spawn {
    while {true} do {
        sleep 20; // Check every 20 seconds

        // Reset the reinforcement count every 5 minutes
        if (time - lastResetTime >= 1800) then {
            reinforcementCount = 0;
            lastResetTime = time;
        };

        // Only deploy reinforcements if count is below cap
        if (reinforcementCount < 100) then {
            // Check if OPFOR kills are above or equal to thresholds
            if (opforKillCount >= 30) then {
                [] execVM "s3.sqf"; // Execute s3.sqf for 30 or more kills
                hint "Executing s3.sqf: 30+ OPFOR kills!"; // Debug message
                opforKillCount = 0; // Reset kill count after executing
                reinforcementCount = reinforcementCount + 30; // Increment reinforcement count
            } else {
                if (opforKillCount >= 20) then {
                    [] execVM "s2.sqf"; // Execute s2.sqf for 20 or more kills
                    hint "Executing s2.sqf: 20+ OPFOR kills!"; // Debug message
                    opforKillCount = 0; // Reset kill count after executing
                    reinforcementCount = reinforcementCount + 20; // Increment reinforcement count
                } else {
                    if (opforKillCount >= 5) then {
                        [] execVM "s1.sqf"; // Execute s1.sqf for 5 or more kills
                        hint "Executing s1.sqf: 5+ OPFOR kills!"; // Debug message
                        opforKillCount = 0; // Reset kill count after executing
                        reinforcementCount = reinforcementCount + 5; // Increment reinforcement count
                    };
                };
            };
        } else {
            hint "Reinforcement cap reached: 100 reinforcements in the last 30 minutes.";
        };
    };
};
