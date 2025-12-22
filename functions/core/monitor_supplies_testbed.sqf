/*
 * Multi-Objective Supply Monitor
 * 
 * Description: Monitors supplies at FOB locations near OPCOM objectives
 * Usage: Execute this script for comprehensive objective supply analysis
 * 
 * Run with: [] execVM "functions\core\monitor_supplies_testbed.sqf"
 * 
 * Features:
 * - Multiple supply box detection across map
 * - Objective-based supply grouping
 * - Supply sorting by total available
 * - Lowest supply marker placement
 * - FOB/Objective supply tracking
 * 
 * Author: GitHub Copilot Assistant
 * Version: 2.0 - Multi-Objective
 */

systemChat "=== MULTI-OBJECTIVE SUPPLY MONITOR ===";

// Check ALiVE availability first
if (isNil "ALiVE_sectorGrid") exitWith {
    systemChat "ERROR: ALiVE Sector Grid not found!";
    hint parseText "<t size='1.2' color='#ff0000'>ERROR</t><br/><t size='0.9'>ALiVE not loaded!</t>";
};

if (isNil "OPCOM_instances" || count OPCOM_instances == 0) exitWith {
    systemChat "ERROR: No OPCOM instances found!";
    hint parseText "<t size='1.2' color='#ff0000'>ERROR</t><br/><t size='0.9'>No OPCOM objectives!</t>";
};

// Find all supply boxes across the map (increased search radius)
systemChat "Scanning for supply boxes across the map...";
private _allSupplyBoxes = [];

// Search from map center with large radius
private _mapCenter = [worldSize/2, worldSize/2, 0];
private _searchRadius = worldSize;

// Only look for specific player-placed supply crates (not ALiVE spawned ones)
private _boxTypes = [
    "O_supplyCrate_F",    // OPFOR Supply Crate
    "B_supplyCrate_F"     // BLUFOR Supply Crate
];

{
    private _boxes = _mapCenter nearObjects [_x, _searchRadius];
    _allSupplyBoxes append _boxes;
} forEach _boxTypes;

systemChat format ["Found %1 supply boxes total", count _allSupplyBoxes];

if (count _allSupplyBoxes == 0) exitWith {
    systemChat "ERROR: No supply boxes found on the map!";
    hint parseText "<t size='1.2' color='#ff0000'>ERROR</t><br/><t size='0.9'>No supply boxes found!</t>";
};

// Function to calculate combat supplies for a box
private _fnc_getBoxSupplies = {
    params ["_supplyBox"];
    
    // Get supply information using cargo commands (combat supplies only)
    private _magCargo = getMagazineCargo _supplyBox;
    private _wpnCargo = getWeaponCargo _supplyBox;
    private _itemCargo = getItemCargo _supplyBox;

    // Extract items and counts
    private _magTypes = _magCargo select 0;
    private _magCounts = _magCargo select 1;
    private _wpnTypes = _wpnCargo select 0;
    private _wpnCounts = _wpnCargo select 1;
    private _itemTypes = _itemCargo select 0;
    private _itemCounts = _itemCargo select 1;

    // Filter items to only include combat-relevant supplies
    private _filteredItemCounts = [];
    {
        private _itemType = _itemTypes select _forEachIndex;
        private _itemCount = _itemCounts select _forEachIndex;
        
        // Include medical items, explosives, and combat equipment
        if (
            // Medical items
            (_itemType find "FirstAid" >= 0) ||
            (_itemType find "Medikit" >= 0) ||
            (_itemType find "FieldDressing" >= 0) ||
            (_itemType find "Morphine" >= 0) ||
            (_itemType find "Epinephrine" >= 0) ||
            (_itemType find "Bandage" >= 0) ||
            (_itemType find "BloodBag" >= 0) ||
            // Explosives
            (_itemType find "Explosive" >= 0) ||
            (_itemType find "Mine" >= 0) ||
            (_itemType find "Charge" >= 0) ||
            (_itemType find "Grenade" >= 0) ||
            (_itemType find "HandGrenade" >= 0) ||
            (_itemType find "SmokeShell" >= 0) ||
            (_itemType find "Chemlight" >= 0) ||
            (_itemType find "FlareGreen" >= 0) ||
            (_itemType find "FlareRed" >= 0) ||
            (_itemType find "FlareWhite" >= 0) ||
            (_itemType find "FlareYellow" >= 0)
        ) then {
            _filteredItemCounts pushBack _itemCount;
        };
    } forEach _itemTypes;

    // Calculate totals
    private _totalMags = 0;
    {_totalMags = _totalMags + _x} forEach _magCounts;

    private _totalWpns = 0;
    {_totalWpns = _totalWpns + _x} forEach _wpnCounts;

    private _totalItems = 0;
    {_totalItems = _totalItems + _x} forEach _filteredItemCounts;

    private _totalSupplies = _totalMags + _totalWpns + _totalItems;
    
    [_totalMags, _totalWpns, _totalItems, _totalSupplies]
};

