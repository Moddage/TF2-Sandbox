#pragma semicolon 1

#define PLUGIN_AUTHOR "TF2SB Studio"
#define PLUGIN_VERSION "1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>
#include <tf2_stocks>

#pragma newdecls required

public Plugin myinfo =
{
	name = "[TF2] Sandbox - Portal Gun",
	author = PLUGIN_AUTHOR,
	description = "Portal-style linked portals for TF2 Sandbox",
	version = PLUGIN_VERSION,
	url = "https://sandbox.moddage.site/"
};

#define WEAPON_SLOT          1
#define MAX_TRACE_DISTANCE   4096.0
#define PORTAL_COOLDOWN      0.4
#define PORTAL_EXIT_PUSH     48.0
#define PORTAL_TRIGGER_HALF  24.0

#define HIDEHUD_WEAPONSELECTION (1 << 0)
#define EF_NODRAW               (1 << 5)
#define EF_BONEMERGE            (1 << 0)
#define EF_BONEMERGE_FASTCULL   (1 << 7)

#define SPRITE_PORTAL_GLOW   "sprites/light_glow03.vmt"
#define MODEL_PORTALGUN_VM   "models/tf2sandbox/v_portalgun.mdl"
#define MODEL_PORTALGUN_WM   "models/tf2sandbox/w_portalgun.mdl"
#define MODEL_TRIGGER_DUMMY  "models/error.mdl"

#define PARTICLE_PORTAL_BLUE   "teleporter_blue"
#define PARTICLE_PORTAL_ORANGE "teleporter_red"

#define SOUND_FIRE_BLUE      "weapons/teleporter_send.wav"
#define SOUND_FIRE_ORANGE    "weapons/teleporter_receive.wav"
#define SOUND_TELEPORT       "misc/teleporter_activated.wav"
#define SOUND_DENY           "common/wpn_denyselect.wav"

#define PORTAL_BLUE   0
#define PORTAL_ORANGE 1

#define VMSEQ_IDLE        0
#define VMSEQ_FIRE_BLUE   1
#define VMSEQ_FIRE_ORANGE 1
#define VMSEQ_CLEAR       2

#define VMSEQ_RESET_DELAY 0.5

static const int g_iPortalColor[2][4] = {
	{ 80, 160, 255, 255 },  // blue
	{ 255, 130, 30, 255 }   // orange
};

static const int g_iPortalGunWeaponIndex = 474; // Conscientious Objector
static const int g_iPortalGunQuality     = 1;
static const int g_iPortalGunLevel       = 98 - 128;

int g_iPortalGunWM;
int g_iPortalGunVM;
int g_iPortalGlowSprite;
int g_iTriggerDummyModel;

Handle g_hSdkEquipWearable;
int g_iClientVMRef[MAXPLAYERS + 1];
float g_fVMBusyUntil[MAXPLAYERS + 1];

int g_iPortalVisualRef[MAXPLAYERS + 1][2];   // env_sprite halo
int g_iPortalParticleRef[MAXPLAYERS + 1][2]; // info_particle_system swirl
int g_iPortalTriggerRef[MAXPLAYERS + 1][2];
int g_iPortalLightRef[MAXPLAYERS + 1][2];
float g_fPortalAngles[MAXPLAYERS + 1][2][3];
float g_fPortalOrigin[MAXPLAYERS + 1][2][3];
bool g_bPortalExists[MAXPLAYERS + 1][2];
bool g_bIN_ATTACK[MAXPLAYERS + 1];
bool g_bIN_ATTACK2[MAXPLAYERS + 1];
bool g_bIN_RELOAD[MAXPLAYERS + 1];
float g_fFireCD[MAXPLAYERS + 1];

int g_iTriggerOwner[2049];
int g_iTriggerSide[2049];

// post teleport cooldown to prevent immediate re-entry loop.
float g_fEntityCooldown[2049];

ConVar g_cvbAllowProjectiles;
ConVar g_cvbAllowProps;
ConVar g_cvbAllowPlayers;
ConVar g_cvbPreserveMomentum;
ConVar g_cvfFireCooldown;


