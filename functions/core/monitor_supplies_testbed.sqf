/*
 * Communication Hub Supply Monitor
 *
 * Description: Monitors OPFOR/BLUFOR communication hubs and nearby supply crates.
 * Usage: [] execVM "functions\core\monitor_supplies_testbed.sqf"
 */

systemChat "=== COMM HUB SUPPLY MONITOR ===";

private _supplyClasses = [
    "O_supplyCrate_F",
    "B_supplyCrate_F",
    "CargoNet_01_box_F",
    "Box_East_Ammo_F",
    "Box_East_Wps_F"
];

private _fnc_getSectorControlAtPos = {
    params ["_position"];

    if (!isNil "RES_fnc_getSectorControl") exitWith {
        [_position] call RES_fnc_getSectorControl
    };

    if (isNil "ALiVE_sectorGrid") exitWith {"NONE"};
    private _sector = [ALiVE_sectorGrid, "positionToSector", _position] call ALIVE_fnc_sectorGrid;
    if (count _sector == 0 || {count (_sector select 1) == 0}) exitWith {"NONE"};

    private _sectorData = [_sector, "data"] call ALIVE_fnc_hashGet;
    if (isNil "_sectorData" || count _sectorData == 0) exitWith {"NONE"};

    private _dominatingSide = "NONE";
    private _maxCount = 0;

    if ("entitiesBySide" in (_sectorData select 1)) then {
        private _entitiesBySide = [_sectorData, "entitiesBySide"] call ALIVE_fnc_hashGet;
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
        } forEach ["EAST", "WEST", "GUER", "CIV"];
    };

    switch (_dominatingSide) do {
        case "EAST": {"OPFOR"};
        case "WEST": {"BLUFOR"};
        case "GUER": {"INDEP"};
        default {"NONE"};
    }
};

private _fnc_getBoxSupplies = {
    params ["_supplyBox"];

    private _magCargo = getMagazineCargo _supplyBox;
    private _wpnCargo = getWeaponCargo _supplyBox;
    private _itemCargo = getItemCargo _supplyBox;

    private _magCounts = _magCargo select 1;
    private _wpnCounts = _wpnCargo select 1;
    private _itemTypes = _itemCargo select 0;
    private _itemCounts = _itemCargo select 1;

    private _filteredItemCounts = [];
    {
        private _itemType = _itemTypes select _forEachIndex;
        private _itemCount = _itemCounts select _forEachIndex;

        if (
            (_itemType find "FirstAid" >= 0) ||
            (_itemType find "Medikit" >= 0) ||
            (_itemType find "FieldDressing" >= 0) ||
            (_itemType find "Morphine" >= 0) ||
            (_itemType find "Epinephrine" >= 0) ||
            (_itemType find "Bandage" >= 0) ||
            (_itemType find "BloodBag" >= 0) ||
            (_itemType find "Explosive" >= 0) ||
            (_itemType find "Mine" >= 0) ||
            (_itemType find "Charge" >= 0) ||
            (_itemType find "Grenade" >= 0) ||
            (_itemType find "HandGrenade" >= 0) ||
            (_itemType find "SmokeShell" >= 0) ||
            (_itemType find "Chemlight" >= 0) ||
            (_itemType find "Flare" >= 0)
        ) then {
            _filteredItemCounts pushBack _itemCount;
        };
    } forEach _itemTypes;

    private _totalMags = 0;
    { _totalMags = _totalMags + _x; } forEach _magCounts;

    private _totalWpns = 0;
    { _totalWpns = _totalWpns + _x; } forEach _wpnCounts;

    private _totalItems = 0;
    { _totalItems = _totalItems + _x; } forEach _filteredItemCounts;

    [_totalMags, _totalWpns, _totalItems, (_totalMags + _totalWpns + _totalItems)]
};

