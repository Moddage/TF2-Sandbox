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

#if BUILDMODAPI_VER < 3
	#error "build.inc is outdated. please update before compiling"
#endif

#define MSGTAG "\x01[\x04TF2SB\x01]"

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;


new g_iPropCurrent[MAXPLAYERS];
new g_iDollCurrent[MAXPLAYERS];
new g_iServerCurrent;
new g_iEntOwner[MAX_HOOK_ENTITIES] = {-1,...};

new Handle:g_hBlackListArray;
new Handle:g_hCvarSwitch = INVALID_HANDLE;
new Handle:g_hCvarNonOwner = INVALID_HANDLE;
new Handle:g_hCvarFly = INVALID_HANDLE;
new Handle:g_hCvarClPropLimit = INVALID_HANDLE;
new Handle:g_hCvarClDollLimit = INVALID_HANDLE;
new Handle:g_hCvarServerLimit = INVALID_HANDLE;

new g_iCvarEnabled;
new g_iCvarNonOwner;
new g_iCvarFly;
new g_iCvarClPropLimit[MAXPLAYERS];
new g_iCvarClDollLimit;
new g_iCvarServerLimit;

public Plugin:myinfo = {
	name = "TF2 Sandbox Core",
	author = "DaRkWoRlD",
	description = "TF2SB Controller Core",
	version = BUILDMOD_VER,
	url = "http://dtf2server.ddns.net"
};

static const String:tips[10][] = { 
		"Type /g to get the Physics Gun and move props around.",
		"You can rotate a prop by holding down the Reload button.", 		
		"If you want to delete everything you own, type !delall", 
		"Type /del to delete the prop you are looking at.", 
		"This server is running \x04TF2:Sandbox\x01 by \x05Danct12\x01 and \x05DaRkWoRlD\x01",
		"This mod is a work in progress.",
		"Type /goto <player> to teleport to a player.",
		"Type /build to begin building.",
		"TF2SB official group: http://steamcommunity.com/groups/TF2Sandbox",
		"Tired to be in Godmode? Why not turn it off? Say !god"
	}; 

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
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
	
	return APLRes_Success;
}

public OnPluginStart() {	
	g_hCvarSwitch = CreateConVar("bm_buildmod", "2", "Turn on, off TF2SB, or admins only.", 0, true, 0.0, true, 2.0);
	g_hCvarNonOwner = CreateConVar("bm_nonowner", "0", "Switch non-admin player can control non-owner props or not", 0, true, 0.0, true, 1.0);
	g_hCvarFly = CreateConVar("bm_fly", "1", "Switch non-admin player can use !fly to noclip or not", 0, true, 0.0, true, 1.0);
	g_hCvarClPropLimit = CreateConVar("bm_prop", "120", "Player prop spawn limit.", 0, true, 0.0);
	g_hCvarClDollLimit = CreateConVar("bm_doll", "10", "Player doll spawn limit.", 0, true, 0.0);
	g_hCvarServerLimit = CreateConVar("bm_maxprops", "2000", "Limit server-side prop.", 0, true, 0.0, true, 3000.0);
	RegAdminCmd("sm_version", Command_Version, 0, "Show TF2SB Core version");
	RegAdminCmd("sm_my", Command_SpawnCount, 0, "Show how many entities are you spawned.");
	ServerCommand("tf_allow_player_use 1");
	
	g_iCvarEnabled = GetConVarInt(g_hCvarSwitch);
	g_iCvarNonOwner = GetConVarBool(g_hCvarNonOwner);
	g_iCvarFly = GetConVarBool(g_hCvarFly);
	for (new i = 0; i < MAXPLAYERS; i++)
		g_iCvarClPropLimit[i] = GetConVarInt(g_hCvarClPropLimit);
	g_iCvarClDollLimit = GetConVarInt(g_hCvarClDollLimit);
	g_iCvarServerLimit = GetConVarInt(g_hCvarServerLimit);

	HookConVarChange(g_hCvarSwitch, Hook_CvarEnabled);
	HookConVarChange(g_hCvarNonOwner, Hook_CvarNonOwner);
	HookConVarChange(g_hCvarFly, Hook_CvarFly);
	HookConVarChange(g_hCvarClPropLimit, Hook_CvarClPropLimit);
	HookConVarChange(g_hCvarClDollLimit, Hook_CvarClDollLimit);
	HookConVarChange(g_hCvarServerLimit, Hook_CvarServerLimit);
	
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
	ServerCommand("sw_gamedesc_override \"TF2: Sandbox %s\"", BUILDMOD_VER);
	g_hBlackListArray = CreateArray(33, 128);	// 33 arrays, every array size is 128
	ReadBlackList();
	PrintToServer("[TF2SB] Plugin successfully started!");
	PrintToServer("This plugin is a work in progress thing, if you have any issues about it, please leave a thread on DTF2 Server thread!");
	CreateTimer(30.0, HandleTips, any:0, 1);
}

