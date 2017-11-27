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
#include <build>
#include <build_stocks>
#undef REQUIRE_PLUGIN
#include <updater>
#include <steamworks>

#define DEBUG 

#define UPDATE_URL    ""

#if BUILDMODAPI_VER < 3
#error "build.inc is outdated. please update before compiling"
#endif

#define MSGTAG "\x01[\x04TF2SB\x01]"

#pragma newdecls required

public Plugin myinfo =  
{
	name = "[TF2] Sandbox - Core", 
	author = "Danct12, DaRkWoRlD, greenteaf0718, hjkwe654, BattlefieldDuck", 
	description = "TF2SB Controller Core", 
	version = BUILDMOD_VER, 
	url = "http://dtf2server.ddns.net"
};

//bool
bool steamworks = false;
bool g_bclientLang[MAXPLAYERS];

//Handle
Handle g_hCookieclientLang;
Handle g_hCvarServerTag = INVALID_HANDLE;
Handle g_hCvarGameDesc = INVALID_HANDLE;
Handle g_hBlackListArray;
Handle g_hCvarSwitch = INVALID_HANDLE;
Handle g_hCvarNonOwner = INVALID_HANDLE;
Handle g_hCvarFly = INVALID_HANDLE;
Handle g_hCvarClPropLimit = INVALID_HANDLE;
Handle g_hCvarClDollLimit = INVALID_HANDLE;
Handle g_hCvarServerLimit = INVALID_HANDLE;

//int
int g_iCvarEnabled;
int g_iCvarNonOwner;
int g_iCvarFly;
int g_iCvarClPropLimit[MAXPLAYERS];
int g_iCvarClDollLimit;
int g_iCvarServerLimit;
int g_iPropCurrent[MAXPLAYERS];
int g_iDollCurrent[MAXPLAYERS];
int g_iServerCurrent;
int g_iEntOwner[MAX_HOOK_ENTITIES] =  { -1, ... };

//char
static const char tips[10][] =  
{
	"Type /g to get the Physics Gun and move props around.", 
	"You can rotate a prop by holding down the Reload button.", 
	"If you want to delete everything you own, type !delall", 
	"Type /del to delete the prop you are looking at.", 
	"This server is running \x04TF2:Sandbox\x01 by \x05Danct12\x01 and \x05DaRkWoRlD\x01. Type !tf2sb for more info.", 
	"This mod is a work in progress.", 
	"Type /build to begin building.", 
	"TF2SB Source Code: https://github.com/Danct12/TF2SB", 
	"TF2SB official group: http://steamcommunity.com/groups/TF2Sandbox", 
	"Tired to be in Godmode? Why not turn it off? Say !god"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	RegPluginLibrary("build_test");
	
	CreateNative("Build_RegisterEntityOwner", Native_RegisterOwner);
	CreateNative("Build_ReturnEntityOwner", Native_ReturnOwner);
	CreateNative("Build_SetLimit", Native_SetLimit);
	CreateNative("Build_AllowToUse", Native_AllowToUse);
	CreateNative("Build_AllowFly", Native_AllowFly);
	CreateNative("Build_IsAdmin", Native_IsAdmin);
	CreateNative("Build_ClientAimEntity", Native_ClientAimEntity);
	CreateNative("Build_IsEntityOwner", Native_IsOwner);
	CreateNative("Build_Logging", Native_LogCmds);
	CreateNative("Build_PrintToChat", Native_PrintToChat);
	CreateNative("Build_PrintToAll", Native_PrintToAll);
	CreateNative("Build_AddBlacklist", Native_AddBlacklist);
	CreateNative("Build_RemoveBlacklist", Native_RemoveBlacklist);
	CreateNative("Build_IsBlacklisted", Native_IsBlacklisted);
	CreateNative("Build_IsClientValid", Native_IsClientValid);
	
	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	#if defined _SteamWorks_Included
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	#endif
	
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
	
	if (!strcmp(name, "SteamWorks", false))
		steamworks = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "SteamWorks", false))
		steamworks = false;
}

public void OnConfigsExecuted() 
{
	if (GetConVarBool(g_hCvarServerTag))
		TagsCheck("tf2sb");
	
	if (GetConVarBool(g_hCvarGameDesc))
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "TF2: Sandbox %s", BUILDMOD_VER);
		#if defined _SteamWorks_Included
		if (steamworks)
		{
			SteamWorks_SetGameDescription(sBuffer);
		}
		#endif
	}
}

