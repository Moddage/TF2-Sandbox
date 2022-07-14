/*
	This file is part of TF2 Sandbox.
	
	TF2 Sandbox is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    TF2 Sandbox is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TF2 Sandbox.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <clientprefs>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>
#include <build_stocks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <vphysics>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#tryinclude <tf2idb>
#tryinclude <tf2items_giveweapon>
#tryinclude <rtd2>
#define REQUIRE_PLUGIN
#tryinclude <advancedinfiniteammo>

#define UPDATE_URL ""

#if BUILDMODAPI_VER < 3
#error "build.inc is outdated. please update before compiling"
#endif

#pragma newdecls required

int LastUsed[MAXPLAYERS + 1];

Handle g_hMenuCredits;

Handle g_hCookieSDoorTarget;
Handle g_hCookieSDoorModel;

Handle g_hPropNameArray;
Handle g_hPropModelPathArray;
Handle g_hPropTypeArray;
Handle g_hPropStringArray;
Handle g_hPropNameArrayDonor;
Handle g_hPropModelPathArrayDonor;
Handle g_hPropTypeArrayDonor;
Handle g_hPropStringArrayDonor;
char g_szFile[128];

char g_szConnectedClient[32][MAXPLAYERS];
//char g_szDisconnectClient[32][MAXPLAYERS];
int g_iTempOwner[MAX_HOOK_ENTITIES] =  { -1, ... };

bool g_bGodmode[MAXPLAYERS];
bool g_bBuddha[MAXPLAYERS];

#define EFL_NO_PHYSCANNON_INTERACTION (1<<30)


int g_iCopyTarget[MAXPLAYERS];
float g_fCopyPlayerOrigin[MAXPLAYERS][3];
bool g_bCopyIsRunning[MAXPLAYERS] = false;

bool g_bBuffer[MAXPLAYERS + 1];

Handle g_hMainMenu = INVALID_HANDLE;
Handle g_hPropMenu = INVALID_HANDLE;
Handle g_hEquipMenu = INVALID_HANDLE;
Handle g_hPoseMenu = INVALID_HANDLE;
Handle g_hPlayerStuff = INVALID_HANDLE;
Handle g_hCondMenu = INVALID_HANDLE;
Handle g_hModelMenu = INVALID_HANDLE;
Handle g_hHealthMenu = INVALID_HANDLE;
Handle g_hDSPMenu = INVALID_HANDLE;
Handle g_hSizeMenu = INVALID_HANDLE;
// Handle g_hRemoveMenu = INVALID_HANDLE;
Handle g_hBuildHelperMenu = INVALID_HANDLE;
Handle g_hPropMenuComic = INVALID_HANDLE;
Handle g_hPropMenuConstructions = INVALID_HANDLE;
Handle g_hPropMenuWeapons = INVALID_HANDLE;
Handle g_hPropMenuCosmetics = INVALID_HANDLE;
Handle g_hPropMenuPickup = INVALID_HANDLE;
Handle g_hPropMenuLead = INVALID_HANDLE;
Handle g_hPropMenuHL2 = INVALID_HANDLE;
Handle g_hPropMenuDonor = INVALID_HANDLE;
Handle g_hPropMenuRequested = INVALID_HANDLE;

char CopyableProps[][] =  {
	"prop_dynamic", 
	"prop_dynamic_override", 
	"5", 
	"func_physbox", 
	"player"
};

char DelClass[][] =  {
	"npc_", 
	"Npc_", 
	"NPC_", 
	"prop_", 
	"Prop_", 
	"PROP_", 
	"func_", 
	"Func_", 
	"FUNC_", 
	"item_", 
	"Item_", 
	"ITEM_", 
	"gib"
};

// grabber can suck a dick!

float nextactivetime[MAXPLAYERS + 1];

//int g_iBeam;
//int g_iHalo;
//int g_iLaser;
//int g_iPhys;

public Plugin myinfo = 
{
	name = "Team Fortress 2 Sandbox", 
	author = "TF2SB Studio", 
	description = "The base gamemode plugin of Team Fortress 2 Sandbox. Includes all base Sandbox modules in one plugin.", 
	version = BUILDMOD_VER, 
	url = "https://sandbox.moddage.site/"
};

public void OnPluginStart()
{
	// cvars
	SetConVarInt(FindConVar("mp_waitingforplayers_time"), 0);
	SetConVarInt(FindConVar("tf_avoidteammates"), 0);
	SetConVarInt(FindConVar("tf_allow_player_use"), 1);

	// blacklist
	RegAdminCmd("sm_bl", Command_AddBL, ADMFLAG_CONVARS, "Add clients to the blacklist");
	RegAdminCmd("sm_unbl", Command_RemoveBL, ADMFLAG_CONVARS, "Remove clients from the blacklist");

	// disable exploits
	SetCommandFlags("explode", GetCommandFlags("setpos"));
	
	// disable cheat flags
	SetCommandFlags("noclip", GetCommandFlags("kill")); // TODO: Don't use kill for this
	SetCommandFlags("god", GetCommandFlags("kill"));
	SetCommandFlags("buddha", GetCommandFlags("kill"));

	// command hooks
	RegConsoleCmd("kill", Command_kill, "");
	RegConsoleCmd("noclip", Command_Fly, "");
	RegConsoleCmd("god", Command_ChangeGodMode, "");
	
	// spawn props
	RegAdminCmd("sm_spawnprop", Command_SpawnProp, 0, "Spawn a prop in command list!");
	RegAdminCmd("sm_prop", Command_SpawnProp, 0, "Spawn props in command list, too!");
	
	// coloring, skins, scale
	RegAdminCmd("sm_color", Command_Color, 0, "Color a prop.");
	RegAdminCmd("sm_colour", Command_Color, 0, "Colour a prop.");
	RegAdminCmd("sm_render", Command_Render, 0, "Render an entity.");
	RegAdminCmd("sm_skin", Command_Skin, 0, "Color a prop.");
	RegAdminCmd("sm_propscale", Command_PropScale, 0, "Prop Scale");
	
	// building
	RegAdminCmd("sm_build", Command_BuildMenu, 0);
	RegAdminCmd("sm_sandbox", Command_BuildMenu, 0);
	RegAdminCmd("sm_propfinder", Command_PropFinder, 0);
	RegAdminCmd("sm_delall", Command_DeleteAll, 0, "Delete all of your spawned props");
	RegAdminCmd("sm_del", Command_Delete, 0, "Delete a entity");
	RegAdminCmd("sm_setname", Command_SetName, 0, "Set the name of a prop");
	RegAdminCmd("sm_sdoor", Command_SpawnDoor, 0, "Scripted Door");
	RegAdminCmd("sm_ld", Command_LightDynamic, 0, "Dynamic Light");
	RegAdminCmd("sm_simplelight", Command_LightDynamic, 0, "Dynamic Light");
	RegAdminCmd("sm_propdoor", Command_OpenableDoorProp, 0, "Half-Life 2 Door");
	RegAdminCmd("sm_rotate", Command_Rotate, 0, "Rotate an entity");
	RegAdminCmd("sm_r", Command_Rotate, 0, "Rotate an entity");
	RegAdminCmd("sm_accuraterotate", Command_AccurateRotate, 0, "Accurate rotate a prop");
	RegAdminCmd("sm_ar", Command_AccurateRotate, 0, "Accurate rotate a prop.");
	RegAdminCmd("sm_move", Command_Move, 0, "Move a prop to a position.");
	RegAdminCmd("+copy", Command_Copy, 0, "Copy a prop");
	RegAdminCmd("-copy", Command_Paste, 0, "Stop Copying a Prop");
	
	// player commands
	RegAdminCmd("sm_god", Command_ChangeGodMode, 0, "Turn Godmode On/Off");
	RegAdminCmd("sm_buddha", Command_ChangeBuddha, 0, "Turn Buddha On/Off");
	RegAdminCmd("sm_addhealth", Command_Health, 0, "Add onto your max health");
	RegAdminCmd("sm_resupply", Command_Resupply, 0);
	RegAdminCmd("sm_fly", Command_Fly, 0, "Noclip");

	// admin commands
	RegAdminCmd("sm_fda", ClientRemoveAll, ADMFLAG_SLAY);

	// Half-life 2 default props
	g_hPropMenuHL2 = CreateMenu(PropMenuHL2);
	SetMenuTitle(g_hPropMenuHL2, /*"TF2SB - */ "Miscellaneous"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuHL2, true);
	AddMenuItem(g_hPropMenuHL2, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuHL2, "blank", "", ITEMDRAW_IGNORE);

	// props-extended.ini
	g_hPropMenuDonor = CreateMenu(PropMenuDonor);
	SetMenuTitle(g_hPropMenuDonor, /*"TF2SB - */ "Donator \nKeep in mind some of these props may not be removable!");
	SetMenuExitBackButton(g_hPropMenuDonor, true);
	AddMenuItem(g_hPropMenuDonor, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuDonor, "blank", "", ITEMDRAW_IGNORE);
	
	// arrays, cookies
	g_hCookieSDoorTarget = RegClientCookie("cookie_SDoorTarget", "For SDoor.", CookieAccess_Private); // TODO: Don't fucking do this dumb shit.
	g_hCookieSDoorModel = RegClientCookie("cookie_SDoorModel", "For SDoor.", CookieAccess_Private);
	g_hPropNameArray = CreateArray(33, 4064); // Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 4064); // Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 4064); // Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 4064);
	g_hPropNameArrayDonor = CreateArray(33, 4064); // Max Prop List is 1024-->2048
	g_hPropModelPathArrayDonor = CreateArray(128, 4064); // Max Prop List is 1024-->2048
	g_hPropTypeArrayDonor = CreateArray(33, 4064); // Max Prop List is 1024-->2048
	g_hPropStringArrayDonor = CreateArray(256, 4064);

	// read props.ini and props-extended.ini
	ReadProps(false, "configs/buildmod/props.ini");
	ReadProps(true, "configs/buildmod/props-extended.ini");
	
	// godmode on spawn
	HookEvent("player_spawn", Event_Spawn);

	// translations
	LoadTranslations("common.phrases");
	LoadTranslations("tf2sandbox.phrases");

	CreateTimer(0.1, Display_Msgs, 0, TIMER_REPEAT);

	// disallow breaking props
	HookEntityOutput("prop_physics_respawnable", "OnBreak", OnPropBreak);
	
	// tf2 buildables
	HookEvent("player_builtobject", Event_player_builtobject);
	
	// main menu
	g_hMainMenu = CreateMenu(MainMenu);
	SetMenuTitle(g_hMainMenu, "Team Fortress 2 Sandbox");
	AddMenuItem(g_hMainMenu, "spawnlist", "Spawn Props");
	AddMenuItem(g_hMainMenu, "equipmenu", "Equip Weapons");
	AddMenuItem(g_hMainMenu, "playerstuff", "Player Conditions");
	
	// player menu
	g_hPlayerStuff = CreateMenu(PlayerStuff);
	SetMenuTitle(g_hPlayerStuff, /*"TF2SB - */ "Player Conditions");
	AddMenuItem(g_hPlayerStuff, "cond", "Addcond");
	AddMenuItem(g_hPlayerStuff, "sizes", "Sizes");
	AddMenuItem(g_hPlayerStuff, "poser", "Player Poser");
	AddMenuItem(g_hPlayerStuff, "health", "Health");
	AddMenuItem(g_hPlayerStuff, "model", "Model");
	AddMenuItem(g_hPlayerStuff, "pitch", "Voice");
	SetMenuExitBackButton(g_hPlayerStuff, true);
	
	// build helper
	g_hBuildHelperMenu = CreateMenu(BuildHelperMenu);
	SetMenuTitle(g_hBuildHelperMenu, /*"TF2SB - */ "Build Helper"); // \nType /toolgun for toolgun\nThis menu was here because not all features are in ToolGun.");
	AddMenuItem(g_hBuildHelperMenu, "delprop", "| Delete");
	AddMenuItem(g_hBuildHelperMenu, "colors", "Color (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "effects", "Effects (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "skin", "Skin (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "rotate", "Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "accuraterotate", "Accurate Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "doors", "Doors (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "lights", "Lights (see chat)");
	
	// conditions
	g_hCondMenu = CreateMenu(CondMenu);
	SetMenuTitle(g_hCondMenu, /*"TF2SB - */ "Addcond List");
	AddMenuItem(g_hCondMenu, "godmode", "Godmode");
	AddMenuItem(g_hCondMenu, "crits", "Crits");
	AddMenuItem(g_hCondMenu, "noclip", "Noclip");
	#if defined _AdvancedInfiniteAmmo_included
		AddMenuItem(g_hCondMenu, "infammo", "Inf. Ammo");
	#endif
	AddMenuItem(g_hCondMenu, "speedboost", "Speed Boost");
	AddMenuItem(g_hCondMenu, "resupply", "Resupply");
	AddMenuItem(g_hCondMenu, "buddha", "Buddha");
	AddMenuItem(g_hCondMenu, "removeweps", "Remove Weapons");
	AddMenuItem(g_hCondMenu, "minicrits", "Mini-Crits");
	#if defined _rtd2_included
		AddMenuItem(g_hCondMenu, "drugged", "Drugged");
		AddMenuItem(g_hCondMenu, "funnyfeeling", "Funny Feeling");
		AddMenuItem(g_hCondMenu, "frozen", "Frozen");
		AddMenuItem(g_hCondMenu, "toxic", "Toxic");
		AddMenuItem(g_hCondMenu, "drunkwalk", "Drunk Walk");
		AddMenuItem(g_hCondMenu, "monochromia", "Monochromia");
		AddMenuItem(g_hCondMenu, "mercsdietwice", "Mercs Die Twice");
		AddMenuItem(g_hCondMenu, "springshoes", "Spring Shoes");
		AddMenuItem(g_hCondMenu, "lowgravity", "Low Gravity");
		AddMenuItem(g_hCondMenu, "strongrecoil", "Strong Recoil");
		AddMenuItem(g_hCondMenu, "lag", "Lag");
		AddMenuItem(g_hCondMenu, "inclineproblem", "Incline Problem");
		AddMenuItem(g_hCondMenu, "sickness", "Sickness");
	#endif
	SetMenuExitBackButton(g_hCondMenu, true);

	// model
	g_hModelMenu = CreateMenu(ModelMenu);
	SetMenuTitle(g_hModelMenu, /*"TF2SB - */ "Set Model");
	AddMenuItem(g_hModelMenu, "0", "None");
	AddMenuItem(g_hModelMenu, "models/player/scout.mdl", "Scout");
	AddMenuItem(g_hModelMenu, "models/player/soldier.mdl", "Soldier");
	AddMenuItem(g_hModelMenu, "models/player/pyro.mdl", "Pyro");
	AddMenuItem(g_hModelMenu, "models/player/engineer.mdl", "Engineer");
	AddMenuItem(g_hModelMenu, "models/player/heavy.mdl", "Heavy");
	AddMenuItem(g_hModelMenu, "models/player/demo.mdl", "Demoman");
	AddMenuItem(g_hModelMenu, "models/player/medic.mdl", "Medic");
	AddMenuItem(g_hModelMenu, "models/player/sniper.mdl", "Sniper");
	AddMenuItem(g_hModelMenu, "models/player/spy.mdl", "Spy");
	AddMenuItem(g_hModelMenu, "models/bots/headless_hatman.mdl", "HHH");
	AddMenuItem(g_hModelMenu, "models/bots/skeleton_sniper/skeleton_sniper.mdl", "Skeleton");
	SetMenuExitBackButton(g_hModelMenu, true);

	// TODO: Bonemerge

	// voice fx
	g_hHealthMenu = CreateMenu(HealthMenu);
	SetMenuTitle(g_hHealthMenu, /*"TF2SB - */ "Health");
	AddMenuItem(g_hHealthMenu, "-300", "-300");
	AddMenuItem(g_hHealthMenu, "-200", "-200");
	AddMenuItem(g_hHealthMenu, "-100", "-100");
	AddMenuItem(g_hHealthMenu, "0", "None");
	AddMenuItem(g_hHealthMenu, "100", "+100");
	AddMenuItem(g_hHealthMenu, "200", "+200");
	AddMenuItem(g_hHealthMenu, "300", "+300");
	SetMenuExitBackButton(g_hHealthMenu, true);

	// voice fx
	g_hDSPMenu = CreateMenu(DSPMenu);
	SetMenuTitle(g_hDSPMenu, /*"TF2SB - */ "Voice Effects");
	AddMenuItem(g_hDSPMenu, "0", "None");
	AddMenuItem(g_hDSPMenu, "20", "Echo");
	AddMenuItem(g_hDSPMenu, "23", "Blur");
	AddMenuItem(g_hDSPMenu, "30", "Quiet");
	AddMenuItem(g_hDSPMenu, "134", "Fly");
	AddMenuItem(g_hDSPMenu, "135", "Demon");
	AddMenuItem(g_hDSPMenu, "116", "Micspam");
	SetMenuExitBackButton(g_hDSPMenu, true);
	
	// equip menu
	g_hEquipMenu = CreateMenu(EquipMenu);
	SetMenuTitle(g_hEquipMenu, /*"TF2SB - */ "Equip Weapons");
	// CreateTimer(2.0, TF2SB_DelayedStuff);
	SetMenuExitBackButton(g_hEquipMenu, true);
	
	// poser menu
	g_hPoseMenu = CreateMenu(TF2SBPoseMenu);
	SetMenuTitle(g_hPoseMenu, /*"TF2SB - */ "Player Poser");
	AddMenuItem(g_hPoseMenu, "1", "-1x - Reversed");
	AddMenuItem(g_hPoseMenu, "2", "0x - Frozen");
	AddMenuItem(g_hPoseMenu, "3", "0.1x");
	AddMenuItem(g_hPoseMenu, "4", "0.25x");
	AddMenuItem(g_hPoseMenu, "5", "0.5x");
	AddMenuItem(g_hPoseMenu, "6", "1x - Normal");
	AddMenuItem(g_hPoseMenu, "7", "Untaunt");
	SetMenuExitBackButton(g_hPoseMenu, true);

	// size menu
	g_hSizeMenu = CreateMenu(TF2SBSizeMenu);
	SetMenuTitle(g_hSizeMenu, /*"TF2SB - */ "Player Sizes");
	AddMenuItem(g_hSizeMenu, "0.10", "0.10x");
	AddMenuItem(g_hSizeMenu, "0.25", "0.25x");
	AddMenuItem(g_hSizeMenu, "0.50", "0.50x");
	AddMenuItem(g_hSizeMenu, "0.75", "0.75x");
	AddMenuItem(g_hSizeMenu, "1.0", "1.0x");
	AddMenuItem(g_hSizeMenu, "1.25", "1.25x");
	AddMenuItem(g_hSizeMenu, "1.5", "1.5x");
	AddMenuItem(g_hSizeMenu, "1.75", "1.75x");
	AddMenuItem(g_hSizeMenu, "2.0", "2.0x");
	AddMenuItem(g_hSizeMenu, "2.25", "2.25x");
	AddMenuItem(g_hSizeMenu, "2.5", "2.5x");
	AddMenuItem(g_hSizeMenu, "2.75", "2.75x");
	AddMenuItem(g_hSizeMenu, "3.0", "3.0x");
	SetMenuExitBackButton(g_hSizeMenu, true);
	
	/*								 *\
	  ///					      \\\
	  ///    SPAWNLISTS BELOW!!   \\\
	  ///					      \\\
	\*								 */

	// Prop Menu INIT
	g_hPropMenu = CreateMenu(PropMenu);
	SetMenuTitle(g_hPropMenu, /*"TF2SB - */ "Spawn Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenu, true);

	// Requested
	g_hPropMenuRequested = CreateMenu(PropMenuRequested);
	SetMenuTitle(g_hPropMenuRequested, /*"TF2SB - */ "Requested Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuRequested, true);
	AddMenuItem(g_hPropMenuRequested, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuRequested, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuRequested, "scout", "Scout");
	AddMenuItem(g_hPropMenuRequested, "soldier", "Soldier");
	AddMenuItem(g_hPropMenuRequested, "pyro", "Pyro");
	AddMenuItem(g_hPropMenuRequested, "demoman", "Demoman");
	AddMenuItem(g_hPropMenuRequested, "heavy", "Heavy");
	AddMenuItem(g_hPropMenuRequested, "engineer", "Engineer");
	AddMenuItem(g_hPropMenuRequested, "sniper", "Sniper");
	AddMenuItem(g_hPropMenuRequested, "medic", "Medic");
	AddMenuItem(g_hPropMenuRequested, "spy", "Spy");
	AddMenuItem(g_hPropMenuRequested, "horseless", "Horseless Headless Horseman");
	AddMenuItem(g_hPropMenuRequested, "skeleton", "Skeleton");
	AddMenuItem(g_hPropMenuRequested, "sentrybuster", "Sentry Buster");
	AddMenuItem(g_hPropMenuRequested, "robotscout", "Robot Scout");
	AddMenuItem(g_hPropMenuRequested, "robotsoldier", "Robot Soldier");
	AddMenuItem(g_hPropMenuRequested, "robotpyro", "Robot Pyro");
	AddMenuItem(g_hPropMenuRequested, "robotdemoman", "Robot Demoman");
	AddMenuItem(g_hPropMenuRequested, "robotheavy", "Robot Heavy");
	AddMenuItem(g_hPropMenuRequested, "robotengineer", "Robot Engineer");
	AddMenuItem(g_hPropMenuRequested, "robotsniper", "Robot Sniper");
	AddMenuItem(g_hPropMenuRequested, "robotmedic", "Robot Medic");
	AddMenuItem(g_hPropMenuRequested, "robotspy", "Robot Spy");
	AddMenuItem(g_hPropMenuRequested, "cow", "Cow");
	AddMenuItem(g_hPropMenuRequested, "explosion", "Explosion");
	AddMenuItem(g_hPropMenuRequested, "muzzleflash", "Muzzleflash");
	AddMenuItem(g_hPropMenuRequested, "security_camera2", "Security Camera 2");	
	AddMenuItem(g_hPropMenuRequested, "tank", "Tank");
	AddMenuItem(g_hPropMenuRequested, "tank_track", "Tank Track");

	// Lead's Specialty Menu
	g_hPropMenuLead = CreateMenu(PropMenuLead);
	SetMenuTitle(g_hPropMenuLead, /*"TF2SB - */ "Special Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuLead, true);
	AddMenuItem(g_hPropMenuLead, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuLead, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuLead, "rickmay", "Rick May Statue");
	AddMenuItem(g_hPropMenuLead, "light", "Light");

	// Prop Menu Pickup
	g_hPropMenuPickup = CreateMenu(PropMenuPickup);
	SetMenuTitle(g_hPropMenuPickup, /*"TF2SB - */ "Pickup Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuPickup, true);
	AddMenuItem(g_hPropMenuPickup, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuPickup, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuPickup, "ammopack_large", "Ammo Pack Large");
	AddMenuItem(g_hPropMenuPickup, "ammopack_large_bday", "Ammo Pack Large Bday");
	AddMenuItem(g_hPropMenuPickup, "ammopack_medium", "Ammo Pack Medium");
	AddMenuItem(g_hPropMenuPickup, "ammopack_medium_bday", "Ammo Pack Medium Bday");
	AddMenuItem(g_hPropMenuPickup, "ammopack_small", "Ammo Pack Small");
	AddMenuItem(g_hPropMenuPickup, "ammopack_small_bday", "Ammo Pack Small Bday");
	AddMenuItem(g_hPropMenuPickup, "halloween_gift", "Big Gift");
	AddMenuItem(g_hPropMenuPickup, "intelbriefcase", "Briefcase");
	AddMenuItem(g_hPropMenuPickup, "currencypack_large", "Currency Pack Large");
	AddMenuItem(g_hPropMenuPickup, "currencypack_medium", "Currency Pack Medium");
	AddMenuItem(g_hPropMenuPickup, "currencypack_small", "Currency Pack Small");
	AddMenuItem(g_hPropMenuPickup, "tf_gift", "Gift");
	AddMenuItem(g_hPropMenuPickup, "medkit_large", "Medkit Large");
	AddMenuItem(g_hPropMenuPickup, "medkit_large_bday", "Medkit Large Bday");
	AddMenuItem(g_hPropMenuPickup, "medkit_medium", "Medkit Medium");
	AddMenuItem(g_hPropMenuPickup, "medkit_medium_bday", "Medkit Medium Bday");
	AddMenuItem(g_hPropMenuPickup, "medkit_small", "Medkit Small");
	AddMenuItem(g_hPropMenuPickup, "medkit_small_bday", "Medkit Small Bday");
	AddMenuItem(g_hPropMenuPickup, "platesandvich", "Sandvich Plate");
	AddMenuItem(g_hPropMenuPickup, "platesteak", "Steak Plate");
	AddMenuItem(g_hPropMenuPickup, "plate_robo_sandwich", "Sandvich Robo Plate");
	
	// Prop Menu Weapons
	g_hPropMenuWeapons = CreateMenu(PropMenuWeapons);
	SetMenuTitle(g_hPropMenuWeapons, /*"TF2SB - */ "Weapon Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuWeapons, true);
	AddMenuItem(g_hPropMenuWeapons, "removeprops", "| Remove");
	// AddMenuItem(g_hPropMenuPickup, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuWeapons, "w_baseball", "Baseball");
	AddMenuItem(g_hPropMenuWeapons, "w_bat", "Bat");
	AddMenuItem(g_hPropMenuWeapons, "w_cigarette_case", "Cigarette Case");
	AddMenuItem(g_hPropMenuWeapons, "w_fireaxe", "Fire Axe");
	AddMenuItem(g_hPropMenuWeapons, "w_frontierjustice", "Frontier Justice");
	AddMenuItem(g_hPropMenuWeapons, "w_grenade_grenadelauncher", "Grenade");
	AddMenuItem(g_hPropMenuWeapons, "w_grenadelauncher", "Grenade Launcher");
	AddMenuItem(g_hPropMenuWeapons, "w_knife", "Knife");
	AddMenuItem(g_hPropMenuWeapons, "w_medigun", "Medi Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_minigun", "MiniGun");
	AddMenuItem(g_hPropMenuWeapons, "w_builder", "PDA Build");
	AddMenuItem(g_hPropMenuWeapons, "w_pda_engineer", "PDA Destroy");
	AddMenuItem(g_hPropMenuWeapons, "w_pistol", "Pistol");
	AddMenuItem(g_hPropMenuWeapons, "w_revolver", "Revolver");
	AddMenuItem(g_hPropMenuWeapons, "w_rocket", "Rocket");
	AddMenuItem(g_hPropMenuWeapons, "w_rocketlauncher", "Rocket Launcher");
	AddMenuItem(g_hPropMenuWeapons, "w_sapper", "Sapper");
	AddMenuItem(g_hPropMenuWeapons, "w_scattergun", "Scatter Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_shotgun", "Shotgun");
	AddMenuItem(g_hPropMenuWeapons, "w_shovel", "Shovel");
	AddMenuItem(g_hPropMenuWeapons, "w_smg", "SMG");
	AddMenuItem(g_hPropMenuWeapons, "w_sniperrifle", "Sniper Rifle");
	AddMenuItem(g_hPropMenuWeapons, "w_stickybomb_launcher", "Sticky Bomb Launcher");
	AddMenuItem(g_hPropMenuWeapons, "w_syringegun", "Syringe Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_wrangler", "The Wrangler");
	AddMenuItem(g_hPropMenuWeapons, "w_toolbox", "Toolbox");
	AddMenuItem(g_hPropMenuWeapons, "w_ttg_max_gun", "TTG Max Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_wrench", "Wrench");
	AddMenuItem(g_hPropMenuWeapons, "apsap", "The Ap-Sap");
	AddMenuItem(g_hPropMenuWeapons, "apocofists", "The Apoco-Fists");
	AddMenuItem(g_hPropMenuWeapons, "atomizer", "The Atomizer");
	AddMenuItem(g_hPropMenuWeapons, "awperhand", "The AWPer Hand");
	AddMenuItem(g_hPropMenuWeapons, "babyfacesblaster", "The Baby Face's Blaster");
	AddMenuItem(g_hPropMenuWeapons, "backscatter", "The Back Scatter");
	AddMenuItem(g_hPropMenuWeapons, "backburner", "The Backburner");
	AddMenuItem(g_hPropMenuWeapons, "batouttahell", "The Bat Outta Hell");
	AddMenuItem(g_hPropMenuWeapons, "batsaber", "The Batsaber");
	AddMenuItem(g_hPropMenuWeapons, "battalionsbackup", "The Battalion's Backup");
	AddMenuItem(g_hPropMenuWeapons, "beggarsbazooka", "The Beggar's Bazooka");
	AddMenuItem(g_hPropMenuWeapons, "bigearner", "The Big Earner");
	AddMenuItem(g_hPropMenuWeapons, "blackrose", "The Black Rose");
	AddMenuItem(g_hPropMenuWeapons, "blutsauger", "The Blutsauger");
	AddMenuItem(g_hPropMenuWeapons, "bonkatomicpunch", "The Bonk! Atomic Punch");
	AddMenuItem(g_hPropMenuWeapons, "bostonbasher", "The Boston Basher");
	AddMenuItem(g_hPropMenuWeapons, "breadbite", "The Bread Bite");
	AddMenuItem(g_hPropMenuWeapons, "buffalosteaksandvich", "The Buffalo Steak Sandvich");
	AddMenuItem(g_hPropMenuWeapons, "bushwacka", "The Bushwacka");
	AddMenuItem(g_hPropMenuWeapons, "capper", "The C.A.P.P.E.R");
	AddMenuItem(g_hPropMenuWeapons, "candycane", "The Candy Cane");
	AddMenuItem(g_hPropMenuWeapons, "classic", "The Classic");
	AddMenuItem(g_hPropMenuWeapons, "cleanerscarbine", "The Cleaner's Carbine");
	AddMenuItem(g_hPropMenuWeapons, "concheror", "The Concheror");
	AddMenuItem(g_hPropMenuWeapons, "conniverskunai", "The Conniver's Kunai");
	AddMenuItem(g_hPropMenuWeapons, "conscientiousobjector", "The Conscientious Objector");
	AddMenuItem(g_hPropMenuWeapons, "cowmangler5000", "The Cow Mangler 5000");
	AddMenuItem(g_hPropMenuWeapons, "cozycamper", "The Cozy Camper");
	AddMenuItem(g_hPropMenuWeapons, "critacola", "The Crit-a-Cola");
	AddMenuItem(g_hPropMenuWeapons, "crossingguard", "The Crossing Guard");
	AddMenuItem(g_hPropMenuWeapons, "dalokohsbar", "The Dalokohs Bar");
	AddMenuItem(g_hPropMenuWeapons, "darwinsdangershield", "The Darwin's Danger Shield");
	AddMenuItem(g_hPropMenuWeapons, "diamondback", "The Diamondback");
	AddMenuItem(g_hPropMenuWeapons, "directhit", "The Direct Hit");
	AddMenuItem(g_hPropMenuWeapons, "dragonsfury", "The Dragon's Fury");
	AddMenuItem(g_hPropMenuWeapons, "enforcer", "The Enforcer");
	AddMenuItem(g_hPropMenuWeapons, "equalizer", "The Equalizer");
	AddMenuItem(g_hPropMenuWeapons, "escapeplan", "The Escape Plan");
	AddMenuItem(g_hPropMenuWeapons, "eurekaeffect", "The Eureka Effect");
	AddMenuItem(g_hPropMenuWeapons, "evictionnotice", "The Eviction Notice");
	AddMenuItem(g_hPropMenuWeapons, "fanowar", "The Fan O'War");
	AddMenuItem(g_hPropMenuWeapons, "festiveambassador", "The Festive Ambassador");
	AddMenuItem(g_hPropMenuWeapons, "festiveaxtinguisher", "The Festive Axtinguisher");
	AddMenuItem(g_hPropMenuWeapons, "festivebackburner2014", "The Festive Backburner 2014");
	AddMenuItem(g_hPropMenuWeapons, "festiveblackbox", "The Festive Black Box");
	AddMenuItem(g_hPropMenuWeapons, "festivebonesaw2014", "The Festive Bonesaw 2014");
	AddMenuItem(g_hPropMenuWeapons, "festivebonk2014", "The Festive Bonk 2014");
	AddMenuItem(g_hPropMenuWeapons, "festivecrusaderscrossbow", "The Festive Crusader's Crossbow");
	AddMenuItem(g_hPropMenuWeapons, "festiveeyelander", "The Festive Eyelander");
	AddMenuItem(g_hPropMenuWeapons, "festiveflaregun", "The Festive Flare Gun");
	AddMenuItem(g_hPropMenuWeapons, "festiveforceanature", "The Festive Force-a-Nature");
	AddMenuItem(g_hPropMenuWeapons, "festivefrontierjustice", "The Festive Frontier Justice");
	AddMenuItem(g_hPropMenuWeapons, "festiveglovesofrunningurgently", "The Festive Gloves of Running Urgently");
	AddMenuItem(g_hPropMenuWeapons, "festivegrenadelauncher", "The Festive Grenade Launcher");
	AddMenuItem(g_hPropMenuWeapons, "festiveholymackerel", "The Festive Holy Mackerel");
	AddMenuItem(g_hPropMenuWeapons, "festivehuntsman", "The Festive Huntsman");
	AddMenuItem(g_hPropMenuWeapons, "festivejarate", "The Festive Jarate");
	AddMenuItem(g_hPropMenuWeapons, "festiverevolver2014", "The Festive Revolver 2014");
	AddMenuItem(g_hPropMenuWeapons, "festivesandvich", "The Festive Sandvich");
	AddMenuItem(g_hPropMenuWeapons, "festivesapper", "The Festive Sapper");
	AddMenuItem(g_hPropMenuWeapons, "festivetarge2014", "The Festive Targe 2014");
	AddMenuItem(g_hPropMenuWeapons, "festiveubersaw", "The Festive Ubersaw");
	AddMenuItem(g_hPropMenuWeapons, "festivewrangler", "The Festive Wrangler");
	AddMenuItem(g_hPropMenuWeapons, "fishcake", "The Fishcake");
	AddMenuItem(g_hPropMenuWeapons, "fistsofsteel", "The Fists of Steel");
	AddMenuItem(g_hPropMenuWeapons, "fortifiedcompound", "The Fortified Compound");
	AddMenuItem(g_hPropMenuWeapons, "freedomstaff", "The Freedom Staff");
	AddMenuItem(g_hPropMenuWeapons, "fryingpan", "The Frying Pan");
	AddMenuItem(g_hPropMenuWeapons, "gaspasser", "The Gas Passer");
	AddMenuItem(g_hPropMenuWeapons, "gigercounter", "The Giger Counter");
	AddMenuItem(g_hPropMenuWeapons, "glovesofrunningurgentlymvm", "The Gloves of Running Urgently MvM");
	AddMenuItem(g_hPropMenuWeapons, "goldfryingpan", "The Gold Frying Pan");
	AddMenuItem(g_hPropMenuWeapons, "goldenwrench", "The Golden Wrench");
	AddMenuItem(g_hPropMenuWeapons, "gunboats", "The Gunboats");
	AddMenuItem(g_hPropMenuWeapons, "hamshank", "The Ham Shank");
	AddMenuItem(g_hPropMenuWeapons, "hitmansheatmaker", "The Hitman's Heatmaker");
	AddMenuItem(g_hPropMenuWeapons, "holidaypunch", "The Holiday Punch");
	AddMenuItem(g_hPropMenuWeapons, "homewrecker", "The Homewrecker");
	AddMenuItem(g_hPropMenuWeapons, "horselessheadlesshorsemanshead", "The Horseless Headless Horseman's Headtaker");
	AddMenuItem(g_hPropMenuWeapons, "hothand", "The Hot Hand");
	AddMenuItem(g_hPropMenuWeapons, "ironcurtain", "The Iron Curtain");
	AddMenuItem(g_hPropMenuWeapons, "killingglovesofboxing", "The Killing Gloves of Boxing");
	AddMenuItem(g_hPropMenuWeapons, "letranger", "The L'Etranger");
	AddMenuItem(g_hPropMenuWeapons, "libertylauncher", "The Liberty Launcher");
	AddMenuItem(g_hPropMenuWeapons, "lollichop", "The Lollichop");
	AddMenuItem(g_hPropMenuWeapons, "manmelter", "The Manmelter");
	AddMenuItem(g_hPropMenuWeapons, "mantreads", "The Mantreads");
	AddMenuItem(g_hPropMenuWeapons, "marketgardener", "The Market Gardener");
	AddMenuItem(g_hPropMenuWeapons, "maul", "The Maul");
	AddMenuItem(g_hPropMenuWeapons, "memorymaker", "The Memory Maker");
	AddMenuItem(g_hPropMenuWeapons, "mutatedmilk", "The Mutated Milk");
	AddMenuItem(g_hPropMenuWeapons, "natascha", "The Natascha");
	AddMenuItem(g_hPropMenuWeapons, "necrosmasher", "The Necro Smasher");
	AddMenuItem(g_hPropMenuWeapons, "nessiesnineiron", "The Nessie's Nine Iron");
	AddMenuItem(g_hPropMenuWeapons, "nostromonapalmer", "The Nostromo Napalmer");
	AddMenuItem(g_hPropMenuWeapons, "original", "The Original");
	AddMenuItem(g_hPropMenuWeapons, "overdose", "The Overdose");
	AddMenuItem(g_hPropMenuWeapons, "paintrain", "The Pain Train");
	AddMenuItem(g_hPropMenuWeapons, "phlogistinator", "The Phlogistinator");
	AddMenuItem(g_hPropMenuWeapons, "pomson6000", "The Pomson 6000");
	AddMenuItem(g_hPropMenuWeapons, "postalpummeler", "The Postal Pummeler");
	AddMenuItem(g_hPropMenuWeapons, "prettyboyspocketpistol", "The Pretty Boy's Pocket Pistol");
	AddMenuItem(g_hPropMenuWeapons, "prinnymachete", "The Prinny Machete");
	AddMenuItem(g_hPropMenuWeapons, "quickfix", "The Quick-Fix");
	AddMenuItem(g_hPropMenuWeapons, "quickiebomblauncher", "The Quickiebomb Launcher");
	AddMenuItem(g_hPropMenuWeapons, "rainblower", "The Rainblower");
	AddMenuItem(g_hPropMenuWeapons, "razorback", "The Razorback");
	AddMenuItem(g_hPropMenuWeapons, "righteousbison", "The Righteous Bison");
	AddMenuItem(g_hPropMenuWeapons, "robosandvich", "The Robo-Sandvich");
	AddMenuItem(g_hPropMenuWeapons, "rocketjumper", "The Rocket Jumper");
	AddMenuItem(g_hPropMenuWeapons, "sandman", "The Sandman");
	AddMenuItem(g_hPropMenuWeapons, "saxxy", "The Saxxy");
	AddMenuItem(g_hPropMenuWeapons, "scottishhandshake", "The Scottish Handshake");
	AddMenuItem(g_hPropMenuWeapons, "scottishresistance", "The Scottish Resistance");
	AddMenuItem(g_hPropMenuWeapons, "secondbanana", "The Second Banana");
	AddMenuItem(g_hPropMenuWeapons, "selfawarebeautymark", "The Self-Aware Beauty Mark");
	AddMenuItem(g_hPropMenuWeapons, "sharpdresser", "The Sharp Dresser");
	AddMenuItem(g_hPropMenuWeapons, "sharpenedvolcanofragment", "The Sharpened Volcano Fragment");
	AddMenuItem(g_hPropMenuWeapons, "shootingstar", "The Shooting Star");
	AddMenuItem(g_hPropMenuWeapons, "shortcircuit", "The Short Circuit");
	AddMenuItem(g_hPropMenuWeapons, "solemnvow", "The Solemn Vow");
	AddMenuItem(g_hPropMenuWeapons, "sournhospitality", "The Southern Hospitality");
	AddMenuItem(g_hPropMenuWeapons, "spycicle", "The Spy-cicle");
	AddMenuItem(g_hPropMenuWeapons, "stickybombjumper", "The Stickybomb Jumper");
	AddMenuItem(g_hPropMenuWeapons, "sunonastick", "The Sun-on-a-Stick");
	AddMenuItem(g_hPropMenuWeapons, "sydneysleeper", "The Sydney Sleeper");
	AddMenuItem(g_hPropMenuWeapons, "rmalthruster", "The Thermal Thruster");
	AddMenuItem(g_hPropMenuWeapons, "thirddegree", "The Third Degree");
	AddMenuItem(g_hPropMenuWeapons, "threeruneblade", "The Three-Rune Blade");
	AddMenuItem(g_hPropMenuWeapons, "tideturner", "The Tide Turner");
	AddMenuItem(g_hPropMenuWeapons, "tribalmansshiv", "The Tribalman's Shiv");
	AddMenuItem(g_hPropMenuWeapons, "ttgmaxpistol", "The TTG Max Pistol");
	AddMenuItem(g_hPropMenuWeapons, "ttgmaxpistolpokernight", "The TTG Max Pistol - Poker Night");
	AddMenuItem(g_hPropMenuWeapons, "ttgsamrevolver", "The TTG Sam Revolver");
	AddMenuItem(g_hPropMenuWeapons, "ullapoolcaber", "The Ullapool Caber");
	AddMenuItem(g_hPropMenuWeapons, "unarmedcombat", "The Unarmed Combat");
	AddMenuItem(g_hPropMenuWeapons, "vaccinator", "The Vaccinator");
	AddMenuItem(g_hPropMenuWeapons, "vitasaw", "The Vita-Saw");
	AddMenuItem(g_hPropMenuWeapons, "wangaprick", "The Wanga Prick");
	AddMenuItem(g_hPropMenuWeapons, "warriorsspirit", "The Warrior's Spirit");
	AddMenuItem(g_hPropMenuWeapons, "widowmaker", "The Widowmaker");
	AddMenuItem(g_hPropMenuWeapons, "wrapassassin", "The Wrap Assassin");
	AddMenuItem(g_hPropMenuWeapons, "youreternalreward", "The Your Eternal Reward");

	// Prop Menu Cosmetics
	g_hPropMenuCosmetics = CreateMenu(PropMenuCosmetics);
	SetMenuTitle(g_hPropMenuCosmetics, /*"TF2SB - */ "Cosmetic Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuCosmetics, true);
	AddMenuItem(g_hPropMenuCosmetics, "ararfestivetree", "A Rather Festive Tree");
	AddMenuItem(g_hPropMenuCosmetics, "allbrero", "Allbrero");
	AddMenuItem(g_hPropMenuCosmetics, "anger", "Anger");
	AddMenuItem(g_hPropMenuCosmetics, "armoredauthority", "Armored Authority");
	AddMenuItem(g_hPropMenuCosmetics, "attendant", "Attendant");
	AddMenuItem(g_hPropMenuCosmetics, "audiofile", "Audio File");
	AddMenuItem(g_hPropMenuCosmetics, "aztecwarrior", "Aztec Warrior");
	AddMenuItem(g_hPropMenuCosmetics, "bmoc", "B.M.O.C.");
	AddMenuItem(g_hPropMenuCosmetics, "backbitersbillycock", "Backbiter's Billycock");
	AddMenuItem(g_hPropMenuCosmetics, "backwardsballcap", "Backwards Ballcap");
	AddMenuItem(g_hPropMenuCosmetics, "ballkickingboots", "Ball-Kicking Boots");
	AddMenuItem(g_hPropMenuCosmetics, "baronvonhavenaplane", "Baron von Havenaplane");
	AddMenuItem(g_hPropMenuCosmetics, "basemetalbillycock", "Base Metal Billycock");
	AddMenuItem(g_hPropMenuCosmetics, "battershelmet", "Batter's Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "battleboonie", "Battle Boonie");
	AddMenuItem(g_hPropMenuCosmetics, "belgiandetective", "Belgian Detective");
	AddMenuItem(g_hPropMenuCosmetics, "belltowerspecops", "Belltower Spec Ops");
	AddMenuItem(g_hPropMenuCosmetics, "benefactorskanmuri", "Benefactor's Kanmuri");
	AddMenuItem(g_hPropMenuCosmetics, "berlinersbuckelm", "Berliner's Bucket Helm");
	AddMenuItem(g_hPropMenuCosmetics, "bigchief", "Big Chief");
	AddMenuItem(g_hPropMenuCosmetics, "birdcage", "Birdcage");
	AddMenuItem(g_hPropMenuCosmetics, "blackwatch", "Black Watch");
	AddMenuItem(g_hPropMenuCosmetics, "blazingbull", "Blazing Bull");
	AddMenuItem(g_hPropMenuCosmetics, "blightedbeak", "Blighted Beak");
	AddMenuItem(g_hPropMenuCosmetics, "bolgan", "Bolgan");
	AddMenuItem(g_hPropMenuCosmetics, "bolganfamilycrest", "Bolgan Family Crest");
	AddMenuItem(g_hPropMenuCosmetics, "boltactionblitzer", "Bolt Action Blitzer");
	AddMenuItem(g_hPropMenuCosmetics, "boltedbicorne", "Bolted Bicorne");
	AddMenuItem(g_hPropMenuCosmetics, "boltedbushman", "Bolted Bushman");
	AddMenuItem(g_hPropMenuCosmetics, "bombingrun", "Bombing Run");
	AddMenuItem(g_hPropMenuCosmetics, "bonedome", "Bone Dome");
	AddMenuItem(g_hPropMenuCosmetics, "bonkboy", "Bonk Boy");
	AddMenuItem(g_hPropMenuCosmetics, "bonkhelm", "Bonk Helm");
	AddMenuItem(g_hPropMenuCosmetics, "bonkleadwear", "Bonk Leadwear");
	AddMenuItem(g_hPropMenuCosmetics, "bootlegbasemetalbillycock", "Bootleg Base Metal Billycock");
	AddMenuItem(g_hPropMenuCosmetics, "bostonboombringer", "Boston Boom-Bringer");
	AddMenuItem(g_hPropMenuCosmetics, "botdogger", "Bot Dogger");
	AddMenuItem(g_hPropMenuCosmetics, "brainiacgoggles", "Brainiac Goggles");
	AddMenuItem(g_hPropMenuCosmetics, "brainiachairpiece", "Brainiac Hairpiece");
	AddMenuItem(g_hPropMenuCosmetics, "brigadehelm", "Brigade Helm");
	AddMenuItem(g_hPropMenuCosmetics, "brimfullofbullets", "Brim-Full Of Bullets");
	AddMenuItem(g_hPropMenuCosmetics, "broadbandbonnet", "Broadband Bonnet");
	AddMenuItem(g_hPropMenuCosmetics, "brownbomber", "Brown Bomber");
	AddMenuItem(g_hPropMenuCosmetics, "buccaneersbicorne", "Buccaneer's Bicorne");
	AddMenuItem(g_hPropMenuCosmetics, "buckarooshat", "Buckaroos Hat");
	AddMenuItem(g_hPropMenuCosmetics, "buckethat", "Bucket Hat");
	AddMenuItem(g_hPropMenuCosmetics, "buildersblueprints", "Builder's Blueprints");
	AddMenuItem(g_hPropMenuCosmetics, "bunsenbrave", "Bunsen Brave");
	AddMenuItem(g_hPropMenuCosmetics, "burningbeanie", "Burning Beanie");
	AddMenuItem(g_hPropMenuCosmetics, "burningquestion", "Burning Question");
	AddMenuItem(g_hPropMenuCosmetics, "bushmansboonie", "Bushman's Boonie");
	AddMenuItem(g_hPropMenuCosmetics, "cadaverscranium", "Cadaver's Cranium");
	AddMenuItem(g_hPropMenuCosmetics, "camerabeard", "Camera Beard");
	AddMenuItem(g_hPropMenuCosmetics, "camerahelm", "Camera Helm");
	AddMenuItem(g_hPropMenuCosmetics, "caponescapper", "Capone's Capper");
	AddMenuItem(g_hPropMenuCosmetics, "captainscocktails", "Captain's Cocktails");
	AddMenuItem(g_hPropMenuCosmetics, "cariboucompanion", "Caribou Companion");
	AddMenuItem(g_hPropMenuCosmetics, "carouserscapotain", "Carouser's Capotain");
	AddMenuItem(g_hPropMenuCosmetics, "centurion", "Centurion");
	AddMenuItem(g_hPropMenuCosmetics, "charmerschapeau", "Charmer's Chapeau");
	AddMenuItem(g_hPropMenuCosmetics, "chiefconstable", "Chief Constable");
	AddMenuItem(g_hPropMenuCosmetics, "chieftainschallenge", "Chieftain's Challenge");
	AddMenuItem(g_hPropMenuCosmetics, "civiliangradejackhat", "Civilian Grade JACK Hat");
	AddMenuItem(g_hPropMenuCosmetics, "classycapper", "Classy Capper");
	AddMenuItem(g_hPropMenuCosmetics, "clockwerkshelm", "Clockwerk's Helm");
	AddMenuItem(g_hPropMenuCosmetics, "cloudcrasher", "Cloud Crasher");
	AddMenuItem(g_hPropMenuCosmetics, "coldcase", "Cold Case");
	AddMenuItem(g_hPropMenuCosmetics, "combatmedicscrushercap", "Combat Medic's Crusher Cap");
	AddMenuItem(g_hPropMenuCosmetics, "commandoelite", "Commando Elite");
	AddMenuItem(g_hPropMenuCosmetics, "commonstatclock", "Common Stat Clock");
	AddMenuItem(g_hPropMenuCosmetics, "conjurerscowl", "Conjurer's Cowl");
	AddMenuItem(g_hPropMenuCosmetics, "connoisseurscap", "Connoisseur's Cap");
	AddMenuItem(g_hPropMenuCosmetics, "conquistador", "Conquistador");
	AddMenuItem(g_hPropMenuCosmetics, "coppershardtop", "Copper's Hard Top");
	AddMenuItem(g_hPropMenuCosmetics, "cosanostracap", "Cosa Nostra Cap");
	AddMenuItem(g_hPropMenuCosmetics, "cottonhead", "Cotton Head");
	AddMenuItem(g_hPropMenuCosmetics, "counterfeitbillycock", "Counterfeit Billycock");
	AddMenuItem(g_hPropMenuCosmetics, "coupedisaster", "Coupe D'isaster");
	AddMenuItem(g_hPropMenuCosmetics, "couvrecorner", "Couvre Corner");
	AddMenuItem(g_hPropMenuCosmetics, "croclearslouch", "Crocleather Slouch");
	AddMenuItem(g_hPropMenuCosmetics, "crocodilesmile", "Crocodile Smile");
	AddMenuItem(g_hPropMenuCosmetics, "cronesdome", "Crone's Dome");
	AddMenuItem(g_hPropMenuCosmetics, "crosscommcrashhelmet", "Cross-Comm Crash Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "crosscommexpress", "Cross-Comm Express");
	AddMenuItem(g_hPropMenuCosmetics, "crosslinkerscoil", "Crosslinker's Coil");
	AddMenuItem(g_hPropMenuCosmetics, "cyborgstunlmet", "Cyborg Stunt Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "dailyduelwinnerrewardhat", "Daily Duel Winner Reward Hat");
	AddMenuItem(g_hPropMenuCosmetics, "dailygiftgiverrewardhat", "Daily Gift Giver Reward Hat");
	AddMenuItem(g_hPropMenuCosmetics, "dailymapstamprewardhat", "Daily Map Stamp Reward Hat");
	AddMenuItem(g_hPropMenuCosmetics, "darkfalkirkhelm", "Dark Falkirk Helm");
	AddMenuItem(g_hPropMenuCosmetics, "dasnaggenvatcher", "Das Naggenvatcher");
	AddMenuItem(g_hPropMenuCosmetics, "dasubersternmann", "Das Ubersternmann");
	AddMenuItem(g_hPropMenuCosmetics, "dashinhashshashin", "Dashin' Hashshashin");
	AddMenuItem(g_hPropMenuCosmetics, "deadlittlebuddy", "Dead Little Buddy");
	AddMenuItem(g_hPropMenuCosmetics, "defiantspartan", "Defiant Spartan");
	AddMenuItem(g_hPropMenuCosmetics, "demokabuto", "Demo Kabuto");
	AddMenuItem(g_hPropMenuCosmetics, "demomanhallmark", "Demoman Hallmark");
	AddMenuItem(g_hPropMenuCosmetics, "demomantricorne", "Demoman Tricorne");
	AddMenuItem(g_hPropMenuCosmetics, "dermaschinensoldatenhelm", "Der Maschinensoldaten-Helm");
	AddMenuItem(g_hPropMenuCosmetics, "detectivenoir", "Detective Noir");
	AddMenuItem(g_hPropMenuCosmetics, "doctorssack", "Doctor's Sack");
	AddMenuItem(g_hPropMenuCosmetics, "doeboy", "Doe-Boy");
	AddMenuItem(g_hPropMenuCosmetics, "drsdappertopper", "Dr's Dapper Topper");
	AddMenuItem(g_hPropMenuCosmetics, "dragonbornhelmet", "Dragonborn Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "ebenezer", "Ebenezer");
	AddMenuItem(g_hPropMenuCosmetics, "electricescorter", "Electric Escorter");
	AddMenuItem(g_hPropMenuCosmetics, "eliminatorssafeguard", "Eliminators Safeguard");
	AddMenuItem(g_hPropMenuCosmetics, "ellishat", "Ellis Hat");
	AddMenuItem(g_hPropMenuCosmetics, "engineerearmuffs", "Engineer Earmuffs");
	AddMenuItem(g_hPropMenuCosmetics, "engineerweldingmask", "Engineer Welding Mask");
	AddMenuItem(g_hPropMenuCosmetics, "engineerscap", "Engineer's Cap");
	AddMenuItem(g_hPropMenuCosmetics, "exquisiterack", "Exquisite Rack");
	AddMenuItem(g_hPropMenuCosmetics, "familiarfez", "Familiar Fez");
	AddMenuItem(g_hPropMenuCosmetics, "fancyfedora", "Fancy Fedora");
	AddMenuItem(g_hPropMenuCosmetics, "fatmansfieldcap", "Fat Man's Field Cap");
	AddMenuItem(g_hPropMenuCosmetics, "fearedfiend", "Feathered Fiend");
	AddMenuItem(g_hPropMenuCosmetics, "fedfightinfedora", "Fed-Fightin' Fedora");
	AddMenuItem(g_hPropMenuCosmetics, "federalcasemaker", "Federal Casemaker");
	AddMenuItem(g_hPropMenuCosmetics, "firewallhelmet", "Firewall Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "flamboyantflamenco", "Flamboyant Flamenco");
	AddMenuItem(g_hPropMenuCosmetics, "flamingokid", "Flamingo Kid");
	AddMenuItem(g_hPropMenuCosmetics, "flippedtrilby", "Flipped Trilby");
	AddMenuItem(g_hPropMenuCosmetics, "footballhelmet", "Football Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "friendlyitem", "Friendly Item");
	AddMenuItem(g_hPropMenuCosmetics, "fruitshoot", "Fruit Shoot");
	AddMenuItem(g_hPropMenuCosmetics, "fullheadofsteam", "Full Head of Steam");
	AddMenuItem(g_hPropMenuCosmetics, "fullmetaldrillhat", "Full Metal Drill Hat");
	AddMenuItem(g_hPropMenuCosmetics, "furiousfukaamigasa", "Furious Fukaamigasa");
	AddMenuItem(g_hPropMenuCosmetics, "gabeglasses", "Gabe Glasses");
	AddMenuItem(g_hPropMenuCosmetics, "galvanizedgibus", "Galvanized Gibus");
	AddMenuItem(g_hPropMenuCosmetics, "gentlemunitionneofleisure", "Gentle Munitionne of Leisure");
	AddMenuItem(g_hPropMenuCosmetics, "gentlemansushanka", "Gentleman's Ushanka");
	AddMenuItem(g_hPropMenuCosmetics, "germangonzila", "German Gonzila");
	AddMenuItem(g_hPropMenuCosmetics, "ghastlygibus", "Ghastly Gibus");
	AddMenuItem(g_hPropMenuCosmetics, "ghastlygibus2010", "Ghastly Gibus 2010");
	AddMenuItem(g_hPropMenuCosmetics, "ghastlygibus2011", "Ghastly Gibus 2011");
	AddMenuItem(g_hPropMenuCosmetics, "ghostlygibus", "Ghostly Gibus");
	AddMenuItem(g_hPropMenuCosmetics, "gildedguard", "Gilded Guard");
	AddMenuItem(g_hPropMenuCosmetics, "glengarrybonnet", "Glengarry Bonnet");
	AddMenuItem(g_hPropMenuCosmetics, "grandmaster", "Grandmaster");
	AddMenuItem(g_hPropMenuCosmetics, "graybanns", "Graybanns");
	AddMenuItem(g_hPropMenuCosmetics, "grenadierhelm", "Grenadier Helm");
	AddMenuItem(g_hPropMenuCosmetics, "grenadierssoftcap", "Grenadier's Softcap");
	AddMenuItem(g_hPropMenuCosmetics, "gridironguardian", "Gridiron Guardian");
	AddMenuItem(g_hPropMenuCosmetics, "grimmhatte", "Grimm Hatte");
	AddMenuItem(g_hPropMenuCosmetics, "gymrat", "Gym Rat");
	AddMenuItem(g_hPropMenuCosmetics, "halfzatoichi", "Half-Zatoichi");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskdemoman", "Halloween Mask - Demoman");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskengineer", "Halloween Mask - Engineer");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskheavy", "Halloween Mask - Heavy");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskmedic", "Halloween Mask - Medic");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskpyro", "Halloween Mask - Pyro");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmasksaxtonhale", "Halloween Mask - Saxton Hale");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskscout", "Halloween Mask - Scout");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmasksniper", "Halloween Mask - Sniper");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmasksoldier", "Halloween Mask - Soldier");
	AddMenuItem(g_hPropMenuCosmetics, "halloweenmaskspy", "Halloween Mask - Spy");
	AddMenuItem(g_hPropMenuCosmetics, "handymanshandle", "Handyman's Handle");
	AddMenuItem(g_hPropMenuCosmetics, "hardcounter", "Hard Counter");
	AddMenuItem(g_hPropMenuCosmetics, "hardylaurel", "Hardy Laurel");
	AddMenuItem(g_hPropMenuCosmetics, "harmburg", "Harmburg");
	AddMenuItem(g_hPropMenuCosmetics, "hatofcards", "Hat of Cards");
	AddMenuItem(g_hPropMenuCosmetics, "headhedge", "Head Hedge");
	AddMenuItem(g_hPropMenuCosmetics, "headwarmer", "Head Warmer");
	AddMenuItem(g_hPropMenuCosmetics, "heavyartilleryofficerscap", "Heavy Artillery Officer's Cap");
	AddMenuItem(g_hPropMenuCosmetics, "heavytopknot", "Heavy Topknot");
	AddMenuItem(g_hPropMenuCosmetics, "heershelmet", "Heer's Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "helmetwithoutahome", "Helmet Without a Home");
	AddMenuItem(g_hPropMenuCosmetics, "hermes", "Hermes");
	AddMenuItem(g_hPropMenuCosmetics, "heroshachimaki", "Hero's Hachimaki");
	AddMenuItem(g_hPropMenuCosmetics, "holyhunter", "Holy Hunter");
	AddMenuItem(g_hPropMenuCosmetics, "hongkongcone", "Hong Kong Cone");
	AddMenuItem(g_hPropMenuCosmetics, "horrificheadsplitter", "Horrific Headsplitter");
	AddMenuItem(g_hPropMenuCosmetics, "horselessheadlesshorsemanshead", "Horseless Headless Horseman's Head");
	AddMenuItem(g_hPropMenuCosmetics, "hotdogger", "Hot Dogger");
	AddMenuItem(g_hPropMenuCosmetics, "humanitarianshachimaki", "Humanitarian's Hachimaki");
	AddMenuItem(g_hPropMenuCosmetics, "hunterindarkness", "Hunter in Darkness");
	AddMenuItem(g_hPropMenuCosmetics, "idiotbox", "Idiot Box");
	AddMenuItem(g_hPropMenuCosmetics, "industrialfestivizer", "Industrial Festivizer");
	AddMenuItem(g_hPropMenuCosmetics, "infernalimpaler", "Infernal Impaler");
	AddMenuItem(g_hPropMenuCosmetics, "janissaryhat", "Janissary Hat");
	AddMenuItem(g_hPropMenuCosmetics, "jumpersjeepcap", "Jumper's Jeepcap");
	AddMenuItem(g_hPropMenuCosmetics, "junglewreath", "Jungle Wreath");
	AddMenuItem(g_hPropMenuCosmetics, "killerexclusive", "Killer Exclusive");
	AddMenuItem(g_hPropMenuCosmetics, "kissking", "Kiss King");
	AddMenuItem(g_hPropMenuCosmetics, "linspecteur", "L'Inspecteur");
	AddMenuItem(g_hPropMenuCosmetics, "l4dhat", "L4D Hat");
	AddMenuItem(g_hPropMenuCosmetics, "largeluchadore", "Large Luchadore");
	AddMenuItem(g_hPropMenuCosmetics, "larrikinrobin", "Larrikin Robin");
	AddMenuItem(g_hPropMenuCosmetics, "laststraw", "Last Straw");
	AddMenuItem(g_hPropMenuCosmetics, "law", "Law");
	AddMenuItem(g_hPropMenuCosmetics, "lepartyphantom", "Le Party Phantom");
	AddMenuItem(g_hPropMenuCosmetics, "letchsled", "Letch's LED");
	AddMenuItem(g_hPropMenuCosmetics, "littlebuddy", "Little Buddy");
	AddMenuItem(g_hPropMenuCosmetics, "lofilongwave", "Lo-Fi Longwave");
	AddMenuItem(g_hPropMenuCosmetics, "lordcockswainsnoveltymuttoncho", "Lord Cockswain's Novelty Mutton Chops and Pipe");
	AddMenuItem(g_hPropMenuCosmetics, "lordcockswainspithhelmet", "Lord Cockswain's Pith Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "loyaltyreward", "Loyalty Reward");
	AddMenuItem(g_hPropMenuCosmetics, "luckyshot", "Lucky Shot");
	AddMenuItem(g_hPropMenuCosmetics, "madamedixie", "Madame Dixie");
	AddMenuItem(g_hPropMenuCosmetics, "mademan", "Made Man");
	AddMenuItem(g_hPropMenuCosmetics, "magnificentmongolian", "Magnificent Mongolian");
	AddMenuItem(g_hPropMenuCosmetics, "mangnanimousmonarch", "Mangnanimous Monarch");
	AddMenuItem(g_hPropMenuCosmetics, "manncocap", "Mann Co. Cap");
	AddMenuItem(g_hPropMenuCosmetics, "manncoonlinecap", "Mann Co. Online Cap");
	AddMenuItem(g_hPropMenuCosmetics, "mannanascap", "Mannanas Cap");
	AddMenuItem(g_hPropMenuCosmetics, "maskofshaman", "Mask of the Shaman");
	AddMenuItem(g_hPropMenuCosmetics, "mastersyellowbelt", "Master's Yellow Belt");
	AddMenuItem(g_hPropMenuCosmetics, "medicgatsby", "Medic Gatsby");
	AddMenuItem(g_hPropMenuCosmetics, "medicgeishahair", "Medic Geisha Hair");
	AddMenuItem(g_hPropMenuCosmetics, "medicgoggles", "Medic Goggles");
	AddMenuItem(g_hPropMenuCosmetics, "medicmtghat", "Medic MtG Hat");
	AddMenuItem(g_hPropMenuCosmetics, "medicsmountaincap", "Medic's Mountain Cap");
	AddMenuItem(g_hPropMenuCosmetics, "mercenaryparkcap", "Mercenary Park Cap");
	AddMenuItem(g_hPropMenuCosmetics, "mildlydisturbinghalloweenmask", "Mildly Disturbing Halloween Mask");
	AddMenuItem(g_hPropMenuCosmetics, "militarygradejackhat", "Military Grade JACK Hat");
	AddMenuItem(g_hPropMenuCosmetics, "milkman", "Milkman");
	AddMenuItem(g_hPropMenuCosmetics, "mininglight", "Mining Light");
	AddMenuItem(g_hPropMenuCosmetics, "mnchat", "MNC Hat");
	AddMenuItem(g_hPropMenuCosmetics, "mncmascothat", "MNC Mascot Hat");
	AddMenuItem(g_hPropMenuCosmetics, "modestmetalpileofscrap", "Modest Metal Pile of Scrap");
	AddMenuItem(g_hPropMenuCosmetics, "modestpileofhat", "Modest Pile of Hat");
	AddMenuItem(g_hPropMenuCosmetics, "monoculus", "MONOCULUS!");
	AddMenuItem(g_hPropMenuCosmetics, "napoleoncomplex", "Napoleon Complex");
	AddMenuItem(g_hPropMenuCosmetics, "nappersrespite", "Napper's Respite");
	AddMenuItem(g_hPropMenuCosmetics, "neckwearheadwear", "Neckwear Headwear");
	AddMenuItem(g_hPropMenuCosmetics, "necronomicrown", "Necronomicrown");
	AddMenuItem(g_hPropMenuCosmetics, "neverforgetcap", "Never Forget Cap");
	AddMenuItem(g_hPropMenuCosmetics, "nobleamassmentofhats", "Noble Amassment of Hats");
	AddMenuItem(g_hPropMenuCosmetics, "noblenickelamassmentofhats", "Noble Nickel Amassment of Hats");
	AddMenuItem(g_hPropMenuCosmetics, "officersushanka", "Officer's Ushanka");
	AddMenuItem(g_hPropMenuCosmetics, "olgeezer", "Ol' Geezer");
	AddMenuItem(g_hPropMenuCosmetics, "olsnaggletooth", "Ol' Snaggletooth");
	AddMenuItem(g_hPropMenuCosmetics, "oldguadalajara", "Old Guadalajara");
	AddMenuItem(g_hPropMenuCosmetics, "osxitem", "OSX Item");
	AddMenuItem(g_hPropMenuCosmetics, "otolaryngologistsmirror", "Otolaryngologist's Mirror");
	AddMenuItem(g_hPropMenuCosmetics, "outdoorsman", "Outdoorsman");
	AddMenuItem(g_hPropMenuCosmetics, "parasitehat", "Parasite Hat");
	AddMenuItem(g_hPropMenuCosmetics, "pencilpusher", "Pencil Pusher");
	AddMenuItem(g_hPropMenuCosmetics, "petballoonicorn", "Pet Balloonicorn");
	AddMenuItem(g_hPropMenuCosmetics, "petreindoonicorn", "Pet Reindoonicorn");
	AddMenuItem(g_hPropMenuCosmetics, "pilotka", "Pilotka");
	AddMenuItem(g_hPropMenuCosmetics, "pipboy", "Pip-Boy");
	AddMenuItem(g_hPropMenuCosmetics, "pithyprofessional", "Pithy Professional");
	AddMenuItem(g_hPropMenuCosmetics, "platinumpickelhaube", "Platinum Pickelhaube");
	AddMenuItem(g_hPropMenuCosmetics, "pluginprospector", "Plug-In Prospector");
	AddMenuItem(g_hPropMenuCosmetics, "pointandshoot", "Point and Shoot");
	AddMenuItem(g_hPropMenuCosmetics, "pokervisor", "Poker Visor");
	AddMenuItem(g_hPropMenuCosmetics, "polarbear", "Polar Bear");
	AddMenuItem(g_hPropMenuCosmetics, "polishwarbabushka", "Polish War Babushka");
	AddMenuItem(g_hPropMenuCosmetics, "potatohat", "Potato Hat");
	AddMenuItem(g_hPropMenuCosmetics, "prairieheelbiters", "Prairie Heel Biters");
	AddMenuItem(g_hPropMenuCosmetics, "prancerspride", "Prancer's Pride");
	AddMenuItem(g_hPropMenuCosmetics, "princetavishscrown", "Prince Tavish's Crown");
	AddMenuItem(g_hPropMenuCosmetics, "privateeye", "Private Eye");
	AddMenuItem(g_hPropMenuCosmetics, "professionalspanama", "Professional's Panama");
	AddMenuItem(g_hPropMenuCosmetics, "professorspeculiarity", "Professor's Peculiarity");
	AddMenuItem(g_hPropMenuCosmetics, "propagandacontestfirstplace", "Propaganda Contest First Place");
	AddMenuItem(g_hPropMenuCosmetics, "propagandacontestsecondplace", "Propaganda Contest Second Place");
	AddMenuItem(g_hPropMenuCosmetics, "propagandacontestthirdplace", "Propaganda Contest Third Place");
	AddMenuItem(g_hPropMenuCosmetics, "prussianpickelhaube", "Prussian Pickelhaube");
	AddMenuItem(g_hPropMenuCosmetics, "puffypolarcap", "Puffy Polar Cap");
	AddMenuItem(g_hPropMenuCosmetics, "pugilistsprotector", "Pugilist's Protector");
	AddMenuItem(g_hPropMenuCosmetics, "puretincapotain", "Pure Tin Capotain");
	AddMenuItem(g_hPropMenuCosmetics, "purityfist", "Purity Fist");
	AddMenuItem(g_hPropMenuCosmetics, "pyrohelm", "Pyro Helm");
	AddMenuItem(g_hPropMenuCosmetics, "pyromonocle", "Pyro Monocle");
	AddMenuItem(g_hPropMenuCosmetics, "pyrosbeanie", "Pyro's Beanie");
	AddMenuItem(g_hPropMenuCosmetics, "pyrosboronbeanie", "Pyro's Boron Beanie");
	AddMenuItem(g_hPropMenuCosmetics, "pyromancersmask", "Pyromancer's Mask");
	AddMenuItem(g_hPropMenuCosmetics, "rebelrouser", "Rebel Rouser");
	AddMenuItem(g_hPropMenuCosmetics, "respectlessroboglove", "Respectless Robo-Glove");
	AddMenuItem(g_hPropMenuCosmetics, "respectlessrubberglove", "Respectless Rubber Glove");
	AddMenuItem(g_hPropMenuCosmetics, "rimmedraincatcher", "Rimmed Raincatcher");
	AddMenuItem(g_hPropMenuCosmetics, "robotchickenhat", "Robot Chicken Hat");
	AddMenuItem(g_hPropMenuCosmetics, "robotrunningman", "Robot Running Man");
	AddMenuItem(g_hPropMenuCosmetics, "runnerswarmup", "Runner's Warm-Up");
	AddMenuItem(g_hPropMenuCosmetics, "saltydog", "Salty Dog");
	AddMenuItem(g_hPropMenuCosmetics, "sarifcap", "Sarif Cap");
	AddMenuItem(g_hPropMenuCosmetics, "saxtonhat", "Saxton Hat");
	AddMenuItem(g_hPropMenuCosmetics, "scotchbonnet", "Scotch Bonnet");
	AddMenuItem(g_hPropMenuCosmetics, "scotsmansstovepipe", "Scotsman's Stove Pipe");
	AddMenuItem(g_hPropMenuCosmetics, "scoutbeanie", "Scout Beanie");
	AddMenuItem(g_hPropMenuCosmetics, "scoutmtghat", "Scout MtG Hat");
	AddMenuItem(g_hPropMenuCosmetics, "scoutshako", "Scout Shako");
	AddMenuItem(g_hPropMenuCosmetics, "scoutwhoopeecap", "Scout Whoopee Cap");
	AddMenuItem(g_hPropMenuCosmetics, "sealmask", "Seal Mask");
	AddMenuItem(g_hPropMenuCosmetics, "securityshades", "Security Shades");
	AddMenuItem(g_hPropMenuCosmetics, "seeingdouble", "Seeing Double");
	AddMenuItem(g_hPropMenuCosmetics, "shoestringbudget", "Shoestring Budget");
	AddMenuItem(g_hPropMenuCosmetics, "shooterstintopi", "Shooter's Tin Topi");
	AddMenuItem(g_hPropMenuCosmetics, "sinnersshade", "Sinner's Shade");
	AddMenuItem(g_hPropMenuCosmetics, "sixpackabs", "Six Pack Abs");
	AddMenuItem(g_hPropMenuCosmetics, "skullislandtopper", "Skull Island Topper");
	AddMenuItem(g_hPropMenuCosmetics, "skyhighflyguy", "Sky High Fly Guy");
	AddMenuItem(g_hPropMenuCosmetics, "slopoke", "Slo-Poke");
	AddMenuItem(g_hPropMenuCosmetics, "sniperfishinghat", "Sniper Fishing Hat");
	AddMenuItem(g_hPropMenuCosmetics, "sniperpithhelmet", "Sniper Pith Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "sniperssnipinglass", "Sniper's Snipin' Glass");
	AddMenuItem(g_hPropMenuCosmetics, "soberstuntman", "Sober Stuntman");
	AddMenuItem(g_hPropMenuCosmetics, "soldierdrillhat", "Soldier Drill Hat");
	AddMenuItem(g_hPropMenuCosmetics, "soldiersamuraihat", "Soldier Samurai Hat");
	AddMenuItem(g_hPropMenuCosmetics, "soldiersslopescopers", "Soldier's Slope Scopers");
	AddMenuItem(g_hPropMenuCosmetics, "soldiersstash", "Soldier's Stash");
	AddMenuItem(g_hPropMenuCosmetics, "spectresspectacles", "Spectre's Spectacles");
	AddMenuItem(g_hPropMenuCosmetics, "spinechillingskull", "Spine-Chilling Skull");
	AddMenuItem(g_hPropMenuCosmetics, "spinechillingskull2011", "Spine-Chilling Skull 2011");
	AddMenuItem(g_hPropMenuCosmetics, "spinechillingskull2011style1", "Spine-Chilling Skull 2011 Style 1");
	AddMenuItem(g_hPropMenuCosmetics, "spinechillingskull2011style2", "Spine-Chilling Skull 2011 Style 2");
	AddMenuItem(g_hPropMenuCosmetics, "spinechillingskull2011style3", "Spine-Chilling Skull 2011 Style 3");
	AddMenuItem(g_hPropMenuCosmetics, "spiralsallet", "Spiral Sallet");
	AddMenuItem(g_hPropMenuCosmetics, "spyberet", "Spy Beret");
	AddMenuItem(g_hPropMenuCosmetics, "spyonimask", "Spy Oni Mask");
	AddMenuItem(g_hPropMenuCosmetics, "stahlhelm", "Stahlhelm");
	AddMenuItem(g_hPropMenuCosmetics, "stainlesspot", "Stainless Pot");
	AddMenuItem(g_hPropMenuCosmetics, "starboardcrusader", "Starboard Crusader");
	AddMenuItem(g_hPropMenuCosmetics, "statelysteeltoe", "Stately Steel Toe");
	AddMenuItem(g_hPropMenuCosmetics, "stealthsteeler", "Stealth Steeler");
	AddMenuItem(g_hPropMenuCosmetics, "steelpipes", "Steel Pipes");
	AddMenuItem(g_hPropMenuCosmetics, "steelshako", "Steel Shako");
	AddMenuItem(g_hPropMenuCosmetics, "stereoscopicshades", "Stereoscopic Shades");
	AddMenuItem(g_hPropMenuCosmetics, "stormspiritsjollyhat", "Storm Spirit's Jolly Hat");
	AddMenuItem(g_hPropMenuCosmetics, "stoutshako", "Stout Shako");
	AddMenuItem(g_hPropMenuCosmetics, "stovepipesnipershako", "Stovepipe Sniper Shako");
	AddMenuItem(g_hPropMenuCosmetics, "strontiumstovepipe", "Strontium Stove Pipe");
	AddMenuItem(g_hPropMenuCosmetics, "sultansceremonial", "Sultan's Ceremonial");
	AddMenuItem(g_hPropMenuCosmetics, "summerhat", "Summer Hat");
	AddMenuItem(g_hPropMenuCosmetics, "summershades", "Summer Shades");
	AddMenuItem(g_hPropMenuCosmetics, "surgeonsstahlhelm", "Surgeon's Stahlhelm");
	AddMenuItem(g_hPropMenuCosmetics, "surgeonsstethoscope", "Surgeon's Stethoscope");
	AddMenuItem(g_hPropMenuCosmetics, "swagmansswatter", "Swagman's Swatter");
	AddMenuItem(g_hPropMenuCosmetics, "sydneystrawboat", "Sydney Straw Boat");
	AddMenuItem(g_hPropMenuCosmetics, "tamoshanter", "Tam O'Shanter");
	AddMenuItem(g_hPropMenuCosmetics, "tartantyrolean", "Tartan Tyrolean");
	AddMenuItem(g_hPropMenuCosmetics, "tavishdegrootexperience", "Tavish DeGroot Experience");
	AddMenuItem(g_hPropMenuCosmetics, "teamcaptain", "Team Captain");
	AddMenuItem(g_hPropMenuCosmetics, "teutonictoque", "Teutonic Toque");
	AddMenuItem(g_hPropMenuCosmetics, "texastengallon", "Texas Ten Gallon");
	AddMenuItem(g_hPropMenuCosmetics, "texastingallon", "Texas Tin-Gallon");
	AddMenuItem(g_hPropMenuCosmetics, "tfbirthdayhat2011", "TF Birthday Hat 2011");
	AddMenuItem(g_hPropMenuCosmetics, "timelesstopper", "Timeless Topper");
	AddMenuItem(g_hPropMenuCosmetics, "titaniumtyrolean", "Titanium Tyrolean");
	AddMenuItem(g_hPropMenuCosmetics, "toughguystoque", "Tough Guy's Toque");
	AddMenuItem(g_hPropMenuCosmetics, "toughstuffmuffs", "Tough Stuff Muffs");
	AddMenuItem(g_hPropMenuCosmetics, "toweringpillarofhats", "Towering Pillar of Hats");
	AddMenuItem(g_hPropMenuCosmetics, "toweringtitaniumpillarofhats", "Towering Titanium Pillar of Hats");
	AddMenuItem(g_hPropMenuCosmetics, "toytailor", "Toy Tailor");
	AddMenuItem(g_hPropMenuCosmetics, "trafficcone", "Traffic Cone");
	AddMenuItem(g_hPropMenuCosmetics, "treasurehat1", "Treasure Hat 1");
	AddMenuItem(g_hPropMenuCosmetics, "treasurehat2", "Treasure Hat 2");
	AddMenuItem(g_hPropMenuCosmetics, "treasurehat3", "Treasure Hat 3");
	AddMenuItem(g_hPropMenuCosmetics, "trencherstopper", "Trencher's Topper");
	AddMenuItem(g_hPropMenuCosmetics, "triclops", "Triclops");
	AddMenuItem(g_hPropMenuCosmetics, "trophybelt", "Trophy Belt");
	AddMenuItem(g_hPropMenuCosmetics, "ttgglasses", "TTG Glasses");
	AddMenuItem(g_hPropMenuCosmetics, "ttgmaxhat", "TTG Max Hat");
	AddMenuItem(g_hPropMenuCosmetics, "tundratop", "Tundra Top");
	AddMenuItem(g_hPropMenuCosmetics, "tungstentoque", "Tungsten Toque");
	AddMenuItem(g_hPropMenuCosmetics, "tyrantshelm", "Tyrant's Helm");
	AddMenuItem(g_hPropMenuCosmetics, "tyrantiumhelmet", "Tyrantium Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "uclanka", "U-clank-a");
	AddMenuItem(g_hPropMenuCosmetics, "unusualcap", "Unusual Cap");
	AddMenuItem(g_hPropMenuCosmetics, "vintagetyrolean", "Vintage Tyrolean");
	AddMenuItem(g_hPropMenuCosmetics, "virtualrealityheadset", "Virtual Reality Headset");
	AddMenuItem(g_hPropMenuCosmetics, "virusdoctor", "Virus Doctor");
	AddMenuItem(g_hPropMenuCosmetics, "voodoojuju", "Voodoo Juju");
	AddMenuItem(g_hPropMenuCosmetics, "voodoojuju(slightreturn)", "Voodoo Juju (Slight Return)");
	AddMenuItem(g_hPropMenuCosmetics, "voxdiabolus", "Vox Diabolus");
	AddMenuItem(g_hPropMenuCosmetics, "wareagle", "War Eagle");
	AddMenuItem(g_hPropMenuCosmetics, "wargoggles", "War Goggles");
	AddMenuItem(g_hPropMenuCosmetics, "warhead", "War Head");
	AddMenuItem(g_hPropMenuCosmetics, "warpig", "War Pig");
	AddMenuItem(g_hPropMenuCosmetics, "warswornhelmet", "Warsworn Helmet");
	AddMenuItem(g_hPropMenuCosmetics, "wearmaster", "Weather Master");
	AddMenuItem(g_hPropMenuCosmetics, "wellroundedrifleman", "Well-Rounded Rifleman");
	AddMenuItem(g_hPropMenuCosmetics, "westernwear", "Western Wear");
	AddMenuItem(g_hPropMenuCosmetics, "wetworks", "Wet Works");
	AddMenuItem(g_hPropMenuCosmetics, "whirlywarrior", "Whirly Warrior");
	AddMenuItem(g_hPropMenuCosmetics, "wikicap", "Wiki Cap");
	AddMenuItem(g_hPropMenuCosmetics, "wingstick", "Wingstick");
	AddMenuItem(g_hPropMenuCosmetics, "worldtraveler", "World Traveler");
	AddMenuItem(g_hPropMenuCosmetics, "yeoiledbakerboy", "Ye Oiled Baker Boy");
	AddMenuItem(g_hPropMenuCosmetics, "yeoldebakerboy", "Ye Olde Baker Boy");
	AddMenuItem(g_hPropMenuCosmetics, "yetiparkcap", "Yeti Park Cap");
	AddMenuItem(g_hPropMenuCosmetics, "yetiparkhardhat", "Yeti Park Hardhat");

	// Prop Menu Comics Prop
	g_hPropMenuComic = CreateMenu(PropMenuComics);
	SetMenuTitle(g_hPropMenuComic, /*"TF2SB - */ "Comic Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuComic, true);
	AddMenuItem(g_hPropMenuComic, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuComic, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuComic, "air_intake", "Air Fan");
	AddMenuItem(g_hPropMenuComic, "barbell", "Barbell");
	AddMenuItem(g_hPropMenuComic, "sign_barricade001a", "Barricade for Signs");
	AddMenuItem(g_hPropMenuComic, "basketball_hoop", "Basketball Hoop");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01", "Battlements Sign");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_sm", "Battlements Sign (Small)");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_witharrow_L_sm", "Battlements Sign (small) <-");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_witharrow_R_sm", "Battlements Sign (small) ->");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_witharrow_l", "Battlements Sign <-");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_witharrow_r", "Battlements Sign ->");
	AddMenuItem(g_hPropMenuComic, "sign_gameplay01_hanging01", "Battlements Sign Hanging");
	AddMenuItem(g_hPropMenuComic, "beer_keg001", "Beer Keg");
	AddMenuItem(g_hPropMenuComic, "bird", "Bird");
	AddMenuItem(g_hPropMenuComic, "bookstand001", "Book Stand 1");
	AddMenuItem(g_hPropMenuComic, "bookstand002", "Book Stand 2");
	AddMenuItem(g_hPropMenuComic, "bookcase_132_01", "Bookcase 1");
	AddMenuItem(g_hPropMenuComic, "bookcase_132_02", "Bookcase 2");
	AddMenuItem(g_hPropMenuComic, "bookcase_132_03", "Bookcase 3");
	AddMenuItem(g_hPropMenuComic, "campervan", "Camper Van");
	AddMenuItem(g_hPropMenuComic, "chair", "Chair");
	AddMenuItem(g_hPropMenuComic, "chalkboard01", "Chalk Board");
	AddMenuItem(g_hPropMenuComic, "box_cluster01", "Cluster of Boxes");
	AddMenuItem(g_hPropMenuComic, "box_cluster02", "Cluster of Boxes 2");
	AddMenuItem(g_hPropMenuComic, "coffeemachine", "Coffee Machine");
	AddMenuItem(g_hPropMenuComic, "coffeepot", "Coffee Pot");
	AddMenuItem(g_hPropMenuComic, "computer_printer", "Computer Printer");
	AddMenuItem(g_hPropMenuComic, "couch_01", "Couch");
	AddMenuItem(g_hPropMenuComic, "milk_crate", "Crate of Milk");
	AddMenuItem(g_hPropMenuComic, "dumptruck", "Dump Truck");
	AddMenuItem(g_hPropMenuComic, "dumptruck_empty", "Dump Truck (Empty)");
	AddMenuItem(g_hPropMenuComic, "fire_extinguisher", "Fire Extinguisher");
	AddMenuItem(g_hPropMenuComic, "fire_extinguisher_cabinet01", "Fire Extinguisher Cabinet");
	AddMenuItem(g_hPropMenuComic, "ingot001", "Gold Ingot");
	AddMenuItem(g_hPropMenuComic, "baby_grand_01", "Grand Piano");
	AddMenuItem(g_hPropMenuComic, "hardhat001", "Hard Hat");
	AddMenuItem(g_hPropMenuComic, "haybale", "Haybale");
	AddMenuItem(g_hPropMenuComic, "horseshoe001", "Horse Shoe");
	AddMenuItem(g_hPropMenuComic, "hose001", "Hose");
	AddMenuItem(g_hPropMenuComic, "hubcap", "Hubcap");
	AddMenuItem(g_hPropMenuComic, "kitchen_shelf", "Kitchen Shelf");
	AddMenuItem(g_hPropMenuComic, "kitchen_stove", "Kitchen Stove");
	AddMenuItem(g_hPropMenuComic, "lunchbag", "Lunchbag");
	AddMenuItem(g_hPropMenuComic, "metalbucket001", "Metal Bucket");
	AddMenuItem(g_hPropMenuComic, "milkjug001", "Milk Jug");
	AddMenuItem(g_hPropMenuComic, "miningcrate001", "Mining Crate 1");
	AddMenuItem(g_hPropMenuComic, "miningcrate002", "Mining Crate 2");
	AddMenuItem(g_hPropMenuComic, "mop_and_bucket", "Mop and Bucket");
	AddMenuItem(g_hPropMenuComic, "mvm_museum_case", "Museum Case");
	AddMenuItem(g_hPropMenuComic, "signpost001", "No Swimming Sign");
	AddMenuItem(g_hPropMenuComic, "resupply_locker", "Non-working Resupply Locker");
	AddMenuItem(g_hPropMenuComic, "oilcan01", "Oilcan 1");
	AddMenuItem(g_hPropMenuComic, "oilcan01b", "Oilcan 1b");
	AddMenuItem(g_hPropMenuComic, "oilcan02", "Oilcan 2");
	AddMenuItem(g_hPropMenuComic, "oildrum", "Oildrum");
	AddMenuItem(g_hPropMenuComic, "padlock", "Padlock");
	AddMenuItem(g_hPropMenuComic, "paint_can001", "Paint Can 1");
	AddMenuItem(g_hPropMenuComic, "paint_can002", "Paint Can 2");
	AddMenuItem(g_hPropMenuComic, "painting_02", "Painting 1");
	AddMenuItem(g_hPropMenuComic, "painting_03", "Painting 2");
	AddMenuItem(g_hPropMenuComic, "painting_04", "Painting 3");
	AddMenuItem(g_hPropMenuComic, "painting_05", "Painting 4");
	AddMenuItem(g_hPropMenuComic, "painting_06", "Painting 5");
	AddMenuItem(g_hPropMenuComic, "painting_07", "Painting 6");
	AddMenuItem(g_hPropMenuComic, "picnic_table", "Picnic Table");
	AddMenuItem(g_hPropMenuComic, "bookpile_01", "Pile of Books");
	AddMenuItem(g_hPropMenuComic, "pill_bottle01", "Pill Bottle");
	AddMenuItem(g_hPropMenuComic, "portrait_01", "Portrait Painting");
	AddMenuItem(g_hPropMenuComic, "computer_low", "Potato Computer");
	AddMenuItem(g_hPropMenuComic, "propane_tank_tall01", "Propane Tank Tall");
	AddMenuItem(g_hPropMenuComic, "sack_flat", "Sack Flat");
	AddMenuItem(g_hPropMenuComic, "sack_stack", "Sack Stack");
	AddMenuItem(g_hPropMenuComic, "sack_stack_pallet", "Sack Stack's Pallet");
	AddMenuItem(g_hPropMenuComic, "shelf_props01", "Shelf of Tools");
	AddMenuItem(g_hPropMenuComic, "sign_wood_cap001", "Sign Wood Cap 1");
	AddMenuItem(g_hPropMenuComic, "sign_wood_cap002", "Sign Wood Cap 2");
	AddMenuItem(g_hPropMenuComic, "bullskull001", "Skull of a bull");
	AddMenuItem(g_hPropMenuComic, "target_scout", "Target Scout");
	AddMenuItem(g_hPropMenuComic, "target_soldier", "Target Soldier");
	AddMenuItem(g_hPropMenuComic, "target_pyro", "Target Pyro");
	AddMenuItem(g_hPropMenuComic, "target_demoman", "Target Demoman");
	AddMenuItem(g_hPropMenuComic, "target_heavy", "Target Heavy");
	AddMenuItem(g_hPropMenuComic, "target_engineer", "Target Engineer");
	AddMenuItem(g_hPropMenuComic, "target_medic", "Target Medic");
	AddMenuItem(g_hPropMenuComic, "target_sniper", "Target Sniper");
	AddMenuItem(g_hPropMenuComic, "target_spy", "Target Spy");
	AddMenuItem(g_hPropMenuComic, "tv001", "TV");
	AddMenuItem(g_hPropMenuComic, "uniform_locker", "Uniform Locker");
	AddMenuItem(g_hPropMenuComic, "uniform_locker_pj", "Uniform Locker 2");
	AddMenuItem(g_hPropMenuComic, "wastebasket01", "Waste Basket");
	AddMenuItem(g_hPropMenuComic, "weathervane001", "Weather Vane");
	AddMenuItem(g_hPropMenuComic, "weight_scale", "Weight Scale");
	AddMenuItem(g_hPropMenuComic, "welding_machine01", "Welding Machine");
	AddMenuItem(g_hPropMenuComic, "pick001", "Wood Pickaxe");
	
	// Prop Menu Constructions Prop
	g_hPropMenuConstructions = CreateMenu(PropMenuConstructions);
	SetMenuTitle(g_hPropMenuConstructions, /*"TF2SB - */ "Construction Props"); // \nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuConstructions, true);
	AddMenuItem(g_hPropMenuConstructions, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenuConstructions, "emptyspace", "", ITEMDRAW_IGNORE);
	AddMenuItem(g_hPropMenuConstructions, "barrel_flatbed01", "Barrel Flatbed");
	AddMenuItem(g_hPropMenuConstructions, "bench001a", "Bench 1");
	AddMenuItem(g_hPropMenuConstructions, "bench001b", "Bench 2");
	AddMenuItem(g_hPropMenuConstructions, "chimney003", "Chimney 1");
	AddMenuItem(g_hPropMenuConstructions, "chimney005", "Chimney 2");
	AddMenuItem(g_hPropMenuConstructions, "chimney006", "Chimney 3");
	AddMenuItem(g_hPropMenuConstructions, "concrete_block001", "Concrete Block");
	AddMenuItem(g_hPropMenuConstructions, "concrete_pipe001", "Concrete Pipe 1");
	AddMenuItem(g_hPropMenuConstructions, "concrete_pipe002", "Concrete Pipe 2");
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container", "Container 1");
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container_01b", "Container 2");
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container_01c", "Container 3");
	AddMenuItem(g_hPropMenuConstructions, "cap_point_base", "Control Point");
	AddMenuItem(g_hPropMenuConstructions, "control_room_console01", "Control Room Console 1");
	AddMenuItem(g_hPropMenuConstructions, "control_room_console02", "Control Room Console 2");
	AddMenuItem(g_hPropMenuConstructions, "control_room_console03", "Control Room Console 3");
	AddMenuItem(g_hPropMenuConstructions, "control_room_console04", "Control Room Console 4");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal001", "Corrugated Metal 1");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal002", "Corrugated Metal 2");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal003", "Corrugated Metal 3");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal004", "Corrugated Metal 4");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal005", "Corrugated Metal 5");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal006", "Corrugated Metal 6");
	AddMenuItem(g_hPropMenuConstructions, "corrugated_metal007", "Corrugated Metal 7");
	AddMenuItem(g_hPropMenuConstructions, "crane_platform001", "Crane Platform");
	AddMenuItem(g_hPropMenuConstructions, "crane_platform001b", "Crane Platform 2");
	AddMenuItem(g_hPropMenuConstructions, "barrel02", "Dark Barrel");
	AddMenuItem(g_hPropMenuConstructions, "drain_pipe001", "Drain Pipe");
	AddMenuItem(g_hPropMenuConstructions, "groundlight001", "Ground Light 1");
	AddMenuItem(g_hPropMenuConstructions, "groundlight002", "Ground Light 2");
	AddMenuItem(g_hPropMenuConstructions, "ladder001", "Ladder");
	AddMenuItem(g_hPropMenuConstructions, "lantern001", "Lantern (on)");
	AddMenuItem(g_hPropMenuConstructions, "lantern001_off", "Lantern (off)");
	AddMenuItem(g_hPropMenuConstructions, "keg_large", "Large Keg");
	AddMenuItem(g_hPropMenuConstructions, "locker001", "Locker");
	AddMenuItem(g_hPropMenuConstructions, "saw_blade_large", "Monster Saw Blade");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal001", "Roof Metal 1");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal002", "Roof Metal 2");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal003", "Roof Metal 3");
	AddMenuItem(g_hPropMenuConstructions, "roof_vent001", "Roof Vent");
	AddMenuItem(g_hPropMenuConstructions, "saw_blade", "Saw Blade");
	AddMenuItem(g_hPropMenuConstructions, "sink001", "Sink");
	AddMenuItem(g_hPropMenuConstructions, "sniper_fence01", "Sniper Fence 1");
	AddMenuItem(g_hPropMenuConstructions, "sniper_fence02", "Sniper Fence 2");
	AddMenuItem(g_hPropMenuConstructions, "spool_rope", "Spool (rope)");
	AddMenuItem(g_hPropMenuConstructions, "spool_wire", "Spool (wire)");
	AddMenuItem(g_hPropMenuConstructions, "stairs_wood001a", "Stair Wood 1");
	AddMenuItem(g_hPropMenuConstructions, "stairs_wood001b", "Stair Wood 2");
	AddMenuItem(g_hPropMenuConstructions, "table_01", "Table 1");
	AddMenuItem(g_hPropMenuConstructions, "table_02", "Table 2");
	AddMenuItem(g_hPropMenuConstructions, "table_03", "Table 3");
	AddMenuItem(g_hPropMenuConstructions, "tank001", "Tank 1");
	AddMenuItem(g_hPropMenuConstructions, "tank002", "Tank 2");
	AddMenuItem(g_hPropMenuConstructions, "telephone001", "Telephone");
	AddMenuItem(g_hPropMenuConstructions, "telephonepole001", "Telephone Pole");
	AddMenuItem(g_hPropMenuConstructions, "thermos", "Thermos");
	AddMenuItem(g_hPropMenuConstructions, "tire001", "Tire 1");
	AddMenuItem(g_hPropMenuConstructions, "tire002", "Tire 2");
	AddMenuItem(g_hPropMenuConstructions, "tire003", "Tire 3");
	AddMenuItem(g_hPropMenuConstructions, "tracks001", "Tracks 1");
	AddMenuItem(g_hPropMenuConstructions, "tractor_01", "Tractor Wheel");
	AddMenuItem(g_hPropMenuConstructions, "train_engine_01", "Train Engine");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel001", "Train Wheel 1");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel002", "Train Wheel 2");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel003", "Train Wheel 3");
	AddMenuItem(g_hPropMenuConstructions, "vent001", "Vent");
	AddMenuItem(g_hPropMenuConstructions, "wagonwheel001", "Wagon Wheel");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel", "Water Barrel");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_large", "Water Barrel (large)");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster", "Water Barrel Cluster 1");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster2", "Water Barrel Cluster 2");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster3", "Water Barrel Cluster 3");
	AddMenuItem(g_hPropMenuConstructions, "waterpump001", "Water Pump");
	AddMenuItem(g_hPropMenuConstructions, "water_spigot", "Water Spigot");
	AddMenuItem(g_hPropMenuConstructions, "wood_crate_01", "Wood Crate");
	AddMenuItem(g_hPropMenuConstructions, "pallet001", "Wood Pallet");
	AddMenuItem(g_hPropMenuConstructions, "wood_pile", "Wood Pile");
	AddMenuItem(g_hPropMenuConstructions, "woodpile_indoor", "Wood Pile Indoor");
	AddMenuItem(g_hPropMenuConstructions, "wood_pile_short", "Wood Pile Short");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform1", "Wood Platform 1");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform2", "Wood Platform 2");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform3", "Wood Platform 3");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs128", "Wood Stairs 128");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs48", "Wood Stairs 48");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs96", "Wood Stairs 96");
	AddMenuItem(g_hPropMenuConstructions, "wooden_barrel", "Wooden Barrel");
	AddMenuItem(g_hPropMenuConstructions, "work_table001", "Work Table");
	AddMenuItem(g_hPropMenuConstructions, "barrel01", "Yellow Barrel");
	AddMenuItem(g_hPropMenuConstructions, "barrel03", "Yellow Barrel 2");

	// updater
	#if defined _updater_included
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	#endif

	// config
	AutoExecConfig();
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++) {
<<<<<<< HEAD
    	if(IsClientConnected(i))
=======
	if(IsClientConnected(i))
>>>>>>> 0681785044414eb0f74decbbb9e4f5bab2104d98
		{
			if(i != 0)
			{
				FakeClientCommand(i, "sm_delall");
			}
		}
  }
}

