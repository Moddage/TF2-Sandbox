/*
 *Grabber Plugin
 */

new const String:PLUGIN_VERSION[60] = "1.1.5.138";

public Plugin:myinfo = {
	
	name = "GravityGun",
	author = "FlaminSarge, javalia",
	description = "Grab it!",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
	
};

//인클루드문장
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <vphysics>
#include <stocklib>
#include <matrixmath>

#include "GravityGun/GravityGunsound.inc"
#include "GravityGun/GravityGuncvars.inc"

#define EFL_NO_PHYSCANNON_INTERACTION (1<<30)
 
#pragma semicolon 1

enum PropTypeCheck{

	PROP_NONE = 0,
	PROP_RIGID = 1,
	PROP_PHYSBOX = 2,
	PROP_WEAPON = 3,
	PROP_TF2OBJ = 4,//tf2 buildings
	PROP_RAGDOLL = 5,
	PROP_TF2PROJ = 6//tf2 projectiles

};

//are they using grabber?
//new bool:grabenabled[MAXPLAYERS + 1];

new bool:g_bIsWeaponGrabber[MAXPLAYERS + 1];

//which entity is grabbed?(and are we currently grabbing anything?) this is entref, not ent index
new grabbedentref[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

new keybuffer[MAXPLAYERS + 1];

new Float:grabangle[MAXPLAYERS + 1][3];
new bool:firstGrab[MAXPLAYERS + 1];
new Float:grabdistance[MAXPLAYERS + 1];
new Float:resultangle[MAXPLAYERS + 1][3];

new Float:preeyangle[MAXPLAYERS + 1][3];
new Float:playeranglerotate[MAXPLAYERS + 1][3];

new Float:nextactivetime[MAXPLAYERS + 1];

new bool:entitygravitysave[MAXPLAYERS + 1];
new entityownersave[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

new PropTypeCheck:grabentitytype[MAXPLAYERS + 1];

new Handle:forwardOnClientGrabEntity = INVALID_HANDLE;
new Handle:forwardOnClientDragEntity = INVALID_HANDLE;
new Handle:forwardOnClientEmptyShootEntity = INVALID_HANDLE;
new Handle:forwardOnClientShootEntity = INVALID_HANDLE;
//new g_iBeam;
new g_iHalo;
//new g_iLaser;
new g_iPhys;

public OnPluginStart(){
	
	HookEvent("player_spawn", EventSpawn);
	creategravityguncvar();
	for (new client = 0; client <= MaxClients; client++)
	{
		g_bIsWeaponGrabber[client] = false;

		grabbedentref[client] = INVALID_ENT_REFERENCE;
		if (isClientConnectedIngame(client))
		{
			SDKHook(client, SDKHook_PreThink, PreThinkHook);
			SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitchHook);
		}
	}
	//LoadTranslations("gravitygun.phrases");
	
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max){

	CreateNative("GG_GetCurrentHeldEntity", Native_GetCurrntHeldEntity);
	CreateNative("GG_ForceDropHeldEntity", Native_ForceDropHeldEntity);
	CreateNative("GG_ForceGrabEntity", Native_ForceGrabEntity);
	
	forwardOnClientGrabEntity = CreateGlobalForward("OnClientGrabEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientDragEntity =  CreateGlobalForward("OnClientDragEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientEmptyShootEntity =  CreateGlobalForward("OnClientEmptyShootEntity", ET_Event, Param_Cell, Param_Cell);
	forwardOnClientShootEntity =  CreateGlobalForward("OnClientShootEntity", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("GravityGun");
	
	return APLRes_Success;
	
}

public OnMapStart(){
	
	prepatchsounds();

	g_iHalo = PrecacheModel("materials/sprites/halo01.vmt");
	//g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt");
//	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	
	AutoExecConfig();
	
}

public Action:EventSpawn(Handle:Event, const String:Name[], bool:Broadcast){
	
	decl client;
	client = GetClientOfUserId(GetEventInt(Event, "userid"));
	
	nextactivetime[client] = GetGameTime();
	
}

public OnClientPutInServer(client){
	
	g_bIsWeaponGrabber[client] = false;
	
	grabbedentref[client] = INVALID_ENT_REFERENCE;
	
	SDKHook(client, SDKHook_PreThink, PreThinkHook);
	SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitchHook);

}

public OnClientDisconnect(client){
	
	//we must release any thing if it is on spectator`s hand
	release(client);
	
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){

	if(isClientConnectedIngameAlive(client)){
		
		if(clientisgrabbingvalidobject(client)){
	
		
			if(buttons & IN_USE){
			
				ZeroVector(vel);
				
				  
		 
				if(buttons & IN_FORWARD){
				
					buttons &= ~IN_FORWARD;
					
					if(buttons & IN_SPEED){
					
						grabdistance[client] = grabdistance[client] + 10.0;
					
					}else{
					
						grabdistance[client] = grabdistance[client] + 1.0;
						
					}
					
					if(grabdistance[client] >= GetConVarFloat(cvar_grab_maxdistance)){
					
						grabdistance[client] = GetConVarFloat(cvar_grab_maxdistance);
					
					}
				
				}else if(buttons & IN_BACK){
				
					buttons &= ~IN_BACK;
					
					if(buttons & IN_SPEED){
					
						grabdistance[client] = grabdistance[client] - 10.0;
					
					}else{
					
						grabdistance[client] = grabdistance[client] - 1.0;
						
					}
					
					if(grabdistance[client] < GetConVarFloat(cvar_grab_mindistance)){
					
						grabdistance[client] = GetConVarFloat(cvar_grab_mindistance);
					
					}
				
				}		
		}
		
	}
	}
	return Plugin_Continue;

}

public Action:WeaponSwitchHook(client, entity){
	
	decl String:weaponname[64];
	if(!isClientConnectedIngameAlive(client) || !IsValidEntity(entity)){
		
		g_bIsWeaponGrabber[client] = false;
		return Plugin_Continue;
		
	}
	
	GetEdictClassname(entity, weaponname, sizeof(weaponname));
	 
	new rulecheck = GetConVarInt(g_cvarWeaponSwitchRule);
	 
	if(!isWeaponGrabber(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon")) || EntRefToEntIndex(grabbedentref[client]) == -1 || !Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))){
		 
		g_bIsWeaponGrabber[client] = isWeaponGrabber(entity);
		return Plugin_Continue;
	
	}else{ 
		if(rulecheck == 0){
			
			return Plugin_Handled;
			
		}else{
		
			g_bIsWeaponGrabber[client] = isWeaponGrabber(entity);
			if(!g_bIsWeaponGrabber[client] || rulecheck == 1) release(client);
			return Plugin_Continue;
		
		}
		
	}
	
}

public PreThinkHook(client){
	
	if(isClientConnectedIngameAlive(client)){
		
		new buttons = GetClientButtons(client);
		new clientteam = GetClientTeam(client);
		
		
			
		 	if(buttons & IN_ATTACK2 && !(keybuffer[client] & IN_ATTACK2) && GetConVarBool(g_cvarEnableMotionControl)){
				if(grabbedentref[client] != 0 && g_bIsWeaponGrabber[client] && grabbedentref[client] != INVALID_ENT_REFERENCE)
				{
					if(Phys_IsMotionEnabled(EntRefToEntIndex(grabbedentref[client]))){
						
						keybuffer[client] = keybuffer[client] | IN_ATTACK2;
						AcceptEntityInput(grabbedentref[client], "DisableMotion");
						playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_MOTION);
						release(client);
						return;
					
					}else{
						
						keybuffer[client] = keybuffer[client] | IN_ATTACK2;
						AcceptEntityInput(grabbedentref[client], "EnableMotion");
						playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_MOTION);
						return;
					
					}
				}
			}
			
		if((buttons & IN_USE)  && clientisgrabbingvalidobject(client)){
		
			//SetEntityFlags(client, GetEntityFlags(client) & FL_ONTRAIN);
		
			
			if(buttons & IN_SPEED){
			
			//	grabangle[client][0] = 0.0;
			//	grabangle[client][1] = 0.0;
			//		grabangle[client][2] = 0.0;
			
			}else{
		
					
				decl Float:nowangle[3];
				GetClientEyeAngles(client, nowangle);
				
				
				playeranglerotate[client][0] = playeranglerotate[client][0] + (preeyangle[client][0] - nowangle[0]);
				playeranglerotate[client][1] = playeranglerotate[client][1] + (preeyangle[client][1] - nowangle[1]);
				playeranglerotate[client][2] = playeranglerotate[client][2] + (preeyangle[client][2] - nowangle[2]);
				 
				TeleportEntity(client, NULL_VECTOR, preeyangle[client], NULL_VECTOR);
				
			}
		
		}
		else{		
			GetClientEyeAngles(client, preeyangle[client]);	
		}
		
		if(grabbedentref[client] == INVALID_ENT_REFERENCE)
		{	
			if((buttons & IN_ATTACK) && !(keybuffer[client] & IN_ATTACK))
			{		
				//trying to grab something
				if(teamcanusegravitygun(clientteam) && g_bIsWeaponGrabber[client]){
				
					grab(client);
					
				}		
			}
			
			
		}
		else if(EntRefToEntIndex(grabbedentref[client]) == -1 || !Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client])))
		{
			//held object has gone
			grabbedentref[client] = INVALID_ENT_REFERENCE;
			//lets make some release sound of gravity gun.
			stopentitysound(client, SOUND_GRAVITYGUN_HOLD);
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_DROP);	
		}
		else
		{	
			//we are currently holding something now		
			if(( (buttons & IN_ATTACK) && !(keybuffer[client] & IN_ATTACK)) && teamcanusegravitygun(clientteam) && g_bIsWeaponGrabber[client])
			{	
				hold(client);			
			}
			else
			{			
				release(client);
			}	
		}
		
		if(!(buttons & IN_ATTACK))
		{
			keybuffer[client] = keybuffer[client] & ~IN_ATTACK;
			
		}
		if(!(buttons & IN_ATTACK2))
		{	
			keybuffer[client] = keybuffer[client] & ~IN_ATTACK2;
			
		}
		
	} // if holding player is connected to the server
	else
	{
		release(client);
	
	}
	
}

