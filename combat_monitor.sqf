// combat_monitor.sqf

// Initialize counters
if (isNil "factionStats") then {
    factionStats = [
        ["BLUFOR", 0], // [Faction, Killed]
        ["OPFOR", 0],
        ["INDEPENDENT", 0],
        ["CIVILIAN", 0]
    ];
};
// Store killed and wounded positions
if (isNil "killedPositions") then { killedPositions = []; };
if (isNil "woundedPositions") then { woundedPositions = []; };
// Store marker name for first contact
if (isNil "contactMarkerName") then { contactMarkerName = ""; };
if (isNil "contactMarkerPlaced") then { contactMarkerPlaced = false; };
if (isNil "latestCasualtyPos") then { latestCasualtyPos = [0,0,0]; };

// Helper function to get faction name
getFactionName = {
    params ["_side"];
    switch (_side) do {
        case west: {"BLUFOR"};
        case east: {"OPFOR"};
        case resistance: {"INDEPENDENT"};
        case civilian: {"CIVILIAN"};
        default {"UNKNOWN"};
    };
};

// Event handler for killed units
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    _side = side group _unit;
    _faction = [_side] call getFactionName;
    _pos = getPos _unit;
    private _killedCount = 0;
    {
        if (_x select 0 == _faction) then {
            _x set [1, (_x select 1) + 1]; // Increment killed count
            _killedCount = _x select 1;
        };
    } forEach factionStats;
    killedPositions pushBack _pos;
    latestCasualtyPos = _pos;
    // Place marker if not already placed
    if (!contactMarkerPlaced) then {
        contactMarkerName = format ["contactMarker_%1", diag_tickTime];
        private _marker = createMarker [contactMarkerName, _pos];
        _marker setMarkerType "mil_dot";
        _marker setMarkerColor "ColorRed";
        _marker setMarkerText "Troops in Contact";
        contactMarkerPlaced = true;
        // Delete marker after 5 minutes
        [{contactMarkerName}, {
            deleteMarker _this;
            contactMarkerPlaced = false;
        }] call CBA_fnc_waitAndExecute;
    };
    // Debug message with location
    systemChat format [
        "[DEBUG] Troops in contact! %1 killed at %2 | Total killed: %3",
        _faction,
        _pos,
        _killedCount
    ];
}];

// Event handler for wounded units
{
    _unit = _x;
    _unit addEventHandler ["HandleDamage", {
        params ["_unit", "_selectionName", "_damage", "_source", "_projectile"];
        _side = side group _unit;
        _faction = [_side] call getFactionName;
        if (_damage > 0.5 && alive _unit) then {
            _pos = getPos _unit;
            woundedPositions pushBack _pos;
            latestCasualtyPos = _pos;
            // Place marker if not already placed
            if (!contactMarkerPlaced) then {
                contactMarkerName = format ["contactMarker_%1", diag_tickTime];
                private _marker = createMarker [contactMarkerName, _pos];
                _marker setMarkerType "mil_dot";
                _marker setMarkerColor "ColorRed";
                _marker setMarkerText "Troops in Contact";
                contactMarkerPlaced = true;
                // Delete marker after 5 minutes
                [{contactMarkerName}, {
                    deleteMarker _this;
                    contactMarkerPlaced = false;
                }] call CBA_fnc_waitAndExecute;
            };
            // Debug message with location
            systemChat format [
                "[DEBUG] Troops in contact! %1 wounded at %2",
                _faction,
                _pos
            ];
        };
        _damage
    }];
} forEach allUnits;