// Main config for mymod_gui addon
class CfgPatches
{
    class mymod_gui
    {
        units[] = {};
        weapons[] = {};
        requiredVersion = 1.0;
        requiredAddons[] = {};
        author = "Your Name";
        name = "My Mod - GUI";
    };
};

// Include the standalone dialog
#include "dialogs\myMapDialog.hpp"

// Include the map overlay (extends the main map display)
#include "dialogs\mapOverlay.hpp"