public void OnPluginStart() 
{
	// Check for update status:
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	g_hCvarSwitch = CreateConVar("sbox_enable", "2", "Turn on, off TF2SB, or admins only.\n0 = Off\n1 = Admins Only\n2 = Enabled for everyone", 0, true, 0.0, true, 2.0);
	g_hCvarNonOwner = CreateConVar("sbox_nonowner", "0", "Switch non-admin player can control non-owner props or not", 0, true, 0.0, true, 1.0);
	g_hCvarFly = CreateConVar("sbox_noclip", "1", "Can players can use !fly to noclip or not?", 0, true, 0.0, true, 1.0);
	g_hCvarClPropLimit = CreateConVar("sbox_maxpropsperplayer", "120", "Player prop spawn limit.", 0, true, 0.0);
	g_hCvarClDollLimit = CreateConVar("sbox_maxragdolls", "10", "Player doll spawn limit.", 0, true, 0.0);
	g_hCvarServerLimit = CreateConVar("sbox_maxprops", "2000", "Server-side props limit.\nDO NOT CHANGE THIS UNLESS YOU KNOW WHAT ARE YOU DOING.\nIf you're looking for changing props limit for player, check out 'sbox_maxpropsperplayer'.'", 0, true, 0.0, true, 0.0);
	g_hCvarServerTag = CreateConVar("sbox_tag", "1", "Enable 'tf2sb' tag", 0, true, 1.0);
	g_hCvarGameDesc = CreateConVar("sbox_gamedesc", "1", "Change game name to 'TF2 Sandbox Version'?", 0, true, 1.0);
	RegAdminCmd("sm_version", Command_Version, 0, "Show TF2SB Core version");
	RegAdminCmd("sm_my", Command_SpawnCount, 0, "Show how many entities are you spawned.");
	SetConVarInt(FindConVar("tf_allow_player_use"), 1);
	
	g_iCvarEnabled = GetConVarInt(g_hCvarSwitch);
	g_iCvarNonOwner = GetConVarBool(g_hCvarNonOwner);
	g_iCvarFly = GetConVarBool(g_hCvarFly);
	for (int i = 0; i < MAXPLAYERS; i++)
		g_iCvarClPropLimit[i] = GetConVarInt(g_hCvarClPropLimit);
	
	g_iCvarClDollLimit = GetConVarInt(g_hCvarClDollLimit);
	g_iCvarServerLimit = GetConVarInt(g_hCvarServerLimit);
	
	HookConVarChange(g_hCvarSwitch, Hook_CvarEnabled);
	HookConVarChange(g_hCvarNonOwner, Hook_CvarNonOwner);
	HookConVarChange(g_hCvarFly, Hook_CvarFly);
	HookConVarChange(g_hCvarClPropLimit, Hook_CvarClPropLimit);
	HookConVarChange(g_hCvarClDollLimit, Hook_CvarClDollLimit);
	HookConVarChange(g_hCvarServerLimit, Hook_CvarServerLimit);
	
	g_hCookieclientLang = RegClientCookie("cookie_BuildModclientLang", "TF2SB client Language.", CookieAccess_Private);
	
	steamworks = LibraryExists("SteamWorks");

	g_hBlackListArray = CreateArray(33, 128); // 33 arrays, every array size is 128
	ReadBlackList();
	PrintToServer("[TF2SB] Plugin successfully started!");
	PrintToServer("This plugin is a work in progress thing, if you have any issues about it, please make a issue post on TF2SB Github: https://github.com/Danct12/TF2SB");
	CreateTimer(120.0, HandleTips, 0, 1);	
}

public void OnMapStart() 
{
	CreateTimer(5.0, DisplayHud);
	Build_FirstRun();
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if ((buttons & IN_SCORE))
	{
		// If so, add the button to use (+use)
		buttons += IN_USE;
	}
}

public Action DisplayHud(Handle timer)
{
	SetHudTextParams(-1.0, 0.0, 1.0, 0, 255, 255, 255, 0, 1.0, 0.1, 0.2);
	for(int i = 1; i <= MAXPLAYERS; i++) if (Build_IsClientValid(i, i))
	{
		ShowHudText(i, -1, "Type !build. This is a WORK IN PROGRESS gamemode!\n\nCurrent Props: %i/%i", g_iPropCurrent[i], g_iCvarClPropLimit[i]);
	}
	CreateTimer(0.1, DisplayHud);
}

public Action HandleTips(Handle timer)
{
	Build_PrintToAll(" %s", tips[GetRandomInt(0, sizeof(tips) - 1)]);
}

