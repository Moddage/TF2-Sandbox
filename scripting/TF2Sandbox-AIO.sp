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
#include <entity_prop_stocks>
#include <tf2items>
//#include <stocklib>
#include <matrixmath>
#include "GravityGun/GravityGunsound.inc"
#include "GravityGun/GravityGuncvars.inc"

#define MDL_TOOLGUN			"models/weapons/v_357.mdl"
#define SND_TOOLGUN_SHOOT	"weapons/airboat/airboat_gun_lastshot1.wav"
#define SND_TOOLGUN_SHOOT2	"weapons/airboat/airboat_gun_lastshot2.wav"
#define SND_TOOLGUN_SELECT	"buttons/button15.wav"

// Toolgun
#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)

/* RIP new syntax PropTypeCheck change to int
enum PropTypeCheck
{
	PROP_NONE = 0, 
	PROP_RIGID = 1, 
	PROP_PHYSBOX = 2, 
	PROP_WEAPON = 3, 
	PROP_TF2OBJ = 4,  //tf2 buildings
	PROP_RAGDOLL = 5, 
	PROP_TF2PROJ = 6,  //tf2 projectiles
	PROP_PLAYER = 7
};
*/

#pragma newdecls required

Handle g_hSdkEquipWearable;
int g_CollisionOffset;

int g_hWearableOwner[2049];
int g_iTiedEntity[2049];
bool g_bIsToolgun[2049];
char g_sCurrentColor[MAXPLAYERS + 1][32];
RenderFx g_fxEffectTool[MAXPLAYERS + 1];
int g_iCurrentColor[MAXPLAYERS + 1][3];
int LastUsed[MAXPLAYERS + 1];

int g_iTool[MAXPLAYERS + 1];
int g_iColorTool[MAXPLAYERS + 1];
int g_iEffectTool[MAXPLAYERS + 1];
bool g_bPlayerPressedReload[MAXPLAYERS + 1];
bool g_bAttackWasMouse2[MAXPLAYERS + 1];
bool g_bAttackWasMouse3[MAXPLAYERS + 1];

//Duplicator ToolGun
char modelnamedupe[MAXPLAYERS + 1][256];
float propeyeangle[MAXPLAYERS + 1][3];

bool g_bClientLang[MAXPLAYERS];
Handle g_hCookieClientLang;

MoveType g_mtGrabMoveType[MAXPLAYERS];
int g_iGrabTarget[MAXPLAYERS];
float g_vGrabPlayerOrigin[MAXPLAYERS][3];
bool g_bGrabIsRunning[MAXPLAYERS];
bool g_bGrabFreeze[MAXPLAYERS];

Handle g_hMenuCredits;
Handle g_hMenuCredits2;


Handle g_hCookieSDoorTarget;
Handle g_hCookieSDoorModel;

Handle g_hPropNameArray;
Handle g_hPropModelPathArray;
Handle g_hPropTypeArray;
Handle g_hPropStringArray;
char g_szFile[128];

char g_szConnectedClient[32][MAXPLAYERS];
//char g_szDisconnectClient[32][MAXPLAYERS];
int g_iTempOwner[MAX_HOOK_ENTITIES] =  { -1, ... };

float g_fDelRangePoint1[MAXPLAYERS][3];
float g_fDelRangePoint2[MAXPLAYERS][3];
float g_fDelRangePoint3[MAXPLAYERS][3];
char g_szDelRangeStatus[MAXPLAYERS][8];
bool g_szDelRangeCancel[MAXPLAYERS] =  { false, ... };

int g_RememberGodmode[MAXPLAYERS];

int ColorBlue[4] =  {
	50, 
	50, 
	255, 
	255 };
int ColorWhite[4] =  {
	255, 
	255, 
	255, 
	255 };
int ColorRed[4] =  {
	255, 
	50, 
	50, 
	255 };
int ColorGreen[4] =  {
	50, 
	255, 
	50, 
	255 };

#define EFL_NO_PHYSCANNON_INTERACTION (1<<30)

int g_Halo;
int g_PBeam;

bool g_bBuffer[MAXPLAYERS + 1];

int g_iCopyTarget[MAXPLAYERS];
float g_fCopyPlayerOrigin[MAXPLAYERS][3];
bool g_bCopyIsRunning[MAXPLAYERS] = false;

int g_Beam;

Handle g_hMainMenu = INVALID_HANDLE;
Handle g_hPropMenu = INVALID_HANDLE;
Handle g_hEquipMenu = INVALID_HANDLE;
Handle g_hPoseMenu = INVALID_HANDLE;
Handle g_hPlayerStuff = INVALID_HANDLE;
Handle g_hCondMenu = INVALID_HANDLE;
Handle g_hRemoveMenu = INVALID_HANDLE;
Handle g_hBuildHelperMenu = INVALID_HANDLE;
Handle g_hPropMenuComic = INVALID_HANDLE;
Handle g_hPropMenuConstructions = INVALID_HANDLE;
Handle g_hPropMenuWeapons = INVALID_HANDLE;
Handle g_hPropMenuPickup = INVALID_HANDLE;
Handle g_hPropMenuHL2 = INVALID_HANDLE;

/*char g_szFile[128];
Handle g_hPropNameArray;
Handle g_hPropModelPathArray;
Handle g_hPropTypeArray;
Handle g_hPropStringArray;*/

char CopyableProps[][] =  {
	"prop_dynamic", 
	"prop_dynamic_override", 
	"prop_physics", 
	"prop_physics_multiplayer", 
	"prop_physics_override", 
	"prop_physics_respawnable", 
	"5", 
	"func_physbox", 
	"player"
};

