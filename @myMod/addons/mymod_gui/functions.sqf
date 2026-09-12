// Functions for the Unit List GUI on Map
// These handle populating and managing the squad/group list

// Global variables
mymod_groupListData = [];
mymod_squadTags = []; // Array to store squad tags: [[group, "tag"], ...]
mymod_mapControlsCreated = false;
mymod_selectedGroup = grpNull;
mymod_waypointMode = false;
mymod_waypointMarkers = []; // Array to store waypoint marker names
mymod_waypointPositions = []; // Array to store waypoint positions
mymod_waypointNumbers = []; // Array to store original waypoint numbers (parallel to positions)
mymod_waypointTypes = []; // Array to store waypoint types (parallel to positions)
mymod_stagedWaypoints = []; // Array tracking staged status (parallel to positions - true = staged, false = active)
mymod_waypointLinks = []; // Array of waypoint sync links: [srcGroupId, srcWpNum, tgtGroupId, tgtWpNum, markerName]
mymod_waypointSyncMarkers = []; // Array of sync line marker names
mymod_linkModeActive = false; // Whether link mode is active
mymod_linkSource = []; // [groupId, wpNumber] for link source
mymod_waypointTypeOptions = ["MOVE", "GETIN", "GETOUT", "LOAD", "UNLOAD", "TR UNLOAD", "HOLD", "SAD", "GUARD", "ATTACK"]; // Supported waypoint types
mymod_waypointHelipads = []; // Array to store spawned helipads: [[helipad, markerName], ...]
mymod_selectedWaypointIndex = -1; // Currently selected waypoint index for editing
mymod_isDraggingWaypoint = false; // Whether we're currently dragging a waypoint
mymod_waypointMonitorActive = false; // Whether waypoint monitoring is active
mymod_nextWaypointNumber = 0; // Counter for assigning waypoint numbers
mymod_knownGroups = []; // Track groups (by object reference) to detect new ones
mymod_squadListMonitorActive = false; // Monitor for new squads
mymod_groupsRevision = 0; // Revision counter for group list changes
mymod_serverGroups = []; // Server-published group list (for Zeus-spawned squads)
mymod_serverGroupsRevision = 0; // Server-published revision
mymod_lastServerGroupsRevision = -1; // Client-side revision tracking
mymod_rightClickWaypointIndex = -1; // Store which waypoint was right-clicked
mymod_contextMenuOpen = false; // Whether context menu is open
mymod_stagedGroupReferences = []; // List of groups with staged waypoints
// Stage system variables
mymod_stages = []; // Array of stages: [{squads: [grp1, grp2], status: "pending/active/completed"}]
mymod_currentStageIndex = 0; // Current active stage (0-based)
mymod_stageControlsCreated = false; // Whether stage panel UI is created
mymod_selectedSquadForStage = grpNull; // Squad selected for stage assignment
mymod_selectedStageIndexForAssignment = -1; // Stage index selected in assignment dialog

// Show context menu for waypoint
mymod_fnc_showWaypointContextMenu = {
    params ["_waypointIndex"];
    
    if (_waypointIndex < 0 || _waypointIndex >= count mymod_waypointPositions) exitWith {};
    
    mymod_rightClickWaypointIndex = _waypointIndex;
    mymod_contextMenuOpen = true;
    
    private _wpNumber = mymod_waypointNumbers select _waypointIndex;
    private _groupName = groupId mymod_selectedGroup;
    
    createDialog "mymod_waypointContextMenu";
    [] call mymod_fnc_populateWaypointContextMenu;
};