public void OnMapEnd() 
{
	char szFile[128], szData[64];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/buildmod/blacklist.ini");
	
	Handle hFile = OpenFile(szFile, "w");
	if (hFile != INVALID_HANDLE)
	{
		for (int i = 0; i < GetArraySize(g_hBlackListArray); i++) 
		{
			GetArrayString(g_hBlackListArray, i, szData, sizeof(szData));
			if (StrContains(szData, "STEAM_") != -1)
				WriteFileString(hFile, szData, false);
		}
		CloseHandle(hFile);
	}
}

public Action OnClientCommand(int client, int args)  
{
	if (Build_IsClientValid(client, client) && client > 0) 
	{
		char Lang[8];
		GetClientCookie(client, g_hCookieclientLang, Lang, sizeof(Lang));
		if (StrEqual(Lang, "1"))
			g_bclientLang[client] = true;
		else
			g_bclientLang[client] = false;
	}
}

public void Hook_CvarEnabled(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarEnabled = GetConVarInt(g_hCvarSwitch);
}

public void Hook_CvarNonOwner(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarNonOwner = GetConVarBool(g_hCvarNonOwner);
}

public void Hook_CvarFly(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarFly = GetConVarBool(g_hCvarFly);
}

public void Hook_CvarClPropLimit(Handle convar, const char[] oldValue, const char[] newValue) 
{
	for (int i = 0; i < MAXPLAYERS; i++)
		g_iCvarClPropLimit[i] = GetConVarInt(g_hCvarClPropLimit);
}

public void Hook_CvarClDollLimit(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarClDollLimit = GetConVarInt(g_hCvarClDollLimit);
}

public void Hook_CvarServerLimit(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarServerLimit = GetConVarInt(g_hCvarServerLimit);
}

public Action Command_Version(int client, int args) 
{
	if (g_bclientLang[client])
		Build_PrintToChat(client, "TF2SB 系統核心版本: %s", BUILDMOD_VER);
	else
		Build_PrintToChat(client, "TF2SB Core version: %s", BUILDMOD_VER);
	return Plugin_Handled;
}

public Action Command_SpawnCount(int client, int args) 
{
	if (!Build_AllowToUse(client) || Build_IsBlacklisted(client))
		return Plugin_Handled;
	
	char szTemp[33], szArgs[128];
	for (int i = 0; i <= GetCmdArgs(); i++) 
	{
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(client, "sm_my", szArgs);
	if (g_bclientLang[client])
		Build_PrintToChat(client, "你的上限: %i/%i [人偶: %i/%i], 伺服器上限: %i/%i", g_iPropCurrent[client], g_iCvarClPropLimit[client], g_iDollCurrent[client], g_iCvarClDollLimit, g_iServerCurrent, g_iCvarServerLimit);
	else
		Build_PrintToChat(client, "Your Limit: %i/%i [Ragdoll: %i/%i], Server Limit: %i/%i", g_iPropCurrent[client], g_iCvarClPropLimit[client], g_iDollCurrent[client], g_iCvarClDollLimit, g_iServerCurrent, g_iCvarServerLimit);
	if (Build_IsAdmin(client)) 
	{
		for (int i = 0; i < MaxClients; i++) 
		{
			if (Build_IsClientValid(i, i) && client != i) 
			{
				if (g_bclientLang[client])
					Build_PrintToChat(client, "%N: %i/%i [人偶: %i/%i]", i, g_iPropCurrent[i], g_iCvarClPropLimit[i], g_iDollCurrent[i], g_iCvarClDollLimit);
				else
					Build_PrintToChat(client, "%N: %i/%i [Ragdoll: %i/%i]", i, g_iPropCurrent[i], g_iCvarClPropLimit[i], g_iDollCurrent[i], g_iCvarClDollLimit);
			}
		}
	}
	return Plugin_Handled;
}

public int Native_RegisterOwner(Handle hPlugin, int iNumParams) 
{
	int iEnt = GetNativeCell(1);
	int client = GetNativeCell(2);
	bool bIsDoll = false;
	
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	
	if (client == -1) {
		g_iEntOwner[iEnt] = -1;
		return true;
	}
	if (IsValidEntity(iEnt) && Build_IsClientValid(client, client)) 
	{
		if (g_iServerCurrent < g_iCvarServerLimit) 
		{
			if (bIsDoll) 
			{
				if (g_iDollCurrent[client] < g_iCvarClDollLimit) 
				{
					g_iDollCurrent[client] += 1;
					g_iPropCurrent[client] += 1;
				} 
				else 
				{
					ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
					if (g_bclientLang[client])
						Build_PrintToChat(client, "你的人偶數量已達上限.");
					else
						Build_PrintToChat(client, "You've hit the ragdoll limit!");
					return false;
				}
			} 
			else 
			{
				if (g_iPropCurrent[client] < g_iCvarClPropLimit[client])
					g_iPropCurrent[client] += 1;
				else 
				{
					ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
					if (g_bclientLang[client])
						Build_PrintToChat(client, "你的物件數量已達上限.");
					else
						Build_PrintToChat(client, "You've hit the prop limit!");
					return false;
				}
			}
			g_iEntOwner[iEnt] = client;
			g_iServerCurrent += 1;
			return true;
		} 
		else 
		{
			ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
			if (g_bclientLang[client])
				Build_PrintToChat(client, "伺服器總物件數量已達總上限.");
			else
				Build_PrintToChat(client, "Server props limit reach maximum.");
			return false;
		}
	}
	
	if (!IsValidEntity(iEnt))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity id %i is invalid.", iEnt);
	
	if (!Build_IsClientValid(client, client))
		ThrowNativeError(SP_ERROR_NATIVE, "client id %i is not in game.", client);
	
	return false;
}

public int Native_ReturnOwner(Handle hPlugin, int iNumParams) 
{
	int iEnt = GetNativeCell(1);
	if (IsValidEntity(iEnt))
		return g_iEntOwner[iEnt];
	else 
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity id %i is invalid.", iEnt);
		return -1;
	}
}