char EntityType[][] =  {
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
	"5", 
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

//are they using grabber?
//bool grabenabled[MAXPLAYERS + 1];

bool g_bIsWeaponGrabber[MAXPLAYERS + 1];

//which entity is grabbed?(and are we currently grabbing anything?) this is entref, not ent index
int grabbedentref[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

int keybuffer[MAXPLAYERS + 1];

float grabangle[MAXPLAYERS + 1][3];
bool firstGrab[MAXPLAYERS + 1];
float grabdistance[MAXPLAYERS + 1];
float resultangle[MAXPLAYERS + 1][3];

float preeyangle[MAXPLAYERS + 1][3];
float playeranglerotate[MAXPLAYERS + 1][3];

float nextactivetime[MAXPLAYERS + 1];

bool entitygravitysave[MAXPLAYERS + 1];
int entityownersave[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

int grabentitytype[MAXPLAYERS + 1]; //PropTypeCheck 

float grabpos[MAXPLAYERS + 1][3];

Handle forwardOnClientGrabEntity = INVALID_HANDLE;
Handle forwardOnClientDragEntity = INVALID_HANDLE;
Handle forwardOnClientEmptyShootEntity = INVALID_HANDLE;
Handle forwardOnClientShootEntity = INVALID_HANDLE;
int g_PhysGunModel;
//int g_iBeam;
int g_iHalo;
//int g_iLaser;
int g_iPhys;

public Plugin myinfo = 
{
	name = "TF2 Sandbox All In One Module", 
	author = "Danct12, DaRkWoRlD, FlaminSarge, javalia, greenteaf0718, hjkwe654, BattlefieldDuck", 
	description = "Everything in one module, isn't that cool? Yes", 
	version = BUILDMOD_VER, 
	url = "http://dtf2server.ddns.net"
};

public void OnPluginStart()
{
	// client Language Base
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB client Language.", CookieAccess_Private);
	
	RegAdminCmd("sm_bl", Command_AddBL, ADMFLAG_CONVARS, "Add clients to TF2SB Blacklist");
	RegAdminCmd("sm_unbl", Command_RemoveBL, ADMFLAG_CONVARS, "Remove clients from TF2SB Blacklist");
	
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
	RegAdminCmd("sm_ld", Command_LightDynamic, 0, "Dynamic Light.");
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
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB client Language.", CookieAccess_Private);
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
	
	g_CollisionOffset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	RegAdminCmd("sm_toolgun", Command_ToolGun, 0);
	
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
	RegAdminCmd("sm_g2", Command_PhysGun, 0);
	RegAdminCmd("sm_g", Command_PhysGunNew, 0);
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
	
	AddMenuItem(g_hEquipMenu, "physgun", "Physics Gun V1");
	AddMenuItem(g_hEquipMenu, "physgunv2", "Physics Gun V2");
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
	SetMenuTitle(g_hPropMenuWeapons, "TF2SB - Weapon Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuWeapons, true);
	AddMenuItem(g_hPropMenuWeapons, "removeprops", "|Remove");
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
	
	// Prop Menu Comics Prop
	g_hPropMenuComic = CreateMenu(PropMenuComics);
	SetMenuTitle(g_hPropMenuComic, "TF2SB - Comic Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuComic, true);
	AddMenuItem(g_hPropMenuComic, "removeprops", "|Remove");
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
	SetMenuTitle(g_hPropMenuConstructions, "TF2SB - Construction Props\nSay /g in chat to move Entities!");
	SetMenuExitBackButton(g_hPropMenuConstructions, true);
	AddMenuItem(g_hPropMenuConstructions, "removeprops", "|Remove");
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
	
	
	/*	g_hPropNameArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 2048);	// Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 2048);
	
	ReadProps();
	
	char szPropName[32], char szPropFrozen[32], char szPropString[256], char szModelPath[128];
	
	int PropName = FindStringInArray(g_hPropNameArray, szPropName);
	int PropString = FindStringInArray(g_hPropNameArray, szPropString);*/
	
	creategravityguncvar();
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bIsWeaponGrabber[i] = false;
		
		grabbedentref[i] = INVALID_ENT_REFERENCE;
		if (IsValidClient(i) && IsClientInGame(i))
		{
			SDKHook(i, SDKHook_PreThink, PreThinkHook);
			SDKHook(i, SDKHook_WeaponSwitch, WeaponSwitchHook);
		}
	}
	
	RegAdminCmd("sm_fda", ClientRemoveAll, ADMFLAG_SLAY);
	
	char buffer[512];
	
	g_hMenuCredits = CreateMenu(TF2SBCred1);
	
	Format(buffer, sizeof(buffer), "Credits\n \n");
	StrCat(buffer, sizeof(buffer), "Coders: Danct12 and DaRkWoRlD\n");
	StrCat(buffer, sizeof(buffer), "\n");
	StrCat(buffer, sizeof(buffer), "greenteaf0718 and hjkwe654 for the original BuildMod\n");
	StrCat(buffer, sizeof(buffer), "FlaminSarge and javalia for the GravityGun Mod (which creates the PhysGun v1)\n");
	StrCat(buffer, sizeof(buffer), "Pelipoika for the ToolGun Source Code\n");
	StrCat(buffer, sizeof(buffer), "TESTBOT#7 for making official group profile\n");
	StrCat(buffer, sizeof(buffer), "BattlefieldDuck for tweaking and making addons for TF2SB, also the creator of PhysGun v2\n");
	StrCat(buffer, sizeof(buffer), "Garry Newman for creating Garry's Mod, without him, this wouldn't exist\n");
	StrCat(buffer, sizeof(buffer), "AlliedModders because without this, SourceMod wouldn't exist and this also wouldn't\n \n");
	
	SetMenuTitle(g_hMenuCredits, buffer);
	AddMenuItem(g_hMenuCredits, "0", "Next");
	
	g_hMenuCredits2 = CreateMenu(TF2SBCred2);
	
	Format(buffer, sizeof(buffer), "Credits\n \n");
	StrCat(buffer, sizeof(buffer), "Thanks to these people for tested this mod at the beginning:\n");
	StrCat(buffer, sizeof(buffer), "periodicJudgement\n");
	StrCat(buffer, sizeof(buffer), "Lecubon\n");
	StrCat(buffer, sizeof(buffer), "iKiroZz\n");
	StrCat(buffer, sizeof(buffer), "Lazyneer\n");
	StrCat(buffer, sizeof(buffer), "Cecil\n");
	StrCat(buffer, sizeof(buffer), "TESTBOT#7\n");
	StrCat(buffer, sizeof(buffer), "The Moddage community for hosting the server\n");
	StrCat(buffer, sizeof(buffer), "And every players who have joined to test it out!\n \n");
	StrCat(buffer, sizeof(buffer), "THANKS FOR PLAYING!\n");
	
	SetMenuTitle(g_hMenuCredits2, buffer);
	AddMenuItem(g_hMenuCredits2, "0", "Back");
	RegAdminCmd("sm_tf2sb", Command_TF2SBCred, 0);
	RegAdminCmd("hidehudtf2sb", Command_TF2SBHideHud, 0);
	
}

public Action Command_TF2SBCred(int client, int args)
{
	DisplayMenu(g_hMenuCredits, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int TF2SBCred1(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:DisplayMenu(g_hMenuCredits2, param1, MENU_TIME_FOREVER);
		}
	}
}

public int TF2SBCred2(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:DisplayMenu(g_hMenuCredits, param1, MENU_TIME_FOREVER);
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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
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

public void OnMapStart()
{
	g_Halo = PrecacheModel("materials/sprites/halo01.vmt");
	g_Beam = PrecacheModel("materials/sprites/laser.vmt");
	g_PBeam = PrecacheModel("materials/sprites/physbeam.vmt");
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("buttons/button3.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
	PrecacheSound("npc/strider/charging.wav", true);
	PrecacheSound("npc/strider/fire.wav", true);
	for (int i = 1; i < MaxClients; i++)
	{
		g_szConnectedClient[i] = "";
		if (Build_IsClientValid(i, i))
			GetClientAuthId(i, AuthId_Steam2, g_szConnectedClient[i], sizeof(g_szConnectedClient));
	}
	
	prepatchsounds();
	
	PrecacheModel(MDL_TOOLGUN);
	PrecacheSound(SND_TOOLGUN_SHOOT);
	PrecacheSound(SND_TOOLGUN_SHOOT2);
	PrecacheSound(SND_TOOLGUN_SELECT);
	
	g_iHalo = PrecacheModel("materials/sprites/halo01.vmt");
	//g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt");
	//	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	
	g_PhysGunModel = PrecacheModel("models/weapons/v_superphyscannon.mdl");
	
	AutoExecConfig();
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, g_szConnectedClient[client], sizeof(g_szConnectedClient));
	
	g_bIsWeaponGrabber[client] = false;
	
	grabbedentref[client] = INVALID_ENT_REFERENCE;
	
	SDKHook(client, SDKHook_PreThink, PreThinkHook);
	SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitchHook);
}

public void OnClientDisconnect(int client)
{
	FakeClientCommand(client, "sm_delall");
	/*g_szConnectedClient[client] = "";
	GetClientAuthId(client, AuthId_Steam2, g_szDisconnectClient[client], sizeof(g_szDisconnectClient));
	int iCount;
	for (int iCheck = 0; iCheck < MAX_HOOK_ENTITIES; iCheck++) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == client) {
				g_iTempOwner[iCheck] = client;
				Build_RegisterEntityOwner(iCheck, -1);
				iCount++;
			}
		}
	}
	Build_SetLimit(client, 0);
	Build_SetLimit(client, 0, true);
	if (iCount > 0) {
		Handle hPack;
		CreateDataTimer(0.001, Timer_Disconnect, hPack);
		WritePackCell(hPack, client);
		WritePackCell(hPack, 0);
	}*/
	
	//we must release any thing if it is on spectator`s hand
	release(client);
}

public void OnClientConnected(int client)
{
	g_RememberGodmode[client] = 1;
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

public Action OnClientCommand(int client, int args)
{
	if (Build_IsClientValid(client, client) && client > 0)
	{
		char Lang[8];
		GetClientCookie(client, g_hCookieClientLang, Lang, sizeof(Lang));
		if (StrEqual(Lang, "1"))
			g_bClientLang[client] = true;
		else
			g_bClientLang[client] = false;
	}
}

public Action Command_Copy(int client, int args)
{
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it so fast! Slow it down!");
		
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
		Build_PrintToChat(client, "You are already copying something!");
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
			Build_PrintToChat(client, "You need \x04L2 Build Access\x01 to copy this prop!");
			return Plugin_Handled;
		}
	} else {
		if (StrEqual(szClass, "func_physbox") && !Build_IsAdmin(client, true)) {
			
			Build_PrintToChat(client, "You can't copy this prop!");
			return Plugin_Handled;
		}
		
		if (StrEqual(szClass, "prop_dynamic")) {
			szClass = "prop_dynamic_override";
		}
		
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
			if (StrEqual(szModelName, "models/props_c17/oildrum001_explosive.mdl") && !Build_IsAdmin(client, true)) {
				Build_PrintToChat(client, "You need \x04L2 Build Access\x01 to copy this prop!");
				RemoveEdict(g_iCopyTarget[client]);
				return Plugin_Handled;
			}
			DispatchKeyValue(g_iCopyTarget[client], "model", szModelName);
			SetEntPropString(g_iCopyTarget[client], Prop_Data, "m_iName", szPropName);
			
			
			GetEdictClassname(g_iCopyTarget[client], szClass, sizeof(szClass));
			if (StrEqual(szClass, "prop_dynamic_override")) {
				SetEntProp(g_iCopyTarget[client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[client], Prop_Data, "m_nSolidType", 6);
			}
			
			/*if (StrEqual(szClass, "prop_dynamic_override")) {
				SetEntProp(g_iCopyTarget[client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[client], Prop_Data, "m_nSolidType", 6);
			}*/
			
			DispatchSpawn(g_iCopyTarget[client]);
			TeleportEntity(g_iCopyTarget[client], fEntityOrigin, fEntityAngle, NULL_VECTOR);
			
			if (Phys_IsPhysicsObject(g_iCopyTarget[client]))
				Phys_EnableMotion(g_iCopyTarget[client], false);
			
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
			Build_PrintToChat(client, "This prop was not copy able.");
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
		
		TE_SetupBeamPoints(fOriginEntity, fOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
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
		
		TE_SetupBeamRingPoint(fOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(fOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
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
		
		if (Phys_IsPhysicsObject(g_iCopyTarget[client])) {
			Phys_EnableMotion(g_iCopyTarget[client], false);
			Phys_Sleep(g_iCopyTarget[client]);
		}
		SetEntityMoveType(g_iCopyTarget[client], MOVETYPE_NONE);
		TeleportEntity(g_iCopyTarget[client], fOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bCopyIsRunning[client])
			CreateTimer(0.001, Timer_CopyMain, client);
		else {
			if (Phys_IsPhysicsObject(g_iCopyTarget[client])) {
				Phys_EnableMotion(g_iCopyTarget[client], false);
				Phys_Sleep(g_iCopyTarget[client]);
			}
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it too fast! Slow it down!");
		
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
		
		int PlayerSpawnCheck;
		
		while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
		{
			if (Entity_InRange(iDoor, PlayerSpawnCheck, 400.0))
			{
				
				
			}
		}
		
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

public Action Command_ReloadAIOPlugin(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	ReadProps();
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 5) {
		
		Build_PrintToChat(client, "Usage: !render <fx amount> <fx> <R> <G> <B>");
		Build_PrintToChat(client, "Ex. Flashing Green: !render 150 4 15 255 0");
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
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 3) {
		Build_PrintToChat(client, "Usage: !color <R> <G> <B>");
		Build_PrintToChat(client, "Ex: Green: !color 0 255 0");
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
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "Usage: !propscale <number>");
		Build_PrintToChat(client, "Notice: Physics are non-scaled.");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		
		//float Scale2  = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
		char szPropScale[33];
		GetCmdArg(1, szPropScale, sizeof(szPropScale));
		
		float Scale = StringToFloat(szPropScale);
		
		SetVariantString(szPropScale);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", Scale);
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "Usage: !skin <number>");
		Build_PrintToChat(client, "Notice: Not every model have multiple skins.");
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
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "Usage: !rotate/!r <x> <y> <z>");
		Build_PrintToChat(client, "Ex: !rotate 0 90 0");
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
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "Noclip ON");
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	else
	{
		Build_PrintToChat(client, "Noclip OFF");
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	/*if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it too fast! Slow it down!");
		
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "Usage: !ar <x> <y> <z>");
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
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "Usage: !ld <brightness> <R> <G> <B>");
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	int Obj_LightDMelon = CreateEntityByName("prop_dynamic");
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
		
		int Obj_LightDynamic = CreateEntityByName("light_dynamic");
		
		if (StringToInt(szBrightness) > 7) {
			if (g_bClientLang[client])
				Build_PrintToChat(client, "亮度上限是 7!");
			else
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
		
		int PlayerSpawnCheck;
		
		while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
		{
			if (Entity_InRange(Obj_LightDMelon, PlayerSpawnCheck, 400.0))
			{
				
			}
		}
		
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
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it too fast! Slow it down!");
		
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
		int Obj_Door = CreateEntityByName("prop_dynamic_override");
		
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
			
			int PlayerSpawnCheck;
			
			while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
			{
				if (Entity_InRange(Obj_Door, PlayerSpawnCheck, 400.0))
				{
					
					
				}
			}
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
				
				GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				SetClientCookie(client, g_hCookieSDoorTarget, szFormatStr);
				SetClientCookie(client, g_hCookieSDoorModel, szModel);
			}
			case 'b': {
				GetClientCookie(client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				
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
		Build_PrintToChat(client, "Usage: !sdoor <choose>");
		Build_PrintToChat(client, "!sdoor 1~7 = Spawn door");
		Build_PrintToChat(client, "!sdoor a = Select door");
		Build_PrintToChat(client, "!sdoor b = Select button (Shoot to open)");
		Build_PrintToChat(client, "!sdoor c = Select button (Press to open)");
		Build_PrintToChat(client, "NOTE: Not all doors movable using PhysGun, use the !move command!");
	}
	return Plugin_Handled;
}

public Action Command_Move(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "Usage: !move <x> <y> <z>");
		Build_PrintToChat(client, "Ex, move up 50: !move 0 0 50");
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
		
		float vOriginPlayer[3], vOriginAim[3];
		
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
		}
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
		Build_PrintToChat(client, "Usage: !setname <name you want it to be>");
		Build_PrintToChat(client, "Ex: !setname \"A teddy bear\"");
		Build_PrintToChat(client, "Ex: !setname \"Gabe Newell\"");
		return Plugin_Handled;
	}
	
	int iEntity = Build_ClientAimEntity(client);
	if (iEntity == -1)
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(client, iEntity)) {
		char newpropname[256];
		GetCmdArg(args, newpropname, sizeof(newpropname));
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

public Action Command_SpawnProp(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		Build_PrintToChat(client, "You must be alive to use this command!");
		
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Build_PrintToChat(client, "Usage: !spawnprop/!s <Prop name>");
		Build_PrintToChat(client, "Ex: !spawnprop goldbar");
		Build_PrintToChat(client, "Ex: !spawnprop alyx");
		return Plugin_Handled;
	}
	
	char szPropName[32], szPropFrozen[32], szPropString[256], szModelPath[128];
	GetCmdArg(1, szPropName, sizeof(szPropName));
	GetCmdArg(2, szPropFrozen, sizeof(szPropFrozen));
	
	int IndexInArray = FindStringInArray(g_hPropNameArray, szPropName);
	
	if (StrEqual(szPropName, "explosivecan") && !Build_IsAdmin(client, true)) {
		Build_PrintToChat(client, "You need \x04L2 Build Access\x01 to spawn this prop!");
		return Plugin_Handled;
	}
	
	if (g_bBuffer[client])
	{
		Build_PrintToChat(client, "You're doing it too fast! Slow it down!");
		
		return Plugin_Handled;
	}
	
	g_bBuffer[client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(client));
	
	if (IndexInArray != -1) {
		bool bIsDoll = false;
		char szEntType[33];
		GetArrayString(g_hPropTypeArray, IndexInArray, szEntType, sizeof(szEntType));
		
		if (!Build_IsAdmin(client, true)) {
			if (StrEqual(szPropName, "explosivecan") || StrEqual(szEntType, "5")) {
				Build_PrintToChat(client, "You need \x04L2 Build Access\x01 to spawn this prop!");
				return Plugin_Handled;
			}
		}
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
			
			Build_ClientAimOrigin(client, iAim);
			iAim[2] = iAim[2] + 10;
			
			GetClientAbsOrigin(client, vOriginPlayer);
			vOriginPlayer[2] = vOriginPlayer[2] + 50;
			
			
			DispatchSpawn(iEntity);
			TeleportEntity(iEntity, iAim, NULL_VECTOR, NULL_VECTOR);
			
			
			
			TE_SetupBeamPoints(iAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
			TE_SendToAll();
			
			int random = GetRandomInt(0, 1);
			if (random == 1) {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			} else {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			}
			
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);
			
			// Debugging issues
			//PrintToChatAll(szPropString);
			
			int PlayerSpawnCheck;
			
			while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
			{
				if (Entity_InRange(iEntity, PlayerSpawnCheck, 400.0))
				{
					
					
				}
			}
			
			
			if (!StrEqual(szPropFrozen, "")) {
				if (Phys_IsPhysicsObject(iEntity))
					Phys_EnableMotion(iEntity, false);
			}
		} else
			RemoveEdict(iEntity);
	} else {
		Build_PrintToChat(client, "Prop not found: %s", szPropName);
	}
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_spawnprop", szArgs);
	return Plugin_Handled;
}

void ReadProps()
{
	BuildPath(Path_SM, g_szFile, sizeof(g_szFile), "configs/buildmod/props.ini");
	
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
		
		ReadPropsLine(szLine, iCountProps++);
	}
	CloseHandle(iFile);
}

void ReadPropsLine(const char[] szLine, int iCountProps)
{
	char szPropInfo[4][128];
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

public Action Event_Spawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	LastUsed[client] = 0;
	
	if (g_RememberGodmode[client] == 1.0)
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
	
	nextactivetime[client] = GetGameTime();
}

public Action Command_ChangeGodMode(int client, int args)
{
	if (!Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	if (GetEntProp(client, Prop_Data, "m_takedamage") == 0)
	{
		Build_PrintToChat(client, "God Mode OFF");
		g_RememberGodmode[client] = 0;
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	}
	else
	{
		Build_PrintToChat(client, "God Mode ON");
		g_RememberGodmode[client] = 1;
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
	
	return Plugin_Handled;
}

public Action Command_EnableGrab(int client, int args)
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client) || !Build_IsClientValid(client, client, true))
		return Plugin_Handled;
	
	g_iGrabTarget[client] = Build_ClientAimEntity(client, true, true);
	if (g_iGrabTarget[client] == -1)
		return Plugin_Handled;
	
	if (g_bGrabIsRunning[client]) {
		Build_PrintToChat(client, "You are already grabbing something!");
		return Plugin_Handled;
	}
	
	if (!Build_IsAdmin(client)) {
		if (GetEntityFlags(g_iGrabTarget[client]) == (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (Build_IsEntityOwner(client, g_iGrabTarget[client])) {
		char szFreeze[20], szColorR[20], szColorG[20], szColorB[20], szColor[128];
		GetCmdArg(1, szFreeze, sizeof(szFreeze));
		GetCmdArg(2, szColorR, sizeof(szColorR));
		GetCmdArg(3, szColorG, sizeof(szColorG));
		GetCmdArg(4, szColorB, sizeof(szColorB));
		
		g_bGrabFreeze[client] = true;
		if (StrEqual(szFreeze, "1"))
			g_bGrabFreeze[client] = true;
		
		DispatchKeyValue(g_iGrabTarget[client], "rendermode", "5");
		DispatchKeyValue(g_iGrabTarget[client], "renderamt", "150");
		DispatchKeyValue(g_iGrabTarget[client], "renderfx", "4");
		
		if (StrEqual(szColorR, ""))
			szColorR = "255";
		if (StrEqual(szColorG, ""))
			szColorG = "50";
		if (StrEqual(szColorB, ""))
			szColorB = "50";
		Format(szColor, sizeof(szColor), "%s %s %s", szColorR, szColorG, szColorB);
		DispatchKeyValue(g_iGrabTarget[client], "rendercolor", szColor);
		
		g_mtGrabMoveType[client] = GetEntityMoveType(g_iGrabTarget[client]);
		g_bGrabIsRunning[client] = true;
		
		CreateTimer(0.01, Timer_GrabBeam, client);
		CreateTimer(0.01, Timer_GrabRing, client);
		CreateTimer(0.05, Timer_GrabMain, client);
	}
	return Plugin_Handled;
}

public Action Command_DisableGrab(int client, int args)
{
	g_bGrabIsRunning[client] = false;
	return Plugin_Handled;
}

public Action Timer_GrabBeam(Handle timer, any client)
{
	if (IsValidEntity(g_iGrabTarget[client]) && Build_IsClientValid(client, client)) {
		float vOriginEntity[3], vOriginPlayer[3];
		
		GetClientAbsOrigin(client, g_vGrabPlayerOrigin[client]);
		GetClientAbsOrigin(client, vOriginPlayer);
		GetEntPropVector(g_iGrabTarget[client], Prop_Data, "m_vecOrigin", vOriginEntity);
		vOriginPlayer[2] += 50;
		
		int iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamPoints(vOriginEntity, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[client])
			CreateTimer(0.01, Timer_GrabBeam, client);
	}
}

public Action Timer_GrabRing(Handle timer, any client)
{
	if (IsValidEntity(g_iGrabTarget[client]) && Build_IsClientValid(client, client))
	{
		float vOriginEntity[3];
		GetEntPropVector(g_iGrabTarget[client], Prop_Data, "m_vecOrigin", vOriginEntity);
		
		int iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamRingPoint(vOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SetupBeamRingPoint(vOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[client])
			CreateTimer(0.3, Timer_GrabRing, client);
	}
}

public Action Timer_GrabMain(Handle timer, any client)
{
	if (IsValidEntity(g_iGrabTarget[client]) && Build_IsClientValid(client, client)) {
		if (!Build_IsAdmin(client)) {
			if (Build_ReturnEntityOwner(g_iGrabTarget[client]) != client) {
				g_bGrabIsRunning[client] = false;
				return;
			}
		}
		
		float vOriginEntity[3], vOriginPlayer[3];
		
		GetEntPropVector(g_iGrabTarget[client], Prop_Data, "m_vecOrigin", vOriginEntity);
		GetClientAbsOrigin(client, vOriginPlayer);
		
		vOriginEntity[0] += vOriginPlayer[0] - g_vGrabPlayerOrigin[client][0];
		vOriginEntity[1] += vOriginPlayer[1] - g_vGrabPlayerOrigin[client][1];
		vOriginEntity[2] += vOriginPlayer[2] - g_vGrabPlayerOrigin[client][2];
		
		if (Phys_IsPhysicsObject(g_iGrabTarget[client])) {
			Phys_EnableMotion(g_iGrabTarget[client], false);
			Phys_Sleep(g_iGrabTarget[client]);
		}
		SetEntityMoveType(g_iGrabTarget[client], MOVETYPE_NONE);
		TeleportEntity(g_iGrabTarget[client], vOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bGrabIsRunning[client])
			CreateTimer(0.001, Timer_GrabMain, client);
		else {
			if (GetEntityFlags(g_iGrabTarget[client]) & (FL_CLIENT | FL_FAKECLIENT))
				SetEntityMoveType(g_iGrabTarget[client], MOVETYPE_WALK);
			else {
				if (!g_bGrabFreeze[client] && Phys_IsPhysicsObject(g_iGrabTarget[client])) {
					Phys_EnableMotion(g_iGrabTarget[client], true);
					Phys_Sleep(g_iGrabTarget[client]);
				}
				SetEntityMoveType(g_iGrabTarget[client], g_mtGrabMoveType[client]);
			}
			DispatchKeyValue(g_iGrabTarget[client], "rendermode", "5");
			DispatchKeyValue(g_iGrabTarget[client], "renderamt", "255");
			DispatchKeyValue(g_iGrabTarget[client], "renderfx", "0");
			DispatchKeyValue(g_iGrabTarget[client], "rendercolor", "255 255 255");
		}
	}
	return;
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
	
	if (IsWorldEnt(iTarget)) {
		if (Build_IsAdmin(client)) {
			char szSteamId[32], szIP[16];
			GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			ShowHudText(client, -1, "%s\nIs a World Entity.", iTarget);
		} else {
		}
	}
	
	SetHudTextParams(0.015, 0.08, 0.01, 255, 255, 255, 255, 0, 6.0, 0.1, 0.2);
	if (IsPlayer(iTarget)) {
		int iHealth = GetClientHealth(iTarget);
		if (iHealth <= 1)
			iHealth = 0;
		if (Build_IsAdmin(client)) {
			char szSteamId[32], szIP[16];
			GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			ShowHudText(client, -1, "Player: %N\nHealth: %i\nUserID: %i\nSteamID:%s", iTarget, iHealth, GetClientUserId(iTarget), szSteamId);
		} else {
			ShowHudText(client, -1, "Player: %N\nHealth: %i", iTarget, iHealth);
		}
		return;
	}
	char szClass[32];
	GetEdictClassname(iTarget, szClass, sizeof(szClass));
	if (IsNpc(iTarget)) {
		int iHealth = GetEntProp(iTarget, Prop_Data, "m_iHealth");
		if (iHealth <= 1)
			iHealth = 0;
		ShowHudText(client, -1, "Classname: %s\nHealth: %i", szClass, iHealth);
		return;
	}
	
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
	
	if (Phys_IsPhysicsObject(iTarget)) {
		SetHudTextParams(-1.0, 0.6, 0.01, 255, 0, 0, 255);
		if (StrContains(szClass, "prop_door_", false) == 0) {
			ShowHudText(client, -1, "%s \nbuilt by %s\nPress [TAB] to use", szPropString, szOwner);
		}
		else {
			ShowHudText(client, -1, "%s \nbuilt by %s", szPropString, szOwner);
		}
		//if (g_bClientLang[client])
		
		//ShowHudText(client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s\n重量:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
		//else
		//ShowHudText(client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s\nMass:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
	} else {
		if (g_bClientLang[client])
			ShowHudText(client, -1, "%s \nbuilt by %s", szPropString, szOwner);
		//ShowHudText(client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s", szClass, iTarget, szModel, szOwner);
		//else
		//ShowHudText(client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s", szClass, iTarget, szModel, szOwner);
	}
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

bool IsNpc(int iEntity)
{
	char szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "npc_", false) == 0)
		return true;
	return false;
}

bool IsWorldEnt(int iEntity)
{
	int szOwner = -1;
	if (IsValidEntity(iEntity))
		szOwner = Build_ReturnEntityOwner(iEntity);
	
	if (szOwner == 0)
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
		Build_PrintToChat(client, "Deleted all props you owns.");
	} else {
		Build_PrintToChat(client, "You don't have any props.");
	}
	
	Build_SetLimit(client, 0);
	Build_SetLimit(client, 0, true);
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
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
				Build_PrintToChat(client, "You can't delete this prop!");
				return Plugin_Handled;
			}
		}
		
		float vOriginPlayer[3], vOriginAim[3];
		int Obj_Dissolver = CreateDissolver("3");
		
		Build_ClientAimOrigin(client, vOriginAim);
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
		
		DispatchKeyValue(iEntity, "targetname", "Del_Target");
		
		TE_SetupBeamRingPoint(vOriginAim, 10.0, 150.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, ColorWhite, 20, 0);
		TE_SendToAll();
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
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
		else
			Build_SetLimit(client, -1);
		Build_RegisterEntityOwner(iEntity, -1);
	}
	
	char szTemp[33], szArgs[128];
	for (int i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_del", szArgs);
	return Plugin_Handled;
}

public Action Command_DelRange(int client, int args)
{
	if (!Build_IsClientValid(client, client))
		return Plugin_Handled;
	
	char szCancel[32];
	GetCmdArg(1, szCancel, sizeof(szCancel));
	if (!StrEqual(szCancel, "") && (!StrEqual(g_szDelRangeStatus[client], "off") || !StrEqual(g_szDelRangeStatus[client], ""))) {
		Build_PrintToChat(client, "Canceled DelRange");
		g_szDelRangeCancel[client] = true;
		return Plugin_Handled;
	}
	
	if (StrEqual(g_szDelRangeStatus[client], "x"))
		g_szDelRangeStatus[client] = "y";
	else if (StrEqual(g_szDelRangeStatus[client], "y"))
		g_szDelRangeStatus[client] = "z";
	else if (StrEqual(g_szDelRangeStatus[client], "z"))
		g_szDelRangeStatus[client] = "off";
	else {
		Build_ClientAimOrigin(client, g_fDelRangePoint1[client]);
		g_szDelRangeStatus[client] = "x";
		CreateTimer(0.05, Timer_DR, client);
	}
	return Plugin_Handled;
}

public Action Command_DelStrider(int client, int args)
{
	if (!Build_IsClientValid(client, client))
		return Plugin_Handled;
	
	float fRange;
	char szRange[5];
	float vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(client, vOriginAim);
	
	Handle hDataPack;
	CreateDataTimer(0.01, Timer_DScharge, hDataPack);
	WritePackCell(hDataPack, client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}

public Action Command_DelStrider2(int client, int args)
{
	if (!Build_IsClientValid(client, client))
		return Plugin_Handled;
	
	float fRange;
	char szRange[5];
	float vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(client, vOriginAim);
	
	Handle hDataPack;
	CreateDataTimer(0.01, Timer_DScharge2, hDataPack);
	WritePackCell(hDataPack, client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}

public Action Timer_DR(Handle timer, any client)
{
	if (!Build_IsClientValid(client, client))
		return;
	if (g_szDelRangeCancel[client]) {
		g_szDelRangeCancel[client] = false;
		g_szDelRangeStatus[client] = "off";
		return;
	}
	
	float vPoint2[3], vPoint3[3], vPoint4[3];
	float vClonePoint1[3], vClonePoint2[3], vClonePoint3[3], vClonePoint4[3];
	float vOriginAim[3], vOriginPlayer[3];
	
	if (StrEqual(g_szDelRangeStatus[client], "x")) {
		Build_ClientAimOrigin(client, vOriginAim);
		vPoint2[0] = vOriginAim[0];
		vPoint2[1] = vOriginAim[1];
		vPoint2[2] = g_fDelRangePoint1[client][2];
		vClonePoint1[0] = g_fDelRangePoint1[client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint2, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint2[client] = vPoint2;
		CreateTimer(0.001, Timer_DR, client);
	} else if (StrEqual(g_szDelRangeStatus[client], "y")) {
		Build_ClientAimOrigin(client, vOriginAim);
		vPoint2[0] = g_fDelRangePoint2[client][0];
		vPoint2[1] = g_fDelRangePoint2[client][1];
		vPoint2[2] = g_fDelRangePoint1[client][2];
		vClonePoint1[0] = g_fDelRangePoint1[client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[client][0];
		vPoint3[1] = g_fDelRangePoint1[client][1];
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
		
		GetClientAbsOrigin(client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint3, vClonePoint3, ColorRed);
		DrowLine(vPoint3, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vClonePoint3, ColorRed);
		DrowLine(vPoint4, vClonePoint4, ColorRed);
		DrowLine(vPoint3, g_fDelRangePoint1[client], ColorRed);
		DrowLine(vPoint4, vPoint2, ColorRed);
		DrowLine(vClonePoint1, vClonePoint3, ColorRed);
		DrowLine(vClonePoint2, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint3[client] = vPoint4;
		CreateTimer(0.001, Timer_DR, client);
	} else if (StrEqual(g_szDelRangeStatus[client], "z")) {
		vPoint2[0] = g_fDelRangePoint2[client][0];
		vPoint2[1] = g_fDelRangePoint2[client][1];
		vPoint2[2] = g_fDelRangePoint1[client][2];
		vClonePoint1[0] = g_fDelRangePoint1[client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[client][0];
		vPoint3[1] = g_fDelRangePoint1[client][1];
		vPoint3[2] = g_fDelRangePoint3[client][2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[client][2];
		
		DrowLine(g_fDelRangePoint1[client], vClonePoint1, ColorGreen);
		DrowLine(g_fDelRangePoint1[client], vClonePoint2, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint2, ColorGreen);
		DrowLine(vPoint3, vClonePoint3, ColorGreen);
		DrowLine(vPoint3, vClonePoint4, ColorGreen);
		DrowLine(g_fDelRangePoint3[client], vClonePoint3, ColorGreen);
		DrowLine(g_fDelRangePoint3[client], vClonePoint4, ColorGreen);
		DrowLine(vPoint3, g_fDelRangePoint1[client], ColorGreen);
		DrowLine(vPoint2, g_fDelRangePoint3[client], ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		TE_SetupBeamPoints(vPoint3, g_fDelRangePoint1[client], g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(g_fDelRangePoint3[client], vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint3, vClonePoint1, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint4, vClonePoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		
		CreateTimer(0.001, Timer_DR, client);
	} else {
		vPoint2[0] = g_fDelRangePoint2[client][0];
		vPoint2[1] = g_fDelRangePoint2[client][1];
		vPoint2[2] = g_fDelRangePoint1[client][2];
		vPoint3[0] = g_fDelRangePoint1[client][0];
		vPoint3[1] = g_fDelRangePoint1[client][1];
		vPoint3[2] = g_fDelRangePoint3[client][2];
		
		vClonePoint1[0] = g_fDelRangePoint1[client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = g_fDelRangePoint1[client][2];
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[client][1];
		vClonePoint2[2] = vPoint2[2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[client][2];
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[client], ColorWhite, true);
		DrowLine(vClonePoint2, g_fDelRangePoint1[client], ColorWhite, true);
		DrowLine(vClonePoint3, g_fDelRangePoint3[client], ColorWhite, true);
		DrowLine(vClonePoint4, g_fDelRangePoint3[client], ColorWhite, true);
		DrowLine(vPoint2, vClonePoint1, ColorWhite, true);
		DrowLine(vPoint2, vClonePoint2, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint3, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint4, ColorWhite, true);
		DrowLine(vPoint2, g_fDelRangePoint3[client], ColorWhite, true);
		DrowLine(vPoint3, g_fDelRangePoint1[client], ColorWhite, true);
		DrowLine(vClonePoint1, vClonePoint3, ColorWhite, true);
		DrowLine(vClonePoint2, vClonePoint4, ColorWhite, true);
		
		int Obj_Dissolver = CreateEntityByName("env_entity_dissolver");
		DispatchKeyValue(Obj_Dissolver, "dissolvetype", "3");
		DispatchKeyValue(Obj_Dissolver, "targetname", "Del_Dissolver");
		DispatchSpawn(Obj_Dissolver);
		ActivateEntity(Obj_Dissolver);
		
		float vOriginEntity[3];
		char szClass[32];
		int iCount = 0;
		int iEntity = -1;
		for (int i = 0; i < sizeof(EntityType); i++) {
			while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
				GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
				vOriginEntity[2] += 1;
				if (vOriginEntity[0] != 0 && vOriginEntity[1] != 1 && vOriginEntity[2] != 0 && Build_IsInSquare(vOriginEntity, g_fDelRangePoint1[client], g_fDelRangePoint3[client])) {
					GetEdictClassname(iEntity, szClass, sizeof(szClass));
					if (StrEqual(szClass, "func_physbox"))
						AcceptEntityInput(iEntity, "kill", -1);
					else {
						DispatchKeyValue(iEntity, "targetname", "Del_Target");
						SetVariantString("Del_Target");
						AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
						DispatchKeyValue(iEntity, "targetname", "Del_Drop");
					}
					
					int iOwner = Build_ReturnEntityOwner(iEntity);
					if (iOwner != -1) {
						if (StrEqual(szClass, "5"))
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
			Build_PrintToChat(client, "Deleted %i props.", iCount);
	}
}

public Action Timer_DScharge(Handle timer, Handle hDataPack)
{
	float vOriginAim[3], vOriginPlayer[3];
	ResetPack(hDataPack);
	int client = ReadPackCell(hDataPack);
	float fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	int Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "20");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	int Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	/*
	char szPointTeslaName[128], char szThickMin[64], char szThickMax[64], char szOnUser[128], char szKill[64];
	int Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	float fThickMin = StringToFloat(szRange) / 40;
	float iThickMax = StringToFloat(szRange) / 30;
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
	
	float f;
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
	
	Handle hNewPack;
	CreateDataTimer(1.3, Timer_DSfire, hNewPack);
	WritePackCell(hNewPack, client);
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

public Action Timer_DSfire(Handle timer, Handle hDataPack)
{
	float vOriginAim[3], vOriginPlayer[3];
	ResetPack(hDataPack);
	int client = ReadPackCell(hDataPack);
	int Obj_Push = ReadPackCell(hDataPack);
	int Obj_Core = ReadPackCell(hDataPack);
	float fRange = ReadPackFloat(hDataPack);
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
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	int Obj_Dissolver = CreateDissolver("3");
	float vOriginEntity[3];
	int iCount = 0;
	int iEntity = -1;
	for (int i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			char szClass[33];
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
				
				int iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "5"))
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
	if (iCount > 0 && Build_IsClientValid(client, client))
		Build_PrintToChat(client, "Deleted %i props.", iCount);
}

public Action Timer_DScharge2(Handle timer, Handle hDataPack)
{
	float vOriginAim[3], vOriginPlayer[3];
	ResetPack(hDataPack);
	int client = ReadPackCell(hDataPack);
	float fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	int Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "28");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	int Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	
	float vOriginEntity[3];
	char szClass[32];
	int iEntity = -1;
	for (int i = 0; i < sizeof(EntityType); i++) {
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
	char szPointTeslaName[128], char szThickMin[64], char szThickMax[64], char szOnUser[128], char szKill[64];
	int Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	float fThickMin = StringToFloat(szRange) / 40;
	float iThickMax = StringToFloat(szRange) / 30;
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
	
	float f;
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
	
	Handle hNewPack;
	CreateDataTimer(1.3, Timer_DSfire2, hNewPack);
	WritePackCell(hNewPack, client);
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

public Action Timer_DSfire2(Handle timer, Handle hDataPack)
{
	float vOriginAim[3], vOriginPlayer[3];
	ResetPack(hDataPack);
	int client = ReadPackCell(hDataPack);
	int Obj_Push = ReadPackCell(hDataPack);
	int Obj_Core = ReadPackCell(hDataPack);
	float fRange = ReadPackFloat(hDataPack);
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
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	int Obj_Dissolver = CreateDissolver("3");
	float vOriginEntity[3];
	int iCount = 0;
	int iEntity = -1;
	for (int i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			char szClass[33];
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
				int iOwner = Build_ReturnEntityOwner(iEntity);
				if (iOwner != -1) {
					if (StrEqual(szClass, "5"))
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
	if (iCount > 0 && Build_IsClientValid(client, client))
		Build_PrintToChat(client, "Deleted %i props.", iCount);
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

stock int CreateCore(float vOrigin[3], float fScale, char szSpawnFlags[8])
{
	int Core_Index = CreateEntityByName("env_citadel_energy_core");
	TeleportEntity(Core_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Core_Index, "scale", fScale);
	DispatchKeyValue(Core_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Core_Index);
	return Core_Index;
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

public Action Command_ToolGun(int client, int args)
{
	/*if (client > 0)
	{
		DisplayMenu(g_hBuildHelperMenu, client, MENU_TIME_FOREVER);
	}*/
	
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		GiveToolgun(client);
	}
	
	return Plugin_Handled;
}

public Action Command_PhysGun(int client, int args)
{
	Build_PrintToChat(client, "You have a Physics Gun v1!");
	Build_PrintToChat(client, "Your Physics Gun will be in the secondary slot.");
	TF2Items_GiveWeapon(client, 99999);
	int weapon = GetPlayerWeaponSlot(client, 1);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}

public Action Command_PhysGunNew(int client, int args)
{
	FakeClientCommand(client, "sm_p");
}

public Action Command_Resupply(int client, int args)
{
	Build_PrintToChat(client, "You're now resupplied.");
	TF2_RegeneratePlayer(client);
}

public int MainMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
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
	}
}

public int PropMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int CondMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hCondMenu, param1, MENU_TIME_FOREVER);
		char item[64];
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
				return 0;
			
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
	return 0;
}

public int PlayerStuff(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		char item[64];
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int EquipMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hEquipMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "physgun"))
		{
			FakeClientCommand(param1, "sm_g2");
		}
		if (StrEqual(item, "physgunv2"))
		{
			FakeClientCommand(param1, "sm_p");
		}
		if (StrEqual(item, "toolgun"))
		{
			FakeClientCommand(param1, "sm_toolgun");
		}
		/*if (StrEqual(item, "portalgun"))
		{
				FakeClientCommand(param1, "sm_portalgun");
		}*/
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int RemoveMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		char item[64];
		GetMenuItem(menu, param2, item, sizeof(item));
		
		if (StrEqual(item, "remove"))
		{
			FakeClientCommand(param1, "sm_del");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int BuildHelperMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
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
			FakeClientCommand(param1, "sm_simplelight");
		}
		else if (StrEqual(item, "doors"))
		{
			FakeClientCommand(param1, "sm_propdoor");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hMainMenu, param1, MENU_TIME_FOREVER);
	}
}