public OnMapStart() {
	CreateTimer(1.0, DisplayHud, any:0, 3);
	Build_FirstRun();
}


public Action:OnPlayerRunCmd(client, &buttons)
{
	if ((buttons & IN_SCORE))
    { 
        // If so, add the button to use (+use)
        buttons += IN_USE;    
    }
}	

public Action:DisplayHud(Handle:timer)
{
	SetHudTextParams(-1.0, 0.0, 1.0, 0, 255, 255, 255, 0, 1.0, 0.1, 0.2);
	new i = 1;
	while (i < MaxClients)
	{
		if (IsValidEntity(i))
		{
			ShowHudText(i, -1, "Type !build. This is a WORK IN PROGRESS gamemode!");
		}
		i++;
	}
	return Action:0;
}


public Action:HandleTips(Handle:timer)
{
	Build_PrintToAll(" %s", tips[GetRandomInt(0, sizeof(tips) - 1)]);
}

public void OnMapEnd() {
	new String:szFile[128], String:szData[64];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/buildmod/blacklist.ini");
	
	new Handle:hFile = OpenFile(szFile, "w");
	if (hFile == INVALID_HANDLE)
		return false;
	
	for (new i = 0; i < GetArraySize(g_hBlackListArray); i++) {
		GetArrayString(g_hBlackListArray , i, szData, sizeof(szData));
		if(StrContains(szData, "STEAM_") != -1)
			WriteFileString(hFile, szData, false);
	}
	
	CloseHandle(hFile);
	return true;
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

public Hook_CvarEnabled(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iCvarEnabled = GetConVarInt(g_hCvarSwitch);
}

public Hook_CvarNonOwner(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iCvarNonOwner = GetConVarBool(g_hCvarNonOwner);
}

public Hook_CvarFly(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iCvarFly = GetConVarBool(g_hCvarFly);
}

public Hook_CvarClPropLimit(Handle:convar, const String:oldValue[], const String:newValue[]) {
	for (new i = 0; i < MAXPLAYERS; i++)
		g_iCvarClPropLimit[i] = GetConVarInt(g_hCvarClPropLimit);
}

public Hook_CvarClDollLimit(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iCvarClDollLimit = GetConVarInt(g_hCvarClDollLimit);
}

public Hook_CvarServerLimit(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_iCvarServerLimit = GetConVarInt(g_hCvarServerLimit);
}

public Action:Command_Version(Client, args) {
	if (g_bClientLang[Client])
		Build_PrintToChat(Client, "TF2SB 系統核心版本: %s", BUILDMOD_VER);
	else
		Build_PrintToChat(Client, "TF2SB Core version: %s", BUILDMOD_VER);
	return Plugin_Handled;
}

public Action:Command_SpawnCount(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client))
		return Plugin_Handled;
		
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_my", szArgs);
	if (g_bClientLang[Client])
		Build_PrintToChat(Client, "你的上限: %i/%i [人偶: %i/%i], 伺服器上限: %i/%i", g_iPropCurrent[Client], g_iCvarClPropLimit[Client], g_iDollCurrent[Client], g_iCvarClDollLimit, g_iServerCurrent, g_iCvarServerLimit);
	else
		Build_PrintToChat(Client, "Your Limit: %i/%i [Ragdoll: %i/%i], Server Limit: %i/%i", g_iPropCurrent[Client], g_iCvarClPropLimit[Client], g_iDollCurrent[Client], g_iCvarClDollLimit, g_iServerCurrent, g_iCvarServerLimit);
	if (Build_IsAdmin(Client)) {
		for (new i = 1; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i) && Client != i) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "%N: %i/%i [人偶: %i/%i]", i, g_iPropCurrent[i], g_iCvarClPropLimit[i], g_iDollCurrent[i], g_iCvarClDollLimit);
				else
					Build_PrintToChat(Client, "%N: %i/%i [Ragdoll: %i/%i]", i, g_iPropCurrent[i], g_iCvarClPropLimit[i], g_iDollCurrent[i], g_iCvarClDollLimit);
			}
		}
	}
	return Plugin_Handled;
}