public int Native_SetLimit(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	int Amount = GetNativeCell(2);
	int bIsDoll = false;
	
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	
	if (Amount == 0) 
	{
		if (bIsDoll) 
		{
			g_iServerCurrent -= g_iDollCurrent[client];
			g_iPropCurrent[client] -= g_iDollCurrent[client];
			g_iDollCurrent[client] = 0;
		} 
		else 
		{
			g_iServerCurrent -= g_iPropCurrent[client];
			g_iPropCurrent[client] = 0;
		}
	} 
	else 
	{
		if (bIsDoll) 
		{
			if (g_iDollCurrent[client] > 0)
				g_iDollCurrent[client] += Amount;
		}
		if (g_iPropCurrent[client] > 0)
			g_iPropCurrent[client] += Amount;
		if (g_iServerCurrent > 0)
			g_iServerCurrent += Amount;
	}
	if (g_iDollCurrent[client] < 0)
		g_iDollCurrent[client] = 0;
	if (g_iPropCurrent[client] < 0)
		g_iPropCurrent[client] = 0;
	if (g_iServerCurrent < 0)
		g_iServerCurrent = 0;
}

public int Native_AllowToUse(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	if (IsClientConnected(client)) 
	{
		switch (g_iCvarEnabled) 
		{
			case 0: 
			{
				ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
				if (g_bclientLang[client])
					Build_PrintToChat(client, "TF2SB 目前不能使用或已關閉!");
				else
					Build_PrintToChat(client, "TF2SB is not available or disabled!");
				return false;
			}
			case 1: 
			{
				if (!Build_IsAdmin(client)) 
				{
					if (g_bclientLang[client])
						Build_PrintToChat(client, "TF2SB 目前不能使用或已關閉.");
					else
						Build_PrintToChat(client, "TF2SB is not available or disabled.");
					ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
					return false;
				} 
				else
					return true;
			}
			default:return true;
		}
	}
	
	ThrowNativeError(SP_ERROR_NATIVE, "client id %i is not connected.", client);
	return false;
}

public int Native_AllowFly(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	if (IsClientConnected(client)) 
	{
		//int AdminId:Aid = GetUserAdmin(client);
		if (!g_iCvarFly == true) {
			Build_PrintToChat(client, "Noclip is not available or disabled.");
			ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
			return false;
		} else
			return true;
	}
	
	ThrowNativeError(SP_ERROR_NATIVE, "client id %i is not connected.", client);
	return false;
}

public int Native_IsAdmin(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	bool bLevel2 = false;
	
	if (iNumParams >= 2)
		bLevel2 = GetNativeCell(2);
	
	if (IsClientConnected(client)) 
	{
		AdminId Aid = GetUserAdmin(client);
		if (GetAdminFlag(Aid, (bLevel2) ? Admin_Custom1 : Admin_Slay))
			return true;
		else
			return false;
	} 
	else 
	{
		ThrowNativeError(SP_ERROR_NATIVE, "client id %i is not connected.", client);
		return false;
	}
}

