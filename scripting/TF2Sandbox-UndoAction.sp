#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Undo Action",
	author = PLUGIN_AUTHOR,
	description = "Reverses the last action(s) you made.",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-UndoAction"
};

#define MAXENTITY 300
int g_iSpawnedEntityRef[MAXPLAYERS + 1][MAXENTITY];
int g_iIndex[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_undo", Command_UndoAction, 0, "Reverses the last action");
	
	for (int client = 1; client <= MaxClients; client++)
		if(IsClientInGame(client))
			OnClientPutInServer(client);
}

public void OnClientPutInServer(int client)
{
	for (int i = 0; i < MAXENTITY; i++)
	{
		g_iSpawnedEntityRef[client][i] = INVALID_ENT_REFERENCE;
	}
	
	g_iIndex[client] = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "prop_") != -1)
	{
		RequestFrame(GetEntityOwner, EntIndexToEntRef(entity));
	}
}

public void GetEntityOwner(int entityref)
{
	int entity = EntRefToEntIndex(entityref);
	if (entity == INVALID_ENT_REFERENCE)
	{
		return;
	}
	
	int client = Build_ReturnEntityOwner(entity);
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_iSpawnedEntityRef[client][g_iIndex[client]] = entityref;
		g_iIndex[client]++;
	}
}

public Action Command_UndoAction(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		int entity = INVALID_ENT_REFERENCE;
		while (g_iIndex[client] > 0)
		{
			g_iIndex[client]--;
			entity = EntRefToEntIndex(g_iSpawnedEntityRef[client][g_iIndex[client]]);
			g_iSpawnedEntityRef[client][g_iIndex[client]] = INVALID_ENT_REFERENCE;
			
			if (entity != INVALID_ENT_REFERENCE)
			{
				break;
			}
		}

		if (entity != INVALID_ENT_REFERENCE)
		{
			char strName[128];
			GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));

			Format(strName, sizeof(strName), "Undone Prop (%s)", strName);
			Build_PrintToChat(client, strName);
			
			AcceptEntityInput(entity, "Kill");
			Build_SetLimit(client, -1);
		}
	}
}
