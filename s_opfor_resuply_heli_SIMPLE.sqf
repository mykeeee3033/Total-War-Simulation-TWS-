/*
 * s_opfor_resuply_heli_SIMPLE.sqf
 * Smart OPFOR helicopter supply system
 * Automatically delivers to lowest supply objective
 */

TWS_OPFLOGI_fnc_hasDepotSupplies = {
    params ["_depotPos", ["_radius", 200]];

    private _supplyClasses = [
        "O_supplyCrate_F",
        "CargoNet_01_box_F",
        "Box_East_Ammo_F",
        "Box_East_Wps_F"
    ];

    private _supplyObjects = [];
    {
        _supplyObjects append (_depotPos nearObjects [_x, _radius]);
    } forEach _supplyClasses;

    (count _supplyObjects) > 0
};

TWS_OPFLOGI_supplyClasses = [
    "O_supplyCrate_F",
    "CargoNet_01_box_F",
    "Box_East_Ammo_F",
    "Box_East_Wps_F"
];

if (isNil "TWS_OPFLOGI_fobAmmoStats") then { TWS_OPFLOGI_fobAmmoStats = createHashMap; };
if (isNil "TWS_OPFLOGI_cargoNetClass") then { TWS_OPFLOGI_cargoNetClass = "O_CargoNet_01_ammo_F"; };
if (isNil "TWS_OPFLOGI_hubClass") then { TWS_OPFLOGI_hubClass = "RuggedTerminal_01_communications_hub_F"; };
if (isNil "TWS_OPFLOGI_hubClassList") then { TWS_OPFLOGI_hubClassList = [TWS_OPFLOGI_hubClass]; };
if (isNil "TWS_OPFLOGI_fobMaxSupplyCapacity") then { TWS_OPFLOGI_fobMaxSupplyCapacity = 500; };
if (isNil "TWS_OPFLOGI_resupplyThresholdPct") then { TWS_OPFLOGI_resupplyThresholdPct = 0.5; };
if (isNil "TWS_OPFLOGI_loopSleepSeconds") then { TWS_OPFLOGI_loopSleepSeconds = 900; };
if (isNil "TWS_OPFLOGI_dispatchCooldownSeconds") then { TWS_OPFLOGI_dispatchCooldownSeconds = 600; };
if (isNil "TWS_OPFLOGI_missionTimeoutSeconds") then { TWS_OPFLOGI_missionTimeoutSeconds = 1200; };
if (isNil "TWS_OPFLOGI_missionActive") then { TWS_OPFLOGI_missionActive = false; };
if (isNil "TWS_OPFLOGI_missionStartTime") then { TWS_OPFLOGI_missionStartTime = -1; };
if (isNil "TWS_OPFLOGI_lastDispatchTime") then { TWS_OPFLOGI_lastDispatchTime = -1; };
if (isNil "TWS_OPFLOGI_activeMissionHubId") then { TWS_OPFLOGI_activeMissionHubId = ""; };