public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_portalgun_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);

	RegAdminCmd("sm_portalgun",   Command_EquipPortalGun, 0, "Equip a Portal Gun");
	RegAdminCmd("sm_pgun",        Command_EquipPortalGun, 0, "Equip a Portal Gun");
	RegAdminCmd("sm_portalclear", Command_ClearPortals,   0, "Remove your active portals");

	g_cvbAllowProjectiles = CreateConVar("sm_tf2sb_portalgun_projectiles", "1", "Allow projectiles through portals",   0, true, 0.0, true, 1.0);
	g_cvbAllowProps       = CreateConVar("sm_tf2sb_portalgun_props",       "1", "Allow props through portals",         0, true, 0.0, true, 1.0);
	g_cvbAllowPlayers     = CreateConVar("sm_tf2sb_portalgun_players",     "1", "Allow players through portals",       0, true, 0.0, true, 1.0);
	g_cvbPreserveMomentum = CreateConVar("sm_tf2sb_portalgun_momentum",    "1", "Preserve entry speed on exit",        0, true, 0.0, true, 1.0);
	g_cvfFireCooldown     = CreateConVar("sm_tf2sb_portalgun_firecd",      "0.35", "Seconds between consecutive shots", 0, true, 0.05, true, 5.0);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	g_iPortalGunWM       = PrecacheModel(MODEL_PORTALGUN_WM);
	g_iPortalGunVM       = PrecacheModel(MODEL_PORTALGUN_VM);
	g_iPortalGlowSprite  = PrecacheModel(SPRITE_PORTAL_GLOW);
	g_iTriggerDummyModel = PrecacheModel(MODEL_TRIGGER_DUMMY);

	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.mdl");
	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.vvd");
	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.dx80.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.dx90.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.sw.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/w_portalgun.phy");

	AddFileToDownloadsTable("models/tf2sandbox/v_portalgun.mdl");
	AddFileToDownloadsTable("models/tf2sandbox/v_portalgun.vvd");
	AddFileToDownloadsTable("models/tf2sandbox/v_portalgun.dx80.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/v_portalgun.dx90.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/v_portalgun.sw.vtx");

	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_hands.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_hands.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun2.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun2.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_exponent.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_glass.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_glass.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_lightwarp.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_mask.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_models/v_portalgun/v_portalgun_normal.vtf");

	AddFileToDownloadsTable("materials/models/weapons/w_models/portalgun/w_portalgun.vmt");
	AddFileToDownloadsTable("materials/models/weapons/w_models/portalgun/w_portalgun.vtf");
	AddFileToDownloadsTable("materials/models/weapons/w_models/portalgun/w_portalgun_exponent.vtf");
	AddFileToDownloadsTable("materials/models/weapons/w_models/portalgun/w_portalgun_lightwarp.vtf");
	AddFileToDownloadsTable("materials/models/weapons/w_models/portalgun/w_portalgun_normal.vtf");

	PrecacheSound(SOUND_FIRE_BLUE);
	PrecacheSound(SOUND_FIRE_ORANGE);
	PrecacheSound(SOUND_TELEPORT);
	PrecacheSound(SOUND_DENY);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}

	for (int i = 0; i < sizeof(g_iTriggerOwner); i++)
	{
		g_iTriggerOwner[i] = 0;
		g_iTriggerSide[i] = 0;
		g_fEntityCooldown[i] = 0.0;
	}
}

public void OnClientPutInServer(int client)
{
	for (int side = 0; side < 2; side++)
	{
		g_iPortalVisualRef[client][side] = INVALID_ENT_REFERENCE;
		g_iPortalParticleRef[client][side] = INVALID_ENT_REFERENCE;
		g_iPortalTriggerRef[client][side] = INVALID_ENT_REFERENCE;
		g_iPortalLightRef[client][side] = INVALID_ENT_REFERENCE;
		g_bPortalExists[client][side] = false;
	}
	g_bIN_ATTACK[client] = false;
	g_bIN_ATTACK2[client] = false;
	g_bIN_RELOAD[client] = false;
	g_fFireCD[client] = 0.0;
	g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
	g_fVMBusyUntil[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	ClearClientPortals(client);

	int vm = EntRefToEntIndex(g_iClientVMRef[client]);
	if (vm != INVALID_ENT_REFERENCE && vm > 0)
	{
		AcceptEntityInput(vm, "Kill");
	}
	g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, BlockPortalGunDrop);
	}
}

