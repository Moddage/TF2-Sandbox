////////////////////////
// Table of contents: 
//		Main Menu	  
//					  
//	1.Load...     	  
//	2.Save...	 	  
//	3.Delete...		  
//  4.Set Permission...
//  5.Load others project...
//	6.Cache System...
//	7.Connect to Cloud Storage
//		  		      
////////////////////////

#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck, maintained by Yuuki795"
#define PLUGIN_VERSION "9.7"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <vphysics>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - SaveSystem", 
	author = PLUGIN_AUTHOR, 
	description = "Save System for TF2SandBox", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/tf2-sandbox-studio/Module-SaveSystem"
};

Handle g_hFileEditting[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle cvg_iCoolDownsec;
Handle cviStoreSlot;
Handle cviLoadMode;
Handle cviLoadSec;
Handle cviLoadProps;
Handle cviAdvertisement;
Handle cvMapname;

char g_cCurrentMap[64];

#define MAX_SLOT 50
bool g_bPermission[MAXPLAYERS + 1][MAX_SLOT + 1]; //client, slot

//Cache system
Handle g_hCacheTimer[MAXPLAYERS + 1] = INVALID_HANDLE;

bool g_bWaitingForPlayers;

int g_iCoolDown[MAXPLAYERS + 1] = 0;
int g_iSelectedClient[MAXPLAYERS + 1];

//Cloud
char dbconfig[] = "SaveSystem";
Database g_DB;

int g_iCloudRow[MAXPLAYERS + 1];
bool g_SqlRunning = false;

/*******************************************************************************************
	Start
*******************************************************************************************/
public void OnPluginStart()
{
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	if(g_DB != INVALID_HANDLE) SQL_SetCharset(g_DB, "utf8");
	
	CreateConVar("sm_tf2sb_ss_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	
	cvg_iCoolDownsec = CreateConVar("sm_tf2sb_ss_cooldownsec", "2", "(1 - 50) Set CoolDown seconds to prevent flooding.", 0, true, 1.0, true, 50.0);
	cviStoreSlot = CreateConVar("sm_tf2sb_ss_storeslots", "4", "(1 - 50) How many slots for client to save", 0, true, 1.0, true, float(MAX_SLOT));
	cviLoadMode = CreateConVar("sm_tf2sb_ss_loadmode", "1", "1 = Load instantly, 2 = Load Props by Timer (Slower but less lag?)", 0, true, 1.0, true, 2.0);
	cviLoadSec = CreateConVar("sm_tf2sb_ss_loadsec", "0.01", "(0.01 - 1.00) Load Props/Sec (Work on sm_tf2sb_ss_loadmode 2 only)", 0, true, 0.01, true, 1.0);
	cviLoadProps = CreateConVar("sm_tf2sb_ss_loadprops", "3", "(1 - 60) Load Sec/Props (Work on sm_tf2sb_ss_loadmode 2 only)", 0, true, 1.0, true, 60.0);
	cviAdvertisement = CreateConVar("sm_tf2sb_ss_ads", "30.0", "(10.0 - 60.0) Advertisement loop time", 0, true, 10.0, true, 60.0);
	cvMapname = CreateConVar("sm_tf2sb_ss_mapcheck", "", "Load map name of the file. (Nothing = Current map)");
	
	RegAdminCmd("sm_ss", Command_MainMenu, 0, "Open SaveSystem menu");
	RegAdminCmd("sm_ssload", Command_LoadDataFromDatabase, ADMFLAG_GENERIC, "Usage: sm_ssload <targetname|steamid64> <slot>");
	RegAdminCmd("sm_ssname", Command_SetDataName, 0, "Usage: sm_ssname <slot> <name>");
	
	char cCheckPath[128];
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "data/TF2SBSaveSystem");
	if (!DirExists(cCheckPath))
	{
		CreateDirectory(cCheckPath, 511);
		
		if (DirExists(cCheckPath))
		{
			PrintToServer("[TF2SB] Folder TF2SBSaveSystem created under addons/sourcemod/data/ sucessfully!");
		}
		else
		{
			SetFailState("[TF2SB] Failed to create directory addons/sourcemod/data/TF2SBSaveSystem/ - Please manually create this directory and reload the plugin.");
		}
	}
	
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "data/TF2SBCache");
	if (!DirExists(cCheckPath))
	{
		CreateDirectory(cCheckPath, 511);
		
		if (DirExists(cCheckPath))
		{
			PrintToServer("[TF2SB] Folder TF2SBCache created under addons/sourcemod/data/ sucessfully!");
		}
		else
		{
			SetFailState("[TF2SB] Failed to create directory addons/sourcemod/data/TF2SBCache/ - Please manually create this directory and reload the plugin.");
		}
	}
	
	AutoExecConfig();
	CreateTimer(5.0, Timer_LoadMap, 0);
}