public Native_RegisterOwner(Handle:hPlugin, iNumParams) {
	new iEnt = GetNativeCell(1);
	new Client = GetNativeCell(2);
	new bool:bIsDoll = false;
	
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	
	if (Client == -1) {
		g_iEntOwner[iEnt] = -1;
		return true;
	}
	if (IsValidEntity(iEnt) && Build_IsClientValid(Client, Client)) {
		if (g_iServerCurrent < g_iCvarServerLimit) {
			if (bIsDoll) {
				if (g_iDollCurrent[Client] < g_iCvarClDollLimit) {
					g_iDollCurrent[Client] += 1;
					g_iPropCurrent[Client] += 1;
				} else {
					if (g_bClientLang[Client])
						Build_PrintToChat(Client, "你的人偶數量已達上限.");
					else
						Build_PrintToChat(Client, "Your dolls limit reach maximum.");
					return false;
				}
			} else {
				if (g_iPropCurrent[Client] < g_iCvarClPropLimit[Client])
					g_iPropCurrent[Client] += 1;
				else {
					if (g_bClientLang[Client])
						Build_PrintToChat(Client, "你的物件數量已達上限.");
					else
						Build_PrintToChat(Client, "Your props limit reach maximum.");
					return false;
				}
			}
			g_iEntOwner[iEnt] = Client;
			g_iServerCurrent += 1;
			return true;
		} else {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "伺服器總物件數量已達總上限.");
			else
				Build_PrintToChat(Client, "Server props limit reach maximum.");
			return false;
		}
	}
	
	if (!IsValidEntity(iEnt))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity id %i is invalid.", iEnt);
		
	if (!Build_IsClientValid(Client, Client))
		ThrowNativeError(SP_ERROR_NATIVE, "Client id %i is not in game.", Client);
		
	return -1;
}

public Native_ReturnOwner(Handle:hPlugin, iNumParams) {
	new iEnt = GetNativeCell(1);
	if (IsValidEntity(iEnt))
		return g_iEntOwner[iEnt];
	else {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity id %i is invalid.", iEnt);
		return -1;
	}
}

public Native_SetLimit(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new Amount = GetNativeCell(2);
	new bIsDoll = false;
	
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	
	if (Amount == 0) {
		if (bIsDoll) {
			g_iServerCurrent -= g_iDollCurrent[Client];
			g_iPropCurrent[Client] -= g_iDollCurrent[Client];
			g_iDollCurrent[Client] = 0;
		} else {
			g_iServerCurrent -= g_iPropCurrent[Client];
			g_iPropCurrent[Client] = 0;
		}
	} else {
		if (bIsDoll) {
			if(g_iDollCurrent[Client] > 0)
				g_iDollCurrent[Client] += Amount;
		}
		if (g_iPropCurrent[Client] > 0)
			g_iPropCurrent[Client] += Amount;
		if (g_iServerCurrent > 0)
			g_iServerCurrent += Amount;
	}
	if (g_iDollCurrent[Client] < 0)
		g_iDollCurrent[Client] = 0;
	if (g_iPropCurrent[Client] < 0)
		g_iPropCurrent[Client] = 0;
	if (g_iServerCurrent < 0)
		g_iServerCurrent = 0;
}

public Native_AllowToUse(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	if (IsClientConnected(Client)) {
		switch (g_iCvarEnabled) {
			case 0: {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "TF2SB 目前不能使用或已關閉!");
				else
					Build_PrintToChat(Client, "TF2SB is not available or disabled!");
				return false;
			}
			case 1: {
				if (!Build_IsAdmin(Client)) {
					if (g_bClientLang[Client])
						Build_PrintToChat(Client, "TF2SB 目前不能使用或已關閉.");
					else
						Build_PrintToChat(Client, "TF2SB is not available or disabled.");
					return false;
				} else
					return true;
			}
			default: return true;
		}
	}
	
	ThrowNativeError(SP_ERROR_NATIVE, "Client id %i is not connected.", Client);
	return -1;
}

public Native_AllowFly(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	if (IsClientConnected(Client)) {
		new AdminId:Aid = GetUserAdmin(Client);
		if (!g_iCvarFly && GetAdminFlag(Aid, ADMFLAG_CUSTOM1) == false) {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "Fly 目前不能使用或已關閉.");
			else
				Build_PrintToChat(Client, "Fly is not available or disabled.");
			return false;
		} else
			return true;
	}
	
	ThrowNativeError(SP_ERROR_NATIVE, "Client id %i is not connected.", Client);
	return -1;
}

