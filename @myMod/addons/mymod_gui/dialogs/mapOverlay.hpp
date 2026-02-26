// Map overlay - adds controls to the main map display
// Shows a list of all units on the left side of the map

class RscDisplayMainMap
{
    onLoad = "[] spawn mymod_fnc_initMapUnitList;";
    
    class controls
    {
        // Background panel for the unit list
        class UnitListBackground
        {
            idc = -1;
            type = 0;
            style = 0;
            x = 0.01;
            y = 0.05;
            w = 0.22;
            h = 0.9;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        
        // Title bar
        class UnitListTitle
        {
            idc = -1;
            type = 0;
            style = 2;
            text = "UNITS IN SCENARIO";
            x = 0.01;
            y = 0.05;
            w = 0.22;
            h = 0.04;
            colorBackground[] = {0.2, 0.3, 0.4, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };
        
        // Listbox showing all units
        class UnitListBox
        {
            idc = 9200;
            type = 5;
            style = 16;
            x = 0.01;
            y = 0.1;
            w = 0.22;
            h = 0.75;
            rowHeight = 0.03;
            colorBackground[] = {0.1, 0.1, 0.1, 0.8};
            colorSelectBackground[] = {0.3, 0.3, 0.3, 1};
            colorText[] = {1, 1, 1, 1};
            colorSelect[] = {1, 1, 0, 1};
            sizeEx = 0.03;
            font = "PuristaMedium";
            maxHistoryDelay = 1;
            autoScrollSpeed = -1;
            autoScrollDelay = 5;
            autoScrollRewind = 0;
            onLBSelChanged = "[] call mymod_fnc_onUnitSelected;";
        };
        
        // Refresh button
        class RefreshButton
        {
            idc = 9201;
            type = 1;
            style = 2;
            text = "REFRESH";
            x = 0.01;
            y = 0.86;
            w = 0.11;
            h = 0.04;
            action = "[] call mymod_fnc_refreshUnitList;";
            colorBackground[] = {0, 0.4, 0, 0.8};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.03;
        };
        
        // Center on Unit button
        class CenterButton
        {
            idc = 9202;
            type = 1;
            style = 2;
            text = "CENTER";
            x = 0.12;
            y = 0.86;
            w = 0.11;
            h = 0.04;
            action = "[] call mymod_fnc_centerOnSelectedUnit;";
            colorBackground[] = {0, 0.3, 0.5, 0.8};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.03;
        };
        
        // Status text at bottom
        class StatusText
        {
            idc = 9203;
            type = 0;
            style = 0;
            x = 0.01;
            y = 0.91;
            w = 0.22;
            h = 0.03;
            colorBackground[] = {0, 0, 0, 0};
            colorText[] = {0.7, 0.7, 0.7, 1};
            text = "Loading units...";
            sizeEx = 0.025;
        };
    };
};
