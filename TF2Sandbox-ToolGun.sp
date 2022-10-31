#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.9"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <build>
#include <tf2_stocks>
#include <vphysics>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Tool Gun",
	author = PLUGIN_AUTHOR,
	description = "Allows players to manipulate a variety of functions to create different things.",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-ToolGun"
};

//Tool Gun Settings
#define WEAPON_SLOT 1

enum PhysicsGunSequence
{
	IDLE = 0,
	HOLD_IDLE,
	DRAW,
	HOLSTER,
	fire,
	ALTFIRE,
	CHARGEUP
}

bool g_bIN_ATTACK[MAXPLAYERS + 1];
bool g_bIN_ATTACK2[MAXPLAYERS + 1];
bool g_bIN_ATTACK3[MAXPLAYERS + 1];

#define MODEL_TOOLLASER	"materials/sprites/physbeam.vmt"
#define MODEL_HALOINDEX	"materials/sprites/halo01.vmt"
#define MODEL_TOOLGUNVM	"models/tf2sandbox/weapons/v_357.mdl"
#define MODEL_TOOLGUNWM	"models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.mdl"

#define SOUND_TOOLGUN_SHOOT	(GetRandomInt(0, 1))? "weapons/airboat/airboat_gun_lastshot1.wav":"weapons/airboat/airboat_gun_lastshot2.wav"
#define SONND_TOOLGUN_SELECT "buttons/button15.wav"

static const int g_iToolGunWeaponIndex = 1071;//Choose Gold Frying Pan(1071) because the player movement won't become a villager
static const int g_iToolGunQuality = 1;
static const int g_iToolGunLevel = 99-128;	//Level displays as 99 but negative level ensures this is unique

int g_iModelIndex;
int g_iHaloIndex;
int g_iToolGunVM;
int g_iToolGunWM;

int g_iAimPointRef[MAXPLAYERS + 1]; //Entity aimming point
int g_iClientVMRef[MAXPLAYERS + 1]; //Client Tool gun viewmodel ref
int g_iTools[MAXPLAYERS + 1];
float g_fToolsCD[MAXPLAYERS + 1];
bool g_bIN_RELOAD[MAXPLAYERS + 1];
int g_iDisplay[MAXPLAYERS + 1];
float g_fDisplayCD[MAXPLAYERS + 1];

//Duplicator
int g_iCopyEntityRef[MAXPLAYERS + 1];

//Color
int g_iEntityColor[MAXPLAYERS + 1];

//RenderFx
int g_iEntityRenderFx[MAXPLAYERS + 1];

//Effects
int g_iEntityEffect[MAXPLAYERS + 1];
#define PARTICLE_LIST 15
static char g_strParticle[PARTICLE_LIST][] =
{
	"burningplayer_red",
	"burningplayer_blue",
	"burningplayer_rainbow",
	"burningplayer_rainbow_blue",
	"burningplayer_rainbow_red",
	"burningplayer_rainbow_flame",
	"burningplayer_rainbow_glow_old",
	"burningplayer_rainbow_OLD",
	"burningplayer_rainbow_glow_white",
	"community_sparkle",
	"ghost_pumpkin",
	"ghost_pumpkin_flyingbits",
	"ghost_pumpkin_blueglow",
	"hwn_skeleton_glow_blue",
	"hwn_skeleton_glow_red"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_tg", Command_EquipToolGun, 0, "Equip a Tool Gun");
	//RegAdminCmd("sm_toolgun", Command_EquipToolGun, 0, "Equip a Tool Gun");
	
	RegAdminCmd("sm_seq", Command_SetSequence, 0, "Usage: !seq <sequence>");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	g_iModelIndex = PrecacheModel(MODEL_TOOLLASER);
	g_iHaloIndex = PrecacheModel(MODEL_HALOINDEX);
	g_iToolGunVM = PrecacheModel(MODEL_TOOLGUNVM);
	g_iToolGunWM = PrecacheModel(MODEL_TOOLGUNWM);

	AddFileToDownloadsTable("models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.dx80.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.dx90.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.sw.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.vvd");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/c_models/c_revolver/c_revolver.mdl");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/v_357.dx80.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/v_357.dx90.vtx");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/v_357.vvd");
	AddFileToDownloadsTable("models/tf2sandbox/weapons/v_357.mdl");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/screen.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/screen_bg.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/screen_bg.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun_exp.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun_mask.vtf");	
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun2.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun2.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun2_mask.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun3.vmt");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun3.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun3_exp.vtf");
	AddFileToDownloadsTable("materials/models/weapons/v_toolgun/toolgun3_mask.vtf");

	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav");
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav");
	PrecacheSound(SONND_TOOLGUN_SELECT);
	
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
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchHookPost);
	
	g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
	g_iAimPointRef[client] = INVALID_ENT_REFERENCE;
	g_iCopyEntityRef[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, BlockToolGunDrop);
	}
}