private _fnc_getSuppliesNearHub = {
    params ["_hubPos", ["_radius", 220]];

    private _boxes = [];
    {
        _boxes append (_hubPos nearObjects [_x, _radius]);
    } forEach _supplyClasses;

    _boxes = _boxes arrayIntersect _boxes;

    private _totalMags = 0;
    private _totalWpns = 0;
    private _totalItems = 0;
    private _totalSupplies = 0;

    {
        private _parts = [_x] call _fnc_getBoxSupplies;
        _parts params ["_m", "_w", "_i", "_t"];
        _totalMags = _totalMags + _m;
        _totalWpns = _totalWpns + _w;
        _totalItems = _totalItems + _i;
        _totalSupplies = _totalSupplies + _t;
    } forEach _boxes;

    [_totalMags, _totalWpns, _totalItems, _totalSupplies, count _boxes]
};

private _hubType = "RuggedTerminal_01_communications_hub_F";
private _hubs = nearestObjects [[worldSize / 2, worldSize / 2, 0], [_hubType], worldSize];

if ((count _hubs) == 0) exitWith {
    systemChat "ERROR: No communication hubs found!";
    hint parseText "<t size='1.2' color='#ff0000'>ERROR</t><br/><t size='0.9'>No RuggedTerminal communication hubs found!</t>";
};

private _hubData = [];

{
    private _hub = _x;
    private _hubPos = getPosATL _hub;
    private _control = [_hubPos] call _fnc_getSectorControlAtPos;
    private _supply = [_hubPos, 220] call _fnc_getSuppliesNearHub;
    _supply params ["_mags", "_wpns", "_items", "_total", "_boxCount"];

    _hubData pushBack [
        _hub,
        _hubPos,
        _control,
        _mags,
        _wpns,
        _items,
        _total,
        _boxCount,
        mapGridPosition _hub
    ];
} forEach _hubs;

private _opfHubs = _hubData select {(_x select 2) isEqualTo "OPFOR"};
private _bluHubs = _hubData select {(_x select 2) isEqualTo "BLUFOR"};

_hubData = [_hubData, [], {_x select 6}, "ASCEND"] call BIS_fnc_sortBy;

{
    if (markerText _x find "SUPPLY_HUB_" == 0) then {
        deleteMarker _x;
    };
} forEach allMapMarkers;

if ((count _hubData) > 0) then {
    private _lowest = _hubData select 0;
    _lowest params ["_hub", "_hubPos", "_control", "_mags", "_wpns", "_items", "_total", "_boxCount", "_grid"];

    private _marker = createMarker [format ["SUPPLY_HUB_LOWEST_%1", time], _hubPos];
    _marker setMarkerType "mil_warning";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [1.5, 1.5];
    _marker setMarkerText format ["LOW HUB SUPPLY\n%1 items\n%2", _total, _control];

    systemChat format ["CRITICAL: Lowest hub supply at %1 (%2 total)", _grid, _total];
};

private _hintText = "<t size='1.4' color='#ffff00'>COMM HUB SUPPLY STATUS</t><br/><br/>";
_hintText = _hintText + format ["<t size='0.95'>Total hubs: %1 | OPFOR hubs: %2 | BLUFOR hubs: %3</t><br/><br/>", count _hubData, count _opfHubs, count _bluHubs];

{
    _x params ["_hub", "_hubPos", "_control", "_mags", "_wpns", "_items", "_total", "_boxCount", "_grid"];

    private _sideColor = switch (_control) do {
        case "OPFOR": {"#ff4040"};
        case "BLUFOR": {"#0080ff"};
        case "INDEP": {"#40ff40"};
        default {"#ff9900"};
    };

    _hintText = _hintText + format [
        "<t size='1.05' color='%1'>%2. HUB %3 (%4)</t><br/>" +
        "<t size='0.9'>Control: %5 | Crates: %6 | Total: %7</t><br/>" +
        "<t size='0.85'>Mags: %8 | Wpns: %9 | Items: %10</t><br/><br/>",
        _sideColor,
        _forEachIndex + 1,
        _grid,
        _control,
        _control,
        _boxCount,
        _total,
        _mags,
        _wpns,
        _items
    ];

    systemChat format ["%1. HUB %2 (%3) -> %4 supplies from %5 crates", _forEachIndex + 1, _grid, _control, _total, _boxCount];
} forEach _hubData;

hint parseText _hintText;
systemChat "=== COMM HUB SUPPLY MONITOR COMPLETE ===";
