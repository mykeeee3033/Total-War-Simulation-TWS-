/*
 * SIMPLE Infantry Squad Monitor - Single Squad Packets
 * 
 * Like opforDeathStats: Sends individual squad updates to avoid INIDBI2 limits
 * Run with: [] execVM "scripts\infantrySimple.sqf"
 */

systemChat "=== SIMPLE INFANTRY MONITOR ===";

// Initialize global squad tracking
if (isNil "SIMPLE_INF_squads") then { SIMPLE_INF_squads = []; };

// Find all infantry groups across the map (same method as test script)
private _allGroups = [];
private _processedGroups = [];
private _mapCenter = [worldSize/2, worldSize/2, 0];
private _allInfantry = _mapCenter nearEntities [["Man"], worldSize];

{
    private _unit = _x;
    private _unitGroup = group _unit;
    
    if (!(_unitGroup in _processedGroups) && {alive _unit} && {!isPlayer _unit}) then {
        _processedGroups pushBack _unitGroup;
        _allGroups pushBack _unitGroup;
    };
} forEach _allInfantry;

systemChat format ["Found %1 infantry squads total", count _allGroups];

// Process each group and send individual updates
SIMPLE_INF_squads = [];
private _squadCount = 0;

{
    private _group = _x;
    private _groupPos = getPos (leader _group);
    private _groupSide = side _group;
    private _groupName = groupId _group;
    
    // Get basic squad stats
    private _totalHealth = 0;
    private _unitCount = 0;
    private _woundedCount = 0;
    private _deadCount = 0;
    
    {
        if (alive _x) then {
            private _damage = damage _x;
            private _health = (1 - _damage) * 100;
            _totalHealth = _totalHealth + _health;
            _unitCount = _unitCount + 1;
            
            if (_damage > 0.25) then {
                _woundedCount = _woundedCount + 1;
            };
        } else {
            _deadCount = _deadCount + 1;
        };
    } forEach (units _group);
    
    private _avgHealth = if (_unitCount > 0) then { round(_totalHealth / _unitCount) } else { 0 };
    private _gridRef = mapGridPosition _groupPos;
    private _sideText = if (_groupSide == west) then {"BLUFOR"} else {"OPFOR"};
    private _combatText = if (combatMode _group in ["RED", "YELLOW"]) then {"COMBAT"} else {"SAFE"};
    
    // Create simple squad record
    private _squadRecord = format ["id:%1,side:%2,health:%3,ammo:50,alive:%4,wounded:%5,kia:%6,combat:%7,grid:%8",
        _groupName, _sideText, _avgHealth, _unitCount, _woundedCount, _deadCount, _combatText, _gridRef];
    
    SIMPLE_INF_squads pushBack _squadRecord;
    _squadCount = _squadCount + 1;
    
    // Debug output only (removed individual sending to avoid "Unknown command" errors)
    systemChat format ["[SIMPLE-SQUADS] Squad %1: %2 - %3A/%4W/%5K - %6%% health", 
        _squadCount, _groupName, _unitCount, _woundedCount, _deadCount, _avgHealth];
    
} forEach _allGroups;

systemChat format ["Processed %1 squads, sent individual updates", _squadCount];

// A3DJS Command Handler for squad requests
[] spawn {
    waitUntil {!isNil "A3DJS_commandTypes"};
    
    // Define squad status function
    SIMPLE_INF_fnc_getStatus = {
        params["_target", "_sender", "_RequestId", ["_action", ""]];
        
        // Send each squad on separate line for easier parsing
        private _response = SIMPLE_INF_squads joinString "\n";
        
        [_RequestId, _response] call A3DJS_fnc_respondCall;
        systemChat format ["[SIMPLE-SQUADS] Data sent to %1: %2 squads", _sender, count SIMPLE_INF_squads];
    };
    
    // Register command
    ["simple-squads", SIMPLE_INF_fnc_getStatus] call A3DJS_fnc_addCommandType;
    systemChat "Simple squads command registered!";
};

publicVariable "SIMPLE_INF_fnc_getStatus";
publicVariable "SIMPLE_INF_squads";

systemChat "=== SIMPLE INFANTRY MONITOR COMPLETE ===";
systemChat format ["Total squads tracked: %1", count SIMPLE_INF_squads];