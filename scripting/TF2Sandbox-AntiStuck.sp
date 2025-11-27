#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "8.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>
 
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - AntiStuck System", 
	author = PLUGIN_AUTHOR, 
	description = "Antistuck System for TF2SB", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hEnabled;

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_antistuck_ver", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_hEnabled = CreateConVar("sm_tf2sb_antistuck", "1", "Enable the AntiStuck System?", 0, true, 0.0, true, 1.0);
}

public void OnMapStart()
{
	TagsCheck("SandBox_Addons");
}

public void OnConfigsExecuted()
{
	TagsCheck("SandBox_Addons");
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (GetConVarBool(g_hEnabled))
	{
		if (IsValidClient(client) && IsPlayerAlive(client) && GetEntityMoveType(client) != MOVETYPE_NOCLIP && IsPlayerStuckInEnt(client))
		{ 
			//int iType = GetEntProp(client, Prop_Data, "m_nWaterLevel");
			//PrintCenterText(client, "%i", iType);
			//if (iType == 0) //Not in water
			{
				float iPosition[3];
				GetClientAbsOrigin(client, iPosition);
				iPosition[2] += 10.0;
				TeleportEntity(client, iPosition, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

//-------------[	Stock	]---------------------------------------------------
stock bool IsPlayerStuckInEnt(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter( vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayHitOnlyEnt);
	
	int entity = TR_GetEntityIndex();
	if (IsValidEdict(entity) && GetEntProp(entity, Prop_Data, "m_CollisionGroup", 4) != 2)
	{
		char szClass[64];
		GetEdictClassname(entity, szClass, sizeof(szClass));
		if (StrEqual(szClass, "prop_dynamic") && !StrEqual(szClass, "prop_ragdoll"))
		{
			return true;
		}
	}
	return false;
}

public bool TraceRayHitOnlyEnt(int entity, int contentsMask)
{
	return (entity > MaxClients);
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

/*
stock void PropDisableCollision(int ent)
{
	AcceptEntityInput(ent, "DisableCollision");
}

stock void PropEnableCollision(int ent)
{
	AcceptEntityInput(ent, "EnableCollision");
}
*/

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