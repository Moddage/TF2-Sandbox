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
#include <tf2items_giveweapon>
#include <sdktools>
#include <sdkhooks>
#include <build>
#include <build_stocks>
#include <vphysics>
#include <smlib>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <stocklib>
#include <matrixmath>

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

new MoveType:g_mtGrabMoveType[MAXPLAYERS];
new g_iGrabTarget[MAXPLAYERS];
new Float:g_vGrabPlayerOrigin[MAXPLAYERS][3];
new bool:g_bGrabIsRunning[MAXPLAYERS];
new bool:g_bGrabFreeze[MAXPLAYERS];


new Handle:g_hCookieSDoorTarget;
new Handle:g_hCookieSDoorModel;

new Handle:g_hPropNameArray;
new Handle:g_hPropModelPathArray;
new Handle:g_hPropTypeArray;
new Handle:g_hPropStringArray;
new String:g_szFile[128];

new String:g_szConnectedClient[32][MAXPLAYERS];
//new String:g_szDisconnectClient[32][MAXPLAYERS];
new g_iTempOwner[MAX_HOOK_ENTITIES] =  { -1, ... };

new Float:g_fDelRangePoint1[MAXPLAYERS][3];
new Float:g_fDelRangePoint2[MAXPLAYERS][3];
new Float:g_fDelRangePoint3[MAXPLAYERS][3];
new String:g_szDelRangeStatus[MAXPLAYERS][8];
new bool:g_szDelRangeCancel[MAXPLAYERS] =  { false, ... };

new ColorBlue[4] =  {
	50, 
	50, 
	255, 
	255 };

new ColorWhite[4] =  {
	255, 
	255, 
	255, 
	255 };
new ColorRed[4] =  {
	255, 
	50, 
	50, 
	255 };
new ColorGreen[4] =  {
	50, 
	255, 
	50, 
	255 };

#include "GravityGun/GravityGunsound.inc"
#include "GravityGun/GravityGuncvars.inc"

#define EFL_NO_PHYSCANNON_INTERACTION (1<<30)

new g_Halo;
new g_PBeam;

new bool:g_bBuffer[MAXPLAYERS + 1];

new g_iCopyTarget[MAXPLAYERS];
new Float:g_fCopyPlayerOrigin[MAXPLAYERS][3];
new bool:g_bCopyIsRunning[MAXPLAYERS] = false;

new g_Beam;

new Handle:g_hMainMenu = INVALID_HANDLE;
new Handle:g_hPropMenu = INVALID_HANDLE;
new Handle:g_hEquipMenu = INVALID_HANDLE;
new Handle:g_hPoseMenu = INVALID_HANDLE;
new Handle:g_hPlayerStuff = INVALID_HANDLE;
new Handle:g_hCondMenu = INVALID_HANDLE;
new Handle:g_hRemoveMenu = INVALID_HANDLE;
new Handle:g_hBuildHelperMenu = INVALID_HANDLE;
new Handle:g_hPropMenuComic = INVALID_HANDLE;
new Handle:g_hPropMenuConstructions = INVALID_HANDLE;
new Handle:g_hPropMenuWeapons = INVALID_HANDLE;
new Handle:g_hPropMenuPickup = INVALID_HANDLE;
new Handle:g_hPropMenuHL2 = INVALID_HANDLE;

/*new String:g_szFile[128];
new Handle:g_hPropNameArray;
new Handle:g_hPropModelPathArray;
new Handle:g_hPropTypeArray;
new Handle:g_hPropStringArray;*/

new String:CopyableProps[][] =  {
	"prop_dynamic", 
	"prop_dynamic_override", 
	"prop_physics", 
	"prop_physics_multiplayer", 
	"prop_physics_override", 
	"prop_physics_respawnable", 
	"prop_ragdoll", 
	"func_physbox", 
	"player"
};

new String:EntityType[][] =  {
	"player", 
	"func_physbox", 
	"prop_door_rotating", 
	"prop_dynamic", 
	"prop_dynamic_ornament", 
	"prop_dynamic_override", 
	"prop_physics", 
	"prop_physics_multiplayer", 
	"prop_physics_override", 
	"prop_physics_respawnable", 
	"prop_ragdoll", 
	"item_ammo_357", 
	"item_ammo_357_large", 
	"item_ammo_ar2", 
	"item_ammo_ar2_altfire", 
	"item_ammo_ar2_large", 
	"item_ammo_crate", 
	"item_ammo_crossbow", 
	"item_ammo_pistol", 
	"item_ammo_pistol_large", 
	"item_ammo_smg1", 
	"item_ammo_smg1_grenade", 
	"item_ammo_smg1_large", 
	"item_battery", 
	"item_box_buckshot", 
	"item_dynamic_resupply", 
	"item_healthcharger", 
	"item_healthkit", 
	"item_healthvial", 
	"item_item_crate", 
	"item_rpg_round", 
	"item_suit", 
	"item_suitcharger", 
	"weapon_357", 
	"weapon_alyxgun", 
	"weapon_ar2", 
	"weapon_bugbait", 
	"weapon_crossbow", 
	"weapon_crowbar", 
	"weapon_frag", 
	"weapon_physcannon", 
	"weapon_pistol", 
	"weapon_rpg", 
	"weapon_shotgun", 
	"weapon_smg1", 
	"weapon_stunstick", 
	"weapon_slam", 
	"tf_viewmodel", 
	"tf_", 
	"gib"
};