public void BlockPortalGunDrop(int entity)
{
	if (IsValidEntity(entity) && IsPortalGun(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		TF2_RegeneratePlayer(client);
	}
}


/*****************
    Commands
******************/

public Action Command_EquipPortalGun(int client, int args)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	int weapon = CreateEntityByName("tf_weapon_builder");
	if (IsValidEntity(weapon))
	{
		// clear leftover custom viewmodel so we don't stack duplicates.
		int oldVM = EntRefToEntIndex(g_iClientVMRef[client]);
		if (IsValidEntity(oldVM))
		{
			AcceptEntityInput(oldVM, "Kill");
			g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
		}

		SetEntityModel(weapon, MODEL_PORTALGUN_WM);
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_iPortalGunWeaponIndex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityQuality", true), g_iPortalGunQuality);
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityLevel", true), g_iPortalGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", g_iPortalGunQuality);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", g_iPortalGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iPortalGunWM);
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", g_iPortalGunWM, _, 0);

		TF2_RemoveWeaponSlot(client, WEAPON_SLOT);
		DispatchSpawn(weapon);
		EquipPlayerWeapon(client, weapon);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);

		Build_PrintToChat(client, "Portal Gun equipped! [M1] Blue  [M2] Orange  [R] Clear portals");
	}

	return Plugin_Continue;
}

public Action Command_ClearPortals(int client, int args)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
	ClearClientPortals(client);
	Build_PrintToChat(client, "Your portals have been cleared.");
	if (IsHoldingPortalGun(client)) PlayVMSequence(client, VMSEQ_CLEAR, 1.0, VMSEQ_RESET_DELAY);
	return Plugin_Handled;
}


/*****************
    Identity
******************/

bool IsHoldingPortalGun(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	return (IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && IsPortalGun(iActiveWeapon));
}

bool IsPortalGun(int entity)
{
	if (GetEntSendPropOffs(entity, "m_iItemDefinitionIndex", true) <= 0) return false;
	return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex") == g_iPortalGunWeaponIndex
		&& GetEntProp(entity, Prop_Send, "m_iEntityQuality") == g_iPortalGunQuality
		&& GetEntProp(entity, Prop_Send, "m_iEntityLevel") == g_iPortalGunLevel;
}


/*****************
    View model
******************/

void ManageViewModel(int client)
{
	bool holding = IsHoldingPortalGun(client);
	int vm = EntRefToEntIndex(g_iClientVMRef[client]);

	if (holding && vm == INVALID_ENT_REFERENCE)
	{
		int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		if (IsValidEntity(iViewModel))
		{
			SetEntProp(iViewModel, Prop_Send, "m_fEffects",
				GetEntProp(iViewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
		}

		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iPortalGunVM));
	}
	else if (!holding && vm != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(vm, "Kill");
		g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
	}
}

void PlayVMSequence(int client, int sequence, float playbackRate = 1.0, float resetDelay = 0.0)
{
	int vm = EntRefToEntIndex(g_iClientVMRef[client]);
	if (!IsValidEntity(vm)) return;

	SetEntProp(vm, Prop_Send, "m_nSequence", sequence);
	SetEntPropFloat(vm, Prop_Send, "m_flPlaybackRate", playbackRate);
	SetEntPropFloat(vm, Prop_Send, "m_flCycle", 0.0); // restart from frame 0 even if re-firing same sequence

	if (sequence != VMSEQ_IDLE && resetDelay > 0.0)
	{
		g_fVMBusyUntil[client] = GetGameTime() + resetDelay;
		CreateTimer(resetDelay, Timer_ResetVMSequence, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ResetVMSequence(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if (GetGameTime() >= g_fVMBusyUntil[client] - 0.05)
		{
			PlayVMSequence(client, VMSEQ_IDLE, 1.0);
		}
	}
	return Plugin_Stop;
}

// Credits: FlaminSarge
int CreateVM(int client, int modelindex)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	if (!IsValidEntity(ent)) return -1;

	SetEntProp(ent, Prop_Send, "m_nModelIndex", modelindex);
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent);

	return ent;
}

