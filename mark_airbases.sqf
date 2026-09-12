/*
    mark_airbases.sqf
    
    Marks all ALiVE airbases on the map using the same logic as Military Placement
    Usage: [] execVM "mark_airbases.sqf"
    
    Markers will automatically disappear after 1 minute.
*/

systemChat "=== MARKING ALIVE AIRBASES ===";

// Find ALiVE Military Placement modules
private _mpModules = [];
{
    if (typeOf _x == "ALiVE_mil_placement") then {
        _mpModules pushBack _x;
    };
} forEach allMissionObjects "Logic";

systemChat format ["Found %1 Military Placement modules", count _mpModules];

if (count _mpModules == 0) exitWith {
    systemChat "No ALiVE Military Placement modules found!";
    hint "No ALiVE Military Placement modules found!";
};

// Clear existing airbase markers
{
    deleteMarker _x;
} forEach (allMapMarkers select {_x find "alive_airbase_" == 0});

private _totalAirbasesMarked = 0;
private _markerNames = []; // Track marker names for cleanup

{
    private _mpModule = _x;
    private _faction = [_mpModule, "faction"] call ALiVE_mil_placement;
    private _side = "";
    
    // Get faction side
    if (!isNil "_faction") then {
        private _factionConfig = _faction call ALiVE_fnc_configGetFactionClass;
        if (!isNil "_factionConfig") then {
            private _factionSideNumber = getNumber(_factionConfig >> "side");
            _side = _factionSideNumber call ALIVE_fnc_sideNumberToText;
        };
    };
    
    systemChat format ["Processing MP module %1: Faction=%2, Side=%3", _forEachIndex, _faction, _side];
    
    // Get air objectives from Military Placement module
    private _airClusters = [_mpModule, "objectivesAir"] call ALiVE_mil_placement;
    
    if (!isNil "_airClusters" && typeName _airClusters == "ARRAY" && count _airClusters > 0) then {
        systemChat format ["  Found %1 air clusters", count _airClusters];
        
        {
            private _airCluster = _x;
            private _clusterCenter = [_airCluster, "center", [0,0,0]] call ALIVE_fnc_hashGet;
            private _clusterSize = [_airCluster, "size", 0] call ALIVE_fnc_hashGet;
            
            // Get nodes from air cluster (same as ALiVE placement logic)
            private _nodes = [_airCluster, "nodes", []] call ALIVE_fnc_hashGet;
            
            if (count _nodes > 0) then {
                // Find air buildings in the cluster nodes (same as ALiVE logic)
                private _buildings = [_nodes, ALIVE_airBuildingTypes] call ALIVE_fnc_findBuildingsInClusterNodes;
                
                if (count _buildings > 0) then {
                    // This cluster has air buildings - mark it as an airbase
                    private _markerName = format ["alive_airbase_%1", _totalAirbasesMarked];
                    private _marker = createMarker [_markerName, _clusterCenter];
                    
                    _marker setMarkerType "mil_airfield";
                    _marker setMarkerSize [1.5, 1.5];
                    _marker setMarkerText format ["Airbase %1 (%2)", _totalAirbasesMarked + 1, _side];
                    
                    // Set marker color based on side
                    if (_side == "EAST") then {
                        _marker setMarkerColor "ColorRed";
                    } else {
                        if (_side == "WEST") then {
                            _marker setMarkerColor "ColorBlue";
                        } else {
                            _marker setMarkerColor "ColorGreen"; // Independent
                        };
                    };
                    
                    _markerNames pushBack _markerName;
                    
                    systemChat format ["✓ Marked airbase %1: %2 (%3) - %4 air buildings, Size: %5", 
                        _totalAirbasesMarked + 1, _clusterCenter, _side, count _buildings, _clusterSize];
                    
                    _totalAirbasesMarked = _totalAirbasesMarked + 1;
                } else {
                    systemChat format ["✗ Air cluster at %1 has no air buildings", _clusterCenter];
                };
            } else {
                systemChat format ["✗ Air cluster at %1 has no nodes", _clusterCenter];
            };
        } forEach _airClusters;
    } else {
        systemChat format ["  No air clusters found for MP module %1", _forEachIndex];
    };
    
} forEach _mpModules;

// Summary
systemChat format ["=== AIRBASE MARKING COMPLETE ==="];
systemChat format ["Total airbases marked: %1", _totalAirbasesMarked];

if (_totalAirbasesMarked > 0) then {
    // Show summary hint
    private _hintText = format [
        "<t size='1.2' color='#ffff00'>ALiVE AIRBASES MARKED</t><br/>" +
        "<t size='0.9'>Total: %1 airbases</t><br/>" +
        "<t size='0.8' color='#ffaaaa'>Markers will disappear in 60 seconds</t>",
        _totalAirbasesMarked
    ];
    hint parseText _hintText;
    
    // Schedule marker cleanup after 60 seconds
    [_markerNames] spawn {
        params ["_markers"];
        sleep 60;
        
        {
            deleteMarker _x;
        } forEach _markers;
        
        systemChat "ALiVE airbase markers removed.";
        hint "ALiVE airbase markers removed.";
    };
    
} else {
    hint parseText "<t color='#ff6666'>No ALiVE airbases found!<br/>Check Military Placement settings.</t>";
};