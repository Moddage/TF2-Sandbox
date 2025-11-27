#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.4"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Security Camera",
	author = PLUGIN_AUTHOR,
	description = "The security camera will be moving around to ensure safety",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-SecurityCamera"
};

#define MAX_CAMERA 10
#define CONTROL_CAMERA 100
#define SOUND_SNAPSHOT "misc/tf_camera_07.wav"

#define HIDEHUD_ALL ( 1<<2 )

ConVar cvfRotateSpeed;
ConVar cvfMaxTraceClient;
ConVar cvbAutoSnapshot;

#define ENTITY_CAMERA 0
#define ENTITY_OPOINT 1
int g_iCameraList[MAXPLAYERS + 1][MAX_CAMERA][2];

bool g_bIN_SCORE[MAXPLAYERS + 1];
bool g_bIN_ATTACK[MAXPLAYERS + 1];
bool g_bIN_ATTACK2[MAXPLAYERS + 1];
bool g_bIN_ATTACK3[MAXPLAYERS + 1];

bool g_bInConsole[MAXPLAYERS + 1];
int g_iInConsoleID[MAXPLAYERS + 1];
int g_iConsoleOwnerRef[MAXPLAYERS + 1];
int g_iClientWeaponRef[MAXPLAYERS + 1];

float g_fCoolDown[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_securitycamera_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_cam", Command_SecurityCameraActivate, 0, "Activate the security camera");
	RegAdminCmd("sm_camauto", Command_SecurityCameraActivateAuto, 0, "Activate the all the security camera");
	RegAdminCmd("sm_camall", Command_SecurityCameraActivateAuto, 0, "Activate the all the security camera");
	
	cvfRotateSpeed = CreateConVar("sm_tf2sb_cam_rotatespeed", "4.00", "(1.00 - 10.00) Security Camera rotate speed", 0, true, 1.00, true, 10.00);
	cvfMaxTraceClient = CreateConVar("sm_tf2sb_cam_maxtrace", "300.0", "(100.0 - 1000.0) Security Camera max trace client distance", 0, true, 100.0, true, 1000.0);
	cvbAutoSnapshot = CreateConVar("sm_tf2sb_cam_autosnapshot", "0", "(0 or 1) Security Camera automatic snapshot", 0, true, 0.0, true, 1.0);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
	PrecacheSound(SOUND_SNAPSHOT);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	for (int i = 0; i < MAX_CAMERA; i++)
	{
		g_iCameraList[client][i][ENTITY_CAMERA] = INVALID_ENT_REFERENCE;
		g_iCameraList[client][i][ENTITY_OPOINT] = INVALID_ENT_REFERENCE;
	}
	
	g_fCoolDown[client] = 0.0;
	
	SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public void OnPreThink(int client)
{
	if (!g_bInConsole[client])
	{
		return;
	}
	
	//Block attack1 nad attack2 while in camera
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(iWeapon))
	{
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.0);
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if (g_bInConsole[client])
		{
			LeaveCamera(client);
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if (g_bInConsole[client])
		{
			LeaveCamera(client);
		}
	}
}

