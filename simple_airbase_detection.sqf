/*
    Enhanced ALiVE Airbase Detection
    Detects both hangars and runway objects to find all airbases
    
    This combines ALiVE's air cluster detection with direct runway object detection
*/

private _debug = true;

if (_debug) then {
    systemChat "Starting enhanced ALiVE airbase detection...";
    ["=== Enhanced ALiVE Airbase Detection ==="] call ALiVE_fnc_dump;
};

// Runway and airstrip object types to search for
private _runwayTypes = [
    "Land_Runway_PAPI",
    "Land_Runway_PAPI_2", 
    "Land_Runway_PAPI_3",
    "Land_Runway_PAPI_4",
    "Land_TentHangar_V1_F",
    "Land_Airport_Tower_F",
    "Land_Airport_01_hangar_F",
    "Land_Airport_02_hangar_left_F",
    "Land_Airport_02_hangar_right_F",
    "Land_Hangar_F",
    "Land_Runway_1_end_F",
    "Land_Runway_2_end_F",
    "Land_Airport_01_terminal_F",
    "Land_Airport_02_terminal_F"
];

// Additional hangar types for completeness
private _hangarTypes = [
    "Land_TentHangar_V1_F",
    "Land_Airport_01_hangar_F", 
    "Land_Airport_02_hangar_left_F",
    "Land_Airport_02_hangar_right_F",
    "Land_Hangar_F"
];

if (_debug) then {
    ["Searching for runway objects: %1", _runwayTypes] call ALiVE_fnc_dump;
    ["Searching for hangar objects: %1", _hangarTypes] call ALiVE_fnc_dump;
};

// Method 1: Find all runway/airstrip objects on the map
private _allRunwayObjects = [];
{
    private _objects = (position player) nearObjects [_x, 25000]; // Search entire map
    _allRunwayObjects append _objects;
    if (_debug && count _objects > 0) then {
        ["Found %1 objects of type %2", count _objects, _x] call ALiVE_fnc_dump;
    };
} forEach _runwayTypes;

if (_debug) then {
    ["Total runway/airport objects found: %1", count _allRunwayObjects] call ALiVE_fnc_dump;
};

// Method 2: Check ALiVE air clusters for hangars (original method)
private _airbaseLocations = [];

if !(isNil "ALIVE_clustersMilAir") then {
    if (_debug) then {
        ["ALiVE air clusters found, checking for hangars..."] call ALiVE_fnc_dump;
    };
    
    // Get air clusters exactly like ALiVE does in fnc_MP.sqf
    private _airClusters = ALIVE_clustersMilAir select 2;
    
    if (_debug) then {
        ["Found %1 air clusters", count _airClusters] call ALiVE_fnc_dump;
    };
    
    // Process each air cluster exactly like ALiVE does
    {
        private _cluster = _x;
        
        // Get nodes from cluster
        private _nodes = [_cluster, "nodes"] call ALiVE_fnc_hashGet;
        
        if (!isNil "_nodes") then {
            // Find air buildings in cluster nodes
            private _buildings = [_nodes, ALIVE_airBuildingTypes] call ALiVE_fnc_findBuildingsInClusterNodes;
            
            if (_debug) then {
                private _center = [_cluster, "center", [0,0,0]] call ALiVE_fnc_hashGet;
                ["Air cluster at %1 has %2 air buildings", _center, count _buildings] call ALiVE_fnc_dump;
            };
            
            // Add buildings to airbase locations
            {
                private _building = _x;
                private _position = position _building;
                _airbaseLocations pushBack [_position, typeOf _building, "HANGAR"];
                
            } forEach _buildings;
            
        };
        
    } forEach _airClusters;
};