public void OnLibraryAdded(const char[] name)
{
	#if defined _updater_included
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	#endif
}

// public Action TF2SB_DelayedStuff(Handle useless) // what in the goddamn?
public void OnAllPluginsLoaded()
{
	char buffer[512];

	g_hMenuCredits = CreateMenu(TF2SBCred1);
	SetMenuExitButton(g_hMenuCredits, false);
	
	Format(buffer, sizeof(buffer), "Credits\n\n\n");
	StrCat(buffer, sizeof(buffer), " Coders:\n");
	StrCat(buffer, sizeof(buffer), "   Lead\n");
	StrCat(buffer, sizeof(buffer), "   ✔TatLead\n");
	StrCat(buffer, sizeof(buffer), "   _diamondburned_\n");
	StrCat(buffer, sizeof(buffer), "   Danct12\n");
	StrCat(buffer, sizeof(buffer), "   DaRkWoRlD\n");

	StrCat(buffer, sizeof(buffer), " Translators:\n");
	StrCat(buffer, sizeof(buffer), "   Danct12, Lead - English\n");
	StrCat(buffer, sizeof(buffer), "   ✔TatLead - Traditional Chinese, Simplified Chinese\n");
	StrCat(buffer, sizeof(buffer), "   Danct12 - Vietnamese\n");
	StrCat(buffer, sizeof(buffer), "   RedlineLucario - Russian\n");
	StrCat(buffer, sizeof(buffer), "   RobertROU - French\n");
	StrCat(buffer, sizeof(buffer), "   Uncle Dispenser TF2SP - Spanish\n");

	StrCat(buffer, sizeof(buffer), " Testers:\n");
	StrCat(buffer, sizeof(buffer), "   periodicJudgement\n");
	StrCat(buffer, sizeof(buffer), "   Lecubon\n");
	StrCat(buffer, sizeof(buffer), "   iKiroZz\n");
	StrCat(buffer, sizeof(buffer), "   Lazyneer\n");
	StrCat(buffer, sizeof(buffer), "   Cecil\n");
	StrCat(buffer, sizeof(buffer), "   TESTBOT#7\n");

	StrCat(buffer, sizeof(buffer), " Additional:\n");
	StrCat(buffer, sizeof(buffer), "    Huong Tram\n\n");
	StrCat(buffer, sizeof(buffer), "  Buildmod:\n");
	StrCat(buffer, sizeof(buffer), "    hjkwe654\n");
	StrCat(buffer, sizeof(buffer), "    greenteaf0718\n\n");

	AddMenuItem(g_hPropMenu, "removeprops", "| Remove");
	AddMenuItem(g_hPropMenu, "constructprops", "Construction Props");
	AddMenuItem(g_hPropMenu, "comicprops", "Comic Props");
	AddMenuItem(g_hPropMenu, "leadprops", "Special Props");
	AddMenuItem(g_hPropMenu, "requestedprops", "Requested Props");
	AddMenuItem(g_hPropMenu, "pickupprops", "Pickup Props");
	AddMenuItem(g_hPropMenu, "weaponsprops", "Weapons Props");
	AddMenuItem(g_hPropMenu, "cosmeticprops", "Cosmetics Props");
	AddMenuItem(g_hPropMenu, "hl2props", "Miscellaneous Props");
	AddMenuItem(g_hPropMenu, "donatorprops", "Donator Props");

	AddMenuItem(g_hEquipMenu, "toolgun", "--SANDBOX WEAPONS--", ITEMDRAW_DISABLED);

	if(GetCommandFlags("sm_sbpg") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hEquipMenu, "physgun2", "Physics Gun V2");
	}

	if(GetCommandFlags("sm_pg") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hEquipMenu, "physgunv2", "Physics Gun V3");
	}

	if(GetCommandFlags("sm_physgun") != INVALID_FCVAR_FLAGS)
	{
    	AddMenuItem(g_hEquipMenu, "physgunnew", "Physics Gun V5");
	}  

	if(GetCommandFlags("portalgun") != INVALID_FCVAR_FLAGS) // https://forums.alliedmods.net/showthread.php?t=237940
	{
    	AddMenuItem(g_hEquipMenu, "portalgun", "Portal Gun");
	} 

	if(GetCommandFlags("sm_ss") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hMainMenu, "savesys", "Save System");
	}

	if(GetCommandFlags("sm_tf2sbperms") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hMainMenu, "permissions", "Permission System");
	}

	/*if(GetCommandFlags("sm_physgun") == INVALID_FCVAR_FLAGS && GetCommandFlags("sm_pg") == INVALID_FCVAR_FLAGS && GetCommandFlags("sm_sbpg") == INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hEquipMenu, "physgun", "Physics Gun V1");
		StrCat(buffer, sizeof(buffer), "  Gravity Gun:\n");
		StrCat(buffer, sizeof(buffer), "    FlaminSarge\n");
		StrCat(buffer, sizeof(buffer), "    javalia\n\n");	
	}*/

	if(GetCommandFlags("sm_teleporter") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hPropMenuLead, "teleporter", "Teleporter");
	}

	if(GetCommandFlags("sm_cam") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hPropMenuLead, "camera", "Camera");
		AddMenuItem(g_hPropMenuLead, "securitybank", "Security Bank");
	}

	if(GetCommandFlags("sm_laser") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hPropMenuLead, "laser", "Laser");
	}

	AddMenuItem(g_hPropMenuLead, "sdoor", "Sliding Door");
	AddMenuItem(g_hPropMenuLead, "sdoor2", "Blast Door");


	if(GetCommandFlags("sm_tg") != INVALID_FCVAR_FLAGS)
	{
		AddMenuItem(g_hEquipMenu, "toolgun", "Tool Gun");
		/*StrCat(buffer, sizeof(buffer), "  Toolgun:\n");
		StrCat(buffer, sizeof(buffer), "    Pelipoika\n");*/
	}

	RegAdminCmd("sm_g", Command_PhysGun, 0);

	StrCat(buffer, sizeof(buffer), "Thank you so much for playing TF2SB!\n");

	SetMenuTitle(g_hMenuCredits, buffer);
	AddMenuItem(g_hMenuCredits, "back", "Back");
	
	RegAdminCmd("sm_tf2sb", Command_TF2SBCred, 0);
	RegAdminCmd("sm_credits", Command_TF2SBCred, 0);

	AddMenuItem(g_hMainMenu, "credits", "Credits");
}