#define HUD_TEXT "%N's Security Camera\nID: %i  Name: %s\n \n[MOUSE1]: Next  [MOUSE2]: Back\n[MOUSE3]: Snapshot  [TAB]: Quit"
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int console = GetClientAimConsole(client);
	if (console > MaxClients && IsValidEntity(console))
	{
		if (!g_bInConsole[client])
		{
			int owner = Build_ReturnEntityOwner(console);
			if (owner != -1 && HasCamera(owner))
			{
				SetHudTextParams(-1.0, 0.55, 0.01, 124, 252, 0, 255, 1, 6.0, 0.5, 0.5);
				ShowHudText(client, -1, "Press [TAB] to view the Security Cameras");
			}
		}
	}
	
	if (buttons & IN_SCORE)
	{
		if (!g_bIN_SCORE[client])
		{
			g_bIN_SCORE[client] = true;
			
			if (g_bInConsole[client])
			{
				LeaveCamera(client);
			}
			else if (console > MaxClients && IsValidEntity(console))
			{
				//Get console owner
				int owner = Build_ReturnEntityOwner(console);
				g_iConsoleOwnerRef[client] = GetClientUserId(owner);
				
				if (HasCamera(owner))
				{
					g_bInConsole[client] = true;
					
					//Save current holding weapon and set current weapon to -1
					int clientweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					
					if (IsValidEntity(clientweapon))
					{
						g_iClientWeaponRef[client] = EntIndexToEntRef(clientweapon);
					}
					
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
					
					//Hide HUD
					SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_ALL);
					
					//Remove fisheye
					TF2_RemoveCondition(client, TFCond_Zoomed);
					
					g_iInConsoleID[client] = GetNextCameraID(owner, 0);
					int point = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_OPOINT]);
					if (point != INVALID_ENT_REFERENCE)
					{
						SetClientViewEntity(client, point);
						
						int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
						PrintCenterText(client, HUD_TEXT, owner, g_iInConsoleID[client]+1, GetCameraName(camera));
					}
				}
			}
		}
	}
	else
	{
		g_bIN_SCORE[client] = false;
	}
	
	if (g_bInConsole[client])
	{
		//Fix client pos and angle
		SetEntityFlags(client, (GetEntityFlags(client) | FL_FROZEN));
		
		//Switch to next camera
		if (buttons & IN_ATTACK)
		{
			if (!g_bIN_ATTACK[client])
			{
				g_bIN_ATTACK[client] = true;
				
				if (g_iInConsoleID[client] > MAX_CAMERA-1) g_iInConsoleID[client] = 0;
				
				int owner = GetClientOfUserId(g_iConsoleOwnerRef[client]);
				if (owner != 0)
				{
					int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
					if (camera != INVALID_ENT_REFERENCE)
					{
						SetEntProp(camera, Prop_Send, "m_nSkin", 1);
					}
					
					g_iInConsoleID[client] = GetNextCameraID(owner, g_iInConsoleID[client]);
					
					int point = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_OPOINT]);
					if (point != INVALID_ENT_REFERENCE)
					{
						SetClientViewEntity(client, point);
						
						camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
						PrintCenterText(client, HUD_TEXT, owner, g_iInConsoleID[client]+1, GetCameraName(camera));
					}
					else
					{
						//When camera removed
						LeaveCamera(client);
					}
				}
				else
				{
					//When camera owner left
					LeaveCamera(client);
				}
			}
		}
		else
		{
			g_bIN_ATTACK[client] = false;
		}
		
		//Switch camera backward
		if (buttons & IN_ATTACK2)
		{
			if (!g_bIN_ATTACK2[client])
			{
				g_bIN_ATTACK2[client] = true;
					
				if (g_iInConsoleID[client] < 0) g_iInConsoleID[client] = MAX_CAMERA-1;
				
				int owner = GetClientOfUserId(g_iConsoleOwnerRef[client]);
				if (owner != 0)
				{
					int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
					if (camera != INVALID_ENT_REFERENCE)
					{
						SetEntProp(camera, Prop_Send, "m_nSkin", 1);
					}
					
					g_iInConsoleID[client] = GetBackCameraID(owner, g_iInConsoleID[client]);
					
					int point = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_OPOINT]);
					if (point != INVALID_ENT_REFERENCE)
					{
						SetClientViewEntity(client, point);
						
						camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
						PrintCenterText(client, HUD_TEXT, owner, g_iInConsoleID[client]+1, GetCameraName(camera));
					}
					else
					{
						//When camera removed
						LeaveCamera(client);
					}
				}
				else
				{
					//When camera owner left
					LeaveCamera(client);
				}
			}
		}
		else
		{
			g_bIN_ATTACK2[client] = false;
		}
		
		//Take a snapshot
		if (buttons & IN_ATTACK3)
		{
			if (!g_bIN_ATTACK3[client])
			{
				g_bIN_ATTACK3[client] = true;
				
				int owner = GetClientOfUserId(g_iConsoleOwnerRef[client]);
				if (owner == client)
				{
					int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
					int point = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_OPOINT]);
					if (camera != INVALID_ENT_REFERENCE && point != INVALID_ENT_REFERENCE)
					{
						if (g_fCoolDown[client] <= GetGameTime())
						{
							g_fCoolDown[client] = GetGameTime() + 1.0;
							
							float fcamerapos[3];
							GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcamerapos);
							
							int[] clients = new int[MaxClients + 1];
							clients[0] = client;
							
							int clientcount = 1;
							for (int i = 1; i <= MaxClients; i++)
							{
								if (!IsClientInGame(i) || i == client)
								{
									continue;
								}
								
								if (!CanSeeClient(i, camera))
								{
									continue;
								}
								
								float fclientpos[3];
								GetEntPropVector(i, Prop_Send, "m_vecOrigin", fclientpos);
									
								if (GetVectorDistance(fcamerapos, fclientpos) <= 500.0)
								{
									clients[clientcount] = i;
									
									clientcount++;
								}
							}
							
							CreateSnapShot(camera, point, clients, clientcount);
						}
					}
				}
			}
		}
		else
		{
			g_bIN_ATTACK3[client] = false;
		}
		
		int owner = GetClientOfUserId(g_iConsoleOwnerRef[client]);
		if (owner != 0)
		{
			int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
			if (camera != INVALID_ENT_REFERENCE)
			{
				if (owner == client)
				{
					SetEntProp(camera, Prop_Send, "m_nSkin", CONTROL_CAMERA);
					
					float fcamang[3];
					GetEntPropVector(camera, Prop_Data, "m_angRotation", fcamang);
					
					fcamang[1] -= float(mouse[0]) / 20.0;
					fcamang[2] -= float(mouse[1]) / 20.0;
					
					if (buttons & IN_FORWARD)
					{
						fcamang[2] += 1.0;
					}
					
					if (buttons & IN_BACK)
					{
						fcamang[2] -= 1.0;
					}
					
					if (buttons & IN_MOVELEFT)
					{
						fcamang[1] += 1.0;
					}
					
					if (buttons & IN_MOVERIGHT)
					{
						fcamang[1] -= 1.0;
					}
					
					DispatchKeyValueVector(camera, "angles", fcamang); 
				}
			}
			else
			{
				//When camera removed
				LeaveCamera(client);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Command_SecurityCameraActivate(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	int camera = GetClientAimTarget(client, false);
	if (camera <= MaxClients || !IsValidEntity(camera))
	{
		Build_PrintToChat(client, "Invalid target! Please aim at the security camera!");
		return Plugin_Continue;
	}

	if(!IsSecurityCamera(camera))
	{
		Build_PrintToChat(client, "Invalid target! Please aim at the security camera!");
		return Plugin_Continue;
	}
	
	if (IsCameraActivated(client, camera))
	{
		Build_PrintToChat(client, "The Security Camera had already activated!");
		return Plugin_Continue;
	}
	
	int bracket = GetClosestBracketIndex(client, camera);
	if (bracket == -1 || !IsValidEntity(bracket))
	{
		Build_PrintToChat(client, "Fail to find Security Camera Bracket! Please spawn Security Camera Bracket near the Security Camera!");
		return Plugin_Continue;
	}
	
	float fbracketpos[3], fbracketang[3];
	GetEntPropVector(bracket, Prop_Send, "m_vecOrigin", fbracketpos);
	GetEntPropVector(bracket, Prop_Data, "m_angRotation", fbracketang);
	fbracketang[2] = 0.0;
	TeleportEntity(camera, fbracketpos, fbracketang, NULL_VECTOR);

	if (!SetCameraActivated(client, camera, CreateObserverPoint(camera)))
	{
		Build_PrintToChat(client, "You have reached %i Security Camera limit!", MAX_CAMERA);
		return Plugin_Continue;
	}
	
	SetEntProp(camera, Prop_Send, "m_nSkin", 1);

	Handle dp;
	CreateDataTimer(0.0, Timer_ActivateCamera, dp);
	WritePackCell(dp, EntIndexToEntRef(camera));
	WritePackCell(dp, EntIndexToEntRef(bracket));
	WritePackCell(dp, -1);
	WritePackCell(dp, false);
	
	return Plugin_Continue;
}

public Action Command_SecurityCameraActivateAuto(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	int camera_count = 0;
	int camera = -1;
	while ((camera = FindEntityByClassname(camera, "prop_dynamic")) != -1) 
	{
		if (Build_ReturnEntityOwner(camera) != client)
		{
			continue;
		}
		
		if(!IsSecurityCamera(camera))
		{
			continue;
		}
		
		if (IsCameraActivated(client, camera))
		{
			camera_count++;
			continue;
		}
		
		int bracket = GetClosestBracketIndex(client, camera);
		if (bracket == -1 || !IsValidEntity(bracket))
		{
			continue;
		}
		
		float fbracketpos[3], fbracketang[3];
		GetEntPropVector(bracket, Prop_Send, "m_vecOrigin", fbracketpos);
		GetEntPropVector(bracket, Prop_Data, "m_angRotation", fbracketang);
		fbracketang[2] = 0.0;
		TeleportEntity(camera, fbracketpos, fbracketang, NULL_VECTOR);
		
		if (!SetCameraActivated(client, camera, CreateObserverPoint(camera)))
		{
			break;
		}
		
		SetEntProp(camera, Prop_Send, "m_nSkin", 1);
		
		Handle dp;
		CreateDataTimer(0.0, Timer_ActivateCamera, dp);
		WritePackCell(dp, EntIndexToEntRef(camera));
		WritePackCell(dp, EntIndexToEntRef(bracket));
		WritePackCell(dp, -1);
		WritePackCell(dp, false);
		
		camera_count++;
	}
	
	Build_PrintToChat(client, "You have activated %i Security Camera!", camera_count);
	
	return Plugin_Continue;
}

public Action Timer_ActivateCamera(Handle timer, Handle dp)
{
	ResetPack(dp);
	int camera = EntRefToEntIndex(ReadPackCell(dp));
	int bracket = EntRefToEntIndex(ReadPackCell(dp));
	
	int aimclient = ReadPackCell(dp);
	if (aimclient != -1)
	{
		aimclient = GetClientOfUserId(aimclient);
	}
	
	bool rotateright = ReadPackCell(dp);
	
	if (camera == INVALID_ENT_REFERENCE || bracket == INVALID_ENT_REFERENCE)
	{
		return Plugin_Continue;
	}
	
	float fcamerapos[3], fbracketpos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcamerapos);
	GetEntPropVector(bracket, Prop_Send, "m_vecOrigin", fbracketpos);
	
	//Deactivate when carema or bracket position were not the same
	if (fcamerapos[0] != fbracketpos[0] || fcamerapos[1] != fbracketpos[1] || fcamerapos[2] != fbracketpos[2])
	{
		RemoveCameraActivated(camera);

		return Plugin_Continue;
	}
	
	int iMode = GetEntProp(camera, Prop_Send, "m_nSkin");
	int client = GetClosestClient(camera);
	if (iMode != CONTROL_CAMERA)
	{
		if (client != -1)
		{	
			float fclientpos[3];
			GetClientEyePosition(client, fclientpos);
			
			float vector[3];
			MakeVectorFromPoints(fcamerapos, fclientpos, vector);
			
			float faimangle[3];
			GetVectorAngles(vector, faimangle);
	
			faimangle[2] = faimangle[0]*-1;
			faimangle[1] -= 90.0;
			faimangle[0] = 0.0;
			
			DispatchKeyValueVector(camera, "angles", faimangle);
			
			if (aimclient != client && cvbAutoSnapshot.BoolValue)
			{
				aimclient = client;
				
				int clients[2];
				clients[0] = client;
				
				int point = GetCameraObserverPoint(camera);
				if (point != INVALID_ENT_REFERENCE)
				{
					CreateSnapShot(camera, point, clients, 1);
				}
			}
		}
		else
		{
			//aimclient = -1;
			
			float fcamang[3];
			GetEntPropVector(camera, Prop_Data, "m_angRotation", fcamang);
			
			float fbracketang[3];
			GetEntPropVector(bracket, Prop_Data, "m_angRotation", fbracketang);
			
			float angdiff = fbracketang[1] - fcamang[1];
			if (angdiff > 45.0)
			{
				rotateright = true;
			}
			else if (angdiff < -45.0)
			{
				rotateright = false;
			}
		
			float rotateangle;
			rotateangle = (rotateright) ? cvfRotateSpeed.FloatValue : cvfRotateSpeed.FloatValue*-1;
			
			fcamang[1] += rotateangle;
			
			DispatchKeyValueVector(camera, "angles", fcamang);
		}
	}

	CreateDataTimer(0.1, Timer_ActivateCamera, dp);
	WritePackCell(dp, EntIndexToEntRef(camera));
	WritePackCell(dp, EntIndexToEntRef(bracket));
	
	if (aimclient > 0 && aimclient <= MaxClients && IsClientInGame(aimclient))
	{
		WritePackCell(dp, GetClientUserId(aimclient));
	}
	else
	{
		WritePackCell(dp, -1);
	}
	
	WritePackCell(dp, rotateright);
	
	return Plugin_Continue;
}

int GetClosestBracketIndex(int client, int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	int bracket = -1;
	float shortestdistance = 30.0;
	char strModel[64];
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1) 
	{
		if (Build_ReturnEntityOwner(entity) != client)
		{
			continue;
		}
		
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		if(!StrEqual(strModel, "models/props_spytech/security_camera_bracket.mdl"))
		{
			continue;
		}
		
		float fbrapos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fbrapos);
		
		float distance = GetVectorDistance(fcampos, fbrapos);
		if (distance < shortestdistance)
		{
			bracket = entity;
			shortestdistance = distance;
		}
	}
	
	return bracket;
}

