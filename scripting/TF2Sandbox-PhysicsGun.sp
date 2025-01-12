#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "5.5"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <build>
#include <tf2_stocks>
#include <vphysics>

#pragma newdecls required

public Plugin myinfo =
{
	name = "[TF2] Sandbox - Physics Gun",
	author = PLUGIN_AUTHOR,
	description = "Brings physics gun feature to tf2! (Sandbox version)",
	version = PLUGIN_VERSION,
	url = "https://github.com/TF2-Sandbox-Studio/Module-PhysicsGun"
};

public const float ZERO_VECTOR[3] = {0.0, 0.0, 0.0};

//Hide ammo count & weapon selection
#define HIDEHUD_WEAPONSELECTION	( 1<<0 )

#define EF_NODRAW (1 << 5)

//Impluse
#define IN_SPRAY 201

//Physics Gun Settings
#define WEAPON_SLOT 1
#define MAX_TRACE_DISTANCE 999999.9

#define SOUND_MODE "buttons/button15.wav"
#define SOUND_COPY "weapons/physcannon/physcannon_pickup.wav"

#define MODEL_PHYSICSLASER "materials/sprites/physbeam.vmt"
#define MODEL_HALOINDEX	"materials/sprites/halo01.vmt"
char g_strPhysGunVM[2][] =
{
	"models/weapons/v_physcannon.mdl",
	"models/weapons/v_superphyscannon.mdl"
};
#define MODEL_PHYSICSGUNWM "models/tf2sandbox/w_physicsgun.mdl" //"models/weapons/w_superphyscannon.mdl" <- broken world model

static const int g_iPhysicsGunWeaponIndex = 423;//Choose Saxxy(423) because the player movement won't become a villager
static const int g_iPhysicsGunQuality = 1;
static const int g_iPhysicsGunLevel = 99-128;	//Level displays as 99 but negative level ensures this is unique
int g_iPhysicsGunColor[2][4] = { {255, 50, 0, 255}, {0, 191, 255, 255} };

enum PhysicsGunSequence
{
	IDLE = 0,
	HOLD_IDLE,
	DRAW,
	HOLSTER,
	FIRE,
	ALTFIRE,
	CHARGEUP
}

Handle g_hSyncHints;

ConVar g_cvbCanGrabBuild;
ConVar g_cvbFullDuplicate;

Handle g_hCvarClPropLimit;
Handle g_hCvarClPhysLimit;

int g_iModelIndex;
int g_iHaloIndex;
int g_iPhysicsGunVM[2];
int g_iPhysicsGunWM;
int g_iCvarClPropLimit;
int g_iCvarClPhysLimit;


bool g_bPhysGunMode[MAXPLAYERS + 1];
bool g_bShowHints[MAXPLAYERS + 1];
bool g_bIN_ATTACK[MAXPLAYERS + 1];
bool g_bIN_ATTACK2[MAXPLAYERS + 1];
bool g_bIN_ATTACK3[MAXPLAYERS + 1];

int g_iAimingEntityRef[MAXPLAYERS + 1]; //Aimming entity ref
int g_iGrabEntityRef[MAXPLAYERS + 1]; //Grabbing entity ref
int g_iGrabGlowRef[MAXPLAYERS + 1]; //Grabbing entity glow ref
int g_iGrabOutlineRef[MAXPLAYERS + 1]; //Grabbing entity outline ref
int g_iGrabPointRef[MAXPLAYERS + 1]; //Entity grabbing point
int g_iClientVMRef[MAXPLAYERS + 1]; //Client physics gun viewmodel ref
float g_fGrabDistance[MAXPLAYERS + 1]; //Distance between the client eye and entity grabbing point

float g_oldfEntityPos[MAXPLAYERS + 1][3];
float g_fEntityPos[MAXPLAYERS + 1][3];

MoveType g_mtOriginal[MAXPLAYERS + 1];

float g_fRotateCD[MAXPLAYERS + 1];
float g_fCopyCD[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_physgun_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_physgun", Command_EquipPhysicsGun, 0, "Equip a Physics Gun");
	RegAdminCmd("sm_physicsgun", Command_EquipPhysicsGun, 0, "Equip a Physics Gun");
	
	RegAdminCmd("sm_physguncredits", Command_PhysicsGunCredits, 0, "Open physgun credits menu");
	
	g_cvbCanGrabBuild = CreateConVar("sm_tf2sb_physgun_cangrabbuild", "0", "Enable/disable grabbing buildings", 0, true, 0.0, true, 1.0);
	g_cvbFullDuplicate = CreateConVar("sm_tf2sb_physgun_fullduplicate", "0", "Enable/disable full duplicate feature - Disable = Only prop_dynamic", 0, true, 0.0, true, 1.0);
	
	g_iCvarClPhysLimit = GetConVarInt(FindConVar("sbox_maxphyspropsperplayer"));
	g_iCvarClPropLimit = GetConVarInt(FindConVar("sbox_maxpropsperplayer"));	
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AddNormalSoundHook(SoundHook);
	
	g_hSyncHints = CreateHudSynchronizer();
}

