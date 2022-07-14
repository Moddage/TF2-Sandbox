#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Danct12"
#define PLUGIN_VERSION "0.0"

#include <sourcemod>
#include <sdktools>
#include <build>

int g_sblife[MAXPLAYERS];

#pragma newdecls required

public Plugin myinfo = 
{
	name = "TF2 Sandbox - Teleport to Real Life",
	author = PLUGIN_AUTHOR,
	description = "April fools!",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_sblife", Command_SBLife, ADMFLAG_CONVARS, "Teleport to real life with sandbox mode.");
}

public void OnClientConnected(int client)
{
	g_sblife[client] = 0;
}


public Action Command_SBLife(int client, int args)
{
	if (g_sblife[client] == 1)
	{
		g_sblife[client] = 0;
		
		if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
			return;

		Build_PrintToChat(client, "Aborted the real life teleporting operation.");
		ClientCommand(client, "r_screenoverlay \"\"");
	}
	else
	{
		g_sblife[client] = 1;
		
		if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
			return;

		Build_PrintToChat(client, "Teleporting to real life... Please wait.");
		ClientCommand(client, "r_screenoverlay \"effects/tp_eyefx/tpeye3.vtf\"");

}

}