// Delete the right-clicked waypoint
mymod_fnc_deleteWaypointFromMenu = {
    if (mymod_rightClickWaypointIndex >= 0 && mymod_rightClickWaypointIndex < count mymod_waypointPositions) then {
        private _nearestIndex = mymod_rightClickWaypointIndex;
        private _wpNumber = mymod_waypointNumbers select _nearestIndex;
        private _groupName = groupId mymod_selectedGroup;
        private _isStaged = mymod_stagedWaypoints select _nearestIndex;
        
        // Delete the markers
        private _markerName = format ["mymod_wp_%1_%2", _groupName, _wpNumber];
        deleteMarker _markerName;
        
        // Delete helipad if it exists for this waypoint
        [_markerName] call mymod_fnc_deleteHelipadForMarker;
        
        // Delete line marker FROM this waypoint TO the next (if exists)
        if (_nearestIndex + 1 < count mymod_waypointNumbers) then {
            private _nextWpNumber = mymod_waypointNumbers select (_nearestIndex + 1);
            private _lineMarkerName = format ["mymod_line_%1_%2", _groupName, _nextWpNumber];
            deleteMarker _lineMarkerName;
            
            private _lineIndex = mymod_waypointMarkers find _lineMarkerName;
            if (_lineIndex >= 0) then {
                mymod_waypointMarkers deleteAt _lineIndex;
            };
        };
        
        // Remove waypoint from arrays
        private _markerIndex = mymod_waypointMarkers find _markerName;
        if (_markerIndex >= 0) then {
            mymod_waypointMarkers deleteAt _markerIndex;
        };
        
        mymod_waypointPositions deleteAt _nearestIndex;
        mymod_waypointNumbers deleteAt _nearestIndex;
        if (_nearestIndex < count mymod_waypointTypes) then { mymod_waypointTypes deleteAt _nearestIndex; };
        if (_nearestIndex < count mymod_stagedWaypoints) then { mymod_stagedWaypoints deleteAt _nearestIndex; };

        // Remove any sync links tied to this waypoint
        [groupId mymod_selectedGroup, _wpNumber] call mymod_fnc_removeLinksForWaypoint;
        
        // Only delete AI waypoint if it's not staged (staged waypoints don't have AI waypoints yet)
        if (!_isStaged) then {
            private _aiWaypoints = waypoints mymod_selectedGroup;
            if ((_nearestIndex + 1) < count _aiWaypoints) then {
                deleteWaypoint (_aiWaypoints select (_nearestIndex + 1));
            };
        };
        
        // Redraw lines
        [] call mymod_fnc_redrawWaypointLines;
        
        // Persist changes
        [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
        
        private _statusMsg = if (_isStaged) then { "STAGED waypoint deleted" } else { "ACTIVE waypoint deleted" };
        hint format ["%1\n%2 waypoints remaining", _statusMsg, count mymod_waypointPositions];
        systemChat format ["Waypoint deleted from %1 - %2 waypoints remaining", _groupName, count mymod_waypointPositions];
        
        mymod_rightClickWaypointIndex = -1;
        mymod_contextMenuOpen = false;
    };
};

// Close context menu without action
mymod_fnc_closeWaypointContextMenu = {
    mymod_rightClickWaypointIndex = -1;
    mymod_contextMenuOpen = false;
};

// Populate waypoint context menu with current type
mymod_fnc_populateWaypointContextMenu = {
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _typeList = _display displayCtrl 9503;
    if (isNull _typeList) exitWith {};

    lbClear _typeList;
    {
        private _idx = _typeList lbAdd _x;
        _typeList lbSetData [_idx, _x];
    } forEach mymod_waypointTypeOptions;

    private _currentType = "MOVE";
    if (mymod_rightClickWaypointIndex >= 0 && mymod_rightClickWaypointIndex < count mymod_waypointTypes) then {
        _currentType = mymod_waypointTypes select mymod_rightClickWaypointIndex;
    };

    private _selectIndex = mymod_waypointTypeOptions find _currentType;
    if (_selectIndex < 0) then { _selectIndex = 0; };
    _typeList lbSetCurSel _selectIndex;
};

// Set waypoint type from context menu
mymod_fnc_setWaypointTypeFromMenu = {
    private _display = findDisplay 9500;
    if (isNull _display) exitWith {};

    private _typeList = _display displayCtrl 9503;
    if (isNull _typeList) exitWith {};

    private _selectedIndex = lbCurSel _typeList;
    if (_selectedIndex < 0) exitWith {};

    private _selectedType = _typeList lbData _selectedIndex;
    if (_selectedType == "") then { _selectedType = _typeList lbText _selectedIndex; };

    if (mymod_rightClickWaypointIndex >= 0 && mymod_rightClickWaypointIndex < count mymod_waypointTypes) then {
        mymod_waypointTypes set [mymod_rightClickWaypointIndex, _selectedType];

        private _wpNumber = mymod_waypointNumbers select mymod_rightClickWaypointIndex;
        private _markerName = format ["mymod_wp_%1_%2", groupId mymod_selectedGroup, _wpNumber];
        private _isStaged = mymod_stagedWaypoints select mymod_rightClickWaypointIndex;
        private _markerText = if (_isStaged) then {
            format ["[%1] - %2 (STAGED)", groupId mymod_selectedGroup, _selectedType]
        } else {
            format ["[%1] - %2", groupId mymod_selectedGroup, _selectedType]
        };
        _markerName setMarkerText _markerText;

        [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
        systemChat format ["Waypoint type set to %1", _selectedType];
    };
};

// Start link mode for the selected waypoint
mymod_fnc_startWaypointLink = {
    if (mymod_rightClickWaypointIndex < 0 || mymod_rightClickWaypointIndex >= count mymod_waypointPositions) exitWith {};

    private _wpNumber = mymod_waypointNumbers select mymod_rightClickWaypointIndex;
    mymod_linkModeActive = true;
    mymod_linkSource = [groupId mymod_selectedGroup, _wpNumber];

    hint format ["LINK MODE\nClick target waypoint to link\nSource: %1 WP%2", groupId mymod_selectedGroup, _wpNumber];
    systemChat "Link mode active - click a target waypoint";
};

// Cancel link mode
mymod_fnc_cancelWaypointLink = {
    mymod_linkModeActive = false;
    mymod_linkSource = [];
    hint "Link mode canceled";
};

// Add a waypoint link between source and target
mymod_fnc_addWaypointLink = {
    params ["_srcGroupId", "_srcWpNum", "_tgtGroupId", "_tgtWpNum"];

    private _markerName = format ["mymod_sync_%1_%2_%3_%4", _srcGroupId, _srcWpNum, _tgtGroupId, _tgtWpNum];

    // Avoid duplicate links
    private _existing = mymod_waypointLinks findIf {
        (_x select 0) == _srcGroupId && (_x select 1) == _srcWpNum && (_x select 2) == _tgtGroupId && (_x select 3) == _tgtWpNum
    };
    if (_existing >= 0) exitWith { systemChat "Link already exists"; };

    mymod_waypointLinks pushBack [_srcGroupId, _srcWpNum, _tgtGroupId, _tgtWpNum, _markerName];

    // Draw sync line
    private _srcGroup = [_srcGroupId] call mymod_fnc_findGroupById;
    private _tgtGroup = [_tgtGroupId] call mymod_fnc_findGroupById;
    if (!isNull _srcGroup && !isNull _tgtGroup) then {
        private _srcNumbers = _srcGroup getVariable ["mymod_wp_numbers", []];
        private _tgtNumbers = _tgtGroup getVariable ["mymod_wp_numbers", []];
        private _srcIndex = _srcNumbers find _srcWpNum;
        private _tgtIndex = _tgtNumbers find _tgtWpNum;

        private _srcPositions = _srcGroup getVariable ["mymod_wp_positions", []];
        private _tgtPositions = _tgtGroup getVariable ["mymod_wp_positions", []];

        if (_srcIndex >= 0 && _tgtIndex >= 0) then {
            private _srcPos = _srcPositions select _srcIndex;
            private _tgtPos = _tgtPositions select _tgtIndex;
            [_markerName, _srcPos, _tgtPos] call mymod_fnc_drawSyncLine;
        };
    };

    [] call mymod_fnc_applyWaypointLinks;
    systemChat format ["Linked %1 WP%2 -> %3 WP%4", _srcGroupId, _srcWpNum, _tgtGroupId, _tgtWpNum];
};

// Find group by groupId
mymod_fnc_findGroupById = {
    params ["_groupId"];
    private _group = grpNull;
    {
        if (groupId _x == _groupId) exitWith { _group = _x; };
    } forEach allGroups;
    _group
};

// Register created AI waypoint for linking
mymod_fnc_registerAiWaypoint = {
    params ["_group", "_wpNumber", "_wp"];
    if (isNull _group) exitWith {};

    private _aiMap = _group getVariable ["mymod_wp_ai", []];
    private _idx = _aiMap findIf { (_x select 0) == _wpNumber };
    if (_idx >= 0) then {
        _aiMap set [_idx, [_wpNumber, _wp]];
    } else {
        _aiMap pushBack [_wpNumber, _wp];
    };
    _group setVariable ["mymod_wp_ai", _aiMap];
};

// Get AI waypoint object for a group/wpNumber
mymod_fnc_getAiWaypoint = {
    params ["_group", "_wpNumber"];
    if (isNull _group) exitWith {nil};

    private _aiMap = _group getVariable ["mymod_wp_ai", []];
    private _idx = _aiMap findIf { (_x select 0) == _wpNumber };
    if (_idx < 0) exitWith {nil};
    (_aiMap select _idx) select 1
};

// Apply waypoint synchronization links if both endpoints exist
mymod_fnc_applyWaypointLinks = {
    {
        private _srcGroupId = _x select 0;
        private _srcWpNum = _x select 1;
        private _tgtGroupId = _x select 2;
        private _tgtWpNum = _x select 3;

        private _srcGroup = [_srcGroupId] call mymod_fnc_findGroupById;
        private _tgtGroup = [_tgtGroupId] call mymod_fnc_findGroupById;

        if (!isNull _srcGroup && !isNull _tgtGroup) then {
            private _srcWp = [_srcGroup, _srcWpNum] call mymod_fnc_getAiWaypoint;
            private _tgtWp = [_tgtGroup, _tgtWpNum] call mymod_fnc_getAiWaypoint;

            if (!isNil "_srcWp" && !isNil "_tgtWp") then {
                _srcWp synchronizeWaypoint [_tgtWp];
            };
        };
    } forEach mymod_waypointLinks;
};

// Remove links for a waypoint
mymod_fnc_removeLinksForWaypoint = {
    params ["_groupId", "_wpNumber"];

    private _remaining = [];
    {
        private _srcGroupId = _x select 0;
        private _srcWpNum = _x select 1;
        private _tgtGroupId = _x select 2;
        private _tgtWpNum = _x select 3;
        private _markerName = _x select 4;

        if ((_srcGroupId == _groupId && _srcWpNum == _wpNumber) || (_tgtGroupId == _groupId && _tgtWpNum == _wpNumber)) then {
            deleteMarker _markerName;
            private _syncIndex = mymod_waypointSyncMarkers find _markerName;
            if (_syncIndex >= 0) then { mymod_waypointSyncMarkers deleteAt _syncIndex; };
        } else {
            _remaining pushBack _x;
        };
    } forEach mymod_waypointLinks;

    mymod_waypointLinks = _remaining;
};

// Draw a sync line between two waypoints
mymod_fnc_drawSyncLine = {
    params ["_markerName", "_startPos", "_endPos"];

    deleteMarker _markerName;

    private _midPoint = [
        ((_startPos select 0) + (_endPos select 0)) / 2,
        ((_startPos select 1) + (_endPos select 1)) / 2,
        0
    ];

    private _distance = _startPos distance _endPos;
    private _angle = (_startPos getDir _endPos) + 90;

    private _marker = createMarker [_markerName, _midPoint];
    _marker setMarkerShape "RECTANGLE";
    _marker setMarkerSize [_distance / 2, 0.2];
    _marker setMarkerDir _angle;
    _marker setMarkerColor "ColorWhite";
    _marker setMarkerBrush "FDiagonal";
    _marker setMarkerAlpha 0.7;

    if !(_markerName in mymod_waypointSyncMarkers) then {
        mymod_waypointSyncMarkers pushBack _markerName;
    };
};

// Redraw all sync lines (used after moving waypoints)
mymod_fnc_redrawSyncLines = {
    {
        deleteMarker _x;
    } forEach mymod_waypointSyncMarkers;
    mymod_waypointSyncMarkers = [];

    {
        private _srcGroupId = _x select 0;
        private _srcWpNum = _x select 1;
        private _tgtGroupId = _x select 2;
        private _tgtWpNum = _x select 3;
        private _markerName = _x select 4;

        private _srcGroup = [_srcGroupId] call mymod_fnc_findGroupById;
        private _tgtGroup = [_tgtGroupId] call mymod_fnc_findGroupById;

        if (!isNull _srcGroup && !isNull _tgtGroup) then {
            private _srcNumbers = _srcGroup getVariable ["mymod_wp_numbers", []];
            private _tgtNumbers = _tgtGroup getVariable ["mymod_wp_numbers", []];
            private _srcIndex = _srcNumbers find _srcWpNum;
            private _tgtIndex = _tgtNumbers find _tgtWpNum;

            private _srcPositions = _srcGroup getVariable ["mymod_wp_positions", []];
            private _tgtPositions = _tgtGroup getVariable ["mymod_wp_positions", []];

            if (_srcIndex >= 0 && _tgtIndex >= 0) then {
                private _srcPos = _srcPositions select _srcIndex;
                private _tgtPos = _tgtPositions select _tgtIndex;
                [_markerName, _srcPos, _tgtPos] call mymod_fnc_drawSyncLine;
            };
        };
    } forEach mymod_waypointLinks;
};

// Load waypoint data for a specific group into local working arrays
mymod_fnc_loadGroupWaypointData = {
    params ["_group"];
    if (isNull _group) exitWith {};

    mymod_waypointPositions = +(_group getVariable ["mymod_wp_positions", []]);
    mymod_waypointNumbers = +(_group getVariable ["mymod_wp_numbers", []]);
    mymod_waypointMarkers = +(_group getVariable ["mymod_wp_markers", []]);
    mymod_waypointTypes = +(_group getVariable ["mymod_wp_types", []]);
    mymod_stagedWaypoints = +(_group getVariable ["mymod_wp_staged", []]);
    mymod_nextWaypointNumber = _group getVariable ["mymod_wp_next", 0];

    if (count mymod_waypointTypes != count mymod_waypointNumbers) then {
        mymod_waypointTypes = [];
        {
            mymod_waypointTypes pushBack "MOVE";
        } forEach mymod_waypointNumbers;
    };

    // Refresh marker text to reflect type/staged status
    {
        private _wpNumber = mymod_waypointNumbers select _forEachIndex;
        private _wpType = mymod_waypointTypes select _forEachIndex;
        private _isStaged = false;
        if (_forEachIndex < count mymod_stagedWaypoints) then {
            _isStaged = mymod_stagedWaypoints select _forEachIndex;
        };

        private _markerName = format ["mymod_wp_%1_%2", groupId _group, _wpNumber];
        private _markerText = if (_isStaged) then {
            format ["[%1] - %2 (STAGED)", groupId _group, _wpType]
        } else {
            format ["[%1] - %2", groupId _group, _wpType]
        };
        _markerName setMarkerText _markerText;
    } forEach mymod_waypointNumbers;
};

// Save local working arrays back to the specified group
mymod_fnc_saveGroupWaypointData = {
    params ["_group"];
    if (isNull _group) exitWith {};

    _group setVariable ["mymod_wp_positions", +mymod_waypointPositions];
    _group setVariable ["mymod_wp_numbers", +mymod_waypointNumbers];
    _group setVariable ["mymod_wp_markers", +mymod_waypointMarkers];
    _group setVariable ["mymod_wp_types", +mymod_waypointTypes];
    _group setVariable ["mymod_wp_staged", +mymod_stagedWaypoints];
    _group setVariable ["mymod_wp_next", mymod_nextWaypointNumber];
};

// === STAGE MANAGEMENT FUNCTIONS ===

// Show menu to assign squad to a stage
mymod_fnc_showStageAssignmentMenu = {
    if (isNull mymod_selectedSquadForStage) exitWith {};
    
    private _squadName = groupId mymod_selectedSquadForStage;
    private _stageCount = count mymod_stages;
    
    if (_stageCount == 0) exitWith {
        hint "No stages created!\nClick 'ADD STAGE' first";
        systemChat "Create at least one stage before assigning squads";
    };
    
    // Create dialog for stage selection
    createDialog "mymod_stageAssignmentDialog";
    
    // Populate the listbox with available stages
    private _dialog = findDisplay 9600;
    if (!isNull _dialog) then {
        private _listbox = _dialog displayCtrl 9601;
        if (!isNull _listbox) then {
            lbClear _listbox;
            
            for "_i" from 0 to (_stageCount - 1) do {
                private _stage = mymod_stages select _i;
                private _squadCount = count (_stage get "squads");
                private _status = _stage get "status";
                
                private _text = format ["Stage %1 (%2 squads) - %3", _i + 1, _squadCount, _status];
                private _index = _listbox lbAdd _text;
                _listbox lbSetData [_index, str _i];
            };
            
            // Select first stage by default
            _listbox lbSetCurSel 0;
            mymod_selectedStageIndexForAssignment = 0;
        };
    };
};

// Called when stage is selected in assignment dialog
mymod_fnc_onStageSelected = {
    params ["_selectedIndex"];
    mymod_selectedStageIndexForAssignment = _selectedIndex;
};

// Confirm stage assignment from dialog
mymod_fnc_confirmStageAssignment = {
    if (isNull mymod_selectedSquadForStage) exitWith {};
    if (mymod_selectedStageIndexForAssignment < 0) exitWith {};
    
    [mymod_selectedSquadForStage, mymod_selectedStageIndexForAssignment] call mymod_fnc_assignSquadToStage;
    
    mymod_selectedSquadForStage = grpNull;
    mymod_selectedStageIndexForAssignment = -1;
};

// Add a new execution stage
mymod_fnc_addNewStage = {
    private _newStage = createHashMapFromArray [
        ["squads", []],
        ["status", "pending"]
    ];
    
    mymod_stages pushBack _newStage;
    
    [] call mymod_fnc_refreshStageList;
    
    private _stageNum = count mymod_stages;
    hint format ["Stage %1 created\n\nRight-click squads to assign\nRight-click stage to execute manually", _stageNum];
    systemChat format ["Stage %1 added - right-click squads to assign, right-click stage to execute", _stageNum];
};

// Clear all stages
mymod_fnc_clearAllStages = {
    mymod_stages = [];
    mymod_currentStageIndex = 0;
    [] call mymod_fnc_refreshStageList;
    hint "All stages cleared";
    systemChat "All execution stages cleared";
};

// Refresh the stage list display
mymod_fnc_refreshStageList = {
    private _display = findDisplay 12;
    if (isNull _display) exitWith {};
    
    private _stageListbox = _display displayCtrl 9222;
    if (isNull _stageListbox) exitWith {};
    
    lbClear _stageListbox;
    
    if (count mymod_stages == 0) then {
        _stageListbox lbAdd "No stages created";
        _stageListbox lbSetColor [0, [0.5, 0.5, 0.5, 1]];
    } else {
        {
            private _stageIndex = _forEachIndex;
            private _stage = _x;
            private _squads = _stage get "squads";
            private _status = _stage get "status";
            
            // Add stage header
            private _statusIcon = switch (_status) do {
                case "pending": { "○" };
                case "active": { "►" };
                case "completed": { "✓" };
                default { "?" };
            };
            
            private _headerText = format ["%1 STAGE %2 (%3 squads)", _statusIcon, _stageIndex + 1, count _squads];
            private _headerIndex = _stageListbox lbAdd _headerText;
            
            // Store stage index in data for right-click detection
            _stageListbox lbSetData [_headerIndex, str _stageIndex];
            
            // Color based on status
            private _color = switch (_status) do {
                case "pending": { [1, 1, 0, 1] }; // Yellow
                case "active": { [0, 1, 0, 1] }; // Green
                case "completed": { [0.5, 0.5, 0.5, 1] }; // Gray
                default { [1, 1, 1, 1] };
            };
            _stageListbox lbSetColor [_headerIndex, _color];
            
            // Add squads in this stage
            {
                private _grp = _x;
                if (!isNull _grp) then {
                    private _squadText = format ["  └ %1", groupId _grp];
                    private _squadIndex = _stageListbox lbAdd _squadText;
                    _stageListbox lbSetColor [_squadIndex, [0.7, 0.7, 0.7, 1]];
                };
            } forEach _squads;
        } forEach mymod_stages;
    };
};

// Assign squad to specific stage
mymod_fnc_assignSquadToStage = {
    params ["_squad", "_stageIndex"];
    
    if (isNull _squad) exitWith {};
    if (_stageIndex < 0 || _stageIndex >= count mymod_stages) exitWith {
        hint "Invalid stage!";
    };
    
    // Remove squad from all other stages first
    {
        private _stage = _x;
        private _squads = _stage get "squads";
        _squads = _squads - [_squad];
        _stage set ["squads", _squads];
    } forEach mymod_stages;
    
    // Add to target stage
    private _targetStage = mymod_stages select _stageIndex;
    private _squads = _targetStage get "squads";
    _squads pushBackUnique _squad;
    _targetStage set ["squads", _squads];
    
    [] call mymod_fnc_refreshStageList;
    
    hint format ["%1 assigned to Stage %2", groupId _squad, _stageIndex + 1];
    systemChat format ["Squad %1 assigned to Stage %2", groupId _squad, _stageIndex + 1];
};

// Manually execute a specific stage (called from right-click on stage list)
mymod_fnc_manuallyExecuteStage = {
    params ["_stageIndex"];
    
    if (_stageIndex < 0 || _stageIndex >= count mymod_stages) exitWith {
        hint "Invalid stage index!";
    };
    
    private _stage = mymod_stages select _stageIndex;
    private _status = _stage get "status";
    private _squads = _stage get "squads";
    
    // Check if stage is already completed
    if (_status == "completed") exitWith {
        hint format ["Stage %1 is already completed!", _stageIndex + 1];
        systemChat format ["Cannot execute Stage %1 - already completed", _stageIndex + 1];
    };
    
    // Check if stage has squads
    if (count _squads == 0) exitWith {
        hint format ["Stage %1 has no squads assigned!", _stageIndex + 1];
    };
    
    // Set current stage index and execute
    mymod_currentStageIndex = _stageIndex;
    
    // If this is the first manual execution, start the monitor
    if (_status == "pending") then {
        [] spawn mymod_fnc_monitorStageCompletion;
    };
    
    [] call mymod_fnc_executeCurrentStage;
    
    hint format ["MANUALLY EXECUTING STAGE %1\n%2 squads activated", _stageIndex + 1, count _squads];
    systemChat format ["Manual execution: Stage %1 activated (%2 squads)", _stageIndex + 1, count _squads];
};

// Monitor for map display opening and create controls dynamically
// This runs continuously and creates UI when map opens
mymod_fnc_monitorMapDisplay = {
    systemChat "Map monitor started - Squad list UI will appear when you open the map";
    
    while {true} do {
        private _display = findDisplay 12;
        
        // If map is open and controls haven't been created yet
        if (!isNull _display && !mymod_mapControlsCreated) then {
            systemChat "Map opened! Creating squad list UI...";
            
            // Create the controls
            [_display] call mymod_fnc_createMapControls;
            
            // Populate the list
            [] call mymod_fnc_refreshUnitList;
            
            // Add map click handler for waypoints
            [_display] call mymod_fnc_setupMapClickHandler;
            
            // Start squad list monitor to detect new squads
            [] spawn mymod_fnc_monitorSquadList;
            
            mymod_mapControlsCreated = true;
        };
        
        // If map is closed, reset the flag
        if (isNull _display && mymod_mapControlsCreated) then {
            mymod_mapControlsCreated = false;
            mymod_waypointMode = false; // Reset waypoint mode when map closes
            mymod_squadListMonitorActive = false; // Stop squad monitoring
            mymod_knownGroups = [];
            // Note: Don't clear markers or stop monitoring - waypoints persist even when map is closed
        };
        
        sleep 0.5;
    };
};

// Create all the map controls dynamically
mymod_fnc_createMapControls = {
    params ["_display"];
    
    // Background panel
    private _background = _display ctrlCreate ["RscText", 9210];
    _background ctrlSetPosition [0.01, 0.05, 0.22, 0.9];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _background ctrlCommit 0;
    
    // Title bar
    private _title = _display ctrlCreate ["RscText", 9211];
    _title ctrlSetPosition [0.01, 0.05, 0.22, 0.04];
    _title ctrlSetBackgroundColor [0.2, 0.3, 0.4, 1];
    _title ctrlSetText "SQUADS IN SCENARIO";
    _title ctrlSetFontHeight 0.035;
    _title ctrlCommit 0;
    
    // Listbox
    private _listbox = _display ctrlCreate ["RscListbox", 9200];
    _listbox ctrlSetPosition [0.01, 0.1, 0.22, 0.75];
    _listbox ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.8];
    _listbox ctrlSetFontHeight 0.03;
    _listbox ctrlCommit 0;
    
    // Add event handler for selection
    _listbox ctrlAddEventHandler ["LBSelChanged", {
        [] call mymod_fnc_onUnitSelected;
    }];
    
    // Add right-click handler for squad assignment to stages
    _listbox ctrlAddEventHandler ["MouseButtonDown", {
        params ["_control", "_button", "_xPos", "_yPos"];
        if (_button == 1) then {
            // Right-click - get selected squad
            private _selectedIndex = lbCurSel _control;
            if (_selectedIndex >= 0 && _selectedIndex < count mymod_groupListData) then {
                mymod_selectedSquadForStage = mymod_groupListData select _selectedIndex;
                [] call mymod_fnc_showStageAssignmentMenu;
            };
        };
    }];
    
    // Refresh button
    private _refreshBtn = _display ctrlCreate ["RscButton", 9201];
    _refreshBtn ctrlSetPosition [0.01, 0.86, 0.055, 0.04];
    _refreshBtn ctrlSetText "REFRESH";
    _refreshBtn ctrlSetBackgroundColor [0, 0.4, 0, 0.8];
    _refreshBtn ctrlSetFontHeight 0.03;
    _refreshBtn ctrlCommit 0;
    
    _refreshBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_refreshUnitList;
    }];
    
    // Center button
    private _centerBtn = _display ctrlCreate ["RscButton", 9202];
    _centerBtn ctrlSetPosition [0.066, 0.86, 0.055, 0.04];
    _centerBtn ctrlSetText "CENTER";
    _centerBtn ctrlSetBackgroundColor [0, 0.3, 0.5, 0.8];
    _centerBtn ctrlSetFontHeight 0.03;
    _centerBtn ctrlCommit 0;
    
    _centerBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_centerOnSelectedUnit;
    }];
    
    // Waypoint button
    private _waypointBtn = _display ctrlCreate ["RscButton", 9204];
    _waypointBtn ctrlSetPosition [0.122, 0.86, 0.055, 0.04];
    _waypointBtn ctrlSetText "WAYPOINT";
    _waypointBtn ctrlSetBackgroundColor [0.5, 0.3, 0, 0.8];
    _waypointBtn ctrlSetFontHeight 0.03;
    _waypointBtn ctrlCommit 0;
    
    _waypointBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_toggleWaypointMode;
    }];
    
    // Clear waypoints button
    private _clearWpBtn = _display ctrlCreate ["RscButton", 9205];
    _clearWpBtn ctrlSetPosition [0.178, 0.86, 0.055, 0.04];
    _clearWpBtn ctrlSetText "CLEAR WP";
    _clearWpBtn ctrlSetBackgroundColor [0.6, 0, 0, 0.8];
    _clearWpBtn ctrlSetFontHeight 0.03;
    _clearWpBtn ctrlCommit 0;
    
    _clearWpBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_clearWaypoints;
    }];
    
    // Tag button
    private _tagBtn = _display ctrlCreate ["RscButton", 9209];
    _tagBtn ctrlSetPosition [0.01, 0.905, 0.11, 0.04];
    _tagBtn ctrlSetText "TAG SQUAD";
    _tagBtn ctrlSetBackgroundColor [0.5, 0.4, 0, 0.8];
    _tagBtn ctrlSetFontHeight 0.03;
    _tagBtn ctrlCommit 0;
    
    _tagBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_tagSquad;
    }];
    
    // Execute All button (for staged waypoints)
    private _executeAllBtn = _display ctrlCreate ["RscButton", 9206];
    _executeAllBtn ctrlSetPosition [0.122, 0.905, 0.111, 0.04];
    _executeAllBtn ctrlSetText "EXECUTE ALL";
    _executeAllBtn ctrlSetBackgroundColor [0, 0.6, 0, 0.8];
    _executeAllBtn ctrlSetFontHeight 0.03;
    _executeAllBtn ctrlCommit 0;
    
    _executeAllBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_executeAllStagedWaypoints;
    }];
    
    // Status text
    private _statusText = _display ctrlCreate ["RscText", 9203];
    _statusText ctrlSetPosition [0.01, 0.955, 0.22, 0.03];
    _statusText ctrlSetBackgroundColor [0, 0, 0, 0];
    _statusText ctrlSetText "Loading squads...";
    _statusText ctrlSetFontHeight 0.025;
    _statusText ctrlCommit 0;
    
    // === STAGE PANEL (Right side) ===
    
    // Stage panel background
    private _stageBackground = _display ctrlCreate ["RscText", 9220];
    _stageBackground ctrlSetPosition [0.77, 0.05, 0.22, 0.9];
    _stageBackground ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _stageBackground ctrlCommit 0;
    
    // Stage title bar
    private _stageTitle = _display ctrlCreate ["RscText", 9221];
    _stageTitle ctrlSetPosition [0.77, 0.05, 0.22, 0.04];
    _stageTitle ctrlSetBackgroundColor [0.3, 0.2, 0.4, 1];
    _stageTitle ctrlSetText "STAGES (Right-click to execute)";
    _stageTitle ctrlSetFontHeight 0.035;
    _stageTitle ctrlCommit 0;
    
    // Stage listbox
    private _stageListbox = _display ctrlCreate ["RscListbox", 9222];
    _stageListbox ctrlSetPosition [0.77, 0.1, 0.22, 0.8];
    _stageListbox ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.8];
    _stageListbox ctrlSetFontHeight 0.03;
    _stageListbox ctrlCommit 0;
    
    // Add right-click handler to manually execute a stage
    _stageListbox ctrlAddEventHandler ["MouseButtonDown", {
        params ["_control", "_button", "_xPos", "_yPos"];
        if (_button == 1) then {
            // Right-click - find which stage was clicked
            private _selectedIndex = lbCurSel _control;
            if (_selectedIndex >= 0) then {
                // Get data stored in listbox item
                private _stageData = _control lbData _selectedIndex;
                if (_stageData != "") then {
                    private _stageIndex = parseNumber _stageData;
                    if (_stageIndex >= 0 && _stageIndex < count mymod_stages) then {
                        [_stageIndex] call mymod_fnc_manuallyExecuteStage;
                    };
                };
            };
        };
    }];
    
    // Add New Stage button
    private _addStageBtn = _display ctrlCreate ["RscButton", 9223];
    _addStageBtn ctrlSetPosition [0.77, 0.91, 0.11, 0.035];
    _addStageBtn ctrlSetText "ADD STAGE";
    _addStageBtn ctrlSetBackgroundColor [0, 0.4, 0.6, 0.8];
    _addStageBtn ctrlSetFontHeight 0.03;
    _addStageBtn ctrlCommit 0;
    
    _addStageBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_addNewStage;
    }];
    
    // Clear Stages button
    private _clearStagesBtn = _display ctrlCreate ["RscButton", 9224];
    _clearStagesBtn ctrlSetPosition [0.88, 0.91, 0.11, 0.035];
    _clearStagesBtn ctrlSetText "CLEAR ALL";
    _clearStagesBtn ctrlSetBackgroundColor [0.6, 0, 0, 0.8];
    _clearStagesBtn ctrlSetFontHeight 0.03;
    _clearStagesBtn ctrlCommit 0;
    
    _clearStagesBtn ctrlAddEventHandler ["ButtonClick", {
        [] call mymod_fnc_clearAllStages;
    }];
    
    mymod_stageControlsCreated = true;
    
    systemChat "Squad list UI controls created successfully!";
};