public int TF2SBPoseMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuHL2(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuHL2, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuConstructions(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuConstructions, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuConstructions, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuComics(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuComic, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuComic, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuWeapons(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuWeapons, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}

public int PropMenuPickup(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenuAtItem(g_hPropMenuPickup, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];
		
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
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu, param1, MENU_TIME_FOREVER);
	}
}


// GravityGun.SP

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsValidClient(client) && IsPlayerAlive(client)) {
		
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
	
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		
		int aw = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if (IsValidEntity(aw) && g_bIsToolgun[aw])
		{
			int ent = GetEntPropEnt(client, Prop_Data, "m_hViewModel");
			SetEntProp(ent, Prop_Data, "m_nModelIndex", PrecacheModel(MDL_TOOLGUN), 2);
			SetEntProp(ent, Prop_Send, "m_nSequence", 1);
			
			SetHudTextParams(0.0, 0.25, 1.0, 150, 150, 0, 150, 0, 0.0, 0.0, 0.0);
			
			switch (g_iTool[client])
			{
				case 1:ShowHudText(client, -1, "TOOL:\nREMOVER\n\n\n\n[PRIMARY] Remove\n[SECONDARY] Remove\n[RELOAD] Switch Tools");
				case 2:ShowHudText(client, -1, "TOOL:\nTHE EXPLOSION TOOL\n\n\n\n[PRIMARY] BOOM!\n[RELOAD] Switch Tools");
				case 3:ShowHudText(client, -1, "TOOL:\nRESIZE TOOL\n\n\n\n[PRIMARY] Larger\n[SECONDARY] Smaller\n[RELOAD] Switch Tools");
				case 4:ShowHudText(client, -1, "TOOL:\nNO COLLIDE\n\n\n\n[PRIMARY] No Collide\n[SECONDARY] Collide\n[RELOAD] Switch Tools");
				case 5:ShowHudText(client, -1, "TOOL:\nDUPLICATOR\n\n\n\n[PRIMARY] Paste\n[SECONDARY] Copy\n[RELOAD] Switch Tools");
				case 6:ShowHudText(client, -1, "TOOL:\nALPHA\n\n\n\n[PRIMARY] More Transparent\n[SECONDARY] More Visible\n[RELOAD] Switch Tools");
				case 7:ShowHudText(client, -1, "TOOL:\nCOLORS\n%s\n\n\n[PRIMARY] Apply\n[SECONDARY] Restore\n[TERTIARY] Change Colors\n[RELOAD] Switch Tools", g_sCurrentColor[client]);
				case 8:ShowHudText(client, -1, "TOOL:\nSKIN\n\n\n\n[PRIMARY] Next Skin\n[SECONDARY] Previous Skin\n[RELOAD] Switch Tools");
				case 9:ShowHudText(client, -1, "TOOL:\nRENDER FX\n%i\n\n\n[PRIMARY] Apply\n[SECONDARY] Restore\n[TERTIARY] Change FX\n[RELOAD] Switch Tools", g_fxEffectTool[client]);
				case 10:ShowHudText(client, -1, "TOOL:\nSDOOR\n\n\n\n[PRIMARY] Spawn Door\n[SECONDARY] Shoot to Open\n[RELOAD] Switch Tools");
				case 11:ShowHudText(client, -1, "TOOL:\nLIGHTS\n\n\n\n[PRIMARY] Spawn Light\n[RELOAD] Switch Tools");
				case 12:ShowHudText(client, -1, "TOOL:\nPROPDOOR\n\n\n\n[PRIMARY] Spawn Propdoor\n[RELOAD] Switch Tools");
			}
			
			if (buttons & IN_ATTACK2)
			{
				g_bAttackWasMouse2[client] = true;
				buttons &= ~IN_ATTACK2;
				buttons |= IN_ATTACK;
			}
			else
				g_bAttackWasMouse2[client] = false;
			
			if (buttons & IN_ATTACK3)
			{
				g_bAttackWasMouse3[client] = true;
				buttons &= ~IN_ATTACK3;
				buttons |= IN_ATTACK;
			}
			else
				g_bAttackWasMouse3[client] = false;
			
			if (buttons & IN_RELOAD && !g_bPlayerPressedReload[client])
			{
				if (g_iTool[client] < 12)
					g_iTool[client]++;
				else
					g_iTool[client] = 1;
				
				EmitSoundToClient(client, SND_TOOLGUN_SELECT);
				
				g_bPlayerPressedReload[client] = true;
			}
			else if (!(buttons & IN_RELOAD) && g_bPlayerPressedReload[client])
				g_bPlayerPressedReload[client] = false;
		}
	}
	return Plugin_Continue;
	
}

