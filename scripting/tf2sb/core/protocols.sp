#define MSGTAG "\x01[\x04TF2SB\x01]"

//bool
#if defined _SteamWorks_Included
bool steamworks = false;
#endif

bool g_bIN_SCORE[MAXPLAYERS + 1];

//Handle
Handle g_hCvarServerTag = INVALID_HANDLE;
Handle g_hCvarGameDesc = INVALID_HANDLE;
Handle g_hBlackListArray;
Handle g_hCvarSwitch = INVALID_HANDLE;
Handle g_hCvarNonOwner = INVALID_HANDLE;
Handle g_hCvarFly = INVALID_HANDLE;
Handle g_hCvarPhysSwitch = INVALID_HANDLE;
Handle g_hCvarTips = INVALID_HANDLE;
Handle g_hCvarClPhysLimit	 = INVALID_HANDLE;
Handle g_hCvarClDonatorLimit = INVALID_HANDLE;
Handle g_hCvarClPropLimit = INVALID_HANDLE;
Handle g_hCvarClDollLimit = INVALID_HANDLE;
Handle g_hCvarServerLimit = INVALID_HANDLE;

//int
int g_iCvarEnabled;
int g_iCvarNonOwner;
int g_iCvarFly;
int g_iCvarPhysEnabled;
int g_iCvarTips;
int g_iCvarClPropLimit;
int g_iCvarClDonatorLimit;
int g_iCvarClPhysLimit;
int g_iCvarClDollLimit;
int g_iCvarServerLimit;
int g_iPropCurrent[MAXPLAYERS];
int g_iPhysCurrent[MAXPLAYERS];
int g_iDollCurrent[MAXPLAYERS];
int g_iServerCurrent;
int g_iEntOwner[MAX_HOOK_ENTITIES] =  { -1, ... };

//char
static const char tips[5][] =  
{
	"tip1",
	"tip2",
	"tip3",
	"tip4",
	"tip5"
};

//float
float g_fCoolDown[MAXPLAYERS + 1];

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
	CreateNative("Build_ResetPhysProps", Native_ResetPhysProps);
	CreateNative("Build_DelPhysProp", Native_DelPhysProp);
	CreateNative("Build_GetCurrentProps", Native_GetCurrentProps);
    CreateNative("Build_GetCurrentPhysProps", Native_GetCurrentPhysProps);

	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	#if defined _SteamWorks_Included
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	#endif
	
	return APLRes_Success;
}