public Action Command_TF2SBCred(int client, int args)
{
	DisplayMenu(g_hMenuCredits, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int TF2SBCred1(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "back"))
		{
			DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
		}
	}
}

stock float GetEntitiesDistance(int ent1, int ent2)
{
	float orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	float orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);
	
	return GetVectorDistance(orig1, orig2);
}

public void OnMapStart()
{
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("buttons/button3.wav", true);
	// PrecacheSound("ui/panel_open.wav", true);
	PrecacheSound("ui/panel_close.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
	for (int i = 1; i < MaxClients; i++)
	{
		g_szConnectedClient[i] = "";
		if (Build_IsClientValid(i, i))
			GetClientAuthId(i, AuthId_Steam2, g_szConnectedClient[i], sizeof(g_szConnectedClient));
	}
	
	//g_iHalo = PrecacheModel("materials/sprites/halo01.vmt");
	//g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	//g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt");
	//	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	
	// g_PhysGunModel = PrecacheModel("models/weapons/v_superphyscannon.mdl");
	
	AutoExecConfig();
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, g_szConnectedClient[client], sizeof(g_szConnectedClient));
}

public void OnClientDisconnect(int client)
{
	if (!StrEqual(g_szConnectedClient[client], "", false)) {
		g_szConnectedClient[client] = "";
		FakeClientCommand(client, "sm_delall");
	}

	g_bBuffer[client] = false;
}

