// Initialize the OPFOR kill count and death positions array if not already defined
if (isNil "opforKillCount") then { opforKillCount = 0; };
if (isNil "opforDeathPositions") then { opforDeathPositions = []; };

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

// Threshold check loop
[] spawn {
    while {true} do {
        sleep 60; // Check every 20 seconds

        // Check if OPFOR kills are above or equal to 30
        if (opforKillCount >= 30) then {
            [] execVM "s3.sqf"; // Execute s3.sqf for 30 or more kills
            hint "Executing s3.sqf: 30+ OPFOR kills!"; // Debug message
            opforKillCount = 0; // Reset kill count after executing
        } else {
            // Check if OPFOR kills are above or equal to 20
            if (opforKillCount >= 20) then {
                [] execVM "s2.sqf"; // Execute s2.sqf for 20 or more kills
                hint "Executing s2.sqf: 20+ OPFOR kills!"; // Debug message
                opforKillCount = 0; // Reset kill count after executing
            } else {
                // If not, check if OPFOR kills are above or equal to 5
                if (opforKillCount >= 5) then {
                    [] execVM "s1.sqf"; // Execute s1.sqf for 5 or more kills
                    hint "Executing s1.sqf: 5+ OPFOR kills!"; // Debug message
                    opforKillCount = 0; // Reset kill count after executing
                };
            };
        };
    };
};