public void OnLibraryAdded_Protocols(const char[] name)
{
	#if defined _updater_included
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	#endif

	#if defined _SteamWorks_Included
		steamworks = true;
	#endif
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

public void OnPluginStart_Protocols() 
{
	// Check for update status:
	#if defined _updater_included
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	#endif

	g_hCvarSwitch = CreateConVar("sbox_enable", "2", "Turn on, off TF2SB, or admins only.\n0 = Off\n1 = Admins Only\n2 = Enabled for everyone", 0, true, 0.0, true, 2.0);
	g_hCvarNonOwner = CreateConVar("sbox_nonowner", "0", "Disable anti-grief", 0, true, 0.0, true, 1.0);
	g_hCvarFly = CreateConVar("sbox_noclip", "1", "Can players can use !fly or noclip to noclip or not?", 0, true, 0.0, true, 1.0);
	g_hCvarTips = CreateConVar("sbox_tips", "1", "Will TF2Sandbox Tips be displayed?", 0, true, 0.0, true, 1.0);
	g_hCvarPhysSwitch = CreateConVar("sbox_enablephysprops", "0", "Allow props with physics", 0, true, 0.0, true, 1.0);
	g_hCvarClPropLimit = CreateConVar("sbox_maxpropsperplayer", "120", "Player prop spawn limit.", 0, true, 0.0);
	g_hCvarClDonatorLimit = CreateConVar("sbox_maxpropsperdonator", "300", "Donator Player prop spawn limit.", 0, true, 0.0);
	g_hCvarClPhysLimit = CreateConVar("sbox_maxphyspropsperplayer", "50", "Player phys prop limit", 0, true, 0.0);
	g_hCvarClDollLimit = CreateConVar("sbox_maxragdolls", "10", "Player doll spawn limit.", 0, true, 0.0);
	g_hCvarServerLimit = CreateConVar("sbox_maxprops", "2000", "Server-side props limit", 0, true, 0.0);
	g_hCvarServerTag = CreateConVar("sbox_tag", "1", "Enable 'tf2sb' tag", 0, true, 1.0);
	g_hCvarGameDesc = CreateConVar("sbox_gamedesc", "1", "Change game name to 'TF2 Sandbox Version'?", 0, true, 1.0);
	RegAdminCmd("sm_version", Command_Version, 0, "Show TF2SB Core version");
	RegAdminCmd("sm_my", Command_SpawnCount, 0, "Show how many entities are you spawned.");
	
	g_iCvarEnabled = GetConVarInt(g_hCvarSwitch);
	g_iCvarTips = GetConVarBool(g_hCvarTips);
	g_iCvarNonOwner = GetConVarBool(g_hCvarNonOwner);
	g_iCvarFly = GetConVarBool(g_hCvarFly);
	g_iCvarPhysEnabled = GetConVarBool(g_hCvarPhysSwitch);
	g_iCvarClPhysLimit = GetConVarInt(g_hCvarClPhysLimit);
	g_iCvarClPropLimit = GetConVarInt(g_hCvarClPropLimit);
	g_iCvarClDonatorLimit = GetConVarInt(g_hCvarClDonatorLimit);
	g_iCvarClDollLimit = GetConVarInt(g_hCvarClDollLimit);
	g_iCvarServerLimit = GetConVarInt(g_hCvarServerLimit);
	
	HookConVarChange(g_hCvarSwitch, Hook_CvarEnabled);
	HookConVarChange(g_hCvarNonOwner, Hook_CvarNonOwner);
	HookConVarChange(g_hCvarFly, Hook_CvarFly);
	HookConVarChange(g_hCvarPhysSwitch, Hook_CvarPhysEnabled);
	HookConVarChange(g_hCvarTips, Hook_CvarTips);
	HookConVarChange(g_hCvarClPhysLimit, Hook_CvarClPhysLimit);
	HookConVarChange(g_hCvarClPropLimit, Hook_CvarClPropLimit);
	HookConVarChange(g_hCvarClDonatorLimit, Hook_CvarClDonatorLimit);
	HookConVarChange(g_hCvarClDollLimit, Hook_CvarClDollLimit);
	HookConVarChange(g_hCvarServerLimit, Hook_CvarServerLimit);
	
	#if defined _SteamWorks_Included
		steamworks = LibraryExists("SteamWorks");
	#endif

	g_hBlackListArray = CreateArray(33, 128); // 33 arrays, every array size is 128
	ReadBlackList();
	CreateTimer(15.0, HandleTips, 0, 1);

	AutoExecConfig();
	LoadTranslations("tf2sandbox.phrases");

	PrintToServer("%T", "tf2sb1", LANG_SERVER);
	PrintToServer("%T", "tf2sb2", LANG_SERVER, BUILDMOD_VER);
}

public void OnMapStart_Protocols() 
{
	CreateTimer(5.0, DisplayHud);
	Build_FirstRun();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer_Protocols(client);
		}
	}
}