public void OnClientConnected(int client)
{
	g_bGodmode[client] = true;
}

public Action Timer_Disconnect(Handle timer, Handle hPack)
{
	ResetPack(hPack);
	int client = ReadPackCell(hPack);
	
	int iCount;
	for (int iCheck = client; iCheck < MAX_HOOK_ENTITIES; iCheck++)
	{
		if (IsValidEntity(iCheck))
		{
			if (g_iTempOwner[iCheck] == client)
			{
				AcceptEntityInput(iCheck, "Kill", -1);
				iCount++;
			}
		}
	}
	return;
}

public Action Command_Copy(int client, int args)
{
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	int iEntity = Build_ClientAimEntity(client, true, true);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (!Build_IsAdmin(client, true)) {
		if (GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (!Build_IsEntityOwner(client, iEntity, true))
		return Plugin_Handled;
	
	if (g_bCopyIsRunning[client]) {
		Build_PrintToChat(client, "%t", "alreadycopy");
		return Plugin_Handled;
	}
	
	char szClass[33];
	bool bCanCopy = false;
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	for (int i = 0; i < sizeof(CopyableProps); i++) {
		if (StrEqual(szClass, CopyableProps[i], false))
			bCanCopy = true;
	}
	
	bool IsDoll = false;
	if (StrEqual(szClass, "5") || StrEqual(szClass, "player")) {
		if (Build_IsAdmin(client, true)) {
			g_iCopyTarget[client] = CreateEntityByName("5");
			IsDoll = true;
		} else {
			return Plugin_Handled;
		}
	} else {
		if (StrEqual(szClass, "func_physbox") && !Build_IsAdmin(client, true)) {
			return Plugin_Handled;
		}
		
		// Physics exploit can be introduced by copying physics objects
		// if (StrEqual(szClass, "prop_dynamic")) {
		szClass = "prop_physics_override";
		// }
		
		g_iCopyTarget[client] = CreateEntityByName(szClass);
	}
	
	if (Build_RegisterEntityOwner(g_iCopyTarget[client], client, IsDoll)) {
		if (bCanCopy) {
			float fEntityOrigin[3], fEntityAngle[3];
			char szModelName[128];
			char szPropName[128];
			char szColorR[20], szColorG[20], szColorB[20], szColor[3][128], szColor2[255];
			
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
			GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
			GetEntPropString(iEntity, Prop_Data, "m_iName", szPropName, sizeof(szPropName));

			DispatchKeyValue(g_iCopyTarget[client], "model", szModelName);
			SetEntPropString(g_iCopyTarget[client], Prop_Data, "m_iName", szPropName);
			
			GetEdictClassname(g_iCopyTarget[client], szClass, sizeof(szClass));

			if (StrEqual(szClass, "prop_physics_override")) {
				SetEntProp(g_iCopyTarget[client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[client], Prop_Data, "m_nSolidType", 6);
			}
			
			/*if (StrEqual(szClass, "prop_dynamic_override")) {
				SetEntProp(g_iCopyTarget[client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[client], Prop_Data, "m_nSolidType", 6);
			}*/
			
			DispatchSpawn(g_iCopyTarget[client]);
			TeleportEntity(g_iCopyTarget[client], fEntityOrigin, fEntityAngle, NULL_VECTOR);
			
			// if (Phys_IsPhysicsObject(g_iCopyTarget[client]))
			//	Phys_EnableMotion(g_iCopyTarget[client], false);
			
			GetCmdArg(1, szColorR, sizeof(szColorR));
			GetCmdArg(2, szColorG, sizeof(szColorG));
			GetCmdArg(3, szColorB, sizeof(szColorB));
			
			DispatchKeyValue(g_iCopyTarget[client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[client], "renderamt", "150");
			DispatchKeyValue(g_iCopyTarget[client], "renderfx", "4");
			
			if (args > 1) {
				szColor[0] = szColorR;
				szColor[1] = szColorG;
				szColor[2] = szColorB;
				ImplodeStrings(szColor, 3, " ", szColor2, 255);
				DispatchKeyValue(g_iCopyTarget[client], "rendercolor", szColor2);
			} else {
				DispatchKeyValue(g_iCopyTarget[client], "rendercolor", "50 255 255");
			}
			g_bCopyIsRunning[client] = true;
			
			CreateTimer(0.01, Timer_CopyRing, client);
			CreateTimer(0.01, Timer_CopyBeam, client);
			CreateTimer(0.02, Timer_CopyMain, client);
			return Plugin_Handled;
		} else {
			return Plugin_Handled;
		}
	} else {
		RemoveEdict(g_iCopyTarget[client]);
		return Plugin_Handled;
	}
}

public Action Command_Paste(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client))
		return Plugin_Handled;
	
	g_bCopyIsRunning[client] = false;
	return Plugin_Handled;
}

public Action Timer_CopyBeam(Handle timer, any client)
{
	if (IsValidEntity(g_iCopyTarget[client]) && Build_IsClientValid(client, client))
	{
		float fOriginPlayer[3], fOriginEntity[3];
		
		GetClientAbsOrigin(client, g_fCopyPlayerOrigin[client]);
		GetClientAbsOrigin(client, fOriginPlayer);
		
		GetEntPropVector(g_iCopyTarget[client], Prop_Data, "m_vecOrigin", fOriginEntity);
		fOriginPlayer[2] += 50;
		
		int iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = GetRandomInt(255, 255);
		
		/* TE_SetupBeamPoints(fOriginEntity, fOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll(); */
		
		if (g_bCopyIsRunning[client])
			CreateTimer(0.01, Timer_CopyBeam, client);
	}
}

public Action Timer_CopyRing(Handle timer, any client)
{
	if (IsValidEntity(g_iCopyTarget[client]) && Build_IsClientValid(client, client))
	{
		float fOriginEntity[3];
		
		GetEntPropVector(g_iCopyTarget[client], Prop_Data, "m_vecOrigin", fOriginEntity);
		
		int iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(254, 255);
		iColor[2] = GetRandomInt(254, 255);
		iColor[3] = GetRandomInt(250, 255);
		
		/*TE_SetupBeamRingPoint(fOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(fOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();*/
		
		if (g_bCopyIsRunning[client])
			CreateTimer(0.3, Timer_CopyRing, client);
	}
}

public Action Timer_CopyMain(Handle timer, any client)
{
	if (IsValidEntity(g_iCopyTarget[client]) && Build_IsClientValid(client, client))
	{
		float fOriginEntity[3], fOriginPlayer[3];
		
		GetEntPropVector(g_iCopyTarget[client], Prop_Data, "m_vecOrigin", fOriginEntity);
		GetClientAbsOrigin(client, fOriginPlayer);
		
		fOriginEntity[0] += fOriginPlayer[0] - g_fCopyPlayerOrigin[client][0];
		fOriginEntity[1] += fOriginPlayer[1] - g_fCopyPlayerOrigin[client][1];
		fOriginEntity[2] += fOriginPlayer[2] - g_fCopyPlayerOrigin[client][2];
		
		/*if (Phys_IsPhysicsObject(g_iCopyTarget[client])) {
			Phys_EnableMotion(g_iCopyTarget[client], false);
			Phys_Sleep(g_iCopyTarget[client]);
		}*/
		SetEntityMoveType(g_iCopyTarget[client], MOVETYPE_VPHYSICS);
		TeleportEntity(g_iCopyTarget[client], fOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bCopyIsRunning[client])
			CreateTimer(0.001, Timer_CopyMain, client);
		else {
			/*if (Phys_IsPhysicsObject(g_iCopyTarget[client])) {
				Phys_EnableMotion(g_iCopyTarget[client], false);
				Phys_Sleep(g_iCopyTarget[client]);
			}*/
			SetEntityMoveType(g_iCopyTarget[client], MOVETYPE_VPHYSICS);
			
			DispatchKeyValue(g_iCopyTarget[client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[client], "renderamt", "255");
			DispatchKeyValue(g_iCopyTarget[client], "renderfx", "0");
			DispatchKeyValue(g_iCopyTarget[client], "rendercolor", "255 255 255");
		}
	}
}

public Action Timer_CoolDown(Handle hTimer, any iBuffer)
{
	int iClient = GetClientFromSerial(iBuffer);
	
	if (g_bBuffer[iClient])g_bBuffer[iClient] = false;
}

public Action Command_OpenableDoorProp(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	int iDoor = CreateEntityByName("prop_door_rotating");
	if (Build_RegisterEntityOwner(iDoor, client)) {
		char szRange[33], szBrightness[33], szColorR[33], szColorG[33], szColorB[33];
		char szNamePropDoor[64];
		float fOriginAim[3];
		GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(2, szBrightness, sizeof(szBrightness));
		GetCmdArg(3, szColorR, sizeof(szColorR));
		GetCmdArg(4, szColorG, sizeof(szColorG));
		GetCmdArg(5, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(client, fOriginAim);
		fOriginAim[2] += 50;
		
		if (!IsModelPrecached("models/props_manor/doorframe_01_door_01a.mdl"))
			PrecacheModel("models/props_manor/doorframe_01_door_01a.mdl");
		
		DispatchKeyValue(iDoor, "model", "models/props_manor/doorframe_01_door_01a.mdl");
		DispatchKeyValue(iDoor, "distance", "90");
		DispatchKeyValue(iDoor, "speed", "100");
		DispatchKeyValue(iDoor, "returndelay", "-1");
		DispatchKeyValue(iDoor, "dmg", "-20");
		DispatchKeyValue(iDoor, "opendir", "0");
		DispatchKeyValue(iDoor, "spawnflags", "8192");
		//DispatchKeyValue(iDoor, "OnFullyOpen", "!caller,close,,0,-1");
		DispatchKeyValue(iDoor, "hardware", "1");
		
		DispatchSpawn(iDoor);
		
		TeleportEntity(iDoor, fOriginAim, NULL_VECTOR, NULL_VECTOR);
		
		Format(szNamePropDoor, sizeof(szNamePropDoor), "TF2SB_Door%i", GetRandomInt(1000, 5000));
		DispatchKeyValue(iDoor, "targetname", szNamePropDoor);
		SetVariantString(szNamePropDoor);
	} else
		RemoveEdict(iDoor);
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_propdoor", szArgs);
	return Plugin_Handled;
}

public Action Command_kill(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	ForcePlayerSuicide(client);
	
	//if (GetCmdArgs() > 0)
	//	Build_PrintToChat(client, "Don't use unneeded args in kill");
	
	return Plugin_Handled;
}

public Action Command_ReloadAIOPlugin(int client, int args) // 😂👌
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	// ReadProps();
	Build_PrintToAll("TF2 Sandbox has updated!");
	Build_PrintToAll("Please type !build to begin building!");
	
	//if (GetCmdArgs() > 0)
	//	Build_PrintToChat(client, "Don't use unneeded args in kill");
	
	return Plugin_Handled;
}

public Action Command_Render(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 5) {
		
		Build_PrintToChat(client, "%t: !render <fx amount> <fx> <R> <G> <B>", "usage");
		// Build_PrintToChat(client, "Ex. Flashing Green: !render 150 4 15 255 0");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szRenderAlpha[20], szRenderFX[20], szColorRGB[20][3], szColors[128];
		GetCmdArg(1, szRenderAlpha, sizeof(szRenderAlpha));
		GetCmdArg(2, szRenderFX, sizeof(szRenderFX));
		GetCmdArg(3, szColorRGB[0], sizeof(szColorRGB));
		GetCmdArg(4, szColorRGB[1], sizeof(szColorRGB));
		GetCmdArg(5, szColorRGB[2], sizeof(szColorRGB));
		
		Format(szColors, sizeof(szColors), "%s %s %s", szColorRGB[0], szColorRGB[1], szColorRGB[2]);
		if (StringToInt(szRenderAlpha) < 1)
			szRenderAlpha = "1";
		DispatchKeyValue(iEntity, "rendermode", "5");
		DispatchKeyValue(iEntity, "renderamt", szRenderAlpha);
		DispatchKeyValue(iEntity, "renderfx", szRenderFX);
		DispatchKeyValue(iEntity, "rendercolor", szColors);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_render", szArgs);
	return Plugin_Handled;
}

public Action Command_Color(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 3) {
		Build_PrintToChat(client, "%t: !color <R> <G> <B>", "usage");
		// Build_PrintToChat(client, "Ex: Green: !color 0 255 0");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szColorRGB[20][3], szColors[33];
		GetCmdArg(1, szColorRGB[0], sizeof(szColorRGB));
		GetCmdArg(2, szColorRGB[1], sizeof(szColorRGB));
		GetCmdArg(3, szColorRGB[2], sizeof(szColorRGB));
		
		Format(szColors, sizeof(szColors), "%s %s %s", szColorRGB[0], szColorRGB[1], szColorRGB[2]);
		DispatchKeyValue(iEntity, "rendermode", "5");
		DispatchKeyValue(iEntity, "renderamt", "255");
		DispatchKeyValue(iEntity, "renderfx", "0");
		DispatchKeyValue(iEntity, "rendercolor", szColors);
		
		float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		/*TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_color", szArgs);
	return Plugin_Handled;
}

public Action Command_PropScale(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !propscale <number>", "usage");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		//float Scale2  = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
		char szPropScale[33];
		GetCmdArg(1, szPropScale, sizeof(szPropScale));
		
		if (StringToInt(szPropScale) > 3) {
			Build_PrintToChat(client, "%t3", "maxscale");
			return Plugin_Handled;
		}

		if (StringToFloat(szPropScale) < 0.1) {
			Build_PrintToChat(client, "%t0.1", "higherthan");
			return Plugin_Handled;
		}

		float Scale = StringToFloat(szPropScale);
		
		SetVariantString(szPropScale);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", Scale);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_propscale", szArgs);
	return Plugin_Handled;
}

public Action Command_Skin(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !skin <number>", "usage");
		Build_PrintToChat(client, "%t", "skins");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szSkin[33];
		GetCmdArg(1, szSkin, sizeof(szSkin));
		
		SetVariantString(szSkin);
		AcceptEntityInput(iEntity, "skin", iEntity, client, 0);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_skin", szArgs);
	return Plugin_Handled;
}

public Action Command_Rotate(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !rotate/!r <x> <y> <z>", "usage");
		// Build_PrintToChat(client, "Ex: !rotate 0 90 0");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szAngleX[8], szAngleY[8], szAngleZ[8];
		float fEntityOrigin[3], fEntityAngle[3];
		GetCmdArg(1, szAngleX, sizeof(szAngleX));
		GetCmdArg(2, szAngleY, sizeof(szAngleY));
		GetCmdArg(3, szAngleZ, sizeof(szAngleZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		fEntityAngle[0] += StringToFloat(szAngleX);
		fEntityAngle[1] += StringToFloat(szAngleY);
		fEntityAngle[2] += StringToFloat(szAngleZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_rotate", szArgs);
	return Plugin_Handled;
}

public Action Command_Fly(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true) || !Build_AllowFly(client))
		return Plugin_Handled;
	
	if (GetEntityMoveType(client) != MOVETYPE_NOCLIP)
	{
		Build_PrintToChat(client, "Noclip %t", "on");
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	else
	{
		Build_PrintToChat(client, "Noclip %t", "off");
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	return Plugin_Handled;
}

public Action Command_SimpleLight(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	/*if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));*/
	FakeClientCommand(client, "sm_ld 7 255 255 255");
	
	return Plugin_Handled;
}

public Action Command_AccurateRotate(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !ar <x> <y> <z>", "usage");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szRotateX[33], szRotateY[33], szRotateZ[33];
		float fEntityOrigin[3], fEntityAngle[3];
		GetCmdArg(1, szRotateX, sizeof(szRotateX));
		GetCmdArg(2, szRotateY, sizeof(szRotateY));
		GetCmdArg(3, szRotateZ, sizeof(szRotateZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		fEntityAngle[0] = StringToFloat(szRotateX);
		fEntityAngle[1] = StringToFloat(szRotateY);
		fEntityAngle[2] = StringToFloat(szRotateZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_accuraterotate", szArgs);
	return Plugin_Handled;
}

public Action Command_LightDynamic(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		FakeClientCommand(client, "sm_ld 7 255 255 255");
		// Build_PrintToChat(client, "Usage: !ld <brightness> <R> <G> <B>");
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	int Obj_LightDMelon = CreateEntityByName("prop_physics");
	if (Build_RegisterEntityOwner(Obj_LightDMelon, client)) {
		char szBrightness[33], szColorR[33], szColorG[33], szColorB[33], szColor[33];
		char szNameMelon[64];
		float fOriginAim[3];
		//GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(1, szBrightness, sizeof(szBrightness));
		GetCmdArg(2, szColorR, sizeof(szColorR));
		GetCmdArg(3, szColorG, sizeof(szColorG));
		GetCmdArg(4, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(client, fOriginAim);
		fOriginAim[2] += 50;
		
		if (!IsModelPrecached("models/props_2fort/lightbulb001.mdl"))
			PrecacheModel("models/props_2fort/lightbulb001.mdl");
		
		if (StrEqual(szBrightness, ""))
			szBrightness = "3";
		if (StringToInt(szColorR) < 100 || StrEqual(szColorR, ""))
			szColorR = "100";
		if (StringToInt(szColorG) < 100 || StrEqual(szColorG, ""))
			szColorG = "100";
		if (StringToInt(szColorB) < 100 || StrEqual(szColorB, ""))
			szColorB = "100";
		Format(szColor, sizeof(szColor), "%s %s %s", szColorR, szColorG, szColorB);
		
		DispatchKeyValue(Obj_LightDMelon, "model", "models/props_2fort/lightbulb001.mdl");
		//DispatchKeyValue(Obj_LightDMelon, "rendermode", "5");
		//DispatchKeyValue(Obj_LightDMelon, "renderamt", "150");
		//DispatchKeyValue(Obj_LightDMelon, "renderfx", "15");
		DispatchKeyValue(Obj_LightDMelon, "rendercolor", szColor);
		DispatchKeyValue(Obj_LightDMelon, "skin", szBrightness);
		
		int Obj_LightDynamic = CreateEntityByName("light_dynamic");
		
		if (StringToInt(szBrightness) > 7) {
			Build_PrintToChat(client, "Max brightness is 7!");
			Build_SetLimit(client, -1);
			return Plugin_Handled;
		}
		
		SetVariantString("500");
		AcceptEntityInput(Obj_LightDynamic, "distance", -1);
		SetVariantString(szBrightness);
		AcceptEntityInput(Obj_LightDynamic, "brightness", -1);
		SetVariantString("2");
		AcceptEntityInput(Obj_LightDynamic, "style", -1);
		SetVariantString(szColor);
		AcceptEntityInput(Obj_LightDynamic, "color", -1);
		SetEntProp(Obj_LightDMelon, Prop_Send, "m_nSolidType", 6);
		
		DispatchSpawn(Obj_LightDMelon);
		TeleportEntity(Obj_LightDMelon, fOriginAim, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(Obj_LightDynamic);
		TeleportEntity(Obj_LightDynamic, fOriginAim, NULL_VECTOR, NULL_VECTOR);

		Format(szNameMelon, sizeof(szNameMelon), "Obj_LightDMelon%i", GetRandomInt(1000, 5000));
		DispatchKeyValue(Obj_LightDMelon, "targetname", szNameMelon);
		SetVariantString(szNameMelon);
		AcceptEntityInput(Obj_LightDynamic, "setparent", -1);
		AcceptEntityInput(Obj_LightDynamic, "turnon", client, client);
		
	} else
		RemoveEdict(Obj_LightDMelon);
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++)
	{
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_ld", szArgs);
	return Plugin_Handled;
}

public Action Command_SpawnDoor(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	char szDoorTarget[16], szType[4], szFormatStr[64], szNameStr[8];
	float iAim[3];
	Build_ClientAimOrigin(client, iAim);
	GetCmdArg(1, szType, sizeof(szType));
	static int iEntity;
	char szModel[128];
	
	if (StrEqual(szType[0], "1") || StrEqual(szType[0], "2") || StrEqual(szType[0], "3") || StrEqual(szType[0], "4") || StrEqual(szType[0], "5") || StrEqual(szType[0], "6") || StrEqual(szType[0], "7")) {
		int Obj_Door = CreateEntityByName("prop_physics_override");
		
		switch (szType[0]) {
			case '1':szModel = "models/props_lab/blastdoor001c.mdl";
			case '2':szModel = "models/combine_gate_citizen.mdl";
			case '3':szModel = "models/combine_gate_Vehicle.mdl";
			case '4':szModel = "models/props_doors/doorKLab01.mdl";
			case '5':szModel = "models/props_lab/elevatordoor.mdl";
			case '6':szModel = "models/props_lab/RavenDoor.mdl";
			case '7':szModel = "models/props_lab/blastdoor001c.mdl";
		}
		
		DispatchKeyValue(Obj_Door, "model", szModel);
		SetEntProp(Obj_Door, Prop_Send, "m_nSolidType", 6);
		if (Build_RegisterEntityOwner(Obj_Door, client)) {
			TeleportEntity(Obj_Door, iAim, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(Obj_Door);
		}
	} else if (StrEqual(szType[0], "a") || StrEqual(szType[0], "b") || StrEqual(szType[0], "c")) {
		
		iEntity = Build_ClientAimEntity(client);
		if (iEntity == -1)
			return Plugin_Handled;
		
		switch (szType[0]) {
			case 'a': {
				int iName = GetRandomInt(1000, 5000);
				
				IntToString(iName, szNameStr, sizeof(szNameStr));
				Format(szFormatStr, sizeof(szFormatStr), "door%s", szNameStr);
				DispatchKeyValue(iEntity, "targetname", szFormatStr);

				Build_PrintToChat(client, "SDoor A set!");
				
				GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				SetClientCookie(client, g_hCookieSDoorTarget, szFormatStr);
				SetClientCookie(client, g_hCookieSDoorModel, szModel);
			}
			case 'b': {
				GetClientCookie(client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				
				Build_PrintToChat(client, "SDoor B set!");

				if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,dog_open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,DisableCollision,,1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,5", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,EnableCollision,,5.1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				} else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Drop,7", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				} else {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				}
			}
			case 'c': {
				GetClientCookie(client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				DispatchKeyValue(iEntity, "spawnflags", "258");
				
				Build_PrintToChat(client, "SDoor C set!");

				if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,dog_open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,DisableCollision,,1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,5", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,EnableCollision,,5.1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				} else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Drop,7", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				} else {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				}
			}
		}
	} else {
		Build_PrintToChat(client, "%t: !sdoor <1-6>", "usage");
		Build_PrintToChat(client, "%t", "sdoor");
		Build_PrintToChat(client, "%t", "sdoor2");
		Build_PrintToChat(client, "%t", "sdoor3");
		Build_PrintToChat(client, "%t", "sdoor4");
		// Build_PrintToChat(client, "NOTE: As for the current update, sdoors are fixed.");
	}
	return Plugin_Handled;
}


public Action Command_Move(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !move <x> <y> <z>", "usage");
		// Build_PrintToChat(client, "Ex, move up 50: !move 0 0 50");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		float fEntityOrigin[3], fEntityAngle[3];
		char szArgX[33], szArgY[33], szArgZ[33];
		GetCmdArg(1, szArgX, sizeof(szArgX));
		GetCmdArg(2, szArgY, sizeof(szArgY));
		GetCmdArg(3, szArgZ, sizeof(szArgZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		
		fEntityOrigin[0] += StringToFloat(szArgX);
		fEntityOrigin[1] += StringToFloat(szArgY);
		fEntityOrigin[2] += StringToFloat(szArgZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		/*float vOriginPlayer[3], vOriginAim[3];
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_move", szArgs);
	return Plugin_Handled;
}

public Action Command_SetName(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(client, "%t", "setname");
		// Build_PrintToChat(client, "Ex: !setname \"A teddy bear\"");
		// Build_PrintToChat(client, "Ex: !setname \"Gabe Newell\"");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char newpropname[256];
		GetCmdArgString(newpropname, sizeof(newpropname));
		//Format(newpropname, sizeof(newpropname), "%s", args);
		SetEntPropString(iEntity, Prop_Data, "m_iName", newpropname);
	}
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_setname", szArgs);
	return Plugin_Handled;
}

public Action Timer_FadeEffect(Handle timer, any iEntity)
{
	if (!IsValidEntity(iEntity))
		return;

	SetEntityRenderColor(iEntity, 255, 255, 255, 255);
	SetEntityRenderFx(iEntity, RENDERFX_NONE);
}

public Action Command_SpawnProp(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "%t", "alivetouse");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !spawnprop/!s <Prop>", "usage");
		// Build_PrintToChat(client, "Ex: !spawnprop goldbar");
		// Build_PrintToChat(client, "Ex: !spawnprop alyx");
		return Plugin_Handled;
	}
	
	char szPropName[32], szPropFrozen[32], szPropString[256], szModelPath[128];
	bool phys = false;
	GetCmdArg(1, szPropName, sizeof(szPropName));
	GetCmdArg(2, szPropFrozen, sizeof(szPropFrozen));
	if(StrEqual(szPropFrozen, "1"))
	{
		phys = true;
	}
	int IndexInArray = FindStringInArray(g_hPropNameArray, szPropName);
	int IndexInArray2 = FindStringInArray(g_hPropNameArrayDonor, szPropName);
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		
		return Plugin_Handled;
	}
	
	// EmitSoundToClient(client, "ui/panel_open.wav");

	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	// TODO: JUST CHECK IF ITS A DONOR PROP OR NOT FOR VALUES AND DO REST ONLY ONCE
	if (IndexInArray != -1) {
		bool bIsDoll = false;
		char szEntType[33];
		GetArrayString(g_hPropTypeArray, IndexInArray, szEntType, sizeof(szEntType));
		
		if (StrEqual(szEntType, "5"))
			bIsDoll = true;
		
		int iEntity = CreateEntityByName(szEntType);
		
		if (Build_RegisterEntityOwner(iEntity, client, bIsDoll, phys)) {
			float fOriginWatching[3], fOriginFront[3], fAngles[3], fRadiansX, fRadiansY;
			
			float iAim[3];
			float vOriginPlayer[3];
			
			GetClientEyePosition(client, fOriginWatching);
			GetClientEyeAngles(client, fAngles);
			
			fRadiansX = DegToRad(fAngles[0]);
			fRadiansY = DegToRad(fAngles[1]);
			
			fOriginFront[0] = fOriginWatching[0] + (100 * Cosine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[1] = fOriginWatching[1] + (100 * Sine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[2] = fOriginWatching[2] - 20;
			
			GetArrayString(g_hPropModelPathArray, IndexInArray, szModelPath, sizeof(szModelPath));
			
			
			GetArrayString(g_hPropStringArray, IndexInArray, szPropString, sizeof(szPropString));
			
			if (!IsModelPrecached(szModelPath))
				PrecacheModel(szModelPath);
			
			DispatchKeyValue(iEntity, "model", szModelPath);
			
			//DispatchKeyValue(iEntity, "propnametf2sb", szPropString);
			SetEntPropString(iEntity, Prop_Data, "m_iName", szPropString);
			if (StrEqual(szEntType, "prop_physics"))
			{
				SetEntityMoveType(iEntity, 6);
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
				SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);
				SetEntProp(iEntity, Prop_Data, "nodamageforces", 0);
			}

			
			if (StrEqual(szEntType, "prop_physics_overide"))
			{
				SetEntityMoveType(iEntity, 6);
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
				SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);
				SetEntProp(iEntity, Prop_Data, "nodamageforces", 0);
			}

			Build_ClientAimOrigin(client, iAim);
			iAim[2] = iAim[2] + 10;
			
			GetClientAbsOrigin(client, vOriginPlayer);
			vOriginPlayer[2] = vOriginPlayer[2] + 50;
			
			
			DispatchSpawn(iEntity);
			
<<<<<<< HEAD
			if(!StrEqual(szPropFrozen, "1"))	
=======
			if(!StrEqual(szPropFrozen, "1"))
>>>>>>> 0681785044414eb0f74decbbb9e4f5bab2104d98
			{
				Phys_EnableCollisions(iEntity, false);
				Phys_EnableGravity(iEntity, false);
				Phys_EnableDrag(iEntity, false);
				Phys_EnableMotion(iEntity, false);
			}
			else
			{
				Phys_EnableCollisions(iEntity, true);
				Phys_EnableGravity(iEntity, true);
				Phys_EnableDrag(iEntity, true);
				Phys_EnableMotion(iEntity, true);
			}
			TeleportEntity(iEntity, iAim, NULL_VECTOR, NULL_VECTOR);
			
			
			// TE_SetupBeamPoints(iAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
			// TE_SendToAll();
			
			/*int random = GetRandomInt(0, 1);
			if (random == 1) {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			} else {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			}*/
			
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);

			SetEntityRenderMode(iEntity, RENDER_TRANSALPHA);
			SetEntityRenderColor(iEntity, 255, 255, 255, 0);
			SetEntityRenderFx(iEntity, RENDERFX_SOLID_FAST);

			CreateTimer(0.4, Timer_FadeEffect, iEntity);

			// WIP FADE EFFECT
			
			// Debugging issues
			//PrintToChatAll(szPropString);
			
			/*if (!StrEqual(szPropFrozen, "")) {
				if (Phys_IsPhysicsObject(iEntity))
					Phys_EnableMotion(iEntity, false);
			}*/
		} else
			RemoveEdict(iEntity);
	} else if (IndexInArray2 != -1 && CheckCommandAccess(client, "sm_tf2sb_donor", 0)) {
		bool bIsDoll = false;
		char szEntType[33];
		GetArrayString(g_hPropTypeArrayDonor, IndexInArray2, szEntType, sizeof(szEntType));
		
		if (StrEqual(szEntType, "5"))
			bIsDoll = true;
		
		int iEntity = CreateEntityByName(szEntType);
		
		if (Build_RegisterEntityOwner(iEntity, client, bIsDoll)) {
			float fOriginWatching[3], fOriginFront[3], fAngles[3], fRadiansX, fRadiansY;
			
			float iAim[3];
			float vOriginPlayer[3];
			
			GetClientEyePosition(client, fOriginWatching);
			GetClientEyeAngles(client, fAngles);
			
			fRadiansX = DegToRad(fAngles[0]);
			fRadiansY = DegToRad(fAngles[1]);
			
			fOriginFront[0] = fOriginWatching[0] + (100 * Cosine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[1] = fOriginWatching[1] + (100 * Sine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[2] = fOriginWatching[2] - 20;
			
			GetArrayString(g_hPropModelPathArrayDonor, IndexInArray2, szModelPath, sizeof(szModelPath));
			
			
			GetArrayString(g_hPropStringArrayDonor, IndexInArray2, szPropString, sizeof(szPropString));
			
			if (!IsModelPrecached(szModelPath))
				PrecacheModel(szModelPath);
			
			DispatchKeyValue(iEntity, "model", szModelPath);
			
			//DispatchKeyValue(iEntity, "propnametf2sb", szPropString);
			SetEntPropString(iEntity, Prop_Data, "m_iName", szPropString);
			SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
			if (StrEqual(szEntType, "prop_physics"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			if (StrEqual(szEntType, "prop_physics_override"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			Build_ClientAimOrigin(client, iAim);
			iAim[2] = iAim[2] + 10;
			
			GetClientAbsOrigin(client, vOriginPlayer);
			vOriginPlayer[2] = vOriginPlayer[2] + 50;
			
			
			DispatchSpawn(iEntity);
			TeleportEntity(iEntity, iAim, NULL_VECTOR, NULL_VECTOR);
			
			
			
			// TE_SetupBeamPoints(iAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
			// TE_SendToAll();
			
			/*int random = GetRandomInt(0, 1);
			if (random == 1) {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			} else {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			}*/
			
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);

			SetEntityRenderMode(iEntity, RENDER_TRANSALPHA);
			SetEntityRenderColor(iEntity, 255, 255, 255, 0);
			SetEntityRenderFx(iEntity, RENDERFX_SOLID_FAST);

			CreateTimer(0.4, Timer_FadeEffect, iEntity);

			// WIP FADE EFFECT
			
			// Debugging issues
			//PrintToChatAll(szPropString);

			/*if (!StrEqual(szPropFrozen, "")) {
				if (Phys_IsPhysicsObject(iEntity))
					Phys_EnableMotion(iEntity, false);
			}*/
		} else
			RemoveEdict(iEntity);
	} else{
		Build_PrintToChat(client, "%t%s", "propnotfound", szPropName);
	}
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_spawnprop", szArgs);
	return Plugin_Handled;
}

void ReadProps(bool Donator, char path[64])
{
	BuildPath(Path_SM, g_szFile, sizeof(g_szFile), path);// "configs/buildmod/props.ini");
	
	Handle iFile = OpenFile(g_szFile, "rt");
	if (iFile == INVALID_HANDLE)
		return;
	
	int iCountProps = 0;
	while (!IsEndOfFile(iFile))
	{
		char szLine[255];
		if (!ReadFileLine(iFile, szLine, sizeof(szLine)))
			break;
		
		/* 略過註解 */
		int iLen = strlen(szLine);
		bool bIgnore = false;
		
		for (int i = 0; i < iLen; i++) {
			if (bIgnore) {
				if (szLine[i] == '"')
					bIgnore = false;
			} else {
				if (szLine[i] == '"')
					bIgnore = true;
				else if (szLine[i] == ';') {
					szLine[i] = '\0';
					break;
				} else if (szLine[i] == '/' && i != iLen - 1 && szLine[i + 1] == '/') {
					szLine[i] = '\0';
					break;
				}
			}
		}
		
		TrimString(szLine);
		
		if ((szLine[0] == '/' && szLine[1] == '/') || (szLine[0] == ';' || szLine[0] == '\0'))
			continue;
		
		if (Donator == true) {
			ReadPropsLine(szLine, iCountProps++, true);
		} else {
			ReadPropsLine(szLine, iCountProps++, false);
		}
	}
	CloseHandle(iFile);
}

void ReadPropsLine(const char[] szLine, int iCountProps, bool Donor)
{
	char szPropInfo[4][128];
	ExplodeString(szLine, ", ", szPropInfo, sizeof(szPropInfo), sizeof(szPropInfo[]));
	StripQuotes(szPropInfo[0]);
	StripQuotes(szPropInfo[1]);
	StripQuotes(szPropInfo[2]);
	StripQuotes(szPropInfo[3]);
	
	if (Donor) {
		SetArrayString(g_hPropNameArrayDonor, iCountProps, szPropInfo[0]);
		SetArrayString(g_hPropModelPathArrayDonor, iCountProps, szPropInfo[1]);
		SetArrayString(g_hPropTypeArrayDonor, iCountProps, szPropInfo[2]);
		SetArrayString(g_hPropStringArrayDonor, iCountProps, szPropInfo[3]);
		AddMenuItem(g_hPropMenuDonor, szPropInfo[0], szPropInfo[3]);
	} else {
		SetArrayString(g_hPropNameArray, iCountProps, szPropInfo[0]);
		SetArrayString(g_hPropModelPathArray, iCountProps, szPropInfo[1]);
		SetArrayString(g_hPropTypeArray, iCountProps, szPropInfo[2]);
		SetArrayString(g_hPropStringArray, iCountProps, szPropInfo[3]);
		AddMenuItem(g_hPropMenuHL2, szPropInfo[0], szPropInfo[3]);
	}
}

public Action Event_Spawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	LastUsed[client] = 0;
	
	if (g_bGodmode[client])
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}

	else if(g_bBuddha[client])
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
	}

	// TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
	// TF2_RegeneratePlayer(client);

	SetEntProp(client, Prop_Data, "m_CollisionGroup", 17);

	nextactivetime[client] = GetGameTime();
}

public Action Command_ChangeGodMode(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	g_bGodmode[client] = !g_bGodmode[client];
	
	if (g_bGodmode[client])
	{
		Build_PrintToChat(client, "God Mode %t", "on");
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		
		g_bBuddha[client] = false;
	}
	else
	{
		Build_PrintToChat(client, "God Mode %t", "off");
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		
		g_bBuddha[client] = false;
	}
	
	return Plugin_Handled;
}

public Action Command_ChangeBuddha(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	g_bBuddha[client] = !g_bBuddha[client];
	
	if (g_bBuddha[client])
	{
		Build_PrintToChat(client, "Buddha %t", "on");
		SetEntProp(client, Prop_Data, "m_takedamage", 1, 1);
		g_bBuddha[client] = true;
		g_bGodmode[client] = false;
	}
	else
	{
		Build_PrintToChat(client, "Buddha %t", "off");
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		
		g_bGodmode[client] = false;
	}
	
	return Plugin_Handled;
}

public Action Command_Health(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(client, "%t: !addhealth -300 - 15000", "usage");
		return Plugin_Handled;
	}
	
	char szHealth[128];
	GetCmdArg(1, szHealth, sizeof(szHealth));
	// Build_PrintToChat(client, "Added %s onto your health", szHealth);
	TF2Attrib_RemoveByName(client, "max health additive bonus");
	TF2Attrib_SetByName(client, "max health additive bonus", StringToFloat(szHealth));
	TF2_RegeneratePlayer(client);

	return Plugin_Handled;
}

// Messages
public Action Display_Msgs(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (Build_IsClientValid(client, client, true) && !IsFakeClient(client)) {
			int iAimTarget = Build_ClientAimEntity(client, false, true);
			if (iAimTarget != -1 && IsValidEdict(iAimTarget))
				EntityInfo(client, iAimTarget);
		}
	}
	return;
}

public void EntityInfo(int client, int iTarget)
{
	if (IsFunc(iTarget))
		return;
	
	/* if (IsWorldEnt(iTarget)) {
		if (Build_IsAdmin(client)) {
			char szSteamId[32], szIP[16];
			GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			ShowHudText(client, -1, "%s\nIs a World Entity.", iTarget);
		} else {
		}
	} */
	
	SetHudTextParams(-1.0, 0.6, 0.01, 255, 255, 255, 255);
	if (IsPlayer(iTarget) && GetClientTeam(iTarget) != GetClientTeam(client) && TF2_GetPlayerClass(client) != TFClass_Spy) {
		ShowHudText(client, -1, "\n%N", iTarget);
		return;
	}

	if (IsPlayer(iTarget)) {
		return;
	}

	char szClass[32];
	GetEdictClassname(iTarget, szClass, sizeof(szClass));
	/*if (IsNpc(iTarget)) {
		int iHealth = GetEntProp(iTarget, Prop_Data, "m_iHealth");
		if (iHealth <= 1)
			iHealth = 0;
		ShowHudText(client, -1, "Classname: %s\nHealth: %i", szClass, iHealth);
		return;
	}*/
	
	char szModel[128], szOwner[32], szPropString[256];
	
	//char szGetThoseString[512];
	GetEntPropString(iTarget, Prop_Data, "m_iName", szPropString, sizeof(szPropString));
	
	int iOwner = Build_ReturnEntityOwner(iTarget);
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	if (Build_IsClientValid(iOwner, iOwner))
        GetClientName(iOwner, szOwner, sizeof(szOwner));
	else if (iOwner > MAXPLAYERS) {
		szOwner = "*Disconnected";
	} else {
		szOwner = "*World";
	}
	
	/*if ((StrContains(szClass, "prop_door_", false) == 0 || StrEqual(szModel, "models/props_lab/teleplatform.mdl") || (GetCommandFlags("sm_cam") != INVALID_FCVAR_FLAGS && (StrEqual(szModel, "models/props_spytech/computer_screen_bank.mdl") || StrEqual(szModel, "models/props_lab/securitybank.mdl")))) && Entity_InRange(client, iTarget, 100.0)) {
		ShowHudText(client, -1, "%s \nbuilt by %s\nPress [TAB] to use", szPropString, szOwner);
	}
	else {*/
	ShowHudText(client, -1, "%s \n%T %s", szPropString, "builtby", client, szOwner);
	//}

	return;
}

bool IsFunc(int iEntity)
{
	char szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "func_", false) == 0 && !StrEqual(szClass, "func_physbox"))
		return true;
	return false;
}

bool IsPlayer(int iEntity)
{
	if ((GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT)))
		return true;
	return false;
}

// Remover.sp

public Action Command_DeleteAll(int client, int args)
{
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
		return Plugin_Handled;
	}

	if (!Build_AllowToUse(client) || !Build_IsClientValid(client, client))
		return Plugin_Handled;
	
	int iCheck = 0, iCount = 0;
	while (iCheck < MAX_HOOK_ENTITIES) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == client) {
				for (int i = 0; i < sizeof(DelClass); i++) {
					char szClass[32];
					GetEdictClassname(iCheck, szClass, sizeof(szClass));
					if (StrContains(szClass, DelClass[i]) >= 0) {
						AcceptEntityInput(iCheck, "Kill", -1);
						iCount++;
					}
					Build_RegisterEntityOwner(iCheck, -1);
				}
			}
		}
		iCheck += 1;
	}
	if (iCount > 0) {
		Build_PrintToChat(client, "%t", "deletedallprops");
	} else {
		Build_PrintToChat(client, "%t", "noprops");
	}
	
	Build_SetLimit(client, 0);
	Build_SetLimit(client, 0, true);
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));

	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_ResetPhysProps(client);
	Build_Logging(client, "sm_delall", szArgs);
	return Plugin_Handled;
}

