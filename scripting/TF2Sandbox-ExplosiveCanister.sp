#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Explosive Canister",
	author = PLUGIN_AUTHOR,
	description = "Pressure the canister - BOOOOM!",
	version = PLUGIN_VERSION,
	url = "https://tf2sandbox.tatlead.com/"
};

#define MODEL_CANISTER1 "models/props_c17/canister01a.mdl"
#define MODEL_CANISTER2 "models/props_c17/canister02a.mdl"

#define MODEL_EXPLOSION "sprites/sprite_fire01.vmt"

Handle g_hSyncPreBar;
Handle g_hSyncHudBox;

int g_iModelExplosion;

ConVar g_TraceDistance;
ConVar g_Magnitude;
ConVar g_RadiusOverride;
ConVar g_CoolDown;

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_canister_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	
	g_TraceDistance = CreateConVar("sm_tf2sb_canister_distance", "250", "(100 - 500) Set the tracable distance between the client and canister.", 0, true, 100.0, true, 500.0);
	g_Magnitude = CreateConVar("sm_tf2sb_canister_magnitude", "500", "(100 - 5000) Set the magnitude of canister explosion.", 0, true, 100.0, true, 5000.0);
	g_RadiusOverride = CreateConVar("sm_tf2sb_canister_radius", "500", "(100 - 5000) Set the radius of canister explosion.", 0, true, 100.0, true, 5000.0);
	g_CoolDown = CreateConVar("sm_tf2sb_canister_cooldown", "3.0", "(0.0 - 10.0) Set the cooldown of canister explosion.", 0, true, 0.0, true, 10.0);
	
	g_hSyncPreBar = CreateHudSynchronizer();
	g_hSyncHudBox = CreateHudSynchronizer();
}

public void OnMapStart()
{
	g_iModelExplosion = PrecacheModel(MODEL_EXPLOSION);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "prop_dynamic") != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

public void OnEntitySpawned(int entity)
{
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	
	if (StrEqual(strModelName, MODEL_CANISTER1) || StrEqual(strModelName, MODEL_CANISTER2))
	{
		//Set initial health
		SetPressureBySequence(entity, 0);
		
		SetEntityRenderColor(entity, _, _, _, 255);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	//Return if player is not alive
	if (!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	//Return if the aiming entity is invalid
	int entity = GetClientAimTarget(client, false);
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	//Return if the aiming entity is not canister
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	if (!StrEqual(strModelName, MODEL_CANISTER1) && !StrEqual(strModelName, MODEL_CANISTER2))
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is grabbed by physgun
	float entityVecOrigin[3], clientVecOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityVecOrigin);
	if (entityVecOrigin[0] == 0.0 && entityVecOrigin[1] == 0.0 && entityVecOrigin[2] == 0.0)
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is not within the distance
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientVecOrigin);
	if (GetVectorDistance(entityVecOrigin, clientVecOrigin) > g_TraceDistance.FloatValue)
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is cooling down
	int alpha;
	GetEntityRenderColor(entity, alpha, alpha, alpha, alpha);
	if (alpha != 255)
	{
		return Plugin_Continue;
	}
	
	int pressure = GetPressureHealthBySequence(entity);
	
	SetHudTextParams(-1.0, 0.25, 0.05, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hSyncHudBox, "Pressure\n[                 ]");
	SetHudTextParams(-1.0, 0.2871, 0.05, (pressure > 75) ? 255 : 0, (pressure > 75) ? 0 : 255, (pressure > 75) ? 0 : 128, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hSyncPreBar, "%s\n \nHold Mouse3 to add pressure", GetPressureBar(pressure));
	
	if (buttons & IN_ATTACK3)
	{
		//Increase the pressure
		SetPressureBySequence(entity, ++pressure);
		
		if (pressure >= 100)
		{
			CreateExplosionForce(entity, g_Magnitude.IntValue, g_RadiusOverride.IntValue);
			TE_SetupExplosion(entityVecOrigin, g_iModelExplosion, 15.0, 1, 0, g_RadiusOverride.IntValue, g_Magnitude.IntValue);
			TE_SendToAll();
			
			//Reset Pressure
			SetPressureBySequence(entity, 0);
			
			SetEntityRenderColor(entity, _, _, _, 100);
			
			CreateTimer(g_CoolDown.FloatValue, Timer_ResetCanister, EntIndexToEntRef(entity));
		}
	}
	
	return Plugin_Continue;
}

void CreateExplosionForce(int entity, int iMagnitude, int iRadiusOverride)
{
	float entityVecOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityVecOrigin);
	
	int explosion = CreateEntityByName("env_explosion");
	if (explosion != -1)
	{
		char strMagnitude[8], strRadiusOverride[8];
		IntToString(iMagnitude, strMagnitude, sizeof(strMagnitude));
		IntToString(iRadiusOverride, strRadiusOverride, sizeof(strRadiusOverride));
		
		DispatchKeyValue(explosion, "iMagnitude", strMagnitude);
		DispatchKeyValue(explosion, "iRadiusOverride", strRadiusOverride);
		
		DispatchSpawn(explosion);
		
		TeleportEntity(explosion, entityVecOrigin, NULL_VECTOR, NULL_VECTOR);
		
		AcceptEntityInput(explosion, "Explode");
		
		CreateTimer(1.0, Timer_KillExplosionPost, EntIndexToEntRef(explosion));
	}
}

public Action Timer_KillExplosionPost(Handle timer, int explosionRef)
{
	int explosion = EntRefToEntIndex(explosionRef);
	
	if(explosion != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(explosion, "Kill");
	}
}

public Action Timer_ResetCanister(Handle timer, int explosionRef)
{
	int explosion = EntRefToEntIndex(explosionRef);
	
	if(explosion != INVALID_ENT_REFERENCE)
	{
		SetEntityRenderColor(explosion, _, _, _, 255);
	}
}

char[] GetPressureBar(int pressure)
{
	int barCount = RoundFloat(float(pressure) / 10.0);
	
	char strPressureBar[11] = "";
	while (barCount--)
	{
		Format(strPressureBar, sizeof(strPressureBar), "%s|", strPressureBar);
	}
	
	return strPressureBar;
}

int GetPressureHealthBySequence(int entity)
{
	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
	return (sequence < 0) ? 0 : RoundFloat(FloatAbs(float(sequence)));
}

int SetPressureBySequence(int entity, int pressure)
{
	SetEntProp(entity, Prop_Send, "m_nSequence", pressure);
}