int GetClosestClient(int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	int client = -1;
	float shortestdistance = cvfMaxTraceClient.FloatValue;
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			float fclientpos[3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", fclientpos);
			
			float distance = GetVectorDistance(fcampos, fclientpos);
			if (distance < shortestdistance)
			{
				if (!CanSeeClient(i, camera))
				{
					continue;
				}
				
				client = i;
				shortestdistance = distance;
			}
		}
	}

	return client;
}

int GetClientAimConsole(int client)
{
	int console = GetClientAimTarget(client, false);
	if (console > MaxClients && IsValidEntity(console))
	{
		//Get the entity model to check whether is securitybank or not
		char strModel[64];
		GetEntPropString(console, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		if (StrEqual(strModel, "models/props_spytech/computer_screen_bank.mdl") || StrEqual(strModel, "models/props_lab/securitybank.mdl"))
		{
			//Get the disance between client and console
			float fconpos[3], fclientpos[3];
			GetEntPropVector(console, Prop_Send, "m_vecOrigin", fconpos);
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", fclientpos);
			
			if (GetVectorDistance(fconpos, fclientpos) < 150.0)
			{
				return console;
			}
		}
	}
	
	return -1;
}

bool CanSeeClient(int client, int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	float fclientpos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fclientpos);
	fclientpos[2] += 50.0;
	
	Handle trace = TR_TraceRayFilterEx(fcampos, fclientpos, MASK_SHOT, RayType_EndPoint, TraceEntityFilter, camera);
	if (TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (entity > 0 && entity <= MaxClients)
		{
			CloseHandle(trace);
			
			return true;
		}
	}
	
	CloseHandle(trace);
	
	return false;
}