public Action Command_LoadDataFromDatabase(int client, int args)
{
	if (Build_IsClientValid(client, client))
	{
		if (g_iCoolDown[client] != 0)
		{
			Build_PrintToChat(client, "Loading is currently on cooldown, please wait \x04%i\x01 more seconds.", g_iCoolDown[client]);
		}
		else if (args == 2)
		{
			char cTarget[20], cSlot[8];
			GetCmdArg(1, cTarget, sizeof(cTarget));
			GetCmdArg(2, cSlot, sizeof(cSlot));
			
			int targets[1]; // When not target multiple players, COMMAND_FILTER_NO_MULTI 
			char target_name[MAX_TARGET_LENGTH];
			bool tn_is_ml;
			int targets_found = ProcessTargetString(cTarget, client, targets, sizeof(targets), COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml);
			
			if (targets_found <= COMMAND_TARGET_AMBIGUOUS) Build_PrintToChat(client, "Error: More then one client has the name \x04%s\x01!", cTarget);
			else if (targets_found <= COMMAND_TARGET_NONE)
			{
				Build_PrintToChat(client, "Searching for SteamID(\x04%s\x01)... Searching for save slot\x04%i\x01...", cTarget, StringToInt(cSlot));
				
				char cFileName[255];
				BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", g_cCurrentMap, cTarget, StringToInt(cSlot));
				
				if (FileExists(cFileName)) LoadDataSteamID(client, cTarget, StringToInt(cSlot));
				else Build_PrintToChat(client, "Error: Failed to find the save file!");
			}
			else
			{
				Build_PrintToChat(client, "Found target(\x04%N\x01)... Searching file slot\x04%i\x01...", targets[0], StringToInt(cSlot));
				if (DataFileExist(targets[0], StringToInt(cSlot))) LoadData(client, targets[0], StringToInt(cSlot));
				else Build_PrintToChat(client, "Error: Failed to find the save file...");
			}
			
			g_iCoolDown[client] = GetConVarInt(cvg_iCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else Build_PrintToChat(client, "Usage: sm_ssload <\x04targetname\x01|\x04steamid\x01> <\x04slot\x01>");
	}
}

public Action Command_SetDataName(int client, int args)
{
	if (!Build_IsClientValid(client, client))
	{
		return;
	}
	
	if (args < 2)
	{
		Build_PrintToChat(client, "Usage: sm_ssname <\x04slot\x01> <\x04name\x01>");
		return;
	}
	
	char cSlot[8];
	GetCmdArg(1, cSlot, sizeof(cSlot));
	
	int slot = StringToInt(cSlot);
	if (slot == 0)
	{
		Build_PrintToChat(client, "Usage: sm_ssname <\x04slot\x01> <\x04name\x01>");
		return;
	}
	
	char cName[255];
	GetCmdArgString(cName, sizeof(cName));
	
	char szBuffer[10][255];
	ExplodeString(cName, " ", szBuffer, 10, 255);
	
	Format(cName, sizeof(cName), "%s %s %s", szBuffer[1], szBuffer[2], szBuffer[3]);
	
	TrimString(cName);
	
	SetDataName(client, slot, cName);
	
	Build_PrintToChat(client, "Set slot \x04%i\x01 name to \x04%s\x01!", slot, cName);
}

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
	
	CreateTimer(GetConVarFloat(cviAdvertisement), Timer_Ads, 0, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(3.0, Timer_LoadMap, 0, TIMER_FLAG_NO_MAPCHANGE);
	ServerCommand("sm_cvar mp_waitingforplayers_cancel 1");
	
	TagsCheck("SandBox_Addons");
}

public void OnConfigsExecuted()
{
	TagsCheck("SandBox_Addons");
}

public void OnClientPutInServer(int client)
{
	g_iCoolDown[client] = 0;
	for (int j = 0; j < 50; j++)
	g_bPermission[client][j] = false;
	
	//Cache system
	g_hCacheTimer[client] = INVALID_HANDLE;
	
	if(g_bWaitingForPlayers)	CreateTimer(30.0, Timer_Load, client);
	else CreateTimer(5.0, Timer_Load, client);
}

public void OnClientDisconnect(int client)
{
	if (g_hCacheTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hCacheTimer[client]);
	}
}

public void TF2_OnWaitingForPlayersStart()
{
	g_bWaitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_bWaitingForPlayers = false;
}

/*******************************************************************************************
	Timer
*******************************************************************************************/
public Action Timer_CoolDownFunction(Handle timer, int client)
{
	g_iCoolDown[client] -= 1;
	
	if (g_iCoolDown[client] >= 1) CreateTimer(1.0, Timer_CoolDownFunction, client);
	else g_iCoolDown[client] = 0;
}

public Action Timer_Ads(Handle timer, int LoopNumber)
{
	switch (LoopNumber)
	{
		case (0): Build_PrintToAll(" Say \x04/ss\x01 to SAVE or LOAD your builds!");
		case (1): Build_PrintToAll(" Remember to SAVE your builds! Say \x04/ss\x01 in the chat to save!");
		case (2): Build_PrintToAll(" Cache System will help you cache your props!");
		case (3): Build_PrintToAll(" If you disconnected accidently, do not worry! Cache System will save your props!");
		case (4): CPrintToChatAll("[{green}Save System{default}] {orange}Developers{default}: {yellow}BattlefieldDuck{default}, {green}aIM{default}, {pink}Leadkiller{default}, {red}Danct12{default}.");
	}
	
	LoopNumber++;
	
	if (LoopNumber > 4) LoopNumber = 0;
	
	CreateTimer(GetConVarFloat(cviAdvertisement), Timer_Ads, LoopNumber, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_LoadMap(Handle timer, int client)
{
	char Mapname[64];
	GetConVarString(cvMapname, Mapname, sizeof(Mapname));
	
	if (strlen(Mapname) == 0) GetCurrentMap(g_cCurrentMap, sizeof(g_cCurrentMap));
	else strcopy(g_cCurrentMap, sizeof(Mapname), Mapname);
}

//Cache system
public Action Timer_Save(Handle timer, int client)
{
	if (!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	
	SaveData(client, 0);
	
	return Plugin_Continue;
}

public Action Timer_Load(Handle timer, int client)
{
	if (IsValidClient(client) && !IsFakeClient(client) && !g_bWaitingForPlayers)
	{
		if (DataFileExist(client, 0)) Command_CacheMenu(client, -1);
		else if (g_hCacheTimer[client] == INVALID_HANDLE)
		{
			g_hCacheTimer[client] = CreateTimer(5.0, Timer_Save, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else CreateTimer(5.0, Timer_Load, client);
}
//------------

/*******************************************************************************************
	Cache Menu
*******************************************************************************************/
public Action Command_CacheMenu(int client, int args)
{
	char menuinfo[1024];
	Menu menu = new Menu(Handler_CacheMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Cache System Menu v%s\n \nSome of your props were cached before you disconnected.\nWould you like to load your Cache?\n ", PLUGIN_VERSION);
	menu.SetTitle(menuinfo);
	
	int iSlot = 0;
	char cDate[11], cSlot[6];
	IntToString(iSlot, cSlot, sizeof(cSlot));
	
	if (DataFileExist(client, iSlot))
	{
		GetDataDate(client, iSlot, cDate, sizeof(cDate));
		Format(menuinfo, sizeof(menuinfo), " Cache (Stored %s, %i Props)", cDate, GetDataProps(client, iSlot));
	}
	else Format(menuinfo, sizeof(menuinfo), " Cache (No Data)");
	
	menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
	
	Format(menuinfo, sizeof(menuinfo), " Yes, Load it.", client);
	menu.AddItem("LOAD", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " No, Don't load it", client);
	menu.AddItem("DELETE", menuinfo);
	
	menu.ExitBackButton = false;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CacheMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "LOAD")) LoadData(client, client, 0); //Load Cache
		else if (StrEqual(info, "DELETE"))
		{
			char cFileName[255];
			GetBuildPath(client, 0, cFileName);
			
			if (FileExists(cFileName)) DeleteFile(cFileName); //Delete
		}
		
		CreateTimer(5.0, Timer_Save, client);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}


/*******************************************************************************************
	1. Main Menu
*******************************************************************************************/
public Action Command_MainMenu(int client, int args)
{
	if(g_SqlRunning)
	{
		Build_PrintToAll(" Cloud Storage is currently loading!");
		return Plugin_Handled;
	}
	
	char menuinfo[1024];
	Menu menu = new Menu(Handler_MainMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s\n ", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Load... ", client);
	menu.AddItem("LOAD", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Save... ", client);
	menu.AddItem("SAVE", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Delete... ", client);
	menu.AddItem("DELETE", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Set Save Permissions... ", client);
	menu.AddItem("PERMISSION", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Load Other Saves... ", client);
	if (GetClientInGame() > 1) menu.AddItem("LOADOTHERS", menuinfo);
	else menu.AddItem("LOADOTHERS", menuinfo, ITEMDRAW_DISABLED);
	
	Format(menuinfo, sizeof(menuinfo), " Cache System... ", client);
	menu.AddItem("CACHE", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Connect to Cloud Storage... ", client);
	menu.AddItem("CLOUD", menuinfo);
	
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Handler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "LOAD")) Command_LoadMenu(client, -1);
		else if (StrEqual(info, "SAVE")) Command_SaveMenu(client, -1);
		else if (StrEqual(info, "DELETE")) Command_DeleteMenu(client, -1);
		else if (StrEqual(info, "PERMISSION")) Command_PermissionMenu(client, -1);
		else if (StrEqual(info, "LOADOTHERS")) Command_LoadOthersMenu(client, -1);
		else if (StrEqual(info, "CACHE")) Command_CheckCacheMenu(client, -1);
		else if (StrEqual(info, "CLOUD"))
		{
			Handle dp;
			CreateDataTimer(0.1, Timer_SqlRunning, dp);
			WritePackCell(dp, client);
			WritePackCell(dp, 0);
			WritePackCell(dp, 25);
			g_SqlRunning = true;
			
			Command_CloudMenu(client, -1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) FakeClientCommand(client, "sm_build");
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 2. Load Menu
*******************************************************************************************/
public Action Command_LoadMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_LoadMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to LOAD....", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	char cSlot[6], cDate[11];
	for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
	{
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			GetDataDate(client, iSlot, cDate, sizeof(cDate));
			Format(menuinfo, sizeof(menuinfo), " Slot %i (%s, %i Props)[%s]", iSlot, cDate, GetDataProps(client, iSlot), GetDataName(client, iSlot));
			menu.AddItem(cSlot, menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
			menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_LoadMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (g_iCoolDown[client] == 0)
		{
			LoadData(client, client, iSlot);
			g_iCoolDown[client] = GetConVarInt(cvg_iCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else Build_PrintToChat(client, "Load Function is currently on cooldown, please wait \x04%i\x01 seconds.", g_iCoolDown[client]);
		
		Command_LoadMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_MainMenu(client, -1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 3. Save Menu
*******************************************************************************************/
public Action Command_SaveMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_SaveMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to SAVE....", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	char cSlot[6];
	char cDate[11];
	for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
	{
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			GetDataDate(client, iSlot, cDate, sizeof(cDate));
			Format(menuinfo, sizeof(menuinfo), " Slot %i (%s, %i Props)[%s]", iSlot, cDate, GetDataProps(client, iSlot), GetDataName(client, iSlot));
			menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
			menu.AddItem(cSlot, menuinfo);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_SaveMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (g_iCoolDown[client] == 0)
		{
			SaveData(client, iSlot);
			g_iCoolDown[client] = GetConVarInt(cvg_iCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else Build_PrintToChat(client, "Save Function is currently on cooldown, please wait \x04%i\x01 seconds.", g_iCoolDown[client]);
		
		Command_SaveMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 4. Delete Menu
*******************************************************************************************/
public Action Command_DeleteMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_DeleteMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to DELETE....", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	char cSlot[6], cDate[11];
	for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
	{
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			GetDataDate(client, iSlot, cDate, sizeof(cDate));
			Format(menuinfo, sizeof(menuinfo), " Slot %i (%s, %i Props)[%s]", iSlot, cDate, GetDataProps(client, iSlot), GetDataName(client, iSlot));
			menu.AddItem(cSlot, menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
			menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_DeleteMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		Command_DeleteConfirmMenu(client, iSlot);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 4.1. Delete Confirm (2) Menu
*******************************************************************************************/
public Action Command_DeleteConfirmMenu(int client, int iSlot)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_DeleteConfirmMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \n Are you sure to DELETE slot %i?", PLUGIN_VERSION, g_cCurrentMap, iSlot);
	menu.SetTitle(menuinfo);
	
	char cSlot[8];
	IntToString(iSlot, cSlot, sizeof(cSlot));
	Format(menuinfo, sizeof(menuinfo), " Yes, Delete it.");
	menu.AddItem(cSlot, menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " No, go back!");
	menu.AddItem("NO", menuinfo);
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Handler_DeleteConfirmMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (!StrEqual(info, "NO")) DeleteData(client, StringToInt(info));
		
		Command_DeleteMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_DeleteMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 5. Permission Menu
*******************************************************************************************/
public Action Command_PermissionMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_PermissionMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nSet Permission on project:\n [Private]: Only you can load the project (Default)\n [Public]: Let others to load your project\n ", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	char cSlot[6];
	//char cDate[11];
	char cPermission[8] = "Private";
	for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
	{
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			if (g_bPermission[client][iSlot])
				cPermission = "Public";
			else
				cPermission = "Private";
			
			Format(menuinfo, sizeof(menuinfo), " Slot %i [%s]: [%s]", iSlot, GetDataName(client, iSlot), cPermission);
			menu.AddItem(cSlot, menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data): [Private]", iSlot);
			menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_PermissionMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (g_iCoolDown[client] == 0)
		{
			if (g_bPermission[client][iSlot])
			{
				g_bPermission[client][iSlot] = false;
				Build_PrintToChat(client, "Slot\x04%i\x01's permissions have set to \x04Private\x01.", iSlot);
			}
			else
			{
				g_bPermission[client][iSlot] = true;
				Build_PrintToChat(client, "Slot\x04%i\x01's permission have set to \x04Public\x01.", iSlot);
			}
			
			g_iCoolDown[client] = GetConVarInt(cvg_iCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else Build_PrintToChat(client, "Permission Function is currently on cooldown, please wait \x04%i\x01 seconds.", g_iCoolDown[client]);
		
		Command_PermissionMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 6. LoadOthers Menu
*******************************************************************************************/
public Action Command_LoadOthersMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_LoadOthersMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nLoad others project,\nPlease select a Player:\n ", PLUGIN_VERSION, g_cCurrentMap);
	menu.SetTitle(menuinfo);
	
	char cClient[4];
	char cName[48];
	for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i) && i != client && !IsFakeClient(i))
	{
		IntToString(i, cClient, sizeof(cClient));
		GetClientName(i, cName, sizeof(cName));
		
		Format(menuinfo, sizeof(menuinfo), " %s", cName);
		menu.AddItem(cClient, menuinfo);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_LoadOthersMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iClient = StringToInt(info);
		
		if (IsValidClient(iClient))
		{
			Command_LoadOthersProjectsMenu(client, iClient);
			g_iSelectedClient[client] = iClient;
		}
		else
		{
			Build_PrintToChat(client, "Error: Client %i not found", iClient);
			Command_LoadOthersMenu(client, -1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 6.1. LoadOthersProjects Menu
*******************************************************************************************/
public Action Command_LoadOthersProjectsMenu(int client, int selectedclient) //client, selected client
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_LoadOthersProjectsMenu);
	
	char cSelectedclentName[48];
	if (IsValidClient(selectedclient)) GetClientName(selectedclient, cSelectedclentName, sizeof(cSelectedclentName));
	else
	{
		Build_PrintToChat(client, "Error: Client %i not found", selectedclient);
		Command_LoadOthersMenu(client, -1);
	}
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nSelected Player: %s\n \nSelect a Slot to LOAD....", PLUGIN_VERSION, g_cCurrentMap, cSelectedclentName);
	menu.SetTitle(menuinfo);
	
	char cSlot[6];
	char cPermission[8] = "Private";
	for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
	{
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(selectedclient, iSlot))
		{
			if (g_bPermission[selectedclient][iSlot])
			{
				cPermission = "Public";
				Format(menuinfo, sizeof(menuinfo), " Slot %i [%s]: [%s]", iSlot, GetDataName(selectedclient, iSlot), cPermission);
				menu.AddItem(cSlot, menuinfo);
			}
			else
			{
				cPermission = "Private";
				Format(menuinfo, sizeof(menuinfo), " Slot %i [%s]: [%s]", iSlot, GetDataName(selectedclient, iSlot), cPermission);
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data) : [Private]", iSlot);
			menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_LoadOthersProjectsMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (IsValidClient(g_iSelectedClient[client]))
		{
			if (g_iCoolDown[client] == 0)
			{
				LoadData(client, g_iSelectedClient[client], iSlot);
				
				char cName[48];
				GetClientName(client, cName, sizeof(cName));
				Build_PrintToChat(g_iSelectedClient[client], "Player \x04%s\x01 has loaded Slot\x04%i\x01!", cName, iSlot);
				PrintCenterText(g_iSelectedClient[client], "Player %s has loaded Slot %i!", cName, iSlot);
				g_iCoolDown[client] = GetConVarInt(cvg_iCoolDownsec);
				CreateTimer(0.05, Timer_CoolDownFunction, client);
			}
			else Build_PrintToChat(client, "Load Function is currently on cooldown, please wait \x04%i\x01 seconds.", g_iCoolDown[client]);
		}
		
		Command_LoadOthersProjectsMenu(client, g_iSelectedClient[client]);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_LoadOthersMenu(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	 7. CheckCache Menu
*******************************************************************************************/
public Action Command_CheckCacheMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_CheckCacheMenu);
	
	char cacheStatus[48];
	if (g_hCacheTimer[client] == INVALID_HANDLE)
	{
		cacheStatus = "STOPPED";
	}
	else
	{
		cacheStatus = "RUNNING";
	}
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s\n \nPlugin Author: BattlefieldDuck\nCredits: Danct12, Leadkiller, aIM...\n \nCache System: %s\n ", PLUGIN_VERSION, g_cCurrentMap, cacheStatus);
	menu.SetTitle(menuinfo);
	
	int iSlot = 0;
	char cDate[11], cSlot[6];
	IntToString(iSlot, cSlot, sizeof(cSlot));
	if (DataFileExist(client, iSlot))
	{
		GetDataDate(client, iSlot, cDate, sizeof(cDate));
		Format(menuinfo, sizeof(menuinfo), " Cache (Stored %s, %i Props)", cDate, GetDataProps(client, iSlot));
	}
	else Format(menuinfo, sizeof(menuinfo), " Cache (No Data)");
	
	menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
	
	Format(menuinfo, sizeof(menuinfo), " Load current cache data");
	menu.AddItem("LOAD", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Refresh\n");
	menu.AddItem("REFRESH", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " ---------------------\n!!! Restarting cache system will lost the cache data !!!\n");
	menu.AddItem("", menuinfo, ITEMDRAW_DISABLED);
	
	Format(menuinfo, sizeof(menuinfo), " Restart cache system");
	menu.AddItem("RESTART", menuinfo);
	
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CheckCacheMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual("REFRESH", info)) Command_CheckCacheMenu(client, 0);
		else if (StrEqual("LOAD", info))
		{
			LoadData(client, client, 0);
			
			Command_CheckCacheMenu(client, 0);
		}
		else if (StrEqual("RESTART", info))
		{
			char cFileName[255];
			GetBuildPath(client, 0, cFileName);
			
			if (FileExists(cFileName)) DeleteFile(cFileName); //Delete
			
			Build_PrintToChat(client, "Cache system restarted");
			
			Command_CheckCacheMenu(client, 0);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 8. Cloud Storage Menu
*******************************************************************************************/
public Action Command_CloudMenu(int client, int args)
{
	char ConnectionStatus[32] = "Disconnected";
	if(g_DB != INVALID_HANDLE) //thx https://editor.datatables.net/generator/
	{
		char SteamID[32];
		GetClientSteamID(client, SteamID);
		char createTableQuery[4096];
		Format(createTableQuery, sizeof(createTableQuery), 
			"CREATE TABLE IF NOT EXISTS `%s` ( \
			`id` int(10) NOT NULL auto_increment, \
			`szclass` varchar(255), \
			`szmodel` varchar(255), \
			`forigin0` numeric(15,6), \
			`forigin1` numeric(15,6), \
			`forigin2` numeric(15,6), \
			`fangles0` numeric(9,6), \
			`fangles1` numeric(9,6), \
			`fangles2` numeric(9,6), \
			`icollision` numeric(2,0), \
			`fsize` numeric(9,6), \
			`ired` numeric(3,0), \
			`igreen` numeric(3,0), \
			`iblue` numeric(3,0), \
			`ialpha` numeric(3,0), \
			`irenderfx` numeric(2,0), \
			`iskin` numeric(3,0), \
			`szname` varchar(255), \
			`reserved1` varchar(255), \
			`reserved2` varchar(255), \
			`reserved3` varchar(255), \
			`reserved4` varchar(255), \
			`reserved5` varchar(255), \
			PRIMARY KEY( `id` ));"
		, SteamID);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
		ConnectionStatus = "Connected";
	}
	
	char menuinfo[255];
	Menu menu = new Menu(Handler_CloudMenu);
	
	if(g_SqlRunning) Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Cloud Storage %s \n \nDatabase Connection:\n [ %s ] --- Loading~\n ", PLUGIN_VERSION, ConnectionStatus);
	else Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Cloud Storage %s \n \nDatabase Connection:\n [ %s ]\n ", PLUGIN_VERSION, ConnectionStatus);
	menu.SetTitle(menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), " Refresh");
	if(g_SqlRunning)
	{
		menu.AddItem("REFRESH", menuinfo, ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("REFRESH", menuinfo);
	}
	
	Sql_GetRow(client);
	Format(menuinfo, sizeof(menuinfo), " Storage (%i Props)", g_iCloudRow[client]);
	menu.AddItem("", menuinfo, ITEMDRAW_DISABLED);
	
	if(g_DB == INVALID_HANDLE || g_SqlRunning)
	{
		Format(menuinfo, sizeof(menuinfo), " Load... ");
		menu.AddItem("LOAD", menuinfo, ITEMDRAW_DISABLED);	
		Format(menuinfo, sizeof(menuinfo), " Save... ");
		menu.AddItem("SAVE", menuinfo, ITEMDRAW_DISABLED);		
		Format(menuinfo, sizeof(menuinfo), " Delete... ");
		menu.AddItem("DELETE", menuinfo, ITEMDRAW_DISABLED);
	}
	else
	{
		if(g_iCloudRow[client] > 0)
		{
			Format(menuinfo, sizeof(menuinfo), " Load... ");
			menu.AddItem("LOAD", menuinfo);			
			Format(menuinfo, sizeof(menuinfo), " Save... ");
			menu.AddItem("SAVE", menuinfo, ITEMDRAW_DISABLED);		
			Format(menuinfo, sizeof(menuinfo), " Delete... ");
			menu.AddItem("DELETE", menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Load... ");
			menu.AddItem("LOAD", menuinfo, ITEMDRAW_DISABLED);			
			Format(menuinfo, sizeof(menuinfo), " Save... ");
			menu.AddItem("SAVE", menuinfo);	
			Format(menuinfo, sizeof(menuinfo), " Delete... ");
			menu.AddItem("DELETE", menuinfo, ITEMDRAW_DISABLED);
		}
	}
	
	if(g_SqlRunning) menu.ExitBackButton = false;
	else menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CloudMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		Sql_GetRow(client);
		if (StrEqual("REFRESH", info))
		{
			Handle dp;
			CreateDataTimer(0.1, Timer_SqlRunning, dp);
			WritePackCell(dp, client);
			WritePackCell(dp, 0);
			WritePackCell(dp, 10);
			g_SqlRunning = true;
		}
		else if(StrEqual("LOAD", info) && !g_SqlRunning)
		{
			Sql_LoadData(client);
			Handle dp;
			CreateDataTimer(0.1, Timer_SqlRunning, dp);
			WritePackCell(dp, client);
			WritePackCell(dp, 0);
			WritePackCell(dp, 20);
			g_SqlRunning = true;
		}
		else if(StrEqual("SAVE", info) && !g_SqlRunning)
		{
			int iCount = 0;
			char szClass[64];
			for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)if (IsValidEdict(i))
			{
				GetEdictClassname(i, szClass, sizeof(szClass));
				if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll") && Build_ReturnEntityOwner(i) == client)
				{
					iCount++;
				}
			}
			
			Sql_SaveData(client);
			Handle dp;
			CreateDataTimer(0.1, Timer_SqlRunning, dp);
			WritePackCell(dp, client);
			WritePackCell(dp, iCount);
			WritePackCell(dp, -1);
			g_SqlRunning = true;
		}
		else if(StrEqual("DELETE", info) && !g_SqlRunning)
		{
			Sql_DeleteData(client);
			Handle dp;
			CreateDataTimer(0.1, Timer_SqlRunning, dp);
			WritePackCell(dp, client);
			WritePackCell(dp, 0);
			WritePackCell(dp, -1);
			g_SqlRunning = true;
		}
		
		Command_CloudMenu(client, 0);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}


/*******************************************************************************************
	 Stock
*******************************************************************************************/
//-----------[ Load data Function ]--------------------------------------------------------------------------------------
void LoadData(int loader, int client, int slot) // Load Data from data file (loader, client in data file, slot number)
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (FileExists(cFileName)) LoadFunction(loader, slot, cFileName);
}

void LoadDataSteamID(int loader, char[] SteamID64, int slot) // Load Data from data file (loader, client steamid64 in data file, slot number) //Special!! X Cache
{
	char cFileName[255];
	BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", g_cCurrentMap, SteamID64, slot);
	
	if (FileExists(cFileName)) LoadFunction(loader, slot, cFileName);
}

void LoadFunction(int loader, int slot, char cFileName[255])
{
	if (GetConVarInt(cviLoadMode) == 2)
	{
		Handle dp;
		CreateDataTimer(0.05, Timer_LoadProps, dp);
		WritePackCell(dp, loader);
		WritePackCell(dp, slot);
		WritePackString(dp, cFileName);
		WritePackCell(dp, 0);
		WritePackCell(dp, 0);
		WritePackCell(dp, 0);
	}
	else if (GetConVarInt(cviLoadMode) == 1)
	{
		if (FileExists(cFileName))
		{
			g_hFileEditting[loader] = OpenFile(cFileName, "r");
			if (g_hFileEditting[loader] != INVALID_HANDLE)
			{
				int g_iCountEntity = 0;
				int g_iCountLoop = 0;
				char szLoadString[255];
				
				while(ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString)))
				{
					if (StrContains(szLoadString, "ent") != -1 && StrContains(szLoadString, ";") == -1) //Map name have ent sytax??? Holy
					{
						if (LoadProps(loader, szLoadString)) g_iCountEntity++;
						g_iCountLoop++;
					}
					
					if (IsEndOfFile(g_hFileEditting[loader])) break;
				}
				CloseHandle(g_hFileEditting[loader]);
				
				if (slot == 0)
				{
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Cache Loaded", g_iCountEntity, g_iCountLoop - g_iCountEntity);
					
					DeleteFile(cFileName);
					
					if (g_hCacheTimer[loader] == INVALID_HANDLE)
					{
						g_hCacheTimer[loader] = CreateTimer(5.0, Timer_Save, loader, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					}
				}
				else Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Loaded Slot\x04%i\x01", g_iCountEntity, g_iCountLoop - g_iCountEntity, slot);
			}
		}
	}
}

public Action Timer_LoadProps(Handle timer, Handle dp)
{
	ResetPack(dp);
	int loader = ReadPackCell(dp);
	int slot = ReadPackCell(dp);
	char cFileName[255];
	ReadPackString(dp, cFileName, sizeof(cFileName));
	int Fileline = ReadPackCell(dp);
	int g_iCountEntity = ReadPackCell(dp);
	int g_iCountLoop = ReadPackCell(dp);
	
	if (FileExists(cFileName))
	{
		g_hFileEditting[loader] = OpenFile(cFileName, "r");
		if (g_hFileEditting[loader] != INVALID_HANDLE)
		{
			char szLoadString[255];
			
			for (int i = 0; i < Fileline; i++)
			ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString));
			
			for (int i = 0; i < GetConVarInt(cviLoadProps); i++) if (ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString)))
			{
				Fileline++;
				if (StrContains(szLoadString, "ent") != -1 && StrContains(szLoadString, "models/") != -1 && StrContains(szLoadString, "prop_") != -1)// && StrContains(szLoadString, ";") == -1) //Map name have ent sytax??? Holy
				{
					if (LoadProps(loader, szLoadString)) g_iCountEntity++;
					g_iCountLoop++;
				}
				if (IsEndOfFile(g_hFileEditting[loader])) break;
			}
			if (IsEndOfFile(g_hFileEditting[loader]))
			{
				if (slot == 0)
				{
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Cache Loaded", g_iCountEntity, g_iCountLoop - g_iCountEntity);
					
					CloseHandle(g_hFileEditting[loader]);
					
					DeleteFile(cFileName);
					
					if (g_hCacheTimer[loader] == INVALID_HANDLE)
					{
						g_hCacheTimer[loader] = CreateTimer(5.0, Timer_Save, loader, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					}
					
					return;
				}
				else Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Loaded Slot\x04%i\x01", g_iCountEntity, g_iCountLoop - g_iCountEntity, slot);
			}
			else
			{
				CreateDataTimer(GetConVarFloat(cviLoadSec), Timer_LoadProps, dp);
				WritePackCell(dp, loader);
				WritePackCell(dp, slot);
				WritePackString(dp, cFileName);
				WritePackCell(dp, Fileline);
				WritePackCell(dp, g_iCountEntity);
				WritePackCell(dp, g_iCountLoop);
			}
			CloseHandle(g_hFileEditting[loader]);
		}
	}
}

bool LoadProps(int loader, char[] szLoadString)
{
	float fOrigin[3], fAngles[3], fSize, flPlaybackRate;
	char szModel[128], szClass[64], szFormatStr[255], DoorIndex[5], szBuffer[30][255], szName[255];
	int Obj_LoadEntity, iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iRandom, iSkin, iSequence, iPhysProp;
	RenderFx FxRender = RENDERFX_NONE;
	
	ExplodeString(szLoadString, " ", szBuffer, 30, 255);
	Format(szClass, sizeof(szClass), "%s", szBuffer[1]);
	Format(szModel, sizeof(szModel), "%s", szBuffer[2]);
	fOrigin[0] = StringToFloat(szBuffer[3]);
	fOrigin[1] = StringToFloat(szBuffer[4]);
	fOrigin[2] = StringToFloat(szBuffer[5]);
	fAngles[0] = StringToFloat(szBuffer[6]);
	fAngles[1] = StringToFloat(szBuffer[7]);
	fAngles[2] = StringToFloat(szBuffer[8]);
	iCollision = StringToInt(szBuffer[9]);
	fSize = StringToFloat(szBuffer[10]);
	iRed = StringToInt(szBuffer[11]);
	iGreen = StringToInt(szBuffer[12]);
	iBlue = StringToInt(szBuffer[13]);
	iAlpha = StringToInt(szBuffer[14]);
	iRenderFx = StringToInt(szBuffer[15]);
	iSkin = StringToInt(szBuffer[16]);
	iPhysProp = StringToInt(szBuffer[21]);

	int iNameStart = 18;
	if (IsCharNumeric(szBuffer[17][0]))
	{
		iSequence = StringToInt(szBuffer[17]);
		flPlaybackRate = StringToFloat(szBuffer[18]);
		Format(szName, sizeof(szName), "%s", szBuffer[19]);
		
		iNameStart = 20;
	}
	else
	{
		iSequence = 0;
		flPlaybackRate = 0.0;
		Format(szName, sizeof(szName), "%s", szBuffer[17]);
	}
	
	for (int i = iNameStart; i < 30; i++)
	{
		if (!StrEqual(szBuffer[i], ""))
		{
			Format(szName, sizeof(szName), "%s %s", szName, szBuffer[i]);
		}
		else
		{
			break;
		}
	}
	
	TrimString(szName);
	
	if (strlen(szBuffer[9]) == 0)
		iCollision = 5;
	if (strlen(szBuffer[10]) == 0)
		fSize = 1.0;
	if (strlen(szBuffer[11]) == 0)
		iRed = 255;
	if (strlen(szBuffer[12]) == 0)
		iGreen = 255;
	if (strlen(szBuffer[13]) == 0)
		iBlue = 255;
	if (strlen(szBuffer[14]) == 0)
		iAlpha = 255;
	if (strlen(szBuffer[15]) == 0)
		iRenderFx = 1;
	if (strlen(szBuffer[16]) == 0)
		iSkin = 0;
	if (strlen(szBuffer[17]) == 0)
		iSequence = 0;
	if (strlen(szBuffer[18]) == 0)
		flPlaybackRate = 0.0;
	if (strlen(szBuffer[19]) == 0)
		szName = "";
	if (strlen(szBuffer[21]) == 0)
		iPhysProp = 0;
	
	if (StrContains(szClass, "prop_dynamic") >= 0)
	{
		Obj_LoadEntity = CreateEntityByName("prop_dynamic_override");
		SetEntProp(Obj_LoadEntity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(Obj_LoadEntity, Prop_Data, "m_nSolidType", 6);
	}
	else if (StrEqual(szClass, "prop_physics")) Obj_LoadEntity = CreateEntityByName("prop_physics_override");
	else if (StrContains(szClass, "prop_physics") >= 0) Obj_LoadEntity = CreateEntityByName(szClass);
	
	if (Obj_LoadEntity > MaxClients && IsValidEntity(Obj_LoadEntity))
	{
		if (Build_RegisterEntityOwner(Obj_LoadEntity, loader))
		{
			if (!IsModelPrecached(szModel)) PrecacheModel(szModel);
			
			DispatchKeyValue(Obj_LoadEntity, "model", szModel);
			TeleportEntity(Obj_LoadEntity, fOrigin, fAngles, NULL_VECTOR);
			DispatchSpawn(Obj_LoadEntity);
			
			SetEntProp(Obj_LoadEntity, Prop_Data, "m_CollisionGroup", iCollision);
			SetEntPropFloat(Obj_LoadEntity, Prop_Send, "m_flModelScale", fSize);
			if(iAlpha < 255) SetEntityRenderMode(Obj_LoadEntity, RENDER_TRANSCOLOR);
			else SetEntityRenderMode(Obj_LoadEntity, RENDER_NORMAL);
			SetEntityRenderColor(Obj_LoadEntity, iRed, iGreen, iBlue, iAlpha);

			switch (iRenderFx)
			{
				case 1:FxRender = RENDERFX_NONE;
				case 2:FxRender = RENDERFX_PULSE_SLOW;
				case 3:FxRender = RENDERFX_PULSE_FAST;
				case 4:FxRender = RENDERFX_PULSE_SLOW_WIDE;
				case 5:FxRender = RENDERFX_PULSE_FAST_WIDE;
				case 6:FxRender = RENDERFX_FADE_SLOW;
				case 7:FxRender = RENDERFX_FADE_FAST;
				case 8:FxRender = RENDERFX_SOLID_SLOW;
				case 9:FxRender = RENDERFX_SOLID_FAST;
				case 10:FxRender = RENDERFX_STROBE_SLOW;
				case 11:FxRender = RENDERFX_STROBE_FAST;
				case 12:FxRender = RENDERFX_STROBE_FASTER;
				case 13:FxRender = RENDERFX_FLICKER_SLOW;
				case 14:FxRender = RENDERFX_FLICKER_FAST;
				case 15:FxRender = RENDERFX_NO_DISSIPATION;
				case 16:FxRender = RENDERFX_DISTORT;
				case 17:FxRender = RENDERFX_HOLOGRAM;
			}
			SetEntityRenderFx(Obj_LoadEntity, FxRender);
			SetEntProp(Obj_LoadEntity, Prop_Send, "m_nSkin", iSkin);
			
			SetEntProp(Obj_LoadEntity, Prop_Send, "m_nSequence", iSequence);
			
			SetEntPropFloat(Obj_LoadEntity, Prop_Send, "m_flPlaybackRate", flPlaybackRate);
			
			ReplaceString(szName, sizeof(szName), "\n", "", false);
			SetEntPropString(Obj_LoadEntity, Prop_Data, "m_iName", szName);
			
			//light bulb
			if (StrEqual(szModel, "models/props_2fort/lightbulb001.mdl"))
			{
				int Obj_LightDynamic = CreateEntityByName("light_dynamic");

				SetVariantString("500");
				AcceptEntityInput(Obj_LightDynamic, "distance", -1);
				
				if (iSkin > 7) iSkin = 7;
				char szBrightness[2];
				IntToString(iSkin, szBrightness, sizeof(szBrightness));
				SetVariantString(szBrightness);
				AcceptEntityInput(Obj_LightDynamic, "brightness", -1);
				
				SetVariantString("2");
				AcceptEntityInput(Obj_LightDynamic, "style", -1);
				
				char szColor[32];
				Format(szColor, sizeof(szColor), "%i %i %i", iRed, iGreen, iBlue);
				SetVariantString(szColor);
				AcceptEntityInput(Obj_LightDynamic, "color", -1);
				
				if (Obj_LightDynamic != -1)
				{
					DispatchSpawn(Obj_LightDynamic);
					TeleportEntity(Obj_LightDynamic, fOrigin, fAngles, NULL_VECTOR);
					
					if (strlen(szBuffer[17]) == 0)
					{
						char szNameMelon[64];
						Format(szNameMelon, sizeof(szNameMelon), "Obj_LoadEntity%i", GetRandomInt(1000, 5000));
						DispatchKeyValue(Obj_LoadEntity, "targetname", szNameMelon);
						SetVariantString(szNameMelon);
					}
					else 
					{
						DispatchKeyValue(Obj_LoadEntity, "targetname", szName);
						SetVariantString(szName);
					}
					
					AcceptEntityInput(Obj_LightDynamic, "setparent", -1);
					AcceptEntityInput(Obj_LightDynamic, "turnon", loader, loader);
				}
			}
			
			//door
			if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl") && StrContains(szName, "door") == -1 && StrContains(szName, "Blastdoor") != -1)
			{
				if (strlen(szBuffer[17]) == 0)
				{
					iRandom = GetRandomInt(1000, 5000);
					IntToString(iRandom, DoorIndex, sizeof(DoorIndex));
					Format(szFormatStr, sizeof(szFormatStr), "door%s", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "targetname", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,dog_open,0", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "door%s,DisableCollision,,1", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,close,5", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "door%s,EnableCollision,,5.1", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
				}
				else
				{
					SetEntPropString(Obj_LoadEntity, Prop_Data, "m_iName", szName);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,dog_open,0", szName);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,DisableCollision,,1", szName);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,5", szName);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,EnableCollision,,5.1", szName);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
				}				
			}
			else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl"))
			{
				if (strlen(szBuffer[17]) == 0)
				{
					iRandom = GetRandomInt(1000, 5000);
					IntToString(iRandom, DoorIndex, sizeof(DoorIndex));
					Format(szFormatStr, sizeof(szFormatStr), "door%s", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "targetname", szFormatStr);
					
					Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,RavenDoor_Open,0", DoorIndex);	
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,RavenDoor_Drop,7", DoorIndex);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
				}
				else
				{
					SetEntPropString(Obj_LoadEntity, Prop_Data, "m_iName", szName);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Open,0", szName);	
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Drop,7", szName);
					DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
				}
			}
			else if (StrEqual(szModel, "models/combine_gate_citizen.mdl") 
			|| StrEqual(szModel, "models/combine_gate_Vehicle.mdl")
			|| StrEqual(szModel, "models/props_doors/doorKLab01.mdl")
			|| StrEqual(szModel, "models/props_lab/elevatordoor.mdl"))
			{
				iRandom = GetRandomInt(1000, 5000);
				IntToString(iRandom, DoorIndex, sizeof(DoorIndex));
				Format(szFormatStr, sizeof(szFormatStr), "door%s", DoorIndex);
				DispatchKeyValue(Obj_LoadEntity, "targetname", szFormatStr);
				
				Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", DoorIndex);
				DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
				Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", DoorIndex);
				DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
			}

			if(iPhysProp)
			{
				Phys_EnableCollisions(Obj_LoadEntity, true);
				Phys_EnableGravity(Obj_LoadEntity, true);
				Phys_EnableDrag(Obj_LoadEntity, true);
				Phys_EnableMotion(Obj_LoadEntity, true);
			}	
			return true;
		}
		else RemoveEdict(Obj_LoadEntity);
	}
	
	return false;
}

//-----------[ Save data Function ]-------------------------------------
void SaveData(int client, int slot) // Save Data from data file (CLIENT INDEX, SLOT ( 0 = cache, 1 >= save))
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	int g_iCountEntity = -1;
	//----------------------------------------------------Open file and start write-----------------------------------------------------------------
	g_hFileEditting[client] = OpenFile(cFileName, "w");
	if (g_hFileEditting[client] != INVALID_HANDLE)
	{
		g_iCountEntity = 0;
		
		float fOrigin[3], fAngles[3], fSize, flPlaybackRate;
		char szModel[128], szTime[64], szClass[64], szName[128];
		int iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, iSequence, iPhysProp;
		RenderFx EntityRenderFx;
		
		FormatTime(szTime, sizeof(szTime), "%Y/%m/%d");
		WriteFileLine(g_hFileEditting[client], ";- Saved Map: %s", g_cCurrentMap);
		WriteFileLine(g_hFileEditting[client], ";- SteamID64: %s (%N)", SteamID64, client);
		WriteFileLine(g_hFileEditting[client], ";- Data Slot: %i", slot);
		WriteFileLine(g_hFileEditting[client], ";- Saved on : %s", szTime);
		WriteFileLine(g_hFileEditting[client], ";- FileName : No Name");
		for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++) if (IsValidEdict(i))
		{
			GetEdictClassname(i, szClass, sizeof(szClass));
			if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll") && Build_ReturnEntityOwner(i) == client)
			{
				GetEntPropString(i, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOrigin);
				GetEntPropVector(i, Prop_Data, "m_angRotation", fAngles);
				iCollision = GetEntProp(i, Prop_Data, "m_CollisionGroup", 4);
				fSize = GetEntPropFloat(i, Prop_Send, "m_flModelScale");
				GetEntityRenderColor(i, iRed, iGreen, iBlue, iAlpha);
				EntityRenderFx = GetEntityRenderFx(i);
				switch(EntityRenderFx)
				{
					case(RENDERFX_PULSE_SLOW): 			iRenderFx = 2;
					case(RENDERFX_PULSE_FAST): 			iRenderFx = 3;
					case(RENDERFX_PULSE_SLOW_WIDE): 	iRenderFx = 4;
					case(RENDERFX_PULSE_FAST_WIDE): 	iRenderFx = 5;
					case(RENDERFX_FADE_SLOW): 			iRenderFx = 6;
					case(RENDERFX_FADE_FAST):			iRenderFx = 7;
					case(RENDERFX_SOLID_SLOW): 			iRenderFx = 8;
					case(RENDERFX_SOLID_FAST): 			iRenderFx = 9;
					case(RENDERFX_STROBE_SLOW):		 	iRenderFx = 10;
					case(RENDERFX_STROBE_FAST): 		iRenderFx = 11;
					case(RENDERFX_STROBE_FASTER): 		iRenderFx = 12;
					case(RENDERFX_FLICKER_SLOW): 		iRenderFx = 13;
					case(RENDERFX_FLICKER_FAST): 		iRenderFx = 14;
					case(RENDERFX_NO_DISSIPATION): 		iRenderFx = 15;
					case(RENDERFX_DISTORT): 			iRenderFx = 16;
					case(RENDERFX_HOLOGRAM): 			iRenderFx = 17;
					default:	iRenderFx = 1;
				}
								
				iSkin = GetEntProp(i, Prop_Send, "m_nSkin");
				
				iSequence = GetEntProp(i, Prop_Send, "m_nSequence");
				
				flPlaybackRate = GetEntPropFloat(i, Prop_Send, "m_flPlaybackRate");
				
				GetEntPropString(i, Prop_Data, "m_iName", szName, sizeof(szName));

				iPhysProp = Phys_IsGravityEnabled(i);
				
				WriteFileLine(g_hFileEditting[client], "ent%i %s %s %f %f %f %f %f %f %i %f %i %i %i %i %i %i %i %f %s %i"
				, g_iCountEntity, szClass, szModel, fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], iCollision, fSize, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, iSequence, flPlaybackRate, szName, iPhysProp);
				
				g_iCountEntity++;
			}
		}
		WriteFileLine(g_hFileEditting[client], ";- Data File End | %i Props Saved", g_iCountEntity);
		WriteFileLine(g_hFileEditting[client], ";- File:TF2Sandbox-SaveSystem.smx");
		
		FlushFile(g_hFileEditting[client]);
		//-------------------------------------------------------------Close file-------------------------------------------------------------------
		CloseHandle(g_hFileEditting[client]);
		
		if (FileExists(cFileName) && g_iCountEntity == 0)
		{
			if (slot != 0) Build_PrintToChat(client, "Save Result >> ERROR!!! >> You didn't build anything! Please build something and save again.");
			
			DeleteFile(cFileName);
		}
		else if (slot != 0) Build_PrintToChat(client, "Save Result >> Saved: \x04%i\x01, Error:\x04 0\x01 >> Saved in Slot\x04%i\x01", g_iCountEntity, slot);
	}
	if (g_iCountEntity == -1)
	{
		if (slot == 0) Build_PrintToChat(client, "Cache Result >> ERROR!!! >> Please contact a server admin.");
		else Build_PrintToChat(client, "Save Result >> ERROR!!! >> Error in Slot\x04%i\x01, please contact a server admin.", slot);
	}
}

//-----------[ Delete data Function ]-----------------------------------
void DeleteData(int client, int slot) // Delete Data from data file
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (DataFileExist(client, slot))
	{
		DeleteFile(cFileName);
		
		if (DataFileExist(client, slot)) Build_PrintToChat(client, "Fail to deleted Slot\x04%i\x01 Data, please contact a server admin.", slot);
		else Build_PrintToChat(client, "Deleted Slot\x04%i\x01 Data successfully", slot);
	}
}

//-----------[ Set name Function ]--------------------------------------
void SetDataName(int client, int slot, char[] name)
{
	if (DataFileExist(client, slot))
	{
		bool bSetName = false;
		
		char cOldFileName[255];
		GetBuildPath(client, slot, cOldFileName);
		Handle hOriginal = OpenFile(cOldFileName, "r");
		
		char cFileName[255];
		cFileName = cOldFileName;
		ReplaceString(cFileName, sizeof(cFileName), ".tf2sb", "-copy.tf2sb");
		Handle hNewFile = OpenFile(cFileName, "w");
		
		if (hOriginal != INVALID_HANDLE && hNewFile != INVALID_HANDLE)
		{
			char szLoadString[511];
			while (ReadFileLine(hOriginal, szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, ";- FileName : ") != -1 && !bSetName)
				{
					WriteFileLine(hNewFile, ";- FileName : %s", name);
					
					bSetName = true;
				}
				else
				{
					if (StrContains(szLoadString, ";- ") == -1 && !bSetName)
					{
						WriteFileLine(hNewFile, ";- FileName : %s", name);
					
						bSetName = true;
					}
					
					ReplaceString(szLoadString, sizeof(szLoadString), "\n", "");
					WriteFileLine(hNewFile, szLoadString);
				}
			}
			
			CloseHandle(hOriginal);
			CloseHandle(hNewFile);
			
			DeleteFile(cOldFileName);
			RenameFile(cOldFileName, cFileName);
		}
	}
}

//-----------[ Get data Function ]----------------------------------------------------------------------------------
char[] GetDataName(int client, int slot)
{
	char cName[255];
	cName = "No Name";
	
	if (DataFileExist(client, slot))
	{
		char cFileName[255];
		GetBuildPath(client, slot, cFileName);
		
		g_hFileEditting[client] = OpenFile(cFileName, "r");
		if (g_hFileEditting[client] != INVALID_HANDLE)
		{
			char szBuffer[6][255], szLoadString[255];
			while (ReadFileLine(g_hFileEditting[client], szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, ";- FileName :") != -1)
				{
					ExplodeString(szLoadString, " ", szBuffer, 6, 255);
					Format(cName, sizeof(cName), "%s %s %s", szBuffer[3], szBuffer[4], szBuffer[5]);
					TrimString(cName);
					
					break;
				}
			}
			
			CloseHandle(g_hFileEditting[client]);
		}
	}
	
	return cName;
}

void GetDataDate(int client, int slot, char[] data, int maxlength) //Get the date inside the data file
{
	if (DataFileExist(client, slot))
	{
		char cFileName[255];
		GetBuildPath(client, slot, cFileName);
		
		g_hFileEditting[client] = OpenFile(cFileName, "r");
		if (g_hFileEditting[client] != INVALID_HANDLE)
		{
			char cDate[11], szBuffer[6][255];
			char szLoadString[255];
			while (ReadFileLine(g_hFileEditting[client], szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, "Saved on :") != -1)
				{
					ExplodeString(szLoadString, " ", szBuffer, 6, 255);
					Format(cDate, sizeof(cDate), "%s", szBuffer[4]);
					strcopy(data, maxlength, cDate);
					break;
				}
			}
			
			CloseHandle(g_hFileEditting[client]);
		}
	}
}

int GetDataProps(int client, int slot) //Get how many props inside data file
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (DataFileExist(client, slot))
	{
		g_hFileEditting[client] = OpenFile(cFileName, "r");
		if (g_hFileEditting[client] != INVALID_HANDLE)
		{
			int iProps;
			char szBuffer[9][255];
			char szLoadString[255];
			while (ReadFileLine(g_hFileEditting[client], szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, "Data File End |") != -1)
				{
					ExplodeString(szLoadString, " ", szBuffer, 9, 255);
					iProps = StringToInt(szBuffer[5]);
					break;
				}
			}
			
			CloseHandle(g_hFileEditting[client]);
			return iProps;
		}
	}
	
	return -1;
}

void GetBuildPath(int client, int slot, char[] cFileNameout) //Get the sourcemod Build path
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	
	char cFileName[255];
	if (slot == 0) BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBCache/%s&%s.tf2sb", g_cCurrentMap, SteamID64);
	else BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", g_cCurrentMap, SteamID64, slot);
	
	strcopy(cFileNameout, sizeof(cFileName), cFileName);
}

void GetClientSteamID(int client, char[] SteamID64out)
{
	char SteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64), true);
	
	strcopy(SteamID64out, sizeof(SteamID64), SteamID64);
}

//-----------[ Check Function ]--------------------------------------------------------
bool DataFileExist(int client, int slot) //Is the data file exist? true : false 
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (FileExists(cFileName)) return true;
	
	return false;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

int GetClientInGame()
{
	int iCount = 0;
	for (int i = 1; i < MAXPLAYERS; i++) if (IsValidClient(i) && !IsFakeClient(i)) iCount++;
	
	return iCount;
}

void TagsCheck(const char[] tag) //TF2Stat.sp
{
	Handle hTags = FindConVar("sv_tags");
	char tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (!(StrContains(tags, tag, false)>-1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	
	CloseHandle(hTags);
}
//------------[ Cloud ]------------------------------------------------------------------
public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) 
{
	if (!StrEqual(error, "")) LogError(error);
}

//GetRow (How many props)----------
public void Sql_GetRow(int client)
{
	if(g_DB != INVALID_HANDLE)
	{
		char SteamID[18];
		GetClientSteamID(client, SteamID);
		char GetRowQuery[1024];
		Format(GetRowQuery, sizeof(GetRowQuery), "SELECT * FROM `%s`;", SteamID);
		SQL_TQuery(g_DB, SQLGetRowQuery, GetRowQuery, client);
	}
}

public void SQLGetRowQuery(Handle owner, Handle hndl, const char[] error, any data) 
{
	g_iCloudRow[data] = SQL_GetRowCount(hndl);
}
//--------------------------------

//Sql_LoadData--------------------
public void Sql_LoadData(int client)
{
	if(g_DB != INVALID_HANDLE)
	{
		char SteamID[18];
		GetClientSteamID(client, SteamID);
		char GetData[1024];
		for (int i = 1; i <= g_iCloudRow[client]; i++)
		{
			Format(GetData, sizeof(GetData), "SELECT * FROM `%s` WHERE id = '%i';", SteamID, i);
			SQL_TQuery(g_DB, SQLLoadQuery, GetData, client);
		}
	}
}

public void SQLLoadQuery(Handle owner, Handle hndl, const char[] error, any data) 
{
	float fOrigin[3], fAngles[3], fSize, flPlaybackRate;
	char szModel[128], szClass[64], szName[128], strSequence[10], strPlaybackRate[10];
	int iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, iSequence;
	char szLoadString[1024];
	while (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 1, szClass, sizeof(szClass));
		SQL_FetchString(hndl, 2, szModel, sizeof(szModel));
		fOrigin[0] = SQL_FetchFloat(hndl, 3);
		fOrigin[1] = SQL_FetchFloat(hndl, 4);
		fOrigin[2] = SQL_FetchFloat(hndl, 5);
		fAngles[0] = SQL_FetchFloat(hndl, 6);
		fAngles[1] = SQL_FetchFloat(hndl, 7);
		fAngles[2] = SQL_FetchFloat(hndl, 8);
		iCollision = SQL_FetchInt(hndl, 9);
		fSize = SQL_FetchFloat(hndl, 10);
		iRed = SQL_FetchInt(hndl, 11);
		iGreen = SQL_FetchInt(hndl, 12);
		iBlue = SQL_FetchInt(hndl, 13);
		iAlpha = SQL_FetchInt(hndl, 14);
		iRenderFx = SQL_FetchInt(hndl, 15);
		iSkin = SQL_FetchInt(hndl, 16);
		SQL_FetchString(hndl, 17, szName, sizeof(szName));
		
		SQL_FetchString(hndl, 18, strSequence, sizeof(strSequence));
		iSequence = StringToInt(strSequence);
		SQL_FetchString(hndl, 19, strPlaybackRate, sizeof(strPlaybackRate));
		flPlaybackRate = StringToFloat(strPlaybackRate);
	}
	
	Format(szLoadString, sizeof(szLoadString), "ent %s %s %f %f %f %f %f %f %i %f %i %i %i %i %i %i %i %f %s"
	, szClass, szModel, fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], iCollision, fSize, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, iSequence, flPlaybackRate, szName);
	
	LoadProps(data, szLoadString);
}
//--------------------------------

//Sql_SaveData--------------------
public void Sql_SaveData(int client)
{
	if(g_DB != INVALID_HANDLE)
	{
		char SteamID[18];
		GetClientSteamID(client, SteamID);
		char GetData[1024];
		float fOrigin[3], fAngles[3], fSize, flPlaybackRate;
		char szModel[128], szClass[64], szName[128];
		int iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, iSequence;
		RenderFx EntityRenderFx;
		for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)if (IsValidEdict(i))
		{
			GetEdictClassname(i, szClass, sizeof(szClass));
			if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll") && Build_ReturnEntityOwner(i) == client)
			{
				GetEntPropString(i, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOrigin);
				GetEntPropVector(i, Prop_Data, "m_angRotation", fAngles);
				iCollision = GetEntProp(i, Prop_Data, "m_CollisionGroup", 4);
				fSize = GetEntPropFloat(i, Prop_Send, "m_flModelScale");
				GetEntityRenderColor(i, iRed, iGreen, iBlue, iAlpha);
				EntityRenderFx = GetEntityRenderFx(i);
				switch(EntityRenderFx)
				{
					case(RENDERFX_PULSE_SLOW): 			iRenderFx = 2;
					case(RENDERFX_PULSE_FAST): 			iRenderFx = 3;
					case(RENDERFX_PULSE_SLOW_WIDE): 	iRenderFx = 4;
					case(RENDERFX_PULSE_FAST_WIDE): 	iRenderFx = 5;
					case(RENDERFX_FADE_SLOW): 			iRenderFx = 6;
					case(RENDERFX_FADE_FAST):			iRenderFx = 7;
					case(RENDERFX_SOLID_SLOW): 			iRenderFx = 8;
					case(RENDERFX_SOLID_FAST): 			iRenderFx = 9;
					case(RENDERFX_STROBE_SLOW):		 	iRenderFx = 10;
					case(RENDERFX_STROBE_FAST): 		iRenderFx = 11;
					case(RENDERFX_STROBE_FASTER): 		iRenderFx = 12;
					case(RENDERFX_FLICKER_SLOW): 		iRenderFx = 13;
					case(RENDERFX_FLICKER_FAST): 		iRenderFx = 14;
					case(RENDERFX_NO_DISSIPATION): 		iRenderFx = 15;
					case(RENDERFX_DISTORT): 			iRenderFx = 16;
					case(RENDERFX_HOLOGRAM): 			iRenderFx = 17;
					default:	iRenderFx = 1;
				}				
				iSkin = GetEntProp(i, Prop_Send, "m_nSkin");
				
				iSequence = GetEntProp(i, Prop_Send, "m_nSequence");
				char strSequence[10];
				IntToString(iSequence, strSequence, sizeof(strSequence));
				
				flPlaybackRate = GetEntPropFloat(i, Prop_Send, "m_flPlaybackRate");
				char strPlaybackRate[10];
				FloatToString(flPlaybackRate, strPlaybackRate, sizeof(strPlaybackRate));
				
				GetEntPropString(i, Prop_Data, "m_iName", szName, sizeof(szName));
				
				Format(GetData, sizeof(GetData), "INSERT IGNORE INTO `%s` (`id`, `szclass`, `szmodel`, `forigin0`, `forigin1`, `forigin2`, `fangles0`, `fangles1`, `fangles2`, `icollision`, `fsize`, `ired`, `igreen`, `iblue`, `ialpha`, `irenderfx`, `iskin`, `szname`, `reserved1`, `reserved2`, `reserved3`, `reserved4`, `reserved5`) VALUES (NULL, '%s', '%s', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%f', '%i', '%i', '%i', '%i', '%i', '%i', '%s', '%s', '%s', '%s', '%s', '%s');"
				, SteamID, szClass, szModel, fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], iCollision, fSize, iRed, iGreen, iBlue, iAlpha, iRenderFx, iSkin, szName, strSequence, strPlaybackRate, "", "","");
				SQL_TQuery(g_DB, SQLErrorCheckCallback, GetData, client);
			}
		}
	}
}
//--------------------------------

//Sql_DeleteData--------------------
bool Sql_DeleteData(int client)
{
	if(g_DB != INVALID_HANDLE)
	{
		char SteamID[18];
		GetClientSteamID(client, SteamID);
		char GetRowQuery[1024];
		Format(GetRowQuery, sizeof(GetRowQuery), "DROP TABLE `%s`;", SteamID);
		SQL_TQuery(g_DB, SQLGetRowQuery, GetRowQuery, client);
	}
}
//--------------------------------

//Check the data is changed or not, if not, wait
public Action Timer_SqlRunning(Handle timer, Handle dp)
{
	ResetPack(dp);
	int client = ReadPackCell(dp);
	int iCount = ReadPackCell(dp);
	int iType = ReadPackCell(dp);
	
	if(!IsValidClient(client)) return;
	if(g_iCloudRow[client] >= iCount && iType == -1)
	{
		g_SqlRunning = false;
		Command_CloudMenu(client, 0);
	}
	else if(iType == -1)
	{
		CreateDataTimer(0.1, Timer_SqlRunning, dp);
		WritePackCell(dp, client);
		WritePackCell(dp, iCount);
		WritePackCell(dp, iType);
	}
	else if(iType > 0)
	{
		iType--;
		CreateDataTimer(0.1, Timer_SqlRunning, dp);
		WritePackCell(dp, client);
		WritePackCell(dp, iCount);
		WritePackCell(dp, iType);
	}
	else 
	{
		g_SqlRunning = false;
		Command_CloudMenu(client, 0);
	}
}