grab(client){

	new targetentity, Float:distancetoentity, Float:resultpos[3];
	
	targetentity = GetClientAimEntity3(client, distancetoentity, resultpos);
	
	if(targetentity != -1){
		
		new PropTypeCheck:entityType = entityTypeCheck(targetentity);
		
		if(entityType && !isClientConnectedIngameAlive(GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity"))){
				
		 
			/*	//should we allow grab?
				if(GetForwardFunctionCount(forwardOnClientGrabEntity) > 0){
				
					new Action:result;
			   
					Call_StartForward(forwardOnClientGrabEntity);
					Call_PushCell(client);
					Call_PushCell(targetentity);
					Call_Finish(result);
				   
					if(result !=  Plugin_Continue){
					
						return;
					
					}
					
				}
				*/
				if(!clientcangrab(client))	
					return;
				
				if (entityType == PROP_TF2OBJ && GetEntPropEnt(targetentity, Prop_Send, "m_hBuilder") != client)
					return;

				grabentitytype[client] = entityType;
				
				if(entityType == PROP_RIGID){
			
					SetEntProp(targetentity, Prop_Data, "m_bFirstCollisionAfterLaunch", false);
				
				}
				
				new lastowner = GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity");
				
				if(lastowner != INVALID_ENT_REFERENCE){
				
					entityownersave[client] = EntIndexToEntRef(lastowner);
				
				}else{
				
					entityownersave[client] = INVALID_ENT_REFERENCE;
					
				}
				
				SetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity", client);
				grabbedentref[client] = EntIndexToEntRef(targetentity);
				
				//SetEntPropEnt(targetentity, Prop_Data, "m_hParent", client);
				
				//SetEntProp(targetentity, Prop_Data, "m_iEFlags", GetEntProp(targetentity, Prop_Data, "m_iEFlags") | EFL_NO_PHYSCANNON_INTERACTION);
				
				entitygravitysave[client] = Phys_IsGravityEnabled(targetentity);
				
				Phys_EnableGravity(targetentity, false);
				
				decl Float:clienteyeangle[3], Float:entityangle[3];//, Float:entityposition[3];
				GetEntPropVector(grabbedentref[client], Prop_Send, "m_angRotation", entityangle);
				GetClientEyeAngles(client, clienteyeangle);
				 
				playeranglerotate[client][0] = entityangle[0];
				playeranglerotate[client][1] = entityangle[1];
				playeranglerotate[client][2] = entityangle[2];
				 
				
				grabdistance[client] = GetEntitiesDistance(client, targetentity);
				/* GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
				grabpos[client][0] = entityposition[0] - resultpos[0];
				grabpos[client][1] = entityposition[1] - resultpos[1];
				grabpos[client][2] = entityposition[2] - resultpos[2]; */
				
				new matrix[matrix3x4_t];
				
				matrix3x4FromAnglesNoOrigin(clienteyeangle, matrix);
				
				decl Float:temp[3];
				
				MatrixAngles(matrix, temp);
				
//				TransformAnglesToLocalSpace(entityangle, grabangle[client], matrix);
				
				keybuffer[client] = keybuffer[client] | IN_ATTACK2;
				
				playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PICKUP);
				playentitysoundfromclient(client, SOUND_GRAVITYGUN_HOLD);
				
				grabangle[client][0] = entityangle[0];
				grabangle[client][1] = entityangle[1];
				grabangle[client][2] = entityangle[2];					
			}
			
		}
}

 
emptyshoot(client){
	
	if(!clientcanpull(client)){
		
		return;
	
	}
	
	new targetentity, Float:distancetoentity;
	
	targetentity = GetClientAimEntity(client, distancetoentity); 
	if(targetentity != -1){
		
		new PropTypeCheck:entityType = entityTypeCheck(targetentity);
		
		if(entityType && (distancetoentity <= GetConVarFloat(cvar_maxpulldistance))  && !isClientConnectedIngameAlive(GetEntPropEnt(targetentity, Prop_Send, "m_hOwnerEntity"))){
		
			if(GetForwardFunctionCount(forwardOnClientEmptyShootEntity) > 0){
				
				new Action:result;
		   
				Call_StartForward(forwardOnClientEmptyShootEntity);
				Call_PushCell(client);
				Call_PushCell(targetentity);
				Call_Finish(result);
			   
				if(result !=  Plugin_Continue){
				
					return;
				
				}
				
			}
			
			decl Float:clienteyeangle[3], Float:anglevector[3];
			GetClientEyeAngles(client, clienteyeangle);
			GetAngleVectors(clienteyeangle, anglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(anglevector, anglevector);
			ScaleVector(anglevector, GetConVarFloat(cvar_pullforce));
			
			decl Float:ZeroSpeed[3];
			ZeroVector(ZeroSpeed);
			//TeleportEntity(targetentity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
			Phys_AddVelocity(targetentity, anglevector, ZeroSpeed);
			
			if(entityType == PROP_RIGID || entityType == PROP_PHYSBOX || entityType == PROP_RAGDOLL){
			
				SetEntPropEnt(targetentity, Prop_Data, "m_hPhysicsAttacker", client);
				SetEntPropFloat(targetentity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
				
			}
			if(entityType == PROP_RIGID){
			
				SetEntProp(targetentity, Prop_Data, "m_bThrownByPlayer", true);
			
			}
			
			if (entityType != PROP_TF2OBJ) playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PUNT);
			
		}
	
	}

}

release(client){
	
	if(EntRefToEntIndex(grabbedentref[client]) != -1){
		
		Phys_EnableGravity(EntRefToEntIndex(grabbedentref[client]), entitygravitysave[client]);
		SetEntPropEnt(grabbedentref[client], Prop_Send, "m_hOwnerEntity", EntRefToEntIndex(entityownersave[client]));
		if(isClientConnectedIngame(client)){
	
			playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_DROP);
			
		}
		firstGrab[client] = false;
		
	}
	grabbedentref[client] = INVALID_ENT_REFERENCE;
	keybuffer[client] = keybuffer[client] | IN_ATTACK2;
	
	stopentitysound(client, SOUND_GRAVITYGUN_HOLD);
}