public Native_IsAdmin(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new bool:bLevel2 = false;
	
	if (iNumParams >= 2)
		bLevel2 = GetNativeCell(2);
	
	if (IsClientConnected(Client)) {
		new AdminId:Aid = GetUserAdmin(Client);
		if (GetAdminFlag(Aid, (bLevel2) ? Admin_Custom1 : Admin_Slay))
			return true;
		else
			return false;
	} else {
		ThrowNativeError(SP_ERROR_NATIVE, "Client id %i is not connected.", Client);
		return -1;
	}
}

public Native_ClientAimEntity(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new bool:bShowMsg = GetNativeCell(2);
	new bool:bIncClient = false;
	new Float:vOrigin[3], Float:vAngles[3];
	GetClientEyePosition(Client, vOrigin);
	GetClientEyeAngles(Client, vAngles);
	
	if (iNumParams >= 3)
		bIncClient = GetNativeCell(3);
	
	// Command Range Limit
	{
		/*
		new Float:AnglesVec[3], Float:EndPoint[3], Float:Distance;
		if (Build_IsAdmin(Client))
			Distance = 50000.0;
		else
			Distance = 1000.0;
		GetClientEyeAngles(Client,vAngles);
		GetClientEyePosition(Client,vOrigin);
		GetAngleVectors(vAngles, AnglesVec, NULL_VECTOR, NULL_VECTOR);

		EndPoint[0] = vOrigin[0] + (AnglesVec[0]*Distance);
		EndPoint[1] = vOrigin[1] + (AnglesVec[1]*Distance);
		EndPoint[2] = vOrigin[2] + (AnglesVec[2]*Distance);
		new Handle:trace = TR_TraceRayFilterEx(vOrigin, EndPoint, MASK_SHOT, RayType_EndPoint, TraceEntityFilter, Client);
		*/
	}
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, Client);
	
	if (TR_DidHit(trace)) {
		new iEntity = TR_GetEntityIndex(trace);
		
		if (iEntity > 0 && IsValidEntity(iEntity)) {
			if(!bIncClient) {
				if (!(GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))) {
					CloseHandle(trace);
					return iEntity;
				}
			} else {
				CloseHandle(trace);
				return iEntity;
			}
		}
	}
	
	if (bShowMsg) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "你未瞄準任何目標或目標無效.");
		else
			Build_PrintToChat(Client, "You dont have a target or target invalid.");
	}
	CloseHandle(trace);
	return -1;
}

public bool:TraceEntityFilter(entity, mask, any:data) {
    return data != entity;
}

public Native_IsOwner(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new iEnt = GetNativeCell(2);
	new bool:bIngoreCvar = false;
	
	if (iNumParams >= 3)
		bIngoreCvar = GetNativeCell(3);
	
	if (Build_ReturnEntityOwner(iEnt) != Client) {
		if (!Build_IsAdmin(Client)) {
			if (GetEntityFlags(iEnt) & (FL_CLIENT | FL_FAKECLIENT)) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "你沒有權限對玩家使用此指令!");
				else
					Build_PrintToChat(Client, "You are not allowed to do this to players!");
				return false;
			}
			if (Build_ReturnEntityOwner(iEnt) == -1) {
				if (!bIngoreCvar) {
					if (!g_iCvarNonOwner) {
						
						return false;
					} else
						return true;
				} else
					return true;
			} else {
				
				return false;
			}
		} else
			return true;
	} else
		return true;
}