// Server-side group monitor (like @Advanced AICOMMAND)
// Publishes groups to missionNamespace so clients see Zeus-spawned squads
mymod_fnc_monitorServerGroups = {
    if (!isServer) exitWith {};

    while {true} do {
        private _serverGroups = [];
        private _sourceGroups = allGroups;
        if !(_sourceGroups isEqualType []) then { _sourceGroups = []; };

        {
            private _grp = _x;
            if (!isNull _grp) then {
                private _aliveCount = {alive _x} count (units _grp);

                if (_aliveCount > 0) then {
                    _serverGroups pushBack _grp;
                };
            };
        } forEach _sourceGroups;

        if (count _serverGroups != count mymod_serverGroups) then {
            mymod_serverGroups = _serverGroups;
            mymod_serverGroupsRevision = mymod_serverGroupsRevision + 1;
            missionNamespace setVariable ["mymod_serverGroups", mymod_serverGroups, true];
            missionNamespace setVariable ["mymod_serverGroupsRevision", mymod_serverGroupsRevision, true];
        } else {
            // Check if any groups changed
            private _changed = false;
            {
                if !(_x in mymod_serverGroups) then {
                    _changed = true;
                };
            } forEach _serverGroups;

            if (_changed) then {
                mymod_serverGroups = _serverGroups;
                mymod_serverGroupsRevision = mymod_serverGroupsRevision + 1;
                missionNamespace setVariable ["mymod_serverGroups", mymod_serverGroups, true];
                missionNamespace setVariable ["mymod_serverGroupsRevision", mymod_serverGroupsRevision, true];
            };
        };

        sleep 5; // Match Advanced AI Command cadence
    };
};