public void BlockToolGunDrop(int entity)
{
	if(IsValidEntity(entity) && IsToolGun(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action Command_EquipToolGun(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	Build_PrintToChat(client, "You have equipped a Tool Gun (Sandbox version)!");
	
	//Set tool gun as Active Weapon
	int weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	
	//Credits: FlaminSarge
	weapon = CreateEntityByName("tf_weapon_builder");
	if (IsValidEntity(weapon))
	{
		SetEntityModel(weapon, MODEL_TOOLGUNWM);
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_iToolGunWeaponIndex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		//Player crashes if quality and level aren't set with both methods, for some reason
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityQuality", true), g_iToolGunQuality);
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityLevel", true), g_iToolGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", g_iToolGunQuality);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", g_iToolGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		SetEntProp(weapon, Prop_Send, "m_nSkin", 1);
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iToolGunWM);
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", g_iToolGunWM, _, 0);
		SetEntProp(weapon, Prop_Send, "m_nSequence", 2);
		
		TF2_RemoveWeaponSlot(client, WEAPON_SLOT);
		DispatchSpawn(weapon);
		EquipPlayerWeapon(client, weapon);		
	}

	return Plugin_Continue;
}

public Action Command_SetSequence(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	if (args != 1)
	{
		Build_PrintToChat(client, "Usage: !seq <sequence>");
		return Plugin_Continue;
	}
	
	char strSeq[5];
	GetCmdArg(1, strSeq, sizeof(strSeq));
	
	int seq = StringToInt(strSeq);
	
	int entity = GetClientAimEntity(client);
	if (!IsValidEntity(entity))
	{
		Build_PrintToChat(client, "Please aim on your prop!");
	}
	
	SetEntProp(entity, Prop_Send, "m_nSequence", seq);
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
	SetEntPropFloat(entity, Prop_Send, "m_flCycle", 0.0);
						
	Build_PrintToChat(client, "Set Entity %i to Sequence %i", entity, seq);
	
	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		TF2_RegeneratePlayer(client);
	}
}

