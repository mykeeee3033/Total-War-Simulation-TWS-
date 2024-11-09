// Get the OPFOR death positions stored from initPlayerLocal
private _deathPositions = missionNamespace getVariable ["opforDeathPositions", []];

// Check if there are any OPFOR deaths
if (count _deathPositions > 0) then {
    // Fetch spawn position for the first vehicle and group
    private _spawnPos1 = getMarkerPos "opfor_spawn";  // Marker for first vehicle spawn
    
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
};