// Credits: FlaminSarge
void TF2_EquipWearable(int client, int entity)
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
		CloseHandle(hGameConf);

		if (g_hSdkEquipWearable == INVALID_HANDLE)
		{
			SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
			return;
		}
	}

	SDKCall(g_hSdkEquipWearable, client, entity);
}


/*****************
    Input
******************/

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Continue;

	ManageViewModel(client);

	if (!IsHoldingPortalGun(client)) return Plugin_Continue;

	if ((buttons & IN_ATTACK) && !g_bIN_ATTACK[client])
	{
		g_bIN_ATTACK[client] = true;
		TryFirePortal(client, PORTAL_BLUE);
	}
	else if (!(buttons & IN_ATTACK))
	{
		g_bIN_ATTACK[client] = false;
	}

	if ((buttons & IN_ATTACK2) && !g_bIN_ATTACK2[client])
	{
		g_bIN_ATTACK2[client] = true;
		TryFirePortal(client, PORTAL_ORANGE);
	}
	else if (!(buttons & IN_ATTACK2))
	{
		g_bIN_ATTACK2[client] = false;
	}

	if ((buttons & IN_RELOAD) && !g_bIN_RELOAD[client])
	{
		g_bIN_RELOAD[client] = true;
		if (g_bPortalExists[client][0] || g_bPortalExists[client][1])
		{
			ClearClientPortals(client);
			EmitSoundToClient(client, SOUND_DENY);
			Build_PrintToChat(client, "Portals cleared.");
			PlayVMSequence(client, VMSEQ_CLEAR, 1.0, VMSEQ_RESET_DELAY);
		}
	}
	else if (!(buttons & IN_RELOAD))
	{
		g_bIN_RELOAD[client] = false;
	}

	return Plugin_Continue;
}


/*****************
    Firing
******************/

void TryFirePortal(int client, int side)
{
	if (g_fFireCD[client] > GetGameTime())
	{
		EmitSoundToClient(client, SOUND_DENY);
		return;
	}

	float eyePos[3], eyeAng[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);

	Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_Self, client);
	if (!TR_DidHit(trace))
	{
		CloseHandle(trace);
		EmitSoundToClient(client, SOUND_DENY);
		return;
	}

	int hitEntity = TR_GetEntityIndex(trace);
	if (hitEntity > 0)
	{
		char hitClass[32];
		GetEdictClassname(hitEntity, hitClass, sizeof(hitClass));
		if (!StrEqual(hitClass, "worldspawn"))
		{
			CloseHandle(trace);
			EmitSoundToClient(client, SOUND_DENY);
			Build_PrintToChat(client, "Portals can only be placed on world surfaces.");
			return;
		}
	}

	float hitPos[3], normal[3];
	TR_GetEndPosition(hitPos, trace);
	TR_GetPlaneNormal(trace, normal);
	CloseHandle(trace);

	// offset slightly off the surface so the visual doesn't z-fight.
	float spawnPos[3];
	spawnPos[0] = hitPos[0] + normal[0] * 2.0;
	spawnPos[1] = hitPos[1] + normal[1] * 2.0;
	spawnPos[2] = hitPos[2] + normal[2] * 2.0;

	float portalAng[3];
	GetVectorAngles(normal, portalAng);

	PlacePortal(client, side, spawnPos, portalAng);

	g_fFireCD[client] = GetGameTime() + g_cvfFireCooldown.FloatValue;
	EmitSoundToClient(client, (side == PORTAL_BLUE) ? SOUND_FIRE_BLUE : SOUND_FIRE_ORANGE);
	PlayVMSequence(client, (side == PORTAL_BLUE) ? VMSEQ_FIRE_BLUE : VMSEQ_FIRE_ORANGE, 1.0);

	if (g_bPortalExists[client][0] && g_bPortalExists[client][1])
	{
		Build_PrintToChat(client, "Portals linked.");
	}
}