public Native_LogCmds(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new String:szCmd[33], String:szArgs[128];
	GetNativeString(2, szCmd, sizeof(szCmd));
	GetNativeString(3, szArgs, sizeof(szArgs));
	
	static String:szLogPath[64];
	new String:szTime[16], String:szName[33], String:szAuthid[33];
	
	FormatTime(szTime, sizeof(szTime), "%Y-%m-%d");
	GetClientName(Client, szName, sizeof(szName));
	GetClientAuthId(Client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	
	BuildPath(Path_SM, szLogPath, 64, "logs/%s-TF2SB.log", szTime);
	
	if (StrEqual(szArgs, "")) {
		LogToFile(szLogPath, "\"%s\" (%s) Cmd: %s", szName, szAuthid, szCmd);
		LogToGame("\"%s\" (%s) Cmd: %s", szName, szAuthid, szCmd);
	} else {
		LogToFile(szLogPath, "\"%s\" (%s) Cmd: %s, Args:%s", szName, szAuthid, szCmd, szArgs);
		LogToGame("\"%s\" (%s) Cmd: %s, Args:%s", szName, szAuthid, szCmd, szArgs);
	}
}

public Native_PrintToChat(Handle:hPlugin, iNumParams) {
	new String:szMsg[192], written;
	FormatNativeString(0, 2, 3, sizeof(szMsg), written, szMsg);
	if (GetNativeCell(1) > 0)
		PrintToChat(GetNativeCell(1), "%s %s", MSGTAG, szMsg);
}

public Native_PrintToAll(Handle:hPlugin, iNumParams) {
	new String:szMsg[192], written;
	FormatNativeString(0, 1, 2, sizeof(szMsg), written, szMsg);
	PrintToChatAll("%s%s", MSGTAG, szMsg);
}

public Native_AddBlacklist(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new String:szAuthid[33], String:szName[33], String:WriteToArray[128], String:szData[128];
	GetClientAuthId(Client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	GetClientName(Client, szName, sizeof(szName));
	
	new i;
	for (i = 0; i < GetArraySize(g_hBlackListArray); i++) {
		GetArrayString(g_hBlackListArray , i, szData, sizeof(szData));
		if(StrEqual(szData, ""))
			break;
	}
	
	Format(WriteToArray, sizeof(WriteToArray), "\"%s\"\t\t// %s\n", szAuthid, szName);
	if (SetArrayString(g_hBlackListArray, i, WriteToArray))
		return true;
	
	return false;
}

public Native_RemoveBlacklist(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new String:szAuthid[33], String:szName[33], String:szData[128];
	GetClientAuthId(Client, AuthId_Steam2, szAuthid, sizeof(szAuthid));
	GetClientName(Client, szName, sizeof(szName));
	
	new i;
	for (i = 0; i < GetArraySize(g_hBlackListArray); i++) {
		GetArrayString(g_hBlackListArray , i, szData, sizeof(szData));
		if(StrContains(szData, szAuthid) != -1) {
			RemoveFromArray(g_hBlackListArray, i);
			return true;
		}
	}
	
	return false;
}

public Native_IsBlacklisted(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new String:szAuthid[33], String:szData[128];
	new bool:BLed = false;
	GetClientAuthId(Client, AuthId_Steam2, szAuthid, sizeof(szAuthid));

	for(new i = 0; i < GetArraySize(g_hBlackListArray); i++) {
		GetArrayString(g_hBlackListArray , i, szData, sizeof(szData));
		if(StrContains(szData, szAuthid) != -1) {
			BLed = true;
			break;
		}
	}
	
	if(BLed) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "你被加入黑名單了 :(");
			Build_PrintToChat(Client, "你可以請管理員解除你的黑名單 :(");
		} else {
			Build_PrintToChat(Client, "You were blacklisted :(");
			Build_PrintToChat(Client, "You may ask admins to unblacklist you :(");
		}
		return true;
	}
	
	return false;
}

public Native_IsClientValid(Handle:hPlugin, iNumParams) {
	new Client = GetNativeCell(1);
	new iTarget = GetNativeCell(2);
	new bool:IsAlive, bool:ReplyTarget;
	if (iNumParams == 3)
		IsAlive = GetNativeCell(3);
	if (iNumParams == 4)
		ReplyTarget = GetNativeCell(4);
	
	if (iTarget < 1 || iTarget > 32)
		return false;
	if (!IsClientInGame(iTarget))
		return false;
	else if (IsAlive) {
		if (!IsPlayerAlive(iTarget)) {
			if (ReplyTarget) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "無法在目標玩家死亡狀態下使用.");
				else
					Build_PrintToChat(Client, "This command can only be used on alive players.");
			} else {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "你無法在死亡狀態下使用此指令.");
				else
					Build_PrintToChat(Client, "You cannot use the command if you dead.");
			}
			return false;
		}
	}
	return true;
}

ReadBlackList() {
	new String:szFile[128];
	BuildPath(Path_SM, szFile, sizeof(szFile), "configs/buildmod/blacklist.ini");
	
	new Handle:hFile = OpenFile(szFile, "r");
	if (hFile == INVALID_HANDLE)
		return;
	
	new iClients = 0;
	while (!IsEndOfFile(hFile))
	{
		new String:szLine[255];
		if (!ReadFileLine(hFile, szLine, sizeof(szLine)))
			break;
			
		SetArrayString(g_hBlackListArray, iClients++, szLine);
	}
	CloseHandle(hFile);
}