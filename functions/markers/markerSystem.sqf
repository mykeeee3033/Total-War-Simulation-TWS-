/*
 * markerSystem.sqf
 * Comprehensive Marker System for Strategic Objects
 * 
 * Features:
 * - Persistent markers for all strategic objects
 * - Color coding and icons for different object types
 * - Status information in marker labels
 * - Marker updates based on object state
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_objectRoles"};
    
    diag_log "[TWS] Initializing marker system...";
    systemChat "[TWS] Initializing marker system...";
    
    // Marker tracking
    TWS_markers = createHashMap;
    TWS_markers set ["objectMarkers", createHashMap];
    TWS_markers set ["eventMarkers", []];
    TWS_markers set ["combatMarkers", []];
    
    // Marker configuration for different object types
    TWS_markerConfig = createHashMap;
    
    // Factories
    TWS_markerConfig set ["munitionsFactory", ["ICON", "mil_box", "ColorYellow", "Factory"]];
    TWS_markerConfig set ["fuelRefinery", ["ICON", "mil_box", "ColorOrange", "Refinery"]];
    TWS_markerConfig set ["vehiclePlant", ["ICON", "mil_box", "ColorBrown", "Vehicle Plant"]];
    TWS_markerConfig set ["aircraftPlant", ["ICON", "mil_box", "ColorGreen", "Aircraft Plant"]];
    
    // Infrastructure
    TWS_markerConfig set ["powerStation", ["ICON", "mil_dot", "ColorYellow", "Power Station"]];
    TWS_markerConfig set ["antenna", ["ICON", "mil_triangle", "ColorBlue", "Antenna"]];
    TWS_markerConfig set ["radarSite", ["ICON", "mil_warning", "ColorRed", "Radar"]];
    TWS_markerConfig set ["hqNode", ["ICON", "mil_flag", "ColorBlack", "HQ"]];
    TWS_markerConfig set ["logisticsHub", ["ICON", "mil_box", "ColorGreen", "Supply Point"]];
    
    // Function to create marker for strategic object
    TWS_fnc_createObjectMarker = {
        params ["_object", "_role", "_faction"];
        
        if (isNull _object) exitWith {
            diag_log "[TWS] Cannot create marker for null object";
        };
        
        private _pos = getPosASL _object;
        private _markerName = format ["tws_obj_%1_%2", _role, str _object];
        
        // Get marker configuration
        private _config = TWS_markerConfig getOrDefault [_role, ["ICON", "mil_dot", "ColorGrey", "Object"]];
        private _markerType = _config select 0;
        private _markerIcon = _config select 1;
        private _markerColor = _config select 2;
        private _markerLabel = _config select 3;
        
        // Adjust color based on faction
        if (_faction == "OPFOR") then {
            _markerColor = "ColorRed";
        } else {
            if (_faction == "BLUFOR") then {
                _markerColor = "ColorBlue";
            };
        };
        
        // Create marker
        private _marker = createMarker [_markerName, _pos];
        _marker setMarkerType _markerIcon;
        _marker setMarkerColor _markerColor;
        _marker setMarkerText format ["%1 (%2)", _markerLabel, _faction];
        _marker setMarkerAlpha 1;
        
        // Store marker reference
        private _objectMarkers = TWS_markers get "objectMarkers";
        _objectMarkers set [str _object, _markerName];
        
        diag_log format ["[TWS] Created marker %1 for %2 at %3", _markerName, _role, _pos];
        
        _markerName
    };
    
    // Function to update object marker status
    TWS_fnc_updateObjectMarker = {
        params ["_object", "_operational"];
        
        private _objectMarkers = TWS_markers get "objectMarkers";
        private _markerName = _objectMarkers getOrDefault [str _object, ""];
        
        if (_markerName == "") exitWith {
            diag_log format ["[TWS] No marker found for object %1", _object];
        };
        
        // Update marker appearance based on operational status
        if (_operational) then {
            _markerName setMarkerAlpha 1;
        } else {
            _markerName setMarkerAlpha 0.5;
            _markerName setMarkerColor "ColorGrey";
            private _text = markerText _markerName;
            _markerName setMarkerText format ["%1 [DESTROYED]", _text];
        };
        
        diag_log format ["[TWS] Updated marker %1 operational status: %2", _markerName, _operational];
    };
    
    // Function to create all object markers at mission start
    TWS_fnc_createAllObjectMarkers = {
        private _count = 0;
        
        // Iterate through all registered objects
        {
            private _objectKey = _x;
            private _roleData = _y;
            
            private _object = _roleData getOrDefault ["object", objNull];
            private _role = _roleData getOrDefault ["role", ""];
            private _faction = _roleData getOrDefault ["faction", "NONE"];
            
            if (!isNull _object && _role != "" && _faction != "NONE") then {
                [_object, _role, _faction] call TWS_fnc_createObjectMarker;
                _count = _count + 1;
            };
        } forEach TWS_objectRoles;
        
        systemChat format ["[TWS] Created %1 strategic object markers", _count];
        diag_log format ["[TWS] Created %1 strategic object markers at mission start", _count];
        
        _count
    };
    
    // Function to create fading event marker
    TWS_fnc_createEventMarker = {
        params ["_position", "_text", "_color", ["_fadeTime", 300]];
        
        private _markerName = format ["tws_event_%1", diag_tickTime];
        
        private _marker = createMarker [_markerName, _position];
        _marker setMarkerType "mil_dot";
        _marker setMarkerColor _color;
        _marker setMarkerText _text;
        _marker setMarkerAlpha 1;
        
        // Store event marker
        private _eventMarkers = TWS_markers get "eventMarkers";
        _eventMarkers pushBack _markerName;
        
        // Schedule marker deletion
        [_markerName, _fadeTime] spawn {
            params ["_markerName", "_fadeTime"];
            
            // Fade out over time
            private _fadeStep = _fadeTime / 10;
            for "_i" from 10 to 0 step -1 do {
                _markerName setMarkerAlpha (_i / 10);
                sleep _fadeStep;
            };
            
            // Delete marker
            deleteMarker _markerName;
            
            // Remove from tracking
            private _eventMarkers = TWS_markers get "eventMarkers";
            _eventMarkers = _eventMarkers - [_markerName];
            TWS_markers set ["eventMarkers", _eventMarkers];
        };
        
        _markerName
    };
    
    // Function to create combat marker (for troops in contact)
    TWS_fnc_createCombatMarker = {
        params ["_position", "_squad", "_faction", ["_fadeTime", 300]];
        
        private _markerName = format ["tws_combat_%1", diag_tickTime];
        
        private _color = if (_faction == "OPFOR") then {"ColorRed"} else {"ColorBlue"};
        
        private _marker = createMarker [_markerName, _position];
        _marker setMarkerType "mil_warning";
        _marker setMarkerColor _color;
        _marker setMarkerText format ["Contact: %1", _squad];
        _marker setMarkerAlpha 1;
        
        // Store combat marker
        private _combatMarkers = TWS_markers get "combatMarkers";
        _combatMarkers pushBack [_markerName, _position, _squad, _faction, diag_tickTime];
        
        // Schedule marker deletion
        [_markerName, _fadeTime] spawn {
            params ["_markerName", "_fadeTime"];
            sleep _fadeTime;
            deleteMarker _markerName;
            
            // Remove from tracking
            private _combatMarkers = TWS_markers get "combatMarkers";
            _combatMarkers = _combatMarkers select {(_x select 0) != _markerName};
            TWS_markers set ["combatMarkers", _combatMarkers];
        };
        
        _markerName
    };
    
    // Function to get all markers by type
    TWS_fnc_getMarkersByType = {
        params ["_type"];
        
        switch (_type) do {
            case "object": {TWS_markers get "objectMarkers"};
            case "event": {TWS_markers get "eventMarkers"};
            case "combat": {TWS_markers get "combatMarkers"};
            default {createHashMap};
        };
    };
    
    // Make public
    publicVariable "TWS_markers";
    publicVariable "TWS_markerConfig";
    publicVariable "TWS_fnc_createObjectMarker";
    publicVariable "TWS_fnc_updateObjectMarker";
    publicVariable "TWS_fnc_createAllObjectMarkers";
    publicVariable "TWS_fnc_createEventMarker";
    publicVariable "TWS_fnc_createCombatMarker";
    publicVariable "TWS_fnc_getMarkersByType";
    
    systemChat "[TWS] Marker system initialized";
    diag_log "[TWS] Marker system initialized";
};