public Action WeaponSwitchHook(int client, int entity)
{
	char weaponname[64];
	if (!IsPlayerAlive(client) || !IsValidEntity(entity)) {
		
		g_bIsWeaponGrabber[client] = false;
		return Plugin_Continue;
		
	}
	
	GetEdictClassname(entity, weaponname, sizeof(weaponname));
	
	int rulecheck = GetConVarInt(g_cvarWeaponSwitchRule);
	
	if (!isWeaponGrabber(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon")) || EntRefToEntIndex(grabbedentref[client]) == -1 || !Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))) {
		
		g_bIsWeaponGrabber[client] = isWeaponGrabber(entity);
		if (g_bIsWeaponGrabber[client])
		{
			int ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			SetEntProp(ent, Prop_Send, "m_nModelIndex", g_PhysGunModel, 2);
			SetEntProp(ent, Prop_Send, "m_nSequence", 2);
		}
		else
		{
			int ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
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

public void PreThinkHook(int client)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		int buttons = GetClientButtons(client);
		int clientteam = GetClientTeam(client);
		
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
				
				
				float nowangle[3];
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
					int iWeapon = GetPlayerWeaponSlot(client, 1);
					int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if (IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && GetEntProp(iActiveWeapon, Prop_Send, "m_iEntityQuality") == 6)
					{
						grab(client);
					}
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

void grab(int client)
{
	int targetentity;
	float distancetoentity, resultpos[3];
	
	targetentity = GetClientAimEntity3(client, distancetoentity, resultpos);
	
	if (IsValidEntity(targetentity) && !IsValidClient(targetentity))
	{
		int entityType = entityTypeCheck(targetentity); //PropTypeCheck 
		
		//int Owner = -1;
		//Owner = GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity");
		if (entityType != 0 && IsValidClient(Build_ReturnEntityOwner(targetentity)))
		{
			
			/*	//should we allow grab?
				if(GetForwardFunctionCount(forwardOnClientGrabEntity) > 0){
				
					int Action:result;
			   
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
			
			if (entityType == 4 && GetEntPropEnt(targetentity, Prop_Send, "m_hBuilder") != client)
				return;
			
			grabentitytype[client] = entityType;
			
			if (entityType == 1) //PROP_RIGID
			{
				//SetEntProp(targetentity, Prop_Data, "m_bFirstCollisionAfterLaunch", false);
			}
			
			
			int lastowner = GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity");
			
			if (lastowner != INVALID_ENT_REFERENCE) {
				
				entityownersave[client] = EntIndexToEntRef(lastowner);
				
			} else {
				
				entityownersave[client] = INVALID_ENT_REFERENCE;
				
			}
			
			SetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity", client);
			grabbedentref[client] = EntIndexToEntRef(targetentity);
			
			//SetEntPropEnt(targetentity, Prop_Data, "m_hParent", client);
			
			//SetEntProp(targetentity, Prop_Data, "m_iEFlags", GetEntProp(targetentity, Prop_Data, "m_iEFlags") | EFL_NO_PHYSCANNON_INTERACTION);
			
			char szClass[64];
			GetEdictClassname(targetentity, szClass, sizeof(szClass));
			
			if (StrEqual(szClass, "prop_physics"))
			{
				entitygravitysave[client] = Phys_IsGravityEnabled(targetentity);
			}
			else entitygravitysave[client] = false;
			
			if (entityType != 1) //PROP_RIGID
			{
				Phys_EnableGravity(targetentity, false);
			}
			
			
			float clienteyeangle[3], entityangle[3], entityposition[3];
			GetEntPropVector(grabbedentref[client], Prop_Send, "m_angRotation", entityangle);
			GetClientEyeAngles(client, clienteyeangle);
			
			playeranglerotate[client][0] = entityangle[0];
			playeranglerotate[client][1] = entityangle[1];
			playeranglerotate[client][2] = entityangle[2];
			
			
			grabdistance[client] = GetEntitiesDistance(client, targetentity);
			GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
			grabpos[client][0] = entityposition[0] - resultpos[0];
			grabpos[client][1] = entityposition[1] - resultpos[1];
			grabpos[client][2] = entityposition[2] - resultpos[2];
			
			
			
			int matrix[matrix3x4_t];
			
			matrix3x4FromAnglesNoOrigin(clienteyeangle, matrix);
			
			float temp[3];
			
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

void emptyshoot(int client)
{
	
	if (!clientcanpull(client)) {
		
		return;
		
	}
	
	int targetentity, float distancetoentity;
	
	targetentity = GetClientAimEntity(client, distancetoentity);
	if (targetentity != -1) {
		
		int entityType = entityTypeCheck(targetentity); //PropTypeCheck 
		
		if (entityType != 0 && (distancetoentity <= GetConVarFloat(cvar_maxpulldistance)) && !IsPlayerAlive(GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity"))) {
			
			if (GetForwardFunctionCount(forwardOnClientEmptyShootEntity) > 0) {
				
				int Action:result;
				
				Call_StartForward(forwardOnClientEmptyShootEntity);
				Call_PushCell(client);
				Call_PushCell(targetentity);
				Call_Finish(result);
				
				if (result != Plugin_Continue) {
					
					return;
					
				}
				
			}
			
			float clienteyeangle[3], float anglevector[3];
			GetClientEyeAngles(client, clienteyeangle);
			GetAngleVectors(clienteyeangle, anglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(anglevector, anglevector);
			ScaleVector(anglevector, GetConVarFloat(cvar_pullforce));
			
			float ZeroSpeed[3];
			ZeroVector(ZeroSpeed);
			//TeleportEntity(targetentity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
			Phys_AddVelocity(targetentity, anglevector, ZeroSpeed);
			
			if (entityType == 1 || entityType == 2 || entityType == 5) {
				
				SetEntPropEnt(targetentity, Prop_Data, "m_hPhysicsAttacker", client);
				SetEntPropFloat(targetentity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
				
			}
			if (entityType == 1) {
				
				//SetEntProp(targetentity, Prop_Data, "m_bThrownByPlayer", true);
				
				
			}
			
			if (entityType != 4)playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PUNT);
			
		}
		
	}
	
}

void release(int client)
{
	if (EntRefToEntIndex(grabbedentref[client]) != -1)
	{
		Phys_EnableGravity(EntRefToEntIndex(grabbedentref[client]), entitygravitysave[client]);
		SetEntPropEnt(grabbedentref[client], Prop_Send, "m_hOwnerEntity", EntRefToEntIndex(entityownersave[client]));
		if (IsValidClient(client) && IsClientInGame(client))
		{
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_DROP);
		}
		firstGrab[client] = false;
	}
	grabbedentref[client] = INVALID_ENT_REFERENCE;
	keybuffer[client] = keybuffer[client] | IN_ATTACK2;
	
	stopentitysound(client, SOUND_GRAVITYGUN_HOLD);
}

void hold(int client)
{
	float resultpos[3], resultvecnormal[3];
	GetClientAimPosition(client, grabdistance[client], resultpos, resultvecnormal, tracerayfilterrocket, client);
	
	float entityposition[3], clientposition[3], vector[3];
	GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
	GetClientEyePosition(client, clientposition);
	float clienteyeangle[3];
	GetClientEyeAngles(client, clienteyeangle);
	
	float clienteyeangleafterchange[3];
	
	float aimorigin[3];
	GetAimOrigin(client, aimorigin);
	
	float fAngles[3];
	float fOrigin[3];
	float fEOrigin[3];
	// bomba
	int g_iWhite[4] =  { 255, 255, 255, 200 };
	GetClientAbsOrigin(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_vecOrigin", fEOrigin);
	
	TE_SetupBeamPoints(fOrigin, fEOrigin, g_iPhys, g_iHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, g_iWhite, 10);
	TE_SendToAll();
	
	clienteyeangleafterchange[0] = clienteyeangle[0] + playeranglerotate[client][0];
	clienteyeangleafterchange[1] = clienteyeangle[1] + playeranglerotate[client][1];
	clienteyeangleafterchange[2] = clienteyeangle[2] + playeranglerotate[client][2];
	
	matrix3x4_t playerlocalspace[matrix3x4_t], playerlocalspaceafterchange[matrix3x4_t];
	
	matrix3x4FromAnglesNoOrigin(clienteyeangle, playerlocalspace);
	matrix3x4FromAnglesNoOrigin(clienteyeangleafterchange, playerlocalspaceafterchange);
	
	
	//TransformAnglesToWorldSpace(grabangle[client], resultangle, playerlocalspaceafterchange);
	//TransformAnglesToLocalSpace(resultangle, grabangle[client], playerlocalspace);
	
	//ZeroVector(playeranglerotate[client]);
	
	MakeVectorFromPoints(entityposition, resultpos, vector);
	ScaleVector(vector, GetConVarFloat(cvar_grabforcemultiply));
	
	float entityangle[3], resultangle2[3];
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_angRotation", entityangle);
	
	resultangle[client][0] = grabangle[client][0];
	resultangle[client][1] = grabangle[client][1];
	resultangle[client][2] = grabangle[client][2];
	//PrintToChatAll("%f :: %f :: %f", entityangle[0], entityangle[1], entityangle[2] );
	resultangle2[0] = resultangle[client][0] + playeranglerotate[client][0];
	resultangle2[1] = resultangle[client][1] + playeranglerotate[client][1];
	resultangle2[2] = resultangle[client][2] + playeranglerotate[client][2];
	
	if (grabentitytype[client] != 5)
	{
		TeleportEntity(grabbedentref[client], NULL_VECTOR, playeranglerotate[client], NULL_VECTOR);
	}
	
	if (grabentitytype[client] != 1)
	{
		Phys_SetVelocity(EntRefToEntIndex(grabbedentref[client]), vector, ZERO_VECTOR, true);
	}
	
	
	float physgunaimfinal[3];
	/*physgunaimfinal[0] = resultpos[0] - aimorigin[0];
	physgunaimfinal[1] = resultpos[1] - aimorigin[1];
	physgunaimfinal[2] = resultpos[2] - aimorigin[2];*/
	
	physgunaimfinal[0] = fOrigin[0] - aimorigin[0];
	physgunaimfinal[1] = fOrigin[1] - aimorigin[1];
	physgunaimfinal[2] = fOrigin[2] - aimorigin[2];
	
	if (grabentitytype[client] == 2 || grabentitytype[client] == 5 || grabentitytype[client] == 7) {
		
		SetEntPropEnt(grabbedentref[client], Prop_Data, "m_hPhysicsAttacker", client);
		SetEntPropFloat(grabbedentref[client], Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
		
	}
	if (grabentitytype[client] == 1) {
		
		float eyeposfornow[3];
		GetClientEyePosition(client, eyeposfornow);
		
		float eyeanglefornow[3];
		GetClientEyeAngles(client, eyeanglefornow);
		
		
		//SetEntProp(grabbedentref[client], Prop_Data, "m_bThrownByPlayer", true);
		//TeleportEntity(grabbedentref[client], resultpos, playeranglerotate[client], NULL_VECTOR);
		//TeleportEntity(grabbedentref[client], resultpos, playeranglerotate[client], NULL_VECTOR);
		TeleportEntity(grabbedentref[client], resultpos, playeranglerotate[client], NULL_VECTOR);
		
	}
	
}

int entityTypeCheck(int entity) //PropTypeCheck
{
	char classname[64];
	GetEdictClassname(entity, classname, 64);
	
	if (StrContains(classname, "prop_dynamic", false) != -1 || StrContains(classname, "tf_dropped_weapon", false) != -1 || StrContains(classname, "prop_door_", false) != -1 || StrContains(classname, "tf_ammo_pack", false) != -1 || StrContains(classname, "prop_physics_multiplayer", false) != -1) {
		
		return 1;
	}
	else if (StrContains(classname, "func_physbox", false) != -1 || StrContains(classname, "prop_physics", false) != -1) {
		
		return 2;
		
	} else if (StrContains(classname, "5", false) != -1) {
		
		return 5;
		
	} else if (StrContains(classname, "weapon_", false) != -1) {
		
		return 3;
		
	} else if (StrContains(classname, "tf_projectile", false) != -1) {
		
		return 6;
		
	} else if (StrEqual(classname, "obj_sentrygun", false) || StrEqual(classname, "obj_dispenser", false)
		 || StrEqual(classname, "obj_teleporter", false)) {
		
		return 1;
	}
	else if (StrContains(classname, "player", false) != -1)
	{
		return 7;
	}
	else {
		
		return 0; //PROP_NONE
		
	}
	
}

bool clientcanpull(int client)
{
	float now = GetGameTime();
	
	if (nextactivetime[client] <= now) {
		
		nextactivetime[client] = now + GetConVarFloat(cvar_pull_delay);
		
		return true;
		
	}
	
	return false;
	
}

bool clientcangrab(int client)
{
	if (!IsValidClient(client))
		return false;
	
	float now = GetGameTime();
	
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
	return false;
}

bool clientisgrabbingvalidobject(int client)
{
	
	if (EntRefToEntIndex(grabbedentref[client]) != -1 && Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))) {
		
		return true;
		
	} else {
		
		return false;
		
	}
	
}

public int Native_GetCurrntHeldEntity(Handle plugin, int args)
{
	
	int client = GetNativeCell(1);
	
	if (IsValidClient(client) && IsPlayerAlive(client)) {
		
		return EntRefToEntIndex(grabbedentref[client]);
		
	} else {
		
		return -1;
		
	}
	
}

public int Native_ForceDropHeldEntity(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	
	if (IsValidClient(client) && IsPlayerAlive(client)) {
		
		release(client);
		return true;
	}
	
	return false;
}

public int Native_ForceGrabEntity(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);
	
	if (IsValidClient(client) && IsPlayerAlive(client)) {
		
		if (IsValidEdict(entity)) {
			
			int entityType = entityTypeCheck(entity);
			
			if (entityType && !IsPlayerAlive(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))) {
				
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

public Action ClientRemoveAll(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_fda <#userid|name>");
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
		ReplyToCommand(client, "[SM] Usage: sm_bl <#userid|name>");
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
			if (g_bClientLang[i])
				Build_PrintToChat(i, "%N 將 %s 加入到黑名單 :(", client, target_name);
			else
				Build_PrintToChat(i, "%N added %s to this server blacklist :(", client, target_name);
		}
	}
	return Plugin_Handled;
}

public Action Command_RemoveBL(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: sm_unbl <#userid|name>");
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
				if (g_bClientLang[i])
					Build_PrintToChat(i, "%N 將 %s 從黑名單移除 :)", client, target_name);
				else
					Build_PrintToChat(i, "%N removed %s from this server blacklist :)", client, target_name);
			}
		}
	} else {
		for (int i = 0; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i)) {
				if (g_bClientLang[i])
					Build_PrintToChat(i, "%N 將 %s 從黑名單移除 :)", client, target_name);
				else
					Build_PrintToChat(i, "%N removed %s from this server blacklist :)", client, target_name);
			}
		}
	}
	return Plugin_Handled;
}