float[] GetPointAimPosition(float pos[3], float angles[3], float maxtracedistance, int camera)
{
	Handle trace = TR_TraceRayFilterEx(pos, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, camera);

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
			CloseHandle(trace);
			return endpos;
		}
		
		CloseHandle(trace);
		return endpos;
	}
	
	CloseHandle(trace);
	return pos;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	char strModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
	
	return (StrContains(strModel, "security_camera") == -1);
}

char[] GetCameraName(int camera)
{
	char strName[128];
	GetEntPropString(camera, Prop_Data, "m_iName", strName, sizeof(strName));
	ReplaceString(strName, sizeof(strName), "\n", "");

	return strName;
}

int GetCameraObserverPoint(int camera)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		for (int j = 0; j < MAX_CAMERA; j++)
		{
			if (EntRefToEntIndex(g_iCameraList[i][j][ENTITY_CAMERA]) == camera)
			{
				return EntRefToEntIndex(g_iCameraList[i][j][ENTITY_OPOINT]);
			}
		}
	}
	
	return -1;
}

bool IsSecurityCamera(int entity)
{
	char strModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
	
	return StrEqual(strModel, "models/props_spytech/security_camera.mdl");
}

int CreateObserverPoint(int camera)
{
	float fcampos[3], fcamang[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	GetEntPropVector(camera, Prop_Data, "m_angRotation", fcamang);
	
	int point = CreateEntityByName("info_observer_point");
	fcamang[1] += 90.0;
	fcamang[2] = 0.0;
	DispatchKeyValueVector(point, "angles", fcamang);
	DispatchKeyValueVector(point, "origin", GetPointAimPosition(fcampos, fcamang, 25.0, camera));
	
	DispatchSpawn(point);
	
	SetVariantString("!activator");
	AcceptEntityInput(point, "SetParent", camera);
	
	return point;
}

void CreateSnapShot(int camera, int point, int[] clients, int clientcount)
{
	//Emit Camera Sound
	EmitSoundToAll(SOUND_SNAPSHOT, camera);
	
	//Unstick
	AcceptEntityInput(point, "ClearParent");
	
	float fpointpos[3], fpointang[3];
	GetEntPropVector(point, Prop_Send, "m_vecOrigin", fpointpos);
	GetEntPropVector(point, Prop_Data, "m_angRotation", fpointang);
	
	//Stick
	SetVariantString("!activator");
	AcceptEntityInput(point, "SetParent", camera);
	
	//Create flash light Splash
	TE_SetupEnergySplash(fpointpos, fpointang, false);
	TE_SendToAll();
	
	//Create flash light on clients' screen
	int duration = 5;
	int holdtime = 10;
	int color[4] = { 255, 255, 255, 240 };

	Handle message = StartMessageEx(GetUserMessageId("Fade"), clients, clientcount);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", 0);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(0);		
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}
	
	EndMessage();
}