public bool TraceFilter_Self(int entity, int mask, int data)
{
	return entity != data;
}

void PlacePortal(int client, int side, const float pos[3], const float ang[3])
{
	// kill any prior portal on this side.
	KillPortalSide(client, side);

	int sprite = CreateEntityByName("env_sprite");
	if (IsValidEntity(sprite))
	{
		char colorRGB[32];
		Format(colorRGB, sizeof(colorRGB), "%i %i %i",
			g_iPortalColor[side][0], g_iPortalColor[side][1], g_iPortalColor[side][2]);

		DispatchKeyValue(sprite, "model", SPRITE_PORTAL_GLOW);
		DispatchKeyValue(sprite, "scale", "1.6");
		DispatchKeyValue(sprite, "rendermode", "5");      // kRenderTransAdd
		DispatchKeyValue(sprite, "rendercolor", colorRGB);
		DispatchKeyValue(sprite, "renderamt", "255");
		DispatchKeyValue(sprite, "spawnflags", "1");      
		DispatchSpawn(sprite);

		float spritePos[3];
		float normal[3];
		GetAngleVectors(ang, normal, NULL_VECTOR, NULL_VECTOR);
		spritePos[0] = pos[0] + normal[0] * 4.0;
		spritePos[1] = pos[1] + normal[1] * 4.0;
		spritePos[2] = pos[2] + normal[2] * 4.0;
		TeleportEntity(sprite, spritePos, NULL_VECTOR, NULL_VECTOR);

		AcceptEntityInput(sprite, "ShowSprite");
		g_iPortalVisualRef[client][side] = EntIndexToEntRef(sprite);
	}

	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle))
	{
		DispatchKeyValue(particle, "effect_name",
			(side == PORTAL_BLUE) ? PARTICLE_PORTAL_BLUE : PARTICLE_PORTAL_ORANGE);
		DispatchKeyValue(particle, "start_active", "1");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		AcceptEntityInput(particle, "Start");
		g_iPortalParticleRef[client][side] = EntIndexToEntRef(particle);
	}

	int light = CreateEntityByName("light_dynamic");
	if (IsValidEntity(light))
	{
		char colorStr[32];
		Format(colorStr, sizeof(colorStr), "%i %i %i %i",
			g_iPortalColor[side][0], g_iPortalColor[side][1],
			g_iPortalColor[side][2], 255);

		DispatchKeyValue(light, "_light", colorStr);
		DispatchKeyValue(light, "brightness", "4");
		DispatchKeyValue(light, "distance", "180");
		DispatchKeyValue(light, "spotlight_radius", "96");
		DispatchKeyValue(light, "style", "0");
		DispatchSpawn(light);

		SetVariantString(colorStr);
		AcceptEntityInput(light, "color");
		SetVariantString("180");
		AcceptEntityInput(light, "distance");
		SetVariantString("4");
		AcceptEntityInput(light, "brightness");

		float lightPos[3];
		float lightNormal[3];
		GetAngleVectors(ang, lightNormal, NULL_VECTOR, NULL_VECTOR);
		lightPos[0] = pos[0] + lightNormal[0] * 12.0;
		lightPos[1] = pos[1] + lightNormal[1] * 12.0;
		lightPos[2] = pos[2] + lightNormal[2] * 12.0;
		TeleportEntity(light, lightPos, ang, NULL_VECTOR);

		AcceptEntityInput(light, "TurnOn");
		g_iPortalLightRef[client][side] = EntIndexToEntRef(light);
	}

	int trigger = CreateEntityByName("trigger_multiple");
	if (IsValidEntity(trigger))
	{
		DispatchKeyValue(trigger, "spawnflags", "1");
		DispatchKeyValue(trigger, "wait", "0");
		SetEntityModel(trigger, MODEL_TRIGGER_DUMMY);
		DispatchSpawn(trigger);
		ActivateEntity(trigger);

		float mins[3], maxs[3];
		mins[0] = -PORTAL_TRIGGER_HALF * 0.4;  // shallow along normal
		maxs[0] =  PORTAL_TRIGGER_HALF * 0.4;
		mins[1] = -PORTAL_TRIGGER_HALF;
		maxs[1] =  PORTAL_TRIGGER_HALF;
		mins[2] = -PORTAL_TRIGGER_HALF;
		maxs[2] =  PORTAL_TRIGGER_HALF;

		SetEntPropVector(trigger, Prop_Send, "m_vecMins", mins);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", maxs);
		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2); // SOLID_BBOX
		SetEntityRenderMode(trigger, RENDER_NONE);
		SetEntProp(trigger, Prop_Send, "m_fEffects", GetEntProp(trigger, Prop_Send, "m_fEffects") | EF_NODRAW);

		float triggerPos[3];
		float normal[3];
		GetAngleVectors(ang, normal, NULL_VECTOR, NULL_VECTOR);
		triggerPos[0] = pos[0] + normal[0] * (PORTAL_TRIGGER_HALF * 0.4 + 4.0);
		triggerPos[1] = pos[1] + normal[1] * (PORTAL_TRIGGER_HALF * 0.4 + 4.0);
		triggerPos[2] = pos[2] + normal[2] * (PORTAL_TRIGGER_HALF * 0.4 + 4.0);

		TeleportEntity(trigger, triggerPos, ang, NULL_VECTOR);

		g_iTriggerOwner[trigger] = client;
		g_iTriggerSide[trigger]  = side;
		g_iPortalTriggerRef[client][side] = EntIndexToEntRef(trigger);

		SDKHook(trigger, SDKHook_StartTouch, OnPortalStartTouch);
	}

	g_fPortalOrigin[client][side] = pos;
	g_fPortalAngles[client][side] = ang;
	g_bPortalExists[client][side] = true;
}


