/*
    EW strike listener for ALiVE OCA events.

    Execute once on the server. The script registers an ALiVE event listener
    and triggers the custom EW strike when OPCOM requests an OCA mission.
*/

if (!isServer) exitWith {
    "ew_strike.sqf" remoteExec ["execVM", 2];
    hint "EW strike listener request sent to server.";
};

if (isNil "EW_STRIKE_Cooldown") then {
    EW_STRIKE_Cooldown = 900;
};

EW_STRIKE_fnc_waitForDependencies = {
    private _timeoutAt = time + 60;

    if (isNil "radar_fnc_scanAirbase" || {isNil "radar_fnc_getAirMarkers"}) then {
        [] execVM "radar_system.sqf";
    };

    if (isNil "WAR_RADAR_JAM_fnc_createZone") then {
        [] execVM "radar_jamming.sqf";
    };

    if (isNil "EW_STRIKE_fnc_getGroundAssaultConfig") then {
        [] execVM "ew_strike_ground_selection.sqf";
    };

    waitUntil {
        sleep 0.25;
        !isNil "ALIVE_eventLog" &&
        !isNil "ALIVE_fnc_eventLog" &&
        !isNil "ALIVE_profileHandler" &&
        !isNil "ALIVE_fnc_profileHandler" &&
        !isNil "ALiVE_profileSystem" &&
        !isNil "radar_fnc_scanAirbase" &&
        !isNil "radar_fnc_getAirMarkers" &&
        !isNil "WAR_RADAR_JAM_fnc_createZone" &&
        !isNil "EW_STRIKE_fnc_getGroundAssaultConfig" &&
        { [ALiVE_profileSystem, "startupComplete", false] call ALIVE_fnc_hashGet } ||
        { time > _timeoutAt }
    };

    !(
        isNil "ALIVE_eventLog" ||
        {isNil "ALIVE_fnc_eventLog"} ||
        {isNil "ALIVE_profileHandler"} ||
        {isNil "ALIVE_fnc_profileHandler"} ||
        {isNil "ALiVE_profileSystem"} ||
        {isNil "radar_fnc_scanAirbase"} ||
        {isNil "radar_fnc_getAirMarkers"} ||
        {isNil "WAR_RADAR_JAM_fnc_createZone"} ||
        {isNil "EW_STRIKE_fnc_getGroundAssaultConfig"} ||
        {!([ALiVE_profileSystem, "startupComplete", false] call ALIVE_fnc_hashGet)}
    )
};

EW_STRIKE_fnc_getControllerFromSide = {
    params ["_side"];

    switch (_side) do {
        case east: {"OPFOR"};
        case west: {"BLUFOR"};
        case resistance: {"INDEP"};
        default {"UNKNOWN"};
    }
};

EW_STRIKE_fnc_getPilotClass = {
    params ["_controller"];

    switch (_controller) do {
        case "OPFOR": {"O_Pilot_F"};
        case "BLUFOR": {"B_Pilot_F"};
        case "INDEP": {"I_pilot_F"};
        default {"O_Pilot_F"};
    }
};

EW_STRIKE_fnc_collectAirbases = {
    private _airMarkers = call radar_fnc_getAirMarkers;
    private _airbases = [];

    {
        private _markerName = _x;
        private _markerPos = getMarkerPos _markerName;
        private _scan = [_markerPos, _markerName] call radar_fnc_scanAirbase;
        _scan params ["_pos", "_marker", "_controller", "_radarCount", "_bluPlanes", "_opfPlanes", "_bluRadars", "_opfRadars"];

        if !(_controller isEqualTo "") then {
            _airbases pushBack [_marker, _pos, _controller, _radarCount, _bluPlanes, _opfPlanes, _bluRadars, _opfRadars];
        };
    } forEach _airMarkers;

    _airbases
};

EW_STRIKE_fnc_selectAirbasesForEvent = {
    params ["_attackerController", "_targetPos", "_airbases"];

    private _attackerBases = _airbases select {(_x select 2) isEqualTo _attackerController};
    private _targetBases = _airbases select {
        private _controller = _x select 2;
        _controller != _attackerController &&
        {_controller in ["OPFOR", "BLUFOR", "INDEP"]}
    };

    if (_attackerBases isEqualTo [] || {_targetBases isEqualTo []}) exitWith {[]};

    private _sortedAttackers = [_attackerBases, [_targetPos], {_Input0 distance2D (_x select 1)}, "ASCEND"] call ALiVE_fnc_SortBy;
    private _sortedTargets = [_targetBases, [_targetPos], {_Input0 distance2D (_x select 1)}, "ASCEND"] call ALiVE_fnc_SortBy;

    [
        _sortedAttackers select 0,
        _sortedTargets select 0
    ]
};

