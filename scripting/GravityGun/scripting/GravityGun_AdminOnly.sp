/*
 *descriptions here
 */

new const String:PLUGIN_VERSION[60] = "1.0.0.2";

public Plugin:myinfo = {
	
	name = "GravityGun Admin Only",
	author = "Auther",
	description = "GravityGun Plugin`s addon",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
	
};

//uncomment if u wanna use function of these include file
#include <sourcemod>
#include <sdktools>
//#include <cstrike>
//#include "sdkhooks"
//#include "vphysics"
//#include "stocklib"
#include "GravityGun/GravityGun.inc"

//semicolon!!!!
#pragma semicolon 1

new bool:g_bClientIsAdmin[MAXPLAYERS + 1];

public OnPluginStart(){
	
	CreateConVar("gravitygunadminonly_version", PLUGIN_VERSION, "plugin info cvar", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen){
	
	g_bClientIsAdmin[client] = false;
	return true;

}

public OnClientPostAdminCheck(client){

	if(GetUserAdmin(client) != INVALID_ADMIN_ID){
	
		g_bClientIsAdmin[client] = true;
	
	}

}

public Action:OnClientGrabEntity(client, entity){

	if(!g_bClientIsAdmin[client]){
	
		return Plugin_Handled;
	
	}
	
	return Plugin_Continue;

}

public Action:OnClientDragEntity(client, entity){

	if(!g_bClientIsAdmin[client]){
	
		return Plugin_Handled;
	
	}
	
	return Plugin_Continue;

}

public Action:OnClientEmptyShootEntity(client, entity){

	if(!g_bClientIsAdmin[client]){
	
		return Plugin_Handled;
	
	}
	
	return Plugin_Continue;

}

public Action:OnClientShootEntity(client, entity){

	if(!g_bClientIsAdmin[client]){
	
		return Plugin_Handled;
	
	}
	
	return Plugin_Continue;

}