public Action Command_Delete(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	int iEntity = Build_ClientAimEntity(client, true, true);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char szClass[33];
		GetEdictClassname(iEntity, szClass, sizeof(szClass));
		DispatchKeyValue(iEntity, "targetname", "Del_Drop");
		
		if (!Build_IsAdmin(client)) {
			if (StrEqual(szClass, "prop_vehicle_driveable") || StrEqual(szClass, "prop_vehicle") || StrEqual(szClass, "prop_vehicle_airboat") || StrEqual(szClass, "prop_vehicle_prisoner_pod")) {
				Build_PrintToChat(client, "%t", "cantdelete");
				return Plugin_Handled;
			}
		}
		
		float vOriginPlayer[3], vOriginAim[3];
		int Obj_Dissolver = CreateDissolver("3");
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		/*int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}*/
		
		DispatchKeyValue(iEntity, "targetname", "Del_Target");
		
		/*TE_SetupBeamRingPoint(vOriginAim, 10.0, 150.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, ColorWhite, 20, 0);
		TE_SendToAll();
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();*/

		EmitSoundToClient(client, "ui/panel_close.wav");
		
		if (Build_IsAdmin(client)) {
			if (StrEqual(szClass, "player") || StrContains(szClass, "prop_") == 0 || StrContains(szClass, "npc_") == 0 || StrContains(szClass, "weapon_") == 0 || StrContains(szClass, "item_") == 0) {
				SetVariantString("Del_Target");
				AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
				AcceptEntityInput(Obj_Dissolver, "kill", -1);
				DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				
				int iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "5"))
						Build_SetLimit(iOwner, -1, true);
					else if (Phys_IsGravityEnabled(iEntity))
					{
						Build_SetLimit(iOwner, -1, false, true);
					}
					else
						Build_SetLimit(iOwner, -1);
					Build_RegisterEntityOwner(iEntity, -1);
				}
				return Plugin_Handled;
			}
			if (!(GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))) {
				AcceptEntityInput(iEntity, "kill", -1);
				AcceptEntityInput(Obj_Dissolver, "kill", -1);
				return Plugin_Handled;
			}
		}
		
		if (StrEqual(szClass, "func_physbox")) {
			AcceptEntityInput(iEntity, "kill", -1);
			AcceptEntityInput(Obj_Dissolver, "kill", -1);
		} else {
			SetVariantString("Del_Target");
			AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
			AcceptEntityInput(Obj_Dissolver, "kill", -1);
			DispatchKeyValue(iEntity, "targetname", "Del_Drop");
		}

		if (StrEqual(szClass, "5"))
			Build_SetLimit(client, -1, true);
		else if (Phys_IsGravityEnabled(iEntity))
			Build_SetLimit(client, -1, false, true);
		else
			Build_SetLimit(client, -1);
		Build_RegisterEntityOwner(iEntity, -1);
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
<<<<<<< HEAD
	