EW_STRIKE_fnc_disableAAInRadius = {
    params ["_targetPos", "_targetMarker"];

    private _tierConfig = [2] call WAR_RADAR_JAM_fnc_getTierConfig;
    private _jamRadius = if (_tierConfig isEqualType [] && {count _tierConfig > 0}) then {_tierConfig select 0} else {1000};
    private _jamDuration = missionNamespace getVariable ["WAR_RADAR_JAM_DURATION", 300];

    if ((random 1) >= 0.6) exitWith {
        private _aaFailMsg = format [
            "EW STRIKE: AA suppression roll failed at %1 (40%% miss chance).",
            _targetMarker
        ];
        diag_log format ["[EW_STRIKE] %1", _aaFailMsg];
    };

    private _aaCandidates = _targetPos nearEntities [["LandVehicle", "StaticWeapon"], _jamRadius];
    private _disabledAA = [];

    {
        private _asset = _x;
        if (!alive _asset) then { continue };

        private _isAA =
            (_asset isKindOf "StaticAAWeapon") ||
            {_asset isKindOf "AAA_System_01_base_F"} ||
            {_asset isKindOf "SAM_System_01_base_F"} ||
            {_asset isKindOf "SAM_System_02_base_F"} ||
            {[_asset] call ALiVE_fnc_isAntiAir} ||
            {[_asset] call ALiVE_fnc_isAA};

        if (!_isAA) then { continue };
        if (_asset getVariable ["EW_STRIKE_AA_DISABLED", false]) then { continue };

        _asset setVariable ["EW_STRIKE_AA_DISABLED", true, true];
        _asset setVehicleAmmo 0;
        _asset setVehicleRadar 0;

        {
            _x disableAI "TARGET";
            _x disableAI "AUTOTARGET";
            _x disableAI "FIREWEAPON";
        } forEach crew _asset;

        _disabledAA pushBack _asset;
    } forEach _aaCandidates;

    if !(_disabledAA isEqualTo []) then {
        [_disabledAA, _jamDuration] spawn {
            params ["_assets", "_duration"];
            sleep _duration;

            {
                if (alive _x) then {
                    _x setVehicleAmmo 1;
                    _x setVehicleRadar 1;
                    _x setVariable ["EW_STRIKE_AA_DISABLED", false, true];

                    {
                        _x enableAI "TARGET";
                        _x enableAI "AUTOTARGET";
                        _x enableAI "FIREWEAPON";
                    } forEach crew _x;
                };
            } forEach _assets;
        };
    };

    private _aaMsg = format [
        "EW STRIKE: AA suppression active in %1 radius around %2. AA assets disabled: %3",
        _jamRadius,
        _targetMarker,
        count _disabledAA
    ];
    [_aaMsg] remoteExec ["hint", 0];
    diag_log format ["[EW_STRIKE] %1", _aaMsg];
};

EW_STRIKE_fnc_virtualizeGroupsNear = {
    params ["_spawnCenter"];

    [_spawnCenter] spawn {
        params ["_center"];

        waitUntil {
            !isNil "ALIVE_profileHandler" &&
            !isNil "ALIVE_fnc_profileHandler" &&
            !isNil "ALiVE_profileSystem" &&
            { [ALiVE_profileSystem, "startupComplete", false] call ALIVE_fnc_hashGet }
        };

        sleep 5;

        private _nearUnits = _center nearEntities [["Man", "LandVehicle", "Ship"], 700];
        private _processedGroups = [];
        private _virtualizedFactions = [];
        private _virtualizedCount = 0;

        {
            private _unit = _x;
            if (!alive _unit || {isPlayer _unit}) then { continue };

            private _grp = if (_unit isKindOf "Man") then {
                group _unit
            } else {
                if (count crew _unit > 0) then { group (crew _unit select 0) } else { grpNull }
            };

            if (isNull _grp || {_grp in _processedGroups}) then { continue };
            _processedGroups pushBack _grp;

            private _leader = leader _grp;
            if (isNull _leader || {!alive _leader}) then { continue };
            if (side _grp == sideLogic) then { continue };
            if ({isPlayer _x} count (units _grp) > 0) then { continue };
            if ((_leader getVariable ["profileID", ""]) != "") then { continue };
            if ((_leader getVariable ["agentID", ""]) != "") then { continue };

            private _faction = faction _leader;
            private _groupLabel = groupId _grp;
            private _profile = [false, [_grp], []] call ALIVE_fnc_createProfilesFromUnitsRuntime;

            if (!isNil "_profile") then {
                [_profile, "busy", false] call ALIVE_fnc_hashSet;
                _virtualizedFactions pushBackUnique _faction;
                _virtualizedCount = _virtualizedCount + 1;
                diag_log format ["[EW_STRIKE] Virtualized %1 (%2) into ALiVE", _groupLabel, _faction];
            };
        } forEach _nearUnits;

        {
            private _faction = _x;
            {
                private _opcomFactions = [_x, "factions", []] call ALiVE_fnc_HashGet;
                if (_faction in _opcomFactions) then {
                    [_x, "scantroops"] call ALiVE_fnc_OPCOM;
                };
            } forEach (missionNamespace getVariable ["OPCOM_instances", []]);
        } forEach _virtualizedFactions;

        diag_log format ["[EW_STRIKE] Ground assault virtualization complete: %1 group(s) added to ALiVE", _virtualizedCount];
    };
};