//ViewModel Handler
#define EF_NODRAW 32
public Action WeaponSwitchHookPost(int client, int entity)
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(IsHoldingToolGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) == INVALID_ENT_REFERENCE)
	{
		//Hide Original viewmodel
		SetEntProp(iViewModel, Prop_Send, "m_fEffects", GetEntProp(iViewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
		 
		//Create client physics gun viewmodel
		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iToolGunVM));
		
		int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
		if (IsValidEntity(iTFViewModel))
		{
			SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(DRAW));
			SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 2.0);
			
			CreateTimer(1.0, ResetPhysGunPlaybackRate, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	//Remove client physics gun viewmodel
	else if (!IsHoldingToolGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(EntRefToEntIndex(g_iClientVMRef[client]), "Kill");
	}
	
	return Plugin_Continue;
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

#define MAX_TOOLS 9
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(IsHoldingToolGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) == INVALID_ENT_REFERENCE)
	{
		//Hide Original viewmodel
		int iEffects = GetEntProp(iViewModel, Prop_Send, "m_fEffects");
		iEffects |= EF_NODRAW;
		SetEntProp(iViewModel, Prop_Send, "m_fEffects", iEffects);
		 
		//Create client toolgun viewmodel
		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iToolGunVM));
	}
	//Remove client toolgun viewmodel
	else if (!IsHoldingToolGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(EntRefToEntIndex(g_iClientVMRef[client]), "Kill");
	}	
	
	if (IsHoldingToolGun(client))
	{
		int iTFViewModel = EntRefToEntIndex(g_iClientVMRef[client]);
		
		if (buttons & IN_ATTACK || buttons & IN_ATTACK2)
		{
			if (IsValidEntity(iTFViewModel))
			{
				if (!g_bIN_ATTACK[client])
				{
					g_bIN_ATTACK[client] = true;
					
					SetEntProp(iTFViewModel, Prop_Send, "m_nSequence", view_as<PhysicsGunSequence>(HOLD_IDLE));
					SetEntPropFloat(iTFViewModel, Prop_Send, "m_flPlaybackRate", 5.0);
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
	
	if (IsHoldingToolGun(client) && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2) || (buttons & IN_ATTACK3)) && g_fToolsCD[client] <= 0.0)
	{

		g_fToolsCD[client] = 2.0;
		
		if (buttons & IN_ATTACK || buttons & IN_ATTACK2)
		{
			TE_SendLaser(client);
		}
		
		int entity = GetClientAimEntity(client);
		switch (g_iTools[client])
		{
			//Remove
			case(0):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						AcceptEntityInput(entity, "Kill");
						PrintCenterText(client, "Removed (%i)", entity);
						
						Build_SetLimit(client, -1);
					}
				}
			}
			//Resizer
			case(1):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						float fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
						if ((buttons & IN_ATTACK) && (fSize < 2.0))
						{
							fSize += 0.1;
						}
						else if ((buttons & IN_ATTACK2) && (fSize > 0.1))
						{
							fSize -= 0.1;
						}
						SetEntPropFloat(entity, Prop_Send, "m_flModelScale", fSize);
						PrintCenterText(client, "Size: %.1f", fSize);
					}
				}
			}
			//Set Collision
			case (2):
			{
				if (IsValidEntity(entity))
				{
					if (buttons & IN_ATTACK)
					{
						SetEntData(entity, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 5, 4, true);
						PrintCenterText(client, "Collide");
					}
					else if (buttons & IN_ATTACK2)
					{
						SetEntData(entity, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 2, 4, true);
						PrintCenterText(client, "No Collide");
					}
				}
			}
			//Duplicator
			case (3):
			{
				if (buttons & IN_ATTACK)
				{
					if (IsValidEntity(entity))
					{
						g_iCopyEntityRef[client] = EntIndexToEntRef(entity);
						PrintCenterText(client, "Copied! Index: %i", entity);
					}
				}
				else if (buttons & IN_ATTACK2)
				{
					int iCopyEntity = EntRefToEntIndex(g_iCopyEntityRef[client]);
					if (iCopyEntity != INVALID_ENT_REFERENCE)
					{
						int iPasteEntity = Duplicator(iCopyEntity);
						if (IsValidEntity(iPasteEntity))
						{
							if (Build_RegisterEntityOwner(iPasteEntity, client))
							{
								TeleportEntity(iPasteEntity, GetClientAimPosition(client), NULL_VECTOR, NULL_VECTOR);
								PrintCenterText(client, "Pasted! Index: %i", iPasteEntity);
							}
							else
							{
								AcceptEntityInput(iPasteEntity, "Kill");
							}
						}
					}
				}
			}
			//Set Alpha
			case (4):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						int iR, iG, iB, iA;
						GetEntityRenderColor(entity, iR, iG, iB, iA);
						
						SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
						
						if (buttons & IN_ATTACK && iA > 55)
						{
							iA -= 10;
							if (iA < 0)	iA = 55;
						}
						else if (buttons & IN_ATTACK2 && iA < 255)
						{
							iA += 10;
							if (iA > 255)	iA = 255;
						}
						SetEntityRenderColor(entity, iR, iG, iB, iA);
						PrintCenterText(client, "Alpha: %i", iA);
					}
				}
			}
			//Set Color
			case (5):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						int iR, iG, iB, iA;
						GetEntityRenderColor(entity, iR, iG, iB, iA);
						SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
						
						if (buttons & IN_ATTACK)
						{
							if (EntRefToEntIndex(g_iCopyEntityRef[client]) == INVALID_ENT_REFERENCE)
							{
								g_iCopyEntityRef[client] = EntIndexToEntRef(entity);
							}
							
							if (entity == EntRefToEntIndex(g_iCopyEntityRef[client]))
							{
								(g_iEntityColor[client] < 5)? (g_iEntityColor[client]++):(g_iEntityColor[client] = 0);
							}
							
							char strColor[10];
							switch (g_iEntityColor[client])
							{
								case (0): { iR = 128; iG = 0; iB = 128; strColor = "Purple"; }
								case (1): { iR = 255; iG = 0; iB = 0; strColor = "Red"; }
								case (2): { iR = 255; iG = 165; iB = 0; strColor = "Orange"; }
								case (3): { iR = 255; iG = 255; iB = 0; strColor = "Yellow"; }
								case (4): { iR = 0; iG = 255; iB = 0; strColor = "Green"; }
								case (5): { iR = 0; iG = 0; iB = 255; strColor = "Blue"; }
							}
	
							SetEntityRenderColor(entity, iR, iG, iB, iA);
							PrintCenterText(client, "Color: %s", strColor);
							
							g_iCopyEntityRef[client] = EntIndexToEntRef(entity);
						}
						else if (buttons & IN_ATTACK2)
						{
							iR = 255;
							iG = 255;
							iB = 255;
							
							SetEntityRenderMode(entity, RENDER_NORMAL);
							SetEntityRenderColor(entity, iR, iG, iB, iA);
							
							if (iA < 255)
							{
								SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
							}
							
							PrintCenterText(client, "Restored");
						}
					}
				}
			}
			//Set Skin
			case (6):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						int iSkin = GetEntProp(entity, Prop_Send, "m_nSkin");
						if (buttons & IN_ATTACK)
						{
							iSkin += 1;
						}
						else if (buttons & IN_ATTACK2 && iSkin > 0)
						{
							iSkin -= 1;
						}
						
						SetEntProp(entity, Prop_Send, "m_nSkin", iSkin);
						PrintCenterText(client, "Skin: %i", iSkin);
					}
				}
			}
			//Set Render Fx
			case (7):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						if (EntRefToEntIndex(g_iCopyEntityRef[client]) == INVALID_ENT_REFERENCE)
						{
							g_iCopyEntityRef[client] = EntIndexToEntRef(entity);
						}
						
						g_iEntityRenderFx[client] = view_as<int>(GetEntityRenderFx(entity));
						
						if (buttons & IN_ATTACK && entity == EntRefToEntIndex(g_iCopyEntityRef[client]))
						{
							if (g_iEntityRenderFx[client] < 16)
							{
								g_iEntityRenderFx[client]++;
							}
							else
							{
								g_iEntityRenderFx[client] = 0;
							}
						}
						else if (buttons & IN_ATTACK2 && entity == EntRefToEntIndex(g_iCopyEntityRef[client]))
						{
							if (g_iEntityRenderFx[client] > 0)
							{
								g_iEntityRenderFx[client]--;
							}
							else
							{
								g_iEntityRenderFx[client] = 16;
							}
						}
						
						char strRenderFx[40];
						switch (g_iEntityRenderFx[client])
						{
							case (0): { strRenderFx = "RENDERFX_NONE"; }
							case (1): { strRenderFx = "RENDERFX_PULSE_SLOW"; }
							case (2): { strRenderFx = "RENDERFX_PULSE_FAST"; }
							case (3): { strRenderFx = "RENDERFX_PULSE_SLOW_WIDE"; }
							case (4): { strRenderFx = "RENDERFX_PULSE_FAST_WIDE"; }
							case (5): { strRenderFx = "RENDERFX_FADE_SLOW"; }
							case (6): { strRenderFx = "RENDERFX_FADE_FAST"; }
							case (7): { strRenderFx = "RENDERFX_SOLID_SLOW"; }
							case (8): { strRenderFx = "RENDERFX_SOLID_FAST"; }
							case (9): { strRenderFx = "RENDERFX_STROBE_SLOW"; }
							case (10): { strRenderFx = "RENDERFX_STROBE_FAST"; }
							case (11): { strRenderFx = "RENDERFX_STROBE_FASTER"; }
							case (12): { strRenderFx = "RENDERFX_FLICKER_SLOW"; }
							case (13): { strRenderFx = "RENDERFX_FLICKER_FAST"; }
							case (14): { strRenderFx = "RENDERFX_NO_DISSIPATION"; }
							case (15): { strRenderFx = "RENDERFX_DISTORT"; }
							case (16): { strRenderFx = "RENDERFX_HOLOGRAM"; }
						}
						
						SetEntityRenderFx(entity, view_as<RenderFx>(g_iEntityRenderFx[client]));
						PrintCenterText(client, "RenderFx: %s (%i)", strRenderFx, g_iEntityRenderFx[client]);
						
						g_iCopyEntityRef[client] = EntIndexToEntRef(entity);
					}
				}
			}
			//Set Effect
			case (8):
			{
				if (IsValidEntity(entity))
				{
					if (buttons & IN_ATTACK)
					{
						TE_ParticleToAll(g_strParticle[g_iEntityEffect[client]], _, _, _, entity, -1, -1, true);
						PrintCenterText(client, "Apply : %s", g_strParticle[g_iEntityEffect[client]]);
					}
					
					if (buttons & IN_ATTACK2)
					{
						TE_ParticleToAll("ping_circle", _, _, _, entity, -1, -1, true);
						PrintCenterText(client, "Remove : %s", g_strParticle[g_iEntityEffect[client]]);
					}
				}
				
				if (buttons & IN_ATTACK3)
				{
					g_iEntityEffect[client]++;
					
					if (g_iEntityEffect[client] >= PARTICLE_LIST)
					{
						g_iEntityEffect[client] = 0;
					}
				}
			}
			//Set Sequences
			case (9):
			{
				if (IsValidEntity(entity))
				{
					if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))
					{
						int iSequence = GetEntProp(entity, Prop_Send, "m_nSequence");
						if (buttons & IN_ATTACK)
						{
							iSequence += 1;
						}
						else if (buttons & IN_ATTACK2 && iSequence > 0)
						{
							iSequence -= 1;
						}
						
						SetEntProp(entity, Prop_Send, "m_nSequence", iSequence);
						SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
						SetEntPropFloat(entity, Prop_Send, "m_flCycle", 0.0);
						
						PrintCenterText(client, "Sequence: %i", iSequence);
					}
				}
			}
			//Set Animation
			case (10):
			{
				if (IsValidEntity(entity))
				{
					if (buttons & IN_ATTACK)
					{	
						SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
					}
					else if (buttons & IN_ATTACK2)
					{
						SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 0.0);
					}
				}
			}
			//Set Pose
			case (11):
			{
				if (IsValidEntity(entity))
				{
					float pose = GetEntPropFloat(entity, Prop_Send, "m_flCycle");
					
					if (buttons & IN_ATTACK)
					{
						pose += 10.0;
						
						SetEntProp(entity, Prop_Send, "m_bClientSideAnimation", 1);
						SetEntPropFloat(entity, Prop_Send, "m_flCycle", pose);
					}
					else if (buttons & IN_ATTACK2)
					{
						pose -= 10.0;
						
						SetEntPropFloat(entity, Prop_Send, "m_flCycle", pose);
					}
					
					PrintCenterText(client, "Pose: %.1f", pose);
				}
			}
		}
	}
	else if (g_fToolsCD[client] > 0.0)
	{
		g_fToolsCD[client] -= 0.1;
	}
	
	if (IsHoldingToolGun(client))
	{
		//Switch tools
		if (buttons & IN_RELOAD && !g_bIN_RELOAD[client])
		{
			g_bIN_RELOAD[client] = true;
			
			EmitSoundToClient(client, SONND_TOOLGUN_SELECT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			
			if (buttons & IN_DUCK)
			{
				(g_iTools[client] > 0)? (g_iTools[client]--) : (g_iTools[client] = MAX_TOOLS);
			}
			else
			{
				(g_iTools[client] < MAX_TOOLS)? (g_iTools[client]++) : (g_iTools[client] = 0);
			}
			
			//Reset value
			if (g_iTools[client] == 3)
			{
				g_iCopyEntityRef[client] = INVALID_ENT_REFERENCE;
			}
			else if (g_iTools[client] == 5)
			{
				g_iEntityColor[client] = 0;
			}
			else if (g_iTools[client] == 7)
			{
				g_iEntityRenderFx[client] = 0;
			}
			else if (g_iTools[client] == 8)
			{
				g_iEntityEffect[client] = 0;
			}
		}
		else if (!(buttons & IN_RELOAD))
		{
			g_bIN_RELOAD[client] = false;
		}
		
		char display[170];
		Format(display, sizeof(display), "------------------------\n%s\n------------------------\n[MOUSE1] %s\n[MOUSE2] %s\n[RELOAD] Next Tool (%i)"
		, GetToolDisplay(g_iTools[client], client), GetToolMouse1(g_iTools[client]), GetToolMouse2(g_iTools[client]), g_iTools[client]);
		
		if (g_iTools[client] == 8)
		{
			PrintCenterText(client, "Current Effect : %s", g_strParticle[g_iEntityEffect[client]]);
		}
		
		SetHudTextParams(0.75, 0.45, 0.05, 255, 255, 255, 150, 0, 0.0, 0.0, 0.0);
		
		if (!(buttons & IN_SCORE))
		{
			ShowHudText(client, -1, display);
		}
	}
	
	return Plugin_Continue;
}