/*****************
    Teleport
******************/

public Action OnPortalStartTouch(int trigger, int other)
{
	if (!IsValidEntity(trigger) || !IsValidEntity(other)) return Plugin_Continue;
	if (other <= 0 || other >= sizeof(g_fEntityCooldown)) return Plugin_Continue;

	int client = g_iTriggerOwner[trigger];
	int side   = g_iTriggerSide[trigger];
	if (client <= 0 || client > MaxClients) return Plugin_Continue;

	int otherSide = (side == 0) ? 1 : 0;
	if (!g_bPortalExists[client][0] || !g_bPortalExists[client][1])
	{
		return Plugin_Continue;
	}

	if (g_fEntityCooldown[other] > GetGameTime())
	{
		return Plugin_Continue;
	}

	if (!IsEntityAllowed(other)) return Plugin_Continue;

	TeleportThroughPortal(other, g_fPortalAngles[client][side], g_fPortalOrigin[client][otherSide], g_fPortalAngles[client][otherSide]);

	g_fEntityCooldown[other] = GetGameTime() + PORTAL_COOLDOWN;
	EmitAmbientSound(SOUND_TELEPORT, g_fPortalOrigin[client][otherSide], _, SNDLEVEL_NORMAL);

	return Plugin_Continue;
}

bool IsEntityAllowed(int entity)
{
	if (entity > 0 && entity <= MaxClients)
	{
		if (!g_cvbAllowPlayers.BoolValue) return false;
		return IsClientInGame(entity) && IsPlayerAlive(entity);
	}

	char cls[64];
	GetEntityClassname(entity, cls, sizeof(cls));

	if (StrContains(cls, "prop_") == 0)
	{
		return g_cvbAllowProps.BoolValue;
	}

	if (StrContains(cls, "tf_projectile_") == 0)
	{
		return g_cvbAllowProjectiles.BoolValue;
	}

	return false;
}