// Create objectives data structure
private _objectiveSupplies = [];

systemChat "Analyzing supply boxes and matching to objectives...";

// Process each supply box
{
    private _supplyBox = _x;
    private _boxPos = getPosATL _supplyBox;
    private _boxType = typeOf _supplyBox;
    
    // Find closest OPCOM objective
    private _closestObjective = objNull;
    private _closestDistance = 999999;
    private _closestObjInfo = [];
    
    {
        private _opcom = _x;
        private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
        private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;
        private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
        
        {
            private _objective = _x;
            private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
            private _distance = _boxPos distance2D _objCenter;
            
            if (_distance < _closestDistance) then {
                _closestDistance = _distance;
                _closestObjective = _objective;
                
                private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                private _objType = [_objective, "objectiveType", "unknown"] call ALIVE_fnc_hashGet;
                private _objSize = [_objective, "size", 0] call ALIVE_fnc_hashGet;
                private _objID = [_objective, "objectiveID", "unknown"] call ALIVE_fnc_hashGet;
                
                _closestObjInfo = [_objID, _objType, _objState, _opcomSide, _opcomFactions, _objSize, _objCenter];
            };
        } forEach _objectives;
    } forEach OPCOM_instances;
    
    // Calculate supplies for this box
    private _supplies = [_supplyBox] call _fnc_getBoxSupplies;
    _supplies params ["_mags", "_wpns", "_items", "_total"];
    
    // Add to objective supplies data
    if (count _closestObjInfo > 0) then {
        _closestObjInfo params ["_objID", "_objType", "_objState", "_opcomSide", "_opcomFactions", "_objSize", "_objCenter"];
        
        // Check if objective already exists in our data
        private _foundIndex = -1;
        {
            if ((_x select 0) == _objID) then {
                _foundIndex = _forEachIndex;
            };
        } forEach _objectiveSupplies;
        
        if (_foundIndex >= 0) then {
            // Add supplies to existing objective
            private _existing = _objectiveSupplies select _foundIndex;
            _existing set [7, (_existing select 7) + _mags];     // Total mags
            _existing set [8, (_existing select 8) + _wpns];     // Total weapons
            _existing set [9, (_existing select 9) + _items];    // Total items
            _existing set [10, (_existing select 10) + _total];  // Total supplies
            _existing set [11, (_existing select 11) + 1];       // Box count
            (_existing select 12) pushBack [_supplyBox, _boxPos, _total]; // Box details
        } else {
            // Create new objective entry
            _objectiveSupplies pushBack [
                _objID,           // 0: Objective ID
                _objType,         // 1: Type
                _objState,        // 2: State
                _opcomSide,       // 3: Side
                _opcomFactions,   // 4: Factions
                _objSize,         // 5: Size
                _objCenter,       // 6: Center position
                _mags,            // 7: Total magazines
                _wpns,            // 8: Total weapons
                _items,           // 9: Total items
                _total,           // 10: Total supplies
                1,                // 11: Box count
                [[_supplyBox, _boxPos, _total]] // 12: Box details
            ];
        };
    };
} forEach _allSupplyBoxes;