EW_STRIKE_fnc_spawnGroundAssault = {
    params ["_attackerController", "_targetPos", "_targetMarker"];

    private _groundSpawnPos = [];
    private _ringDirections = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];
    _ringDirections = _ringDirections call BIS_fnc_arrayShuffle;

    {
        private _candidate = _targetPos getPos [1000, _x];
        if (!surfaceIsWater _candidate) exitWith {
            _groundSpawnPos = _candidate;
        };
    } forEach _ringDirections;

    if (_groundSpawnPos isEqualTo []) then {
        private _fallback = [_targetPos, 900, 1200, 5, 0, 0.3, 0] call BIS_fnc_findSafePos;
        if (!(_fallback isEqualTo [0, 0, 0]) && {!surfaceIsWater _fallback}) then {
            _groundSpawnPos = _fallback;
        } else {
            _groundSpawnPos = _targetPos getPos [1000, random 360];
        };
    };

    diag_log format ["[EW_STRIKE] Ground assault spawn selected at %1 (safe-land check applied)", _groundSpawnPos];

    private _groundConfig = [_attackerController] call EW_STRIKE_fnc_getGroundAssaultConfig;
    _groundConfig params ["_assaultTier", "_tierDesc", "_groundSide", "_vehicleClasses", "_infSquadCount", "_infantryGroupConfig"];

    private _assaultGroups = [];

    {
        private _vehSpawnPos = _groundSpawnPos getPos [30 + (_forEachIndex * 20), random 360];
        private _vehSpawn = [_vehSpawnPos, random 360, _x, _groundSide] call BIS_fnc_spawnVehicle;
        _vehSpawn params ["_vehicle", "_crew", "_group"];

        if (!isNull _group) then {
            _assaultGroups pushBackUnique _group;
        };
    } forEach _vehicleClasses;

    for "_i" from 1 to _infSquadCount do {
        private _infSpawnPos = _groundSpawnPos getPos [80 + (_i * 25), random 360];
        private _infGroup = [_infSpawnPos, _groundSide, _infantryGroupConfig] call BIS_fnc_spawnGroup;

        if (!isNull _infGroup) then {
            _assaultGroups pushBackUnique _infGroup;
        };
    };

    {
        private _grp = _x;
        if (isNull _grp) then { continue };

        private _wpStage = _grp addWaypoint [_targetPos getPos [300, random 360], 0];
        _wpStage setWaypointType "MOVE";
        _wpStage setWaypointSpeed "FULL";
        _wpStage setWaypointBehaviour "AWARE";
        _wpStage setWaypointCombatMode "YELLOW";

        private _wpAssault = _grp addWaypoint [_targetPos, 0];
        _wpAssault setWaypointType "SAD";
        _wpAssault setWaypointSpeed "FULL";
        _wpAssault setWaypointBehaviour "COMBAT";
        _wpAssault setWaypointCombatMode "RED";
        _wpAssault setWaypointCompletionRadius 100;
    } forEach _assaultGroups;

    private _groundMsg = format [
        "EW STRIKE GROUND ASSAULT: %1 launched on %2. Groups spawned: %3",
        _tierDesc,
        _targetMarker,
        count _assaultGroups
    ];

    [_groundMsg] remoteExec ["hint", 0];
    diag_log format ["[EW_STRIKE] %1", _groundMsg];

    [_groundSpawnPos] call EW_STRIKE_fnc_virtualizeGroupsNear;
};

