#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <build>
#include <tf2attributes>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Vending Machine",
	author = PLUGIN_AUTHOR,
	description = "Get a random weapon for free from the vending machine!",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-VendingMachine"
};

#define SOUND_DROP "ambient/levels/labs/coinslot1.wav"

bool g_bIN_SCORE[MAXPLAYERS + 1];

float g_fCoolDown[MAXPLAYERS + 1];

public void OnMapStart()
{
	PrecacheSound(SOUND_DROP);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int machine = GetClientAimVendingMachine(client);
	if (machine > MaxClients && IsValidEntity(machine))
	{
		SetHudTextParams(-1.0, 0.55, 0.01, 124, 252, 0, 255, 1, 6.0, 0.5, 0.5);
		if (g_fCoolDown[client] <= GetGameTime())
		{
			ShowHudText(client, -1, "Press [TAB] to choose items");
		}
		else
		{
			ShowHudText(client, -1, "Cooling Down... (%i)", RoundFloat(g_fCoolDown[client] - GetGameTime()));
		}
		
		if (buttons & IN_SCORE)
		{
			if (!g_bIN_SCORE[client])
			{
				g_bIN_SCORE[client] = true;
				
				if (g_fCoolDown[client] <= GetGameTime())
				{
					Command_VendingMachineMenu(client, -1);
				}
			}
		}
		else
		{
			g_bIN_SCORE[client] = false;
		}
	}
}

public Action Command_VendingMachineMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handle_VendingMachineMenu);
		
	Format(menuinfo, sizeof(menuinfo), "Vending Machine - Item List\n \nGood News! TF2SB players are free to use!\n \nWeapons:");
	menu.SetTitle(menuinfo);

	Format(menuinfo, sizeof(menuinfo), "(FREE) Australium Axtinguisher");
	menu.AddItem("38", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Australium Eyelander");
	menu.AddItem("132", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Australium Wrench");
	menu.AddItem("197", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Australium Medi Gun");
	menu.AddItem("211", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Australium Knife");
	menu.AddItem("194", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Saxxy");
	menu.AddItem("423", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "(FREE) Gold Frying Pan");
	menu.AddItem("1071", menuinfo);

	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);

	return Plugin_Handled;
}

public int Handle_VendingMachineMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		int machine = GetClientAimVendingMachine(client);
		if (machine > MaxClients && IsValidEntity(machine))
		{
			if (g_fCoolDown[client] <= GetGameTime())
			{
				g_fCoolDown[client] = GetGameTime() + 5.0;
				
				int index = StringToInt(info);
				
				switch (index)
				{
					case(38): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/c_models/c_axtinguisher/c_axtinguisher_pyro.mdl", true);
					case(132): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/c_models/c_claymore/c_claymore.mdl", true);
					case(197): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/w_models/w_wrench.mdl", true);
					case(211): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/c_models/c_medigun/c_medigun.mdl", true);
					case(194): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/w_models/w_knife.mdl", true);
					case(423): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/c_models/c_saxxy/c_saxxy.mdl", false);
					case(1071): CreateDroppedWeaponOnVendingMachine(machine, index, "models/weapons/c_models/c_frying_pan/c_frying_pan.mdl", true);
				}
				
				EmitSoundToAll(SOUND_DROP, machine);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

int GetClientAimVendingMachine(int client)
{
	int machine = GetClientAimTarget(client, false);
	if (machine > MaxClients && IsValidEntity(machine))
	{
		char strModel[64];
		GetEntPropString(machine, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		if (StrEqual(strModel, "models/props_interiors/vendingmachinesoda01a.mdl"))
		{
			float fconpos[3], fclientpos[3];
			GetEntPropVector(machine, Prop_Send, "m_vecOrigin", fconpos);
			GetClientEyePosition(client, fclientpos);
			
			if (GetVectorDistance(fconpos, fclientpos) < 150.0)
			{
				return machine;
			}
		}
	}
	
	return -1;
}

int CreateDroppedWeaponOnVendingMachine(int machine, int index, char[] model, bool australium = false)
{
	int weapon = CreateEntityByName("tf_dropped_weapon");
	if (weapon > MaxClients && IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", index);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		SetEntProp(weapon, Prop_Send, "m_iItemIDLow", -1);
		SetEntProp(weapon, Prop_Send, "m_iItemIDHigh", -1);

		int client = Build_ReturnEntityOwner(machine);
		if (client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
		}
		
		if (!IsModelPrecached(model)) PrecacheModel(model);
		SetEntityModel(weapon, model);
		
		if (australium && StrContains(model, "/c_frying_pan/") != -1)
		{
			SetEntProp(weapon, Prop_Send, "m_nSkin", 2);
		}
		else if (australium)
		{
			SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 11);
			
			if (StrContains(model, "/c_medigun/") != -1)
			{
				SetEntProp(weapon, Prop_Send, "m_nSkin", 8);
			}
			else if (StrContains(model, "/c_models/") != -1)
			{
				SetEntProp(weapon, Prop_Send, "m_nSkin", 2);
			}
			else
			{
				SetEntProp(weapon, Prop_Send, "m_nSkin", 8);
			}
		}

		float fmachinepos[3], fmachinerang[3];
		GetEntPropVector(machine, Prop_Send, "m_vecOrigin", fmachinepos);
		GetEntPropVector(machine, Prop_Data, "m_angRotation", fmachinerang);
		fmachinepos[2] -= 30.0;
		
		fmachinerang[1] += GetRandomFloat(-10.0, 10.0);
		
		float fEndPoint[3], fVelocity[3];
		fEndPoint = GetPointAimPosition(fmachinepos, fmachinerang, 15.0, machine);
		MakeVectorFromPoints(fmachinepos, fEndPoint, fVelocity);
		ScaleVector(fVelocity, GetRandomFloat(5.0, 10.0));

		DispatchSpawn(weapon);

		TeleportEntity(weapon, fEndPoint, NULL_VECTOR, fVelocity);
		
		if (australium && StrContains(model, "/c_frying_pan/") != -1)
		{
			TF2Attrib_SetByDefIndex(weapon, 542, 0.0);
			TF2Attrib_SetByDefIndex(weapon, 150, 1.0);
		}
		else if (australium)
		{
			TF2Attrib_SetByDefIndex(weapon, 542, 1.0);
			TF2Attrib_SetByDefIndex(weapon, 2027, 1.0);
			TF2Attrib_SetByDefIndex(weapon, 2022, 1.0);
		}
		
		return weapon;
	}
	
	return -1;
}

float[] GetPointAimPosition(float pos[3], float angles[3], float maxtracedistance, int machine)
{
	Handle trace = TR_TraceRayFilterEx(pos, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, machine);

	if(TR_DidHit(trace))
	{
		float endpos[3];
		TR_GetEndPosition(endpos, trace);
		
		if(!((GetVectorDistance(pos, endpos) <= maxtracedistance) || maxtracedistance <= 0))
		{
			float eyeanglevector[3];
			GetAngleVectors(angles, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			AddVectors(pos, eyeanglevector, endpos);
		}
		
		CloseHandle(trace);
		return endpos;
	}
	
	CloseHandle(trace);
	return pos;
}

public bool TraceEntityFilter(int entity, int mask, int machine)
{
	return false;
}