public void OnClientPutInServer_Protocols(int client)
{
    g_fCoolDown[client] = 0.0;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (buttons & IN_SCORE)
	{
		if (!g_bIN_SCORE[client])
		{
			if (g_fCoolDown[client] <= GetGameTime())
			{	
				g_fCoolDown[client] = GetGameTime() + 2.0;
				
				// If so, add the button to use (+use)
				int iAimTarget = Build_ClientAimEntity(client, false, true);
				char szClass[32];
				char szModel[42];
				if (iAimTarget != -1 && IsValidEdict(iAimTarget))
				{
					GetEdictClassname(iAimTarget, szClass, sizeof(szClass));
					GetEntPropString(iAimTarget, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		
					if (StrContains(szClass, "prop_door_", false) == 0)
					{
						buttons &= IN_USE;
					}
					else if (StrEqual(szModel, "models/props_lab/teleplatform.mdl"))
					{
						FakeClientCommand(client, "sm_teleporter");
					}
				}
				else
				{
					if (GetClientMenu(client, INVALID_HANDLE) == MenuSource_None)
					{
						FakeClientCommand(client, "sm_build");
					}
				}
			}
		}
		
		g_bIN_SCORE[client] = true;
	}
	else
	{
		g_bIN_SCORE[client] = false;
	}
}

public Action DisplayHud(Handle timer)
{
	for(int i = 1; i <= MAXPLAYERS; i++) if (Build_IsClientValid(i, i))
	{
		//int hidehudnumber = GetEntProp(i, Prop_Send, "m_iHideHUD");
	
		//if (hidehudnumber == 2048)
		//{
			
		if (!g_bIN_SCORE[i])
		{
			if (CheckCommandAccess(i, "sm_tf2sb_donor", 0))
			{
				SetHudTextParams(-1.0, 0.01, 0.01, 0, 255, 255, 255, 0, 1.0, 0.5, 0.5);
				ShowHudText(i, -1, "\n%T%i/%i", "hudmsg", i, g_iPropCurrent[i], g_iCvarClDonatorLimit);
				SetHudTextParams(-1.0, 0.08, 0.01, 0, 255, 255, 255, 0, 1.0, 0.5, 0.5);
				ShowHudText(i, -1, "\n%T%i/%i", "hudmsg2", i, g_iPhysCurrent[i], g_iCvarClPhysLimit);
			}
			else
			{
				SetHudTextParams(-1.0, 0.01, 0.01, 0, 255, 255, 255, 0, 1.0, 0.5, 0.5);
				ShowHudText(i, -1, "\n%T%i/%i", "hudmsg", i, g_iPropCurrent[i], g_iCvarClPropLimit);
				SetHudTextParams(-1.0, 0.08, 0.01, 0, 255, 255, 255, 0, 1.0, 0.5, 0.5);
				ShowHudText(i, -1, "\n%T%i/%i", "hudmsg2", i, g_iPhysCurrent[i], g_iCvarClPhysLimit);
			}
			
		}
		
		//}
	}
	CreateTimer(0.1, DisplayHud);
}

public Action HandleTips(Handle timer)
{
	if (!g_iCvarTips == false)
		Build_PrintToAll(" %t", tips[GetRandomInt(0, sizeof(tips) - 1)]);
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

public void Hook_CvarPhysEnabled(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarPhysEnabled = GetConVarBool(g_hCvarPhysSwitch);
}

public void Hook_CvarTips(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarTips = GetConVarBool(g_hCvarTips);
}

public void Hook_CvarClPropLimit(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarClPropLimit = GetConVarInt(g_hCvarClPropLimit);
}

public void Hook_CvarClDonatorLimit(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iCvarClDonatorLimit = GetConVarInt(g_hCvarClDonatorLimit);
}

public void Hook_CvarClPhysLimit(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarClPhysLimit = GetConVarInt(g_hCvarClPhysLimit);
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
	Build_PrintToChat(client, "%s", BUILDMOD_VER);

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
	Build_PrintToChat(client, "Your Limit: %i/%i [Ragdoll: %i/%i] [Phys Props: %i/%i], Server Limit: %i/%i", g_iPropCurrent[client], g_iCvarClPropLimit, g_iDollCurrent[client], g_iPhysCurrent[client], g_iCvarClPhysLimit, g_iCvarClDollLimit, g_iServerCurrent, g_iCvarServerLimit);
	if (Build_IsAdmin(client)) 
	{
		for (int i = 0; i < MaxClients; i++) 
		{
			if (Build_IsClientValid(i, i) && client != i) 
			{
				Build_PrintToChat(client, "%N: %i/%i [Ragdoll: %i/%i]", i, g_iPropCurrent[i], g_iCvarClPropLimit, g_iDollCurrent[i], g_iCvarClDollLimit);
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
	bool bIsPhys = false;
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	if(iNumParams >= 4)
		bIsPhys = GetNativeCell(4);
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
					ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
					Build_PrintToChat(client, "%t", "ragdolllimitreached");
					return false;
				}
			}
			else if(bIsPhys)
			{
				if(g_iPhysCurrent[client] < g_iCvarClPhysLimit)
					g_iPhysCurrent[client] += 1;
				else
				{
					ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
					return false;
				}
			}
			else 
			{
				if ((CheckCommandAccess(client, "sm_tf2sb_donor", 0) && g_iPropCurrent[client] < g_iCvarClDonatorLimit) || g_iPropCurrent[client] < g_iCvarClPropLimit)
				{
					g_iPropCurrent[client] += 1;
				}
				else 
				{
					ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
					Build_PrintToChat(client, "%t", "proplimitreached");
					return false;
				}
			}
			g_iEntOwner[iEnt] = client;
			g_iServerCurrent += 1;
			return true;
		} 
		else 
		{
			ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
			Build_PrintToChat(client, "%t", "globallimitreached");
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
	int bIsPhys = false;
	
	if (iNumParams >= 3)
		bIsDoll = GetNativeCell(3);
	if(iNumParams >= 4)
		bIsPhys = GetNativeCell(4);
	
	if (Amount == 0) 
	{
		if (bIsDoll) 
		{
			g_iServerCurrent -= g_iDollCurrent[client];
			g_iPropCurrent[client] -= g_iDollCurrent[client];
			g_iDollCurrent[client] = 0;
		}
		if (bIsPhys)
		{
			PrintToChat(client, "Set to 0");
			g_iServerCurrent -= g_iPhysCurrent[client];
			g_iPhysCurrent[client] -= g_iPhysCurrent[client];
			g_iPhysCurrent[client] = 0;
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
		if(bIsPhys)
		{
			if(g_iPhysCurrent[client] > 0)
			{
				g_iPhysCurrent[client] += Amount;
			}	
		}
		if(!bIsPhys)
		{
			if (g_iPropCurrent[client] > 0)
				g_iPropCurrent[client] += Amount;
		}	
		if (g_iServerCurrent > 0)
			g_iServerCurrent += Amount;
	}
	if (g_iDollCurrent[client] < 0)
		g_iDollCurrent[client] = 0;
	if (g_iPropCurrent[client] < 0)
		g_iPropCurrent[client] = 0;
	if (g_iPhysCurrent[client] < 0)
		g_iPhysCurrent[client] = 0;
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
				ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
				Build_PrintToChat(client, "TF2SB is not available or disabled!");
				return false;
			}
			case 1: 
			{
				if (!Build_IsAdmin(client)) 
				{
					Build_PrintToChat(client, "TF2SB is not available or disabled.");
					ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
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
			ClientCommand(client, "playgamesound \"%s\"", "replay/replaydialog_warn.wav");
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
		Build_PrintToChat(client, "%t", "invalidtarget");
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
				Build_PrintToChat(client, "%t", "cantuseplayers");
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
		Build_PrintToChat(client, "%t", "blacklisted");
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
				Build_PrintToChat(client, "%t", "deadtarget");
			} 
			else 
			{
				Build_PrintToChat(client, "%t", "alivetouse");
			}
			return false;
		}
	}
	return true;
}
public int Native_ResetPhysProps(Handle hPlugin, int iNumParams)
{
	int client = GetNativeCell(1);
	g_iPhysCurrent[client] = 0;
}

public int Native_DelPhysProp(Handle hPlugin, int iNumParams)
{
	int client = GetNativeCell(1);
	g_iPhysCurrent[client] -= 1;
}

public int Native_GetCurrentProps(Handle hPlugin, int iNumParams)
{
    int client = GetNativeCell(1);
    return g_iPropCurrent[client];
}

public int Native_GetCurrentPhysProps(Handle hPlugin, int iNumParams)
{
    int client = GetNativeCell(1);
    return g_iPhysCurrent[client];
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