/********************
		Stock
*********************/
bool IsHoldingToolGun(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	return (IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && IsToolGun(iActiveWeapon));
}

//Credits: FlaminSarge
bool IsToolGun(int entity) 
{
	if (GetEntSendPropOffs(entity, "m_iItemDefinitionIndex", true) <= 0) 
	{
		return false;
	}
	return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex") == g_iToolGunWeaponIndex
		&& GetEntProp(entity, Prop_Send, "m_iEntityQuality") == g_iToolGunQuality
		&& GetEntProp(entity, Prop_Send, "m_iEntityLevel") == g_iToolGunLevel;
}

void TE_SendLaser(int client)
{
	EmitSoundToClient(client, SOUND_TOOLGUN_SHOOT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		
	TE_SetupBeamRingPoint(GetClientAimPosition(client), 5.0, 20.0, g_iModelIndex, g_iHaloIndex, 0, 10, 0.5, 3.0, 10.0, {255, 255, 255, 255}, 10, 0);
	TE_SendToAll();
	
	int clientvm = EntRefToEntIndex(g_iClientVMRef[client]);
	int iAimPoint = EntRefToEntIndex(g_iAimPointRef[client]);
	if (clientvm != INVALID_ENT_REFERENCE)
	{
		if (iAimPoint == INVALID_ENT_REFERENCE)
		{
			iAimPoint = CreateAimPoint();
			g_iAimPointRef[client] = EntIndexToEntRef(iAimPoint);
		}
		
		TeleportEntity(iAimPoint, GetClientAimPosition(client), NULL_VECTOR, NULL_VECTOR);
		
		TE_SetupBeamEnts(iAimPoint, EntRefToEntIndex(g_iClientVMRef[client]), g_iModelIndex, g_iHaloIndex, 0, 15, 0.1, 1.0, 1.0, 1, 0.0, {255, 255, 255, 255}, 10, 20);
		TE_SendToClient(client);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (client != i && IsClientInGame(i))
			{
				TE_SetupBeamEnts(client, iAimPoint, g_iModelIndex, g_iHaloIndex, 0, 15, 0.1, 1.0, 1.0, 1, 0.0, {255, 255, 255, 255}, 10, 20);
				TE_SendToClient(i);
			}
		}
	}
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

int CreateAimPoint()
{
	int iAimPoint = CreateEntityByName("prop_dynamic_override");
	
	SetEntityModel(iAimPoint, MODEL_TOOLGUNWM);
	
	SetEntPropFloat(iAimPoint, Prop_Send, "m_flModelScale", 0.0);
	
	DispatchSpawn(iAimPoint);
	
	return iAimPoint;
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

float[] GetClientAimPosition(int client)
{
	Handle trace = TR_TraceRayFilterEx(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	float endpos[3];
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(endpos, trace);
	}
	
	CloseHandle(trace);
	
	return endpos;
}

stock float[] GetClientAimNormal(int client)
{
	Handle trace = TR_TraceRayFilterEx(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	float endnormal[3];
	if(TR_DidHit(trace))
	{
		TR_GetPlaneNormal(trace, endnormal);
	}
	
	CloseHandle(trace);
	return endnormal;
}

int GetClientAimEntity(int client)
{
	Handle trace = TR_TraceRayFilterEx(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	if(TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (entity > 0 && (Build_ReturnEntityOwner(entity) == client || CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)))
		{
			char szClass[32];
			GetEntityClassname(entity, szClass, sizeof(szClass));
			
			if (StrContains(szClass, "prop_") == -1)
			{
				return -1;
			}
			
			CloseHandle(trace);
			return entity;
		}
	}
	
	CloseHandle(trace);
	return -1;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	return (IsValidEntity(entity) && entity != client && MaxClients < entity);
}

int Duplicator(int iEntity)
{
	//Get Value
	float fOrigin[3], fAngles[3];
	char szModel[64], szName[128], szClass[32];
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
		
		return iNewEntity;
	}
	
	return -1;
}

stock bool SetAnimation(int entity)
{
	char szModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	
	if (StrContains(szModel, "pickup_powerup_") != -1
	|| StrEqual(szModel, "models/items/tf_gift.mdl")
	|| StrEqual(szModel, "models/props_halloween/halloween_gift.mdl")
	|| StrEqual(szModel, "models/flag/briefcase.mdl")
	|| StrEqual(szModel, "models/flag/ticket_case.mdl")
	|| StrEqual(szModel, "models/props_doomsday/australium_container.mdl")
	|| StrEqual(szModel, "models/buggy.mdl"))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		SetVariantString("spin");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");
		
		return true;
	}
	else if (StrContains(szModel, "ammopack_") != -1
	|| StrContains(szModel, "medkit_") != -1
	|| StrContains(szModel, "currencypack_") != -1
	|| StrEqual(szModel, "models/items/plate_robo_sandwich.mdl")
	|| StrEqual(szModel, "models/items/plate_sandwich_xmas.mdl")
	|| StrEqual(szModel, "models/items/plate.mdl")
	|| StrEqual(szModel, "models/effects/sentry1_muzzle/sentry1_muzzle.mdl"))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		SetVariantString("idle");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");
		
		return true;
	}
	else if (StrContains(szModel, "models/bots/boss_bot/tank_track") != -1)
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		SetVariantString("forward");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");
		
		return true;
	}
	else if (StrEqual(szModel, "models/bots/boss_bot/boss_tank.mdl"))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		SetVariantString("movement");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");
		
		return true;
	}
	else if (StrEqual(szModel, "models/effects/splode.mdl")
	|| StrEqual(szModel, "models/effects/splodeglass.mdl"))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		SetVariantString("anim");
		AcceptEntityInput(entity, "SetAnimation");
		AcceptEntityInput(entity, "Enable");
		
		return true;
	}
	
	return false;
}