EW_STRIKE_fnc_launchAirAttack = {
    params ["_attackerController", "_attackerPos", "_attackerMarker", "_targetPos", "_targetMarker"];

    private _attackSide = switch (_attackerController) do {
        case "BLUFOR": {west};
        case "INDEP": {resistance};
        default {east};
    };
    private _pilotClass = [_attackerController] call EW_STRIKE_fnc_getPilotClass;

    diag_log "[EW_STRIKE] Jam established. Waiting 10 seconds before air launch...";
    sleep 10;

    private _allPlanesNearBase = _attackerPos nearEntities ["Plane", 1200];
    private _emptyPlanes = _allPlanesNearBase select {
        alive _x &&
        {count crew _x == 0}
    };

    if (count _emptyPlanes > 5) then {
        _emptyPlanes = _emptyPlanes select [0, 5];
    };

    if (_emptyPlanes isEqualTo []) exitWith {
        private _noPlanesMsg = format [
            "EW STRIKE: Jam active on %1, but no empty %2 planes found at %3.",
            _targetMarker,
            _attackerController,
            _attackerMarker
        ];
        [_noPlanesMsg] remoteExec ["hint", 0];
        diag_log format ["[EW_STRIKE] %1", _noPlanesMsg];
    };

    private _launchedAirAssets = [];

    {
        private _plane = _x;
        private _pilotGroup = createGroup _attackSide;
        private _pilot = _pilotGroup createUnit [_pilotClass, getPosASL _plane, [], 0, "NONE"];
        _pilot moveInDriver _plane;

        private _planePos = getPosASL _plane;
        _plane setPosASL [_planePos select 0, _planePos select 1, 100];
        _plane setVelocityModelSpace [0, 200, 0];
        _plane engineOn true;

        private _wpAttack = _pilotGroup addWaypoint [_targetPos, 0];
        _wpAttack setWaypointType "SAD";
        _wpAttack setWaypointSpeed "FULL";
        _wpAttack setWaypointBehaviour "COMBAT";
        _wpAttack setWaypointCombatMode "RED";

        _launchedAirAssets pushBack [_pilotGroup, _plane];
        sleep 1;
    } forEach _emptyPlanes;

    private _airMsg = format [
        "EW STRIKE: %1 %2 aircraft launched from %3 to attack %4.",
        count _emptyPlanes,
        _attackerController,
        _attackerMarker,
        _targetMarker
    ];

    [_airMsg] remoteExec ["hint", 0];
    diag_log format ["[EW_STRIKE] %1", _airMsg];

    [_launchedAirAssets, _attackerPos, _attackerMarker] spawn {
        params ["_airAssets", "_rtbPos", "_rtbMarker"];

        sleep 600;

        private _rtbCount = 0;

        {
            _x params ["_pilotGroup", "_plane"];

            if (alive _plane && {!isNull _plane} && {(getPosATL _plane select 2) > 10} && {!isNull _pilotGroup}) then {
                {
                    deleteWaypoint _x;
                } forEach waypoints _pilotGroup;

                private _wpRtb = _pilotGroup addWaypoint [_rtbPos, 0];
                _wpRtb setWaypointType "GETOUT";
                _wpRtb setWaypointSpeed "FULL";
                _wpRtb setWaypointBehaviour "AWARE";
                _wpRtb setWaypointCombatMode "YELLOW";
                _wpRtb setWaypointCompletionRadius 100;

                _rtbCount = _rtbCount + 1;
            };
        } forEach _airAssets;

        if (_rtbCount > 0) then {
            private _rtbMsg = format [
                "EW STRIKE: %1 airborne aircraft ordered to RTB at %2.",
                _rtbCount,
                _rtbMarker
            ];

            [_rtbMsg] remoteExec ["hint", 0];
            diag_log format ["[EW_STRIKE] %1", _rtbMsg];
        } else {
            diag_log "[EW_STRIKE] No airborne aircraft remained for RTB order after 10 minutes.";
        };
    };
};

