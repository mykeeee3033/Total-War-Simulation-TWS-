// Get the OPFOR death positions stored from initPlayerLocal
private _deathPositions = missionNamespace getVariable ["opforDeathPositions", []];

// Check if there are any OPFOR deaths
if (count _deathPositions > 0) then {
    // Find all CSAT flags on the map
    private _mapCenter = [worldSize/2, worldSize/2, 0];
    private _csatFlags = _mapCenter nearObjects ["Flag_CSAT_F", worldSize];
    
    if (count _csatFlags == 0) exitWith {
        systemChat "[Reinforcements] ERROR: No CSAT flags found for spawn point!";
        hint "No CSAT flags available for reinforcement spawn!";
    };
    
    // Select CSAT flag closest to OPFOR death locations
    private _selectedFlag = selectRandom _csatFlags;
    
    // Calculate average death position to find closest flag
    private _avgX = 0;
    private _avgY = 0;
    { 
        _avgX = _avgX + (_x select 0);
        _avgY = _avgY + (_x select 1);
    } forEach _deathPositions;
    _avgX = _avgX / (count _deathPositions);
    _avgY = _avgY / (count _deathPositions);
    private _avgDeathPos = [_avgX, _avgY, 0];
    
    // Find closest CSAT flag to death center
    private _closestDistance = 999999;
    {
        private _flagPos = getPosATL _x;
        private _distance = _avgDeathPos distance2D _flagPos;
        if (_distance < _closestDistance) then {
            _closestDistance = _distance;
            _selectedFlag = _x;
        };
    } forEach _csatFlags;
    
    private _flagPos = getPosATL _selectedFlag;
    
    // Calculate spawn position with 50m radius around flag to avoid collision
    private _angle = random 360;
    private _distance = 30 + (random 20); // 30-50m from flag
    private _spawnPos1 = [
        (_flagPos select 0) + (_distance * cos _angle),
        (_flagPos select 1) + (_distance * sin _angle),
        (_flagPos select 2)
    ];
    
    systemChat format ["[Reinforcements] Using closest CSAT flag at %1 (offset %2m, %3m from deaths)", _spawnPos1, round _distance, round _closestDistance];
    hint format ["Reinforcements spawning from nearest CSAT flag: %1", _spawnPos1];
    
    // Displacement for the second vehicle (to avoid overlap)
    private _displacement = [50, 50];  // Example displacement, adjust as needed

    // Loop for spawning 2 vehicles and 2 groups
    for "_i" from 0 to 1 do {
        // Calculate spawn position for each vehicle
        private _spawnPos = [
            (_spawnPos1 select 0) + (_displacement select 0) * _i, 
            (_spawnPos1 select 1) + (_displacement select 1) * _i, 
            (_spawnPos1 select 2)
        ];

        // Spawn the vehicle and crew (customize with your desired vehicle class)
        private _spawnVeh = [_spawnPos, 0, "O_APC_Wheeled_02_rcws_v2_F", EAST] call BIS_fnc_spawnVehicle;
        private _vehicle = _spawnVeh select 0;
        private _vehicleGroup = _spawnVeh select 2;

        // Spawn the infantry group using a defined CfgGroup
        private _infGroup = [_spawnPos, EAST, (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")] call BIS_fnc_spawnGroup;

        // Assign and move infantry units into the cargo of the vehicle
        {
            _x assignAsCargo _vehicle;
            _x moveInCargo _vehicle;
        } forEach (units _infGroup);

        // Create waypoints for the vehicle and infantry group based on death locations
        {
            private _deathPos = _x; // Current death location

            // Add a "MOVE" waypoint for the vehicle to go to the death position
            private _moveWp = _vehicleGroup addWaypoint [_deathPos, 0];
            _moveWp setWaypointType "MOVE";
            _moveWp setWaypointSpeed "FULL";

            // Add "TR UNLOAD" waypoint for the vehicle to stop and unload at the death position
            private _unloadWp = _vehicleGroup addWaypoint [_deathPos, 0];
            _unloadWp setWaypointType "TR UNLOAD";

            // Add a "GET OUT" waypoint for the infantry to disembark at the death position
            private _getOutWp = _infGroup addWaypoint [_deathPos, 0];
            _getOutWp setWaypointType "GETOUT";
        } forEach _deathPositions;
    };
    
    // Clear death positions after processing to prevent accumulation
    missionNamespace setVariable ["opforDeathPositions", []];
    systemChat "[Reinforcements] Death positions cleared for next wave";
};