#define SPACE "                    "
char[] GetToolDisplay(int tool, int client)
{
	char toolname[61];
	switch (tool)
	{
		case (0):toolname = "       Remover      ";
		case (1):toolname = "       Resizer      ";
		case (2):toolname = "    Set Collision   ";
		case (3):toolname = "      Duplicator    ";
		case (4):toolname = "      Set Alpha     ";
		case (5):toolname = "      Set Color     ";
		case (6):toolname = "      Set Skin      ";
		case (7):toolname = "    Set Render Fx   ";
		case (8):toolname = "     Set Effect     ";
		case (9):toolname = "    Set Sequence    ";
		case (10):toolname = "    Set Animation   ";
	}
	
	Format(toolname, sizeof(toolname), "%s%s%s", SPACE, toolname, SPACE);

	char display[26] = "";
	for (int i = g_iDisplay[client]; i < (g_iDisplay[client] + 25); i++)
	{
		Format(display, sizeof(display), "%s%s", display, toolname[i]);
	}
	
	if (g_fDisplayCD[client] <= 0.0)
	{
		g_fDisplayCD[client] = 1.0;
		(g_iDisplay[client] < 35)? (g_iDisplay[client]++) : (g_iDisplay[client] = 0);
	}
	else if (g_fDisplayCD[client] > 0.0)
	{
		g_fDisplayCD[client] -= 0.1;
	}
	
	return display;
}