public void OnMapStart()
{
	g_iModelIndex = PrecacheModel(MODEL_PHYSICSLASER);
	g_iHaloIndex = PrecacheModel(MODEL_HALOINDEX);
	g_iPhysicsGunVM[0] = PrecacheModel(g_strPhysGunVM[0]);
	g_iPhysicsGunVM[1] = PrecacheModel(g_strPhysGunVM[1]);
	g_iPhysicsGunWM = PrecacheModel(MODEL_PHYSICSGUNWM);

	
	AddFileToDownloadsTable("models/tf2sandbox/w_physicsgun.dx80.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_physicsgun.dx90.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_physicsgun.sw.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_physicsgun.vvd");
	AddFileToDownloadsTable("models/tf2sandbox/w_physicsgun.mdl");

	PrecacheSound(SOUND_MODE);
	PrecacheSound(SOUND_COPY);

	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_bPhysGunMode[client] = false;
	g_bShowHints[client] = true;
	
	g_iAimingEntityRef[client] = INVALID_ENT_REFERENCE;
	g_iGrabEntityRef[client] = INVALID_ENT_REFERENCE;
	g_iGrabGlowRef[client] = INVALID_ENT_REFERENCE;
	g_iGrabOutlineRef[client] = INVALID_ENT_REFERENCE;
	g_iGrabPointRef[client] = INVALID_ENT_REFERENCE;
	g_iGrabPointRef[client] = EntIndexToEntRef(CreateGrabPoint());
	g_fGrabDistance[client] = MAX_TRACE_DISTANCE;
	
	g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
	
	g_fRotateCD[client] = 0.0;
	g_fCopyCD[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	//Kill Grab Point
	int iGrabPoint = EntRefToEntIndex(g_iGrabPointRef[client]);
	if (iGrabPoint != INVALID_ENT_REFERENCE && iGrabPoint != 0)
	{
		AcceptEntityInput(iGrabPoint, "Kill");
	}
	
	//Kill Grab Outline
	int iGrabOutline = EntRefToEntIndex(g_iGrabOutlineRef[client]);
	if (iGrabOutline != INVALID_ENT_REFERENCE && iGrabOutline != 0)
	{
		AcceptEntityInput(iGrabOutline, "Kill");
	}
	
	//Kill Grab Glow
	int iGrabGlow = EntRefToEntIndex(g_iGrabGlowRef[client]);
	if (iGrabGlow != INVALID_ENT_REFERENCE && iGrabGlow != 0)
	{
		AcceptEntityInput(iGrabGlow, "Kill");
	}
}

//Block sound when client IN_ATTACK
#define SOUND_BLOCK "common/wpn_denyselect.wav"
public Action SoundHook(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsHoldingPhysicsGun(i))
		{
			if (StrEqual(sample, SOUND_BLOCK))
			{
				return Plugin_Stop;
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, BlockPhysicsGunDrop);
	}
}

public void BlockPhysicsGunDrop(int entity)
{
	if(IsValidEntity(entity) && IsPhysicsGun(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action Command_EquipPhysicsGun(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	//Credits: FlaminSarge
	int weapon = CreateEntityByName("tf_weapon_builder");
	if (IsValidEntity(weapon))
	{
		int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
		if (IsValidEntity(iTFViewModel))
		{
			AcceptEntityInput(iTFViewModel, "Kill");
		}
		
		SetEntityModel(weapon, MODEL_PHYSICSGUNWM);
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_iPhysicsGunWeaponIndex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		//Player crashes if quality and level aren't set with both methods, for some reason
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityQuality", true), g_iPhysicsGunQuality);
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityLevel", true), g_iPhysicsGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", g_iPhysicsGunQuality);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", g_iPhysicsGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		SetEntProp(weapon, Prop_Send, "m_nSkin", 1);
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iPhysicsGunWM);
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", g_iPhysicsGunWM, _, 0);
		SetEntProp(weapon, Prop_Send, "m_nSequence", 0);
		
		TF2_RemoveWeaponSlot(client, WEAPON_SLOT);
		DispatchSpawn(weapon);
		
		EquipPlayerWeapon(client, weapon);
		
		//Set physics gun as Active Weapon
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		
		Build_PrintToChat(client, "You have equipped a Physics Gun (Sandbox version)!");
	}

	return Plugin_Continue;
}

public Action Command_PhysicsGunCredits(int client, int args)
{
	char menuinfo[1024];
	Menu menu = new Menu(Handler_PhysicsGunCredits);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Physics Gun - Credits\n \nDeveloper: BattlefieldDuck, LeadKiller\n \nEaster EGG:");
	menu.SetTitle(menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Orange Physgun");
	menu.AddItem("ORANGE", menuinfo);
	
	menu.ExitBackButton = false;
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_PhysicsGunCredits(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "ORANGE"))
		{
			Command_EquipPhysicsGun(client, -1);
			
			int weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
			if (IsValidEntity(weapon))
			{
				SetEntProp(weapon, Prop_Send, "m_nSkin", 0);
			}
		}
		
		Command_PhysicsGunCredits(client, -1);
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

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		TF2_RegeneratePlayer(client);
		g_mtOriginal[client] = GetEntityMoveType(client);
	}
}

