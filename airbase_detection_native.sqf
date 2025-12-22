/*
    ALiVE Native Airbase Detection Script
    Uses ALiVE's built-in airport system instead of Military Placement modules
    
    This approach uses the actual airport functions from fnc_ATO.sqf
*/

// Initialize results - use hash like ALiVE does
private _airbases = [] call ALiVE_fnc_hashCreate;
private _debug = true;

if (_debug) then {
    systemChat "Starting native ALiVE airbase detection...";
    ["=== ALiVE Native Airbase Detection ==="] call ALiVE_fnc_dump;
};

// Function to get airport information using native ALiVE functions
ALiVE_fnc_getAirportInfo = {
    params ["_airportID"];
    
    private _info = [] call ALiVE_fnc_hashCreate;
    [_info, "id", _airportID] call ALiVE_fnc_hashSet;
    
    // Get taxi positions (this will tell us if airport exists and is valid)
    private _taxiIn = [_airportID, "ilsTaxiIn", 0] call ALiVE_fnc_getAirportTaxiPos;
    private _taxiOut = [_airportID, "ilsTaxisOff", 0] call ALiVE_fnc_getAirportTaxiPos;
    private _ilsPos = [_airportID, "ilsPosition", 0] call ALiVE_fnc_getAirportTaxiPos;
    
    if (count _taxiIn > 0) then {
        [_info, "taxiIn", _taxiIn] call ALiVE_fnc_hashSet;
        [_info, "taxiOut", _taxiOut] call ALiVE_fnc_hashSet;
        [_info, "ilsPosition", _ilsPos] call ALiVE_fnc_hashSet;
        
        // Calculate center position from taxi positions
        private _centerPos = [0, 0, 0];
        if (count _taxiIn >= 2) then {
            _centerPos = [_taxiIn select 0, _taxiIn select 1, 0];
        };
        [_info, "position", _centerPos] call ALiVE_fnc_hashSet;
        
        // Determine airport type
        private _type = "Unknown";
        if (_airportID == 0) then { _type = "Primary Airport"; };
        if (_airportID > 0 && _airportID < 100) then { _type = format["Secondary Airport %1", _airportID]; };
        if (_airportID >= 100) then { _type = format["Dynamic Runway/Carrier %1", _airportID - 100]; };
        [_info, "type", _type] call ALiVE_fnc_hashSet;
        
        true
    } else {
        false
    };
};

// Check for primary airport (ID 0)
if ([0] call ALiVE_fnc_getAirportInfo) then {
    private _airportInfo = [0] call ALiVE_fnc_getAirportInfo;
    [_airbases, "airport_0", _airportInfo] call ALiVE_fnc_hashSet;
    
    if (_debug) then {
        ["Found Primary Airport (ID 0)"] call ALiVE_fnc_dump;
    };
};

// Check for secondary airports (ID 1-99)
for "_i" from 1 to 20 do { // Check first 20 secondary airports
    if ([_i] call ALiVE_fnc_getAirportInfo) then {
        private _airportInfo = [_i] call ALiVE_fnc_getAirportInfo;
        [_airbases, format["airport_%1", _i], _airportInfo] call ALiVE_fnc_hashSet;
        
        if (_debug) then {
            ["Found Secondary Airport (ID %1)", _i] call ALiVE_fnc_dump;
        };
    };
};

// Check for dynamic runways/carriers (ID 100+)
// ALiVE_Carriers should contain carrier objects
if (!isNil "ALiVE_Carriers") then {
    {
        private _carrierID = _forEachIndex + 100;
        if ([_carrierID] call ALiVE_fnc_getAirportInfo) then {
            private _airportInfo = [_carrierID] call ALiVE_fnc_getAirportInfo;
            [_airbases, format["carrier_%1", _forEachIndex], _airportInfo] call ALiVE_fnc_hashSet;
            
            if (_debug) then {
                ["Found Carrier/Dynamic Runway (ID %1)", _carrierID] call ALiVE_fnc_dump;
            };
        };
    } forEach ALiVE_Carriers;
};

// Alternative method: Use air clusters from ALiVE's cluster system
if (!isNil "ALIVE_clustersMilAir") then {
    if (_debug) then {
        ["Checking ALiVE Air Clusters..."] call ALiVE_fnc_dump;
    };
    
    private _airClusters = ALIVE_clustersMilAir select 2;
    {
        private _cluster = _x;
        private _center = [_cluster, "center", [0,0,0]] call ALiVE_fnc_hashGet;
        private _size = [_cluster, "size", 0] call ALiVE_fnc_hashGet;
        
        // Get nearest airport ID for this cluster
        private _nearestAirportID = [_center] call ALiVE_fnc_getNearestAirportID;
        
        private _clusterInfo = [] call ALiVE_fnc_hashCreate;
        [_clusterInfo, "position", _center] call ALiVE_fnc_hashSet;
        [_clusterInfo, "size", _size] call ALiVE_fnc_hashSet;
        [_clusterInfo, "airportID", _nearestAirportID] call ALiVE_fnc_hashSet;
        [_clusterInfo, "type", "Air Cluster"] call ALiVE_fnc_hashSet;
        
        [_airbases, format["cluster_%1", _forEachIndex], _clusterInfo] call ALiVE_fnc_hashSet;
        
        if (_debug) then {
            ["Air Cluster at %1, nearest airport ID: %2", _center, _nearestAirportID] call ALiVE_fnc_dump;
        };
    } forEach _airClusters;
};

