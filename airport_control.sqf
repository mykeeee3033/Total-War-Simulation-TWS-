waitUntil { !isNil "GRLIB_all_fobs" };
waitUntil { !isNil "blufor_sectors" };

sleep 5;

_lastOwnership = ""; // Variable to track the last ownership state

while { GRLIB_endgame == 0 } do {
//THESE ARE FOR THE NORTHERN AIRPORTS!!!
    _ownership = [getMarkerPos 'capture_24'] call KPLIB_fnc_getSectorOwnership;

    if (_ownership == GRLIB_side_enemy) then {
        if (_lastOwnership != "enemy") then { // Only if ownership changes to OPFOR
            execVM "airport_logi_opfor.sqf";
		execVM "opfor_resupply_heli.sqf";
		execVM "airport_defense_systems_opfor.sqf";
            hint 'Airport is in OPFOR control';
            _lastOwnership = "enemy"; // Update the last ownership state
        };
    } else {
        if (_ownership == GRLIB_side_friendly) then {
            if (_lastOwnership != "friendly") then { // Only if ownership changes to BLUFOR
                execVM "airport_logi_blufor.sqf";
				execVM "blufor_resupply_heli.sqf";
				execVM "airport_defense_systems_blufor.sqf";
                hint 'Airport is in BLUFOR control';
                _lastOwnership = "friendly"; // Update the last ownership state
            };
        } else {
            if (_lastOwnership != "contested") then { // Only if ownership changes to contested
                hint 'Airport is contested';
                _lastOwnership = "contested"; // Update the last ownership state
            };
        };
    };

    sleep 20; // Interval before checking again
};








//TEST FOR SOUTH AIRPORT REGION


while { GRLIB_endgame == 0 } do {
//THESE ARE FOR THE SOUTHERN AIRPORTS!!!
    _ownership = [getMarkerPos 'military_2'] call KPLIB_fnc_getSectorOwnership;

    if (_ownership == GRLIB_side_enemy) then {
        if (_lastOwnership != "enemy") then { // Only if ownership changes to OPFOR
            	execVM "s_airport_logi_opfor.sqf";
		execVM "s_opfor_resupply_heli.sqf";
            hint 'South Airport is in OPFOR control';
            _lastOwnership = "enemy"; // Update the last ownership state
        };
    } else {
        if (_ownership == GRLIB_side_friendly) then {
            if (_lastOwnership != "friendly") then { // Only if ownership changes to BLUFOR
                execVM "s_airport_logi_blufor.sqf";
		execVM "s_blufor_resupply_heli.sqf";
                hint 'South Airport is in BLUFOR control';
                _lastOwnership = "friendly"; // Update the last ownership state
            };
        } else {
            if (_lastOwnership != "contested") then { // Only if ownership changes to contested
                hint 'South Airport is contested';
                _lastOwnership = "contested"; // Update the last ownership state
            };
        };
    };

    sleep 20; // Interval before checking again
};