bool IsCameraActivated(int client, int camera)
{
	for (int i = 0; i < MAX_CAMERA; i++)
	{
		if (g_iCameraList[client][i][ENTITY_CAMERA] == EntIndexToEntRef(camera))
		{
			return true;
		}
	}
	
	return false;
}

bool SetCameraActivated(int client, int camera, int point)
{
	for (int i = 0; i < MAX_CAMERA; i++)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) == INVALID_ENT_REFERENCE)
		{
			g_iCameraList[client][i][ENTITY_CAMERA] = EntIndexToEntRef(camera);
			g_iCameraList[client][i][ENTITY_OPOINT] = EntIndexToEntRef(point);
			
			return true;
		}
	}
	
	return false;
}

void RemoveCameraActivated(int camera)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		for (int j = 0; j < MAX_CAMERA; j++)
		{
			if (EntRefToEntIndex(g_iCameraList[i][j][ENTITY_CAMERA]) == camera)
			{
				g_iCameraList[i][j][ENTITY_CAMERA] = INVALID_ENT_REFERENCE;
				
				int point = EntRefToEntIndex(g_iCameraList[i][j][ENTITY_OPOINT]);
				if (IsValidEntity(point))
				{
					AcceptEntityInput(point, "ClearParent");
					AcceptEntityInput(point, "Kill");
				}

				return;
			}
		}
	}
}