stock void GiveToolgun(int client)
{
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	// Idk why this was here
	//TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
	if (hWeapon != INVALID_HANDLE)
	{
		TF2Items_SetClassname(hWeapon, "tf_weapon_pistol");
		TF2Items_SetItemIndex(hWeapon, 5);
		TF2Items_SetLevel(hWeapon, 100);
		TF2Items_SetQuality(hWeapon, 5);
		
		TF2Items_SetAttribute(hWeapon, 2, 106, 0.0); //Accuracy bonus
		TF2Items_SetAttribute(hWeapon, 3, 1, 0.0); //Damage Penalty
		TF2Items_SetAttribute(hWeapon, 2, 6, 2.0); // Fire Rate Bonus
		//TF2Items_SetAttribute(hWeapon, 2, 5, -1.0); // No limit = fun
		TF2Items_SetNumAttributes(hWeapon, 5);
		
		int weapon = TF2Items_GiveNamedItem(client, hWeapon);
		EquipPlayerWeapon(client, weapon);
		
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		
		CloseHandle(hWeapon);
		
		EquipWearable(client, MDL_TOOLGUN, weapon);
		
		char arms[PLATFORM_MAX_PATH];
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:Format(arms, sizeof(arms), "models/weapons/c_models/c_scout_arms.mdl");
			case TFClass_Soldier:Format(arms, sizeof(arms), "models/weapons/c_models/c_soldier_arms.mdl");
			case TFClass_Pyro:Format(arms, sizeof(arms), "models/weapons/c_models/c_pyro_arms.mdl");
			case TFClass_DemoMan:Format(arms, sizeof(arms), "models/weapons/c_models/c_demo_arms.mdl");
			case TFClass_Heavy:Format(arms, sizeof(arms), "models/weapons/c_models/c_heavy_arms.mdl");
			case TFClass_Engineer:Format(arms, sizeof(arms), "models/weapons/c_models/c_engineer_arms.mdl");
			case TFClass_Medic:Format(arms, sizeof(arms), "models/weapons/c_models/c_medic_arms.mdl");
			case TFClass_Sniper:Format(arms, sizeof(arms), "models/weapons/c_models/c_sniper_arms.mdl");
			case TFClass_Spy:Format(arms, sizeof(arms), "models/weapons/c_models/c_spy_arms.mdl");
		}
		if (strlen(arms) && FileExists(arms, true))
		{
			PrecacheModel(arms, true);
			EquipWearable(client, arms, weapon);
		}
		
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", PrecacheModel(MDL_TOOLGUN));
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(MDL_TOOLGUN), _, 0);
		SetEntProp(weapon, Prop_Send, "m_nSequence", 2);
		
		SetEntityRenderMode(weapon, RENDER_NONE);
		SetEntityRenderColor(weapon, 0, 0, 0, 0);
		
		g_bIsToolgun[weapon] = true;
		g_iTool[client] = 1;
		
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (IsValidEntity(weapon) && g_bIsToolgun[weapon])
	{
		float flStartPos[3], flEyeAng[3], flHitPos[3], fOrigin[3];
		GetClientEyePosition(client, flStartPos);
		GetClientEyeAngles(client, flEyeAng);
		GetClientAbsOrigin(client, fOrigin);
		
		Handle hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, client);
		TR_GetEndPosition(flHitPos, hTrace);
		int iHitEntity = TR_GetEntityIndex(hTrace);
		CloseHandle(hTrace);
		
		// For Entity Check
		char classname[64];
		GetEdictClassname(iHitEntity, classname, 64);
		
		
		
		//	if(TF2_GetClientTeam(client) == TFTeam_Blue)
		//		ShootLaser(weapon, "dxhr_sniper_rail_blue", flStartPos, flHitPos);
		//	else
		//		ShootLaser(weapon, "dxhr_sniper_rail_red", flStartPos, flHitPos);
		
		switch (g_iTool[client])
		{
			case 1:
			{
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (iHitEntity > 0 && IsValidEntity(iHitEntity))
				{
					if (StrContains(classname, "player", false) != -1)
					{
						PrintCenterText(client, "You cannot remove a player!");
					}
					else
					{
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							AcceptEntityInput(iHitEntity, "Kill");
							Build_SetLimit(client, -1);
						}
					}
				}
			}
			case 2:
			{
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (Build_IsAdmin(client))
				{
					int ent = CreateEntityByName("info_particle_system");
					if (IsValidEntity(ent))
					{
						TeleportEntity(ent, flHitPos, NULL_VECTOR, NULL_VECTOR);
						DispatchKeyValue(ent, "effect_name", "asplode_hoodoo");
						DispatchSpawn(ent);
						ActivateEntity(ent);
						AcceptEntityInput(ent, "start");
						SetVariantString("OnUser1 !self:Kill::8:-1");
						AcceptEntityInput(ent, "AddOutput");
						AcceptEntityInput(ent, "FireUser1");
						EmitAmbientSound("weapons/explode3.wav", flHitPos, _, SNDLEVEL_SCREAMING);
					}
				}
				else
				{
					PrintCenterText(client, "This tool now is only for admin due to abusive reasons.");
				}
			}
			case 3:
			{
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (iHitEntity > 0)
				{
					if (Build_IsAdmin(client))
					{
						float flModelScale = GetEntPropFloat(iHitEntity, Prop_Send, "m_flModelScale");
						
						if (g_bAttackWasMouse2[client])
						{
							float flNewScale = flModelScale - 0.1;
							
							if (flNewScale > 0.0)
							{
								char strScale[8];
								FloatToString(flNewScale, strScale, sizeof(strScale));
								
								SetVariantString(strScale);
								AcceptEntityInput(iHitEntity, "SetModelScale");
							}
						}
						else
						{
							float flNewScale = flModelScale + 0.1;
							if (flNewScale > 0.0)
							{
								char strScale[8];
								FloatToString(flNewScale, strScale, sizeof(strScale));
								
								SetVariantString(strScale);
								AcceptEntityInput(iHitEntity, "SetModelScale");
							}
						}
					}
					else
					{
						PrintCenterText(client, "This tool is only available for admins.");
					}
				}
			}
			case 4:
			{
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (g_bAttackWasMouse2[client])
				{
					
					if (iHitEntity > 0)
					{
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntData(iHitEntity, g_CollisionOffset, 5, 4, true);
						}
						
					}
				}
				else
				{
					
					if (iHitEntity > 0)
					{
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntData(iHitEntity, g_CollisionOffset, 2, 4, true);
						}
						
					}
				}
				
			}
			case 5:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				int PropDuped = CreateEntityByName("prop_dynamic_override");
				
				if (g_bAttackWasMouse2[client])
				{
					if (iHitEntity > 0)
					{
						if (StrContains(classname, "player", false) != -1 || StrContains(classname, "obj_", false) != -1)
						{
							PrintCenterText(client, "You cannot duplicate this object!");
						}
						else
						{
							if (Build_IsEntityOwner(client, iHitEntity))
							{
								GetEntPropString(iHitEntity, Prop_Data, "m_ModelName", modelnamedupe[client], 256);
								//GetEntPropString(iHitEntity, Prop_Data, "m_ModelName", modelnamedupe, 256);
								GetEntPropVector(iHitEntity, Prop_Data, "m_angRotation", propeyeangle[client]);
								//PrintToChatAll("Prop name copied %s", modelnamedupe);
							}
						}
					}
				}
				else
				{
					if (StrContains(modelnamedupe[client], "models", false) == -1) {
					}
					else
					{
						if (Build_RegisterEntityOwner(PropDuped, client))
						{
							DispatchKeyValueVector(PropDuped, "origin", flHitPos);
							DispatchKeyValueVector(PropDuped, "angles", propeyeangle[client]);
							
							DispatchKeyValue(PropDuped, "model", modelnamedupe[client]);
							SetEntProp(PropDuped, Prop_Data, "m_nSolidType", 6);
							DispatchSpawn(PropDuped);
							ActivateEntity(PropDuped);
							
							int PlayerSpawnCheck;
							
							while ((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
							{
								if (Entity_InRange(PropDuped, PlayerSpawnCheck, 400.0))
								{
									
									
								}
							}
							
							//PrintToChatAll("Prop name pasted %s", modelnamedupe);
						}
						else
						{
							RemoveEdict(PropDuped);
						}
					}
				}
			}
			case 6:
			{
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				int alphatest[4];
				flEyeAng[0] = 0.0;
				
				if (g_bAttackWasMouse2[client])
				{
					if (Build_IsEntityOwner(client, iHitEntity))
					{
						GetEntityRenderColor(iHitEntity, alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
						if (alphatest[3] < 255)
						{
							
							alphatest[3] = alphatest[3] + 15;
							SetEntityRenderMode(iHitEntity, RENDER_TRANSALPHA);
							SetEntityRenderColor(iHitEntity, alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
							//PrintToChatAll("%i, %i, %i, %i", alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
						}
					}
				}
				else
				{
					if (Build_IsEntityOwner(client, iHitEntity))
					{
						GetEntityRenderColor(iHitEntity, alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
						if (alphatest[3] >= 1)
						{
							
							alphatest[3] = alphatest[3] - 15;
							SetEntityRenderMode(iHitEntity, RENDER_TRANSALPHA);
							SetEntityRenderColor(iHitEntity, alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
							//PrintToChatAll("%i, %i, %i, %i", alphatest[0], alphatest[1], alphatest[2], alphatest[3]);
						}
					}
				}
			}
			case 7:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (g_bAttackWasMouse3[client])
				{
					if (g_iColorTool[client] < 6)
						g_iColorTool[client]++;
					else
						g_iColorTool[client] = 1;
					
					switch (g_iColorTool[client])
					{
						case 1:
						{
							g_sCurrentColor[client] = "Red";
							g_iCurrentColor[client][0] = 255;
							g_iCurrentColor[client][1] = 0;
							g_iCurrentColor[client][2] = 0;
						}
						case 2:
						{
							g_sCurrentColor[client] = "Orange";
							g_iCurrentColor[client][0] = 255;
							g_iCurrentColor[client][1] = 165;
							g_iCurrentColor[client][2] = 0;
						}
						case 3:
						{
							g_sCurrentColor[client] = "Yellow";
							g_iCurrentColor[client][0] = 255;
							g_iCurrentColor[client][1] = 255;
							g_iCurrentColor[client][2] = 0;
						}
						case 4:
						{
							g_sCurrentColor[client] = "Green";
							g_iCurrentColor[client][0] = 0;
							g_iCurrentColor[client][1] = 128;
							g_iCurrentColor[client][2] = 0;
						}
						case 5:
						{
							g_sCurrentColor[client] = "Blue";
							g_iCurrentColor[client][0] = 0;
							g_iCurrentColor[client][1] = 0;
							g_iCurrentColor[client][2] = 255;
						}
						case 6:
						{
							g_sCurrentColor[client] = "Violet";
							g_iCurrentColor[client][0] = 238;
							g_iCurrentColor[client][1] = 130;
							g_iCurrentColor[client][2] = 238;
						}
					}
					
				}
				else if (g_bAttackWasMouse2[client])
				{
					if (iHitEntity > 0) {
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntityRenderColor(iHitEntity, 255, 255, 255, _);
						}
					}
				}
				else
				{
					if (iHitEntity > 0) {
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntityRenderColor(iHitEntity, g_iCurrentColor[client][0], g_iCurrentColor[client][1], g_iCurrentColor[client][2], _);
						}
					}
				}
			}
			case 8:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (iHitEntity > 0) {
					if (g_bAttackWasMouse2[client])
					{
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							if (GetEntProp(iHitEntity, Prop_Send, "m_nSkin") > 0) {
								SetEntProp(iHitEntity, Prop_Send, "m_nSkin", GetEntProp(iHitEntity, Prop_Send, "m_nSkin") - 1, 1);
								Build_PrintToChat(client, "Skin %i has been applied to prop.", GetEntProp(iHitEntity, Prop_Send, "m_nSkin"));
							}
						}
					}
					else
					{
						
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntProp(iHitEntity, Prop_Send, "m_nSkin", GetEntProp(iHitEntity, Prop_Send, "m_nSkin") + 1, 1);
							Build_PrintToChat(client, "Skin %i has been applied to prop.", GetEntProp(iHitEntity, Prop_Send, "m_nSkin"));
						}
					}
				}
			}
			case 9:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (g_bAttackWasMouse3[client])
				{
					if (g_iEffectTool[client] < 17)
						g_iEffectTool[client]++;
					else
						g_iEffectTool[client] = 1;
					
					switch (g_iEffectTool[client])
					{
						case 1:g_fxEffectTool[client] = RENDERFX_NONE;
						case 2:g_fxEffectTool[client] = RENDERFX_PULSE_SLOW;
						case 3:g_fxEffectTool[client] = RENDERFX_PULSE_FAST;
						case 4:g_fxEffectTool[client] = RENDERFX_PULSE_SLOW_WIDE;
						case 5:g_fxEffectTool[client] = RENDERFX_PULSE_FAST_WIDE;
						case 6:g_fxEffectTool[client] = RENDERFX_FADE_SLOW;
						case 7:g_fxEffectTool[client] = RENDERFX_FADE_FAST;
						case 8:g_fxEffectTool[client] = RENDERFX_SOLID_SLOW;
						case 9:g_fxEffectTool[client] = RENDERFX_SOLID_FAST;
						case 10:g_fxEffectTool[client] = RENDERFX_STROBE_SLOW;
						case 11:g_fxEffectTool[client] = RENDERFX_STROBE_FAST;
						case 12:g_fxEffectTool[client] = RENDERFX_STROBE_FASTER;
						case 13:g_fxEffectTool[client] = RENDERFX_FLICKER_SLOW;
						case 14:g_fxEffectTool[client] = RENDERFX_FLICKER_FAST;
						case 15:g_fxEffectTool[client] = RENDERFX_NO_DISSIPATION;
						case 16:g_fxEffectTool[client] = RENDERFX_DISTORT;
						case 17:g_fxEffectTool[client] = RENDERFX_HOLOGRAM;
						
					}
					
				}
				else if (g_bAttackWasMouse2[client])
				{
					if (iHitEntity > 0) {
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntityRenderFx(iHitEntity, RENDERFX_NONE);
						}
					}
				}
				else
				{
					if (iHitEntity > 0) {
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							SetEntityRenderFx(iHitEntity, g_fxEffectTool[client]);
						}
					}
				}
			}
			case 10:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				if (g_bAttackWasMouse2[client])
				{
					if (iHitEntity > 0) {
						if (Build_IsEntityOwner(client, iHitEntity))
						{
							FakeClientCommand(client, "sm_sdoor b");
						}
					}
				}
				else {
					FakeClientCommand(client, "sm_sdoor 7");
				}
				//FakeClientCommand(client, "sm_sdoor 7");
				
			}
			case 11:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				FakeClientCommand(client, "sm_simplelight");
				
			}
			case 12:
			{
				flEyeAng[0] = 0.0;
				
				int currentTime = GetTime();
				if (currentTime - LastUsed[client] < 1)
					return Plugin_Handled;
				
				LastUsed[client] = currentTime;
				
				FakeClientCommand(client, "sm_propdoor");
				
			}
		}
		
		int random = GetRandomInt(0, 1);
		if (random == 1) {
			/* Fuck you all toolgun spammers. I made this change so you guys cannot rape people ears. Thank you.
			I'd rather change the toolgun sound to play the entire Em Gai Mua song, but LeadKiller doesn't want me so then, that's it all.
			*/
			//EmitAmbientSound(SND_TOOLGUN_SHOOT2, flHitPos, iHitEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			//EmitAmbientSound(SND_TOOLGUN_SHOOT2, fOrigin, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT2, iHitEntity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT2, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			/*EmitSoundToAll(SND_TOOLGUN_SHOOT2, weapon, SNDCHAN_WEAPON, SNDLEVEL_RAIDSIREN);
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT2);*/
		} else {
			/*EmitSoundToAll(SND_TOOLGUN_SHOOT, weapon, SNDCHAN_WEAPON, SNDLEVEL_RAIDSIREN);
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT);*/
			
			// Fuck you all toolgun spammers. I made this change so you guys cannot rape people ears. Thank you.
			//EmitAmbientSound(SND_TOOLGUN_SHOOT, flHitPos, iHitEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			//EmitAmbientSound(SND_TOOLGUN_SHOOT, fOrigin, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT, iHitEntity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitSoundToClient(client, SND_TOOLGUN_SHOOT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
		
		TE_SetupBeamRingPoint(flHitPos, 10.0, 150.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, ColorWhite, 20, 0);
		TE_SendToAll();
		TE_SetupBeamPoints(flHitPos, fOrigin, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		SetEntProp(weapon, Prop_Send, "m_iClip1", -1);
	}
	return Plugin_Continue;
}