EW_STRIKE_fnc_executeStrike = {
    params ["_eventSide", "_eventFaction", "_targetPos"];

    if (!isServer) exitWith {};

    private _now = time;
    private _nextAllowed = missionNamespace getVariable ["EW_STRIKE_NextAllowedTime", 0];
    if (_now < _nextAllowed) exitWith {
        diag_log format ["[EW_STRIKE] Ignoring OCA trigger due to cooldown. %1 seconds remaining", round (_nextAllowed - _now)];
    };

    if !([] call EW_STRIKE_fnc_waitForDependencies) exitWith {
        diag_log "[EW_STRIKE] ERROR: Dependencies were not ready for OCA-triggered strike.";
    };

    private _attackerController = [_eventSide] call EW_STRIKE_fnc_getControllerFromSide;
    if !(_attackerController in ["OPFOR", "BLUFOR", "INDEP"]) exitWith {
        diag_log format ["[EW_STRIKE] Unsupported attacker side for OCA event: %1 / %2", _eventSide, _eventFaction];
    };

    private _airbases = [] call EW_STRIKE_fnc_collectAirbases;
    if (_airbases isEqualTo []) exitWith {
        diag_log "[EW_STRIKE] ERROR: No valid airbases were returned by radar_fnc_getAirMarkers.";
    };

    private _selectedAirbases = [_attackerController, _targetPos, _airbases] call EW_STRIKE_fnc_selectAirbasesForEvent;
    if (_selectedAirbases isEqualTo []) exitWith {
        diag_log format ["[EW_STRIKE] ERROR: Could not resolve attacker/target airbases for %1", _attackerController];
    };

    missionNamespace setVariable ["EW_STRIKE_NextAllowedTime", _now + EW_STRIKE_Cooldown, true];

    _selectedAirbases params ["_attacker", "_target"];
    _attacker params ["_attackerMarker", "_attackerPos"];
    _target params ["_targetMarker", "_targetMarkerPos"];

    [_targetPos, 2, "EW_STRIKE", _attackerController] call WAR_RADAR_JAM_fnc_createZone;
    [_targetPos, _targetMarker] call EW_STRIKE_fnc_disableAAInRadius;

    private _msg = format [
        "EW STRIKE: %1 base %2 initiated Tier 2 radar jamming on target area at %3.",
        _attackerController,
        _attackerMarker,
        _targetMarker
    ];

    [_msg] remoteExec ["hint", 0];
    diag_log format ["[EW_STRIKE] %1", _msg];

    [_attackerController, _attackerPos, _attackerMarker, _targetPos, _targetMarker] call EW_STRIKE_fnc_launchAirAttack;
    [_attackerController, _targetPos, _targetMarker] call EW_STRIKE_fnc_spawnGroundAssault;
};

EW_STRIKE_fnc_eventListener = {
    params ["_listener", "_operation", "_args"];

    if (_operation != "handleEvent") exitWith {};
    if !(_args isEqualType []) exitWith {};

    private _event = _args;
    private _eventType = [_event, "type", ""] call ALIVE_fnc_hashGet;
    if (_eventType != "ATO_REQUEST") exitWith {};

    private _eventFrom = [_event, "from", ""] call ALIVE_fnc_hashGet;
    if (_eventFrom != "OPCOM") exitWith {};

    private _eventData = [_event, "data", []] call ALIVE_fnc_hashGet;
    if !(_eventData isEqualType [] && {count _eventData > 4}) exitWith {};

    private _eventRequestType = _eventData select 0;
    if (_eventRequestType != "OCA") exitWith {};

    private _eventSide = _eventData select 1;
    private _eventFaction = _eventData select 2;
    private _eventTargetPos = _eventData select 3;

    if !(_eventTargetPos isEqualType [] && {count _eventTargetPos > 1}) exitWith {
        diag_log "[EW_STRIKE] OCA event ignored because it had no valid target position.";
    };

    [_eventSide, _eventFaction, _eventTargetPos] spawn EW_STRIKE_fnc_executeStrike;
};

EW_STRIKE_fnc_bootstrap = {
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["EW_STRIKE_BootstrapStarted", false]) exitWith {};

    missionNamespace setVariable ["EW_STRIKE_BootstrapStarted", true, true];

    [] spawn {
        if !([] call EW_STRIKE_fnc_waitForDependencies) exitWith {
            diag_log "[EW_STRIKE] ERROR: Failed to bootstrap listener because dependencies were not ready.";
            missionNamespace setVariable ["EW_STRIKE_BootstrapStarted", false, true];
        };

        if (missionNamespace getVariable ["EW_STRIKE_ListenerRegistered", false]) exitWith {};

        private _listener = [] call ALIVE_fnc_hashCreate;
        [_listener, "class", "EW_STRIKE_fnc_eventListener"] call ALIVE_fnc_hashSet;

        private _listenerID = [ALIVE_eventLog, "addListener", [_listener, ["ATO_REQUEST"]]] call ALIVE_fnc_eventLog;

        missionNamespace setVariable ["EW_STRIKE_Listener", _listener];
        missionNamespace setVariable ["EW_STRIKE_ListenerID", _listenerID];
        missionNamespace setVariable ["EW_STRIKE_ListenerRegistered", true, true];

        diag_log format ["[EW_STRIKE] Listener registered for ALiVE OCA requests with cooldown %1 seconds", EW_STRIKE_Cooldown];
    };
};

[] call EW_STRIKE_fnc_bootstrap;
