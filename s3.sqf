// Get the OPFOR death positions stored from initPlayerLocal
private _deathPositions = missionNamespace getVariable ["opforDeathPositions", []];

// Check if there are any OPFOR deaths
if (count _deathPositions > 0) then {
    // Fetch spawn position for the OPFOR spawn marker
    private _spawnPos1 = getMarkerPos "opfor_spawn";  // Marker for vehicle spawn point

    // Loop to spawn 2 trucks, 2 APCs, 2 tanks, and 2 helicopters
    for "_i" from 0 to 1 do {
        // Random displacement values to randomize spawn position within a larger area
        private _randomDisplacementX = (random 100) - 50; // Random X displacement between -50 and 50 meters
        private _randomDisplacementY = (random 100) - 50; // Random Y displacement between -50 and 50 meters

        // Calculate spawn position for truck
        private _spawnPosTruck = [
            (_spawnPos1 select 0) + _randomDisplacementX, 
            (_spawnPos1 select 1) + _randomDisplacementY, 
            (_spawnPos1 select 2)
        ];

        // Calculate spawn position for tank, ensuring it doesn't overlap with the truck
        private _spawnPosTank = [
            (_spawnPosTruck select 0) + (random 50) - 25,  // Slightly offset from the truck's spawn position
            (_spawnPosTruck select 1) + (random 50) - 25,  // Slightly offset from the truck's spawn position
            (_spawnPosTruck select 2)
        ];

        // Calculate spawn position for APC, ensuring it doesn't overlap with the tank
        private _spawnPosAPC = [
            (_spawnPosTank select 0) + (random 50) - 25,  // Slightly offset from the tank's spawn position
            (_spawnPosTank select 1) + (random 50) - 25,  // Slightly offset from the tank's spawn position
            (_spawnPosTank select 2)
        ];

        // Calculate spawn position for helicopter, ensuring it is further away
        private _spawnPosHeli = [
            (_spawnPosTruck select 0) + (random 100) - 50,  // Further offset for heli spawn
            (_spawnPosTruck select 1) + (random 100) - 50,  // Further offset for heli spawn
            (_spawnPosTruck select 2) + 30                // Slightly higher for heli
        ];

        // Spawn 2 trucks
        private _spawnTruck = [_spawnPosTruck, 0, "O_Truck_03_covered_F", EAST] call BIS_fnc_spawnVehicle;
        private _truck = _spawnTruck select 0;
        private _truckGroup = _spawnTruck select 2;

        // Spawn 2 Tanks
        private _spawnTank = [_spawnPosTank, 0, "O_MBT_04_cannon_F", EAST] call BIS_fnc_spawnVehicle;
        private _Tank = _spawnTank select 0;
        private _TankGroup = _spawnTank select 2;

        // Spawn 2 APCs
        private _spawnAPC = [_spawnPosAPC, 0, "O_APC_Wheeled_02_rcws_v2_F", EAST] call BIS_fnc_spawnVehicle;
        private _apc = _spawnAPC select 0;
        private _apcGroup = _spawnAPC select 2;

        // Spawn 2 helicopters
        private _spawnHeli = [_spawnPosHeli, 0, "O_Heli_Attack_02_dynamicLoadout_F", EAST] call BIS_fnc_spawnVehicle;
        private _heli = _spawnHeli select 0;
        private _heliGroup = _spawnHeli select 2;

        // Spawn infantry groups for each vehicle (trucks and APCs)
        private _infGroupTruck = [_spawnPosTruck, EAST, (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")] call BIS_fnc_spawnGroup;
        private _infGroupAPC = [_spawnPosAPC, EAST, (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")] call BIS_fnc_spawnGroup;

        // Assign and move infantry units into the cargo of the vehicles
        {
            _x assignAsCargo _truck;
            _x moveInCargo _truck;
        } forEach (units _infGroupTruck);

        {
            _x assignAsCargo _apc;
            _x moveInCargo _apc;
        } forEach (units _infGroupAPC);

        // Create waypoints for the vehicles and infantry group based on death locations
        {
            private _deathPos = _x; // Current death location

            // Add a "MOVE" waypoint for each vehicle to go to the death position
            private _moveWpTruck = _truckGroup addWaypoint [_deathPos, 0];
            _moveWpTruck setWaypointType "MOVE";
            _moveWpTruck setWaypointSpeed "FULL";

            private _moveWpAPC = _apcGroup addWaypoint [_deathPos, 0];
            _moveWpAPC setWaypointType "MOVE";
            _moveWpAPC setWaypointSpeed "FULL";

            private _moveWpTank = _TankGroup addWaypoint [_deathPos, 0];
            _moveWpTank setWaypointType "SAD";  // Used for tanks and heavy vehicles
            _moveWpTank setWaypointSpeed "FULL";

            private _moveWpHeli = _heliGroup addWaypoint [_deathPos, 0];
            _moveWpHeli setWaypointType "SAD";  // Used for helicopters
            _moveWpHeli setWaypointSpeed "FULL";

            // Add "TR UNLOAD" waypoint for each vehicle to stop and unload at the death position
            private _unloadWpTruck = _truckGroup addWaypoint [_deathPos, 0];
            _unloadWpTruck setWaypointType "TR UNLOAD";

            private _unloadWpAPC = _apcGroup addWaypoint [_deathPos, 0];
            _unloadWpAPC setWaypointType "TR UNLOAD";

            // Add a "GET OUT" waypoint for each infantry group to disembark at the death position
            private _getOutWpTruck = _infGroupTruck addWaypoint [_deathPos, 0];
            _getOutWpTruck setWaypointType "GETOUT";

            private _getOutWpAPC = _infGroupAPC addWaypoint [_deathPos, 0];
            _getOutWpAPC setWaypointType "GETOUT";
        } forEach _deathPositions;
    };
};
