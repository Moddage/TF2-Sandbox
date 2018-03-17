#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Danct12, BloodyNightmare, Hương Tràm Singer"
#define PLUGIN_VERSION ""

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <build>

#pragma newdecls required

bool Airblast[MAXPLAYERS + 1] =  { false, ... };

public Plugin myinfo = 
{
	name = "TF2 Sandbox - Anti Airblast", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	HookEvent("object_deflected", Event_ObjectDeflected);
	
	RegAdminCmd("sm_airblast", OnToggleAirblast, 0, "Toggles airblast on/off");
	RegAdminCmd("sm_ab", OnToggleAirblast, 0, "Toggles airblast on/off");
	
}

public void OnClientConnected(int client)
{
	Airblast[client] = true;
}

public Action Event_ObjectDeflected(Handle event, const char[] name, bool dontBroadcast)
{
	int object2 = GetEventInt(event, "object_entindex");
	if ((object2 >= 1) && (object2 <= MaxClients))
	{
		
		if (Airblast[object2])
		{
			float Vel[3];
			TeleportEntity(object2, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
			TF2_RemoveCondition(object2, TFCond_Dazed); // Stops slowdown
			SetEntPropVector(object2, Prop_Send, "m_vecPunchAngle", Vel);
			SetEntPropVector(object2, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake  
		}
	}
	return Plugin_Continue;
}

public Action OnToggleAirblast(int client, int args)
{
	if (Airblast[client])
	{
		Airblast[client] = false;
		Build_PrintToChat(client, "You're now vulnerable to airblasts!");
	}
	else
	{
		Airblast[client] = true;
		Build_PrintToChat(client, "You're now immune to airblasts. :D");
	}
	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	Airblast[client] = false;
} 