void TeleportThroughPortal(int entity, const float entryAng[3], const float exitPos[3], const float exitAng[3])
{
	float entryFwd[3], entryRight[3], entryUp[3];
	float exitFwd[3], exitRight[3], exitUp[3];
	GetAngleVectors(entryAng, entryFwd, entryRight, entryUp);
	GetAngleVectors(exitAng,  exitFwd,  exitRight,  exitUp);

	// push out from exit so we don't immediately re-touch.
	float newPos[3];
	newPos[0] = exitPos[0] + exitFwd[0] * PORTAL_EXIT_PUSH;
	newPos[1] = exitPos[1] + exitFwd[1] * PORTAL_EXIT_PUSH;
	newPos[2] = exitPos[2] + exitFwd[2] * PORTAL_EXIT_PUSH;

	float curVel[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", curVel);

	float speed = GetVectorLength(curVel);
	float newVel[3] = { 0.0, 0.0, 0.0 };

	if (g_cvbPreserveMomentum.BoolValue && speed > 1.0)
	{
		float local[3];
		local[0] = -GetVectorDotProduct(curVel, entryFwd);   
		local[1] = -GetVectorDotProduct(curVel, entryRight); 
		local[2] =  GetVectorDotProduct(curVel, entryUp);

		for (int i = 0; i < 3; i++)
		{
			newVel[i] = local[0] * exitFwd[i] + local[1] * exitRight[i] + local[2] * exitUp[i];
		}

		// guarantee a minimum forward speed so the player clears the trigger.
		float outSpeed = GetVectorDotProduct(newVel, exitFwd);
		if (outSpeed < 200.0)
		{
			float add = 200.0 - outSpeed;
			newVel[0] += exitFwd[0] * add;
			newVel[1] += exitFwd[1] * add;
			newVel[2] += exitFwd[2] * add;
		}
	}
	else
	{
		newVel[0] = exitFwd[0] * 250.0;
		newVel[1] = exitFwd[1] * 250.0;
		newVel[2] = exitFwd[2] * 250.0;
	}

	if (entity > 0 && entity <= MaxClients)
	{
		float viewAng[3];
		viewAng[0] = exitAng[0];
		viewAng[1] = exitAng[1];
		viewAng[2] = 0.0;
		TeleportEntity(entity, newPos, viewAng, newVel);
	}
	else
	{
		TeleportEntity(entity, newPos, exitAng, newVel);
	}
}


/*****************
    Cleanup
******************/

void KillPortalSide(int client, int side)
{
	int visual = EntRefToEntIndex(g_iPortalVisualRef[client][side]);
	if (visual != INVALID_ENT_REFERENCE && visual > 0)
	{
		AcceptEntityInput(visual, "Kill");
	}
	g_iPortalVisualRef[client][side] = INVALID_ENT_REFERENCE;

	int particle = EntRefToEntIndex(g_iPortalParticleRef[client][side]);
	if (particle != INVALID_ENT_REFERENCE && particle > 0)
	{
		AcceptEntityInput(particle, "Stop");
		AcceptEntityInput(particle, "Kill");
	}
	g_iPortalParticleRef[client][side] = INVALID_ENT_REFERENCE;

	int light = EntRefToEntIndex(g_iPortalLightRef[client][side]);
	if (light != INVALID_ENT_REFERENCE && light > 0)
	{
		AcceptEntityInput(light, "Kill");
	}
	g_iPortalLightRef[client][side] = INVALID_ENT_REFERENCE;

	int trigger = EntRefToEntIndex(g_iPortalTriggerRef[client][side]);
	if (trigger != INVALID_ENT_REFERENCE && trigger > 0)
	{
		if (trigger > 0 && trigger < sizeof(g_iTriggerOwner))
		{
			g_iTriggerOwner[trigger] = 0;
			g_iTriggerSide[trigger]  = 0;
		}
		AcceptEntityInput(trigger, "Kill");
	}
	g_iPortalTriggerRef[client][side] = INVALID_ENT_REFERENCE;

	g_bPortalExists[client][side] = false;
}

void ClearClientPortals(int client)
{
	KillPortalSide(client, PORTAL_BLUE);
	KillPortalSide(client, PORTAL_ORANGE);
}