public Action BlockWeaponSwitch(int client, int entity)
{
	return Plugin_Handled;
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Taunting)
	{
		if (IsHoldingPhysicsGun(client))
		{
			int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			
			//Hide Original viewmodel
			SetEntProp(iViewModel, Prop_Send, "m_fEffects", GetEntProp(iViewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	ClientSettings(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
	PhysGunSettings(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
	
	return Plugin_Continue;
}

/********************
		Stock
*********************/
bool IsHoldingPhysicsGun(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	return (IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && IsPhysicsGun(iActiveWeapon));
}

//Credits: FlaminSarge
bool IsPhysicsGun(int entity) 
{
	if (GetEntSendPropOffs(entity, "m_iItemDefinitionIndex", true) <= 0) 
	{
		return false;
	}
	return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex") == g_iPhysicsGunWeaponIndex
		&& GetEntProp(entity, Prop_Send, "m_iEntityQuality") == g_iPhysicsGunQuality
		&& GetEntProp(entity, Prop_Send, "m_iEntityLevel") == g_iPhysicsGunLevel;
}

bool IsEntityBuild(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	return (StrContains(classname, "obj_") != -1);
}

/* Physics gun function */
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
		int entity = TR_GetEntityIndex(trace);
		if (entity > 0 && (Build_ReturnEntityOwner(entity) == client || CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)))
		{
			g_iAimingEntityRef[client] = EntIndexToEntRef(entity);
			
			if (IsEntityBuild(entity) && !g_cvbCanGrabBuild.BoolValue)
			{
				g_iAimingEntityRef[client] = INVALID_ENT_REFERENCE;
			}
		}
		else
		{
			g_iAimingEntityRef[client] = INVALID_ENT_REFERENCE;
		}
		
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

public bool TraceEntityFilter(int entity, int mask, int client)
{
	return (IsValidEntity(entity)
			&& entity != client
			&& entity != EntRefToEntIndex(g_iGrabEntityRef[client])
			&& entity != EntRefToEntIndex(g_iGrabPointRef[client]));
}

float[] GetAngleYOnly(const float angles[3])
{
	float fAngles[3];
	fAngles[1] = angles[1];

	return fAngles;
}

int CreateGrabPoint()
{
	int iGrabPoint = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(iGrabPoint, "model", MODEL_PHYSICSGUNWM);
	SetEntPropFloat(iGrabPoint, Prop_Send, "m_flModelScale", 0.0);
	DispatchSpawn(iGrabPoint);
	
	AcceptEntityInput(iGrabPoint, "DisableShadow");
	
	return iGrabPoint;
}

//Credits: Alienmario
void TE_SetupBeamEnts(int ent1, int ent2, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed, int flags)
{
	TE_Start("BeamEnts");
	TE_WriteEncodedEnt("m_nStartEntity", ent1);
	TE_WriteEncodedEnt("m_nEndEntity", ent2);
	TE_WriteNum("m_nModelIndex", ModelIndex);
	TE_WriteNum("m_nHaloIndex", HaloIndex);
	TE_WriteNum("m_nStartFrame", StartFrame);
	TE_WriteNum("m_nFrameRate", FrameRate);
	TE_WriteFloat("m_fLife", Life);
	TE_WriteFloat("m_fWidth", Width);
	TE_WriteFloat("m_fEndWidth", EndWidth);
	TE_WriteFloat("m_fAmplitude", Amplitude);
	TE_WriteNum("r", Color[0]);
	TE_WriteNum("g", Color[1]);
	TE_WriteNum("b", Color[2]);
	TE_WriteNum("a", Color[3]);
	TE_WriteNum("m_nSpeed", Speed);
	TE_WriteNum("m_nFadeLength", FadeLength);
	TE_WriteNum("m_nFlags", flags);
}

//Credits: FlaminSarge
#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)
int CreateVM(int client, int modelindex)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_nModelIndex", modelindex);
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent);
	
	return ent;
}

//Credits: FlaminSarge
Handle g_hSdkEquipWearable;
int TF2_EquipWearable(int client, int entity)
{
	if (g_hSdkEquipWearable == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("tf2items.randomizer");
		if (hGameConf == INVALID_HANDLE)
		{
			SetFailState("Couldn't load SDK functions. Could not locate tf2items.randomizer.txt in the gamedata folder.");
			return;
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		if (g_hSdkEquipWearable == INVALID_HANDLE)
		{
			SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
			CloseHandle(hGameConf);
			return;
		}
	}
	
	if (g_hSdkEquipWearable != INVALID_HANDLE) SDKCall(g_hSdkEquipWearable, client, entity);
}

int CreateOutline(int client, int entity)
{
	int ent = CreateEntityByName("tf_glow");
	if(IsValidEntity(ent))
	{
		char oldEntName[256];
		GetEntPropString(entity, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
		
		char strName[128], strClass[64];
		GetEntityClassname(entity, strClass, sizeof(strClass));
		Format(strName, sizeof(strName), "%s%i", strClass, EntIndexToEntRef(entity));
		DispatchKeyValue(entity, "targetname", strName);
		DispatchKeyValue(ent, "target", strName);
		
		DispatchKeyValue(ent, "Mode", "0");
		
		if (GetPhysGunWorldModelSkin(client))
		{
			DispatchKeyValue(ent, "GlowColor", "135 224 230 255"); 
		}
		else
		{
			DispatchKeyValue(ent, "GlowColor", "255 170 0 255"); 
		}
		
		DispatchSpawn(ent);

		AcceptEntityInput(ent, "Enable");
		
		SetEntPropString(entity, Prop_Data, "m_iName", oldEntName);
		
		return ent;
	}
	
	return -1;
}

int CreateGlow(int client)
{
	int ent = CreateEntityByName("light_dynamic");
	if(IsValidEntity(ent))
	{
		SetVariantString("300");
		AcceptEntityInput(ent, "distance");
		
		SetVariantString("4");
		AcceptEntityInput(ent, "brightness");
		
		int color = GetPhysGunWorldModelSkin(client);
		char strColor[32];
		Format(strColor, sizeof(strColor), "%i %i %i %i", g_iPhysicsGunColor[color][0], g_iPhysicsGunColor[color][1], g_iPhysicsGunColor[color][2], g_iPhysicsGunColor[color][3]);
		SetVariantString(strColor);
		AcceptEntityInput(ent, "color");

		DispatchSpawn(ent);
		
		float fpos[3];
		GetClientEyePosition(client, fpos);
		fpos[2] -= 30.0;
		TeleportEntity(ent, fpos, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", client);
		
		AcceptEntityInput(ent, "turnon", client, client);

		return ent;
	}
	
	return -1;
}

int Duplicator(int iEntity)
{
	//Get Value
	float fOrigin[3], fAngles[3];
	char szModel[128], szName[128], szClass[32];
	int iRed, iGreen, iBlue, iAlpha;
	
	GetEntityClassname(iEntity, szClass, sizeof(szClass));
	
	if (StrEqual(szClass, "prop_dynamic"))
	{
		szClass = "prop_dynamic_override";
	}
	else if (StrEqual(szClass, "prop_physics"))
	{
		szClass = "prop_physics_override";
	}
	
	if (!g_cvbFullDuplicate.BoolValue)
	{
		szClass = "prop_dynamic_override";
	}
	
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fAngles);
	GetEntityRenderColor(iEntity, iRed, iGreen, iBlue, iAlpha);
	GetEntPropString(iEntity, Prop_Data, "m_iName", szName, sizeof(szName));
	
	int iNewEntity = CreateEntityByName(szClass);
	if (iNewEntity > MaxClients && IsValidEntity(iNewEntity))
	{
		SetEntProp(iNewEntity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(iNewEntity, Prop_Data, "m_nSolidType", 6);

		if (!IsModelPrecached(szModel))
		{
			PrecacheModel(szModel);
		}

		SetEntityModel(iNewEntity, szModel);
		TeleportEntity(iNewEntity, fOrigin, fAngles, NULL_VECTOR);
		DispatchSpawn(iNewEntity);
		SetEntData(iNewEntity, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), GetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 4), 4, true);
		SetEntPropFloat(iNewEntity, Prop_Send, "m_flModelScale", GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale"));
		(iAlpha < 255) ? SetEntityRenderMode(iNewEntity, RENDER_TRANSCOLOR) : SetEntityRenderMode(iNewEntity, RENDER_NORMAL);
		SetEntityRenderColor(iNewEntity, iRed, iGreen, iBlue, iAlpha);
		SetEntityRenderFx(iNewEntity, GetEntityRenderFx(iEntity));
		SetEntProp(iNewEntity, Prop_Send, "m_nSkin", GetEntProp(iEntity, Prop_Send, "m_nSkin"));
		SetEntPropString(iNewEntity, Prop_Data, "m_iName", szName);
		SetEntProp(iNewEntity, Prop_Send, "m_nSequence", GetEntProp(iEntity, Prop_Send, "m_nSequence"));
		SetEntPropFloat(iNewEntity, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate"));
		
		return iNewEntity;
	}
	
	return -1;
}

stock void ClientSettings(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(IsHoldingPhysicsGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) == INVALID_ENT_REFERENCE)
	{
		//Hide Original viewmodel
		SetEntProp(iViewModel, Prop_Send, "m_fEffects", GetEntProp(iViewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
		 
		//Create client physics gun viewmodel
		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iPhysicsGunVM[GetPhysGunWorldModelSkin(client)]));
		
		int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
		if (IsValidEntity(iTFViewModel))
		{
			SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(DRAW));
			SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 2.0);
			
			CreateTimer(1.0, ResetPhysGunPlaybackRate, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	//Remove client physics gun viewmodel
	else if (!IsHoldingPhysicsGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(EntRefToEntIndex(g_iClientVMRef[client]), "Kill");
	}
	
	if (IsHoldingPhysicsGun(client))
	{
		int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
		
		if (buttons & IN_ATTACK)
		{
			if (IsValidEntity(iTFViewModel))
			{
				if (!g_bIN_ATTACK[client])
				{
					g_bIN_ATTACK[client] = true;
					
					SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(FIRE));
					SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 1.5);
				}
			}
		}
		else
		{
			if (IsValidEntity(iTFViewModel))
			{
				if (g_bIN_ATTACK[client])
				{
					SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(IDLE));
					SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 0.0);
				}
			}
			
			g_bIN_ATTACK[client] = false;
		}
	}
	
	if (IsHoldingPhysicsGun(client) && buttons & IN_ATTACK)
	{
		if (buttons & IN_ATTACK)
		{
			//Block weapon switch
			SDKHook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwitch);
			SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_WEAPONSELECTION);	
			
			//Fix client eyes angles
			int EntityFlags = GetEntityFlags(client);
			
			if (buttons & IN_RELOAD || buttons & IN_ATTACK2 || buttons & IN_ATTACK3)
			{
				if(!(EntityFlags & FL_FROZEN))
				{
					SetEntityFlags(client, EntityFlags | FL_FROZEN);
				}
			}
			else
			{
				if(EntityFlags & FL_FROZEN)
				{
					SetEntityFlags(client, EntityFlags & ~FL_FROZEN);
				}
			}
		}
	}
	//Reset all
	else
	{
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwitch);
		
		int iHideHUD = GetEntProp(client, Prop_Send, "m_iHideHUD");
		if(iHideHUD & HIDEHUD_WEAPONSELECTION)
		{
			SetEntProp(client, Prop_Send, "m_iHideHUD", iHideHUD & ~HIDEHUD_WEAPONSELECTION);
		}
		
		int EntityFlags = GetEntityFlags(client);
		if(EntityFlags & FL_FROZEN)
		{
			SetEntityFlags(client, EntityFlags & ~FL_FROZEN);
		}
	}
}

