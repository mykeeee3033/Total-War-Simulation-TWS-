// Standalone dialog that can be opened with createDialog
class MyMapDialog
{
    idd = 9000;
    movingEnable = 0;
    enableSimulation = 1;
    
    class controls
    {
        // Background
        class MyBackground
        {
            idc = -1;
            type = 0;
            style = 0;
            x = 0.3;
            y = 0.3;
            w = 0.4;
            h = 0.4;
            colorBackground[] = {0, 0, 0, 0.7};
        };
        
        // Title text
        class MyTitle
        {
            idc = -1;
            type = 0;
            style = 2;
            text = "Test Dialog Window";
            x = 0.3;
            y = 0.3;
            w = 0.4;
            h = 0.05;
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.04;
        };
        
        // Test button
        class MyButton
        {
            idc = 9001;
            type = 1;
            style = 2;
            text = "Test Button";
            x = 0.35;
            y = 0.4;
            w = 0.3;
            h = 0.05;
            action = "hint 'Button Pressed from Mod!';";
            colorBackground[] = {0, 0.5, 0, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };
        
        // Another test button
        class MyButton2
        {
            idc = 9002;
            type = 1;
            style = 2;
            text = "Call SQF Function";
            x = 0.35;
            y = 0.47;
            w = 0.3;
            h = 0.05;
            action = "[] call mymod_fnc_testFunction;";
            colorBackground[] = {0, 0, 0.5, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };
        
        // Close button
        class MyCloseButton
        {
            idc = 9003;
            type = 1;
            style = 2;
            text = "Close";
            x = 0.35;
            y = 0.6;
            w = 0.3;
            h = 0.05;
            action = "closeDialog 9000;";
            colorBackground[] = {0.5, 0, 0, 1};
            colorText[] = {1, 1, 1, 1};
            sizeEx = 0.035;
        };
    };
};