public int Native_ClientAimEntity(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	bool bShowMsg = GetNativeCell(2);
	bool bIncclient = false;
	float vOrigin[3], vAngles[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	if (iNumParams >= 3)
		bIncclient = GetNativeCell(3);
	
	// Command Range Limit
	{
		/*
		float AnglesVec[3], Float:EndPoint[3], Float:Distance;
		if (Build_IsAdmin(client))
			Distance = 50000.0;
		else
			Distance = 1000.0;
		GetClientEyeAngles(client,vAngles);
		GetClientEyePosition(client,vOrigin);
		GetAngleVectors(vAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

		EndPoint[0] = vOrigin[0] + (AnglesVec[0]*Distance);
		EndPoint[1] = vOrigin[1] + (AnglesVec[1]*Distance);
		EndPoint[2] = vOrigin[2] + (AnglesVec[2]*Distance);
		Handle trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint, TraceEntityFilter, client);
		*/
	}
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);
	
	if (TR_DidHit(trace)) 
	{
		int iEntity = TR_GetEntityIndex(trace);
		
		if (iEntity > 0 && IsValidEntity(iEntity)) 
		{
			if (!bIncclient) 
			{
				if (!(GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))) 
				{
					CloseHandle(trace);
					return iEntity;
				}
			} 
			else 
			{
				CloseHandle(trace);
				return iEntity;
			}
		}
	}
	
	if (bShowMsg) 
	{
		if (g_bclientLang[client])
			Build_PrintToChat(client, "你未瞄準任何目標或目標無效.");
		else
			Build_PrintToChat(client, "You dont have a target or target invalid.");
	}
	CloseHandle(trace);
	return -1;
}

public bool TraceEntityFilter(int entity, int mask, any data) 
{
	return data != entity;
}

public int Native_IsOwner(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	int iEnt = GetNativeCell(2);
	bool bIngoreCvar = false;
	
	if (iNumParams >= 3)
		bIngoreCvar = GetNativeCell(3);
	
	if (Build_ReturnEntityOwner(iEnt) != client) 
	{
		if (!Build_IsAdmin(client)) 
		{
			if (GetEntityFlags(iEnt) & (FL_CLIENT | FL_FAKECLIENT)) 
			{
				if (g_bclientLang[client])
					Build_PrintToChat(client, "你沒有權限對玩家使用此指令!");
				else
					Build_PrintToChat(client, "You are not allowed to do this to players!");
				return false;
			}
			if (Build_ReturnEntityOwner(iEnt) == -1) 
			{
				if (!bIngoreCvar) 
				{
					if (!g_iCvarNonOwner) 
						return false;
					else
						return true;
				} 
				else
					return true;
			} 
			else 
				return false;
		} 
		else
			return true;
	} 
	else
		return true;
}

