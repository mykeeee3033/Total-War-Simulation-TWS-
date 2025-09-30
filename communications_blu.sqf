// Array of all communication towers
_commTowers = nearestObjects [getPos player, ["Land_Communication_F"], 5000];

// Function to check if unit is in range of a working tower
fnc_hasComm = {
    params ["_unit", "_radius"];
    private _inRange = false;
    {
        if (alive _x && {_unit distance _x < _radius}) exitWith { _inRange = true; };
    } forEach _commTowers;
    _inRange
};

// Usage in your order script
_unit = player; // For testing, use player as the unit
_radius = 1000; // communication radius
if ([ _unit, _radius ] call fnc_hasComm) then {
    systemChat "[COMMS] Unit is within communication radius!";
    // Execute orders immediately
} else {
    systemChat "[COMMS] No communication! Orders delayed.";
    sleep 10; // Delay orders if no comms
    // Execute orders after delay
};