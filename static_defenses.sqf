/*
    Static Defense Virtualization for ALiVE
    
    Execute with: execVM "static_defenses.sqf"
    
    This script virtualizes static weapons and defensive positions:
    - Static machine guns, mortars, artillery
    - Defensive vehicles (tanks, IFVs in defensive positions)
    - Turrets and emplacements
    
    They will only spawn when players are within ALiVE's spawn radius.
*/

// Wait for ALiVE to initialize
if (isNil "ALIVE_profileHandler") then {
    systemChat "Waiting for ALiVE to initialize...";
    waitUntil {!isNil "ALIVE_profileHandler"};
    sleep 2;
};

systemChat "Virtualizing static defenses...";

// Define what counts as static defense
private _staticDefenseClasses = [
    // Static weapons
    "StaticWeapon",
    "StaticMortar", 
    "StaticMGWeapon",
    "StaticATWeapon",
    "StaticAAWeapon",
    "StaticGrenadeLauncher",
    // Add specific classes
    "B_static_AT_F",
    "B_static_AA_F", 
    "B_Mortar_01_F",
    "B_HMG_01_F",
    "B_GMG_01_F",
    "Land_RepairDepot_01_tan_F",
    "B_static_designator_01_F"
];

// Never virtualize these radar systems (empty or occupied)
private _excludedRadarClasses = [
    "O_Radar_System_02_F",
    "B_Radar_System_01_F"
];
//Game objects needed for other scripts
private _excludedGameObjectClasses = [
    "Land_RepairDepot_01_tan_F",
    "Land_RepairDepot_01_green_F"
];

// Never virtualize these supply crates
private _excludedCrateClasses = [
    "O_supplyCrate_F",
    "B_supplyCrate_F",
    "O_CargoNet_01_ammo_F",
    "CargoNet_01_box_F"
];

private _staticCount = 0;

