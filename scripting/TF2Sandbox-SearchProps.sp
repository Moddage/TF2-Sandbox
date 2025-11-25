#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck, Maintained by Yuuki"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Search Props", 
	author = PLUGIN_AUTHOR, 
	description = "Search System for TF2SandBox", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hPropMenu[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_sbs", Command_Search, 0, "Open SearchProps menu");
	RegAdminCmd("sm_sbsearch", Command_Search, 0, "Open SearchProps menu");
}

public Action Command_Search(int client, int args)
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		if(args == 1)
		{
			char cTarget[64];
			GetCmdArg(1, cTarget, sizeof(cTarget));
			g_hPropMenu[client] = CreateMenu(PropMenu);
			SetMenuTitle(g_hPropMenu[client], "TF2Sandbox - Search Props v%s\n \nSearch Result:", PLUGIN_VERSION);
			SetMenuExitButton(g_hPropMenu[client], true);
			SetMenuExitBackButton(g_hPropMenu[client], false);
			
			SearchProps(client, cTarget);
		}
		else Build_PrintToChat(client, "Usage: !sm_sbs <\x04SEARCHWORD\x01>");
	}
}

public int PropMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsValidClient(param1) && IsPlayerAlive(param1))
	{
		DisplayMenuAtItem(g_hPropMenu[param1], param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		//DisplayMenu(g_hPropMenuPickup, param1, MENU_TIME_FOREVER);
		char info[255];		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_prop %s", info);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsValidClient(param1) && IsClientInGame(param1))
	{
		DisplayMenu(g_hPropMenu[param1], param1, MENU_TIME_FOREVER);
	}
}

void SearchProps(int client, char [] cTarget)
{
	char cCheckPath[128];
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "configs/buildmod/props.ini");
	if (FileExists(cCheckPath))
	{
		Handle hOpenFile = OpenFile(cCheckPath, "r");
		if (hOpenFile != INVALID_HANDLE)
		{
			char szLoadString[255];
			char szBuffer[4][255];
			int iCount = 0;
			while (!IsEndOfFile(hOpenFile))
			{
				if (!ReadFileLine(hOpenFile, szLoadString, sizeof(szLoadString)))
					break;
					
				if (StrContains(szLoadString, ";") == -1 && StrContains(szLoadString, cTarget) != -1) 
				{
					ExplodeString(szLoadString, ", ", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]));
					
					for (int i = 0; i <= 2; i++) 
					{
						StripQuotes(szBuffer[i]);
					}
					if(StrContains(szBuffer[0], cTarget) != -1 || StrContains(szBuffer[3], cTarget) != -1)
					{
						AddMenuItem(g_hPropMenu[client], szBuffer[0], szBuffer[3]);
						iCount++;
					}
				}
			}
			if(iCount == 0)
			{
				Build_PrintToChat(client, "No Result. Searched ( \x04%s\x01 )", cTarget);
			}
			else DisplayMenu(g_hPropMenu[client], client, MENU_TIME_FOREVER);
			CloseHandle(hOpenFile);
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}