new String:DelClass[][] =  {
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

enum PropTypeCheck {
	
	PROP_NONE = 0, 
	PROP_RIGID = 1, 
	PROP_PHYSBOX = 2, 
	PROP_WEAPON = 3, 
	PROP_TF2OBJ = 4,  //tf2 buildings
	PROP_RAGDOLL = 5, 
	PROP_TF2PROJ = 6,  //tf2 projectiles
	PROP_PLAYER = 7
	
};

//are they using grabber?
//new bool:grabenabled[MAXPLAYERS + 1];

new bool:g_bIsWeaponGrabber[MAXPLAYERS + 1];

//which entity is grabbed?(and are we currently grabbing anything?) this is entref, not ent index
new grabbedentref[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

new keybuffer[MAXPLAYERS + 1];

new Float:grabangle[MAXPLAYERS + 1][3];
new bool:firstGrab[MAXPLAYERS + 1];
new Float:grabdistance[MAXPLAYERS + 1];
new Float:resultangle[MAXPLAYERS + 1][3];

new Float:preeyangle[MAXPLAYERS + 1][3];
new Float:playeranglerotate[MAXPLAYERS + 1][3];

new Float:nextactivetime[MAXPLAYERS + 1];

new bool:entitygravitysave[MAXPLAYERS + 1];
new entityownersave[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

new PropTypeCheck:grabentitytype[MAXPLAYERS + 1];

new Handle:forwardOnClientGrabEntity = INVALID_HANDLE;
new Handle:forwardOnClientDragEntity = INVALID_HANDLE;
new Handle:forwardOnClientEmptyShootEntity = INVALID_HANDLE;
new Handle:forwardOnClientShootEntity = INVALID_HANDLE;
new g_PhysGunModel;
//new g_iBeam;
new g_iHalo;
//new g_iLaser;
new g_iPhys;

public Plugin:myinfo =  {
	name = "TF2 Sandbox All In One Module", 
	author = "Danct12, DaRkWoRlD, FlaminSarge, javalia, greenteaf0718, hjkwe654", 
	description = "Everything in one module, isn't that cool?", 
	version = BUILDMOD_VER, 
	url = "http://dtf2server.ddns.net"
};

public OnPluginStart() {
	// Client Language Base
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
	
	// Copy
	RegAdminCmd("+copy", Command_Copy, 0, "Copy a prop.");
	RegAdminCmd("-copy", Command_Paste, 0, "Paste a copied prop.");
	
	// Creator
	// For better compatibility
	RegConsoleCmd("kill", Command_kill, "");
	RegConsoleCmd("noclip", Command_Fly, "");
	//RegConsoleCmd("say", Command_Say, "");
	
	// Basic Spawn Commands
	RegAdminCmd("sm_spawnprop", Command_SpawnProp, 0, "Spawn a prop in command list!");
	RegAdminCmd("sm_prop", Command_SpawnProp, 0, "Spawn props in command list, too!");
	
	// More building useful stuffs
	RegAdminCmd("sm_skin", Command_Skin, 0, "Color a prop.");
	
	// Coloring Props and more
	RegAdminCmd("sm_color", Command_Color, 0, "Color a prop.");
	RegAdminCmd("sm_render", Command_Render, 0, "Render an entity.");
	
	// Rotating stuffs
	RegAdminCmd("sm_rotate", Command_Rotate, 0, "Rotate an entity.");
	RegAdminCmd("sm_r", Command_Rotate, 0, "Rotate an entity.");
	RegAdminCmd("sm_accuraterotate", Command_AccurateRotate, 0, "Accurate rotate a prop.");
	RegAdminCmd("sm_ar", Command_AccurateRotate, 0, "Accurate rotate a prop.");
	RegAdminCmd("sm_move", Command_Move, 0, "Move a prop to a position.");
	
	// Misc stuffs
	RegAdminCmd("sm_sdoor", Command_SpawnDoor, 0, "Doors creator.");
	RegAdminCmd("sm_lightforbesure", Command_LightDynamic, 0, "Dynamic Light.");
	RegAdminCmd("sm_fly", Command_Fly, 0, "I BELIEVE I CAN FLYYYYYYY, I BELIEVE THAT I CAN TOUCH DE SKY");
	RegAdminCmd("sm_setname", Command_SetName, 0, "SetPropname");
	RegAdminCmd("sm_simplelight", Command_SimpleLight, 0, "Spawn a Light, in a very simple way.");
	RegAdminCmd("sm_propdoor", Command_OpenableDoorProp, 0, "Making a door, in prop_door way.");
	RegAdminCmd("sm_propscale", Command_PropScale, ADMFLAG_SLAY, "Resizing a prop");
	
	// HL2 Props
	g_hPropMenuHL2 = CreateMenu(PropMenuHL2);
	SetMenuTitle(g_hPropMenuHL2, "TF2SB - HL2 Props and Miscs\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuHL2, true);
	AddMenuItem(g_hPropMenuHL2, "removeprops", "|Remove");
	
	g_hCookieSDoorTarget = RegClientCookie("cookie_SDoorTarget", "For SDoor.", CookieAccess_Private);
	g_hCookieSDoorModel = RegClientCookie("cookie_SDoorModel", "For SDoor.", CookieAccess_Private);
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
	g_hPropNameArray = CreateArray(33, 2048); // Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 2048); // Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 2048); // Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 2048);
	
	ReadProps();
	
	// Reload Plugin If You Want
	RegAdminCmd("sm_reload_tf2sb", Command_ReloadAIOPlugin, ADMFLAG_ROOT, "Reload the AIO Plugin of TF2 Sandbox");
	
	// Godmode Spawn
	HookEvent("player_spawn", Event_Spawn);
	RegAdminCmd("sm_god", Command_ChangeGodMode, 0, "Turn Godmode On/Off");
	
	// Grab
	RegAdminCmd("+grab", Command_EnableGrab, 0, "Grab props.");
	RegAdminCmd("-grab", Command_DisableGrab, 0, "Grab props.");
	
	// Messages
	LoadTranslations("common.phrases");
	CreateTimer(0.1, Display_Msgs, 0, TIMER_REPEAT);
	
	// Remover
	RegAdminCmd("sm_delall", Command_DeleteAll, 0, "Delete all of your spawned entitys.");
	RegAdminCmd("sm_del", Command_Delete, 0, "Delete an entity.");
	
	HookEntityOutput("prop_physics_respawnable", "OnBreak", OnPropBreak);
	
	// Buildings Belong To Us
	HookEvent("player_builtobject", Event_player_builtobject);
	
	// Simple Menu
	g_hMainMenu = CreateMenu(MainMenu);
	SetMenuTitle(g_hMainMenu, "TF2SB - Spawnlist v2");
	AddMenuItem(g_hMainMenu, "spawnlist", "Spawn...");
	AddMenuItem(g_hMainMenu, "equipmenu", "Equip...");
	AddMenuItem(g_hMainMenu, "playerstuff", "Player...");
	AddMenuItem(g_hMainMenu, "buildhelper", "Build Helper...");
	
	// Player Stuff for now
	g_hPlayerStuff = CreateMenu(PlayerStuff);
	SetMenuTitle(g_hPlayerStuff, "TF2SB - Player...");
	AddMenuItem(g_hPlayerStuff, "cond", "Conditions...");
	AddMenuItem(g_hPlayerStuff, "sizes", "Sizes...");
	AddMenuItem(g_hPlayerStuff, "poser", "Player Poser...");
	AddMenuItem(g_hPlayerStuff, "health", "Health");
	AddMenuItem(g_hPlayerStuff, "speed", "Speed");
	AddMenuItem(g_hPlayerStuff, "model", "Model");
	AddMenuItem(g_hPlayerStuff, "pitch", "Pitch");
	SetMenuExitBackButton(g_hPlayerStuff, true);
	
	// Init thing for commands!
	RegAdminCmd("sm_build", Command_BuildMenu, 0);
	RegAdminCmd("sm_sandbox", Command_BuildMenu, 0);
	RegAdminCmd("sm_t", Command_ToolGun, 0);
	RegAdminCmd("sm_g", Command_PhysGun, 0);
	RegAdminCmd("sm_resupply", Command_Resupply, 0);
	
	// Build Helper (placeholder)
	g_hBuildHelperMenu = CreateMenu(BuildHelperMenu);
	SetMenuTitle(g_hBuildHelperMenu, "TF2SB - Build Helper\nThis was actually a placeholder because we can't figure out how to make a toolgun");
	
	AddMenuItem(g_hBuildHelperMenu, "delprop", "Delete Prop");
	AddMenuItem(g_hBuildHelperMenu, "colors", "Color (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "effects", "Effects (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "skin", "Skin (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "rotate", "Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "accuraterotate", "Accurate Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "doors", "Doors (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "lights", "Lights");
	SetMenuExitBackButton(g_hBuildHelperMenu, true);
	
	// Remove Command
	g_hRemoveMenu = CreateMenu(RemoveMenu);
	SetMenuTitle(g_hRemoveMenu, "TF2SB - Remove");
	AddMenuItem(g_hRemoveMenu, "remove", "Remove that prop");
	AddMenuItem(g_hRemoveMenu, "delallfail", "To delete all, type !delall (there is no comeback)");
	
	SetMenuExitBackButton(g_hRemoveMenu, true);
	
	//Addcond Menu
	g_hCondMenu = CreateMenu(CondMenu);
	SetMenuTitle(g_hCondMenu, "TF2SB - Conditions...");
	AddMenuItem(g_hCondMenu, "godmode", "Godmode");
	AddMenuItem(g_hCondMenu, "crits", "Crits");
	AddMenuItem(g_hCondMenu, "noclip", "Noclip");
	//	AddMenuItem(g_hCondMenu, "infammo", "Inf. Ammo");
	AddMenuItem(g_hCondMenu, "speedboost", "Speed Boost");
	AddMenuItem(g_hCondMenu, "resupply", "Resupply");
	//	AddMenuItem(g_hCondMenu, "buddha", "Buddha");
	AddMenuItem(g_hCondMenu, "minicrits", "Mini-Crits");
	AddMenuItem(g_hCondMenu, "fly", "Fly");
	//	AddMenuItem(g_hCondMenu, "infclip", "Inf. Clip");
	AddMenuItem(g_hCondMenu, "damagereduce", "Damage Reduction");
	AddMenuItem(g_hCondMenu, "removeweps", "Remove Weapons");
	SetMenuExitBackButton(g_hCondMenu, true);
	
	// Equip Menu
	g_hEquipMenu = CreateMenu(EquipMenu);
	SetMenuTitle(g_hEquipMenu, "TF2SB - Equip...");
	
	AddMenuItem(g_hEquipMenu, "physgun", "Physics Gun");
	AddMenuItem(g_hEquipMenu, "toolgun", "Tool Gun");
	//	AddMenuItem(g_hEquipMenu, "portalgun", "Portal Gun");
	
	SetMenuExitBackButton(g_hEquipMenu, true);
	
	// Poser Menu
	g_hPoseMenu = CreateMenu(TF2SBPoseMenu);
	SetMenuTitle(g_hPoseMenu, "TF2SB - Player Poser...");
	AddMenuItem(g_hPoseMenu, "1", "-1x - Reversed");
	AddMenuItem(g_hPoseMenu, "2", "0x - Frozen");
	AddMenuItem(g_hPoseMenu, "3", "0.1x");
	AddMenuItem(g_hPoseMenu, "4", "0.25x");
	AddMenuItem(g_hPoseMenu, "5", "0.5x");
	AddMenuItem(g_hPoseMenu, "6", "1x - Normal");
	AddMenuItem(g_hPoseMenu, "7", "Untaunt");
	SetMenuExitBackButton(g_hPoseMenu, true);
	
	/* This goes for something called prop menu, i can't figure out how to make a config spawn list */
	
	// Prop Menu INIT
	g_hPropMenu = CreateMenu(PropMenu);
	SetMenuTitle(g_hPropMenu, "TF2SB - Spawn...\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenu, true);
	AddMenuItem(g_hPropMenu, "removeprops", "|Remove");
	AddMenuItem(g_hPropMenu, "constructprops", "Construction Props");
	AddMenuItem(g_hPropMenu, "comicprops", "Comic Props");
	AddMenuItem(g_hPropMenu, "pickupprops", "Pickup Props");
	AddMenuItem(g_hPropMenu, "weaponsprops", "Weapons Props");
	AddMenuItem(g_hPropMenu, "hl2props", "HL2 Props and Miscs");
	
	// Prop Menu Pickup
	g_hPropMenuPickup = CreateMenu(PropMenuPickup);
	SetMenuTitle(g_hPropMenuPickup, "TF2SB - Pickup Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuPickup, true);
	AddMenuItem(g_hPropMenuPickup, "removeprops", "|Remove");
	AddMenuItem(g_hPropMenuPickup, "medkit_large", "Medkit Large");
	AddMenuItem(g_hPropMenuPickup, "medkit_large_bday", "Medkit Large Bday");
	AddMenuItem(g_hPropMenuPickup, "medkit_medium", "Medkit Medium");
	AddMenuItem(g_hPropMenuPickup, "medkit_medium_bday", "Medkit Medium Bday");
	AddMenuItem(g_hPropMenuPickup, "medkit_small", "Medkit Small");
	AddMenuItem(g_hPropMenuPickup, "medkit_small_bday", "Medkit Small Bday");
	AddMenuItem(g_hPropMenuPickup, "ammopack_large", "Ammo Pack Large");
	AddMenuItem(g_hPropMenuPickup, "ammopack_large_bday", "Ammo Pack Large Bday");
	AddMenuItem(g_hPropMenuPickup, "ammopack_medium", "Ammo Pack Medium");
	AddMenuItem(g_hPropMenuPickup, "ammopack_medium_bday", "Ammo Pack Medium Bday");
	AddMenuItem(g_hPropMenuPickup, "ammopack_small", "Ammo Pack Small");
	AddMenuItem(g_hPropMenuPickup, "ammopack_small_bday", "Ammo Pack Small Bday");
	AddMenuItem(g_hPropMenuPickup, "platesandvich", "Sandvich Plate");
	AddMenuItem(g_hPropMenuPickup, "platesteak", "Steak Plate");
	AddMenuItem(g_hPropMenuPickup, "intelbriefcase", "Briefcase");
	AddMenuItem(g_hPropMenuPickup, "tf_gift", "Gift");
	AddMenuItem(g_hPropMenuPickup, "halloween_gift", "Big Gift");
	AddMenuItem(g_hPropMenuPickup, "plate_robo_sandwich", "Sandvich Robo Plate");
	AddMenuItem(g_hPropMenuPickup, "currencypack_large", "Currency Pack Large");
	AddMenuItem(g_hPropMenuPickup, "currencypack_medium", "Currency Pack Medium");
	AddMenuItem(g_hPropMenuPickup, "currencypack_small", "Currency Pack Small");
	
	// Prop Menu Weapons
	g_hPropMenuWeapons = CreateMenu(PropMenuWeapons);
	SetMenuTitle(g_hPropMenuWeapons, "TF2SB - Weapon Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuWeapons, true);
	AddMenuItem(g_hPropMenuWeapons, "removeprops", "|Remove");
	AddMenuItem(g_hPropMenuWeapons, "w_baseball", "Baseball");
	AddMenuItem(g_hPropMenuWeapons, "w_bat", "Bat");
	AddMenuItem(g_hPropMenuWeapons, "w_builder", "PDA Build");
	AddMenuItem(g_hPropMenuWeapons, "w_cigarette_case", "Cigarette Case");
	AddMenuItem(g_hPropMenuWeapons, "w_fireaxe", "Fire Axe");
	AddMenuItem(g_hPropMenuWeapons, "w_frontierjustice", "Frontier Justice");
	AddMenuItem(g_hPropMenuWeapons, "w_grenade_grenadelauncher", "Grenade");
	AddMenuItem(g_hPropMenuWeapons, "w_grenadelauncher", "Grenade Launcher");
	AddMenuItem(g_hPropMenuWeapons, "w_knife", "Knife");
	AddMenuItem(g_hPropMenuWeapons, "w_medigun", "Medi Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_minigun", "MiniGun");
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
	AddMenuItem(g_hPropMenuWeapons, "w_toolbox", "Toolbox");
	AddMenuItem(g_hPropMenuWeapons, "w_ttg_max_gun", "TTG Max Gun");
	AddMenuItem(g_hPropMenuWeapons, "w_wrangler", "The Wrangler");
	AddMenuItem(g_hPropMenuWeapons, "w_wrench", "Wrench");
	
	// Prop Menu Comics Prop
	g_hPropMenuComic = CreateMenu(PropMenuComics);
	SetMenuTitle(g_hPropMenuComic, "TF2SB - Comic Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuComic, true);
	AddMenuItem(g_hPropMenuComic, "removeprops", "|Remove");
	AddMenuItem(g_hPropMenuComic, "ingot001", "Gold Ingot");
	AddMenuItem(g_hPropMenuComic, "paint_can001", "Paint Can 1");
	AddMenuItem(g_hPropMenuComic, "paint_can002", "Paint Can 2");
	AddMenuItem(g_hPropMenuComic, "painting_02", "Painting 1");
	AddMenuItem(g_hPropMenuComic, "painting_03", "Painting 2");
	AddMenuItem(g_hPropMenuComic, "painting_04", "Painting 3");
	AddMenuItem(g_hPropMenuComic, "painting_05", "Painting 4");
	AddMenuItem(g_hPropMenuComic, "painting_06", "Painting 5");
	AddMenuItem(g_hPropMenuComic, "painting_07", "Painting 6");
	AddMenuItem(g_hPropMenuComic, "target_scout", "Target Scout");
	AddMenuItem(g_hPropMenuComic, "target_soldier", "Target Soldier");
	AddMenuItem(g_hPropMenuComic, "target_pyro", "Target Pyro");
	AddMenuItem(g_hPropMenuComic, "target_demoman", "Target Demoman");
	AddMenuItem(g_hPropMenuComic, "target_heavy", "Target Heavy");
	AddMenuItem(g_hPropMenuComic, "target_engineer", "Target Engineer");
	AddMenuItem(g_hPropMenuComic, "target_medic", "Target Medic");
	AddMenuItem(g_hPropMenuComic, "target_sniper", "Target Sniper");
	AddMenuItem(g_hPropMenuComic, "target_spy", "Target Spy");
	
	// Prop Menu Constructions Prop
	g_hPropMenuConstructions = CreateMenu(PropMenuConstructions);
	SetMenuTitle(g_hPropMenuConstructions, "TF2SB - Construction Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuConstructions, true);
	AddMenuItem(g_hPropMenuConstructions, "removeprops", "|Remove");
	AddMenuItem(g_hPropMenuConstructions, "air_intake", "Air Fan");
	AddMenuItem(g_hPropMenuConstructions, "baby_grand_01", "Grand Piano");
	AddMenuItem(g_hPropMenuConstructions, "barbell", "Barbell");
	AddMenuItem(g_hPropMenuConstructions, "barrel01", "Yellow Barrel");
	AddMenuItem(g_hPropMenuConstructions, "barrel02", "Dark Barrel");
	AddMenuItem(g_hPropMenuConstructions, "barrel03", "Yellow Barrel 2");
	AddMenuItem(g_hPropMenuConstructions, "barrel_flatbed01", "Barrel Flatbed");
	AddMenuItem(g_hPropMenuConstructions, "basketball_hoop", "Basketball Hoop");
	AddMenuItem(g_hPropMenuConstructions, "beer_keg001", "Beer Keg");
	AddMenuItem(g_hPropMenuConstructions, "bench001a", "Bench 1");
	AddMenuItem(g_hPropMenuConstructions, "bench001b", "Bench 2");
	AddMenuItem(g_hPropMenuConstructions, "bird", "Bird");
	AddMenuItem(g_hPropMenuConstructions, "bookcase_132_01", "Bookcase 1");
	AddMenuItem(g_hPropMenuConstructions, "bookcase_132_02", "Bookcase 2");
	AddMenuItem(g_hPropMenuConstructions, "bookcase_132_03", "Bookcase 3");
	AddMenuItem(g_hPropMenuConstructions, "bookpile_01", "Pile of Books");
	AddMenuItem(g_hPropMenuConstructions, "bookstand001", "Book Stand 1");
	AddMenuItem(g_hPropMenuConstructions, "bookstand002", "Book Stand 2");
	AddMenuItem(g_hPropMenuConstructions, "box_cluster01", "Cluster of Boxes");
	AddMenuItem(g_hPropMenuConstructions, "box_cluster02", "Cluster of Boxes 2");
	AddMenuItem(g_hPropMenuConstructions, "bullskull001", "Skull of a bull");
	AddMenuItem(g_hPropMenuConstructions, "campervan", "(HUN)Camper Van");
	AddMenuItem(g_hPropMenuConstructions, "cap_point_base", "Control Point");
	AddMenuItem(g_hPropMenuConstructions, "chair", "Chair");
	AddMenuItem(g_hPropMenuConstructions, "chalkboard01", "Chalk Board");
	AddMenuItem(g_hPropMenuConstructions, "chimney003", "Chimney 1");
	AddMenuItem(g_hPropMenuConstructions, "chimney005", "Chimney 2");
	AddMenuItem(g_hPropMenuConstructions, "chimney006", "Chimney 3");
	AddMenuItem(g_hPropMenuConstructions, "coffeemachine", "Coffee Machine");
	AddMenuItem(g_hPropMenuConstructions, "coffeepot", "Coffee Pot");
	AddMenuItem(g_hPropMenuConstructions, "computer_low", "Potato Computer");
	AddMenuItem(g_hPropMenuConstructions, "computer_printer", "Computer Printer");
	AddMenuItem(g_hPropMenuConstructions, "concrete_block001", "Concrete Block");
	AddMenuItem(g_hPropMenuConstructions, "concrete_pipe001", "Concrete Pipe 1");
	AddMenuItem(g_hPropMenuConstructions, "concrete_pipe002", "Concrete Pipe 2");
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
	AddMenuItem(g_hPropMenuConstructions, "couch_01", "Couch");
	AddMenuItem(g_hPropMenuConstructions, "crane_platform001", "Crane Platform");
	AddMenuItem(g_hPropMenuConstructions, "crane_platform001b", "Crane Platform 2");
	AddMenuItem(g_hPropMenuConstructions, "drain_pipe001", "Drain Pipe");
	AddMenuItem(g_hPropMenuConstructions, "dumptruck", "Dump Truck");
	AddMenuItem(g_hPropMenuConstructions, "dumptruck_empty", "Dump Truck (Empty)");
	AddMenuItem(g_hPropMenuConstructions, "fire_extinguisher", "Fire Extinguisher");
	AddMenuItem(g_hPropMenuConstructions, "fire_extinguisher_cabinet01", "Fire Extinguisher Cabinet");
	AddMenuItem(g_hPropMenuConstructions, "groundlight001", "Ground Light 1");
	AddMenuItem(g_hPropMenuConstructions, "groundlight002", "Ground Light 2");
	AddMenuItem(g_hPropMenuConstructions, "hardhat001", "Hard Hat");
	AddMenuItem(g_hPropMenuConstructions, "haybale", "Haybale");
	AddMenuItem(g_hPropMenuConstructions, "horseshoe001", "Horse Shoe)");
	AddMenuItem(g_hPropMenuConstructions, "hose001", "Hose");
	AddMenuItem(g_hPropMenuConstructions, "hubcap", "Hubcap");
	AddMenuItem(g_hPropMenuConstructions, "keg_large", "Large Keg");
	AddMenuItem(g_hPropMenuConstructions, "kitchen_shelf", "Kitchen Shelf");
	AddMenuItem(g_hPropMenuConstructions, "kitchen_stove", "Kitchen Stove");
	AddMenuItem(g_hPropMenuConstructions, "ladder001", "Ladder");
	AddMenuItem(g_hPropMenuConstructions, "lantern001", "Lantern (on)");
	AddMenuItem(g_hPropMenuConstructions, "lantern001_off", "Lantern (off)");
	AddMenuItem(g_hPropMenuConstructions, "locker001", "Locker");
	AddMenuItem(g_hPropMenuConstructions, "lunchbag", "Lunchbag");
	AddMenuItem(g_hPropMenuConstructions, "metalbucket001", "Metal Bucket");
	AddMenuItem(g_hPropMenuConstructions, "milk_crate", "Crate of Milk");
	AddMenuItem(g_hPropMenuConstructions, "milkjug001", "Milk Jug");
	AddMenuItem(g_hPropMenuConstructions, "miningcrate001", "Mining Crate 1");
	AddMenuItem(g_hPropMenuConstructions, "miningcrate002", "Mining Crate 2");
	AddMenuItem(g_hPropMenuConstructions, "mop_and_bucket", "Mop and Bucket");
	AddMenuItem(g_hPropMenuConstructions, "mvm_museum_case", "Museum Case");
	AddMenuItem(g_hPropMenuConstructions, "oilcan01", "Oilcan 1");
	AddMenuItem(g_hPropMenuConstructions, "oilcan01b", "Oilcan 1b");
	AddMenuItem(g_hPropMenuConstructions, "oilcan02", "Oilcan 2");
	AddMenuItem(g_hPropMenuConstructions, "oildrum", "Oildrum");
	AddMenuItem(g_hPropMenuConstructions, "padlock", "Padlock");
	AddMenuItem(g_hPropMenuConstructions, "pallet001", "Wood Pallet");
	AddMenuItem(g_hPropMenuConstructions, "pick001", "Wood Pickaxe");
	AddMenuItem(g_hPropMenuConstructions, "picnic_table", "Picnic Table");
	AddMenuItem(g_hPropMenuConstructions, "pill_bottle01", "Pill Bottle");
	AddMenuItem(g_hPropMenuConstructions, "portrait_01", "Portrait Painting");
	AddMenuItem(g_hPropMenuConstructions, "propane_tank_tall01", "Propane Tank Tall");
	AddMenuItem(g_hPropMenuConstructions, "resupply_locker", "Non-working Resupply Locker");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal001", "Roof Metal 1");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal002", "Roof Metal 2");
	AddMenuItem(g_hPropMenuConstructions, "roof_metal003", "Roof Metal 3");
	AddMenuItem(g_hPropMenuConstructions, "roof_vent001", "Roof Vent");
	AddMenuItem(g_hPropMenuConstructions, "sack_flat", "Sack Flat");
	AddMenuItem(g_hPropMenuConstructions, "sack_stack", "Sack Stack");
	AddMenuItem(g_hPropMenuConstructions, "sack_stack_pallet", "Sack Stack's Pallet");
	AddMenuItem(g_hPropMenuConstructions, "saw_blade", "Saw Blade");
	AddMenuItem(g_hPropMenuConstructions, "saw_blade_large", "Monster Saw Blade");
	AddMenuItem(g_hPropMenuConstructions, "shelf_props01", "Shelf of Tools");
	AddMenuItem(g_hPropMenuConstructions, "sign_barricade001a", "Barricade for Signs");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01", "Battlements Sign");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_hanging01", "Battlements Sign Hanging");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_sm", "Battlements Sign (Small)");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_witharrow_L_sm", "Battlements Sign (small) <-");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_witharrow_R_sm", "Battlements Sign (small) ->");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_witharrow_l", "Battlements Sign <-");
	AddMenuItem(g_hPropMenuConstructions, "sign_gameplay01_witharrow_r", "Battlements Sign ->");
	AddMenuItem(g_hPropMenuConstructions, "sign_wood_cap001", "Sign Wood Cap 1");
	AddMenuItem(g_hPropMenuConstructions, "sign_wood_cap002", "Sign Wood Cap 2");
	AddMenuItem(g_hPropMenuConstructions, "signpost001", "No Swimming Sign");
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
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container", "Container 1");
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container_01b", "Container 2");
	AddMenuItem(g_hPropMenuConstructions, "train_flatcar_container_01c", "Container 3");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel001", "Train Wheel 1");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel002", "Train Wheel 2");
	AddMenuItem(g_hPropMenuConstructions, "trainwheel003", "Train Wheel 3");
	AddMenuItem(g_hPropMenuConstructions, "tv001", "TV");
	AddMenuItem(g_hPropMenuConstructions, "uniform_locker", "Uniform Locker");
	AddMenuItem(g_hPropMenuConstructions, "uniform_locker_pj", "Uniform Locker 2");
	AddMenuItem(g_hPropMenuConstructions, "vent001", "Vent");
	AddMenuItem(g_hPropMenuConstructions, "wagonwheel001", "Wagon Wheel");
	AddMenuItem(g_hPropMenuConstructions, "wastebasket01", "Waste Basket");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel", "Water Barrel");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster", "Water Barrel Cluster 1");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster2", "Water Barrel Cluster 2");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_cluster3", "Water Barrel Cluster 3");
	AddMenuItem(g_hPropMenuConstructions, "water_barrel_large", "Water Barrel (large)");
	AddMenuItem(g_hPropMenuConstructions, "water_spigot", "Water Spigot");
	AddMenuItem(g_hPropMenuConstructions, "waterpump001", "Water Pump");
	AddMenuItem(g_hPropMenuConstructions, "weathervane001", "Weather Vane");
	AddMenuItem(g_hPropMenuConstructions, "weight_scale", "Weight Scale");
	AddMenuItem(g_hPropMenuConstructions, "welding_machine01", "Welding Machine");
	AddMenuItem(g_hPropMenuConstructions, "wood_crate_01", "Wood Crate");
	AddMenuItem(g_hPropMenuConstructions, "wood_pile", "Wood Pile");
	AddMenuItem(g_hPropMenuConstructions, "wood_pile_short", "Wood Pile Short");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform1", "Wood Platform 1");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform2", "Wood Platform 2");
	AddMenuItem(g_hPropMenuConstructions, "wood_platform3", "Wood Platform 3");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs128", "Wood Stairs 128");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs48", "Wood Stairs 48");
	AddMenuItem(g_hPropMenuConstructions, "wood_stairs96", "Wood Stairs 96");
	AddMenuItem(g_hPropMenuConstructions, "wooden_barrel", "Wooden Barrel");
	AddMenuItem(g_hPropMenuConstructions, "woodpile_indoor", "Wood Pile Indoor");
	AddMenuItem(g_hPropMenuConstructions, "work_table001", "Work Table");
	
	
	/*	g_hPropNameArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 2048);	// Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 2048);
	
	ReadProps();
	
	new String:szPropName[32], String:szPropFrozen[32], String:szPropString[256], String:szModelPath[128];
	
	new PropName = FindStringInArray(g_hPropNameArray, szPropName);
	new PropString = FindStringInArray(g_hPropNameArray, szPropString);*/
	
	creategravityguncvar();
	for (new client = 0; client <= MaxClients; client++)
	{
		g_bIsWeaponGrabber[client] = false;
		
		grabbedentref[client] = INVALID_ENT_REFERENCE;
		if (isClientConnectedIngame(client))
		{
			SDKHook(client, SDKHook_PreThink, PreThinkHook);
			SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitchHook);
		}
	}
	
	RegAdminCmd("sm_fda", ClientRemoveAll, ADMFLAG_SLAY);
	
}

stock Float:GetEntitiesDistance(ent1, ent2)
{
	new Float:orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	new Float:orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);
	
	return GetVectorDistance(orig1, orig2);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	
	CreateNative("GG_GetCurrentHeldEntity", Native_GetCurrntHeldEntity);
	CreateNative("GG_ForceDropHeldEntity", Native_ForceDropHeldEntity);
	CreateNative("GG_ForceGrabEntity", Native_ForceGrabEntity);
	
	forwardOnClientGrabEntity = CreateGlobalForward("OnClientGrabEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientDragEntity = CreateGlobalForward("OnClientDragEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientEmptyShootEntity = CreateGlobalForward("OnClientEmptyShootEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientShootEntity = CreateGlobalForward("OnClientShootEntity", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("GravityGun");
	
	return APLRes_Success;
	
}

public OnMapStart() {
	g_Halo = PrecacheModel("materials/sprites/halo01.vmt");
	g_Beam = PrecacheModel("materials/sprites/laser.vmt");
	g_PBeam = PrecacheModel("materials/sprites/physbeam.vmt");
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("buttons/button3.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
	PrecacheSound("npc/strider/charging.wav", true);
	PrecacheSound("npc/strider/fire.wav", true);
	for (new i = 1; i < MaxClients; i++) {
		g_szConnectedClient[i] = "";
		if (Build_IsClientValid(i, i))
			GetClientAuthId(i, AuthId_Steam2, g_szConnectedClient[i], sizeof(g_szConnectedClient));
	}
	
	prepatchsounds();
	
	g_iHalo = PrecacheModel("materials/sprites/halo01.vmt");
	//g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt");
	//	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	
	g_PhysGunModel = PrecacheModel("models/weapons/v_superphyscannon.mdl");
	
	AutoExecConfig();
}

public OnClientPutInServer(Client) {
	GetClientAuthId(Client, AuthId_Steam2, g_szConnectedClient[Client], sizeof(g_szConnectedClient));
	
	
	g_bIsWeaponGrabber[Client] = false;
	
	grabbedentref[Client] = INVALID_ENT_REFERENCE;
	
	SDKHook(Client, SDKHook_PreThink, PreThinkHook);
	SDKHook(Client, SDKHook_WeaponSwitch, WeaponSwitchHook);
}

public OnClientDisconnect(Client) {
	FakeClientCommand(Client, "sm_delall");
	/*g_szConnectedClient[Client] = "";
	GetClientAuthId(Client, AuthId_Steam2, g_szDisconnectClient[Client], sizeof(g_szDisconnectClient));
	new iCount;
	for (new iCheck = 0; iCheck < MAX_HOOK_ENTITIES; iCheck++) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == Client) {
				g_iTempOwner[iCheck] = Client;
				Build_RegisterEntityOwner(iCheck, -1);
				iCount++;
			}
		}
	}
	Build_SetLimit(Client, 0);
	Build_SetLimit(Client, 0, true);
	if (iCount > 0) {
		new Handle:hPack;
		CreateDataTimer(0.001, Timer_Disconnect, hPack);
		WritePackCell(hPack, Client);
		WritePackCell(hPack, 0);
	}*/
	
	//we must release any thing if it is on spectator`s hand
	release(Client);
}

public Action:Timer_Disconnect(Handle:Timer, Handle:hPack) {
	ResetPack(hPack);
	new Client = ReadPackCell(hPack);
	
	new iCount;
	for (new iCheck = Client; iCheck < MAX_HOOK_ENTITIES; iCheck++) {
		if (IsValidEntity(iCheck)) {
			if (g_iTempOwner[iCheck] == Client) {
				AcceptEntityInput(iCheck, "Kill", -1);
				iCount++;
			}
		}
	}
	
	return;
}

public Action:OnClientCommand(Client, args) {
	if (Client > 0) {
		if (Build_IsClientValid(Client, Client)) {
			new String:Lang[8];
			GetClientCookie(Client, g_hCookieClientLang, Lang, sizeof(Lang));
			if (StrEqual(Lang, "1"))
				g_bClientLang[Client] = true;
			else
				g_bClientLang[Client] = false;
		}
	}
}

public Action:Command_Copy(Client, args) {
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "You're doing it so fast! Slow it down!'");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	
	
	new iEntity = Build_ClientAimEntity(Client, true, true);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (!Build_IsAdmin(Client, true)) {
		if (GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (!Build_IsEntityOwner(Client, iEntity, true))
		return Plugin_Handled;
	
	if (g_bCopyIsRunning[Client]) {
		Build_PrintToChat(Client, "You are already copying something!");
		return Plugin_Handled;
	}
	
	new String:szClass[33], bool:bCanCopy = false;
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	for (new i = 0; i < sizeof(CopyableProps); i++) {
		if (StrEqual(szClass, CopyableProps[i], false))
			bCanCopy = true;
	}
	
	new bool:IsDoll = false;
	if (StrEqual(szClass, "prop_ragdoll") || StrEqual(szClass, "player")) {
		if (Build_IsAdmin(Client, true)) {
			g_iCopyTarget[Client] = CreateEntityByName("prop_ragdoll");
			IsDoll = true;
		} else {
			Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to copy this prop!");
			return Plugin_Handled;
		}
	} else {
		if (StrEqual(szClass, "func_physbox") && !Build_IsAdmin(Client, true)) {
			
			Build_PrintToChat(Client, "You can't copy this prop!");
			return Plugin_Handled;
		}
		
		g_iCopyTarget[Client] = CreateEntityByName(szClass);
	}
	
	if (Build_RegisterEntityOwner(g_iCopyTarget[Client], Client, IsDoll)) {
		if (bCanCopy) {
			new Float:fEntityOrigin[3], Float:fEntityAngle[3];
			new String:szModelName[128];
			new String:szColorR[20], String:szColorG[20], String:szColorB[20], String:szColor[3][128], String:szColor2[255];
			
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
			GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
			if (StrEqual(szModelName, "models/props_c17/oildrum001_explosive.mdl") && !Build_IsAdmin(Client, true)) {
				Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to copy this prop!");
				RemoveEdict(g_iCopyTarget[Client]);
				return Plugin_Handled;
			}
			DispatchKeyValue(g_iCopyTarget[Client], "model", szModelName);
			
			
			GetEdictClassname(g_iCopyTarget[Client], szClass, sizeof(szClass));
			if (StrEqual(szClass, "prop_dynamic")) {
				SetEntProp(g_iCopyTarget[Client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[Client], Prop_Data, "m_nSolidType", 6);
			}
			
			DispatchSpawn(g_iCopyTarget[Client]);
			TeleportEntity(g_iCopyTarget[Client], fEntityOrigin, fEntityAngle, NULL_VECTOR);
			
			if (Phys_IsPhysicsObject(g_iCopyTarget[Client]))
				Phys_EnableMotion(g_iCopyTarget[Client], false);
			
			GetCmdArg(1, szColorR, sizeof(szColorR));
			GetCmdArg(2, szColorG, sizeof(szColorG));
			GetCmdArg(3, szColorB, sizeof(szColorB));
			
			DispatchKeyValue(g_iCopyTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[Client], "renderamt", "150");
			DispatchKeyValue(g_iCopyTarget[Client], "renderfx", "4");
			
			if (args > 1) {
				szColor[0] = szColorR;
				szColor[1] = szColorG;
				szColor[2] = szColorB;
				ImplodeStrings(szColor, 3, " ", szColor2, 255);
				DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", szColor2);
			} else {
				DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", "50 255 255");
			}
			g_bCopyIsRunning[Client] = true;
			
			CreateTimer(0.01, Timer_CopyRing, Client);
			CreateTimer(0.01, Timer_CopyBeam, Client);
			CreateTimer(0.02, Timer_CopyMain, Client);
			return Plugin_Handled;
		} else {
			Build_PrintToChat(Client, "This prop was not copy able.");
			return Plugin_Handled;
		}
	} else {
		RemoveEdict(g_iCopyTarget[Client]);
		return Plugin_Handled;
	}
}

public Action:Command_Paste(Client, args) {
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client))
		return Plugin_Handled;
	
	g_bCopyIsRunning[Client] = false;
	return Plugin_Handled;
}

public Action:Timer_CopyBeam(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginPlayer[3], Float:fOriginEntity[3];
		
		GetClientAbsOrigin(Client, g_fCopyPlayerOrigin[Client]);
		GetClientAbsOrigin(Client, fOriginPlayer);
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		fOriginPlayer[2] += 50;
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = GetRandomInt(255, 255);
		
		TE_SetupBeamPoints(fOriginEntity, fOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
		if (g_bCopyIsRunning[Client])
			CreateTimer(0.01, Timer_CopyBeam, Client);
	}
}

public Action:Timer_CopyRing(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginEntity[3];
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(254, 255);
		iColor[2] = GetRandomInt(254, 255);
		iColor[3] = GetRandomInt(250, 255);
		
		TE_SetupBeamRingPoint(fOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(fOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
		if (g_bCopyIsRunning[Client])
			CreateTimer(0.3, Timer_CopyRing, Client);
	}
}

public Action:Timer_CopyMain(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginEntity[3], Float:fOriginPlayer[3];
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		GetClientAbsOrigin(Client, fOriginPlayer);
		
		fOriginEntity[0] += fOriginPlayer[0] - g_fCopyPlayerOrigin[Client][0];
		fOriginEntity[1] += fOriginPlayer[1] - g_fCopyPlayerOrigin[Client][1];
		fOriginEntity[2] += fOriginPlayer[2] - g_fCopyPlayerOrigin[Client][2];
		
		if (Phys_IsPhysicsObject(g_iCopyTarget[Client])) {
			Phys_EnableMotion(g_iCopyTarget[Client], false);
			Phys_Sleep(g_iCopyTarget[Client]);
		}
		SetEntityMoveType(g_iCopyTarget[Client], MOVETYPE_NONE);
		TeleportEntity(g_iCopyTarget[Client], fOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bCopyIsRunning[Client])
			CreateTimer(0.001, Timer_CopyMain, Client);
		else {
			if (Phys_IsPhysicsObject(g_iCopyTarget[Client])) {
				Phys_EnableMotion(g_iCopyTarget[Client], false);
				Phys_Sleep(g_iCopyTarget[Client]);
			}
			SetEntityMoveType(g_iCopyTarget[Client], MOVETYPE_VPHYSICS);
			
			DispatchKeyValue(g_iCopyTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[Client], "renderamt", "255");
			DispatchKeyValue(g_iCopyTarget[Client], "renderfx", "0");
			DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", "255 255 255");
		}
	}
}

public Action:Timer_CoolDown(Handle:hTimer, any:iBuffer)
{
	new iClient = GetClientFromSerial(iBuffer);
	
	if (g_bBuffer[iClient])g_bBuffer[iClient] = false;
}

public Action:Command_OpenableDoorProp(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	new iDoor = CreateEntityByName("prop_door_rotating");
	if (Build_RegisterEntityOwner(iDoor, Client)) {
		new String:szRange[33], String:szBrightness[33], String:szColorR[33], String:szColorG[33], String:szColorB[33];
		new String:szNamePropDoor[64];
		new Float:fOriginAim[3];
		GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(2, szBrightness, sizeof(szBrightness));
		GetCmdArg(3, szColorR, sizeof(szColorR));
		GetCmdArg(4, szColorG, sizeof(szColorG));
		GetCmdArg(5, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(Client, fOriginAim);
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
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_propdoor", szArgs);
	return Plugin_Handled;
}

public Action:Command_kill(Client, Args) {
	if (!Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	ForcePlayerSuicide(Client);
	
	//if (GetCmdArgs() > 0)
	//	Build_PrintToChat(Client, "Don't use unneeded args in kill");
	
	return Plugin_Handled;
}

public Action:Command_ReloadAIOPlugin(Client, Args) {
	if (!Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	ReadProps();
	Build_PrintToAll("TF2 Sandbox has updated!");
	Build_PrintToAll("Please type !build to begin building!");
	
	//if (GetCmdArgs() > 0)
	//	Build_PrintToChat(Client, "Don't use unneeded args in kill");
	
	return Plugin_Handled;
}

public Action:Command_Render(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 5) {
		
		Build_PrintToChat(Client, "Usage: !render <fx amount> <fx> <R> <G> <B>");
		Build_PrintToChat(Client, "Ex. Flashing Green: !render 150 4 15 255 0");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szRenderAlpha[20], String:szRenderFX[20], String:szColorRGB[20][3], String:szColors[128];
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
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_render", szArgs);
	return Plugin_Handled;
}

public Action:Command_Color(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 3) {
		Build_PrintToChat(Client, "Usage: !color <R> <G> <B>");
		Build_PrintToChat(Client, "Ex: Green: !color 0 255 0");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szColorRGB[20][3], String:szColors[33];
		GetCmdArg(1, szColorRGB[0], sizeof(szColorRGB));
		GetCmdArg(2, szColorRGB[1], sizeof(szColorRGB));
		GetCmdArg(3, szColorRGB[2], sizeof(szColorRGB));
		
		Format(szColors, sizeof(szColors), "%s %s %s", szColorRGB[0], szColorRGB[1], szColorRGB[2]);
		DispatchKeyValue(iEntity, "rendermode", "5");
		DispatchKeyValue(iEntity, "renderamt", "255");
		DispatchKeyValue(iEntity, "renderfx", "0");
		DispatchKeyValue(iEntity, "rendercolor", szColors);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_color", szArgs);
	return Plugin_Handled;
}

public Action:Command_PropScale(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !propscale <number>");
		Build_PrintToChat(Client, "Notice: Physics are non-scaled.");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		
		//new Float:Scale2  = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
		new String:szPropScale[33];
		GetCmdArg(1, szPropScale, sizeof(szPropScale));
		
		new Float:Scale = StringToFloat(szPropScale);
		
		SetVariantString(szPropScale);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", Scale);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_propscale", szArgs);
	return Plugin_Handled;
}

public Action:Command_Skin(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !skin <number>");
		Build_PrintToChat(Client, "Notice: Not every model have multiple skins.");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szSkin[33];
		GetCmdArg(1, szSkin, sizeof(szSkin));
		
		SetVariantString(szSkin);
		AcceptEntityInput(iEntity, "skin", iEntity, Client, 0);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_skin", szArgs);
	return Plugin_Handled;
}

public Action:Command_Rotate(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !rotate/!r <x> <y> <z>");
		Build_PrintToChat(Client, "Ex: !rotate 0 90 0");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szAngleX[8], String:szAngleY[8], String:szAngleZ[8];
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];
		GetCmdArg(1, szAngleX, sizeof(szAngleX));
		GetCmdArg(2, szAngleY, sizeof(szAngleY));
		GetCmdArg(3, szAngleZ, sizeof(szAngleZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		fEntityAngle[0] += StringToFloat(szAngleX);
		fEntityAngle[1] += StringToFloat(szAngleY);
		fEntityAngle[2] += StringToFloat(szAngleZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_rotate", szArgs);
	return Plugin_Handled;
}

public Action:Command_Fly(Client, args) {
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true) || !Build_AllowFly(Client))
		return Plugin_Handled;
	
	if (GetEntityMoveType(Client) != MOVETYPE_NOCLIP)
	{
		Build_PrintToChat(Client, "Noclip ON");
		SetEntityMoveType(Client, MOVETYPE_NOCLIP);
	}
	else
	{
		Build_PrintToChat(Client, "Noclip OFF");
		SetEntityMoveType(Client, MOVETYPE_WALK);
	}
	return Plugin_Handled;
}

public Action:Command_SimpleLight(Client, args) {
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	// Spoiler: I'm Lazy
	FakeClientCommand(Client, "sm_lightforbesure 500 5 255 255 255");
	
	return Plugin_Handled;
}

public Action:Command_AccurateRotate(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !ar <x> <y> <z>");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szRotateX[33], String:szRotateY[33], String:szRotateZ[33];
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];
		GetCmdArg(1, szRotateX, sizeof(szRotateX));
		GetCmdArg(2, szRotateY, sizeof(szRotateY));
		GetCmdArg(3, szRotateZ, sizeof(szRotateZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		fEntityAngle[0] = StringToFloat(szRotateX);
		fEntityAngle[1] = StringToFloat(szRotateY);
		fEntityAngle[2] = StringToFloat(szRotateZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_accuraterotate", szArgs);
	return Plugin_Handled;
}

public Action:Command_LightDynamic(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !ld <range> <brightness> <R> <G> <B>");
		return Plugin_Handled;
	}
	
	new Obj_LightDMelon = CreateEntityByName("prop_dynamic");
	if (Build_RegisterEntityOwner(Obj_LightDMelon, Client)) {
		new String:szRange[33], String:szBrightness[33], String:szColorR[33], String:szColorG[33], String:szColorB[33], String:szColor[33];
		new String:szNameMelon[64];
		new Float:fOriginAim[3];
		GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(2, szBrightness, sizeof(szBrightness));
		GetCmdArg(3, szColorR, sizeof(szColorR));
		GetCmdArg(4, szColorG, sizeof(szColorG));
		GetCmdArg(5, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(Client, fOriginAim);
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
		
		new Obj_LightDynamic = CreateEntityByName("light_dynamic");
		if (StringToInt(szRange) > 500) {
			Build_PrintToChat(Client, "Max range is 500!");
			return Plugin_Handled;
		}
		if (StringToInt(szBrightness) > 7) {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "亮度上限是 7!");
			else
				Build_PrintToChat(Client, "Max brightness is 7!");
			return Plugin_Handled;
		}
		SetVariantString(szRange);
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
		AcceptEntityInput(Obj_LightDynamic, "turnon", Client, Client);
	} else
		RemoveEdict(Obj_LightDMelon);
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_lightforbesure", szArgs);
	return Plugin_Handled;
}

public Action:Command_SpawnDoor(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	decl String:szDoorTarget[16], String:szType[4], String:szFormatStr[64], String:szNameStr[8];
	decl Float:iAim[3];
	Build_ClientAimOrigin(Client, iAim);
	GetCmdArg(1, szType, sizeof(szType));
	static iEntity;
	new String:szModel[128];
	
	if (StrEqual(szType[0], "1") || StrEqual(szType[0], "2") || StrEqual(szType[0], "3") || StrEqual(szType[0], "4") || StrEqual(szType[0], "5") || StrEqual(szType[0], "6") || StrEqual(szType[0], "7")) {
		new Obj_Door = CreateEntityByName("prop_dynamic");
		
		switch (szType[0]) {
			case '1':szModel = "models/props_lab/blastdoor001c.mdl";
			case '2':szModel = "models/props_lab/blastdoor001c.mdl";
			case '3':szModel = "models/props_lab/blastdoor001c.mdl";
			case '4':szModel = "models/props_lab/blastdoor001c.mdl";
			case '5':szModel = "models/props_lab/blastdoor001c.mdl";
			case '6':szModel = "models/props_lab/blastdoor001c.mdl";
			case '7':szModel = "models/props_lab/blastdoor001c.mdl";
		}
		
		DispatchKeyValue(Obj_Door, "model", szModel);
		SetEntProp(Obj_Door, Prop_Send, "m_nSolidType", 6);
		if (Build_RegisterEntityOwner(Obj_Door, Client)) {
			TeleportEntity(Obj_Door, iAim, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(Obj_Door);
		}
	} else if (StrEqual(szType[0], "a") || StrEqual(szType[0], "b") || StrEqual(szType[0], "c")) {
		
		iEntity = Build_ClientAimEntity(Client);
		if (iEntity == -1)
			return Plugin_Handled;
		
		switch (szType[0]) {
			case 'a': {
				new iName = GetRandomInt(1000, 5000);
				
				IntToString(iName, szNameStr, sizeof(szNameStr));
				Format(szFormatStr, sizeof(szFormatStr), "door%s", szNameStr);
				DispatchKeyValue(iEntity, "targetname", szFormatStr);
				
				GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				SetClientCookie(Client, g_hCookieSDoorTarget, szFormatStr);
				SetClientCookie(Client, g_hCookieSDoorModel, szModel);
			}
			case 'b': {
				GetClientCookie(Client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(Client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				
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
				GetClientCookie(Client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(Client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				DispatchKeyValue(iEntity, "spawnflags", "258");
				
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
		Build_PrintToChat(Client, "Usage: !sdoor <choose>");
		Build_PrintToChat(Client, "!sdoor 1~7 = Spawn door");
		Build_PrintToChat(Client, "!sdoor a = Select door");
		Build_PrintToChat(Client, "!sdoor b = Select button (Shoot to open)");
		Build_PrintToChat(Client, "!sdoor c = Select button (Press to open)");
		Build_PrintToChat(Client, "NOTE: Not all doors movable using PhysGun, use the !move command!");
	}
	return Plugin_Handled;
}


public Action:Command_Move(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !move <x> <y> <z>");
		Build_PrintToChat(Client, "Ex, move up 50: !move 0 0 50");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];
		new String:szArgX[33], String:szArgY[33], String:szArgZ[33];
		GetCmdArg(1, szArgX, sizeof(szArgX));
		GetCmdArg(2, szArgY, sizeof(szArgY));
		GetCmdArg(3, szArgZ, sizeof(szArgZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		
		fEntityOrigin[0] += StringToFloat(szArgX);
		fEntityOrigin[1] += StringToFloat(szArgY);
		fEntityOrigin[2] += StringToFloat(szArgZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_move", szArgs);
	return Plugin_Handled;
}

public Action:Command_SetName(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !setname <name you want it to be>");
		Build_PrintToChat(Client, "Ex: !setname \"A teddy bear\"");
		Build_PrintToChat(Client, "Ex: !setname \"Gabe Newell\"");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:newpropname[256];
		GetCmdArg(args, newpropname, sizeof(newpropname));
		//Format(newpropname, sizeof(newpropname), "%s", args);
		SetEntPropString(iEntity, Prop_Data, "m_iName", newpropname);
	}
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_setname", szArgs);
	return Plugin_Handled;
}

public Action:Command_SpawnProp(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !spawnprop/!s <Prop name>");
		Build_PrintToChat(Client, "Ex: !spawnprop goldbar");
		Build_PrintToChat(Client, "Ex: !spawnprop alyx");
		return Plugin_Handled;
	}
	
	new String:szPropName[32], String:szPropFrozen[32], String:szPropString[256], String:szModelPath[128];
	GetCmdArg(1, szPropName, sizeof(szPropName));
	GetCmdArg(2, szPropFrozen, sizeof(szPropFrozen));
	
	new IndexInArray = FindStringInArray(g_hPropNameArray, szPropName);
	
	if (StrEqual(szPropName, "explosivecan") && !Build_IsAdmin(Client, true)) {
		Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to spawn this prop!");
		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	if (IndexInArray != -1) {
		new bool:bIsDoll = false;
		new String:szEntType[33];
		GetArrayString(g_hPropTypeArray, IndexInArray, szEntType, sizeof(szEntType));
		
		if (!Build_IsAdmin(Client, true)) {
			if (StrEqual(szPropName, "explosivecan") || StrEqual(szEntType, "prop_ragdoll")) {
				Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to spawn this prop!");
				return Plugin_Handled;
			}
		}
		if (StrEqual(szEntType, "prop_ragdoll"))
			bIsDoll = true;
		
		new iEntity = CreateEntityByName(szEntType);
		
		if (Build_RegisterEntityOwner(iEntity, Client, bIsDoll)) {
			new Float:fOriginWatching[3], Float:fOriginFront[3], Float:fAngles[3], Float:fRadiansX, Float:fRadiansY;
			
			decl Float:iAim[3];
			new Float:vOriginPlayer[3];
			
			GetClientEyePosition(Client, fOriginWatching);
			GetClientEyeAngles(Client, fAngles);
			
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
			
			if (StrEqual(szEntType, "prop_dynamic"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			if (StrEqual(szEntType, "prop_dynamic_override"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			Build_ClientAimOrigin(Client, iAim);
			iAim[2] = iAim[2] + 10;
			
			GetClientAbsOrigin(Client, vOriginPlayer);
			vOriginPlayer[2] = vOriginPlayer[2] + 50;
			
			
			DispatchSpawn(iEntity);
			TeleportEntity(iEntity, iAim, NULL_VECTOR, NULL_VECTOR);
			
			
			
			TE_SetupBeamPoints(iAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
			TE_SendToAll();
			
			new random = GetRandomInt(0, 1);
			if (random == 1) {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			} else {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			}
			
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);
			
			// Debugging issues
			//PrintToChatAll(szPropString);
			
			new PlayerSpawnCheck;
			
			while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
			{
				if (Entity_InRange(iEntity, PlayerSpawnCheck, 400.0))
				{
					PrintCenterText(Client, "Prop is too near the spawn!");
					Build_SetLimit(Client, -1);
					AcceptEntityInput(iEntity, "kill");
					
				}
			}
			
			
			if (!StrEqual(szPropFrozen, "")) {
				if (Phys_IsPhysicsObject(iEntity))
					Phys_EnableMotion(iEntity, false);
			}
		} else
			RemoveEdict(iEntity);
	} else {
		Build_PrintToChat(Client, "Prop not found: %s", szPropName);
	}
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_spawnprop", szArgs);
	return Plugin_Handled;
}

ReadProps() {
	BuildPath(Path_SM, g_szFile, sizeof(g_szFile), "configs/buildmod/props.ini");
	
	new Handle:iFile = OpenFile(g_szFile, "rt");
	if (iFile == INVALID_HANDLE)
		return;
	
	new iCountProps = 0;
	while (!IsEndOfFile(iFile))
	{
		decl String:szLine[255];
		if (!ReadFileLine(iFile, szLine, sizeof(szLine)))
			break;
		
		/* 略過註解 */
		new iLen = strlen(szLine);
		new bool:bIgnore = false;
		
		for (new i = 0; i < iLen; i++) {
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
		
		ReadPropsLine(szLine, iCountProps++);
	}
	CloseHandle(iFile);
}

ReadPropsLine(const String:szLine[], iCountProps) {
	decl String:szPropInfo[4][128];
	ExplodeString(szLine, ", ", szPropInfo, sizeof(szPropInfo), sizeof(szPropInfo[]));
	
	StripQuotes(szPropInfo[0]);
	SetArrayString(g_hPropNameArray, iCountProps, szPropInfo[0]);
	
	StripQuotes(szPropInfo[1]);
	SetArrayString(g_hPropModelPathArray, iCountProps, szPropInfo[1]);
	
	StripQuotes(szPropInfo[2]);
	SetArrayString(g_hPropTypeArray, iCountProps, szPropInfo[2]);
	
	StripQuotes(szPropInfo[3]);
	SetArrayString(g_hPropStringArray, iCountProps, szPropInfo[3]);
	
	AddMenuItem(g_hPropMenuHL2, szPropInfo[0], szPropInfo[3]);
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	
	nextactivetime[client] = GetGameTime();
}

public Action:Command_ChangeGodMode(Client, Args) {
	if (!Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (GetEntProp(Client, Prop_Data, "m_takedamage") == 0)
	{
		Build_PrintToChat(Client, "God Mode OFF");
		SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
	}
	else
	{
		Build_PrintToChat(Client, "God Mode ON");
		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
	}
	
	return Plugin_Handled;
}

public Action:Command_EnableGrab(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	g_iGrabTarget[Client] = Build_ClientAimEntity(Client, true, true);
	if (g_iGrabTarget[Client] == -1)
		return Plugin_Handled;
	
	if (g_bGrabIsRunning[Client]) {
		Build_PrintToChat(Client, "You are already grabbing something!");
		return Plugin_Handled;
	}
	
	if (!Build_IsAdmin(Client)) {
		if (GetEntityFlags(g_iGrabTarget[Client]) == (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (Build_IsEntityOwner(Client, g_iGrabTarget[Client])) {
		decl String:szFreeze[20], String:szColorR[20], String:szColorG[20], String:szColorB[20], String:szColor[128];
		GetCmdArg(1, szFreeze, sizeof(szFreeze));
		GetCmdArg(2, szColorR, sizeof(szColorR));
		GetCmdArg(3, szColorG, sizeof(szColorG));
		GetCmdArg(4, szColorB, sizeof(szColorB));
		
		g_bGrabFreeze[Client] = true;
		if (StrEqual(szFreeze, "1"))
			g_bGrabFreeze[Client] = true;
		
		DispatchKeyValue(g_iGrabTarget[Client], "rendermode", "5");
		DispatchKeyValue(g_iGrabTarget[Client], "renderamt", "150");
		DispatchKeyValue(g_iGrabTarget[Client], "renderfx", "4");
		
		if (StrEqual(szColorR, ""))
			szColorR = "255";
		if (StrEqual(szColorG, ""))
			szColorG = "50";
		if (StrEqual(szColorB, ""))
			szColorB = "50";
		Format(szColor, sizeof(szColor), "%s %s %s", szColorR, szColorG, szColorB);
		DispatchKeyValue(g_iGrabTarget[Client], "rendercolor", szColor);
		
		g_mtGrabMoveType[Client] = GetEntityMoveType(g_iGrabTarget[Client]);
		g_bGrabIsRunning[Client] = true;
		
		CreateTimer(0.01, Timer_GrabBeam, Client);
		CreateTimer(0.01, Timer_GrabRing, Client);
		CreateTimer(0.05, Timer_GrabMain, Client);
	}
	return Plugin_Handled;
}

public Action:Command_DisableGrab(Client, args) {
	g_bGrabIsRunning[Client] = false;
	return Plugin_Handled;
}

public Action:Timer_GrabBeam(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		new Float:vOriginEntity[3], Float:vOriginPlayer[3];
		
		GetClientAbsOrigin(Client, g_vGrabPlayerOrigin[Client]);
		GetClientAbsOrigin(Client, vOriginPlayer);
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		vOriginPlayer[2] += 50;
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamPoints(vOriginEntity, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.01, Timer_GrabBeam, Client);
	}
}

public Action:Timer_GrabRing(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		new Float:vOriginEntity[3];
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamRingPoint(vOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SetupBeamRingPoint(vOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.3, Timer_GrabRing, Client);
	}
}

public Action:Timer_GrabMain(Handle:Timer, any:Client) {
	if (IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		if (!Build_IsAdmin(Client)) {
			if (Build_ReturnEntityOwner(g_iGrabTarget[Client]) != Client) {
				g_bGrabIsRunning[Client] = false;
				return;
			}
		}
		
		new Float:vOriginEntity[3], Float:vOriginPlayer[3];
		
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		GetClientAbsOrigin(Client, vOriginPlayer);
		
		vOriginEntity[0] += vOriginPlayer[0] - g_vGrabPlayerOrigin[Client][0];
		vOriginEntity[1] += vOriginPlayer[1] - g_vGrabPlayerOrigin[Client][1];
		vOriginEntity[2] += vOriginPlayer[2] - g_vGrabPlayerOrigin[Client][2];
		
		if (Phys_IsPhysicsObject(g_iGrabTarget[Client])) {
			Phys_EnableMotion(g_iGrabTarget[Client], false);
			Phys_Sleep(g_iGrabTarget[Client]);
		}
		SetEntityMoveType(g_iGrabTarget[Client], MOVETYPE_NONE);
		TeleportEntity(g_iGrabTarget[Client], vOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.001, Timer_GrabMain, Client);
		else {
			if (GetEntityFlags(g_iGrabTarget[Client]) & (FL_CLIENT | FL_FAKECLIENT))
				SetEntityMoveType(g_iGrabTarget[Client], MOVETYPE_WALK);
			else {
				if (!g_bGrabFreeze[Client] && Phys_IsPhysicsObject(g_iGrabTarget[Client])) {
					Phys_EnableMotion(g_iGrabTarget[Client], true);
					Phys_Sleep(g_iGrabTarget[Client]);
				}
				SetEntityMoveType(g_iGrabTarget[Client], g_mtGrabMoveType[Client]);
			}
			DispatchKeyValue(g_iGrabTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iGrabTarget[Client], "renderamt", "255");
			DispatchKeyValue(g_iGrabTarget[Client], "renderfx", "0");
			DispatchKeyValue(g_iGrabTarget[Client], "rendercolor", "255 255 255");
		}
	}
	return;
}

// Messages
public Action:Display_Msgs(Handle:timer) {
	for (new Client = 1; Client <= MaxClients; Client++) {
		if (Build_IsClientValid(Client, Client, true) && !IsFakeClient(Client)) {
			new iAimTarget = Build_ClientAimEntity(Client, false, true);
			if (iAimTarget != -1 && IsValidEdict(iAimTarget))
				EntityInfo(Client, iAimTarget);
		}
	}
	return;
}

public EntityInfo(Client, iTarget) {
	if (IsFunc(iTarget))
		return;
	
	if (IsWorldEnt(iTarget)) {
		if (Build_IsAdmin(Client)) {
			new String:szSteamId[32], String:szIP[16];
			GetClientAuthString(iTarget, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			ShowHudText(Client, -1, "%s\nIs a World Entity.", iTarget);
		} else {
		}
	}
	
	SetHudTextParams(0.015, 0.08, 0.1, 255, 255, 255, 255, 0, 6.0, 0.1, 0.2);
	if (IsPlayer(iTarget)) {
		new iHealth = GetClientHealth(iTarget);
		if (iHealth <= 1)
			iHealth = 0;
		if (Build_IsAdmin(Client)) {
			new String:szSteamId[32], String:szIP[16];
			GetClientAuthString(iTarget, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			ShowHudText(Client, -1, "Player: %N\nHealth: %i\nUserID: %i\nSteamID:%s", iTarget, iHealth, GetClientUserId(iTarget), szSteamId);
		} else {
			ShowHudText(Client, -1, "Player: %N\nHealth: %i", iTarget, iHealth);
		}
		return;
	}
	new String:szClass[32];
	GetEdictClassname(iTarget, szClass, sizeof(szClass));
	if (IsNpc(iTarget)) {
		new iHealth = GetEntProp(iTarget, Prop_Data, "m_iHealth");
		if (iHealth <= 1)
			iHealth = 0;
		ShowHudText(Client, -1, "Classname: %s\nHealth: %i", szClass, iHealth);
		return;
	}
	
	new String:szModel[128], String:szOwner[32], String:szPropString[256];
	new String:szGetThoseString = GetEntPropString(iTarget, Prop_Data, "m_iName", szPropString, sizeof(szPropString));
	new iOwner = Build_ReturnEntityOwner(iTarget);
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	if (iOwner != -1)
		GetClientName(iOwner, szOwner, sizeof(szOwner));
	else if (iOwner > MAXPLAYERS) {
		szOwner = "*Disconnected";
	} else {
		szOwner = "*World";
	}
	
	if (Phys_IsPhysicsObject(iTarget)) {
		SetHudTextParams(-1.0, 0.6, 0.1, 255, 0, 0, 255);
		if (StrContains(szClass, "prop_door_", false) == 0) {
			ShowHudText(Client, -1, "%s \nbuilt by %s\nPress [TAB] to use", szPropString, szOwner);
		}
		else {
			ShowHudText(Client, -1, "%s \nbuilt by %s", szPropString, szOwner);
		}
		//if (g_bClientLang[Client])
		
		//ShowHudText(Client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s\n重量:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
		//else
		//ShowHudText(Client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s\nMass:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
	} else {
		if (g_bClientLang[Client])
			ShowHudText(Client, -1, "%s \nbuilt by %s", szPropString, szOwner);
		//ShowHudText(Client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s", szClass, iTarget, szModel, szOwner);
		//else
		//ShowHudText(Client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s", szClass, iTarget, szModel, szOwner);
	}
	return;
}

bool:IsFunc(iEntity) {
	new String:szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "func_", false) == 0 && !StrEqual(szClass, "func_physbox"))
		return true;
	return false;
}

bool:IsNpc(iEntity) {
	new String:szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "npc_", false) == 0)
		return true;
	return false;
}

bool:IsWorldEnt(iEntity) {
	new String:szOwner[32];
	if (StrContains(szOwner, "*World", false) == 0)
		return true;
	return false;
}

bool:IsPlayer(iEntity) {
	if ((GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT)))
		return true;
	return false;
}

// Remover.sp

public Action:Command_DeleteAll(Client, args) {
	if (!Build_AllowToUse(Client) || !Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new iCheck = 0, iCount = 0;
	while (iCheck < MAX_HOOK_ENTITIES) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == Client) {
				for (new i = 0; i < sizeof(DelClass); i++) {
					new String:szClass[32];
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
		Build_PrintToChat(Client, "Deleted all props you owns.");
	} else {
		Build_PrintToChat(Client, "You don't have any props.");
	}
	
	Build_SetLimit(Client, 0);
	Build_SetLimit(Client, 0, true);
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_delall", szArgs);
	return Plugin_Handled;
}

public Action:Command_Delete(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	new iEntity = Build_ClientAimEntity(Client, true, true);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szClass[33];
		GetEdictClassname(iEntity, szClass, sizeof(szClass));
		DispatchKeyValue(iEntity, "targetname", "Del_Drop");
		
		if (!Build_IsAdmin(Client)) {
			if (StrEqual(szClass, "prop_vehicle_driveable") || StrEqual(szClass, "prop_vehicle") || StrEqual(szClass, "prop_vehicle_airboat") || StrEqual(szClass, "prop_vehicle_prisoner_pod")) {
				Build_PrintToChat(Client, "You can't delete this prop!");
				return Plugin_Handled;
			}
		}
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		new Obj_Dissolver = CreateDissolver("3");
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		new random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
		
		DispatchKeyValue(iEntity, "targetname", "Del_Target");
		
		TE_SetupBeamRingPoint(vOriginAim, 10.0, 150.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, ColorWhite, 20, 0);
		TE_SendToAll();
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		if (Build_IsAdmin(Client)) {
			if (StrEqual(szClass, "player") || StrContains(szClass, "prop_") == 0 || StrContains(szClass, "npc_") == 0 || StrContains(szClass, "weapon_") == 0 || StrContains(szClass, "item_") == 0) {
				SetVariantString("Del_Target");
				AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
				AcceptEntityInput(Obj_Dissolver, "kill", -1);
				DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
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
		
		if (StrEqual(szClass, "prop_ragdoll"))
			Build_SetLimit(Client, -1, true);
		else
			Build_SetLimit(Client, -1);
		Build_RegisterEntityOwner(iEntity, -1);
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_del", szArgs);
	return Plugin_Handled;
}

public Action:Command_DelRange(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new String:szCancel[32];
	GetCmdArg(1, szCancel, sizeof(szCancel));
	if (!StrEqual(szCancel, "") && (!StrEqual(g_szDelRangeStatus[Client], "off") || !StrEqual(g_szDelRangeStatus[Client], ""))) {
		Build_PrintToChat(Client, "Canceled DelRange");
		g_szDelRangeCancel[Client] = true;
		return Plugin_Handled;
	}
	
	if (StrEqual(g_szDelRangeStatus[Client], "x"))
		g_szDelRangeStatus[Client] = "y";
	else if (StrEqual(g_szDelRangeStatus[Client], "y"))
		g_szDelRangeStatus[Client] = "z";
	else if (StrEqual(g_szDelRangeStatus[Client], "z"))
		g_szDelRangeStatus[Client] = "off";
	else {
		Build_ClientAimOrigin(Client, g_fDelRangePoint1[Client]);
		g_szDelRangeStatus[Client] = "x";
		CreateTimer(0.05, Timer_DR, Client);
	}
	return Plugin_Handled;
}

public Action:Command_DelStrider(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new Float:fRange, String:szRange[5], Float:vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(Client, vOriginAim);
	
	new Handle:hDataPack;
	CreateDataTimer(0.01, Timer_DScharge, hDataPack);
	WritePackCell(hDataPack, Client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}

public Action:Command_DelStrider2(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new Float:fRange, String:szRange[5], Float:vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(Client, vOriginAim);
	
	new Handle:hDataPack;
	CreateDataTimer(0.01, Timer_DScharge2, hDataPack);
	WritePackCell(hDataPack, Client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}


public Action:Timer_DR(Handle:Timer, any:Client) {
	if (!Build_IsClientValid(Client, Client))
		return;
	if (g_szDelRangeCancel[Client]) {
		g_szDelRangeCancel[Client] = false;
		g_szDelRangeStatus[Client] = "off";
		return;
	}
	
	new Float:vPoint2[3], Float:vPoint3[3], Float:vPoint4[3];
	new Float:vClonePoint1[3], Float:vClonePoint2[3], Float:vClonePoint3[3], Float:vClonePoint4[3];
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	
	if (StrEqual(g_szDelRangeStatus[Client], "x")) {
		Build_ClientAimOrigin(Client, vOriginAim);
		vPoint2[0] = vOriginAim[0];
		vPoint2[1] = vOriginAim[1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint2, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint2[Client] = vPoint2;
		CreateTimer(0.001, Timer_DR, Client);
	} else if (StrEqual(g_szDelRangeStatus[Client], "y")) {
		Build_ClientAimOrigin(Client, vOriginAim);
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = vOriginAim[2];
		vPoint4[0] = vPoint2[0];
		vPoint4[1] = vPoint2[1];
		vPoint4[2] = vOriginAim[2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = vOriginAim[2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = vOriginAim[2];
		
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint3, vClonePoint3, ColorRed);
		DrowLine(vPoint3, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vClonePoint3, ColorRed);
		DrowLine(vPoint4, vClonePoint4, ColorRed);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint4, vPoint2, ColorRed);
		DrowLine(vClonePoint1, vClonePoint3, ColorRed);
		DrowLine(vClonePoint2, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint3[Client] = vPoint4;
		CreateTimer(0.001, Timer_DR, Client);
	} else if (StrEqual(g_szDelRangeStatus[Client], "z")) {
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[Client][2];
		
		DrowLine(g_fDelRangePoint1[Client], vClonePoint1, ColorGreen);
		DrowLine(g_fDelRangePoint1[Client], vClonePoint2, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint2, ColorGreen);
		DrowLine(vPoint3, vClonePoint3, ColorGreen);
		DrowLine(vPoint3, vClonePoint4, ColorGreen);
		DrowLine(g_fDelRangePoint3[Client], vClonePoint3, ColorGreen);
		DrowLine(g_fDelRangePoint3[Client], vClonePoint4, ColorGreen);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorGreen);
		DrowLine(vPoint2, g_fDelRangePoint3[Client], ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		TE_SetupBeamPoints(vPoint3, g_fDelRangePoint1[Client], g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(g_fDelRangePoint3[Client], vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint3, vClonePoint1, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint4, vClonePoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		
		CreateTimer(0.001, Timer_DR, Client);
	} else {
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = g_fDelRangePoint3[Client][2];
		
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = g_fDelRangePoint1[Client][2];
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = vPoint2[2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[Client][2];
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint3, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vClonePoint4, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vPoint2, vClonePoint1, ColorWhite, true);
		DrowLine(vPoint2, vClonePoint2, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint3, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint4, ColorWhite, true);
		DrowLine(vPoint2, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint1, vClonePoint3, ColorWhite, true);
		DrowLine(vClonePoint2, vClonePoint4, ColorWhite, true);
		
		new Obj_Dissolver = CreateEntityByName("env_entity_dissolver");
		DispatchKeyValue(Obj_Dissolver, "dissolvetype", "3");
		DispatchKeyValue(Obj_Dissolver, "targetname", "Del_Dissolver");
		DispatchSpawn(Obj_Dissolver);
		ActivateEntity(Obj_Dissolver);
		
		new Float:vOriginEntity[3], String:szClass[32];
		new iCount = 0;
		new iEntity = -1;
		for (new i = 0; i < sizeof(EntityType); i++) {
			while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
				GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
				vOriginEntity[2] += 1;
				if (vOriginEntity[0] != 0 && vOriginEntity[1] != 1 && vOriginEntity[2] != 0 && Build_IsInSquare(vOriginEntity, g_fDelRangePoint1[Client], g_fDelRangePoint3[Client])) {
					GetEdictClassname(iEntity, szClass, sizeof(szClass));
					if (StrEqual(szClass, "func_physbox"))
						AcceptEntityInput(iEntity, "kill", -1);
					else {
						DispatchKeyValue(iEntity, "targetname", "Del_Target");
						SetVariantString("Del_Target");
						AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
						DispatchKeyValue(iEntity, "targetname", "Del_Drop");
					}
					
					new iOwner = Build_ReturnEntityOwner(iEntity);
					if (iOwner != -1) {
						if (StrEqual(szClass, "prop_ragdoll"))
							Build_SetLimit(iOwner, -1, true);
						else
							Build_SetLimit(iOwner, -1);
						
						Build_RegisterEntityOwner(iEntity, -1);
					}
				}
			}
		}
		AcceptEntityInput(Obj_Dissolver, "kill", -1);
		
		if (iCount > 0)
			Build_PrintToChat(Client, "Deleted %i props.", iCount);
	}
}

public Action:Timer_DScharge(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(Client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	new Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "20");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	new Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	/*
	new String:szPointTeslaName[128], String:szThickMin[64], String:szThickMax[64], String:szOnUser[128], String:szKill[64];
	new Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	new Float:fThickMin = StringToFloat(szRange) / 40;
	new Float:iThickMax = StringToFloat(szRange) / 30;
	Format(szThickMin, sizeof(szThickMin), "%i", RoundToFloor(fThickMin));
	Format(szThickMax, sizeof(szThickMax), "%i", RoundToFloor(iThickMax));
	
	DispatchKeyValue(Obj_PointTesla, "targetname", szPointTeslaName);
	DispatchKeyValue(Obj_PointTesla, "sprite", "sprites/physbeam.vmt");
	DispatchKeyValue(Obj_PointTesla, "m_color", "255 255 255");
	DispatchKeyValue(Obj_PointTesla, "m_flradius", szRange);
	DispatchKeyValue(Obj_PointTesla, "beamcount_min", "100");
	DispatchKeyValue(Obj_PointTesla, "beamcount_max", "500");
	DispatchKeyValue(Obj_PointTesla, "thick_min", szThickMin);
	DispatchKeyValue(Obj_PointTesla, "thick_max", szThickMax);
	DispatchKeyValue(Obj_PointTesla, "lifetime_min", "0.1");
	DispatchKeyValue(Obj_PointTesla, "lifetime_max", "0.1");
	
	new Float:f;
	for (f = 0.0; f < 1.3; f=f+0.05) {
		Format(szOnUser, sizeof(szOnUser), "%s,dospark,,%f", szPointTeslaName, f);
		DispatchKeyValue(Obj_PointTesla, "onuser1", szOnUser);
	}
	Format(szKill, sizeof(szKill), "%s,kill,,1.3", szPointTeslaName);
	DispatchSpawn(Obj_PointTesla);
	DispatchKeyValue(Obj_PointTesla, "onuser1", szKill);
	AcceptEntityInput(Obj_PointTesla, "fireuser1", -1);
	*/
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 15.0, 15.0, 0, 0.0, ColorBlue, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Handle:hNewPack;
	CreateDataTimer(1.3, Timer_DSfire, hNewPack);
	WritePackCell(hNewPack, Client);
	WritePackCell(hNewPack, Obj_Push);
	WritePackCell(hNewPack, Obj_Core);
	WritePackFloat(hNewPack, fRange);
	WritePackFloat(hNewPack, vOriginAim[0]);
	WritePackFloat(hNewPack, vOriginAim[1]);
	WritePackFloat(hNewPack, vOriginAim[2]);
	WritePackFloat(hNewPack, vOriginPlayer[0]);
	WritePackFloat(hNewPack, vOriginPlayer[1]);
	WritePackFloat(hNewPack, vOriginPlayer[2]);
}

public Action:Timer_DSfire(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Obj_Push = ReadPackCell(hDataPack);
	new Obj_Core = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	vOriginPlayer[0] = ReadPackFloat(hDataPack);
	vOriginPlayer[1] = ReadPackFloat(hDataPack);
	vOriginPlayer[2] = ReadPackFloat(hDataPack);
	
	if (IsValidEntity(Obj_Push))
		AcceptEntityInput(Obj_Push, "kill", -1);
	if (IsValidEntity(Obj_Core))
		AcceptEntityInput(Obj_Core, "kill", -1);
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Obj_Dissolver = CreateDissolver("3");
	new Float:vOriginEntity[3];
	new iCount = 0;
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			new String:szClass[33];
			GetEdictClassname(iEntity, szClass, sizeof(szClass));
			if (vOriginEntity[0] != 0 && vOriginEntity[1] != 1 && vOriginEntity[2] != 0 && !StrEqual(szClass, "player") && Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
				if (StrEqual(szClass, "func_physbox"))
					AcceptEntityInput(iEntity, "kill", -1);
				else {
					DispatchKeyValue(iEntity, "targetname", "Del_Target");
					SetVariantString("Del_Target");
					AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
					DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				}
				
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
					else
						Build_SetLimit(iOwner, -1);
					
					Build_RegisterEntityOwner(iEntity, -1);
				}
				iCount++;
			}
		}
	}
	AcceptEntityInput(Obj_Dissolver, "kill", -1);
	if (iCount > 0 && Build_IsClientValid(Client, Client))
		Build_PrintToChat(Client, "Deleted %i props.", iCount);
}

public Action:Timer_DScharge2(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(Client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	new Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "28");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	new Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	
	new Float:vOriginEntity[3], String:szClass[32];
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] = (vOriginEntity[2] + 1);
			if (Phys_IsPhysicsObject(iEntity)) {
				GetEdictClassname(iEntity, szClass, sizeof(szClass));
				if (Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
					Phys_EnableMotion(iEntity, true);
					if (StrEqual(szClass, "player"))
						SetEntityMoveType(iEntity, MOVETYPE_WALK);
					else
						SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
				}
			}
		}
	}
	/*
	new String:szPointTeslaName[128], String:szThickMin[64], String:szThickMax[64], String:szOnUser[128], String:szKill[64];
	new Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	new Float:fThickMin = StringToFloat(szRange) / 40;
	new Float:iThickMax = StringToFloat(szRange) / 30;
	Format(szThickMin, sizeof(szThickMin), "%i", RoundToFloor(fThickMin));
	Format(szThickMax, sizeof(szThickMax), "%i", RoundToFloor(iThickMax));
	
	DispatchKeyValue(Obj_PointTesla, "targetname", szPointTeslaName);
	DispatchKeyValue(Obj_PointTesla, "sprite", "sprites/physbeam.vmt");
	DispatchKeyValue(Obj_PointTesla, "m_color", "255 255 255");
	DispatchKeyValue(Obj_PointTesla, "m_flradius", szRange);
	DispatchKeyValue(Obj_PointTesla, "beamcount_min", "100");
	DispatchKeyValue(Obj_PointTesla, "beamcount_max", "500");
	DispatchKeyValue(Obj_PointTesla, "thick_min", szThickMin);
	DispatchKeyValue(Obj_PointTesla, "thick_max", szThickMax);
	DispatchKeyValue(Obj_PointTesla, "lifetime_min", "0.1");
	DispatchKeyValue(Obj_PointTesla, "lifetime_max", "0.1");
	
	new Float:f;
	for (f = 0.0; f < 1.3; f=f+0.05) {
		Format(szOnUser, sizeof(szOnUser), "%s,dospark,,%f", szPointTeslaName, f);
		DispatchKeyValue(Obj_PointTesla, "onuser1", szOnUser);
	}
	Format(szKill, sizeof(szKill), "%s,kill,,1.3", szPointTeslaName);
	DispatchSpawn(Obj_PointTesla);
	DispatchKeyValue(Obj_PointTesla, "onuser1", szKill);
	AcceptEntityInput(Obj_PointTesla, "fireuser1", -1);
	*/
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 15.0, 15.0, 0, 0.0, ColorBlue, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Handle:hNewPack;
	CreateDataTimer(1.3, Timer_DSfire2, hNewPack);
	WritePackCell(hNewPack, Client);
	WritePackCell(hNewPack, Obj_Push);
	WritePackCell(hNewPack, Obj_Core);
	WritePackFloat(hNewPack, fRange);
	WritePackFloat(hNewPack, vOriginAim[0]);
	WritePackFloat(hNewPack, vOriginAim[1]);
	WritePackFloat(hNewPack, vOriginAim[2]);
	WritePackFloat(hNewPack, vOriginPlayer[0]);
	WritePackFloat(hNewPack, vOriginPlayer[1]);
	WritePackFloat(hNewPack, vOriginPlayer[2]);
}

public Action:Timer_DSfire2(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Obj_Push = ReadPackCell(hDataPack);
	new Obj_Core = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	vOriginPlayer[0] = ReadPackFloat(hDataPack);
	vOriginPlayer[1] = ReadPackFloat(hDataPack);
	vOriginPlayer[2] = ReadPackFloat(hDataPack);
	
	if (IsValidEntity(Obj_Push))
		AcceptEntityInput(Obj_Push, "kill", -1);
	if (IsValidEntity(Obj_Core))
		AcceptEntityInput(Obj_Core, "kill", -1);
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Obj_Dissolver = CreateDissolver("3");
	new Float:vOriginEntity[3];
	new iCount = 0;
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			new String:szClass[33];
			GetEdictClassname(iEntity, szClass, sizeof(szClass));
			if (vOriginEntity[0] != 0 && vOriginEntity[1] != 1 && vOriginEntity[2] != 0 && Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
				if (StrEqual(szClass, "func_physbox"))
					AcceptEntityInput(iEntity, "kill", -1);
				else {
					DispatchKeyValue(iEntity, "targetname", "Del_Target");
					SetVariantString("Del_Target");
					AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
					DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				}
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
					else
						Build_SetLimit(iOwner, -1);
					
					Build_RegisterEntityOwner(iEntity, -1);
				}
				iCount++;
			}
		}
	}
	AcceptEntityInput(Obj_Dissolver, "kill", -1);
	if (iCount > 0 && Build_IsClientValid(Client, Client))
		Build_PrintToChat(Client, "Deleted %i props.", iCount);
}

public OnPropBreak(const String:output[], iEntity, iActivator, Float:delay) {
	if (IsValidEntity(iEntity))
		CreateTimer(0.1, Timer_PropBreak, iEntity);
}

public Action:Timer_PropBreak(Handle:Timer, any:iEntity) {
	if (!IsValidEntity(iEntity))
		return;
	new iOwner = Build_ReturnEntityOwner(iEntity);
	if (iOwner > 0) {
		Build_SetLimit(iOwner, -1);
		Build_RegisterEntityOwner(iEntity, -1);
		AcceptEntityInput(iEntity, "kill", -1);
	}
}

stock DrowLine(Float:vPoint1[3], Float:vPoint2[3], Color[4], bool:bFinale = false) {
	if (bFinale)
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.5, 7.0, 7.0, 0, 0.0, Color, 20);
	else
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, Color, 20);
	TE_SendToAll();
}

stock CreatePush(Float:vOrigin[3], Float:fMagnitude, Float:fRange, String:szSpawnFlags[8]) {
	new Push_Index = CreateEntityByName("point_push");
	TeleportEntity(Push_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Push_Index, "magnitude", fMagnitude);
	DispatchKeyValueFloat(Push_Index, "radius", fRange);
	DispatchKeyValueFloat(Push_Index, "inner_radius", fRange);
	DispatchKeyValue(Push_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Push_Index);
	return Push_Index;
}

stock CreateCore(Float:vOrigin[3], Float:fScale, String:szSpawnFlags[8]) {
	new Core_Index = CreateEntityByName("env_citadel_energy_core");
	TeleportEntity(Core_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Core_Index, "scale", fScale);
	DispatchKeyValue(Core_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Core_Index);
	return Core_Index;
}

stock CreateDissolver(String:szDissolveType[4]) {
	new Dissolver_Index = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(Dissolver_Index, "dissolvetype", szDissolveType);
	DispatchKeyValue(Dissolver_Index, "targetname", "Del_Dissolver");
	DispatchSpawn(Dissolver_Index);
	return Dissolver_Index;
}

// SimpleMenu.sp

public Action:Command_BuildMenu(client, args)
{
	if (client > 0)
	{
		DisplayMenu(g_hMainMenu, client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public Action:Command_ToolGun(client, args)
{
	if (client > 0)
	{
		DisplayMenu(g_hBuildHelperMenu, client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public Action:Command_PhysGun(client, args)
{
	Build_PrintToChat(client, "You have a Physics Gun!");
	Build_PrintToChat(client, "Your Physics Gun will be in the secondary slot.");
	TF2Items_GiveWeapon(client, 99999);
	new weapon = GetPlayerWeaponSlot(client, 1);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}

public Action:Command_Resupply(client, args)
{
	Build_PrintToChat(client, "You're now resupplied.'");
	TF2_RegeneratePlayer(client);
}

public MainMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		new String:item[64];
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
		
	}
}

public PropMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
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
		else if (StrEqual(info, "pickupprops"))
		{
			DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		}
		else if (StrEqual(info, "hl2props"))
		{
			DisplayMenu(g_hPropMenuHL2, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public CondMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenu(g_hCondMenu, param1, MENU_TIME_FOREVER);
		new String:item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "crits"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_CritCanteen))
			{
				Build_PrintToChat(param1, "Crit Cond OFF");
				TF2_RemoveCondition(param1, TFCond_CritCanteen);
			}
			else
			{
				Build_PrintToChat(param1, "Crit Cond ON");
				TF2_AddCondition(param1, TFCond_CritCanteen, TFCondDuration_Infinite, 0);
			}
		}
		
		/*if (StrEqual(item, "infammo"))
		{
			Build_PrintToChat(param1, "Learn more at !aiamenu");
		}
		
		if (StrEqual(item, "infclip"))
		{
			Build_PrintToChat(param1, "Learn more at !aiamenu");
		}*/
		
		if (StrEqual(item, "resupply"))
		{
			TF2_RegeneratePlayer(param1);
		}
		
		if (StrEqual(item, "noclip"))
		{
			FakeClientCommand(param1, "sm_fly");
		}
		
		if (StrEqual(item, "godmode"))
		{
			FakeClientCommand(param1, "sm_god");
		}
		
		/*if (StrEqual(item, "buddha"))
		{
			FakeClientCommand(param1, "sm_buddha");				
		}*/
		
		if (StrEqual(item, "fly"))
		{
			if (!Build_AllowToUse(param1) || Build_IsBlacklisted(param1) || !Build_IsClientValid(param1, param1, true) || !Build_AllowFly(param1))
				return Plugin_Handled;
			
			if (GetEntityMoveType(param1) != MOVETYPE_FLY)
			{
				Build_PrintToChat(param1, "Fly ON");
				SetEntityMoveType(param1, MOVETYPE_FLY);
			}
			else
			{
				Build_PrintToChat(param1, "Fly OFF");
				SetEntityMoveType(param1, MOVETYPE_WALK);
			}
		}
		
		if (StrEqual(item, "minicrits"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_NoHealingDamageBuff))
			{
				Build_PrintToChat(param1, "Mini-Crits OFF");
				TF2_RemoveCondition(param1, TFCond_NoHealingDamageBuff);
			}
			else
			{
				Build_PrintToChat(param1, "Mini-Crits ON");
				TF2_AddCondition(param1, TFCond_NoHealingDamageBuff, TFCondDuration_Infinite, 0);
			}
		}
		
		if (StrEqual(item, "damagereduce"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_DefenseBuffNoCritBlock))
			{
				Build_PrintToChat(param1, "Damage Reduction OFF");
				TF2_RemoveCondition(param1, TFCond_DefenseBuffNoCritBlock);
			}
			else
			{
				Build_PrintToChat(param1, "Damage Reduction ON");
				TF2_AddCondition(param1, TFCond_DefenseBuffNoCritBlock, TFCondDuration_Infinite, 0);
			}
		}
		
		if (StrEqual(item, "speedboost"))
		{
			if (TF2_IsPlayerInCondition(param1, TFCond_HalloweenSpeedBoost))
			{
				Build_PrintToChat(param1, "Speed Boost OFF");
				TF2_RemoveCondition(param1, TFCond_HalloweenSpeedBoost);
			}
			else
			{
				Build_PrintToChat(param1, "Speed Boost ON");
				TF2_AddCondition(param1, TFCond_HalloweenSpeedBoost, TFCondDuration_Infinite, 0);
			}
		}
		
		if (StrEqual(item, "removeweps"))
		{
			TF2_RemoveAllWeapons(param1);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public PlayerStuff(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		new String:item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "cond"))
		{
			DisplayMenu(g_hCondMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "sizes"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "poser"))
		{
			DisplayMenu(g_hPoseMenu, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "health"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "speed"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "model"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(item, "pitch"))
		{
			Build_PrintToChat(param1, "Not yet implemented");
			DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public EquipMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenu(g_hEquipMenu, param1, MENU_TIME_FOREVER);
		new String:item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "physgun"))
		{
			Build_PrintToChat(param1, "You have a Physics Gun!");
			Build_PrintToChat(param1, "Your Physics Gun will be in the secondary slot.");
			TF2Items_GiveWeapon(param1, 99999);
			new weapon = GetPlayerWeaponSlot(param1, 1);
			SetEntPropEnt(param1, Prop_Send, "m_hActiveWeapon", weapon);
		}
		if (StrEqual(item, "toolgun"))
		{
			FakeClientCommand(param1, "sm_t");
		}
		/*if (StrEqual(item, "portalgun"))
		{
				FakeClientCommand(param1, "sm_portalgun");
		}*/
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public RemoveMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		new String:item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "remove"))
		{
			FakeClientCommand(param1, "sm_del");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public BuildHelperMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenu(g_hBuildHelperMenu, param1, MENU_TIME_FOREVER);
		new String:item[64];
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
			FakeClientCommand(param1, "sm_simplelight");
		}
		else if (StrEqual(item, "doors"))
		{
			FakeClientCommand(param1, "sm_propdoor");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public TF2SBPoseMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
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
				Build_PrintToChat(param1, "You're now no longer taunting.'");
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
}

public PropMenuHL2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuHL2, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public PropMenuConstructions(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuConstructions, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuConstructions, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public PropMenuComics(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuComic, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuComic, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public PropMenuWeapons(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuWeapons, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public PropMenuPickup(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuPickup, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else
		{
			FakeClientCommand(param1, "sm_prop %s", info);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}


// GravityGun.SP

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	
	if (isClientConnectedIngameAlive(client)) {
		
		if (clientisgrabbingvalidobject(client)) {
			
			
			if (buttons & IN_RELOAD) {
				
				ZeroVector(vel);
				
				
				
				if (buttons & IN_FORWARD) {
					
					buttons &= ~IN_FORWARD;
					
					if (buttons & IN_SPEED) {
						
						grabdistance[client] = grabdistance[client] + 10.0;
						
					} else {
						
						grabdistance[client] = grabdistance[client] + 1.0;
						
					}
					
					if (grabdistance[client] >= GetConVarFloat(cvar_grab_maxdistance)) {
						
						grabdistance[client] = GetConVarFloat(cvar_grab_maxdistance);
						
					}
					
				} else if (buttons & IN_BACK) {
					
					buttons &= ~IN_BACK;
					
					if (buttons & IN_SPEED) {
						
						grabdistance[client] = grabdistance[client] - 10.0;
						
					} else {
						
						grabdistance[client] = grabdistance[client] - 1.0;
						
					}
					
					if (grabdistance[client] < GetConVarFloat(cvar_grab_mindistance)) {
						
						grabdistance[client] = GetConVarFloat(cvar_grab_mindistance);
						
					}
					
				}
			}
			
		}
	}
	return Plugin_Continue;
	
}

public Action:WeaponSwitchHook(client, entity) {
	
	decl String:weaponname[64];
	if (!isClientConnectedIngameAlive(client) || !IsValidEntity(entity)) {
		
		g_bIsWeaponGrabber[client] = false;
		return Plugin_Continue;
		
	}
	
	GetEdictClassname(entity, weaponname, sizeof(weaponname));
	
	new rulecheck = GetConVarInt(g_cvarWeaponSwitchRule);
	
	if (!isWeaponGrabber(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon")) || EntRefToEntIndex(grabbedentref[client]) == -1 || !Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))) {
		
		g_bIsWeaponGrabber[client] = isWeaponGrabber(entity);
		if (g_bIsWeaponGrabber[client])
		{
			new ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			SetEntProp(ent, Prop_Send, "m_nModelIndex", g_PhysGunModel, 2);
			SetEntProp(ent, Prop_Send, "m_nSequence", 2);
		}
		else
		{
			new ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			if (TF2_GetPlayerClass(client) == TFClass_Heavy)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_heavy_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_scout_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Soldier)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_soldier_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Pyro)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_pyro_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_demo_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Engineer)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_engineer_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Medic)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_medic_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Sniper)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_sniper_arms.mdl"), 2);
			}
			else if (TF2_GetPlayerClass(client) == TFClass_Spy)
			{
				SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel("models/weapons/c_models/c_spy_arms.mdl"), 2);
			}
			else
			{
				PrintToChatAll("Who the fuck would even be no class");
			}
		}
		
		return Plugin_Continue;
		
	} else {
		if (rulecheck == 0) {
			return Plugin_Handled;
			
		} else {
			
			g_bIsWeaponGrabber[client] = isWeaponGrabber(entity);
			
			if (!g_bIsWeaponGrabber[client] || rulecheck == 1)release(client);
			return Plugin_Continue;
			
		}
		
	}
	
}

public PreThinkHook(client) {
	
	if (isClientConnectedIngameAlive(client)) {
		
		new buttons = GetClientButtons(client);
		new clientteam = GetClientTeam(client);
		
		
		
		if (buttons & IN_ATTACK2 && !(keybuffer[client] & IN_ATTACK2) && GetConVarBool(g_cvarEnableMotionControl)) {
			if (grabbedentref[client] != 0 && g_bIsWeaponGrabber[client] && grabbedentref[client] != INVALID_ENT_REFERENCE)
			{
				if (Phys_IsMotionEnabled(EntRefToEntIndex(grabbedentref[client]))) {
					
					keybuffer[client] = keybuffer[client] | IN_ATTACK2;
					AcceptEntityInput(grabbedentref[client], "DisableMotion");
					playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_MOTION);
					release(client);
					return;
					
				} else {
					
					keybuffer[client] = keybuffer[client] | IN_ATTACK2;
					AcceptEntityInput(grabbedentref[client], "EnableMotion");
					playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_MOTION);
					return;
					
				}
				
				
			}
			
			
		}
		
		if ((buttons & IN_RELOAD) && clientisgrabbingvalidobject(client)) {
			
			//SetEntityFlags(client, GetEntityFlags(client) & FL_ONTRAIN);
			
			
			if (buttons & IN_SPEED) {
				
				//	grabangle[client][0] = 0.0;
				//	grabangle[client][1] = 0.0;
				//		grabangle[client][2] = 0.0;
				
			} else {
				
				
				decl Float:nowangle[3];
				GetClientEyeAngles(client, nowangle);
				
				
				playeranglerotate[client][0] = playeranglerotate[client][0] + (preeyangle[client][0] - nowangle[0]);
				playeranglerotate[client][1] = playeranglerotate[client][1] + (preeyangle[client][1] - nowangle[1]);
				playeranglerotate[client][2] = playeranglerotate[client][2] + (preeyangle[client][2] - nowangle[2]);
				
				TeleportEntity(client, NULL_VECTOR, preeyangle[client], NULL_VECTOR);
				
			}
			
		}
		else {
			GetClientEyeAngles(client, preeyangle[client]);
		}
		
		if (grabbedentref[client] == INVALID_ENT_REFERENCE)
		{
			if ((buttons & IN_ATTACK) && !(keybuffer[client] & IN_ATTACK))
			{
				//trying to grab something
				if (teamcanusegravitygun(clientteam) && g_bIsWeaponGrabber[client]) {
					
					grab(client);
					
				}
			}
			
			
		}
		else if (EntRefToEntIndex(grabbedentref[client]) == -1 || !Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client])))
		{
			//held object has gone
			grabbedentref[client] = INVALID_ENT_REFERENCE;
			//lets make some release sound of gravity gun.
			stopentitysound(client, SOUND_GRAVITYGUN_HOLD);
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_DROP);
		}
		else
		{
			//we are currently holding something now		
			if (((buttons & IN_ATTACK) && !(keybuffer[client] & IN_ATTACK)) && teamcanusegravitygun(clientteam) && g_bIsWeaponGrabber[client])
			{
				hold(client);
			}
			else
			{
				release(client);
			}
		}
		
		if (!(buttons & IN_ATTACK))
		{
			keybuffer[client] = keybuffer[client] & ~IN_ATTACK;
			
		}
		if (!(buttons & IN_ATTACK2))
		{
			keybuffer[client] = keybuffer[client] & ~IN_ATTACK2;
			
		}
		
	} // if holding player is connected to the server
	else
	{
		release(client);
		
	}
	
}

grab(client) {
	
	new targetentity, Float:distancetoentity, Float:resultpos[3];
	
	targetentity = GetClientAimEntity3(client, distancetoentity, resultpos);
	
	if (targetentity != -1) {
		
		new PropTypeCheck:entityType = entityTypeCheck(targetentity);
		
		if (entityType && !isClientConnectedIngameAlive(GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity"))) {
			
			
			/*	//should we allow grab?
				if(GetForwardFunctionCount(forwardOnClientGrabEntity) > 0){
				
					new Action:result;
			   
					Call_StartForward(forwardOnClientGrabEntity);
					Call_PushCell(client);
					Call_PushCell(targetentity);
					Call_Finish(result);
					
					if(result !=  Plugin_Continue){
					
						return;
					
					}
					
				}
				*/
			if (!clientcangrab(client))
				
			
			return;
			
			
			
			
			if (entityType == PROP_TF2OBJ && GetEntPropEnt(targetentity, Prop_Send, "m_hBuilder") != client)
				return;
			
			grabentitytype[client] = entityType;
			
			if (entityType == PROP_RIGID) {
				
				//SetEntProp(targetentity, Prop_Data, "m_bFirstCollisionAfterLaunch", false);
				
			}
			
			
			new lastowner = GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity");
			
			if (lastowner != INVALID_ENT_REFERENCE) {
				
				entityownersave[client] = EntIndexToEntRef(lastowner);
				
			} else {
				
				entityownersave[client] = INVALID_ENT_REFERENCE;
				
			}
			
			SetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity", client);
			grabbedentref[client] = EntIndexToEntRef(targetentity);
			
			//SetEntPropEnt(targetentity, Prop_Data, "m_hParent", client);
			
			//SetEntProp(targetentity, Prop_Data, "m_iEFlags", GetEntProp(targetentity, Prop_Data, "m_iEFlags") | EFL_NO_PHYSCANNON_INTERACTION);
			
			entitygravitysave[client] = Phys_IsGravityEnabled(targetentity);
			
			Phys_EnableGravity(targetentity, false);
			
			decl Float:clienteyeangle[3], Float:entityangle[3]; //, Float:entityposition[3];
			GetEntPropVector(grabbedentref[client], Prop_Send, "m_angRotation", entityangle);
			GetClientEyeAngles(client, clienteyeangle);
			
			playeranglerotate[client][0] = entityangle[0];
			playeranglerotate[client][1] = entityangle[1];
			playeranglerotate[client][2] = entityangle[2];
			
			
			grabdistance[client] = GetEntitiesDistance(client, targetentity);
			/* GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
				grabpos[client][0] = entityposition[0] - resultpos[0];
				grabpos[client][1] = entityposition[1] - resultpos[1];
				grabpos[client][2] = entityposition[2] - resultpos[2]; */
			
			new matrix[matrix3x4_t];
			
			matrix3x4FromAnglesNoOrigin(clienteyeangle, matrix);
			
			decl Float:temp[3];
			
			MatrixAngles(matrix, temp);
			
			//				TransformAnglesToLocalSpace(entityangle, grabangle[client], matrix);
			
			keybuffer[client] = keybuffer[client] | IN_ATTACK2;
			
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PICKUP);
			playentitysoundfromclient(client, SOUND_GRAVITYGUN_HOLD);
			
			grabangle[client][0] = entityangle[0];
			grabangle[client][1] = entityangle[1];
			grabangle[client][2] = entityangle[2];
		}
		
	}
}


emptyshoot(client) {
	
	if (!clientcanpull(client)) {
		
		return;
		
	}
	
	new targetentity, Float:distancetoentity;
	
	targetentity = GetClientAimEntity(client, distancetoentity);
	if (targetentity != -1) {
		
		new PropTypeCheck:entityType = entityTypeCheck(targetentity);
		
		if (entityType && (distancetoentity <= GetConVarFloat(cvar_maxpulldistance)) && !isClientConnectedIngameAlive(GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity"))) {
			
			if (GetForwardFunctionCount(forwardOnClientEmptyShootEntity) > 0) {
				
				new Action:result;
				
				Call_StartForward(forwardOnClientEmptyShootEntity);
				Call_PushCell(client);
				Call_PushCell(targetentity);
				Call_Finish(result);
				
				if (result != Plugin_Continue) {
					
					return;
					
				}
				
			}
			
			decl Float:clienteyeangle[3], Float:anglevector[3];
			GetClientEyeAngles(client, clienteyeangle);
			GetAngleVectors(clienteyeangle, anglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(anglevector, anglevector);
			ScaleVector(anglevector, GetConVarFloat(cvar_pullforce));
			
			decl Float:ZeroSpeed[3];
			ZeroVector(ZeroSpeed);
			//TeleportEntity(targetentity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
			Phys_AddVelocity(targetentity, anglevector, ZeroSpeed);
			
			if (entityType == PROP_RIGID || entityType == PROP_PHYSBOX || entityType == PROP_RAGDOLL) {
				
				SetEntPropEnt(targetentity, Prop_Data, "m_hPhysicsAttacker", client);
				SetEntPropFloat(targetentity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
				
			}
			if (entityType == PROP_RIGID) {
				
				//SetEntProp(targetentity, Prop_Data, "m_bThrownByPlayer", true);
				
				
			}
			
			if (entityType != PROP_TF2OBJ)playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PUNT);
			
		}
		
	}
	
}

release(client) {
	
	if (EntRefToEntIndex(grabbedentref[client]) != -1) {
		
		Phys_EnableGravity(EntRefToEntIndex(grabbedentref[client]), entitygravitysave[client]);
		SetEntPropEnt(grabbedentref[client], Prop_Send, "m_hOwnerEntity", EntRefToEntIndex(entityownersave[client]));
		if (isClientConnectedIngame(client)) {
			
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_DROP);
			
		}
		firstGrab[client] = false;
		
	}
	grabbedentref[client] = INVALID_ENT_REFERENCE;
	keybuffer[client] = keybuffer[client] | IN_ATTACK2;
	
	stopentitysound(client, SOUND_GRAVITYGUN_HOLD);
}

hold(client) {
	
	decl Float:resultpos[3], Float:resultvecnormal[3];
	getClientAimPosition(client, grabdistance[client], resultpos, resultvecnormal, tracerayfilterrocket, client);
	
	decl Float:entityposition[3], Float:clientposition[3], Float:vector[3];
	GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
	GetClientEyePosition(client, clientposition);
	decl Float:clienteyeangle[3];
	GetClientEyeAngles(client, clienteyeangle);
	
	decl Float:clienteyeangleafterchange[3];
	
	new Float:fAngles[3];
	new Float:fOrigin[3];
	new Float:fEOrigin[3];
	// bomba
	new g_iWhite[4] =  { 255, 255, 255, 200 };
	GetClientAbsOrigin(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_vecOrigin", fEOrigin);
	
	TE_SetupBeamPoints(fOrigin, fEOrigin, g_iPhys, g_iHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, g_iWhite, 10);
	TE_SendToAll();
	
	clienteyeangleafterchange[0] = clienteyeangle[0] + playeranglerotate[client][0];
	clienteyeangleafterchange[1] = clienteyeangle[1] + playeranglerotate[client][1];
	clienteyeangleafterchange[2] = clienteyeangle[2] + playeranglerotate[client][2];
	
	decl playerlocalspace[matrix3x4_t], playerlocalspaceafterchange[matrix3x4_t];
	
	matrix3x4FromAnglesNoOrigin(clienteyeangle, playerlocalspace);
	matrix3x4FromAnglesNoOrigin(clienteyeangleafterchange, playerlocalspaceafterchange);
	
	
	//TransformAnglesToWorldSpace(grabangle[client], resultangle, playerlocalspaceafterchange);
	//TransformAnglesToLocalSpace(resultangle, grabangle[client], playerlocalspace);
	
	//ZeroVector(playeranglerotate[client]);
	
	MakeVectorFromPoints(entityposition, resultpos, vector);
	ScaleVector(vector, GetConVarFloat(cvar_grabforcemultiply));
	
	decl Float:entityangle[3], Float:resultangle2[3];
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_angRotation", entityangle);
	
	resultangle[client][0] = grabangle[client][0];
	resultangle[client][1] = grabangle[client][1];
	resultangle[client][2] = grabangle[client][2];
	//PrintToChatAll("%f :: %f :: %f", entityangle[0], entityangle[1], entityangle[2] );
	resultangle2[0] = resultangle[client][0] + playeranglerotate[client][0];
	resultangle2[1] = resultangle[client][1] + playeranglerotate[client][1];
	resultangle2[2] = resultangle[client][2] + playeranglerotate[client][2];
	
	
	new PlayerSpawnCheck;
	
	
	while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
	{
		if (Entity_InRange(grabbedentref[client], PlayerSpawnCheck, 400.0))
		{
			if (grabentitytype[client] != PROP_PLAYER)
			{
				Build_PrintToChat(client, "You're too near the spawn!");
				Build_SetLimit(client, -1);
				AcceptEntityInput(grabbedentref[client], "kill");
				//Build_RegisterEntityOwner(grabbedentref[client], -1);
			}
		}
	}
	
	if (grabentitytype[client] != PROP_RAGDOLL)
	{
		TeleportEntity(grabbedentref[client], NULL_VECTOR, playeranglerotate[client], NULL_VECTOR);
	}
	
	
	Phys_SetVelocity(EntRefToEntIndex(grabbedentref[client]), vector, ZERO_VECTOR, true);
	
	if (grabentitytype[client] == PROP_PHYSBOX || grabentitytype[client] == PROP_RAGDOLL) {
		
		SetEntPropEnt(grabbedentref[client], Prop_Data, "m_hPhysicsAttacker", client);
		SetEntPropFloat(grabbedentref[client], Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
		
	}
	if (grabentitytype[client] == PROP_RIGID || grabentitytype[client] == PROP_PLAYER) {
		
		decl Float:eyeposfornow[3];
		GetClientEyePosition(client, eyeposfornow);
		
		decl Float:eyeanglefornow[3];
		GetClientEyeAngles(client, eyeanglefornow);
		//SetEntProp(grabbedentref[client], Prop_Data, "m_bThrownByPlayer", true);
		TeleportEntity(grabbedentref[client], resultpos, playeranglerotate[client], NULL_VECTOR);
		
	}
	
}

PropTypeCheck:entityTypeCheck(entity) {
	
	new String:classname[64];
	GetEdictClassname(entity, classname, 64);
	
	if (StrContains(classname, "prop_dynamic", false) != -1 || StrContains(classname, "prop_physics", false) != -1 || StrContains(classname, "tf_dropped_weapon", false) != -1 || StrContains(classname, "prop_door_", false) != -1 || StrContains(classname, "tf_ammo_pack", false) != -1 || StrContains(classname, "prop_physics_multiplayer", false) != -1) {
		
		return PROP_RIGID;
	}
	else if (StrContains(classname, "func_physbox", false) != -1) {
		
		return PROP_PHYSBOX;
		
	} else if (StrContains(classname, "prop_ragdoll", false) != -1) {
		
		return PROP_RAGDOLL;
		
	} else if (StrContains(classname, "weapon_", false) != -1) {
		
		return PROP_WEAPON;
		
	} else if (StrContains(classname, "tf_projectile", false) != -1) {
		
		return PROP_TF2PROJ;
		
	} else if (StrEqual(classname, "obj_sentrygun", false) || StrEqual(classname, "obj_dispenser", false)
		 || StrEqual(classname, "obj_teleporter", false)) {
		
		return PROP_RIGID;
		
		
		
		
		
		
	}
	else if (StrContains(classname, "player", false) != -1)
	{
		return PROP_PLAYER;
	}
	else {
		
		return PROP_NONE;
		
	}
	
}

bool:clientcanpull(client) {
	
	new Float:now = GetGameTime();
	
	if (nextactivetime[client] <= now) {
		
		nextactivetime[client] = now + GetConVarFloat(cvar_pull_delay);
		
		return true;
		
	}
	
	return false;
	
}

bool:clientcangrab(client) {
	
	new Float:now = GetGameTime();
	
	if (nextactivetime[client] <= now) {
		
		nextactivetime[client] = now + GetConVarFloat(cvar_grab_delay);
		
		//return true;
		
	}
	
	g_iGrabTarget[client] = Build_ClientAimEntity(client, true, true);
	
	
	
	if (Build_IsEntityOwner(client, g_iGrabTarget[client])) {
		if (g_iGrabTarget[client] == -1) {
			if (Build_IsAdmin(client)) {
				GetForwardFunctionCount(forwardOnClientGrabEntity) == 1;
				return true;
			}
			else
			{
				GetForwardFunctionCount(forwardOnClientGrabEntity) == 0;
				return false;
			}
		}
		if (g_iGrabTarget[client] != -1) {
			
			GetForwardFunctionCount(forwardOnClientGrabEntity) == 1;
			return true;
		}
		
		
	}
	
}

bool:clientisgrabbingvalidobject(client) {
	
	if (EntRefToEntIndex(grabbedentref[client]) != -1 && Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))) {
		
		return true;
		
	} else {
		
		return false;
		
	}
	
}

public Native_GetCurrntHeldEntity(Handle:plugin, args) {
	
	new client = GetNativeCell(1);
	
	if (isClientConnectedIngameAlive(client)) {
		
		return EntRefToEntIndex(grabbedentref[client]);
		
	} else {
		
		return -1;
		
	}
	
}

public Native_ForceDropHeldEntity(Handle:plugin, args) {
	
	new client = GetNativeCell(1);
	
	if (isClientConnectedIngameAlive(client)) {
		
		release(client);
		return true;
	}
	
	return false;
	
}

public Native_ForceGrabEntity(Handle:plugin, args) {
	
	new client = GetNativeCell(1);
	new entity = GetNativeCell(2);
	
	if (isClientConnectedIngameAlive(client)) {
		
		if (IsValidEdict(entity)) {
			
			new PropTypeCheck:entityType = entityTypeCheck(entity);
			
			if (entityType && !isClientConnectedIngameAlive(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))) {
				
				//지목한 엔티티는 들 수 있는것이다.
				//이미 들고있는 엔티티가 있다면, 내려놓는다
				release(client);
				
				grabentitytype[client] = entityType;
				grabbedentref[client] = EntIndexToEntRef(entity);
				
				//소리를 낸다
				playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PICKUP);
				playentitysoundfromclient(client, SOUND_GRAVITYGUN_HOLD);
				
				return true;
				
			}
			
		}
		
	}
	
	return false;
	
}


public Action:ClientRemoveAll(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_fda <#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:arg[65], String:cmd[192];
	GetCmdArg(1, arg, sizeof(arg));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
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
	
	for (new i = 0; i < target_count; i++)
	{
		FakeClientCommand(target_list[i], "sm_delall");
	}
	
	return Plugin_Handled;
}

public Action:Event_player_builtobject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new building = GetEventInt(event, "index");
	if (Build_RegisterEntityOwner(building, client)) {
		Build_SetLimit(client, -1);
		decl String:classname[48];
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
