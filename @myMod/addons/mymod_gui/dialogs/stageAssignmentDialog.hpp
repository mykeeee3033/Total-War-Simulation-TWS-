// Stage assignment dialog - shown when right-clicking a squad
class mymod_stageAssignmentDialog {
    idd = 9600;
    movingEnabled = 1;
    enableSimulation = 1;
    
    class ControlsBackground {
        class Background: RscText {
            idc = -1;
            x = 0.35;
            y = 0.3;
            w = 0.3;
            h = 0.4;
            colorBackground[] = {0, 0, 0, 0.8};
            colorBorder[] = {1, 1, 1, 1};
            borderSize = 0.002;
        };
    };
    
    class Controls {
        class TitleText: RscText {
            idc = -1;
            x = 0.35;
            y = 0.3;
            w = 0.3;
            h = 0.04;
            text = "Assign Squad to Stage";
            colorBackground[] = {0.3, 0.2, 0.4, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.04;
            shadow = 0;
        };
        
        class StageListbox: RscListbox {
            idc = 9601;
            x = 0.355;
            y = 0.35;
            w = 0.29;
            h = 0.3;
            colorBackground[] = {0.1, 0.1, 0.1, 0.8};
            sizeEx = 0.035;
            rowHeight = 0.04;
            onLBSelChanged = "[_this select 1] call mymod_fnc_onStageSelected";
        };
        
        class AssignButton: RscButton {
            idc = 9602;
            x = 0.355;
            y = 0.66;
            w = 0.14;
            h = 0.035;
            text = "Assign";
            colorBackground[] = {0, 0.6, 0, 0.8};
            colorBackgroundActive[] = {0, 0.8, 0.2, 1};
            sizeEx = 0.04;
            action = "[] call mymod_fnc_confirmStageAssignment; closeDialog 0;";
        };
        
        class CancelButton: RscButton {
            idc = 9603;
            x = 0.505;
            y = 0.66;
            w = 0.14;
            h = 0.035;
            text = "Cancel";
            colorBackground[] = {0.4, 0.4, 0.4, 0.8};
            colorBackgroundActive[] = {0.5, 0.5, 0.5, 1};
            sizeEx = 0.04;
            action = "closeDialog 0;";
        };
    };
};