=======

>>>>>>> 0681785044414eb0f74decbbb9e4f5bab2104d98
	Build_Logging(client, "sm_del", szArgs);
	return Plugin_Handled;
}

public void OnPropBreak(const char[] output, int iEntity, int iActivator, float delay)
{
	if (IsValidEntity(iEntity))
		CreateTimer(0.1, Timer_PropBreak, iEntity);
}

public Action Timer_PropBreak(Handle timer, any iEntity)
{
	if (!IsValidEntity(iEntity))
		return;
	int iOwner = Build_ReturnEntityOwner(iEntity);
	if (iOwner > 0) {
		Build_SetLimit(iOwner, -1);
		Build_RegisterEntityOwner(iEntity, -1);
		AcceptEntityInput(iEntity, "kill", -1);
	}
}

stock int DrowLine(float vPoint1[3], float vPoint2[3], Color[4], bool bFinale = false)
{
	if (bFinale)
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.5, 7.0, 7.0, 0, 0.0, Color, 20);
	else
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, Color, 20);
	TE_SendToAll();
}

stock int CreatePush(float vOrigin[3], float fMagnitude, float fRange, char szSpawnFlags[8])
{
	int Push_Index = CreateEntityByName("point_push");
	TeleportEntity(Push_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Push_Index, "magnitude", fMagnitude);
	DispatchKeyValueFloat(Push_Index, "radius", fRange);
	DispatchKeyValueFloat(Push_Index, "inner_radius", fRange);
	DispatchKeyValue(Push_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Push_Index);
	return Push_Index;
}