char[] GetToolMouse1(int tool)
{
	char mouse1[30];
	switch (tool)
	{
		case (0): mouse1 = "Remove";
		case (1): mouse1 = "Larger";
		case (2): mouse1 = "Collide";
		case (3): mouse1 = "Copy";
		case (4): mouse1 = "More Transparent";
		case (5): mouse1 = "Next Color";
		case (6): mouse1 = "Next Skin";
		case (7): mouse1 = "Next Render Fx";
		case (8): mouse1 = "Apply Effect";
		case (9): mouse1 = "Next Sequence";
		case (10): mouse1 = "Enable Animation";
	}
	
	return mouse1;
}

char[] GetToolMouse2(int tool)
{
	char mouse2[60];
	switch (tool)
	{
		case (0): mouse2 = "Remove";
		case (1): mouse2 = "Smaller";
		case (2): mouse2 = "No Collide";
		case (3): mouse2 = "Paste";
		case (4): mouse2 = "More Visible";
		case (5): mouse2 = "Restore";
		case (6): mouse2 = "Previous Skin";
		case (7): mouse2 = "Previous Render Fx";
		case (8): mouse2 = "Remove Effect\n[MOUSE3] Change Effect";
		case (9): mouse2 = "Previous Sequence";
		case (10): mouse2 = "Disable Animation";
	}
	
	return mouse2;
}

