/*
    Global Zeus-only virtualization for ALiVE.

    What it does:
    - Tags units/groups created via Zeus curator placement
    - Periodically scans all groups
    - Virtualizes only Zeus-tagged AI groups that are not already profile-managed

    Safety:
    - Script-spawned groups are ignored by default (not Zeus-tagged)
    - Groups/units flagged with TWS_DoNotVirtualize or ALIVE ignore flags are skipped
*/

if (!isServer) exitWith {};

if (isNil "TWS_GV_intervalSeconds") then { TWS_GV_intervalSeconds = 20; };
if (isNil "TWS_GV_graceSeconds") then { TWS_GV_graceSeconds = 10; };
if (isNil "TWS_GV_debug") then { TWS_GV_debug = false; };
if (isNil "TWS_GV_registeredCurators") then { TWS_GV_registeredCurators = createHashMap; };
if (isNil "TWS_GV_excludedRadarClasses") then {
    TWS_GV_excludedRadarClasses = [
        "O_Radar_System_02_F",
        "B_Radar_System_01_F"
    ];
};

TWS_fnc_gvLog = {
    params ["_msg"];
    if (TWS_GV_debug) then {
        diag_log format ["[TWS_GV] %1", _msg];
    };
};

TWS_fnc_markZeusGroup = {
    params ["_entity"];

    if (isNull _entity) exitWith {objNull};
    if !(_entity isKindOf "CAManBase") exitWith {objNull};

    private _grp = group _entity;
    if (isNull _grp) exitWith {objNull};

    _entity setVariable ["TWS_ZeusPlaced", true, true];
    _grp setVariable ["TWS_ZeusPlaced", true, true];
    _grp setVariable ["TWS_ZeusPlacedAt", time, false];

    [_grp]
};

TWS_fnc_tagPlacedEntity = {
    params ["_entity"];

    if (isNull _entity) exitWith {};

    if (_entity isKindOf "CAManBase") exitWith {
        [_entity] call TWS_fnc_markZeusGroup;
    };

    private _crew = crew _entity;
    {
        [_x] call TWS_fnc_markZeusGroup;
    } forEach _crew;
};

TWS_fnc_registerCurator = {
    params ["_curator"];

    if (isNull _curator) exitWith {};

    private _key = str _curator;
    if (TWS_GV_registeredCurators getOrDefault [_key, false]) exitWith {};

    _curator addEventHandler ["CuratorObjectPlaced", {
        params ["_curator", "_entity"];
        [_entity] call TWS_fnc_tagPlacedEntity;
    }];

    TWS_GV_registeredCurators set [_key, true];
    [format ["Curator handler registered: %1", _key]] call TWS_fnc_gvLog;
};

TWS_fnc_isAlreadyProfiled = {
    params ["_group"];

    private _leader = leader _group;
    if (isNull _leader) exitWith {false};

    ((_leader getVariable ["profileID", ""]) != "") || ((_leader getVariable ["agentID", ""]) != "")
};

TWS_fnc_isRadarStaticOrAirVehicle = {
    params ["_vehicle"];

    if (isNull _vehicle) exitWith {false};

    private _cls = typeOf _vehicle;
    if (_cls in TWS_GV_excludedRadarClasses) exitWith {true};
    if (_vehicle isKindOf "StaticWeapon") exitWith {true};
    if (_vehicle isKindOf "Air") exitWith {true};

    private _clsLower = toLower _cls;
    (_clsLower find "radar") >= 0 || (_clsLower find "sam") >= 0 || (_clsLower find "aaa") >= 0
};

TWS_fnc_isGroupExcluded = {
    params ["_group"];

    if (isNull _group) exitWith {true};
    if (side _group == sideLogic) exitWith {true};
    if !(_group getVariable ["TWS_ZeusPlaced", false]) exitWith {true};
    if (_group getVariable ["TWS_DoNotVirtualize", false]) exitWith {true};

    private _placedAt = _group getVariable ["TWS_ZeusPlacedAt", -1];
    if (_placedAt >= 0 && {(time - _placedAt) < TWS_GV_graceSeconds}) exitWith {true};

    private _units = units _group;
    if ((count _units) == 0) exitWith {true};
    if ({isPlayer _x} count _units > 0) exitWith {true};

    private _groupVehicles = [];
    {
        private _veh = vehicle _x;
        if (!isNull _veh && !(_veh isEqualTo _x)) then {
            _groupVehicles pushBackUnique _veh;
        };
    } forEach _units;

    if ({[_x] call TWS_fnc_isRadarStaticOrAirVehicle} count _groupVehicles > 0) exitWith {true};

    // Respect explicit ignore flags on any member of the group.
    private _hasIgnoreFlag = false;
    {
        if (
            (_x getVariable ["TWS_DoNotVirtualize", false]) ||
            (_x getVariable ["ALIVE_profileIgnore", false]) ||
            (_x getVariable ["ALiVE_SYS_PROFILE_IGNORE", false])
        ) exitWith {
            _hasIgnoreFlag = true;
        };
    } forEach _units;
    if (_hasIgnoreFlag) exitWith {true};

    false
};

