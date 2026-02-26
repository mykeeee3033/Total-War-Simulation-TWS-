// Waypoint context menu dialog
class mymod_waypointContextMenu {
    idd = 9500;
    movingEnabled = 1;
    enableSimulation = 1;
    
    class ControlsBackground {
        class Background: RscText {
            idc = -1;
            x = 0.38;
            y = 0.35;
            w = 0.24;
            h = 0.32;
            colorBackground[] = {0, 0, 0, 0.8};
            colorBorder[] = {1, 1, 1, 1};
            borderSize = 0.002;
        };
    };
    
    class Controls {
        class TitleText: RscText {
            idc = -1;
            x = 0.38;
            y = 0.35;
            w = 0.24;
            h = 0.035;
            text = "Waypoint Options";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.04;
            shadow = 0;
        };

        class TypeList: RscListbox {
            idc = 9503;
            x = 0.385;
            y = 0.39;
            w = 0.23;
            h = 0.14;
            colorBackground[] = {0.1, 0.1, 0.1, 0.8};
            sizeEx = 0.035;
            rowHeight = 0.04;
        };

        class SetTypeButton: RscButton {
            idc = 9504;
            x = 0.385;
            y = 0.54;
            w = 0.23;
            h = 0.035;
            text = "Set Type";
            colorBackground[] = {0, 0.4, 0.6, 0.8};
            colorBackgroundActive[] = {0, 0.6, 0.8, 1};
            sizeEx = 0.04;
            action = "[] call mymod_fnc_setWaypointTypeFromMenu;";
        };

        class LinkButton: RscButton {
            idc = 9505;
            x = 0.385;
            y = 0.58;
            w = 0.23;
            h = 0.035;
            text = "Link Waypoint";
            colorBackground[] = {0.4, 0.3, 0.7, 0.8};
            colorBackgroundActive[] = {0.6, 0.5, 0.9, 1};
            sizeEx = 0.04;
            action = "[] call mymod_fnc_startWaypointLink; closeDialog 0;";
        };
        
        class DeleteButton: RscButton {
            idc = 9501;
            x = 0.385;
            y = 0.62;
            w = 0.23;
            h = 0.035;
            text = "Delete Waypoint";
            colorBackground[] = {0.6, 0, 0, 0.8};
            colorBackgroundActive[] = {0.8, 0.2, 0.2, 1};
            colorBackgroundDisabled[] = {0.3, 0.3, 0.3, 0.5};
            colorFocused[] = {0.8, 0.2, 0.2, 1};
            colorShadow[] = {0, 0, 0, 0.5};
            colorBorder[] = {1, 1, 1, 0.5};
            sizeEx = 0.04;
            shadow = 0;
            borderSize = 0.002;
            action = "[] call mymod_fnc_deleteWaypointFromMenu; closeDialog 0;";
        };
        
        class CancelButton: RscButton {
            idc = 9502;
            x = 0.385;
            y = 0.66;
            w = 0.23;
            h = 0.035;
            text = "Cancel";
            colorBackground[] = {0.2, 0.2, 0.2, 0.8};
            colorBackgroundActive[] = {0.3, 0.3, 0.3, 1};
            colorBackgroundDisabled[] = {0.3, 0.3, 0.3, 0.5};
            colorFocused[] = {0.3, 0.3, 0.3, 1};
            colorShadow[] = {0, 0, 0, 0.5};
            colorBorder[] = {1, 1, 1, 0.5};
            sizeEx = 0.04;
            shadow = 0;
            borderSize = 0.002;
            action = "[] call mymod_fnc_closeWaypointContextMenu; closeDialog 0;";
        };
    };
};
