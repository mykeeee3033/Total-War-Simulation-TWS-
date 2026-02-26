/*
    Advanced Naval Profile Integration with OpCom
    
    This script not only virtualizes naval units but also integrates them
    with ALiVE's OpCom system so they can be commanded by AI commanders.
    
    Usage:
    1. Run virtualizeNavalUnits.sqf first
    2. Run this script to integrate with OpCom
    
    Parameters:
    _side - Side that should control these naval assets ("EAST", "WEST", "GUER")
    _faction - Faction these units belong to
    _isReserve - Whether these should be held in reserve (true) or active patrol (false)
*/

params [
    ["_side", "EAST", [""]],
    ["_faction", "", [""]],
    ["_isReserve", true, [true]]
];

// Get all naval profiles
private _navalProfiles = [];
private _allProfiles = [ALIVE_profileHandler, "getProfiles"] call ALIVE_fnc_profileHandler;

{
    private _profile = _x;
    private _objectType = [_profile, "objectType", ""] call ALIVE_fnc_hashGet;
    private _profileSide = [_profile, "side", ""] call ALIVE_fnc_hashGet;
    
    if (_objectType == "Naval" && _profileSide == _side) then {
        _navalProfiles pushBack _profile;
    };
} forEach (_allProfiles select 2);

diag_log format ["[NavalOpCom] Found %1 naval profiles for side %2", count _navalProfiles, _side];

// Find the appropriate OpCom for this side
private _opcom = nil;
{
    private _opcoms = [_x, "getOpcomsBySide", _side] call ALIVE_fnc_OPCOMMil;
    if (count _opcoms > 0) then {
        _opcom = _opcoms select 0;
    };
} forEach (["ALIVE_mil_opcom"] call ALiVE_fnc_getModuleArray);

if (isNil "_opcom") then {
    diag_log format ["[NavalOpCom] Warning: No OpCom found for side %1", _side];
} else {
    diag_log format ["[NavalOpCom] Found OpCom for side %1", _side];
    
    // Add naval profiles to OpCom's available forces
    {
        private _profile = _x;
        private _profileID = [_profile, "profileID"] call ALIVE_fnc_hashGet;
        
        // Set faction if not already set
        if (_faction != "") then {
            [_profile, "faction", _faction] call ALIVE_fnc_profileEntity;
        };
        
        // Mark as OpCom asset
        [_profile, "opcom", _opcom] call ALIVE_fnc_profileEntity;
        
        if (_isReserve) then {
            // Add to reserve forces
            [_profile, "busy", false] call ALIVE_fnc_profileEntity;
            [_profile, "activeCommand", "none"] call ALIVE_fnc_profileEntity;
            
            // Set naval patrol waypoints if none exist
            private _waypoints = [_profile, "waypoints"] call ALIVE_fnc_hashGet;
            if (count _waypoints == 0) then {
                private _position = [_profile, "position"] call ALIVE_fnc_hashGet;
                
                // Create patrol waypoints around the area
                for "_i" from 0 to 3 do {
                    private _patrolPos = [_position, 1000 + (random 2000), random 360] call BIS_fnc_relPos;
                    
                    // Ensure waypoint is over water
                    if (!surfaceIsWater _patrolPos) then {
                        _patrolPos = [_patrolPos] call ALiVE_fnc_getClosestSea;
                    };
                    
                    private _waypoint = [_patrolPos, 200, "MOVE", "LIMITED", 100, [], "LINE"] call ALIVE_fnc_createProfileWaypoint;
                    [_profile, "addWaypoint", _waypoint] call ALIVE_fnc_profileEntity;
                };
                
                // Add cycle waypoint back to start
                private _cycleWaypoint = [[_profile, "position"] call ALIVE_fnc_hashGet, 200, "CYCLE", "LIMITED", 100, [], "LINE"] call ALIVE_fnc_createProfileWaypoint;
                [_profile, "addWaypoint", _cycleWaypoint] call ALIVE_fnc_profileEntity;
            };
        } else {
            // Make actively patrolling
            [_profile, "busy", false] call ALIVE_fnc_profileEntity;
        };
        
        diag_log format ["[NavalOpCom] Integrated naval profile %1 with OpCom", _profileID];
        
    } forEach _navalProfiles;
};

// Create naval task function for OpCom to use
if (!isNil "_opcom") then {
    
    // Function to assign naval support tasks
    ALIVE_fnc_assignNavalSupport = {
        params ["_opcom", "_targetPosition", "_taskType"];
        
        private _side = [_opcom, "side"] call ALIVE_fnc_OPCOMMil;
        private _availableNaval = [];
        
        // Find available naval profiles
        private _allProfiles = [ALIVE_profileHandler, "getProfiles"] call ALIVE_fnc_profileHandler;
        {
            private _profile = _x;
            private _objectType = [_profile, "objectType", ""] call ALIVE_fnc_hashGet;
            private _profileSide = [_profile, "side", ""] call ALIVE_fnc_hashGet;
            private _busy = [_profile, "busy", false] call ALIVE_fnc_hashGet;
            
            if (_objectType == "Naval" && _profileSide == _side && !_busy) then {
                _availableNaval pushBack _profile;
            };
        } forEach (_allProfiles select 2);
        
        if (count _availableNaval > 0) then {
            // Select closest naval asset
            _availableNaval sort {
                private _pos1 = [_x, "position"] call ALIVE_fnc_hashGet;
                private _pos2 = [_y, "position"] call ALIVE_fnc_hashGet;
                (_pos1 distance2D _targetPosition) - (_pos2 distance2D _targetPosition)
            };
            
            private _navalAsset = _availableNaval select 0;
            
            // Assign task
            [_navalAsset, "busy", true] call ALIVE_fnc_profileEntity;
            [_navalAsset, "activeCommand", _taskType] call ALIVE_fnc_profileEntity;
            
            // Clear existing waypoints and add new mission waypoint
            [_navalAsset, "clearWaypoints"] call ALIVE_fnc_profileEntity;
            
            private _missionWaypoint = [_targetPosition, 500, "MOVE", "FULL", 100, [], "LINE"] call ALIVE_fnc_createProfileWaypoint;
            [_navalAsset, "addWaypoint", _missionWaypoint] call ALIVE_fnc_profileEntity;
            
            diag_log format ["[NavalOpCom] Assigned naval asset %1 to %2 mission at %3", 
                [_navalAsset, "profileID"] call ALIVE_fnc_hashGet, _taskType, _targetPosition];
            
            _navalAsset
        } else {
            objNull
        };
    };
};

private _message = format ["[NavalOpCom] Integration complete! %1 naval profiles integrated with OpCom for side %2", count _navalProfiles, _side];
diag_log _message;
systemChat _message;

count _navalProfiles;