// Monitor for new squads and refresh list when changes detected
// Uses revision counter approach like @Advanced AICOMMAND for reliable detection
mymod_fnc_monitorSquadList = {
    mymod_squadListMonitorActive = true;
    systemChat "Squad list monitor started";

    while {mymod_squadListMonitorActive} do {
        if (!isNull (findDisplay 12)) then {
            private _playerSide = side player;
            private _currentGroups = [];
            private _revisionChanged = false;
            private _serverRevision = missionNamespace getVariable ["mymod_serverGroupsRevision", -1];
            private _serverGroups = missionNamespace getVariable ["mymod_serverGroups", []];
            private _useServer = (_serverRevision >= 0) && ((count _serverGroups) > 0);
            private _sourceGroups = if (_useServer) then {_serverGroups} else {allGroups};
            if !(_sourceGroups isEqualType []) then { _sourceGroups = []; };

            // Loop through all groups and build current list (same as @Advanced AICOMMAND)
            {
                private _grp = _x;
                if (!isNull _grp) then {
                    private _hasAliveUnits = {alive _x} count (units _grp);

                    if (_hasAliveUnits > 0) then {
                        private _groupSide = side _grp;
                        // Check if friendly to player
                        private _isFriendly = (_groupSide == _playerSide) || (_playerSide getFriend _groupSide >= 0.6);

                        if (_isFriendly) then {
                            _currentGroups pushBack _grp;
                        };
                    };
                };
            } forEach _sourceGroups;

            // If server revision changed, refresh regardless of local comparison
            if (_useServer && (_serverRevision != mymod_lastServerGroupsRevision)) then {
                _revisionChanged = true;
                mymod_lastServerGroupsRevision = _serverRevision;
            };

            // Detect changes - if different groups or count changed, increment revision
            if (count _currentGroups != count mymod_knownGroups) then {
                _revisionChanged = true;
            } else {
                // Check if any groups are different (new ones added or old ones removed)
                {
                    if !(_x in mymod_knownGroups) then {
                        _revisionChanged = true;
                    };
                } forEach _currentGroups;
            };

            // Update and refresh if changes detected
            if (_revisionChanged) then {
                mymod_knownGroups = _currentGroups;
                mymod_groupsRevision = mymod_groupsRevision + 1;
                [] call mymod_fnc_refreshUnitList;
                systemChat format ["Squad list updated - %1 friendly squad(s) found", count _currentGroups];
            };
        } else {
            // Map is closed
            mymod_squadListMonitorActive = false;
            mymod_knownGroups = [];
        };

        sleep 2; // Check every 2 seconds
    };
};