public int Native_LogCmds(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	char szCmd[33], szArgs[128];
	GetNativeString(2, szCmd, sizeof(szCmd));
	GetNativeString(3, szArgs, sizeof(szArgs));
	
	static char szLogPath[64];
	char szTime[16], szName[33], szAuthid[33];
	
	FormatTime(szTime, sizeof(szTime), "%Y-%m-%d");
	GetClientName(client, szName, sizeof(szName));
	GetClientAuthId(client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	
	BuildPath(Path_SM, szLogPath, 64, "logs/%s-TF2SB.log", szTime);
	
	if (StrEqual(szArgs, "")) 
	{
		LogToFile(szLogPath, "\"%s\" (%s) Cmd: %s", szName, szAuthid, szCmd);
		LogToGame("\"%s\" (%s) Cmd: %s", szName, szAuthid, szCmd);
	} 
	else 
	{
		LogToFile(szLogPath, "\"%s\" (%s) Cmd: %s, Args:%s", szName, szAuthid, szCmd, szArgs);
		LogToGame("\"%s\" (%s) Cmd: %s, Args:%s", szName, szAuthid, szCmd, szArgs);
	}
}

public int Native_PrintToChat(Handle hPlugin, int iNumParams) 
{
	char szMsg[192];
	int written;
	FormatNativeString(0, 2, 3, sizeof(szMsg), written, szMsg);
	if (GetNativeCell(1) > 0)
		PrintToChat(GetNativeCell(1), "%s %s", MSGTAG, szMsg);
}

public int Native_PrintToAll(Handle hPlugin, int iNumParams) 
{
	char szMsg[192];
	int written;
	FormatNativeString(0, 1, 2, sizeof(szMsg), written, szMsg);
	PrintToChatAll("%s%s", MSGTAG, szMsg);
}

public int Native_AddBlacklist(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	char szAuthid[33], szName[33], WriteToArray[128], szData[128];
	GetClientAuthId(client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	GetClientName(client, szName, sizeof(szName));
	
	int i;
	for (i = 0; i < GetArraySize(g_hBlackListArray); i++) 
	{
		GetArrayString(g_hBlackListArray, i, szData, sizeof(szData));
		if (StrEqual(szData, ""))
			break;
	}
	
	Format(WriteToArray, sizeof(WriteToArray), "\"%s\"\t\t// %s\n", szAuthid, szName);
	if (SetArrayString(g_hBlackListArray, i, WriteToArray))
		return true;
	
	return false;
}

public int Native_RemoveBlacklist(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	char szAuthid[33], szName[33], szData[128];
	GetClientAuthId(client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	GetClientName(client, szName, sizeof(szName));
	
	for (int i = 0; i < GetArraySize(g_hBlackListArray); i++) 
	{
		GetArrayString(g_hBlackListArray, i, szData, sizeof(szData));
		if (StrContains(szData, szAuthid) != -1) 
		{
			RemoveFromArray(g_hBlackListArray, i);
			return true;
		}
	}
	return false;
}

public int Native_IsBlacklisted(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	char szAuthid[33], szData[128];
	bool BLed = false;
	GetClientAuthId(client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	
	for (int i = 0; i < GetArraySize(g_hBlackListArray); i++) 
	{
		GetArrayString(g_hBlackListArray, i, szData, sizeof(szData));
		if (StrContains(szData, szAuthid) != -1) 
		{
			BLed = true;
			break;
		}
	}
	
	if (BLed) 
	{
		if (g_bclientLang[client]) 
		{
			Build_PrintToChat(client, "你被加入黑名單了 :(");
			Build_PrintToChat(client, "你可以請管理員解除你的黑名單 :(");
		} 
		else 
		{
			Build_PrintToChat(client, "You were blacklisted :(");
			Build_PrintToChat(client, "You may ask admins to unblacklist you :(");
		}
		return true;
	}
	return false;
}

public int Native_IsClientValid(Handle hPlugin, int iNumParams) 
{
	int client = GetNativeCell(1);
	int iTarget = GetNativeCell(2);
	
	if(client < 0) return false; 
	if(client > MaxClients) return false; 
	if(!IsClientConnected(client)) return false;
	if(!IsClientInGame(client)) return false;
	
	if(iTarget < 0) return false; 
	if(iTarget > MaxClients) return false; 
	if(!IsClientConnected(iTarget)) return false;
	if(!IsClientInGame(iTarget)) return false;
	
	bool IsAlive, ReplyTarget;
	if (iNumParams == 3)
		IsAlive = GetNativeCell(3);
	if (iNumParams == 4)
		ReplyTarget = GetNativeCell(4);

	if (IsAlive) 
	{
		if (!IsPlayerAlive(iTarget)) 
		{
			if (ReplyTarget) 
			{
				if (g_bclientLang[client])
					Build_PrintToChat(client, "無法在目標玩家死亡狀態下使用.");
				else
					Build_PrintToChat(client, "This command can only be used on alive players.");
			} 
			else 
			{
				if (g_bclientLang[client])
					Build_PrintToChat(client, "你無法在死亡狀態下使用此指令.");
				else
					Build_PrintToChat(client, "You cannot use the command if you dead.");
			}
			return false;
		}
	}
	return true;
}

void ReadBlackList() 
{
	char szFile[128];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/buildmod/blacklist.ini");
	
	Handle hFile = OpenFile(szFile, "r");
	if (hFile != INVALID_HANDLE)
	{
		int iclients = 0;
		while (!IsEndOfFile(hFile))
		{
			char szLine[255];
			if (!ReadFileLine(hFile, szLine, sizeof(szLine)))
				break;
			
			SetArrayString(g_hBlackListArray, iclients++, szLine);
		}
		CloseHandle(hFile);
	}
}

stock void TagsCheck(const char[] tag)
{
	Handle hTags = FindConVar("sv_tags");
	char tags[255];
	GetConVarString(hTags, tags, sizeof(tags));
	
	if (!(StrContains(tags, tag, false) > -1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		SetConVarString(hTags, newTags);
	}
	CloseHandle(hTags);
} 