public Action ResetPhysGunPlaybackRate(Handle timer, int client)
{
	int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
	if (IsValidEntity(iTFViewModel))
	{
		SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(IDLE));
		SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 0.0);
	}
}

stock void PhysGunSettings(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	float fPrintAngle[3];
	
	//Enter when client is holding physics gun and mouse1
	if (IsHoldingPhysicsGun(client) && (buttons & IN_ATTACK))
	{
		int iEntity = EntRefToEntIndex(g_iGrabEntityRef[client]);
		if (iEntity == INVALID_ENT_REFERENCE)
		{
			//Set Grab Distance to MAX if not grabbing prop
			g_fGrabDistance[client] = MAX_TRACE_DISTANCE;
		}
		
		float fAimpos[3];
		fAimpos = GetPointAimPosition(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), g_fGrabDistance[client], client);
		
		//Get datas after GetPointAimPosition
		int iGrabPoint = EntRefToEntIndex(g_iGrabPointRef[client]);
		int iAimEntity = EntRefToEntIndex(g_iAimingEntityRef[client]);
		
		//Enter once when client grab a prop
		if (iAimEntity != INVALID_ENT_REFERENCE && iEntity == INVALID_ENT_REFERENCE && iGrabPoint != INVALID_ENT_REFERENCE)
		{
			//Save the aimming entity to grabbing entity
			g_iGrabEntityRef[client] = g_iAimingEntityRef[client];
			
			//Set the aimming entity to grabbing entity
			iEntity = iAimEntity;
			
			//Set Grab Point position and angle
			if (g_bPhysGunMode[client])
			{
				TeleportEntity(iGrabPoint, fAimpos, GetAngleYOnly(angles), NULL_VECTOR);
			}
			else
			{
				float fAngles[3];
				GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fAngles);
				
				TeleportEntity(iGrabPoint, fAimpos, fAngles, NULL_VECTOR);
			}
			
			//Set entity velocity to 0
			char szClass[32];
			GetEdictClassname(iEntity, szClass, sizeof(szClass));
			if(StrEqual(szClass, "prop_physics") || StrEqual(szClass, "tf_dropped_weapon") || (iEntity > 0 && iEntity <= MaxClients))
			{
				TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);

				if(iEntity > 0 && iEntity <= MaxClients && IsClientInGame(iEntity) && IsPlayerAlive(iEntity))
				{
					g_mtOriginal[iEntity] = GetEntityMoveType(iEntity);
					SetEntityMoveType(iEntity, MOVETYPE_NONE);
				}
			}
			
			//Set entity Outline
			int iGrabOutline = EntRefToEntIndex(g_iGrabOutlineRef[client]);
			if (IsValidEntity(iGrabOutline))
			{
				AcceptEntityInput(iGrabOutline, "Kill");
			}
			
			iGrabOutline = CreateOutline(client, iEntity);
			if (IsValidEntity(iGrabOutline))
			{
				g_iGrabOutlineRef[client] = EntIndexToEntRef(iGrabOutline);
			}
			
			//Set physgun glow
			int iGrabGlow = EntRefToEntIndex(g_iGrabGlowRef[client]); 
			if (iGrabGlow == INVALID_ENT_REFERENCE)
			{
				g_iGrabGlowRef[client] = EntIndexToEntRef(CreateGlow(client));
			}
			
			//Set Grab Distance
			g_fGrabDistance[client] = GetVectorDistance(GetClientEyePositionEx(client), fAimpos);
			
			//Set Entity Position (For throwing prop physics)
			g_fEntityPos[client] = fAimpos;
			
			//Set grabbing entity parent to grabbing point
			SetVariantString("!activator");
			AcceptEntityInput(iEntity, "SetParent", iGrabPoint);
		}

		//When the player grabbing prop
		else if (iEntity != INVALID_ENT_REFERENCE && iGrabPoint != INVALID_ENT_REFERENCE)
		{
			TeleportEntity(iGrabPoint, fAimpos, NULL_VECTOR, NULL_VECTOR);
			
			if (buttons & IN_RELOAD || buttons & IN_ATTACK2 || buttons & IN_ATTACK3)
			{
				//Rotate + Push and pull
				if (buttons & IN_RELOAD)
				{
					float fAngle[3];
					GetEntPropVector(iGrabPoint, Prop_Send, "m_angRotation", fAngle);
					
					//Rotate in 45'
					if (buttons & IN_DUCK) 
					{
						if (g_fRotateCD[client] <= GetGameTime())
						{
							if (g_bPhysGunMode[client])
							{
								//Get the magnitude
								int mousex = (mouse[0] < 0) ? mouse[0] * -1 : mouse[0];
								int mousey = (mouse[1] < 0) ? mouse[1] * -1 : mouse[1];
								
								//Rotate in GMOD mode
								if (mousex > mousey && mousex > 5)
								{
									(mouse[0] > 0) ? (fAngle[1] += 45.0) : (fAngle[1] -= 45.0);
									
									g_fRotateCD[client] = GetGameTime() + 0.5;
								}
								else if (mousey > mousex && mousey > 5)
								{
									(mouse[1] > 0) ? (fAngle[0] -= 45.0) : (fAngle[0] += 45.0);
									
									g_fRotateCD[client] = GetGameTime() + 0.5;
								}
							}
							else
							{
								//Get the magnitude
								int mousex = (mouse[0] < 0) ? mouse[0] * -1 : mouse[0];
								int mousey = (mouse[1] < 0) ? mouse[1] * -1 : mouse[1];
								
								//Rotate Z
								if (buttons & IN_ATTACK3)
								{
									if(mouse[1] < 0)		fAngle[2] -= 45.0; //left
									else if(mouse[1] > 0)	fAngle[2] += 45.0; //right
									
									SetAdjustedAngleZ(fAngle);

									g_fRotateCD[client] = GetGameTime() + 0.25;
								}
								//Rotate XY
								else
								{
									if (mousex > mousey && mousex > 5)
									{
										if(mouse[0] < 0)		fAngle[1] -= 45.0; //left
										else if(mouse[0] > 0)	fAngle[1] += 45.0; //right
										
										SetAdjustedAngleY(fAngle);
	
										g_fRotateCD[client] = GetGameTime() + 0.5;
									}
									else if (mousey > mousex && mousey > 5)
									{
										if(mouse[1] < 0) fAngle[0] -= 45.0; //Up
										else if(mouse[1] > 0) fAngle[0] += 45.0; //Down
										
										SetAdjustedAngleX(fAngle);
										
										g_fRotateCD[client] = GetGameTime() + 0.5;
									}
								}
								
								//Rotate left
								if (buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT))
								{
									fAngle[1] -= 45.0;
									
									SetAdjustedAngleY(fAngle);
									
									g_fRotateCD[client] = GetGameTime() + 0.5;
								}
								//Rotate right
								else if (buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT))
								{
									fAngle[1] += 45.0;
									
									SetAdjustedAngleY(fAngle);

									g_fRotateCD[client] = GetGameTime() + 0.5;
								}
							}							
						}
					}
					//Normal rotation
					else
					{
						//Rotate Left
						if (buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT))
						{
							fAngle[1] -= 1.0;
						}
						//Rotate Right
						else if (buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT))
						{
							fAngle[1] += 1.0;
						}
						
						//Rotate Z
						if (!g_bPhysGunMode[client] && buttons & IN_ATTACK3)
						{
							fAngle[2] -= float(mouse[1]) / 6.0;
						}
						//Rotate XY
						else
						{
							fAngle[0] -= float(mouse[1]) / 6.0;
							fAngle[1] += float(mouse[0]) / 6.0;
						}
					}
					
					AnglesNormalize(fAngle);
					
					if (g_bPhysGunMode[client])
					{
						//Set Grab point angles
						DispatchKeyValueVector(iGrabPoint, "angles", fAngle);
						
						//Unstick
						AcceptEntityInput(iEntity, "ClearParent");
						
						//Get angles after ClearParent
						GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fPrintAngle);
						
						//Reset angles
						DispatchKeyValueVector(iGrabPoint, "angles", GetAngleYOnly(angles));
						
						//Stick
						SetVariantString("!activator");
						AcceptEntityInput(iEntity, "SetParent", iGrabPoint);
					}
					else
					{
						//Set Grab point angles
						DispatchKeyValueVector(iGrabPoint, "angles", fAngle);
						
						//Get Grab point angles
						GetEntPropVector(iGrabPoint, Prop_Send, "m_angRotation", fPrintAngle);
					}
					
					//Push and pull
					if(buttons & IN_FORWARD)
					{
						g_fGrabDistance[client] += 1.0;
					}				
					if(buttons & IN_BACK)
					{
						g_fGrabDistance[client] -= 1.0;
						
						if (g_fGrabDistance[client] < 50.0)
						{
							g_fGrabDistance[client] = 50.0;
						}
					}
				}
				//Freeze unfreeze
				else if (buttons & IN_ATTACK2)
				{

				if (!g_bIN_ATTACK2[client])
					{
						g_bIN_ATTACK2[client] = true;
						if(Phys_IsGravityEnabled(iEntity))	
						{
						    if(Build_GetCurrentProps(client) < g_iCvarClPropLimit)
							{
								Phys_EnableCollisions(iEntity, false);
								Phys_EnableGravity(iEntity, false);
								Phys_EnableDrag(iEntity, false);
								Phys_EnableMotion(iEntity, false);
							}
						}
						else
						{
						    if(Build_GetCurrentPhysProps(client) < g_iCvarClPhysLimit)
							Phys_EnableCollisions(iEntity, true);
							Phys_EnableGravity(iEntity, true);
							Phys_EnableDrag(iEntity, true);
							Phys_EnableMotion(iEntity, true);

						}
					
						EmitSoundToClient(client, SOUND_MODE);
					}

				}
				//Push and pull
				else if (buttons & IN_ATTACK3)
				{
					g_fGrabDistance[client] -= mouse[1] / 2.0;
					
					if (g_fGrabDistance[client] < 50.0)
					{
						g_fGrabDistance[client] = 50.0;
					}
				}
			}
			else
			{
				//Set GrabPoint face the same direction to client
				if (g_bPhysGunMode[client])
				{
					DispatchKeyValueVector(iGrabPoint, "angles", GetAngleYOnly(angles));
				}
			}
		}
		
		//Set beam
		if (iGrabPoint == INVALID_ENT_REFERENCE)
		{
			//Create Grab Point
			g_iGrabPointRef[client] = EntIndexToEntRef(CreateGrabPoint());
		}
		else
		{
			//Teleport Grab Point to client's Aim Position
			TeleportEntity(iGrabPoint, fAimpos, NULL_VECTOR, NULL_VECTOR);
			
			//Set beam
			int clientvm = EntRefToEntIndex(g_iClientVMRef[client]);	
			if (clientvm != INVALID_ENT_REFERENCE)
			{
				//Set beam's speed and width depends on (is client grabbed a prop)?
				float beamwidth = (iEntity != INVALID_ENT_REFERENCE) ? 0.5 : 0.2;
				int beamspeed = (iEntity != INVALID_ENT_REFERENCE) ? 20 : 10;
				
				//Set up client's beam
				TE_SetupBeamEnts(iGrabPoint, clientvm, g_iModelIndex, g_iHaloIndex, 0, 10, 0.1, beamwidth, beamwidth, 0, 0.0, GetPhysGunColor(client), beamspeed, 20);
				TE_SendToClient(client);
				
				//Set up global beam
				for (int i = 1; i <= MaxClients; i++)
				{
					//Exclude client itself! (client != i)
					if (client != i && IsClientInGame(i))
					{
						int iWeaponWM = GetPlayerWeaponSlot(client, WEAPON_SLOT);
						TE_SetupBeamEnts(iGrabPoint, IsValidEntity(iWeaponWM) ? iWeaponWM : client, g_iModelIndex, g_iHaloIndex, 0, 10, 0.1, beamwidth, beamwidth, 0, 0.0, GetPhysGunColor(client), beamspeed, 20);
						
						TE_SendToClient(i);
					}
				}
			}
			
			//Set Entity Position (For throwing prop physics)
			g_oldfEntityPos[client] = g_fEntityPos[client];
			g_fEntityPos[client] = fAimpos;
		}
	}
	//Enter when client is not holding physics gun or release prop
	else
	{
		int entity = EntRefToEntIndex(g_iGrabEntityRef[client]);
		if(entity != INVALID_ENT_REFERENCE)
		{
			//Unstick
			AcceptEntityInput(entity, "ClearParent");
			
			//Apply velocity
			char szClass[32];
			GetEdictClassname(entity, szClass, sizeof(szClass));
			if(StrEqual(szClass, "prop_physics") || StrEqual(szClass, "tf_dropped_weapon") || (entity > 0 && entity <= MaxClients))
			{
				if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && IsPlayerAlive(entity))
				{
					SetEntityMoveType(entity, g_mtOriginal[entity]);
				}

				float vector[3];
				MakeVectorFromPoints(g_oldfEntityPos[client], g_fEntityPos[client], vector);
				
				//TODO: ScaleVector base on their mass!
				ScaleVector(vector, StrEqual(szClass, "prop_physics") ? 30.0 : 30.0);
				
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vector);
			}
			
			//Set client grabbing null
			g_iGrabEntityRef[client] = INVALID_ENT_REFERENCE;
		}
		
		//Kill Grab Outline
		int iGrabOutline = EntRefToEntIndex(g_iGrabOutlineRef[client]);
		if (iGrabOutline != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(iGrabOutline, "Kill");
		}
		
		//Kill Grab Glow
		int iGrabGlow = EntRefToEntIndex(g_iGrabGlowRef[client]);
		if (iGrabGlow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(iGrabGlow, "Kill");
		}
	}
	 
	if (IsHoldingPhysicsGun(client))
	{
		//Toggle PhysGun Mode (false: tf2, true: gmod)
		if (!(buttons & IN_ATTACK))
		{
			if (buttons & IN_ATTACK2)
			{
				if (!g_bIN_ATTACK2[client])
				{
					g_bIN_ATTACK2[client] = true;
					
					g_bPhysGunMode[client] = !g_bPhysGunMode[client];
					
					EmitSoundToClient(client, SOUND_MODE);
				}
			}
			else
			{
				g_bIN_ATTACK2[client] = false;
			}
		}
		
		//Physgun Hints
		if (!(buttons & IN_SCORE))
		{
			char strMode[50], strHints[256];
			strMode = (g_bPhysGunMode[client]) ? "Garry's Mod" : "TF2Sandbox";
			
			int color = GetPhysGunWorldModelSkin(client);
			SetHudTextParams(0.73, 0.43, 0.1, g_iPhysicsGunColor[color][0], g_iPhysicsGunColor[color][1], g_iPhysicsGunColor[color][2], g_iPhysicsGunColor[color][3], 0, 0.0, 0.0, 0.0);
			
			int iEntity = EntRefToEntIndex(g_iGrabEntityRef[client]);
			if (iEntity != INVALID_ENT_REFERENCE)
			{
				if (buttons & IN_RELOAD)
				{
					if (g_bShowHints[client])
					{
						Format(strHints, sizeof(strHints), "\n\n[W] Push\n[S] Pull\n[A] Rotate\n[D] Rotate%s", (g_bPhysGunMode[client]) ? "" : "\n[MOUSE3] Rotate Z-axis");
					}
					
					ShowSyncHudText(client, g_hSyncHints, "MODE: %s\n\nAngles: %i %i %i%s", strMode, RoundFloat(fPrintAngle[0]), RoundFloat(fPrintAngle[1]), RoundFloat(fPrintAngle[2]), strHints);
				}
				else
				{
					char strClassname[64];
					GetEntityClassname(iEntity, strClassname, sizeof(strClassname));
					
					int r, g, b, a;
					GetEntityRenderColor(iEntity, r, g, b, a);
					
					char strUserName[64];
					strUserName = "Unknown";
					
					int owner = Build_ReturnEntityOwner(iEntity);
					if (owner > 0 && owner <= MaxClients)
					{
						GetClientName(owner, strUserName, sizeof(strUserName));
					}
					
					if (g_bShowHints[client])
					{
						Format(strHints, sizeof(strHints), "\n\n[MOUSE2] Freeze/Unfreeze\n[MOUSE3] Pull/Push\n[R] Rotate");
					}
					
					ShowSyncHudText(client, g_hSyncHints, "MODE: %s\n\nObject: %s\nColor: %i %i %i %i\nName: %s\nOwner: %s%s", strMode, strClassname, r, g, b, a, GetEntityName(iEntity), strUserName, strHints);
				}
			}
			else
			{
				//Toggle Show Hints
				if (buttons & IN_ATTACK3)
				{
					if (!g_bIN_ATTACK3[client])
					{
						g_bShowHints[client] = !g_bShowHints[client];
					}
					
					g_bIN_ATTACK3[client] = true;
				}
				else
				{
					g_bIN_ATTACK3[client] = false;
				}
				
				strHints = (g_bShowHints[client]) ? "[MOUSE1] Grab\n[MOUSE2] Change Mode\n[MOUSE3] Hide Hints" : "[MOUSE3] Show Hints";
				
				ShowSyncHudText(client, g_hSyncHints, "MODE: %s\n\n%s", strMode, strHints);
			}
		}
	}
}