bool HasCamera(int client)
{
	for (int i = 0; i < MAX_CAMERA; i++)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) != INVALID_ENT_REFERENCE)
		{
			return true;
		}
	}
	
	return false;
}

void LeaveCamera(int client)
{
	g_bInConsole[client] = false;
	
	SetClientViewEntity(client, client);
	
	int weapon = EntRefToEntIndex(g_iClientWeaponRef[client]);
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	
	if(GetEntityFlags(client) & FL_FROZEN)
	{
		SetEntityFlags(client, (GetEntityFlags(client) & ~FL_FROZEN));
	}
	
	int iHideHUD = GetEntProp(client, Prop_Send, "m_iHideHUD");
	SetEntProp(client, Prop_Send, "m_iHideHUD", iHideHUD & ~HIDEHUD_ALL);
	
	int owner = GetClientOfUserId(g_iConsoleOwnerRef[client]);
	if (owner != 0)
	{
		int camera = EntRefToEntIndex(g_iCameraList[owner][g_iInConsoleID[client]][ENTITY_CAMERA]);
		if (camera != INVALID_ENT_REFERENCE)
		{
			SetEntProp(camera, Prop_Send, "m_nSkin", 1);
		}
	}
}

int GetNextCameraID(int client, int id)
{
	for (int i = id+1; i < MAX_CAMERA; i++)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	for (int i = 0; i < id; i++)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	return id;
}

int GetBackCameraID(int client, int id)
{
	for (int i = id-1; i >= 0; i--)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	for (int i = MAX_CAMERA-1; i > id; i--)
	{
		if (EntRefToEntIndex(g_iCameraList[client][i][ENTITY_CAMERA]) != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	return id;
}