// Check ownership using the approach we developed earlier
private _checkOwnership = {
    params ["_position"];
    
    private _ownership = "Unknown";
    private _nearestSector = [_position] call ALiVE_fnc_sectorNear;
    
    if (!isNil "_nearestSector") then {
        private _sectorData = [ALiVE_sectorGrid, _nearestSector] call ALiVE_fnc_hashGet;
        
        if (!isNil "_sectorData") then {
            // Try profile-based detection first
            private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALiVE_fnc_hashGet;
            if (!isNil "_entitiesBySide" && (_entitiesBySide isEqualType [])) then {
                private _westCount = [_entitiesBySide, "WEST", []] call ALiVE_fnc_hashGet;
                private _eastCount = [_entitiesBySide, "EAST", []] call ALiVE_fnc_hashGet;
                
                if (count _westCount > count _eastCount) then { _ownership = "WEST"; };
                if (count _eastCount > count _westCount) then { _ownership = "EAST"; };
                if (count _westCount == count _eastCount) then { _ownership = "Contested"; };
            } else {
                // Fallback to sector control
                private _sectorControl = [_sectorData, "sectorControl"] call ALiVE_fnc_hashGet;
                if (!isNil "_sectorControl") then {
                    _ownership = _sectorControl;
                };
            };
        };
    };
    
    _ownership
};

// Add ownership information to all detected airbases
// Use hash access pattern like ALiVE does - iterate over known keys
private _airbaseTypes = ["airport_0"];
for "_i" from 1 to 20 do { _airbaseTypes pushBack format["airport_%1", _i]; };
if (!isNil "ALiVE_Carriers") then {
    for "_i" from 0 to (count ALiVE_Carriers - 1) do { _airbaseTypes pushBack format["carrier_%1", _i]; };
};
if (!isNil "ALIVE_clustersMilAir") then {
    private _airClusters = ALIVE_clustersMilAir select 2;
    for "_i" from 0 to (count _airClusters - 1) do { _airbaseTypes pushBack format["cluster_%1", _i]; };
};

{
    private _key = _x;
    private _airbaseData = [_airbases, _key] call ALiVE_fnc_hashGet;
    
    if (!isNil "_airbaseData") then {
        private _position = [_airbaseData, "position", [0,0,0]] call ALiVE_fnc_hashGet;
        
        if !(_position isEqualTo [0,0,0]) then {
            private _ownership = [_position] call _checkOwnership;
            [_airbaseData, "ownership", _ownership] call ALiVE_fnc_hashSet;
            
            if (_debug) then {
                private _type = [_airbaseData, "type", "Unknown"] call ALiVE_fnc_hashGet;
                ["Airbase: %1, Position: %2, Ownership: %3", _type, _position, _ownership] call ALiVE_fnc_dump;
            };
        };
    };
} forEach _airbaseTypes;

// Create markers for visualization
{
    private _key = _x;
    private _airbaseData = [_airbases, _key] call ALiVE_fnc_hashGet;
    
    if (!isNil "_airbaseData") then {
        private _position = [_airbaseData, "position", [0,0,0]] call ALiVE_fnc_hashGet;
        private _ownership = [_airbaseData, "ownership", "Unknown"] call ALiVE_fnc_hashGet;
        private _type = [_airbaseData, "type", "Unknown"] call ALiVE_fnc_hashGet;
        
        if !(_position isEqualTo [0,0,0]) then {
            private _markerName = format["airbase_native_%1", _forEachIndex];
            private _marker = createMarker [_markerName, _position];
            _marker setMarkerType "hd_air";
            _marker setMarkerSize [1, 1];
            _marker setMarkerText format["%1 (%2)", _type, _ownership];
            
            // Set color based on ownership
            switch (_ownership) do {
                case "WEST": { _marker setMarkerColor "ColorBlue"; };
                case "EAST": { _marker setMarkerColor "ColorRed"; };
                case "Contested": { _marker setMarkerColor "ColorYellow"; };
                default { _marker setMarkerColor "ColorGrey"; };
            };
            
            if (_debug) then {
                ["Created marker %1 for %2 at %3", _markerName, _type, _position] call ALiVE_fnc_dump;
            };
        };
    };
} forEach _airbaseTypes;

// Clean up markers after 60 seconds
[{
    {
        if (_x find "airbase_native_" == 0) then {
            deleteMarker _x;
        };
    } forEach allMapMarkers;
    systemChat "Native airbase markers cleaned up";
}, [], 60] call CBA_fnc_waitAndExecute;

if (_debug) then {
    ["=== Native Airbase Detection Complete ==="] call ALiVE_fnc_dump;
    // Count entries in hash by checking each possible key
    private _count = 0;
    {
        private _data = [_airbases, _x] call ALiVE_fnc_hashGet;
        if (!isNil "_data") then { _count = _count + 1; };
    } forEach _airbaseTypes;
    ["Found %1 airbases total", _count] call ALiVE_fnc_dump;
};

// Return the results
_airbases