char[] GetEntityName(int entity)
{
	char strName[128];
	GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
	ReplaceString(strName, sizeof(strName), "\n", "");

	return strName;
}

int GetPhysGunWorldModelSkin(int client)
{
	int weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	return GetEntProp(weapon, Prop_Send, "m_nSkin");
}

int[] GetPhysGunColor(int client)
{
	int color = GetPhysGunWorldModelSkin(client);
	int acolor[4];
	acolor[0] = g_iPhysicsGunColor[color][0];
	acolor[1] = g_iPhysicsGunColor[color][1];
	acolor[2] = g_iPhysicsGunColor[color][2];
	acolor[3] = g_iPhysicsGunColor[color][3];
	
	return acolor;
}

void SetAdjustedAngleX(float fAngle[3])
{
	AnglesNormalize(fAngle);
	
	if(0.0 < fAngle[0] && fAngle[0] < 45.0)				fAngle[0] = 0.0;
	else if(45.0 < fAngle[0] && fAngle[0] < 90.0)		fAngle[0] = 45.0;
	else if(90.0 < fAngle[0] && fAngle[0] < 135.0)		fAngle[0] = 90.0;
	else if(135.0 < fAngle[0] && fAngle[0] < 180.0)		fAngle[0] = 135.0;
	else if(180.0 < fAngle[0] && fAngle[0] < 225.0)		fAngle[0] = 180.0;
	else if(225.0 < fAngle[0] && fAngle[0] < 270.0)		fAngle[0] = 225.0;
	else if(0.0 > fAngle[0] && fAngle[0] > -45.0)		fAngle[0] = -45.0;
	else if(-45.0 > fAngle[0] && fAngle[0] > -90.0)		fAngle[0] = -90.0;
}