void TE_ParticleToAll(char[] Name, float origin[3] = NULL_VECTOR, float start[3] = NULL_VECTOR, float angles[3] = NULL_VECTOR, int entindex = -1, int attachtype = -1,int attachpoint = -1, bool resetParticles = true)
{
    // find string table
    int tblidx = FindStringTable("ParticleEffectNames");
    if (tblidx == INVALID_STRING_TABLE) 
    {
        LogError("Could not find string table: ParticleEffectNames");
        return;
    }
    
    // find particle index
    char tmp[256];
    int count = GetStringTableNumStrings(tblidx);
    int stridx = INVALID_STRING_INDEX;
    
    for (int i = 0; i < count; i++)
    {
        ReadStringTable(tblidx, i, tmp, sizeof(tmp));
        if (StrEqual(tmp, Name, false))
        {
            stridx = i;
            break;
        }
    }
    
    if (stridx == INVALID_STRING_INDEX)
    {
        LogError("Could not find particle: %s", Name);
        return;
    }
    
    TE_Start("TFParticleEffect");
    TE_WriteFloat("m_vecOrigin[0]", origin[0]);
    TE_WriteFloat("m_vecOrigin[1]", origin[1]);
    TE_WriteFloat("m_vecOrigin[2]", origin[2]);
    TE_WriteFloat("m_vecStart[0]", start[0]);
    TE_WriteFloat("m_vecStart[1]", start[1]);
    TE_WriteFloat("m_vecStart[2]", start[2]);
    TE_WriteVector("m_vecAngles", angles);
    TE_WriteNum("m_iParticleSystemIndex", stridx);
    
    if (entindex != -1)
    {
        TE_WriteNum("entindex", entindex);
    }
    
    if (attachtype != -1)
    {
        TE_WriteNum("m_iAttachType", attachtype);
    }
    
    if (attachpoint != -1)
    {
        TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
    }
    
    TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);    
    TE_SendToAll();
}