// Sort objectives by total supplies (highest first)
_objectiveSupplies sort false;
_objectiveSupplies = [_objectiveSupplies, [], {_x select 10}, "DESCEND"] call BIS_fnc_sortBy;

systemChat format ["Analyzed %1 objectives with supply boxes", count _objectiveSupplies];

// Clean up old markers
{
    if (markerText _x find "SUPPLY_" == 0) then {
        deleteMarker _x;
    };
} forEach allMapMarkers;

// Find lowest supply box for marking
private _lowestSupplyBox = objNull;
private _lowestSupplyTotal = 999999;
private _lowestObjID = "";

{
    private _objData = _x;
    private _boxes = _objData select 12;
    
    {
        _x params ["_box", "_boxPos", "_boxTotal"];
        if (_boxTotal < _lowestSupplyTotal) then {
            _lowestSupplyTotal = _boxTotal;
            _lowestSupplyBox = _box;
            _lowestObjID = _objData select 0;
        };
    } forEach _boxes;
} forEach _objectiveSupplies;

// Create marker for lowest supply box
if (!isNull _lowestSupplyBox) then {
    private _markerPos = getPosATL _lowestSupplyBox;
    private _marker = createMarker [format ["SUPPLY_LOWEST_%1", time], _markerPos];
    _marker setMarkerType "mil_warning";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [1.5, 1.5];
    _marker setMarkerText format ["LOW SUPPLY\n%1 items\n%2", _lowestSupplyTotal, _lowestObjID];
    
    systemChat format ["CRITICAL: Lowest supply box marked at %1 (%2 items)", _lowestObjID, _lowestSupplyTotal];
};

// Display results
systemChat "=== OBJECTIVE SUPPLY ANALYSIS ===";

private _hintText = "<t size='1.4' color='#ffff00'>OBJECTIVE SUPPLY STATUS</t><br/><br/>";

{
    _x params ["_objID", "_objType", "_objState", "_opcomSide", "_opcomFactions", "_objSize", "_objCenter", "_totalMags", "_totalWpns", "_totalItems", "_totalSupplies", "_boxCount", "_boxDetails"];
    
    private _sideColor = switch (_opcomSide) do {
        case "WEST": {"#0080ff"};
        case "EAST": {"#ff4040"};
        case "GUER": {"#40ff40"};
        default {"#ff9900"};
    };
    
    _hintText = _hintText + format [
        "<t size='1.1' color='%1'>%2. %3</t><br/>" +
        "<t size='0.9'>Side: %4 | State: %5</t><br/>" +
        "<t size='0.9'>Boxes: %6 | Total: %7 items</t><br/>" +
        "<t size='0.9'>Mags: %8 | Wpns: %9 | Items: %10</t><br/><br/>",
        _sideColor,
        _forEachIndex + 1,
        _objID,
        _opcomSide,
        _objState,
        _boxCount,
        _totalSupplies,
        _totalMags,
        _totalWpns,
        _totalItems
    ];
    
    // Output to system chat
    systemChat format ["%1. %2 (%3): %4 total supplies (%5 boxes)", 
        _forEachIndex + 1, _objID, _opcomSide, _totalSupplies, _boxCount];
    systemChat format ["   Breakdown: %1 mags, %2 weapons, %3 items", _totalMags, _totalWpns, _totalItems];
    
} forEach _objectiveSupplies;

// Add summary to hint
if (count _objectiveSupplies > 0) then {
    private _topObj = _objectiveSupplies select 0;
    private _bottomObj = _objectiveSupplies select ((count _objectiveSupplies) - 1);
    
    _hintText = _hintText + format [
        "<t size='1.1' color='#00ff00'>HIGHEST: %1 (%2)</t><br/>" +
        "<t size='1.1' color='#ff4040'>LOWEST: %3 (%4)</t>",
        _topObj select 0,
        _topObj select 10,
        _bottomObj select 0,
        _bottomObj select 10
    ];
} else {
    _hintText = _hintText + "<t size='1.1' color='#ff4040'>No objectives with supplies found!</t>";
};

hint parseText _hintText;

systemChat "=== MULTI-OBJECTIVE SUPPLY MONITOR COMPLETE ===";