void SetAdjustedAngleY(float fAngle[3])
{
	AnglesNormalize(fAngle);
	
	if(0.0 < fAngle[1] && fAngle[1] < 45.0)				fAngle[1] = 0.0;
	else if(45.0 < fAngle[1] && fAngle[1] < 90.0)		fAngle[1] = 45.0;
	else if(90.0 < fAngle[1] && fAngle[1] < 135.0)		fAngle[1] = 90.0;
	else if(135.0 < fAngle[1] && fAngle[1] < 180.0)		fAngle[1] = 135.0;
	else if(0.0 > fAngle[1] && fAngle[1] > -45.0)		fAngle[1] = -45.0;
	else if(-45.0 > fAngle[1] && fAngle[1] > -90.0)		fAngle[1] = -90.0;
	else if(-90.0 > fAngle[1] && fAngle[1] > -135.0)	fAngle[1] = -135.0;
	else if(-135.0 > fAngle[1] && fAngle[1] > -180.0)	fAngle[1] = -180.0;
}

void SetAdjustedAngleZ(float fAngle[3])
{
	AnglesNormalize(fAngle);
	
	if(0.0 < fAngle[2] && fAngle[2] < 45.0)				fAngle[2] = 0.0;
	else if(45.0 < fAngle[2] && fAngle[2] < 90.0)		fAngle[2] = 45.0;
	else if(90.0 < fAngle[2] && fAngle[2] < 135.0)		fAngle[2] = 90.0;
	else if(135.0 < fAngle[2] && fAngle[2] < 180.0)		fAngle[2] = 135.0;
	else if(0.0 > fAngle[2] && fAngle[2] > -45.0)		fAngle[2] = -45.0;
	else if(-45.0 > fAngle[2] && fAngle[2] > -90.0)		fAngle[2] = -90.0;
	else if(-90.0 > fAngle[2] && fAngle[2] > -135.0)	fAngle[2] = -135.0;
	else if(-135.0 > fAngle[2] && fAngle[2] > -180.0)	fAngle[2] = -180.0;
}

void AnglesNormalize(float vAngles[3])
{
	while (vAngles[0] > 89.0) vAngles[0] -= 360.0;
	while (vAngles[0] < -89.0) vAngles[0] += 360.0;
	while (vAngles[1] > 180.0) vAngles[1] -= 360.0;
	while (vAngles[1] < -180.0) vAngles[1] += 360.0;
	while (vAngles[2] > 180.0) vAngles[2] -= 360.0;
	while (vAngles[2] < -180.0) vAngles[2] += 360.0;
}