stock int CreateDissolver(char szDissolveType[4])
{
	int Dissolver_Index = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(Dissolver_Index, "dissolvetype", szDissolveType);
	DispatchKeyValue(Dissolver_Index, "targetname", "Del_Dissolver");
	DispatchSpawn(Dissolver_Index);
	return Dissolver_Index;
}

// SimpleMenu.sp

public Action Command_BuildMenu(int client, int args)
{
	if (client > 0)
	{
		DisplayMenu(g_hMainMenu, client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public Action Command_PhysGun(int client, int args)
{
	if(GetCommandFlags("sm_physgun") == INVALID_FCVAR_FLAGS && GetCommandFlags("sm_pg") == INVALID_FCVAR_FLAGS && GetCommandFlags("sm_sbpg") == INVALID_FCVAR_FLAGS)
	{
		/* Build_PrintToChat(client, "You have been given Physics Gun V1!");
		// Build_PrintToChat(client, "GAWH, WHY ARE YOU USING PHYSGUN 1.0??");
		// Build_PrintToChat(client, "USE 2.0 ALREADY! (/g)");
		Build_PrintToChat(client, "This version is full of bugs, please use the latest from:");
		Build_PrintToChat(client, "https://github.com/tf2-sandbox-studio/Module-PhysicsGun");
		TF2Items_GiveWeapon(client, 99999);
		int weapon = GetPlayerWeaponSlot(client, 1);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon); */
		// bruh moment
		// Build_PrintToChat(client, "You can use the latest physgun from:");
		Build_PrintToChat(client, "https://github.com/tf2-sandbox-studio/Module-PhysicsGun");
	}
	else
	{
		// Build_PrintToChat(client, "Physgun V1 is full of bugs, use V2/V3/V4!");
		if(GetCommandFlags("sm_physgun") != INVALID_FCVAR_FLAGS)
		{
			FakeClientCommand(client, "sm_physgun");
		} else if(GetCommandFlags("sm_pg") != INVALID_FCVAR_FLAGS)
		{
			FakeClientCommand(client, "sm_pg");
		} else if(GetCommandFlags("sm_sbpg") != INVALID_FCVAR_FLAGS)
		{
			FakeClientCommand(client, "sm_sbpg");
		}	
	}
}

public Action Command_PropFinder(int client, int args)
{
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
	}
	else
	{
		Menu PropFinder = CreateMenu(PropFinderMenu);
		SetMenuTitle(PropFinder, /*"TF2SB - */ "Prop Finder");
		g_bBuffer[client] = true;
		CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
		for (int i = 1; i < MAX_HOOK_ENTITIES; i++)
		{
			if (IsValidEntity(i))
			{
				if (Build_ReturnEntityOwner(i) == client)
				{
					char name[128];
					char id[6];
					IntToString(i, id, sizeof(id));
					GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
					AddMenuItem(PropFinder, id, name);
				}
			}
		}
		SetMenuExitBackButton(PropFinder, true);
		DisplayMenu(PropFinder, client, MENU_TIME_FOREVER);
	}
}

public int PropFinderMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		int i = StringToInt(item);
		char name[128];
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));

		Menu PropFinder = CreateMenu(PropFinderMenu2);
		SetMenuTitle(PropFinder, /*"TF2SB - */ "Prop Finder - %s", name);
		AddMenuItem(PropFinder, item, "Delete");
		AddMenuItem(PropFinder, item, "Goto");
		SetMenuExitBackButton(PropFinder, true);
		DisplayMenu(PropFinder, param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public int PropFinderMenu2(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		int i = StringToInt(item);

		if (param2 == 0)
		{
			Build_RegisterEntityOwner(i, -1);
			Build_SetLimit(param1, -1, true);
			AcceptEntityInput(i, "Kill", -1);
		}
		else if (param2 == 1)
		{
			float vector[3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vector);
			TeleportEntity(param1, vector, NULL_VECTOR, NULL_VECTOR);
		}

		FakeClientCommand(param1, "sm_propfinder");
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		FakeClientCommand(param1, "sm_propfinder");
	}
	return 0;
}

