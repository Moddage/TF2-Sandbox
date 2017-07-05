#include <sourcemod>
#include <tf2items_giveweapon>
#include <build>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

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

new String:g_szFile[128];
new Handle:g_hPropNameArray;
new Handle:g_hPropModelPathArray;
new Handle:g_hPropTypeArray;
new Handle:g_hPropStringArray;

public Plugin:myinfo = {
	name = "TF2 Sandbox - Menu",
	author = "Danct12",
	description = "All-in-One menu for multiple purposes!",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart()
{
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
    
	// Build Helper (placeholder)
	g_hBuildHelperMenu = CreateMenu(BuildHelperMenu);
	SetMenuTitle(g_hBuildHelperMenu, "TF2SB - Build Helper\nThis was actually a placeholder because we can't figure out how to make a toolgun");

	AddMenuItem(g_hBuildHelperMenu, "delprop", "Delete Prop");
	AddMenuItem(g_hBuildHelperMenu, "colors", "Color (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "effects", "Effects (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "skin", "Skin (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "rotate", "Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "accuraterotate", "Accurate Rotate (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "sdoors", "Doors (see chat)");
	AddMenuItem(g_hBuildHelperMenu, "pdoors", "Prop Doors");
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
	
	// HL2 Props
	g_hPropMenuHL2 = CreateMenu(PropMenuHL2);
	SetMenuTitle(g_hPropMenuHL2, "TF2SB - HL2 Props and Miscs\nSay /g in chat to move Entities!");
    SetMenuExitBackButton(g_hPropMenuHL2, true);
	AddMenuItem(g_hPropMenuHL2, "removeprops", "|Remove");
	
	
	
	g_hPropNameArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 2048);	// Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 2048);
	
	ReadProps();
	
	new String:szPropName[32], String:szPropFrozen[32], String:szPropString[256], String:szModelPath[128];
	
	new PropName = FindStringInArray(g_hPropNameArray, szPropName);
	new PropString = FindStringInArray(g_hPropNameArray, szPropString);
	
}

public void OnConfigExecuted(){
	
}

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
	TF2Items_GiveWeapon(client, 99999);
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
		
		if(StrEqual(info, "removeprops"))
		{
			DisplayMenu(g_hRemoveMenu, param1, MENU_TIME_FOREVER);
		}
		else if(StrEqual(info, "constructprops"))
		{
			DisplayMenu(g_hPropMenuConstructions, param1, MENU_TIME_FOREVER);
		}
		else if(StrEqual(info, "comicprops"))
		{
			DisplayMenu(g_hPropMenuComic, param1, MENU_TIME_FOREVER);
		}
		else if(StrEqual(info, "weaponsprops"))
		{
			DisplayMenu(g_hPropMenuWeapons, param1, MENU_TIME_FOREVER);
		}
		else if(StrEqual(info, "pickupprops"))
		{
			DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		}
		else if(StrEqual(info, "hl2props"))
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
			if(TF2_IsPlayerInCondition(param1, TFCond_CritCanteen))
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
			if (!Build_AllowToUse(param1) || Build_IsBlacklisted(param1) || !Build_IsClientValid(param1, param1, true))
						return Plugin_Handled;
						
			if (GetEntityMoveType(param1) != MOVETYPE_NOCLIP)
			{
				Build_PrintToChat(param1, "Noclip ON");
				SetEntityMoveType(param1, MOVETYPE_NOCLIP);
			}
			else
			{
				Build_PrintToChat(param1, "Noclip OFF");
				SetEntityMoveType(param1, MOVETYPE_WALK);
			}
		}
		
/*		if (StrEqual(item, "godmode"))
		{
			FakeClientCommand(param1, "sm_god");				
		}
		
		if (StrEqual(item, "buddha"))
		{
			FakeClientCommand(param1, "sm_buddha");				
		}*/
		
		if (StrEqual(item, "fly"))
		{
			if (!Build_AllowToUse(param1) || Build_IsBlacklisted(param1) || !Build_IsClientValid(param1, param1, true))
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
			if(TF2_IsPlayerInCondition(param1, TFCond_NoHealingDamageBuff))
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
			if(TF2_IsPlayerInCondition(param1, TFCond_DefenseBuffNoCritBlock))
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
			if(TF2_IsPlayerInCondition(param1, TFCond_HalloweenSpeedBoost))
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
		else if (StrEqual(item, "sdoors"))
		{
			FakeClientCommand(param1, "sm_sdoor");
		}
		else if (StrEqual(item, "pdoors"))
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
				PrintToChat(param1, "Made you stop Taunting");
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1))
	{
		DisplayMenu(g_hPlayerStuff, param1, MENU_TIME_FOREVER);
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
		
		if(StrEqual(info, "removeprops"))
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
		
		if(StrEqual(info, "removeprops"))
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
		
		if(StrEqual(info, "removeprops"))
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
		
		if(StrEqual(info, "removeprops"))
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

public PropMenuHL2(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select && IsClientInGame(param1))
    {
		DisplayMenuAtItem(g_hPropMenuHL2, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        //DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		decl String:info[255];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "removeprops"))
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
				} else if (szLine[i] == '/' && i != iLen - 1 && szLine[i+1] == '/') {
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
