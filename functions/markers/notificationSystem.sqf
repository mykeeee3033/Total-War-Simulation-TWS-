/*
 * notificationSystem.sqf
 * Comprehensive Event Notification System
 * 
 * Features:
 * - Notifications for training, resupply, orders, sector changes
 * - Event markers that fade over time
 * - Centralized notification management
 * - Debug and tracking capabilities
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState"};
    
    diag_log "[TWS] Initializing notification system...";
    systemChat "[TWS] Initializing notification system...";
    
    // Notification tracking
    TWS_notifications = createHashMap;
    TWS_notifications set ["history", []];
    TWS_notifications set ["enabled", true];
    TWS_notifications set ["showMarkers", true];
    TWS_notifications set ["count", 0];
    
    // Event types and their marker colors
    TWS_eventTypes = createHashMap;
    TWS_eventTypes set ["training", "ColorGreen"];
    TWS_eventTypes set ["resupply", "ColorYellow"];
    TWS_eventTypes set ["orders", "ColorBlue"];
    TWS_eventTypes set ["sectorChange", "ColorOrange"];
    TWS_eventTypes set ["production", "ColorPurple"];
    TWS_eventTypes set ["reinforcement", "ColorRed"];
    TWS_eventTypes set ["combat", "ColorRed"];
    TWS_eventTypes set ["general", "ColorWhite"];
    
    // Function to send notification
    TWS_fnc_notify = {
        params ["_type", "_message", ["_position", [0,0,0]], ["_createMarker", true], ["_markerFadeTime", 300]];
        
        if (!(TWS_notifications get "enabled")) exitWith {};
        
        // Increment counter
        private _count = (TWS_notifications get "count") + 1;
        TWS_notifications set ["count", _count];
        
        // Create notification record
        private _notification = createHashMap;
        _notification set ["type", _type];
        _notification set ["message", _message];
        _notification set ["position", _position];
        _notification set ["timestamp", diag_tickTime];
        _notification set ["gameTime", time];
        
        // Add to history
        private _history = TWS_notifications get "history";
        _history pushBack _notification;
        
        // Keep only last 100 notifications
        if (count _history > 100) then {
            _history deleteAt 0;
        };
        
        // Display notification
        private _displayMessage = format ["[TWS] %1: %2", _type, _message];
        systemChat _displayMessage;
        diag_log _displayMessage;
        
        // Create marker if requested and position is valid
        if (_createMarker && (TWS_notifications get "showMarkers") && !(_position isEqualTo [0,0,0])) then {
            private _color = TWS_eventTypes getOrDefault [_type, "ColorWhite"];
            [_position, _message, _color, _markerFadeTime] call TWS_fnc_createEventMarker;
        };
        
        diag_log format ["[TWS] Notification #%1: [%2] %3", _count, _type, _message];
    };
    
    // Function to notify training event
    TWS_fnc_notifyTraining = {
        params ["_faction", "_position", "_type"];
        
        private _message = format ["%1 training started: %2", _faction, _type];
        ["training", _message, _position, true] call TWS_fnc_notify;
    };
    
    // Function to notify resupply event
    TWS_fnc_notifyResupply = {
        params ["_faction", "_position", "_resourceType", "_amount"];
        
        private _message = format ["%1 resupply: +%2 %3", _faction, _amount, _resourceType];
        ["resupply", _message, _position, true] call TWS_fnc_notify;
    };
    
    // Function to notify order execution
    TWS_fnc_notifyOrderExecution = {
        params ["_faction", "_orderType", "_target"];
        
        private _message = format ["%1 executing order: %2 -> %3", _faction, _orderType, _target];
        ["orders", _message, _target, true] call TWS_fnc_notify;
    };
    
    // Function to notify sector change
    TWS_fnc_notifySectorChange = {
        params ["_sectorName", "_oldState", "_newState", "_position"];
        
        private _message = format ["Sector %1: %2 -> %3", _sectorName, _oldState, _newState];
        ["sectorChange", _message, _position, true, 600] call TWS_fnc_notify; // 10 minute fade
    };
    
    // Function to notify production event
    TWS_fnc_notifyProduction = {
        params ["_faction", "_vehicleType", "_count", "_position"];
        
        private _message = format ["%1 produced: %2x %3", _faction, _count, _vehicleType];
        ["production", _message, _position, true] call TWS_fnc_notify;
    };
    
    // Function to notify reinforcement deployment
    TWS_fnc_notifyReinforcement = {
        params ["_faction", "_position", "_unitCount"];
        
        private _message = format ["%1 reinforcements: %2 units deploying", _faction, _unitCount];
        ["reinforcement", _message, _position, true] call TWS_fnc_notify;
    };
    
    // Function to notify combat event
    TWS_fnc_notifyCombat = {
        params ["_faction", "_position", "_eventType", "_details"];
        
        private _message = format ["%1 %2: %3", _faction, _eventType, _details];
        ["combat", _message, _position, true, 180] call TWS_fnc_notify; // 3 minute fade
    };
    
    // Function to get notification history
    TWS_fnc_getNotificationHistory = {
        params [["_type", ""], ["_count", 10]];
        
        private _history = TWS_notifications get "history";
        
        if (_type == "") then {
            // Return last N notifications
            private _start = (count _history) - _count max 0;
            _history select [_start, _count]
        } else {
            // Filter by type and return last N
            private _filtered = _history select {(_x get "type") == _type};
            private _start = (count _filtered) - _count max 0;
            _filtered select [_start, _count]
        };
    };
    
    // Function to toggle notifications
    TWS_fnc_toggleNotifications = {
        params ["_enable"];
        
        TWS_notifications set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Notifications enabled";
        } else {
            systemChat "[TWS] Notifications disabled";
        };
    };
    
    // Function to toggle notification markers
    TWS_fnc_toggleNotificationMarkers = {
        params ["_enable"];
        
        TWS_notifications set ["showMarkers", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Notification markers enabled";
        } else {
            systemChat "[TWS] Notification markers disabled";
        };
    };
    
    // Function to clear notification history
    TWS_fnc_clearNotificationHistory = {
        TWS_notifications set ["history", []];
        TWS_notifications set ["count", 0];
        systemChat "[TWS] Notification history cleared";
    };
    
    // Make public
    publicVariable "TWS_notifications";
    publicVariable "TWS_eventTypes";
    publicVariable "TWS_fnc_notify";
    publicVariable "TWS_fnc_notifyTraining";
    publicVariable "TWS_fnc_notifyResupply";
    publicVariable "TWS_fnc_notifyOrderExecution";
    publicVariable "TWS_fnc_notifySectorChange";
    publicVariable "TWS_fnc_notifyProduction";
    publicVariable "TWS_fnc_notifyReinforcement";
    publicVariable "TWS_fnc_notifyCombat";
    publicVariable "TWS_fnc_getNotificationHistory";
    publicVariable "TWS_fnc_toggleNotifications";
    publicVariable "TWS_fnc_toggleNotificationMarkers";
    publicVariable "TWS_fnc_clearNotificationHistory";
    
    systemChat "[TWS] Notification system initialized";
    diag_log "[TWS] Notification system initialized";
};