TWS_OPFLOGI_fnc_getSectorControlAtPos = {
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

TWS_OPFLOGI_fnc_getBoxSupplies = {
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
            (_itemType find "FirstAid" >= 0) || (_itemType find "Medikit" >= 0) ||
            (_itemType find "Explosive" >= 0) || (_itemType find "Mine" >= 0) ||
            (_itemType find "Grenade" >= 0) || (_itemType find "SmokeShell" >= 0)
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

    _totalMags + _totalWpns + _totalItems
};

TWS_OPFLOGI_fnc_getBoxSupplyMetrics = {
    params ["_supplyBox"];

    private _fallbackTotal = [_supplyBox] call TWS_OPFLOGI_fnc_getBoxSupplies;
    private _cap = maxLoad _supplyBox;
    private _currentLoad = loadAbs _supplyBox;

    if (_cap <= 0) then {
        _cap = (TWS_OPFLOGI_fobMaxSupplyCapacity max 1);
        _currentLoad = _fallbackTotal;
    };

    private _pctRaw = (_currentLoad / (_cap max 1)) min 1;
    [_currentLoad, _cap, _pctRaw, _fallbackTotal]
};

TWS_OPFLOGI_fnc_getHubCargoNet = {
    params ["_position", ["_radius", 220]];

    private _nets = _position nearObjects [TWS_OPFLOGI_cargoNetClass, _radius];
    _nets = _nets select {alive _x};
    {
        _x setVariable ["ALIVE_profileIgnore", true, true];
        _x setVariable ["ALiVE_SYS_PROFILE_IGNORE", true, true];
        _x setVariable ["TWS_DoNotVirtualize", true, true];
    } forEach _nets;
    if ((count _nets) == 0) exitWith {objNull};

    private _nearest = objNull;
    private _bestDist = 1e10;
    {
        private _d = _position distance2D (getPosATL _x);
        if (_d < _bestDist) then {
            _bestDist = _d;
            _nearest = _x;
        };
    } forEach _nets;

    _nearest
};

TWS_OPFLOGI_fnc_getHubAmmoStatus = {
    params ["_hubPos", ["_radius", 220]];

    private _net = [_hubPos, _radius] call TWS_OPFLOGI_fnc_getHubCargoNet;
    if (isNull _net) exitWith { [objNull, 0, 0, 0, 0] };

    private _metrics = [_net] call TWS_OPFLOGI_fnc_getBoxSupplyMetrics;
    _metrics params ["_currentLoad", "_cap", "_pctRaw", "_fallbackTotal"];
    private _threshold = TWS_OPFLOGI_resupplyThresholdPct max 0.01;
    private _pctNormalized = if (_pctRaw >= _threshold) then {1} else {(_pctRaw / _threshold) min 1};
    [_net, _currentLoad, _pctNormalized, _cap, _pctRaw, _fallbackTotal]
};

TWS_OPFLOGI_fnc_updateHubAmmoStat = {
    params ["_hubId", "_hubPos", ["_reason", "scan"]];

    private _status = [_hubPos, 220] call TWS_OPFLOGI_fnc_getHubAmmoStatus;
    _status params ["_net", "_total", "_pctNormalized", "_cap", "_pctRaw", "_fallbackTotal"];
    TWS_OPFLOGI_fobAmmoStats set [_hubId, [time, _total, _pctNormalized, _cap, !isNull _net, _reason, _pctRaw, _fallbackTotal]];
    publicVariable "TWS_OPFLOGI_fobAmmoStats";
    _status
};

TWS_OPFLOGI_fnc_collectHubCandidates = {
    private _candidates = [];

    {
        private _hubs = allMissionObjects _x;
        {
            _candidates pushBack [
                _x,
                getPosATL _x,
                format ["COMM_HUB_%1", mapGridPosition _x],
                true
            ];
        } forEach _hubs;
    } forEach TWS_OPFLOGI_hubClassList;

    if ((count _candidates) == 0) then {
        private _nets = allMissionObjects TWS_OPFLOGI_cargoNetClass;
        {
            _candidates pushBack [
                objNull,
                getPosATL _x,
                format ["COMM_HUB_NET_%1_%2", mapGridPosition _x, _forEachIndex],
                false
            ];
        } forEach _nets;
    };

    _candidates
};

TWS_OPFLOGI_fnc_setMissionState = {
    params ["_active", ["_hubId", ""], ["_reason", ""]];
    TWS_OPFLOGI_missionActive = _active;
    if (_active) then {
        TWS_OPFLOGI_missionStartTime = time;
        TWS_OPFLOGI_lastDispatchTime = time;
        TWS_OPFLOGI_activeMissionHubId = _hubId;
    } else {
        TWS_OPFLOGI_activeMissionHubId = "";
    };

    if (_reason != "") then {
        systemChat format ["[Supply] Mission state: %1 (%2)", if (_active) then {"ACTIVE"} else {"IDLE"}, _reason];
    };
};

if (isServer) then {
    private _singlePass = false;
    if (!isNil "_this" && {typeName _this == "ARRAY"} && {count _this > 0}) then {
        _singlePass = _this select 0;
    };

    while { true } do {
        systemChat "[Supply] Checking for available helicopters and low supply locations...";

        // Prevent duplicate dispatches while an existing mission is still in transit.
        if (TWS_OPFLOGI_missionActive) then {
            private _missionAge = if (TWS_OPFLOGI_missionStartTime >= 0) then {time - TWS_OPFLOGI_missionStartTime} else {0};
            if (_missionAge < TWS_OPFLOGI_missionTimeoutSeconds) then {
                systemChat format [
                    "[Supply] Active resupply mission already running for %1 (%2s elapsed).",
                    TWS_OPFLOGI_activeMissionHubId,
                    round _missionAge
                ];
                if (_singlePass) then {
                    break;
                };
                sleep TWS_OPFLOGI_loopSleepSeconds;
                continue;
            } else {
                [false, "", "mission-timeout-reset"] call TWS_OPFLOGI_fnc_setMissionState;
            };
        };

        // Global cooldown between dispatches to avoid rapid back-to-back missions.
        if (TWS_OPFLOGI_lastDispatchTime >= 0) then {
            private _sinceLastDispatch = time - TWS_OPFLOGI_lastDispatchTime;
            if (_sinceLastDispatch < TWS_OPFLOGI_dispatchCooldownSeconds) then {
                systemChat format [
                    "[Supply] Dispatch cooldown active (%1s remaining).",
                    round (TWS_OPFLOGI_dispatchCooldownSeconds - _sinceLastDispatch)
                ];
                if (_singlePass) then {
                    break;
                };
                sleep TWS_OPFLOGI_loopSleepSeconds;
                continue;
            };
        };

        private _depotPos = getMarkerPos "cargo_depot_o";

        if (!([_depotPos, 200] call TWS_OPFLOGI_fnc_hasDepotSupplies)) then {
            systemChat "[Supply] No crates near cargo depot - skipping resupply run until airport logistics delivers crates.";
            if (_singlePass) then {
                break;
            };
            sleep TWS_OPFLOGI_loopSleepSeconds;
            continue;
        };
        
        // Find the OPFOR-controlled communication hub with the lowest CARGO NET ammo level.
        private _targetPos = [];
        private _targetObjID = "";
        private _lowestSupplyTotal = 999999;
        private _lowestSupplyPct = 1;
        private _targetHubPos = [];
        private _targetHub = objNull;
        private _targetCargoNet = objNull;
        
        systemChat "[Supply] Scanning communication hubs for OPFOR cargo-net ammo priorities...";
        private _hubCandidates = [] call TWS_OPFLOGI_fnc_collectHubCandidates;

        if ((count _hubCandidates) == 0) then {
            systemChat "[Supply] No communication hubs or cargo nets found - mission cancelled";
        } else {
            {
                _x params ["_hub", "_hubPos", "_hubId", "_isRealHub"];
                private _control = [_hubPos] call TWS_OPFLOGI_fnc_getSectorControlAtPos;

                if !(_control isEqualTo "OPFOR") then {
                    continue;
                };

                private _ammoStatus = [_hubId, _hubPos, "scan"] call TWS_OPFLOGI_fnc_updateHubAmmoStat;
                _ammoStatus params ["_hubCargoNet", "_totalSupplies", "_supplyPct", "_supplyCap", "_supplyPctRaw", "_fallbackCount"];

                if (isNull _hubCargoNet) then {
                    continue;
                };

                systemChat format [
                    "[Supply] OPFOR hub at %1 cargo-net load: %2/%3 (%4%%)",
                    mapGridPosition _hubPos,
                    round _totalSupplies,
                    round _supplyCap,
                    round (_supplyPctRaw * 100)
                ];

                if (_supplyPctRaw >= TWS_OPFLOGI_resupplyThresholdPct) then {
                    continue;
                };

                if (_supplyPctRaw < _lowestSupplyPct || {_supplyPctRaw == _lowestSupplyPct && {_totalSupplies < _lowestSupplyTotal}}) then {
                    _lowestSupplyPct = _supplyPctRaw;
                    _lowestSupplyTotal = _totalSupplies;
                    _targetHub = _hub;
                    _targetCargoNet = _hubCargoNet;
                    _targetHubPos = _hubPos;
                    _targetPos = _hubPos;
                    _targetObjID = _hubId;
                };
            } forEach _hubCandidates;

            if (count _targetPos == 0 || {_targetPos isEqualTo [0,0,0]}) then {
                systemChat "[Supply] No OPFOR-controlled communication hub found - mission cancelled";
            } else {
                systemChat format [
                    "[Supply] TARGET HUB: %1 (cargo-net supplies: %2 / %3%%)",
                    _targetObjID,
                    _lowestSupplyTotal,
                    round (((if (_lowestSupplyPct >= TWS_OPFLOGI_resupplyThresholdPct) then {1} else {(_lowestSupplyPct / (TWS_OPFLOGI_resupplyThresholdPct max 0.01)) min 1}) * 100))
                ];

                // Find nearest helipad to the selected communication hub.
                private _helipadTypes = [
                    "Land_HelipadEmpty_F", "Land_HelipadCircle_F", "Land_HelipadCivil_F",
                    "Land_HelipadRescue_F", "Land_HelipadSquare_F", "HeliH", "HeliHEmpty",
                    "HeliHCivil", "HeliHRescue"
                ];

                private _nearestHelipad = objNull;
                private _nearestHelipadDist = 999999;
                private _helipadSearchRadius = 1000;

                {
                    private _helipads = _targetHubPos nearObjects [_x, _helipadSearchRadius];
                    {
                        private _dist = _targetHubPos distance2D (getPosATL _x);
                        if (_dist < _nearestHelipadDist) then {
                            _nearestHelipadDist = _dist;
                            _nearestHelipad = _x;
                        };
                    } forEach _helipads;
                } forEach _helipadTypes;

                if (!isNull _nearestHelipad) then {
                    private _helipadPos = getPosATL _nearestHelipad;
                    systemChat format ["[Supply] Nearest hub helipad is %1m away - using helipad for unload.", round _nearestHelipadDist];
                    _targetPos = _helipadPos;
                } else {
                    systemChat format ["[Supply] WARNING: No helipad found within %1m of hub; unloading near terminal.", _helipadSearchRadius];
                };
            };
        };
        
        // Continue with helicopter operations if we have a target
        if (count _targetPos > 0) then {
            // Look for helicopters near cargo depot
            private _depotPos = getMarkerPos "cargo_depot_o";
            private _nearbyHelis = _depotPos nearEntities ["Helicopter", 300];
            
            // Filter to empty helicopters (any side)
            private _availableHelis = _nearbyHelis select {
                count crew _x == 0 && 
                alive _x
            };
            
            // Debug: Show details about each helicopter found
            {
                private _heliCrew = count crew _x;
                private _heliSide = side _x;
                private _heliAlive = alive _x;
                systemChat format ["[Supply DEBUG] Heli %1: crew=%2, side=%3, alive=%4", typeOf _x, _heliCrew, _heliSide, _heliAlive];
            } forEach _nearbyHelis;
            
            systemChat format ["[Supply] Found %1 helicopters, %2 available", count _nearbyHelis, count _availableHelis];
            
            if (count _availableHelis > 0) then {
            private _selectedHeli = _availableHelis select 0;

            [true, _targetObjID, "dispatch"] call TWS_OPFLOGI_fnc_setMissionState;
            
            systemChat format ["[Supply] Using helicopter: %1", typeOf _selectedHeli];
            
            // Create helicopter group and pilot
            private _heliGroup = createGroup east;
            private _pilot = _heliGroup createUnit ["O_Pilot_F", getPosASL _selectedHeli, [], 0, "NONE"];
            _pilot moveInDriver _selectedHeli;
            
            systemChat "[Supply] Pilot spawned in helicopter";
            
            // Set helicopter behavior
            _heliGroup setBehaviour "SAFE";
            _heliGroup setCombatMode "GREEN";
            
            systemChat "[Supply] Pilot ready for mission";
            
            // Create waypoint to pick up any cargo at depot (HOOK)
            private _wpLoad = _heliGroup addWaypoint [_depotPos, 0];
            _wpLoad setWaypointType "HOOK";
            _wpLoad setWaypointCompletionRadius 30;
            _wpLoad setWaypointSpeed "NORMAL";
            
            // Create waypoint to delivery location (use dynamic target)
            private _wpDeliver = _heliGroup addWaypoint [_targetPos, 0];
            _wpDeliver setWaypointType "MOVE";
            _wpDeliver setWaypointCompletionRadius 50;
            _wpDeliver setWaypointSpeed "NORMAL";
            
            // Create waypoint to drop supplies (UNHOOK)
            private _wpUnload = _heliGroup addWaypoint [_targetPos, 0];
            _wpUnload setWaypointType "UNHOOK";
            _wpUnload setWaypointCompletionRadius 30;
            _wpUnload setWaypointSpeed "NORMAL";
            
            // Return to depot and get out
            private _wpReturn = _heliGroup addWaypoint [_depotPos, 0];
            _wpReturn setWaypointType "GETOUT";
            _wpReturn setWaypointCompletionRadius 50;
            _wpReturn setWaypointSpeed "NORMAL";

            // Monitor delivery and refill nearest hub supply box, then order nearby OPFOR groups to rearm.
            [_selectedHeli, _targetPos, _targetHubPos, _targetObjID] spawn {
                params ["_heli", "_deliveryPos", "_hubPos", "_hubId"];

                private _finishMission = {
                    params [["_reason", "completed"]];
                    [false, "", _reason] call TWS_OPFLOGI_fnc_setMissionState;
                };

                waitUntil {
                    sleep 5;
                    (!alive _heli) || (isNull _heli) || (_heli distance2D _deliveryPos < 100)
                };

                if (!alive _heli || isNull _heli) exitWith {
                    systemChat "[Supply] Helicopter lost before delivery";
                    ["heli-lost"] call _finishMission;
                };

                systemChat "[Supply] Helicopter arrived at delivery zone";
                sleep 30;

                private _searchPos = if (count _hubPos > 0) then {_hubPos} else {_deliveryPos};
                private _rearmCargoNet = [_searchPos, 220] call TWS_OPFLOGI_fnc_getHubCargoNet;

                if (isNull _rearmCargoNet) exitWith {
                    systemChat "[Supply] WARNING: No OPFOR cargo net found near communication hub for refill";
                    ["no-cargonet-at-target"] call _finishMission;
                };

                systemChat "[Supply] Found hub supply box - clearing and refilling with supplies...";

                clearMagazineCargoGlobal _rearmCargoNet;
                clearWeaponCargoGlobal _rearmCargoNet;
                clearItemCargoGlobal _rearmCargoNet;
                clearBackpackCargoGlobal _rearmCargoNet;

                // Restore magazines
                _rearmCargoNet addMagazineCargoGlobal ["10Rnd_762x54_Mag", 24];
                _rearmCargoNet addMagazineCargoGlobal ["150Rnd_762x54_Box", 12];
                _rearmCargoNet addMagazineCargoGlobal ["16Rnd_9x21_Mag", 14];
                _rearmCargoNet addMagazineCargoGlobal ["1Rnd_HE_Grenade_shell", 24];
                _rearmCargoNet addMagazineCargoGlobal ["1Rnd_Smoke_Grenade_shell", 10];
                _rearmCargoNet addMagazineCargoGlobal ["20Rnd_556x45_UW_mag", 6];
                _rearmCargoNet addMagazineCargoGlobal ["30Rnd_556x45_Stanag_green", 6];
                _rearmCargoNet addMagazineCargoGlobal ["30Rnd_65x39_caseless_green", 25];
                _rearmCargoNet addMagazineCargoGlobal ["30Rnd_9x21_Mag", 14];
                _rearmCargoNet addMagazineCargoGlobal ["5Rnd_127x108_APDS_Mag", 14];
                _rearmCargoNet addMagazineCargoGlobal ["5Rnd_127x108_Mag", 18];
                _rearmCargoNet addMagazineCargoGlobal ["6Rnd_45ACP_Cylinder", 14];
                _rearmCargoNet addMagazineCargoGlobal ["APERSBoundingMine_Range_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["APERSMine_Range_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["APERSTripMine_Wire_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["ATMine_Range_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["ClaymoreDirectionalMine_Remote_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["DemoCharge_Remote_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["HandGrenade", 24];
                _rearmCargoNet addMagazineCargoGlobal ["Laserbatteries", 25];
                _rearmCargoNet addMagazineCargoGlobal ["O_IR_Grenade", 8];
                _rearmCargoNet addMagazineCargoGlobal ["RPG32_F", 8];
                _rearmCargoNet addMagazineCargoGlobal ["RPG32_HE_F", 2];
                _rearmCargoNet addMagazineCargoGlobal ["SatchelCharge_Remote_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["SLAMDirectionalMine_Wire_Mag", 5];
                _rearmCargoNet addMagazineCargoGlobal ["SmokeShell", 10];
                _rearmCargoNet addMagazineCargoGlobal ["Titan_AA", 6];
                _rearmCargoNet addMagazineCargoGlobal ["Titan_AP", 4];
                _rearmCargoNet addMagazineCargoGlobal ["Titan_AT", 6];

                // Restore weapons
                _rearmCargoNet addWeaponCargoGlobal ["arifle_Katiba_C_F", 4];
                _rearmCargoNet addWeaponCargoGlobal ["arifle_Katiba_F", 8];
                _rearmCargoNet addWeaponCargoGlobal ["arifle_Katiba_GL_F", 4];
                _rearmCargoNet addWeaponCargoGlobal ["arifle_SDAR_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["hgun_Pistol_heavy_02_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["hgun_Rook40_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["launch_RPG32_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["launch_Titan_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["launch_Titan_short_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["LMG_Zafir_F", 4];
                _rearmCargoNet addWeaponCargoGlobal ["SMG_02_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["srifle_DMR_01_F", 4];
                _rearmCargoNet addWeaponCargoGlobal ["srifle_GM6_camo_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["srifle_GM6_F", 2];
                _rearmCargoNet addWeaponCargoGlobal ["FirstAidKit", 25];
                _rearmCargoNet addWeaponCargoGlobal ["Medikit", 1];
                _rearmCargoNet addWeaponCargoGlobal ["Laserdesignator_02", 10];
                _rearmCargoNet addWeaponCargoGlobal ["Rangefinder", 1];

                // Restore items
                _rearmCargoNet addItemCargoGlobal ["acc_flashlight", 5];
                _rearmCargoNet addItemCargoGlobal ["acc_pointer_IR", 5];
                _rearmCargoNet addItemCargoGlobal ["ItemGPS", 10];
                _rearmCargoNet addItemCargoGlobal ["MineDetector", 5];
                _rearmCargoNet addItemCargoGlobal ["muzzle_snds_acp", 5];
                _rearmCargoNet addItemCargoGlobal ["muzzle_snds_B", 5];
                _rearmCargoNet addItemCargoGlobal ["muzzle_snds_h", 5];
                _rearmCargoNet addItemCargoGlobal ["muzzle_snds_l", 5];
                _rearmCargoNet addItemCargoGlobal ["optic_ACO_grn", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_ACO_grn_smg", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_Arco", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_DMS", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_LRPS", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_MRCO", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_Nightstalker", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_SOS", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_tws", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_tws_mg", 2];
                _rearmCargoNet addItemCargoGlobal ["optic_Yorris", 2];
                _rearmCargoNet addItemCargoGlobal ["ToolKit", 10];
                _rearmCargoNet addItemCargoGlobal ["NVGogglesB_blk_F", 10];
                _rearmCargoNet addItemCargoGlobal ["ItemMap", 10];
                _rearmCargoNet addItemCargoGlobal ["ItemRadio", 10];
                _rearmCargoNet addItemCargoGlobal ["G_Tactical_Clear", 5];
                _rearmCargoNet addItemCargoGlobal ["G_Tactical_Black", 5];
                _rearmCargoNet addItemCargoGlobal ["H_HelmetO_ViperSP_hex_F", 10];
                _rearmCargoNet addItemCargoGlobal ["O_UavTerminal", 10];

                // Restore backpacks
                _rearmCargoNet addBackpackCargoGlobal ["B_Kitbag_mcamo", 5];

                private _deliveredBoxes = (getPosATL _rearmCargoNet) nearObjects ["ReammoBox_F", 200];
                {
                    if (!isNull _x && {_x != _rearmCargoNet}) then {
                        deleteVehicle _x;
                    };
                } forEach _deliveredBoxes;

                systemChat format ["[Supply] Hub supply box fully restored. Removed %1 nearby dropped supply boxes.", count _deliveredBoxes];

                // Refresh persistent ammo tracking for this hub right after restock.
                [_hubId, _searchPos, "post-delivery"] call TWS_OPFLOGI_fnc_updateHubAmmoStat;
                ["resupply-delivered"] call _finishMission;

                systemChat "[Supply] Searching for OPFOR squads to rearm...";
                private _rearmPos = getPosATL _rearmCargoNet;
                private _nearbyUnits = _rearmPos nearEntities [["Man"], 100];
                private _opforUnits = _nearbyUnits select {side _x == EAST && alive _x && !isPlayer _x};

                private _opforGroups = [];
                {
                    private _grp = group _x;
                    if (!(_grp in _opforGroups) && {count units _grp > 0}) then {
                        _opforGroups pushBack _grp;
                    };
                } forEach _opforUnits;

                systemChat format ["[Supply] Found %1 OPFOR groups within 100m", count _opforGroups];

                {
                    private _grp = _x;
                    private _leader = leader _grp;

                    if (!isNull _leader && alive _leader) then {
                        while {count waypoints _grp > 0} do {
                            deleteWaypoint ((waypoints _grp) select 0);
                        };

                        private _wp = _grp addWaypoint [_rearmPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointCompletionRadius 15;
                        _wp setWaypointSpeed "FULL";

                        [_grp, _rearmCargoNet] spawn {
                            params ["_group", "_cargoNet"];
                            private _cargoPos = getPosATL _cargoNet;

                            waitUntil {
                                sleep 3;
                                (leader _group distance2D _cargoPos < 30) || {!alive leader _group} || {isNull _cargoNet}
                            };

                            if (alive leader _group && !isNull _cargoNet) then {
                                {
                                    if (alive _x) then {
                                        _x action ["Rearm", _cargoNet];
                                        sleep 1;
                                    };
                                } forEach units _group;
                            };
                        };
                    };
                } forEach _opforGroups;
            };
            
            // Add event handler to delete pilot when they get out
            _pilot addEventHandler ["GetOutMan", {
                params ["_unit", "_role", "_vehicle", "_turret"];
                systemChat "[Supply] Pilot returned to base and dismissed";
                if (TWS_OPFLOGI_missionActive) then {
                    [false, "", "pilot-returned"] call TWS_OPFLOGI_fnc_setMissionState;
                };
                deleteVehicle _unit;
            }];
            
            if (_targetObjID != "") then {
                systemChat format ["[Supply] Mission started - delivering to %1 (lowest supplies: %2)", _targetObjID, _lowestSupplyTotal];

                if (!isNull _targetHub) then {
                    private _hubPosForCheck = +_targetHubPos;
                    private _hubIdForCheck = _targetObjID;
                    [_hubPosForCheck, _hubIdForCheck, _lowestSupplyTotal] spawn {
                        params ["_hubPos", "_hubId", "_beforeTotal"];
                        sleep 210;
                        private _status = [_hubId, _hubPos, "post-check"] call TWS_OPFLOGI_fnc_updateHubAmmoStat;
                        _status params ["_net", "_afterTotal", "_afterPct", "_cap", "_afterRawPct"];
                        systemChat format ["[Supply] Post-delivery hub %1 cargo-net supply: %2 -> %3 (%4%%)", _hubId, _beforeTotal, _afterTotal, round (_afterPct * 100)];
                    };
                };
                
                // Create temporary marker at resupply location
                private _markerName = "opfor_resupply_" + str(time);
                createMarker [_markerName, _targetPos];
                _markerName setMarkerType "hd_destroy";
                _markerName setMarkerColor "ColorRed";
                _markerName setMarkerText "OPFOR Resupply Mission";
                _markerName setMarkerSize [1, 1];
                systemChat format ["[Supply] Temporary marker created: %1", _markerName];
                
                // Schedule marker deletion after 2 minutes
                [_markerName] spawn {
                    params ["_marker"];
                    sleep 120; // 2 minutes
                    deleteMarker _marker;
                    systemChat format ["[Supply] Removed temporary marker: %1", _marker];
                };
            } else {
                systemChat "[Supply] Mission started - delivering to fallback location";
            };
            
        } else {
            systemChat "[Supply] No available helicopters found";
            [false, "", "no-heli-available"] call TWS_OPFLOGI_fnc_setMissionState;
        };
        
        } else {
            systemChat "[Supply] No valid delivery target found";
        };
        
        if (_singlePass) then {
            break;
        };

        // Wait before checking again in loop mode.
        sleep TWS_OPFLOGI_loopSleepSeconds;
    };
};