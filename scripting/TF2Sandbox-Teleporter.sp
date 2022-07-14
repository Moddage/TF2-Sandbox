#pragma semicolon 1

#define DEBUG

#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>

#pragma newdecls required

public Plugin myinfo =
{
	name = "[TF2] Sandbox - Teleporter",
	author = "LeadKiller, BattlefieldDuck",
	description = "MSTR Teleporter",
	version = PLUGIN_VERSION,
	url = "https://sandbox.moddage.site/"
};

float g_fCoolDown[MAXPLAYERS + 1];

#define SOUND_TELE "weapons/teleporter_send.wav"

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_teleporter_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	RegAdminCmd("sm_teleporter", Command_Teleporter, 0, "TF2SB Portable Teleporter");
}

public void OnMapStart()
{
	PrecacheSound(SOUND_TELE);
}

public void OnClientPutInServer(int client)
{
    g_fCoolDown[client] = 0.0;
}

public Action Command_Teleporter(int client, int args)
{
	if (!Build_IsClientValid(client, client))
		return Plugin_Handled;

	if (g_fCoolDown[client] >= GetGameTime())
	{
		return Plugin_Handled;
	}

	g_fCoolDown[client] = GetGameTime() + 3.0;

	Menu menu = new Menu(Handler_TeleportMenu);
	menu.SetTitle("TF2SB - Teleporters");
	int index = -1, builderIndex;
	char szModel[128], szIndex[1024], szPropName[256], buffer[512];
	while ((index = FindEntityByClassname(index, "prop_dynamic")) != -1)
	{
		GetEntPropString(index, Prop_Data, "m_ModelName", szModel, sizeof(szModel));

		if (StrEqual(szModel, "models/props_lab/teleplatform.mdl"))
		{
			builderIndex = Build_ReturnEntityOwner(index);

			if (builderIndex > 0 && builderIndex <= MaxClients && IsClientInGame(builderIndex))
			{
				IntToString(EntIndexToEntRef(index), szIndex, sizeof(szIndex));
				GetEntPropString(index, Prop_Data, "m_iName", szPropName, sizeof(szPropName));
				Format(buffer, sizeof(buffer), "%N's %s", builderIndex, szPropName);

				menu.AddItem(szIndex, buffer);
			}
		}
	}

	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Handler_TeleportMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char item[2064];
		menu.GetItem(selection, item, sizeof(item));
		int entity = EntRefToEntIndex(StringToInt(item));
		if (entity != INVALID_ENT_REFERENCE)
		{
			int builderIndex = Build_ReturnEntityOwner(entity);

			float TeleporterPos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", TeleporterPos);

			char PropName[256];
			GetEntPropString(entity, Prop_Data, "m_iName", PropName, sizeof(PropName));

			Build_PrintToChat(client, "Teleported to %N's %s!", builderIndex, PropName);

			TeleportEntity(client, TeleporterPos, NULL_VECTOR, NULL_VECTOR);

			EmitSoundToClient(client, SOUND_TELE);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}