// Method 3: Add all runway objects to airbase locations
{
    private _obj = _x;
    private _position = position _obj;
    private _type = typeOf _obj;
    
    // Check if this location is already covered by a hangar (within 500m)
    private _nearExisting = false;
    {
        if ((_x select 0) distance _position < 500) then {
            _nearExisting = true;
        };
    } forEach _airbaseLocations;
    
    if !_nearExisting then {
        _airbaseLocations pushBack [_position, _type, "RUNWAY"];
        if (_debug) then {
            ["Added runway object %1 at %2", _type, _position] call ALiVE_fnc_dump;
        };
    };
    
} forEach _allRunwayObjects;
// Function to get ownership of a position using ALiVE sector data
private _fnc_getPositionOwnership = {
    params ["_position"];
    
    // Check if ALiVE sector grid is available
    if (isNil "ALiVE_sectorGrid") exitWith {"Unknown"};
    
    // Get the sector for this position
    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;
    
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {"Unknown"};
    
    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (isNil "_sectorData" || count _sectorData == 0) exitWith {"Neutral"};
    
    // Check for profile-based sector control (most accurate)
    private _dominatingSide = "Neutral";
    private _maxCount = 0;
    
    // Check entities by side (ALiVE profiles)
    if ("entitiesBySide" in (_sectorData select 1)) then {
        private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_entitiesBySide select 1)) then {
                private _sideEntities = [_entitiesBySide, _side] call ALIVE_fnc_hashGet;
                private _entityCount = count _sideEntities;
                
                if (_entityCount > _maxCount) then {
                    _maxCount = _entityCount;
                    _dominatingSide = _side;
                };
            };
        } forEach _sides;
    };
    
    // Also check vehicles by side
    if ("vehiclesBySide" in (_sectorData select 1)) then {
        private _vehiclesBySide = [_sectorData, "vehiclesBySide"] call ALIVE_fnc_hashGet;
        private _sides = ["EAST", "WEST", "GUER", "CIV"];
        
        {
            private _side = _x;
            if (_side in (_vehiclesBySide select 1)) then {
                private _sideVehicles = [_vehiclesBySide, _side] call ALIVE_fnc_hashGet;
                private _vehicleCount = count _sideVehicles;
                
                // If this side already has entities, add vehicles to the count
                if (_side == _dominatingSide) then {
                    _maxCount = _maxCount + _vehicleCount;
                } else {
                    // If this side has more total presence, it becomes the new dominating side
                    if (_vehicleCount > _maxCount) then {
                        _maxCount = _vehicleCount;
                        _dominatingSide = _side;
                    };
                };
            };
        } forEach _sides;
    };
    
    // Fallback: Check OPCOM objectives if no profile-based control found
    if (_dominatingSide == "Neutral" && !isNil "OPCOM_instances") then {
        {
            private _opcom = _x;
            private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
            private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
            
            {
                private _objective = _x;
                private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                
                // Check if objective is in this sector and is actively controlled
                if ([_sector, "within", _objCenter] call ALIVE_fnc_sector) then {
                    if (_objState in ["defend", "defending", "reserve"]) then {
                        _dominatingSide = _opcomSide;
                    };
                };
            } forEach _objectives;
        } forEach OPCOM_instances;
    };
    
    _dominatingSide
};
// Now create markers for all detected airbases with ownership information
if (_debug) then {
    ["Total airbase locations found: %1", count _airbaseLocations] call ALiVE_fnc_dump;
    ["Checking ownership for each airbase..."] call ALiVE_fnc_dump;
};

{
    private _location = _x;
    private _position = _location select 0;
    private _objectType = _location select 1;
    private _sourceType = _location select 2; // "HANGAR" or "RUNWAY"
    
    // Get ownership information for this position
    private _ownership = [_position] call _fnc_getPositionOwnership;
    
    if (_debug) then {
        ["Airbase at %1 is controlled by: %2", _position, _ownership] call ALiVE_fnc_dump;
    };
    
    // Determine marker color based on ownership
    private _markerColor = "ColorGrey"; // Default for unknown/neutral
    switch (_ownership) do {
        case "EAST": { _markerColor = "ColorRed"; };
        case "WEST": { _markerColor = "ColorBlue"; };
        case "GUER": { _markerColor = "ColorGreen"; };
        case "CIV": { _markerColor = "ColorYellow"; };
        case "Neutral": { _markerColor = "ColorGrey"; };
        default { _markerColor = "ColorGrey"; };
    };
    
    // Create highly visible marker with ownership info
    private _markerName = format["airbase_%1_%2_%3", _sourceType, floor(_position select 0), floor(_position select 1)];
    private _marker = createMarker [_markerName, _position];
    _marker setMarkerType "hd_air";
    _marker setMarkerSize [1.5, 1.5];
    _marker setMarkerColor _markerColor;
    
    // Create descriptive text with ownership
    private _ownershipText = switch (_ownership) do {
        case "EAST": { "OPFOR" };
        case "WEST": { "BLUFOR" };
        case "GUER": { "INDEP" };
        case "CIV": { "CIVILIAN" };
        case "Neutral": { "NEUTRAL" };
        default { "UNKNOWN" };
    };
    
    if (_sourceType == "HANGAR") then {
        _marker setMarkerText format["%1 HANGAR\n[%2]", _ownershipText, _objectType];
    } else {
        _marker setMarkerText format["%1 AIRSTRIP\n[%2]", _ownershipText, _objectType];
    };
    
    // Create a circle around it for visibility with faction color
    private _circleMarker = createMarker [_markerName + "_circle", _position];
    _circleMarker setMarkerShape "ELLIPSE";
    _circleMarker setMarkerSize [150, 150];
    _circleMarker setMarkerAlpha 0.3;
    _circleMarker setMarkerColor _markerColor;
    
    if (_debug) then {
        ["Created %1 marker at %2 for %3 controlled by %4", _sourceType, _position, _objectType, _ownershipText] call ALiVE_fnc_dump;
    };
    
} forEach _airbaseLocations;

// Clean up markers after 120 seconds (extended time)
[{
    {
        if (_x find "airbase_" == 0) then {
            deleteMarker _x;
        };
    } forEach allMapMarkers;
    systemChat "Airbase markers cleaned up";
}, [], 120] call CBA_fnc_waitAndExecute;

if (_debug) then {
    ["=== Enhanced Airbase Detection Complete ==="] call ALiVE_fnc_dump;
};

systemChat format["Enhanced airbase detection finished - found %1 locations", count _airbaseLocations];