{
    private _vehicle = _x;
    private _isStaticDefense = false;
    private _isExcludedRadar = (typeOf _vehicle) in _excludedRadarClasses;
    private _isExcludedCrate = (typeOf _vehicle) in _excludedCrateClasses;
    private _isExcludedCrate = (typeOf _vehicle) in _excludedGameObjectClasses;
    
    // Check if vehicle is a static defense type
    {
        if (_vehicle isKindOf _x) then {
            _isStaticDefense = true;
        };
    } forEach _staticDefenseClasses;
    
    // Also check if it's a vehicle that hasn't moved (defensive position)
    if (!_isStaticDefense && !(_vehicle isKindOf "Man") && !(_vehicle isKindOf "Air") && !(_vehicle isKindOf "Ship")) then {
        // Check if vehicle is stationary (likely in defensive position)
        private _initialPos = _vehicle getVariable ["initialPos", getPosATL _vehicle];
        if (isNil {_vehicle getVariable "initialPos"}) then {
            _vehicle setVariable ["initialPos", getPosATL _vehicle];
            _initialPos = getPosATL _vehicle;
        };
        
        // If vehicle hasn't moved more than 10m, consider it static defense
        if ((_initialPos distance2D getPosATL _vehicle) < 10 && speed _vehicle < 1) then {
            _isStaticDefense = true;
        };
    };
    
    if (_isStaticDefense && !_isExcludedRadar && !_isExcludedCrate && (_vehicle getVariable ["profileID", ""]) == "") then {
        
        private _crew = crew _vehicle;
        if (count _crew > 0) then {
            // Has crew
            private _group = group (_crew select 0);
            if (!isPlayer leader _group && !isNull leader _group) then {
                
                private _leader = leader _group;
                private _units = units _group;
                private _position = getPosATL _leader;
                
                // Create entity profile manually
                private _entityID = [ALIVE_profileHandler, "getNextInsertEntityID"] call ALIVE_fnc_profileHandler;
                
                private _unitClasses = [];
                private _positions = [];
                private _ranks = [];
                private _damages = [];
                
                {
                    _unitClasses pushBack (typeOf _x);
                    _positions pushBack (getPosATL _x);
                    _ranks pushBack (rank _x);
                    _damages pushBack (damage _x);
                } forEach _units;
                
                private _profileEntity = [nil, "create"] call ALIVE_fnc_profileEntity;
                [_profileEntity, "init"] call ALIVE_fnc_profileEntity;
                [_profileEntity, "profileID", _entityID] call ALIVE_fnc_profileEntity;
                [_profileEntity, "unitClasses", _unitClasses] call ALIVE_fnc_profileEntity;
                [_profileEntity, "position", _position] call ALIVE_fnc_profileEntity;
                [_profileEntity, "despawnPosition", _position] call ALIVE_fnc_profileEntity;
                [_profileEntity, "positions", _positions] call ALIVE_fnc_profileEntity;
                [_profileEntity, "damages", _damages] call ALIVE_fnc_profileEntity;
                [_profileEntity, "ranks", _ranks] call ALIVE_fnc_profileEntity;
                [_profileEntity, "side", str(side _group)] call ALIVE_fnc_profileEntity;
                [_profileEntity, "faction", faction _leader] call ALIVE_fnc_profileEntity;
                [_profileEntity, "isPlayer", false] call ALIVE_fnc_profileEntity;
                [_profileEntity, "objectType", "entity"] call ALIVE_fnc_profileEntity;
                
                // Copy waypoints (defensive positions might have patrol routes)
                private _waypoints = waypoints _group;
                if (currentWaypoint _group < count _waypoints) then {
                    for "_i" from (currentWaypoint _group) to (count _waypoints - 1) do {
                        private _profileWaypoint = [(_waypoints select _i)] call ALIVE_fnc_waypointToProfileWaypoint;
                        [_profileEntity, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;
                    };
                };
                
                // If no waypoints, add defensive stance
                if (count waypoints _group <= 1) then {
                    private _defensiveWaypoint = [_position, 50, "MOVE", "COMBAT", 0, [], "WEDGE"] call ALIVE_fnc_createProfileWaypoint;
                    [_profileEntity, "addWaypoint", _defensiveWaypoint] call ALIVE_fnc_profileEntity;
                };
                
                // Register profile
                [ALIVE_profileHandler, "registerProfile", _profileEntity] call ALIVE_fnc_profileHandler;
                
                // Create vehicle profile
                private _vehicleID = [ALIVE_profileHandler, "getNextInsertVehicleID"] call ALIVE_fnc_profileHandler;
                
                private _profileVehicle = [nil, "create"] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "init"] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "profileID", _vehicleID] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "vehicleClass", typeOf _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "position", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "despawnPosition", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "direction", getDir _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "damage", _vehicle call ALIVE_fnc_vehicleGetDamage] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "fuel", fuel _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "ammo", _vehicle call ALIVE_fnc_vehicleGetAmmo] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "side", str(side _vehicle)] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "faction", faction _vehicle] call ALIVE_fnc_profileVehicle;
                [_profileVehicle, "objectType", "vehicle"] call ALIVE_fnc_profileVehicle;
                
                [ALIVE_profileHandler, "registerProfile", _profileVehicle] call ALIVE_fnc_profileHandler;
                
                // Create vehicle assignment
                private _assignments = [_vehicle, _group] call ALIVE_fnc_vehicleAssignmentToProfileVehicleAssignment;
                private _vehicleAssignments = [_vehicleID, _entityID, _assignments];
                
                [_profileEntity, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileEntity;
                [_profileVehicle, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileVehicle;
                
                // Mark vehicle
                _vehicle setVariable ["profileID", _vehicleID];
                
                // Delete originals
                {
                    deleteVehicle _x;
                } forEach _units;
                deleteVehicle _vehicle;
                
                _staticCount = _staticCount + 1;
                
            };
        } else {
            // Empty static weapon - create vehicle-only profile
            private _vehicleID = [ALIVE_profileHandler, "getNextInsertVehicleID"] call ALIVE_fnc_profileHandler;
            
            private _profileVehicle = [nil, "create"] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "init"] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "profileID", _vehicleID] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "vehicleClass", typeOf _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "position", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "despawnPosition", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "direction", getDir _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "damage", _vehicle call ALIVE_fnc_vehicleGetDamage] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "fuel", fuel _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "ammo", _vehicle call ALIVE_fnc_vehicleGetAmmo] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "side", str(side _vehicle)] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "faction", faction _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "objectType", "vehicle"] call ALIVE_fnc_profileVehicle;
            
            [ALIVE_profileHandler, "registerProfile", _profileVehicle] call ALIVE_fnc_profileHandler;
            
            _vehicle setVariable ["profileID", _vehicleID];
            deleteVehicle _vehicle;
            
            _staticCount = _staticCount + 1;
        };
    };
} forEach vehicles;

systemChat format ["Virtualized %1 static defense positions - they will spawn when players approach", _staticCount];