hold(client){
	
	decl Float:resultpos[3], Float:resultvecnormal[3];
	getClientAimPosition(client, grabdistance[client], resultpos, resultvecnormal, tracerayfilterrocket, client);
	
	decl Float:entityposition[3], Float:clientposition[3], Float:vector[3];
	GetEntPropVector(grabbedentref[client], Prop_Send, "m_vecOrigin", entityposition);
	GetClientEyePosition(client, clientposition);
	decl Float:clienteyeangle[3];
	GetClientEyeAngles(client, clienteyeangle);
	
	decl Float:clienteyeangleafterchange[3];
	
	new Float: fAngles[3];
	new Float: fOrigin[3];
	new Float: fEOrigin[3]; 
	// bomba
	new g_iWhite[4] = {255, 255, 255, 200};
	GetClientAbsOrigin(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
		
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_vecOrigin", fEOrigin);
		
	TE_SetupBeamPoints(fOrigin, fEOrigin, g_iPhys, g_iHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, g_iWhite, 10);
	TE_SendToAll();
		
	clienteyeangleafterchange[0] = clienteyeangle[0] + playeranglerotate[client][0];
	clienteyeangleafterchange[1] = clienteyeangle[1] + playeranglerotate[client][1];
	clienteyeangleafterchange[2] = clienteyeangle[2] + playeranglerotate[client][2];
	
	decl playerlocalspace[matrix3x4_t], playerlocalspaceafterchange[matrix3x4_t];
	
	matrix3x4FromAnglesNoOrigin(clienteyeangle, playerlocalspace);
	matrix3x4FromAnglesNoOrigin(clienteyeangleafterchange, playerlocalspaceafterchange);
	
	
	//TransformAnglesToWorldSpace(grabangle[client], resultangle, playerlocalspaceafterchange);
	//TransformAnglesToLocalSpace(resultangle, grabangle[client], playerlocalspace);
	
	//ZeroVector(playeranglerotate[client]);
	
	MakeVectorFromPoints(entityposition, resultpos, vector);
	ScaleVector(vector, GetConVarFloat(cvar_grabforcemultiply));
	
	decl Float:entityangle[3], Float:resultangle2[3];
	GetEntPropVector(grabbedentref[client], Prop_Data, "m_angRotation", entityangle);
	
	resultangle[client][0] = grabangle[client][0];
	resultangle[client][1] = grabangle[client][1];
	resultangle[client][2] = grabangle[client][2]; 
	//PrintToChatAll("%f :: %f :: %f", entityangle[0], entityangle[1], entityangle[2] );
 	resultangle2[0] = resultangle[client][0] + playeranglerotate[client][0];
	resultangle2[1] = resultangle[client][1] + playeranglerotate[client][1];
	resultangle2[2] = resultangle[client][2] + playeranglerotate[client][2];

	if(grabentitytype[client] != PROP_RAGDOLL)
	{
		TeleportEntity(grabbedentref[client], NULL_VECTOR, playeranglerotate[client], NULL_VECTOR);
	}


	Phys_SetVelocity(EntRefToEntIndex(grabbedentref[client]), vector, ZERO_VECTOR, true);
	
	if(grabentitytype[client] == PROP_RIGID || grabentitytype[client] == PROP_PHYSBOX || grabentitytype[client] == PROP_RAGDOLL){
			
		SetEntPropEnt(grabbedentref[client], Prop_Data, "m_hPhysicsAttacker", client);
		SetEntPropFloat(grabbedentref[client], Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
		
	}
	if(grabentitytype[client]	== PROP_RIGID){
	
		SetEntProp(grabbedentref[client], Prop_Data, "m_bThrownByPlayer", true);
	
	}
	
}

PropTypeCheck:entityTypeCheck(entity){

	new String:classname[64];
	GetEdictClassname(entity, classname, 64);
	
	if(StrContains(classname, "prop_physics", false)  != -1){
	
		return PROP_RIGID;
	
	}else if(StrContains(classname, "func_physbox", false)  != -1){
		
		return PROP_PHYSBOX;
	
	}else if(StrContains(classname, "prop_ragdoll", false)  != -1){
	
		return PROP_RAGDOLL;
	
	}else if(StrContains(classname, "weapon_", false)  != -1){
	
		return PROP_WEAPON;
	
	}else if(StrContains(classname, "tf_projectile", false)  != -1){
	
		return PROP_TF2PROJ;
	
	}else if(StrEqual(classname, "obj_sentrygun", false) || StrEqual(classname, "obj_dispenser", false)
			|| StrEqual(classname, "obj_teleporter", false)){
	
		return PROP_TF2OBJ;
	
	}else{
	
		return PROP_NONE;
	
	}

}

bool:clientcanpull(client){

	new Float:now = GetGameTime();
	
	if(nextactivetime[client] <= now){
	
		nextactivetime[client] = now + GetConVarFloat(cvar_pull_delay);
		
		return true;
	
	}
	
	return false;

}

bool:clientcangrab(client){

	new Float:now = GetGameTime();
	
	if(nextactivetime[client] <= now){
	
		nextactivetime[client] = now + GetConVarFloat(cvar_grab_delay);
		
		return true;
	
	}
	
	return false;

}

bool:clientisgrabbingvalidobject(client){

	if(EntRefToEntIndex(grabbedentref[client]) != -1 && Phys_IsPhysicsObject(EntRefToEntIndex(grabbedentref[client]))){
		
		return true;
		
	}else{
	
		return false;
	
	}

}

public Native_GetCurrntHeldEntity(Handle:plugin,  args){

	new client = GetNativeCell(1);
	
	if(isClientConnectedIngameAlive(client)){
		
		return EntRefToEntIndex(grabbedentref[client]);
		
	}else{
	
		return -1;
	
	}

}

public Native_ForceDropHeldEntity(Handle:plugin,  args){

	new client = GetNativeCell(1);
	
	if(isClientConnectedIngameAlive(client)){
	
		release(client);
		return true;
	}
	
	return false;

}

public Native_ForceGrabEntity(Handle:plugin,  args){

	new client = GetNativeCell(1);
	new entity = GetNativeCell(2);
	
	if(isClientConnectedIngameAlive(client)){
		
		if(IsValidEdict(entity)){
			
			new PropTypeCheck:entityType = entityTypeCheck(entity);
			
			if(entityType && !isClientConnectedIngameAlive(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))){
			
				//지목한 엔티티는 들 수 있는것이다.
				//이미 들고있는 엔티티가 있다면, 내려놓는다
				release(client);
				
				grabentitytype[client] = entityType;
				grabbedentref[client] = EntIndexToEntRef(entity);
				
				//소리를 낸다
				playsoundfromclient(client, SOUNDTYPE_GRAVITYGUN_PICKUP);
				playentitysoundfromclient(client, SOUND_GRAVITYGUN_HOLD);
				
				return true;
			
			}
		
		}
		
	}
	
	return false;

}