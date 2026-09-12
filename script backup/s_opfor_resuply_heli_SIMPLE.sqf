/*
 * s_opfor_resuply_heli_SIMPLE.sqf
 * Smart OPFOR helicopter supply system
 * Automatically delivers to lowest supply objective
 */

if (isServer) then {
    while { true } do {
        systemChat "[Supply] Checking for available helicopters and low supply locations...";
        
        // First, find the objective with lowest supplies
        private _targetPos = [];
        private _targetObjID = "";
        private _lowestSupplyTotal = 999999;
        
        // Check ALiVE availability
        if (!(isNil "ALiVE_sectorGrid") && !(isNil "OPCOM_instances") && count OPCOM_instances > 0) then {
            systemChat "[Supply] Scanning for supply crates needing resupply...";
            
            // Find all player-placed supply boxes
            private _mapCenter = [worldSize/2, worldSize/2, 0];
            private _allSupplyBoxes = [];
            
            // Only look for CSAT (OPFOR) supply crates
            private _boxTypes = ["O_supplyCrate_F"];
            {
                private _boxes = _mapCenter nearObjects [_x, worldSize];
                _allSupplyBoxes append _boxes;
            } forEach _boxTypes;
            
            systemChat format ["[Supply] Found %1 CSAT supply crates to analyze", count _allSupplyBoxes];
            
            if (count _allSupplyBoxes > 0) then {
                // Function to calculate supplies
                private _fnc_getBoxSupplies = {
                    params ["_supplyBox"];
                    private _magCargo = getMagazineCargo _supplyBox;
                    private _wpnCargo = getWeaponCargo _supplyBox;
                    private _itemCargo = getItemCargo _supplyBox;
                    
                    private _magCounts = _magCargo select 1;
                    private _wpnCounts = _wpnCargo select 1;
                    private _itemTypes = _itemCargo select 0;
                    private _itemCounts = _itemCargo select 1;
                    
                    // Filter combat items
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
                    
                    private _totalMags = 0; {_totalMags = _totalMags + _x} forEach _magCounts;
                    private _totalWpns = 0; {_totalWpns = _totalWpns + _x} forEach _wpnCounts;
                    private _totalItems = 0; {_totalItems = _totalItems + _x} forEach _filteredItemCounts;
                    
                    _totalMags + _totalWpns + _totalItems
                };
                
                // Function to determine which faction controls the area around a position
                private _fnc_getFactionControl = {
                    params ["_position"];
                    private _controllingFaction = "UNKNOWN";
                    private _closestDist = 999999;
                    private _nearestObjID = "Unknown";
                    private _debugInfo = [];
                    
                    {
                        private _opcom = _x;
                        private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
                        private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
                        
                        {
                            private _objective = _x;
                            private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
                            private _distance = _position distance2D _objCenter;
                            private _objState = [_objective, "opcom_state", "unassigned"] call ALIVE_fnc_hashGet;
                            private _objID = [_objective, "objectiveID", "unknown"] call ALIVE_fnc_hashGet;
                            
                            _debugInfo pushBack format ["Obj %1: Side=%2, State=%3, Dist=%4m", _objID, _opcomSide, _objState, round _distance];
                            
                            if (_distance < _closestDist) then {
                                _closestDist = _distance;
                                _nearestObjID = _objID;
                                
                                // Determine faction based on OPCOM side and objective state
                                if (_opcomSide == "EAST" && !(_objState in ["unassigned"])) then {
                                    _controllingFaction = "OPFOR";
                                } else {
                                    if (_opcomSide == "WEST" && !(_objState in ["unassigned"])) then {
                                        _controllingFaction = "BLUFOR";
                                    } else {
                                        _controllingFaction = "NEUTRAL";
                                    };
                                };
                            };
                        } forEach _objectives;
                    } forEach OPCOM_instances;
                    
                    // Debug output
                    systemChat format ["[Supply DEBUG] Nearest to %1: %2 (%3, %4m)", _position, _nearestObjID, _controllingFaction, round _closestDist];
                    { systemChat format ["[Supply DEBUG] %1", _x]; } forEach _debugInfo;
                    
                    [_controllingFaction, _nearestObjID, _closestDist]
                };
                
                // Analyze all CSAT supply crates and find the lowest supply count
                systemChat format ["[Supply] Analyzing %1 CSAT supply crates...", count _allSupplyBoxes];
                
                {
                    private _supplyBox = _x;
                    private _boxPos = getPosATL _supplyBox;
                    private _totalSupplies = [_supplyBox] call _fnc_getBoxSupplies;
                    private _factionInfo = [_boxPos] call _fnc_getFactionControl;
                    private _faction = _factionInfo select 0;
                    private _objID = _factionInfo select 1;
                    private _distance = _factionInfo select 2;
                    
                    systemChat format ["[Supply] CSAT %1: %2 supplies (near %3 - %4 control, %5m)", typeOf _supplyBox, _totalSupplies, _objID, _faction, round _distance];
                    
                    // Since we're only looking at CSAT crates, consider all of them
                    if (_totalSupplies < _lowestSupplyTotal) then {
                        _lowestSupplyTotal = _totalSupplies;
                        _targetPos = _boxPos;
                        _targetObjID = _objID;
                        systemChat format ["[Supply] New CSAT resupply target: %1 (%2 supplies)", _objID, _totalSupplies];
                    };
                } forEach _allSupplyBoxes;
                
                // Check if we found a valid CSAT target
                if (count _targetPos == 0 || _targetPos isEqualTo [0,0,0]) then {
                    systemChat "[Supply] No CSAT supply crates need resupply - mission cancelled";
                } else {
                    systemChat format ["[Supply] TARGET: %1 needs resupply (%2 supplies)", _targetObjID, _lowestSupplyTotal];
                    
                    // Find nearest helipad to target position
                    private _helipadTypes = [
                        "Land_HelipadEmpty_F", "Land_HelipadCircle_F", "Land_HelipadCivil_F", 
                        "Land_HelipadRescue_F", "Land_HelipadSquare_F", "HeliH", "HeliHEmpty", 
                        "HeliHCivil", "HeliHRescue"
                    ];
                    
                    private _nearestHelipad = objNull;
                    private _nearestHelipadDist = 999999;
                    private _helipadSearchRadius = 1000; // 1km search radius
                    
                    {
                        private _helipads = _targetPos nearObjects [_x, _helipadSearchRadius];
                        {
                            private _dist = _targetPos distance2D (getPosATL _x);
                            if (_dist < _nearestHelipadDist) then {
                                _nearestHelipadDist = _dist;
                                _nearestHelipad = _x;
                            };
                        } forEach _helipads;
                    } forEach _helipadTypes;
                    
                    if (!isNull _nearestHelipad) then {
                        private _helipadPos = getPosATL _nearestHelipad;
                        systemChat format ["[Supply] Found helipad %1m from target - using for landing", round _nearestHelipadDist];
                        _targetPos = _helipadPos; // Use helipad position instead of supply crate position
                    } else {
                        systemChat format ["[Supply] WARNING: No helipad found within %1m of target! Mission may have landing difficulties.", _helipadSearchRadius];
                        systemChat "[Supply] Consider placing a helipad near the supply objective for safer operations.";
                        // Continue with original target but warn about potential issues
                    };
                };
            } else {
                systemChat "[Supply] No CSAT supply crates found - mission cancelled";
            };
        } else {
            systemChat "[Supply] ALiVE not available - mission cancelled";
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
            
            // Add event handler to delete pilot when they get out
            _pilot addEventHandler ["GetOutMan", {
                params ["_unit", "_role", "_vehicle", "_turret"];
                systemChat "[Supply] Pilot returned to base and dismissed";
                deleteVehicle _unit;
            }];
            
            if (_targetObjID != "") then {
                systemChat format ["[Supply] Mission started - delivering to %1 (lowest supplies: %2)", _targetObjID, _lowestSupplyTotal];
                
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
        };
        
        } else {
            systemChat "[Supply] No valid delivery target found";
        };
        
        // Wait 15 minutes before checking again
        sleep 900;
    };
};