// Refresh the unit list
mymod_fnc_refreshUnitList = {
    private _display = findDisplay 12;
    if (isNull _display) exitWith {
        hint "Map is not open!";
    };
    
    private _listbox = _display displayCtrl 9200;
    private _statusText = _display displayCtrl 9203;
    
    if (isNull _listbox) exitWith {
        systemChat "ERROR: Listbox control not found!";
    };
    
    // Clear the listbox
    lbClear _listbox;
    mymod_groupListData = [];
    
    // Get player's side
    private _playerSide = side player;
    
    // Get all groups that have alive units and are friendly to player
    private _allGroups = [];
    private _allGroupsSource = allGroups;
    if !(_allGroupsSource isEqualType []) then { _allGroupsSource = []; };
    {
        private _grp = _x;
        if (!isNull _grp) then {
            private _units = units _grp;
            if !(_units isEqualType []) then { _units = []; };
            private _hasAliveUnits = {alive _x} count _units;
            
            if (_hasAliveUnits > 0) then {
                // Check if this group's side is friendly to player's side
                private _groupSide = side _grp;
                private _isFriendly = (_groupSide == _playerSide) || (_playerSide getFriend _groupSide >= 0.6);
                
                if (_isFriendly) then {
                    _allGroups pushBack _grp;
                };
            };
        };
    } forEach _allGroupsSource;
    
    // Sort by side and then by distance from player
    _allGroups = [_allGroups, [], {
        private _sideValue = switch (side _x) do {
            case west: {0};
            case east: {1};
            case independent: {2};
            case civilian: {3};
            default {4};
        };
        private _leader = leader _x;
        private _dist = if (!isNull _leader) then {player distance _leader} else {999999};
        _sideValue * 10000 + _dist
    }] call BIS_fnc_sortBy;
    
    // Populate the listbox
    {
        private _group = _x;
        private _groupName = groupId _group;
        private _groupSide = side _group;
        private _leader = leader _group;
        private _aliveUnits = units _group select {alive _x};
        private _unitCount = count _aliveUnits;
        private _distance = if (!isNull _leader) then {round (player distance _leader)} else {0};
        
        // Check if any unit in group is a player
        private _hasPlayer = ({isPlayer _x} count _aliveUnits) > 0;
        
        // Get squad tag if exists
        private _tag = [_group] call mymod_fnc_getSquadTag;
        
        // Color code by side
        private _color = switch (_groupSide) do {
            case west: {[0, 0.4, 0.8, 1]};      // Blue
            case east: {[0.8, 0, 0, 1]};        // Red
            case independent: {[0, 0.8, 0, 1]}; // Green
            case civilian: {[0.7, 0.3, 0.7, 1]};// Purple
            default {[1, 1, 1, 1]};             // White
        };
        
        // Format the display text
        private _displayText = format ["%1 [%2] (%3m)", _groupName, _unitCount, _distance];
        if (_tag != "") then {
            _displayText = format ["[%1] %2", _tag, _displayText];
        };
        if (_hasPlayer) then {
            _displayText = format ["[PLAYER] %1", _displayText];
        };
        
        // Add to listbox
        private _index = _listbox lbAdd _displayText;
        _listbox lbSetColor [_index, _color];
        _listbox lbSetData [_index, str _forEachIndex];
        
        // Store group reference
        mymod_groupListData pushBack _group;
        
    } forEach _allGroups;
    
    // Update status text
    private _countText = format ["Total: %1 friendly squads", count _allGroups];
    _statusText ctrlSetText _countText;
    
    systemChat format ["Squad list refreshed: %1 friendly squads found", count _allGroups];
};

// Handle unit selection in listbox
mymod_fnc_onUnitSelected = {
    private _display = findDisplay 12;
    if (isNull _display) exitWith {};
    
    private _listbox = _display displayCtrl 9200;
    private _selectedIndex = lbCurSel _listbox;
    
    if (_selectedIndex < 0) exitWith {};
    
    // Get the group
    private _dataIndex = parseNumber (_listbox lbData _selectedIndex);
    if (_dataIndex >= count mymod_groupListData) exitWith {};
    
    private _group = mymod_groupListData select _dataIndex;
    
    if (isNull _group) exitWith {
        hint "Group no longer exists";
    };
    
    // Store the selected group
    mymod_selectedGroup = _group;
    [mymod_selectedGroup] call mymod_fnc_loadGroupWaypointData;
    mymod_selectedWaypointIndex = -1;
    mymod_isDraggingWaypoint = false;
    
    private _aliveUnits = units _group select {alive _x};
    if (count _aliveUnits == 0) exitWith {
        hint "All units in group are dead";
    };
    
    private _leader = leader _group;
    
    // Build vehicle list
    private _vehicles = [];
    private _vehicleInfo = "";
    
    {
        private _unit = _x;
        private _unitVehicle = vehicle _unit;
        
        // Check if unit is in a vehicle (not on foot)
        if (_unitVehicle != _unit) then {
            // Check if vehicle is already in our list
            if !(_unitVehicle in _vehicles) then {
                _vehicles pushBack _unitVehicle;
            };
        };
    } forEach _aliveUnits;
    
    // Build vehicle info string
    if (count _vehicles > 0) then {
        _vehicleInfo = "Vehicles:\n";
        {
            private _veh = _x;
            private _vehType = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");
            if (_vehType == "") then { _vehType = typeOf _veh; };
            
            // Count squad members in this vehicle
            private _crewCount = {vehicle _x == _veh} count _aliveUnits;
            
            _vehicleInfo = _vehicleInfo + format ["  • %1 (crew: %2)\n", _vehType, _crewCount];
        } forEach _vehicles;
    } else {
        _vehicleInfo = "On foot";
    };
    
    // Show info
    private _groupInfo = format [
        "Squad: %1\nSide: %2\nUnits: %3\nPosition: %4\n\n%5",
        groupId _group,
        side _group,
        count _aliveUnits,
        mapGridPosition _leader,
        _vehicleInfo
    ];
    
    hint _groupInfo;
    systemChat format ["Selected squad: %1", groupId _group];
};

// Center map on selected unit
mymod_fnc_centerOnSelectedUnit = {
    private _display = findDisplay 12;
    if (isNull _display) exitWith {
        hint "Map is not open!";
    };
    
    private _listbox = _display displayCtrl 9200;
    private _selectedIndex = lbCurSel _listbox;
    
    if (_selectedIndex < 0) exitWith {
        hint "No squad selected! Click on a squad in the list first.";
    };
    
    // Get the group
    private _dataIndex = parseNumber (_listbox lbData _selectedIndex);
    if (_dataIndex >= count mymod_groupListData) exitWith {};
    
    private _group = mymod_groupListData select _dataIndex;
    
    if (isNull _group) exitWith {
        hint "Group no longer exists";
        [] call mymod_fnc_refreshUnitList;
    };
    
    private _leader = leader _group;
    
    if (isNull _leader || !alive _leader) exitWith {
        hint "Group leader is dead";
        [] call mymod_fnc_refreshUnitList;
    };
    
    // Center map on group leader
    private _mapCtrl = _display displayCtrl 51;
    if (!isNull _mapCtrl) then {
        _mapCtrl ctrlMapAnimAdd [0.5, 0.1, getPos _leader];
        ctrlMapAnimCommit _mapCtrl;
        hint format ["Centering on %1 leader", groupId _group];
    };
};

// Setup map click handler for waypoint placement
mymod_fnc_setupMapClickHandler = {
    params ["_display"];
    
    private _mapCtrl = _display displayCtrl 51;
    if (isNull _mapCtrl) exitWith {
        systemChat "ERROR: Map control not found!";
    };
    
    // Mouse button down handler
    _mapCtrl ctrlAddEventHandler ["MouseButtonDown", {
        params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
        
        // Convert screen coords to world position
        private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
        
        // Link mode handling (cross-group waypoint linking)
        if (mymod_linkModeActive) exitWith {
            if (_button == 1) then {
                [] call mymod_fnc_cancelWaypointLink;
                true
            } else {
                private _target = [_worldPos] call mymod_fnc_findNearestWaypointGlobal;
                if (count _target == 2) then {
                    private _srcGroupId = mymod_linkSource select 0;
                    private _srcWpNum = mymod_linkSource select 1;
                    private _tgtGroupId = _target select 0;
                    private _tgtWpNum = _target select 1;

                    if (_srcGroupId == _tgtGroupId && _srcWpNum == _tgtWpNum) then {
                        hint "Cannot link a waypoint to itself";
                    } else {
                        [_srcGroupId, _srcWpNum, _tgtGroupId, _tgtWpNum] call mymod_fnc_addWaypointLink;
                        hint format ["Linked %1 WP%2 -> %3 WP%4", _srcGroupId, _srcWpNum, _tgtGroupId, _tgtWpNum];
                    };
                } else {
                    hint "No waypoint found near click";
                };

                mymod_linkModeActive = false;
                mymod_linkSource = [];
                true
            };
        };

        // Handle left click (button 0) - place or drag waypoints
        if (_button == 0) exitWith {
            // Check if clicking near an existing waypoint (for editing)
            private _clickedWaypointIndex = [_worldPos] call mymod_fnc_findNearestWaypoint;
            
            if (_clickedWaypointIndex >= 0) then {
                // Clicked on a waypoint - select it for dragging
                mymod_selectedWaypointIndex = _clickedWaypointIndex;
                mymod_isDraggingWaypoint = true;
                systemChat format ["Selected waypoint for editing - drag to move"];
                true // consume the click
            } else {
                // Not clicking on waypoint - check if in waypoint placement mode
                if (mymod_waypointMode) then {
                    [_worldPos] call mymod_fnc_placeWaypoint;
                    true // consume the click
                } else {
                    false // don't consume
                };
            };
        };
        
        // Handle right click (button 1) - show context menu
        if (_button == 1) exitWith {
            private _clickedWaypointIndex = [_worldPos] call mymod_fnc_findNearestWaypoint;
            if (_clickedWaypointIndex >= 0) then {
                [_clickedWaypointIndex] call mymod_fnc_showWaypointContextMenu;
            };
            true // consume the click
        };
        
        false
    }];
    
    // Mouse move handler for dragging waypoints
    _mapCtrl ctrlAddEventHandler ["MouseMoving", {
        params ["_control", "_xPos", "_yPos"];
        
        if (mymod_isDraggingWaypoint && mymod_selectedWaypointIndex >= 0) then {
            private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
            [mymod_selectedWaypointIndex, _worldPos] call mymod_fnc_moveWaypoint;
        };
        
        false
    }];
    
    // Mouse button up handler to finish dragging
    _mapCtrl ctrlAddEventHandler ["MouseButtonUp", {
        params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
        
        if (_button == 0 && mymod_isDraggingWaypoint) then {
            private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
            [mymod_selectedWaypointIndex, _worldPos, true] call mymod_fnc_moveWaypoint;
            mymod_isDraggingWaypoint = false;
            
            // Reset all waypoint colors to normal
            {
                private _wpNumber = mymod_waypointNumbers select _forEachIndex;
                private _markerName = format ["mymod_wp_%1_%2", groupId mymod_selectedGroup, _wpNumber];
                _markerName setMarkerColor "ColorOrange";
            } forEach mymod_waypointPositions;
            
            systemChat format ["WP%1 moved to %2", mymod_selectedWaypointIndex, mapGridPosition _worldPos];
            mymod_selectedWaypointIndex = -1;
            true
        } else {
            false
        };
    }];
    
    systemChat "Map click handler installed";
};

