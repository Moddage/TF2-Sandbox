#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>
#include <tf2>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Security Laser",
	author = PLUGIN_AUTHOR,
	description = "Security Laser is not expensive in TF2Sandbox",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-SecurityLaser"
};

#define MODEL_POINTER "models/props_lab/tpplug.mdl"

ConVar cvfRefreshRate;

char g_strLaserModel[][] =
{
	"materials/sprites/laser.vmt", //0
	"materials/sprites/healbeam.vmt", //1
	"materials/sprites/plasmabeam.vmt", //2
	"materials/sprites/bluelaser1.vmt", //3
	"materials/sprites/crystal_beam1.vmt", //4
	"materials/sprites/physbeam.vmt", //5
	"materials/sprites/laserbeam.vmt", //6
	"materials/sprites/laserdot.vmt", //7
	"materials/sprites/lgtning.vmt", //8
	"materials/sprites/steam1.vmt", //9
	"materials/sprites/blueglow1.vmt", //10
	"materials/sprites/crystal_beam1.vmt", //11
	"materials/effects/fire_cloud1.vmt", //12
	"sprites/blueglow2.vmt", //13
	"materials/sprites/halo01.vmt", //14
	"materials/sprites/sprite_fire01.vmt" //15
};

int g_iModelIndex[sizeof(g_strLaserModel)];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_securitylaser_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_laser", Command_SpawnSecurityLaser, 0, "Spawn Security Laser");
	
	cvfRefreshRate = CreateConVar("sm_tf2sb_laser_refreshrate", "0.25", "Security Laser refresh rate", 0, true, 0.1, true, 1.5);
}

public void OnMapStart()
{
	PrecacheModel(MODEL_POINTER);
	
	for (int i = 0; i < sizeof(g_strLaserModel); i++)
	{
		g_iModelIndex[i] = PrecacheModel(g_strLaserModel[i]);
	}

	int index = -1;
	while ((index = FindEntityByClassname(index, "prop_dynamic")) != -1)
	{
		char strModel[64];
		GetEntPropString(index, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		
		if (StrEqual(strModel, MODEL_POINTER))
		{
			CreateTimer(cvfRefreshRate.FloatValue, Timer_SecurityLaser, EntIndexToEntRef(index), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "prop_dynamic") || StrEqual(classname, "prop_dynamic_override"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnLaserPointerSpawn);
	}
}

public void OnLaserPointerSpawn(int entity)
{
	if(IsValidEntity(entity))
	{
		char strModel[64];
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		
		if (StrEqual(strModel, MODEL_POINTER))
		{
			CreateTimer(cvfRefreshRate.FloatValue, Timer_SecurityLaser, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Command_SpawnSecurityLaser(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	SpawnLaserPointer(client);
	
	return Plugin_Continue;
}

public Action Timer_SecurityLaser(Handle timer, int pointerref)
{
	int pointer = EntRefToEntIndex(pointerref);
	if (pointer == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}
	
	float fpointerpos[3], fpointerang[3];
	GetEntPropVector(pointer, Prop_Send, "m_vecOrigin", fpointerpos);
	GetEntPropVector(pointer, Prop_Data, "m_angRotation", fpointerang);
	
	float fSize = GetEntPropFloat(pointer, Prop_Send, "m_flModelScale");
	
	int iSkin = GetEntProp(pointer, Prop_Send, "m_nSkin");
	if (iSkin < 0) iSkin = 0;
	if (iSkin >= sizeof(g_strLaserModel)) iSkin = sizeof(g_strLaserModel) - 1;
	
	int g_iLaserColor[4];
	GetEntityRenderColor(pointer, g_iLaserColor[0], g_iLaserColor[1], g_iLaserColor[2], g_iLaserColor[3]);
	
	TE_SetupBeamPoints(GetPointAimPosition(fpointerpos, fpointerang, 999999.9, pointer), fpointerpos, g_iModelIndex[iSkin], 0, 0, 100, cvfRefreshRate.FloatValue*2.0, fSize, fSize, 0, 0.0, g_iLaserColor, 100);
	TE_SendToAll();
	
	return Plugin_Continue;
}

float[] GetClientEyePositionEx(int client)
{
	float pos[3]; 
	GetClientEyePosition(client, pos);
	
	return pos;
}

float[] GetClientEyeAnglesEx(int client)
{
	float angles[3]; 
	GetClientEyeAngles(client, angles);
	
	return angles;
}

float[] GetPointAimPosition(float pos[3], float angles[3], float maxtracedistance, int client)
{
	Handle trace = TR_TraceRayFilterEx(pos, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

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
		
		if (client > MaxClients)
		{
			float fSize = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
			SetLaserDamageToClient(pos, endpos, fSize);
		}
		
		CloseHandle(trace);
		return endpos;
	}
	
	CloseHandle(trace);
	return pos;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	return (entity > MaxClients && entity != client);
}

void SetLaserDamageToClient(float startpos[3], float endpos[3], float damage)
{
	Handle trace = TR_TraceRayFilterEx(startpos, endpos, MASK_SOLID, RayType_EndPoint, SetClientDamageFilter, damage);
	CloseHandle(trace);
}

public bool SetClientDamageFilter(int entity, int mask, float damage)
{
	if (entity > 0 && entity <= MaxClients && IsClientInGame(entity))
	{
		SDKHooks_TakeDamage(entity, entity, entity, damage, DMG_BURN);
		TF2_AddCondition(entity, TFCond_Bleeding, 2.0);
	}
	
	return false;
}

int SpawnLaserPointer(int client)
{
	int pointer = CreateEntityByName("prop_dynamic_override");
	
	if (IsValidEntity(pointer))
	{
		SetEntProp(pointer, Prop_Send, "m_nSolidType", 6);
		SetEntProp(pointer, Prop_Data, "m_nSolidType", 6);
		
		if (Build_RegisterEntityOwner(pointer, client))
		{
			SetEntityModel(pointer, MODEL_POINTER);
			
			TeleportEntity(pointer, GetPointAimPosition(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), 99999.9, client), NULL_VECTOR, NULL_VECTOR);
			
			DispatchSpawn(pointer);
			
			return pointer;
		}
		
		AcceptEntityInput(pointer, "Kill");
	}
	
	return -1;
}