public bool TraceRayDontHitEntity(int entity, int mask, any data)
{
	if (entity == data)
		return false;
	
	return true;
}

public void OnWeaponSwitch(int client, int iWep)
{
	if (IsValidEntity(iWep))
	{
		int i = -1;
		while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
		{
			if (client == g_hWearableOwner[i])
			{
				int effects = GetEntProp(i, Prop_Send, "m_fEffects");
				if (iWep == g_iTiedEntity[i])
					SetEntProp(i, Prop_Send, "m_fEffects", effects & ~32);
				else
					SetEntProp(i, Prop_Send, "m_fEffects", effects |= 32);
			}
		}
	}
}

public void OnEntityDestroyed(int ent)
{
	if (ent <= 0 || ent > 2048)
		return;
	
	g_bIsToolgun[ent] = false;
	g_iTiedEntity[ent] = 0;
	g_hWearableOwner[ent] = 0;
}

stock int EquipWearable(int client, char[] Mdl, int weapon = 0)
{
	int wearable = CreateWearable(client, Mdl);
	if (wearable == -1)
		return -1;
	
	g_hWearableOwner[wearable] = client;
	
	if (weapon > MaxClients)
	{
		g_iTiedEntity[wearable] = weapon;
		
		int effects = GetEntProp(wearable, Prop_Send, "m_fEffects");
		if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
			SetEntProp(wearable, Prop_Send, "m_fEffects", effects & ~32);
		else
			SetEntProp(wearable, Prop_Send, "m_fEffects", effects |= 32);
	}
	return wearable;
}

stock int CreateWearable(int client, char[] model)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	
	SetVariantString("!activator");
	ActivateEntity(ent);
	
	TF2_EquipWearable(client, ent);
	return ent;
}

stock void TF2_EquipWearable(int client, int entity)
{
	if (g_hSdkEquipWearable == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("tf2items.randomizer");
		if (hGameConf == INVALID_HANDLE)
		{
			SetFailState("Couldn't load SDK functions. Could not locate tf2items.randomizer.txt in the gamedata folder.");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		if (g_hSdkEquipWearable == INVALID_HANDLE)
		{
			SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
			CloseHandle(hGameConf);
			return;
		}
	}
	if (g_hSdkEquipWearable != INVALID_HANDLE)
		SDKCall(g_hSdkEquipWearable, client, entity);
}

public Action Command_TF2SBHideHud(int client, int args)
{
	int hidehudnumber = GetEntProp(client, Prop_Send, "m_iHideHUD");
	
	if (hidehudnumber == 2048)
	{
		Client_SetHideHud(client, HIDEHUD_ALL);
		Client_SetDrawViewModel(client, false);
	}
	else
	{
		Client_SetHideHud(client, HIDEHUD_BONUS_PROGRESS);
		Client_SetDrawViewModel(client, true);
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