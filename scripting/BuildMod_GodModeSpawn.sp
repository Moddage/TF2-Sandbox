#include <build>

public Plugin:myinfo = {
	name = "TF2 Sandbox - Godmode",
	author = "90% by Myst, 10% by Danct12",
	description = "TF2SB GodMode Plugin",
	version = BUILDMOD_VER,
	url = "http://dtf2server.ddns.net"
};

public OnPluginStart()
{
    HookEvent("player_spawn", Event_Spawn);
    RegAdminCmd("sm_god", Command_ChangeGodMode, 0, "Turn Godmode On/Off");
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
}  

public Action:Command_ChangeGodMode(Client, Args) {
	if (!Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (GetEntProp(Client, Prop_Data, "m_takedamage") == 0 )
	{
		Build_PrintToChat(Client, "God Mode OFF");
		SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
	}
	else
	{
		Build_PrintToChat(Client, "God Mode ON");
		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);	
	}
	
	return Plugin_Handled;
}