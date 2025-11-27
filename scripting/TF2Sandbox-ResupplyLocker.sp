#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Resupply Locker",
	author = PLUGIN_AUTHOR,
	description = "A working resupply locker!",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-ResupplyLocker"
};

#define SOUND_LOCKER "items/regenerate.wav"
#define MODEL_LOCKER "models/props_gameplay/resupply_locker.mdl"
#define MODEL_LOCKER2 "models/props_medieval/medieval_resupply.mdl"

float g_fCoolDown[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_resupplylocker_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
}

public void OnMapStart()
{
	PrecacheSound(SOUND_LOCKER);
	PrecacheModel(MODEL_LOCKER);
	PrecacheModel(MODEL_LOCKER2);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	int index = -1;
	while ((index = FindEntityByClassname(index, "prop_dynamic")) != -1)
	{
		char strModel[64];
		GetEntPropString(index, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		
		if (StrEqual(strModel, MODEL_LOCKER) || StrEqual(strModel, MODEL_LOCKER2))
		{
			Handle dp;
			CreateDataTimer(0.1, Timer_ResupplyLocker, dp, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(dp, EntIndexToEntRef(index));
			WritePackCell(dp, false);
		}
	}
}

public void OnClientPutInServer(int client)
{
    g_fCoolDown[client] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "prop_dynamic") || StrEqual(classname, "prop_dynamic_override"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnResupplyLockerSpawn);
	}
}

public void OnResupplyLockerSpawn(int entity)
{
	if(IsValidEntity(entity))
	{
		char strModel[64];
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		
		if (StrEqual(strModel, MODEL_LOCKER) || StrEqual(strModel, MODEL_LOCKER2))
		{
			Handle dp;
			CreateDataTimer(0.1, Timer_ResupplyLocker, dp, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(dp, EntIndexToEntRef(entity));
			WritePackCell(dp, false);
		}
	}
}

public Action Timer_ResupplyLocker(Handle timer, Handle dp)
{
	ResetPack(dp);
	int locker = EntRefToEntIndex(ReadPackCell(dp));
	if (locker == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}
	
	bool IsOpen = ReadPackCell(dp);
	bool HasClientNearBy = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		
		float flockerpos[3], fclientpos[3];
		GetEntPropVector(locker, Prop_Send, "m_vecOrigin", flockerpos);
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", fclientpos);

		if (GetVectorDistance(flockerpos, fclientpos) <= 75.0)
		{
			TR_TraceRayFilter(flockerpos, fclientpos, MASK_SHOT, RayType_EndPoint, TraceEntityFilter, locker);
			if (TR_GetFraction() > 0.98)
			{
				HasClientNearBy = true;
				
				if (!IsOpen)
				{
					IsOpen = true;
					
					SetVariantString("open");
					AcceptEntityInput(locker, "SetAnimation");
				}
				
				if (g_fCoolDown[i] <= GetGameTime())
				{
					g_fCoolDown[i] = GetGameTime() + 3.0;

					EmitSoundToClient(i, SOUND_LOCKER);
					
					//TF2_RegeneratePlayer(i);
					SetEntityHealth(i, GetEntProp(i, Prop_Data, "m_iMaxHealth"));
				}
			}
		}
	}
	
	if (IsOpen && !HasClientNearBy)
	{
		IsOpen = false;
		
		SetVariantString("close");
		AcceptEntityInput(locker, "SetAnimation");
	}
	
	CreateDataTimer(0.1, Timer_ResupplyLocker, dp, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(dp, EntIndexToEntRef(locker));
	WritePackCell(dp, IsOpen);
	
	return Plugin_Continue;
}

public bool TraceEntityFilter(int entity, int mask, int locker)
{
	return (entity != locker);
}