// Toggle waypoint placement mode
mymod_fnc_toggleWaypointMode = {
    private _display = findDisplay 12;
    if (isNull _display) exitWith {};
    
    // Check if a group is selected
    if (isNull mymod_selectedGroup) exitWith {
        hint "No squad selected!\nSelect a squad first, then click WAYPOINT.";
    };
    
    // If turning on waypoint mode, load current group data and reset edit state
    if (!mymod_waypointMode) then {
        [mymod_selectedGroup] call mymod_fnc_loadGroupWaypointData;
        mymod_selectedWaypointIndex = -1;
        mymod_isDraggingWaypoint = false;
    };
    
    // Toggle the mode
    mymod_waypointMode = !mymod_waypointMode;
    
    // Update button appearance
    private _waypointBtn = _display displayCtrl 9204;
    if (!isNull _waypointBtn) then {
        if (mymod_waypointMode) then {
            _waypointBtn ctrlSetBackgroundColor [1, 0.5, 0, 1]; // Bright orange when active
            _waypointBtn ctrlSetText "CANCEL";
        } else {
            _waypointBtn ctrlSetBackgroundColor [0.5, 0.3, 0, 0.8]; // Normal color
            _waypointBtn ctrlSetText "WAYPOINT";
        };
        _waypointBtn ctrlCommit 0;
    };
    
    // Update status text
    private _statusText = _display displayCtrl 9203;
    if (!isNull _statusText) then {
        if (mymod_waypointMode) then {
            _statusText ctrlSetText format ["WAYPOINT MODE: Click map (WP%1 next)", mymod_nextWaypointNumber];
        } else {
            _statusText ctrlSetText format ["Total: %1 friendly squads", count mymod_groupListData];
        };
        _statusText ctrlCommit 0;
    };
    
    if (mymod_waypointMode) then {
        hint format ["WAYPOINT MODE ACTIVE\nClick map to add waypoints for %1\nNext: WP%2\nClick CANCEL to exit", groupId mymod_selectedGroup, mymod_nextWaypointNumber];
        systemChat format ["Waypoint mode ON for %1 - click map to add waypoints", groupId mymod_selectedGroup];
    } else {
        hint "Waypoint mode disabled";
        systemChat "Waypoint mode OFF";
    };
};