public Action Command_Resupply(int client, int args)
{
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "%t", "toofast");
	}
	else
	{
		g_bBuffer[client] = true;
		CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));

		Build_PrintToChat(client, "%t", "resupplied");
		TF2_RegeneratePlayer(client);
	}
}

public int MainMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "spawnlist"))
		{
			DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "equipmenu"))
		{
			DisplayMenu(g_hEquipMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "playerstuff"))
		{
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "buildhelper"))
		{
			DisplayMenu(g_hBuildHelperMenu, param1, MENU_TIME_FOREVER);
		}

		if (StrEqual(item, "savesys"))
		{
			FakeClientCommand(param1, "sm_ss");
		}

		if (StrEqual(item, "credits"))
		{
			FakeClientCommand(param1, "sm_tf2sb");
		}

		if (StrEqual(item, "door"))
		{
			FakeClientCommand(param1, "sm_propdoor");
		}
	}
}

public int PropMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else if (StrEqual(info, "constructprops"))
		{
			DisplayMenu(g_hPropMenuConstructions, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "comicprops"))
		{
			DisplayMenu(g_hPropMenuComic, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "weaponsprops"))
		{
			DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "cosmeticprops"))
		{
			DisplayMenu(g_hPropMenuCosmetics, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "pickupprops"))
		{
			DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "leadprops"))
		{
			DisplayMenu(g_hPropMenuLead, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "hl2props"))
		{
			DisplayMenu(g_hPropMenuHL2, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "requestedprops"))
		{
			DisplayMenu(g_hPropMenuRequested, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "donatorprops"))
		{
			if (CheckCommandAccess(param1, "sm_tf2sb_donor", 0))
			{
				DisplayMenu(g_hPropMenuDonor, param1, MENU_TIME_FOREVER);
			}
			else
			{
				FakeClientCommand(param1, "say !donate");
			}
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int CondMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hCondMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "crits"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_CritCanteen))
			{
				Build_PrintToChat(param1, "Crit Cond %t", "off");
				TF2_RemoveCondition(param1, TFCond_CritCanteen);
			}
			else
			{
				Build_PrintToChat(param1, "Crit Cond %t", "on");
				TF2_AddCondition(param1, TFCond_CritCanteen, TFCondDuration_Infinite, 0);
			}
		}
		
		else if (StrEqual(item, "infammo"))
		{
			#if defined _AdvancedInfiniteAmmo_included
				if (AIA_HasAIA(param1))
				{
					Build_PrintToChat(param1, "Infinite Ammo %t", "off");
					AIA_SetAIA(param1, false);
				}
				else
				{
					Build_PrintToChat(param1, "Infinite Ammo %t", "on");
					AIA_SetAIA(param1, true);
				}
				// Build_PrintToChat(param1, "Learn more at !aiamenu");
			#endif
		}

		/*if (StrEqual(item, "infclip"))
		{
			Build_PrintToChat(param1, "Learn more at !aiamenu");
		}*/
		
		else if (StrEqual(item, "resupply"))
		{
			FakeClientCommand(param1, "sm_resupply");
		}
		
		else if (StrEqual(item, "noclip"))
		{
			FakeClientCommand(param1, "sm_fly");
		}
		
		else if (StrEqual(item, "godmode"))
		{
			FakeClientCommand(param1, "sm_god");
		}
		
		else if (StrEqual(item, "buddha"))
		{
			FakeClientCommand(param1, "sm_buddha");
		}
		
		/*if (StrEqual(item, "buddha"))
		{
			FakeClientCommand(param1, "sm_buddha");				
		}*/
		
		else if (StrEqual(item, "fly"))
		{
			if (!Build_AllowToUse(param1) || Build_IsBlacklisted(param1) || !Build_IsClientValid(param1, param1, true) || !Build_AllowFly(param1))
				return 0;
			
			if (GetEntityMoveType(param1) != MOVETYPE_FLY)
			{
				Build_PrintToChat(param1, "Fly %t", "on");
				SetEntityMoveType(param1, MOVETYPE_FLY);
			}
			else
			{
				Build_PrintToChat(param1, "Fly %t", "off");
				SetEntityMoveType(param1, MOVETYPE_WALK);
			}
		}
		
		else if (StrEqual(item, "minicrits"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_NoHealingDamageBuff))
			{
				Build_PrintToChat(param1, "Mini-Crits %t", "off");
				TF2_RemoveCondition(param1, TFCond_NoHealingDamageBuff);
			}
			else
			{
				Build_PrintToChat(param1, "Mini-Crits %t", "on");
				TF2_AddCondition(param1, TFCond_NoHealingDamageBuff, TFCondDuration_Infinite, 0);
			}
		}
		
		else if (StrEqual(item, "damagereduce"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_DefenseBuffNoCritBlock))
			{
				Build_PrintToChat(param1, "Damage Reduction %t", "off");
				TF2_RemoveCondition(param1, TFCond_DefenseBuffNoCritBlock);
			}
			else
			{
				Build_PrintToChat(param1, "Damage Reduction %t", "on");
				TF2_AddCondition(param1, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite, 0);
			}
		}
		
		else if (StrEqual(item, "speedboost"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_HalloweenSpeedBoost))
			{
				Build_PrintToChat(param1, "Speed Boost %t", "off");
				TF2_RemoveCondition(param1, TFCond_HalloweenSpeedBoost);
			}
			else
			{
				Build_PrintToChat(param1, "Speed Boost %t", "on");
				TF2_AddCondition(param1, TFCond_HalloweenSpeedBoost, TFCondDuration_Infinite, 0);
			}
		}
		
		else if (StrEqual(item, "removeweps"))
		{
			TF2_RemoveAllWeapons(param1);
		}

		/*else if (StrEqual(item, "removeperks"))
		{
			RTD2_Remove(param1, RTDRemove_Custom, "Removed Perks");
		}*/

		else
		{
			#if defined _rtd2_included
				if (RTD2_Force(param1, item, 9999, param1) == RTDForce_ClientInRoll)
				{
					RTD2_Remove(param1, RTDRemove_Custom, "Toggled Perk off");
				}
			#endif
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public int ModelMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hModelMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "0"))
		{
			SetVariantString("");
			AcceptEntityInput(param1, "SetCustomModel");
			SetEntProp(param1, Prop_Send, "m_bUseClassAnimations", 0.0);
		}
		else
		{
			SetVariantString(info);
 			AcceptEntityInput(param1, "SetCustomModel");
			SetEntProp(param1, Prop_Send, "m_bUseClassAnimations", 1.0);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
}

public int HealthMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hHealthMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		float itemf = StringToFloat(item);
		FakeClientCommand(param1, "sm_addhealth %f", itemf);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public int DSPMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hDSPMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		float itemf = StringToFloat(item);
		TF2Attrib_RemoveByName(param1, "SET BONUS: special dsp");
		TF2Attrib_SetByName(param1, "SET BONUS: special dsp", itemf);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}


public int PlayerStuff(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "cond"))
		{
			DisplayMenu(g_hCondMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "sizes"))
		{
			DisplayMenu(g_hSizeMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "poser"))
		{
			DisplayMenu(g_hPoseMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "health"))
		{
			DisplayMenu(g_hHealthMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "speed"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "model"))
		{
			DisplayMenu(g_hModelMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "pitch"))
		{
			DisplayMenu(g_hDSPMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int EquipMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hEquipMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "physgun"))
		{
			FakeClientCommand(param1, "sm_g");
		}
		else if (StrEqual(item, "physgun2"))
		{
			FakeClientCommand(param1, "sm_sbpg");
		}
		else if (StrEqual(item, "physgunv2"))
		{
			FakeClientCommand(param1, "sm_pg");
		}
		else if (StrEqual(item, "physgunnew"))
		{
			FakeClientCommand(param1, "sm_physgun");
		}
		else if (StrEqual(item, "toolgun"))
		{
			FakeClientCommand(param1, "sm_tg");
		}
		else if (StrEqual(item, "portalgun"))
		{
			FakeClientCommand(param1, "portalgun");
		}
		else
		{
			#if defined _tf2items_giveweapon_included
				int szWeapon = TF2Items_GiveWeapon(param1, StringToInt(item));
				SetEntPropEnt(param1, Prop_Send, "m_hActiveWeapon", szWeapon);  
			#endif
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int RemoveMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		//FakeClientCommand(param1, "sm_del");
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "remove"))
		{
			FakeClientCommand(param1, "sm_del");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int BuildHelperMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hBuildHelperMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "delprop"))
		{
			FakeClientCommand(param1, "sm_del");
		}
		else if (StrEqual(item, "colors"))
		{
			FakeClientCommand(param1, "sm_color");
		}
		else if (StrEqual(item, "effects"))
		{
			FakeClientCommand(param1, "sm_render");
		}
		else if (StrEqual(item, "skin"))
		{
			FakeClientCommand(param1, "sm_skin");
		}
		else if (StrEqual(item, "rotate"))
		{
			FakeClientCommand(param1, "sm_rotate");
		}
		else if (StrEqual(item, "accuraterotate"))
		{
			FakeClientCommand(param1, "sm_accuraterotate");
		}
		else if (StrEqual(item, "lights"))
		{
			FakeClientCommand(param1, "sm_ld");
		}
		else if (StrEqual(item, "doors"))
		{
			FakeClientCommand(param1, "sm_propdoor");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int TF2SBPoseMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		switch (param2)
		{
			case 0:
			{
				/*if(TF2_IsPlayerInCondition(param1, TFCond_Taunting))
				{
					DisplayMenu(menu, param1, MENU_TIME_FOREVER);
					TF2Attrib_SetByName(param1, "gesture speed increase", -1.0);
				}
				else
				{
					DisplayMenu(menu, param1, MENU_TIME_FOREVER);
					PrintToChat(param1, "\x04 You cannot set taunt speed to -1 unless you are taunting.");
				}*/
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", -1.0);
			}
			case 1:
			{
				/*if(TF2_IsPlayerInCondition(param1, TFCond_Taunting))
				{
					DisplayMenu(menu, param1, MENU_TIME_FOREVER);
					TF2Attrib_SetByName(param1, "gesture speed increase", 0.0);
				}
				else
				{
					DisplayMenu(menu, param1, MENU_TIME_FOREVER);
					PrintToChat(param1, "\x04 You cannot set taunt speed to 0 unless you are taunting.");
				}*/
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", 0.0);
			}
			case 2:
			{
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", 0.1);
			}
			case 3:
			{
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", 0.25);
			}
			case 4:
			{
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", 0.5);
			}
			case 5:
			{
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2Attrib_SetByName(param1, "gesture speed increase", 1.0);
			}
			case 6:
			{
				DisplayMenu(menu, param1, MENU_TIME_FOREVER);
				TF2_RemoveCondition(param1, TFCond_Taunting);
				Build_PrintToChat(param1, "%t", "nolongertaunting");
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
}

public int TF2SBSizeMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hSizeMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		float itemf = StringToFloat(item);
		SetEntPropFloat(param1, Prop_Send, "m_flModelScale", itemf);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public int PropMenuHL2(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuHL2, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuDonor(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuDonor, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuConstructions(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuConstructions, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuConstructions, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuComics(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuComic, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuComic, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuWeapons(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuWeapons, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuCosmetics(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuCosmetics, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuPickup(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuPickup, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuRequested(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuRequested, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuLead(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuLead, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			// DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
			FakeClientCommand(param1, "sm_del");
		}
		else if (StrEqual(info, "light"))
		{
			FakeClientCommand(param1, "sm_ld");
		}
		else if (StrEqual(info, "door"))
		{
			FakeClientCommand(param1, "sm_propdoor");
		}
		else if (StrEqual(info, "laser"))
		{
			FakeClientCommand(param1, "sm_laser");
		}
		else if (StrEqual(info, "camera"))
		{
			FakeClientCommand(param1, "sm_spawnprop security_camera");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_spawnprop security_camera_bracket");
			g_bBuffer[param1] = true;
			// FakeClientCommand(param1, "sm_camauto");
			Build_PrintToChat(param1, "%t", "camera");
		}
		else if (StrEqual(info, "sdoor"))
		{
			// Command_SpawnDoor(param1, 5);
			FakeClientCommand(param1, "sm_sdoor 5");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_sdoor a");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_sdoor b");
			g_bBuffer[param1] = true;
		}
		else if (StrEqual(info, "sdoor2"))
		{
			// Command_SpawnDoor(param1, 5);
			FakeClientCommand(param1, "sm_sdoor 1");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_sdoor a");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_sdoor b");
			g_bBuffer[param1] = true;	
		}
		else if (StrEqual(info, "sign"))
		{
			FakeClientCommand(param1, "sm_spawnprop signpost001");
			g_bBuffer[param1] = false;
			FakeClientCommand(param1, "sm_setname \"Use !setname to set text\"");
			g_bBuffer[param1] = true;
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && param1 > 0 && param1 <= MaxClients && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public Action ClientRemoveAll(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] %t: sm_fda <#userid|name>", "usage");
		return Plugin_Handled;
	}
	
	char arg[65]; // , cmd[192];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	
	if ((target_count = ProcessTargetString(
				arg, 
				client, 
				target_list, 
				MAXPLAYERS, 
				0, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		FakeClientCommand(target_list[i], "sm_delall");
	}
	
	return Plugin_Handled;
}

public Action Event_player_builtobject(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int building = GetEventInt(event, "index");
	if (Build_RegisterEntityOwner(building, client)) {
		Build_SetLimit(client, -1);
		char classname[48];
		GetEntityClassname(building, classname, sizeof(classname));
		if (StrEqual(classname, "obj_sentrygun"))
		{
			SetEntPropString(building, Prop_Data, "m_iName", "Sentry Gun");
		}
		if (StrEqual(classname, "obj_dispenser"))
		{
			SetEntPropString(building, Prop_Data, "m_iName", "Dispenser");
		}
		if (StrEqual(classname, "obj_teleporter"))
		{
			SetEntPropString(building, Prop_Data, "m_iName", "Teleporter");
		}
	}
	return Plugin_Continue;
}

stock bool GetAimOrigin(int client, float hOrigin[3])
{
	float vAngles[3], fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	GetClientEyeAngles(client, vAngles);
	
	fOrigin[2] += 75.0;
	
	Handle trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hOrigin, trace);
		CloseHandle(trace);
		return true;
	}
	
	CloseHandle(trace);
	return false;
}

// BlackList

public Action Command_AddBL(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "[SM] %t: sm_bl <#userid|name>", "usage");
		return Plugin_Handled;
	}
	
	char arg[33];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++) {
		int target = target_list[i];
		
		if (Build_IsBlacklisted(target)) {
			Build_PrintToChat(client, "%s is already blacklisted!", target_name);
			return Plugin_Handled;
		} else
			Build_AddBlacklist(target);
	}
	
	for (int i = 0; i < MaxClients; i++) {
		if (Build_IsClientValid(i, i)) {
				Build_PrintToChat(i, "%N added %s to this server blacklist!", client, target_name);
		}
	}
	return Plugin_Handled;
}

public Action Command_RemoveBL(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "[SM] %t: sm_unbl <#userid|name>", "usage");
		return Plugin_Handled;
	}
	
	char arg[33];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++) {
		int target = target_list[i];
		
		if (!Build_RemoveBlacklist(target)) {
			Build_PrintToChat(client, "%s is not in blacklist!", target_name);
			return Plugin_Handled;
		}
	}
	
	if (tn_is_ml) {
		for (int i = 0; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i)) {
				Build_PrintToChat(i, "%N removed %s from this server blacklist!", client, target_name);
			}
		}
	} else {
		for (int i = 0; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i)) {
				Build_PrintToChat(i, "%N removed %s from this server blacklist!", client, target_name);
			}
		}
	}
	return Plugin_Handled;
}

stock int GetClientAimEntity3(int client, float &distancetoentity, float endpos[3]) {
	
	float cleyepos[3], cleyeangle[3];
	GetClientEyePosition(client, cleyepos);
	GetClientEyeAngles(client, cleyeangle);
	
	Handle traceresulthandle = INVALID_HANDLE;
	
	traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, tracerayfilterdefault, client);
	
	if (TR_DidHit(traceresulthandle) == true) {
		
		TR_GetEndPosition(endpos, traceresulthandle);
		
		//거리가 일정 이하일 경우
		distancetoentity = GetVectorDistance(cleyepos, endpos);
		int entindextoreturn = TR_GetEntityIndex(traceresulthandle);
		
		CloseHandle(traceresulthandle);
		
		return entindextoreturn;
		
	}
	
	CloseHandle(traceresulthandle);
	
	return -1;
}

stock bool GetClientAimPosition(int client, float maxtracedistance, float resultvecpos[3], float resultvecnormal[3], TraceEntityFilter Tfunction, int filter)
{
	float cleyepos[3], cleyeangle[3], eyeanglevector[3];
	GetClientEyePosition(client, cleyepos);
	GetClientEyeAngles(client, cleyeangle);
	
	Handle traceresulthandle = INVALID_HANDLE;
	
	traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, Tfunction, filter);
	
	if (TR_DidHit(traceresulthandle) == true) {
		
		float endpos[3];
		TR_GetEndPosition(endpos, traceresulthandle);
		TR_GetPlaneNormal(traceresulthandle, resultvecnormal);
		
		//거리가 일정 이하일 경우
		if ((GetVectorDistance(cleyepos, endpos) <= maxtracedistance) || maxtracedistance <= 0) {
			
			resultvecpos[0] = endpos[0];
			resultvecpos[1] = endpos[1];
			resultvecpos[2] = endpos[2];
			
			CloseHandle(traceresulthandle);
			return true;
			
		} else {
			
			GetAngleVectors(cleyeangle, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			
			AddVectors(cleyepos, eyeanglevector, resultvecpos);
			
			CloseHandle(traceresulthandle);
			return true;
			
		}
		
	}
	
	CloseHandle(traceresulthandle);
	return false;
}

public bool tracerayfilterrocket(int entity, int mask, any data)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (entity != data && owner != data)
	{
		return true;
	}
	else
	{
		return false;
	}
}

public bool tracerayfilterdefault(int entity, int mask, any data)
{
	if (entity != data)
	{
		return true;
	}
	else
	{
		return false;
	}
} 