TWS_fnc_virtualizeZeusGroup = {
    params ["_group"];

    if (isNil "ALIVE_profileHandler") exitWith {false};
    if ([_group] call TWS_fnc_isGroupExcluded) exitWith {false};
    if ([_group] call TWS_fnc_isAlreadyProfiled) exitWith {false};

    private _leader = leader _group;
    if (isNull _leader || {isPlayer _leader}) exitWith {false};

    private _units = units _group;
    private _groupSide = str (side _group);
    private _sourceFaction = faction _leader;
    private _effectiveFaction = _sourceFaction;
    private _matchingFactionOpcoms = [];
    private _matchingSideOpcoms = [];

    if (!isNil "OPCOM_INSTANCES") then {
        {
            private _opcom = _x;
            private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
            private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;

            if (_opcomSide == _groupSide) then {
                _matchingSideOpcoms pushBack _opcom;
                if (_sourceFaction in _opcomFactions) then {
                    _matchingFactionOpcoms pushBack _opcom;
                };
            };
        } forEach OPCOM_INSTANCES;

        if (count _matchingFactionOpcoms == 0 && {count _matchingSideOpcoms > 0}) then {
            private _fallbackFactions = [_matchingSideOpcoms select 0, "factions", []] call ALIVE_fnc_hashGet;
            if (count _fallbackFactions > 0) then {
                _effectiveFaction = _fallbackFactions select 0;
            };
        };
    };

    private _position = getPosATL _leader;
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
    [_profileEntity, "side", _groupSide] call ALIVE_fnc_profileEntity;
    [_profileEntity, "faction", _effectiveFaction] call ALIVE_fnc_profileEntity;
    [_profileEntity, "isPlayer", false] call ALIVE_fnc_profileEntity;
    [_profileEntity, "objectType", "infantry"] call ALIVE_fnc_profileEntity;
    [_profileEntity, "aiBehaviour", "SAFE"] call ALIVE_fnc_profileEntity;

    private _waypoints = waypoints _group;
    if (currentWaypoint _group < count _waypoints) then {
        for "_i" from (currentWaypoint _group) to (count _waypoints - 1) do {
            private _profileWaypoint = [(_waypoints select _i)] call ALIVE_fnc_waypointToProfileWaypoint;
            [_profileEntity, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;
        };
    };

    [ALIVE_profileHandler, "registerProfile", _profileEntity] call ALIVE_fnc_profileHandler;

    private _groupVehicles = [];
    {
        private _veh = vehicle _x;
        if !(_veh isEqualTo _x) then {
            _groupVehicles pushBackUnique _veh;
        };
    } forEach _units;

    {
        private _vehicle = _x;
        if ((_vehicle getVariable ["profileID", ""]) == "") then {
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
            [_profileVehicle, "engineOn", isEngineOn _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "canFire", canFire _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "canMove", canMove _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "needReload", needReload _vehicle] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "side", _groupSide] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "faction", _effectiveFaction] call ALIVE_fnc_profileVehicle;
            [_profileVehicle, "objectType", (typeOf _vehicle) call ALIVE_fnc_vehicleGetKindOf] call ALIVE_fnc_profileVehicle;

            [ALIVE_profileHandler, "registerProfile", _profileVehicle] call ALIVE_fnc_profileHandler;

            private _assignments = [_vehicle, _group] call ALIVE_fnc_vehicleAssignmentToProfileVehicleAssignment;
            private _vehicleAssignments = [_vehicleID, _entityID, _assignments];
            [_profileEntity, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileEntity;
            [_profileVehicle, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileVehicle;

            _vehicle setVariable ["profileID", _vehicleID];
        };
    } forEach _groupVehicles;

    {
        deleteVehicle _x;
    } forEach _units;

    {
        deleteVehicle _x;
    } forEach _groupVehicles;

    _group call ALiVE_fnc_DeleteGroupRemote;

    private _opcomsToRefresh = if (count _matchingFactionOpcoms > 0) then {_matchingFactionOpcoms} else {_matchingSideOpcoms};
    {
        [_x, "scantroops"] call ALiVE_fnc_OPCOM;
    } forEach _opcomsToRefresh;

    [format ["Virtualized Zeus group %1 (%2 units).", _entityID, count _units]] call TWS_fnc_gvLog;
    true
};

[] spawn {
    waitUntil {sleep 1; !isNil "ALIVE_profileHandler"};

    while {true} do {
        {
            [_x] call TWS_fnc_registerCurator;
        } forEach allCurators;

        {
            [_x] call TWS_fnc_virtualizeZeusGroup;
        } forEach allGroups;

        sleep TWS_GV_intervalSeconds;
    };
};

["global_virtualize.sqf active: Zeus-only ALiVE virtualization loop started."] call TWS_fnc_gvLog;