// Place a waypoint for the selected group (creates staged waypoint)
mymod_fnc_placeWaypoint = {
    params ["_worldPos"];
    
    if (isNull mymod_selectedGroup) exitWith {
        hint "No squad selected!";
        mymod_waypointMode = false;
    };
    
    // Check if group still exists and has alive units
    private _aliveUnits = units mymod_selectedGroup select {alive _x};
    if (count _aliveUnits == 0) exitWith {
        hint "Selected squad has no alive units!";
        mymod_waypointMode = false;
    };
    
    // Get current waypoint count for this group
    private _wpCount = count mymod_waypointPositions;
    
    // Assign a waypoint number (use the next available number)
    private _wpNumber = mymod_nextWaypointNumber;
    mymod_nextWaypointNumber = mymod_nextWaypointNumber + 1;
    
    // DON'T create actual AI waypoint yet - mark it as staged
    // The waypoint will be created when "Execute All" is clicked
    
    private _wpType = "MOVE";

    // Create marker for this waypoint (yellow for staged)
    private _markerName = format ["mymod_wp_%1_%2", groupId mymod_selectedGroup, _wpNumber];
    private _marker = createMarker [_markerName, _worldPos];
    _marker setMarkerShape "ICON";
    _marker setMarkerType "mil_dot";
    _marker setMarkerSize [1.2, 1.2];
    _marker setMarkerText format ["[%1] - %2 (STAGED)", groupId mymod_selectedGroup, _wpType];
    _marker setMarkerColor "ColorYellow"; // Yellow for staged waypoints
    
    // Store marker name, position, waypoint number, and staged status
    mymod_waypointMarkers pushBack _markerName;
    mymod_waypointPositions pushBack _worldPos;
    mymod_waypointNumbers pushBack _wpNumber;
    mymod_waypointTypes pushBack _wpType;
    mymod_stagedWaypoints pushBack true; // Mark as staged
    
    // Add group to stagedGroupReferences if not already there
    if !(mymod_selectedGroup in mymod_stagedGroupReferences) then {
        mymod_stagedGroupReferences pushBack mymod_selectedGroup;
    };
    
    // Draw connecting lines
    [] call mymod_fnc_redrawWaypointLines;
    
    // Persist changes
    mymod_selectedGroup setVariable ["mymod_wp_ai", []];
    [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
    
    systemChat format ["STAGED: WP%1 for %2 - click EXECUTE ALL to activate", _wpNumber, groupId mymod_selectedGroup];
    hint format ["Waypoint WP%1 staged\nClick EXECUTE ALL when ready", _wpNumber];
    
    // Update UI status if needed
    private _display = findDisplay 12;
    if (!isNull _display) then {
        private _statusText = _display displayCtrl 9203;
        if (!isNull _statusText) then {
            _statusText ctrlSetText format ["WAYPOINT MODE: Click map (WP%1 next)", mymod_nextWaypointNumber];
            _statusText ctrlCommit 0;
        };
    };
};

// Execute all staged waypoints - activates them and starts AI movement
mymod_fnc_executeAllStagedWaypoints = {
    // Check if stages are being used
    if (count mymod_stages > 0) exitWith {
        // STAGE-BASED EXECUTION
        // Reset stage statuses and start from Stage 1
        {
            _x set ["status", "pending"];
        } forEach mymod_stages;
        
        mymod_currentStageIndex = 0;
        
        // Execute Stage 1
        [] call mymod_fnc_executeCurrentStage;
        
        // Start monitoring stage completion for auto-advancement
        [] spawn mymod_fnc_monitorStageCompletion;
        
        hint format ["STAGE EXECUTION STARTED\nStage 1 of %1 is now active", count mymod_stages];
        systemChat format ["Stage-based execution: Starting Stage 1 of %1", count mymod_stages];
    };
    
    // LEGACY EXECUTION (no stages defined)
    // Check if there are any staged waypoints
    if (count mymod_stagedGroupReferences == 0) exitWith {
        hint "No staged waypoints to execute";
        systemChat "No staged waypoints available";
    };
    
    // Process each group with staged waypoints
    {
        private _group = _x;
        if (isNull _group) then {
            // Remove null groups
            _forEachIndex
        } else {
            _group setVariable ["mymod_wp_ai", []];
            // Load group's waypoint data
            private _positions = _group getVariable ["mymod_wp_positions", []];
            private _numbers = _group getVariable ["mymod_wp_numbers", []];
            private _markers = _group getVariable ["mymod_wp_markers", []];
            private _types = _group getVariable ["mymod_wp_types", []];
            private _staged = _group getVariable ["mymod_wp_staged", []];
            
            // Create AI waypoints for all staged ones
            {
                if (_staged select _forEachIndex == true) then {
                    private _wpPos = _positions select _forEachIndex;
                    private _wpNum = _numbers select _forEachIndex;
                    private _markerName = _markers select _forEachIndex;
                    private _wpType = "MOVE";
                    if (_forEachIndex < count _types) then {
                        _wpType = _types select _forEachIndex;
                    };
                    
                    // Create the actual AI waypoint
                    private _wp = _group addWaypoint [_wpPos, 0];
                    _wp setWaypointType _wpType;
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "AWARE";
                    
                    // Spawn helipad if TR UNLOAD waypoint
                    if (_wpType == "TR UNLOAD") then {
                        [_wpPos, _markerName] call mymod_fnc_spawnHelipad;
                    };
                    
                    // Set completion statement - use groupId so it matches in mymod_fnc_markWaypointCompleted
                    private _onCompletionCode = format ["[%1, %2] call mymod_fnc_markWaypointCompleted", str (groupId _group), _wpNum];
                    _wp setWaypointStatements ["true", _onCompletionCode];

                    [_group, _wpNum, _wp] call mymod_fnc_registerAiWaypoint;
                    
                    // Update marker color from yellow (staged) to orange (active)
                    _markerName setMarkerColor "ColorOrange";
                    _markerName setMarkerText format ["[%1] - %2", groupId _group, _wpType];
                    
                    // Mark as active in the staged array
                    _staged set [_forEachIndex, false];
                };
            } forEach _positions;
            
            // Save updated staged status
            _group setVariable ["mymod_wp_staged", _staged];
        };
    } forEach mymod_stagedGroupReferences;

    [] call mymod_fnc_applyWaypointLinks;
    
    // Clear the staged group references since all are now executed
    mymod_stagedGroupReferences = [];
    
    // Update hint
    hint "All staged waypoints EXECUTED!\nSquads are now moving to waypoints";
    systemChat "EXECUTE ALL: All staged waypoints activated";
};

// Execute waypoints for the current stage
mymod_fnc_executeCurrentStage = {
    if (mymod_currentStageIndex < 0 || mymod_currentStageIndex >= count mymod_stages) exitWith {};
    
    private _stage = mymod_stages select mymod_currentStageIndex;
    private _squads = _stage get "squads";
    
    if (count _squads == 0) exitWith {
        hint format ["Stage %1 has no squads!", mymod_currentStageIndex + 1];
    };
    
    // Mark stage as active
    _stage set ["status", "active"];
    [] call mymod_fnc_refreshStageList;
    
    // Execute each squad's staged waypoints
    {
        private _group = _x;
        if (!isNull _group) then {
            _group setVariable ["mymod_wp_ai", []];
            private _positions = _group getVariable ["mymod_wp_positions", []];
            private _numbers = _group getVariable ["mymod_wp_numbers", []];
            private _markers = _group getVariable ["mymod_wp_markers", []];
            private _types = _group getVariable ["mymod_wp_types", []];
            private _staged = _group getVariable ["mymod_wp_staged", []];
            
            // Create AI waypoints for all staged ones
            {
                if (_staged select _forEachIndex == true) then {
                    private _wpPos = _positions select _forEachIndex;
                    private _wpNum = _numbers select _forEachIndex;
                    private _markerName = _markers select _forEachIndex;
                    private _wpType = "MOVE";
                    if (_forEachIndex < count _types) then {
                        _wpType = _types select _forEachIndex;
                    };
                    
                    // Create the actual AI waypoint
                    private _wp = _group addWaypoint [_wpPos, 0];
                    _wp setWaypointType _wpType;
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "AWARE";
                    
                    // Spawn helipad if TR UNLOAD waypoint
                    if (_wpType == "TR UNLOAD") then {
                        [_wpPos, _markerName] call mymod_fnc_spawnHelipad;
                    };
                    
                    // Set completion statement - use groupId so it matches in mymod_fnc_markWaypointCompleted
                    private _onCompletionCode = format ["[%1, %2] call mymod_fnc_markWaypointCompleted", str (groupId _group), _wpNum];
                    _wp setWaypointStatements ["true", _onCompletionCode];

                    [_group, _wpNum, _wp] call mymod_fnc_registerAiWaypoint;
                    
                    // Update marker color from yellow (staged) to orange (active)
                    _markerName setMarkerColor "ColorOrange";
                    _markerName setMarkerText format ["[%1] - %2", groupId _group, _wpType];
                    
                    // Mark as active in the staged array
                    _staged set [_forEachIndex, false];
                };
            } forEach _positions;
            
            // Save updated staged status
            _group setVariable ["mymod_wp_staged", _staged];
        };
    } forEach _squads;

    [] call mymod_fnc_applyWaypointLinks;
    
    hint format ["Stage %1 EXECUTING\n%2 squads moving", mymod_currentStageIndex + 1, count _squads];
    systemChat format ["Stage %1 activated - %2 squads executing waypoints", mymod_currentStageIndex + 1, count _squads];
};

// Monitor stage completion and auto-advance to next stage
mymod_fnc_monitorStageCompletion = {
    systemChat format ["Stage Monitor Started - %1 stages total", count mymod_stages];
    
    while {mymod_currentStageIndex < count mymod_stages} do {
        sleep 1; // Check every 1 second
        
        if (mymod_currentStageIndex >= 0 && mymod_currentStageIndex < count mymod_stages) then {
            private _stage = mymod_stages select mymod_currentStageIndex;
            private _squads = _stage get "squads";
            private _status = _stage get "status";
            
            if (_status == "active") then {
                // Check if all squads in this stage have completed their waypoints
                private _allComplete = true;
                private _debugMsg = format ["Stage %1 Monitor: ", mymod_currentStageIndex + 1];
                
                {
                    private _group = _x;
                    if (!isNull _group) then {
                        private _positions = _group getVariable ["mymod_wp_positions", []];
                        private _wpCount = count _positions;
                        _debugMsg = _debugMsg + format ["%1(%2 WPs) ", groupId _group, _wpCount];
                        
                        if (_wpCount > 0) then {
                            _allComplete = false;
                        };
                    } else {
                        _debugMsg = _debugMsg + "NULL_GROUP ";
                    };
                } forEach _squads;
                
                // Debug output every 5 seconds
                if ((round (time % 5)) == 0) then {
                    systemChat _debugMsg;
                };
                
                // If all squads in current stage completed, advance to next
                if (_allComplete && count _squads > 0) then {
                    systemChat format ["STAGE COMPLETION DETECTED: Stage %1 complete!", mymod_currentStageIndex + 1];
                    
                    _stage set ["status", "completed"];
                    [] call mymod_fnc_refreshStageList;
                    
                    systemChat format ["Stage %1 COMPLETED", mymod_currentStageIndex + 1];
                    
                    // Move to next stage
                    mymod_currentStageIndex = mymod_currentStageIndex + 1;
                    
                    if (mymod_currentStageIndex < count mymod_stages) then {
                        // Execute next stage
                        [] call mymod_fnc_executeCurrentStage;
                        hint format ["STAGE %1 COMPLETE!\nAdvancing to STAGE %2...", mymod_currentStageIndex, mymod_currentStageIndex + 1];
                        systemChat format ["Executing Stage %1", mymod_currentStageIndex + 1];
                    } else {
                        // All stages completed
                        hint "ALL STAGES COMPLETED!";
                        systemChat "✓ All execution stages completed successfully";
                    };
                };
            };
        };
    };
    
    systemChat "Stage Monitor Ended";
};

// Draw a line between two waypoints
mymod_fnc_drawWaypointLine = {
    params ["_startPos", "_endPos", "_lineNumber"];
    
    // Create a marker line between the two waypoints
    private _markerName = format ["mymod_line_%1_%2", groupId mymod_selectedGroup, _lineNumber];
    private _midPoint = [
        ((_startPos select 0) + (_endPos select 0)) / 2,
        ((_startPos select 1) + (_endPos select 1)) / 2,
        0
    ];
    
    // Calculate distance and angle for the line marker
    private _distance = _startPos distance _endPos;
    private _angle = (_startPos getDir _endPos) + 90; // Perpendicular for proper line display
    
    private _marker = createMarker [_markerName, _midPoint];
    _marker setMarkerShape "RECTANGLE";
    _marker setMarkerSize [_distance / 2, 0.3];
    _marker setMarkerDir _angle;
    _marker setMarkerColor "ColorOrange";
    _marker setMarkerBrush "SolidBorder";
    _marker setMarkerAlpha 0.7;
    
    // Store the line marker
    mymod_waypointMarkers pushBack _markerName;
};

// Clear all waypoint markers
mymod_fnc_clearWaypointMarkers = {
    {
        deleteMarker _x;
        // Clean up any helipad associated with this marker
        [_x] call mymod_fnc_deleteHelipadForMarker;
    } forEach mymod_waypointMarkers;
    mymod_waypointMarkers = [];

    {
        deleteMarker _x;
    } forEach mymod_waypointSyncMarkers;
    mymod_waypointSyncMarkers = [];

    if (!isNull mymod_selectedGroup) then {
        [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
    };
};



// Find the nearest waypoint to a clicked position
mymod_fnc_findNearestWaypoint = {
    params ["_clickPos"];
    
    private _nearestIndex = -1;
    private _nearestDist = 50; // Maximum click distance in meters
    
    {
        private _wpPos = _x;
        private _dist = _clickPos distance _wpPos;
        
        if (_dist < _nearestDist) then {
            _nearestDist = _dist;
            _nearestIndex = _forEachIndex;
        };
    } forEach mymod_waypointPositions;
    
    // Update marker colors - highlight selected waypoint
    if (_nearestIndex >= 0) then {
        {
            private _wpNumber = mymod_waypointNumbers select _forEachIndex;
            private _markerName = format ["mymod_wp_%1_%2", groupId mymod_selectedGroup, _wpNumber];
            if (_forEachIndex == _nearestIndex) then {
                _markerName setMarkerColor "ColorYellow"; // Highlight selected
            } else {
                _markerName setMarkerColor "ColorOrange"; // Normal color
            };
        } forEach mymod_waypointPositions;
    };
    
    _nearestIndex
};

// Find the nearest waypoint across all groups
mymod_fnc_findNearestWaypointGlobal = {
    params ["_clickPos"];

    private _nearest = [];
    private _nearestDist = 50; // Maximum click distance in meters

    {
        private _grp = _x;
        if (!isNull _grp) then {
            private _positions = _grp getVariable ["mymod_wp_positions", []];
            private _numbers = _grp getVariable ["mymod_wp_numbers", []];

            {
                private _dist = _clickPos distance _x;
                if (_dist < _nearestDist) then {
                    _nearestDist = _dist;
                    _nearest = [groupId _grp, _numbers select _forEachIndex];
                };
            } forEach _positions;
        };
    } forEach allGroups;

    _nearest
};

// Move a waypoint to a new position
mymod_fnc_moveWaypoint = {
    params ["_wpIndex", "_newPos", ["_finalize", false]];
    
    if (_wpIndex < 0 || _wpIndex >= count mymod_waypointPositions) exitWith {};
    if (isNull mymod_selectedGroup) exitWith {};
    
    // Update the stored position
    mymod_waypointPositions set [_wpIndex, _newPos];
    
    // Update the marker position (use original waypoint number)
    private _wpNumber = mymod_waypointNumbers select _wpIndex;
    private _markerName = format ["mymod_wp_%1_%2", groupId mymod_selectedGroup, _wpNumber];
    _markerName setMarkerPos _newPos;
    
    // Redraw connecting lines
    [] call mymod_fnc_redrawWaypointLines;
    [] call mymod_fnc_redrawSyncLines;

    // Persist changes for this group
    [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
    
    // Always update actual AI waypoint position (both during drag and on finalize)
    private _aiWaypoints = waypoints mymod_selectedGroup;
    // +1 because index 0 is the starting waypoint
    if ((_wpIndex + 1) < count _aiWaypoints) then {
        private _wp = _aiWaypoints select (_wpIndex + 1);
        _wp setWaypointPosition [_newPos, 0];
        
        if (_finalize) then {
            systemChat format ["WP%1 updated at %2", _wpNumber, mapGridPosition _newPos];
        };
    };
};

// Redraw all waypoint connecting lines
mymod_fnc_redrawWaypointLines = {
    // Delete all line markers
    {
        private _markerName = _x;
        if (_markerName find "mymod_line_" == 0) then {
            deleteMarker _markerName;
        };
    } forEach mymod_waypointMarkers;
    
    // Remove line markers from the array (keep only waypoint markers)
    mymod_waypointMarkers = mymod_waypointMarkers select {_x find "mymod_line_" != 0};
    
    // Redraw lines between consecutive waypoints
    for "_i" from 1 to (count mymod_waypointPositions - 1) do {
        private _prevPos = mymod_waypointPositions select (_i - 1);
        private _currPos = mymod_waypointPositions select _i;
        [_prevPos, _currPos, _i] call mymod_fnc_drawWaypointLine;
    };

    if (!isNull mymod_selectedGroup) then {
        [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
    };
};

// Called when a waypoint is completed by the group - triggered via setWaypointStatements
mymod_fnc_markWaypointCompleted = {
    params ["_groupName", "_wpNumber"];
    
    systemChat format ["✓ WAYPOINT COMPLETION TRIGGERED: %1 WP%2", _groupName, _wpNumber];
    
    private _group = grpNull;
    {
        if (groupId _x == _groupName) exitWith {
            _group = _x;
        };
    } forEach allGroups;

    if (isNull _group) exitWith {
        systemChat format ["ERROR: Group %1 not found!", _groupName];
    };

    private _positions = +(_group getVariable ["mymod_wp_positions", []]);
    private _numbers = +(_group getVariable ["mymod_wp_numbers", []]);
    private _markers = +(_group getVariable ["mymod_wp_markers", []]);
    private _types = +(_group getVariable ["mymod_wp_types", []]);
    private _staged = +(_group getVariable ["mymod_wp_staged", []]);
    private _wpIndex = _numbers find _wpNumber;

    if (_wpIndex < 0) exitWith {};

    // Delete the marker for this waypoint
    private _markerName = format ["mymod_wp_%1_%2", _groupName, _wpNumber];
    deleteMarker _markerName;
    private _markerIndex = _markers find _markerName;
    if (_markerIndex >= 0) then {
        _markers deleteAt _markerIndex;
    };

    // Delete the line FROM this waypoint TO the next
    if (_wpIndex + 1 < count _numbers) then {
        private _nextWpNumber = _numbers select (_wpIndex + 1);
        private _lineMarkerName = format ["mymod_line_%1_%2", _groupName, _nextWpNumber];
        deleteMarker _lineMarkerName;

        private _lineIndex = _markers find _lineMarkerName;
        if (_lineIndex >= 0) then {
            _markers deleteAt _lineIndex;
        };
    };

    _positions deleteAt _wpIndex;
    _numbers deleteAt _wpIndex;
    if (_wpIndex < count _types) then { _types deleteAt _wpIndex; };
    if (_wpIndex < count _staged) then { _staged deleteAt _wpIndex; };

    _group setVariable ["mymod_wp_positions", _positions];
    _group setVariable ["mymod_wp_numbers", _numbers];
    _group setVariable ["mymod_wp_markers", _markers];
    _group setVariable ["mymod_wp_types", _types];
    _group setVariable ["mymod_wp_staged", _staged];

    if (_group == mymod_selectedGroup) then {
        mymod_waypointPositions = +_positions;
        mymod_waypointNumbers = +_numbers;
        mymod_waypointMarkers = +_markers;
        mymod_waypointTypes = +_types;
        mymod_stagedWaypoints = +_staged;
    };

    [groupId _group, _wpNumber] call mymod_fnc_removeLinksForWaypoint;

    if (count _positions == 0) then {
        systemChat format ["✓ ALL WAYPOINTS DELETED for %1 - Stage can advance!", _groupName];
    } else {
        systemChat format ["✓ WP%1 deleted - %2 waypoints remaining for %3", _wpNumber, count _positions, _groupName];
    };
};

// Monitor waypoints for changes (revision-based detection)
mymod_fnc_monitorWaypoints = {
    mymod_waypointMonitorActive = true;
    systemChat "Waypoint monitor started";
    
    private _lastSeenRevision = 0;
    
    while {mymod_waypointMonitorActive} do {
        if (!isNull mymod_selectedGroup && count mymod_waypointPositions > 0) then {
            // Check if group is still alive
            private _aliveUnits = units mymod_selectedGroup select {alive _x};
            if (count _aliveUnits == 0) then {
                // Group wiped out - clear markers
                [] call mymod_fnc_clearWaypointMarkers;
                mymod_waypointPositions = [];
                mymod_waypointNumbers = [];
                mymod_nextWaypointNumber = 0;
                [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
                mymod_waypointMonitorActive = false;
                systemChat format ["%1 eliminated - waypoints cleared", groupId mymod_selectedGroup];
            };
        } else {
            // No active waypoints to monitor
            if (count mymod_waypointPositions == 0) then {
                mymod_waypointMonitorActive = false;
            };
        };
        
        sleep 2; // Check every 2 seconds
    };
};

// Remove a waypoint marker and its connecting line when completed
mymod_fnc_removeWaypointMarkerAndLine = {
    params ["_wpIndex"];
    
    if (_wpIndex < 0 || _wpIndex >= count mymod_waypointPositions) exitWith {};
    
    private _groupName = groupId mymod_selectedGroup;
    private _wpNumber = mymod_waypointNumbers select _wpIndex;
    
    // Delete the waypoint marker (use original waypoint number)
    private _markerName = format ["mymod_wp_%1_%2", _groupName, _wpNumber];
    deleteMarker _markerName;
    mymod_waypointMarkers deleteAt (mymod_waypointMarkers find _markerName);
    
    // Delete the line leading FROM this waypoint TO the next waypoint
    if (_wpIndex + 1 < count mymod_waypointPositions) then {
        private _nextWpNumber = mymod_waypointNumbers select (_wpIndex + 1);
        private _lineMarkerName = format ["mymod_line_%1_%2", _groupName, _nextWpNumber];
        deleteMarker _lineMarkerName;
        
        private _lineIndex = mymod_waypointMarkers find _lineMarkerName;
        if (_lineIndex >= 0) then {
            mymod_waypointMarkers deleteAt _lineIndex;
        };
    };
    
    // Remove from tracking arrays
    mymod_waypointPositions deleteAt _wpIndex;
    mymod_waypointNumbers deleteAt _wpIndex;
    if (_wpIndex < count mymod_waypointTypes) then { mymod_waypointTypes deleteAt _wpIndex; };
    if (_wpIndex < count mymod_stagedWaypoints) then { mymod_stagedWaypoints deleteAt _wpIndex; };

    [groupId mymod_selectedGroup, _wpNumber] call mymod_fnc_removeLinksForWaypoint;

    [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
};

// Clear all waypoints for the selected group
mymod_fnc_clearWaypoints = {
    if (isNull mymod_selectedGroup) exitWith {
        hint "No squad selected!\nSelect a squad first.";
    };
    
    private _groupName = groupId mymod_selectedGroup;
    private _wpCount = count (waypoints mymod_selectedGroup) - 1;
    
    if (_wpCount <= 0) exitWith {
        hint format ["%1 has no waypoints to clear", _groupName];
    };
    
    // Delete all waypoints except the starting position (index 0)
    while {(count (waypoints mymod_selectedGroup)) > 1} do {
        deleteWaypoint ((waypoints mymod_selectedGroup) select 1);
    };
    
    // Clear all waypoint markers
    [] call mymod_fnc_clearWaypointMarkers;

    // Remove any sync links for this group
    {
        [groupId mymod_selectedGroup, _x] call mymod_fnc_removeLinksForWaypoint;
    } forEach mymod_waypointNumbers;

    mymod_waypointPositions = [];
    mymod_waypointNumbers = [];
    mymod_waypointTypes = [];
    mymod_stagedWaypoints = [];
    mymod_nextWaypointNumber = 0;
    mymod_selectedWaypointIndex = -1;
    mymod_isDraggingWaypoint = false;
    mymod_waypointMonitorActive = false; // Stop monitoring
    
    // Remove from staged group references if it was there
    private _groupIndex = mymod_stagedGroupReferences find mymod_selectedGroup;
    if (_groupIndex >= 0) then {
        mymod_stagedGroupReferences deleteAt _groupIndex;
    };
    
    [mymod_selectedGroup] call mymod_fnc_saveGroupWaypointData;
    
    hint format ["All waypoints cleared for %1\n%2 waypoint(s) removed", _groupName, _wpCount];
    systemChat format ["%1: All waypoints cleared (%2 removed)", _groupName, _wpCount];
    
    // Update status text if in waypoint mode
    if (mymod_waypointMode) then {
        private _display = findDisplay 12;
        if (!isNull _display) then {
            private _statusText = _display displayCtrl 9203;
            if (!isNull _statusText) then {
                _statusText ctrlSetText format ["WAYPOINT MODE: Click map (WP0 next)"];
                _statusText ctrlCommit 0;
            };
        };
    };
};

// ===== HELIPAD SPAWNING FOR TR UNLOAD WAYPOINTS =====

// Spawn invisible helipad at waypoint location
mymod_fnc_spawnHelipad = {
    params ["_pos", "_markerName"];
    
    // Create invisible helipad
    private _helipad = createVehicle ["Land_HelipadEmpty_F", _pos, [], 0, "CAN_COLLIDE"];
    _helipad setPos _pos;
    
    // Store helipad reference linked to marker
    mymod_waypointHelipads pushBack [_helipad, _markerName];
    
    systemChat format ["Helipad spawned at %1 for unload waypoint", mapGridPosition _pos];
};

// Clean up helipad when waypoint is deleted
mymod_fnc_deleteHelipadForMarker = {
    params ["_markerName"];
    
    {
        if ((_x select 1) == _markerName) then {
            private _helipad = _x select 0;
            deleteVehicle _helipad;
            mymod_waypointHelipads deleteAt _forEachIndex;
            systemChat format ["Helipad removed for waypoint %1", _markerName];
        };
    } forEach mymod_waypointHelipads;
};

// ===== SQUAD TAGGING SYSTEM =====

// Get tag for a squad (returns empty string if no tag)
mymod_fnc_getSquadTag = {
    params ["_group"];
    private _tag = "";
    {
        if ((_x select 0) == _group) exitWith {
            _tag = _x select 1;
        };
    } forEach mymod_squadTags;
    _tag
};

// Set tag for a squad
mymod_fnc_setSquadTag = {
    params ["_group", "_tag"];
    private _found = false;
    {
        if ((_x select 0) == _group) then {
            _x set [1, _tag];
            _found = true;
        };
    } forEach mymod_squadTags;
    if (!_found) then {
        mymod_squadTags pushBack [_group, _tag];
    };
};

// Tag the selected squad
mymod_fnc_tagSquad = {
    if (isNull mymod_selectedGroup) exitWith {
        hint "No squad selected!";
    };
    
    private _currentTag = [mymod_selectedGroup] call mymod_fnc_getSquadTag;
    private _groupName = groupId mymod_selectedGroup;
    
    // Predefined tag options
    private _tagOptions = ["ASSAULT", "RECON", "SUPPORT", "SNIPER", "ARMOR", "AIR", "RESERVE", "QRF", "NONE"];
    
    // Find current tag index
    private _currentIndex = _tagOptions find _currentTag;
    
    // Get next tag (cycle through options)
    private _nextIndex = (_currentIndex + 1) mod (count _tagOptions);
    private _newTag = _tagOptions select _nextIndex;
    
    // If new tag is "NONE", remove the tag
    if (_newTag == "NONE") then {
        mymod_squadTags = mymod_squadTags select {(_x select 0) != mymod_selectedGroup};
        hint format ["Tag removed from %1", _groupName];
    } else {
        [mymod_selectedGroup, _newTag] call mymod_fnc_setSquadTag;
        hint format ["%1 tagged as: %2\n(Click again to cycle tags)", _groupName, _newTag];
    };
    
    [] call mymod_fnc_refreshUnitList;
};

// OLD TEST FUNCTIONS (kept for backwards compatibility)

// Function to open the standalone dialog
mymod_fnc_openDialog = {
    createDialog "MyMapDialog";
};

// Test function
mymod_fnc_testFunction = {
    hint "SQF Function called successfully from mod!";
    systemChat "This proves the mod is loaded and working.";
};

// Initialize
systemChat "MyMod GUI functions loaded successfully!";
systemChat "Open map (M) to see squad list on the left side";

// Auto-start the map monitor
[] spawn mymod_fnc_monitorMapDisplay;

// Auto-start server group monitor for Zeus-spawned squads
if (isServer) then {
    [] spawn mymod_fnc_monitorServerGroups;
};
