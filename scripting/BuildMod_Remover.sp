/*
	This file is part of TF2 Sandbox.
	
	TF2 Sandbox is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    TF2 Sandbox is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TF2 Sandbox.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <clientprefs>
#include <sourcemod>
#include <sdktools>
#include <build>
#include <build_stocks>
#include <vphysics>

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

new String:g_szConnectedClient[32][MAXPLAYERS];
//new String:g_szDisconnectClient[32][MAXPLAYERS];
new g_iTempOwner[MAX_HOOK_ENTITIES] = {-1,...};

new Float:g_fDelRangePoint1[MAXPLAYERS][3];
new Float:g_fDelRangePoint2[MAXPLAYERS][3];
new Float:g_fDelRangePoint3[MAXPLAYERS][3];
new String:g_szDelRangeStatus[MAXPLAYERS][8];
new bool:g_szDelRangeCancel[MAXPLAYERS] = { false,...};

new g_Beam;
new g_Halo;
new g_PBeam;

new ColorWhite[4]	= {
		255,
		255,
		255,
		255};
new ColorRed[4]	= {
		255,
		50,
		50,
		255};
new ColorGreen[4]	= {
		50,
		255,
		50,
		255};
new ColorBlue[4]	= {
		50,
		50,
		255,
		255};

new String:EntityType[][] = {
	"player",
	"func_physbox",
	"prop_door_rotating",
	"prop_dynamic",
	"prop_dynamic_ornament",
	"prop_dynamic_override",
	"prop_physics",
	"prop_physics_multiplayer",
	"prop_physics_override",
	"prop_physics_respawnable",
	"prop_ragdoll",
	"item_ammo_357",
	"item_ammo_357_large",
	"item_ammo_ar2",
	"item_ammo_ar2_altfire",
	"item_ammo_ar2_large",
	"item_ammo_crate",
	"item_ammo_crossbow",
	"item_ammo_pistol",
	"item_ammo_pistol_large",
	"item_ammo_smg1",
	"item_ammo_smg1_grenade",
	"item_ammo_smg1_large",
	"item_battery",
	"item_box_buckshot",
	"item_dynamic_resupply",
	"item_healthcharger",
	"item_healthkit",
	"item_healthvial",
	"item_item_crate",
	"item_rpg_round",
	"item_suit",
	"item_suitcharger",
	"weapon_357",
	"weapon_alyxgun",
	"weapon_ar2",
	"weapon_bugbait",
	"weapon_crossbow",
	"weapon_crowbar",
	"weapon_frag",
	"weapon_physcannon",
	"weapon_pistol",
	"weapon_rpg",
	"weapon_shotgun",
	"weapon_smg1",
	"weapon_stunstick",
	"weapon_slam",
	"tf_viewmodel",
	"tf_",
	"gib"
};

new String:DelClass[][] = {
	"npc_",
	"Npc_",
	"NPC_",
	"prop_",
	"Prop_",
	"PROP_",
	"func_",
	"Func_",
	"FUNC_",
	"item_",
	"Item_",
	"ITEM_",
	"gib"
};

public Plugin:myinfo = {
	name = "TF2 Sandbox - Remover",
	author = "Danct12, DaRkWoRlD",
	description = "Remove props.",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {	
	RegAdminCmd("sm_delall", Command_DeleteAll, 0, "Delete all of your spawned entitys.");
	RegAdminCmd("sm_del", Command_Delete, 0, "Delete an entity.");
	
	HookEntityOutput("prop_physics_respawnable", "OnBreak", OnPropBreak);
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
}

public OnMapStart() {
	g_Halo = PrecacheModel("materials/sprites/halo01.vmt");
	g_Beam = PrecacheModel("materials/sprites/laser.vmt");
	g_PBeam = PrecacheModel("materials/sprites/physbeam.vmt");
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
	PrecacheSound("npc/strider/charging.wav", true);
	PrecacheSound("npc/strider/fire.wav", true);
	for (new i = 1; i < MaxClients; i++) {
		g_szConnectedClient[i] = "";
		if (Build_IsClientValid(i, i))
			GetClientAuthId(i, AuthId_Steam2, g_szConnectedClient[i], sizeof(g_szConnectedClient));
	}
}

public OnClientPutInServer(Client) {
	GetClientAuthId(Client, AuthId_Steam2, g_szConnectedClient[Client], sizeof(g_szConnectedClient));
}

public OnClientDisconnect(Client) {
	FakeClientCommand(Client, "sm_delall");
	/*g_szConnectedClient[Client] = "";
	GetClientAuthId(Client, AuthId_Steam2, g_szDisconnectClient[Client], sizeof(g_szDisconnectClient));
	new iCount;
	for (new iCheck = 0; iCheck < MAX_HOOK_ENTITIES; iCheck++) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == Client) {
				g_iTempOwner[iCheck] = Client;
				Build_RegisterEntityOwner(iCheck, -1);
				iCount++;
			}
		}
	}
	Build_SetLimit(Client, 0);
	Build_SetLimit(Client, 0, true);
	if (iCount > 0) {
		new Handle:hPack;
		CreateDataTimer(0.001, Timer_Disconnect, hPack);
		WritePackCell(hPack, Client);
		WritePackCell(hPack, 0);
	}*/
}

public Action:Timer_Disconnect(Handle:Timer, Handle:hPack) {
	ResetPack(hPack);
	new Client = ReadPackCell(hPack);
	
	new iCount;
	for (new iCheck = Client; iCheck < MAX_HOOK_ENTITIES; iCheck++) {
		if (IsValidEntity(iCheck)) {
			if (g_iTempOwner[iCheck] == Client) {
				AcceptEntityInput(iCheck, "Kill", -1);
				iCount++;
			}
		}
	}
	
	return;
}

public Action:OnClientCommand(Client, args) {
	if (Client > 0) {
		if (Build_IsClientValid(Client, Client)) {
			new String:Lang[8];
			GetClientCookie(Client, g_hCookieClientLang, Lang, sizeof(Lang));
			if (StrEqual(Lang, "1"))
				g_bClientLang[Client] = true;
			else
				g_bClientLang[Client] = false;
		}
	}
}

public Action:Command_DeleteAll(Client, args) {
	if (!Build_AllowToUse(Client) || !Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new iCheck = 0, iCount = 0;
	while (iCheck < MAX_HOOK_ENTITIES) {
		if (IsValidEntity(iCheck)) {
			if (Build_ReturnEntityOwner(iCheck) == Client) {
				for (new i = 0; i < sizeof(DelClass); i++) {
					new String:szClass[32];
					GetEdictClassname(iCheck, szClass, sizeof(szClass));
					if (StrContains(szClass, DelClass[i]) >= 0) {
						AcceptEntityInput(iCheck, "Kill", -1);
						iCount++;
					}
					Build_RegisterEntityOwner(iCheck, -1);
				}
			}
		}
		iCheck += 1;
	}
	if (iCount > 0) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "刪除了所有你擁有的物件.");
		else
			Build_PrintToChat(Client, "Deleted all props you owns.");
	} else {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "你沒有任何物件.");
		else
			Build_PrintToChat(Client, "You don't have any props.");
	}
	
	Build_SetLimit(Client, 0);
	Build_SetLimit(Client, 0, true);
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_delall", szArgs);
	return Plugin_Handled;
}

public Action:Command_Delete(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	new iEntity = Build_ClientAimEntity(Client, true, true);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szClass[33];
		GetEdictClassname(iEntity, szClass, sizeof(szClass));
		DispatchKeyValue(iEntity, "targetname", "Del_Drop");
		
		if (!Build_IsAdmin(Client)) {
			if (StrEqual(szClass, "prop_vehicle_driveable") || StrEqual(szClass, "prop_vehicle") || StrEqual(szClass, "prop_vehicle_airboat") || StrEqual(szClass, "prop_vehicle_prisoner_pod")) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "你無法刪除此物件!");
				else
					Build_PrintToChat(Client, "You can't delete this prop!");
				return Plugin_Handled;
			}
		}
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		new Obj_Dissolver = CreateDissolver("3");
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
		
		DispatchKeyValue(iEntity, "targetname", "Del_Target");
		
		TE_SetupBeamRingPoint(vOriginAim, 10.0, 150.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, ColorWhite, 20, 0);
		TE_SendToAll();
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();

		if (Build_IsAdmin(Client)) {
			if (StrEqual(szClass, "player") || StrContains(szClass, "prop_") == 0 || StrContains(szClass, "npc_") == 0 || StrContains(szClass, "weapon_") == 0 || StrContains(szClass, "item_") == 0) {
				SetVariantString("Del_Target");
				AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
				AcceptEntityInput(Obj_Dissolver, "kill", -1);
				DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if(iOwner != -1) {
					if(StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
					else
						Build_SetLimit(iOwner, -1);
					Build_RegisterEntityOwner(iEntity, -1);
				}
				return Plugin_Handled;
			}
			if (!(GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))) {
				AcceptEntityInput(iEntity, "kill", -1);
				AcceptEntityInput(Obj_Dissolver, "kill", -1);
				return Plugin_Handled;
			}
		}

		if (StrEqual(szClass, "func_physbox")) {
			AcceptEntityInput(iEntity, "kill", -1);
			AcceptEntityInput(Obj_Dissolver, "kill", -1);
		} else {
			SetVariantString("Del_Target");
			AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
			AcceptEntityInput(Obj_Dissolver, "kill", -1);
			DispatchKeyValue(iEntity, "targetname", "Del_Drop");
		}
		
		if(StrEqual(szClass, "prop_ragdoll"))
			Build_SetLimit(Client, -1, true);
		else
			Build_SetLimit(Client, -1);
		Build_RegisterEntityOwner(iEntity, -1);
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_del", szArgs);
	return Plugin_Handled;
}

public Action:Command_DelRange(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new String:szCancel[32];
	GetCmdArg(1, szCancel, sizeof(szCancel));
	if (!StrEqual(szCancel, "") && (!StrEqual(g_szDelRangeStatus[Client], "off") || !StrEqual(g_szDelRangeStatus[Client], ""))) {
		Build_PrintToChat(Client, "Canceled DelRange");
		g_szDelRangeCancel[Client] = true;
		return Plugin_Handled;
	}
	
	if (StrEqual(g_szDelRangeStatus[Client], "x"))
		g_szDelRangeStatus[Client] = "y";
	else if (StrEqual(g_szDelRangeStatus[Client], "y"))
		g_szDelRangeStatus[Client] = "z";
	else if (StrEqual(g_szDelRangeStatus[Client], "z"))
		g_szDelRangeStatus[Client] = "off";
	else {
		Build_ClientAimOrigin(Client, g_fDelRangePoint1[Client]);
		g_szDelRangeStatus[Client] = "x";
		CreateTimer(0.05, Timer_DR, Client);
	}
	return Plugin_Handled;
}

public Action:Command_DelStrider(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new Float:fRange, String:szRange[5], Float:vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(Client, vOriginAim);
	
	new Handle:hDataPack;
	CreateDataTimer(0.01, Timer_DScharge, hDataPack);
	WritePackCell(hDataPack, Client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}

public Action:Command_DelStrider2(Client, args) {
	if (!Build_IsClientValid(Client, Client))
		return Plugin_Handled;
	
	new Float:fRange, String:szRange[5], Float:vOriginAim[3];
	GetCmdArg(1, szRange, sizeof(szRange));
	
	fRange = StringToFloat(szRange);
	if (fRange < 1)
		fRange = 300.0;
	if (fRange > 5000)
		fRange = 5000.0;
	
	Build_ClientAimOrigin(Client, vOriginAim);
	
	new Handle:hDataPack;
	CreateDataTimer(0.01, Timer_DScharge2, hDataPack);
	WritePackCell(hDataPack, Client);
	WritePackFloat(hDataPack, fRange);
	WritePackFloat(hDataPack, vOriginAim[0]);
	WritePackFloat(hDataPack, vOriginAim[1]);
	WritePackFloat(hDataPack, vOriginAim[2]);
	return Plugin_Handled;
}


public Action:Timer_DR(Handle:Timer, any:Client) {
	if (!Build_IsClientValid(Client, Client))
		return;
	if (g_szDelRangeCancel[Client]) {
		g_szDelRangeCancel[Client] = false;
		g_szDelRangeStatus[Client] = "off";
		return;
	}
	
	new Float:vPoint2[3], Float:vPoint3[3], Float:vPoint4[3];
	new Float:vClonePoint1[3], Float:vClonePoint2[3], Float:vClonePoint3[3], Float:vClonePoint4[3];
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	
	if (StrEqual(g_szDelRangeStatus[Client], "x")) {
		Build_ClientAimOrigin(Client, vOriginAim);
		vPoint2[0] = vOriginAim[0];
		vPoint2[1] = vOriginAim[1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint2, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint2[Client] = vPoint2;
		CreateTimer(0.001, Timer_DR, Client);
	} else if (StrEqual(g_szDelRangeStatus[Client], "y")) {
		Build_ClientAimOrigin(Client, vOriginAim);
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = vOriginAim[2];
		vPoint4[0] = vPoint2[0];
		vPoint4[1] = vPoint2[1];
		vPoint4[2] = vOriginAim[2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = vOriginAim[2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = vOriginAim[2];
		
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = (vOriginPlayer[2] + 50);
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint2, vClonePoint1, ColorRed);
		DrowLine(vPoint2, vClonePoint2, ColorRed);
		DrowLine(vPoint3, vClonePoint3, ColorRed);
		DrowLine(vPoint3, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vClonePoint3, ColorRed);
		DrowLine(vPoint4, vClonePoint4, ColorRed);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorRed);
		DrowLine(vPoint4, vPoint2, ColorRed);
		DrowLine(vClonePoint1, vClonePoint3, ColorRed);
		DrowLine(vClonePoint2, vClonePoint4, ColorRed);
		DrowLine(vPoint4, vOriginAim, ColorBlue);
		DrowLine(vOriginAim, vOriginPlayer, ColorBlue);
		
		g_fDelRangePoint3[Client] = vPoint4;
		CreateTimer(0.001, Timer_DR, Client);
	} else if (StrEqual(g_szDelRangeStatus[Client], "z")) {
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = ((g_fDelRangePoint1[Client][2] + vPoint2[2]) / 2);
		
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[Client][2];
		
		DrowLine(g_fDelRangePoint1[Client], vClonePoint1, ColorGreen);
		DrowLine(g_fDelRangePoint1[Client], vClonePoint2, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint2, ColorGreen);
		DrowLine(vPoint3, vClonePoint3, ColorGreen);
		DrowLine(vPoint3, vClonePoint4, ColorGreen);
		DrowLine(g_fDelRangePoint3[Client], vClonePoint3, ColorGreen);
		DrowLine(g_fDelRangePoint3[Client], vClonePoint4, ColorGreen);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorGreen);
		DrowLine(vPoint2, g_fDelRangePoint3[Client], ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		DrowLine(vPoint2, vClonePoint1, ColorGreen);
		TE_SetupBeamPoints(vPoint3, g_fDelRangePoint1[Client], g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(g_fDelRangePoint3[Client], vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint3, vClonePoint1, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		TE_SetupBeamPoints(vClonePoint4, vClonePoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, ColorGreen, 20);
		TE_SendToAll();
		
		CreateTimer(0.001, Timer_DR, Client);
	} else {
		vPoint2[0] = g_fDelRangePoint2[Client][0];
		vPoint2[1] = g_fDelRangePoint2[Client][1];
		vPoint2[2] = g_fDelRangePoint1[Client][2];
		vPoint3[0] = g_fDelRangePoint1[Client][0];
		vPoint3[1] = g_fDelRangePoint1[Client][1];
		vPoint3[2] = g_fDelRangePoint3[Client][2];
		
		vClonePoint1[0] = g_fDelRangePoint1[Client][0];
		vClonePoint1[1] = vPoint2[1];
		vClonePoint1[2] = g_fDelRangePoint1[Client][2];
		vClonePoint2[0] = vPoint2[0];
		vClonePoint2[1] = g_fDelRangePoint1[Client][1];
		vClonePoint2[2] = vPoint2[2];
		vClonePoint3[0] = vClonePoint1[0];
		vClonePoint3[1] = vClonePoint1[1];
		vClonePoint3[2] = g_fDelRangePoint3[Client][2];
		vClonePoint4[0] = vClonePoint2[0];
		vClonePoint4[1] = vClonePoint2[1];
		vClonePoint4[2] = g_fDelRangePoint3[Client][2];
		
		DrowLine(vClonePoint1, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint2, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint3, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vClonePoint4, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vPoint2, vClonePoint1, ColorWhite, true);
		DrowLine(vPoint2, vClonePoint2, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint3, ColorWhite, true);
		DrowLine(vPoint3, vClonePoint4, ColorWhite, true);
		DrowLine(vPoint2, g_fDelRangePoint3[Client], ColorWhite, true);
		DrowLine(vPoint3, g_fDelRangePoint1[Client], ColorWhite, true);
		DrowLine(vClonePoint1, vClonePoint3, ColorWhite, true);
		DrowLine(vClonePoint2, vClonePoint4, ColorWhite, true);
		
		new Obj_Dissolver = CreateEntityByName("env_entity_dissolver");
		DispatchKeyValue(Obj_Dissolver, "dissolvetype", "3");
		DispatchKeyValue(Obj_Dissolver, "targetname", "Del_Dissolver");
		DispatchSpawn(Obj_Dissolver);
		ActivateEntity(Obj_Dissolver);
		
		new Float:vOriginEntity[3], String:szClass[32];
		new iCount = 0;
		new iEntity = -1;
		for (new i = 0; i < sizeof(EntityType); i++) {
			while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
				GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
				vOriginEntity[2] += 1;
				if (vOriginEntity[0] != 0 && vOriginEntity[1] !=1 && vOriginEntity[2] != 0 && Build_IsInSquare(vOriginEntity, g_fDelRangePoint1[Client], g_fDelRangePoint3[Client])) {
					GetEdictClassname(iEntity, szClass, sizeof(szClass));
					if (StrEqual(szClass, "func_physbox"))
						AcceptEntityInput(iEntity, "kill", -1);
					else {
						DispatchKeyValue(iEntity, "targetname", "Del_Target");
						SetVariantString("Del_Target");
						AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
						DispatchKeyValue(iEntity, "targetname", "Del_Drop");
					}
					
					new iOwner = Build_ReturnEntityOwner(iEntity);
					if(iOwner != -1) {
						if(StrEqual(szClass, "prop_ragdoll"))
							Build_SetLimit(iOwner, -1, true);
						else
							Build_SetLimit(iOwner, -1);
							
						Build_RegisterEntityOwner(iEntity, -1);
					}
				}
			}
		}
		AcceptEntityInput(Obj_Dissolver, "kill", -1);
		
		if (iCount > 0)
			Build_PrintToChat(Client, "Deleted %i props.", iCount);
	}
}

public Action:Timer_DScharge(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(Client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	new Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "20");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	new Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	/*
	new String:szPointTeslaName[128], String:szThickMin[64], String:szThickMax[64], String:szOnUser[128], String:szKill[64];
	new Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	new Float:fThickMin = StringToFloat(szRange) / 40;
	new Float:iThickMax = StringToFloat(szRange) / 30;
	Format(szThickMin, sizeof(szThickMin), "%i", RoundToFloor(fThickMin));
	Format(szThickMax, sizeof(szThickMax), "%i", RoundToFloor(iThickMax));
	
	DispatchKeyValue(Obj_PointTesla, "targetname", szPointTeslaName);
	DispatchKeyValue(Obj_PointTesla, "sprite", "sprites/physbeam.vmt");
	DispatchKeyValue(Obj_PointTesla, "m_color", "255 255 255");
	DispatchKeyValue(Obj_PointTesla, "m_flradius", szRange);
	DispatchKeyValue(Obj_PointTesla, "beamcount_min", "100");
	DispatchKeyValue(Obj_PointTesla, "beamcount_max", "500");
	DispatchKeyValue(Obj_PointTesla, "thick_min", szThickMin);
	DispatchKeyValue(Obj_PointTesla, "thick_max", szThickMax);
	DispatchKeyValue(Obj_PointTesla, "lifetime_min", "0.1");
	DispatchKeyValue(Obj_PointTesla, "lifetime_max", "0.1");
	
	new Float:f;
	for (f = 0.0; f < 1.3; f=f+0.05) {
		Format(szOnUser, sizeof(szOnUser), "%s,dospark,,%f", szPointTeslaName, f);
		DispatchKeyValue(Obj_PointTesla, "onuser1", szOnUser);
	}
	Format(szKill, sizeof(szKill), "%s,kill,,1.3", szPointTeslaName);
	DispatchSpawn(Obj_PointTesla);
	DispatchKeyValue(Obj_PointTesla, "onuser1", szKill);
	AcceptEntityInput(Obj_PointTesla, "fireuser1", -1);
	*/
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 15.0, 15.0, 0, 0.0, ColorBlue, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Handle:hNewPack;
	CreateDataTimer(1.3, Timer_DSfire, hNewPack);
	WritePackCell(hNewPack, Client);
	WritePackCell(hNewPack, Obj_Push);
	WritePackCell(hNewPack, Obj_Core);
	WritePackFloat(hNewPack, fRange);
	WritePackFloat(hNewPack, vOriginAim[0]);
	WritePackFloat(hNewPack, vOriginAim[1]);
	WritePackFloat(hNewPack, vOriginAim[2]);
	WritePackFloat(hNewPack, vOriginPlayer[0]);
	WritePackFloat(hNewPack, vOriginPlayer[1]);
	WritePackFloat(hNewPack, vOriginPlayer[2]);
}

public Action:Timer_DSfire(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Obj_Push = ReadPackCell(hDataPack);
	new Obj_Core = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	vOriginPlayer[0] = ReadPackFloat(hDataPack);
	vOriginPlayer[1] = ReadPackFloat(hDataPack);
	vOriginPlayer[2] = ReadPackFloat(hDataPack);
	
	if (IsValidEntity(Obj_Push))
		AcceptEntityInput(Obj_Push, "kill", -1);
	if (IsValidEntity(Obj_Core))
		AcceptEntityInput(Obj_Core, "kill", -1);
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Obj_Dissolver = CreateDissolver("3");
	new Float:vOriginEntity[3];
	new iCount = 0;
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			new String:szClass[33];
			GetEdictClassname(iEntity,szClass,sizeof(szClass));
			if (vOriginEntity[0] != 0 && vOriginEntity[1] !=1 && vOriginEntity[2] != 0 && !StrEqual(szClass, "player") && Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
				if (StrEqual(szClass, "func_physbox"))
					AcceptEntityInput(iEntity, "kill", -1);
				else {
					DispatchKeyValue(iEntity, "targetname", "Del_Target");
					SetVariantString("Del_Target");
					AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
					DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				}
				
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if(iOwner != -1) {
					if(StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
					else
						Build_SetLimit(iOwner, -1);
						
					Build_RegisterEntityOwner(iEntity, -1);
				}
				iCount++;
			}
		}
	}
	AcceptEntityInput(Obj_Dissolver, "kill", -1);
	if (iCount > 0 && Build_IsClientValid(Client, Client))
		Build_PrintToChat(Client, "Deleted %i props.", iCount);
}

public Action:Timer_DScharge2(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	
	GetClientAbsOrigin(Client, vOriginPlayer);
	vOriginPlayer[2] = (vOriginPlayer[2] + 50);
	
	EmitAmbientSound("npc/strider/charging.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/charging.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.3);
	
	new Obj_Push = CreatePush(vOriginAim, -1000.0, fRange, "28");
	AcceptEntityInput(Obj_Push, "enable", -1);
	
	new Obj_Core = CreateCore(vOriginAim, 5.0, "1");
	AcceptEntityInput(Obj_Core, "startdischarge", -1);
	
	new Float:vOriginEntity[3], String:szClass[32];
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] = (vOriginEntity[2] + 1);
			if(Phys_IsPhysicsObject(iEntity)) {
				GetEdictClassname(iEntity, szClass, sizeof(szClass));
				if (Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
					Phys_EnableMotion(iEntity, true);
					if (StrEqual(szClass, "player"))
						SetEntityMoveType(iEntity, MOVETYPE_WALK);
					else
						SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
				}
			}
		}
	}
	/*
	new String:szPointTeslaName[128], String:szThickMin[64], String:szThickMax[64], String:szOnUser[128], String:szKill[64];
	new Obj_PointTesla = CreateEntityByName("point_tesla");
	TeleportEntity(Obj_PointTesla, vOriginAim, NULL_VECTOR, NULL_VECTOR);
	Format(szPointTeslaName, sizeof(szPointTeslaName), "szTesla%i", GetRandomInt(1000, 5000));
	new Float:fThickMin = StringToFloat(szRange) / 40;
	new Float:iThickMax = StringToFloat(szRange) / 30;
	Format(szThickMin, sizeof(szThickMin), "%i", RoundToFloor(fThickMin));
	Format(szThickMax, sizeof(szThickMax), "%i", RoundToFloor(iThickMax));
	
	DispatchKeyValue(Obj_PointTesla, "targetname", szPointTeslaName);
	DispatchKeyValue(Obj_PointTesla, "sprite", "sprites/physbeam.vmt");
	DispatchKeyValue(Obj_PointTesla, "m_color", "255 255 255");
	DispatchKeyValue(Obj_PointTesla, "m_flradius", szRange);
	DispatchKeyValue(Obj_PointTesla, "beamcount_min", "100");
	DispatchKeyValue(Obj_PointTesla, "beamcount_max", "500");
	DispatchKeyValue(Obj_PointTesla, "thick_min", szThickMin);
	DispatchKeyValue(Obj_PointTesla, "thick_max", szThickMax);
	DispatchKeyValue(Obj_PointTesla, "lifetime_min", "0.1");
	DispatchKeyValue(Obj_PointTesla, "lifetime_max", "0.1");
	
	new Float:f;
	for (f = 0.0; f < 1.3; f=f+0.05) {
		Format(szOnUser, sizeof(szOnUser), "%s,dospark,,%f", szPointTeslaName, f);
		DispatchKeyValue(Obj_PointTesla, "onuser1", szOnUser);
	}
	Format(szKill, sizeof(szKill), "%s,kill,,1.3", szPointTeslaName);
	DispatchSpawn(Obj_PointTesla);
	DispatchKeyValue(Obj_PointTesla, "onuser1", szKill);
	AcceptEntityInput(Obj_PointTesla, "fireuser1", -1);
	*/
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 15.0, 15.0, 0, 0.0, ColorBlue, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 1.3, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Handle:hNewPack;
	CreateDataTimer(1.3, Timer_DSfire2, hNewPack);
	WritePackCell(hNewPack, Client);
	WritePackCell(hNewPack, Obj_Push);
	WritePackCell(hNewPack, Obj_Core);
	WritePackFloat(hNewPack, fRange);
	WritePackFloat(hNewPack, vOriginAim[0]);
	WritePackFloat(hNewPack, vOriginAim[1]);
	WritePackFloat(hNewPack, vOriginAim[2]);
	WritePackFloat(hNewPack, vOriginPlayer[0]);
	WritePackFloat(hNewPack, vOriginPlayer[1]);
	WritePackFloat(hNewPack, vOriginPlayer[2]);
}

public Action:Timer_DSfire2(Handle:Timer, Handle:hDataPack) {
	new Float:vOriginAim[3], Float:vOriginPlayer[3];
	ResetPack(hDataPack);
	new Client = ReadPackCell(hDataPack);
	new Obj_Push = ReadPackCell(hDataPack);
	new Obj_Core = ReadPackCell(hDataPack);
	new Float:fRange = ReadPackFloat(hDataPack);
	vOriginAim[0] = ReadPackFloat(hDataPack);
	vOriginAim[1] = ReadPackFloat(hDataPack);
	vOriginAim[2] = ReadPackFloat(hDataPack);
	vOriginPlayer[0] = ReadPackFloat(hDataPack);
	vOriginPlayer[1] = ReadPackFloat(hDataPack);
	vOriginPlayer[2] = ReadPackFloat(hDataPack);
	
	if (IsValidEntity(Obj_Push))
		AcceptEntityInput(Obj_Push, "kill", -1);
	if (IsValidEntity(Obj_Core))
		AcceptEntityInput(Obj_Core, "kill", -1);
	
	EmitAmbientSound("npc/strider/fire.wav", vOriginAim, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	EmitAmbientSound("npc/strider/fire.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 15.0, 15.0, 0, 0.0, ColorRed, 20);
	TE_SendToAll();
	TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_Beam, g_Halo, 0, 66, 0.2, 20.0, 20.0, 0, 0.0, ColorWhite, 20);
	TE_SendToAll();
	
	new Obj_Dissolver = CreateDissolver("3");
	new Float:vOriginEntity[3];
	new iCount = 0;
	new iEntity = -1;
	for (new i = 0; i < sizeof(EntityType); i++) {
		while ((iEntity = FindEntityByClassname(iEntity, EntityType[i])) != -1) {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOriginEntity);
			vOriginEntity[2] += 1;
			new String:szClass[33];
			GetEdictClassname(iEntity,szClass,sizeof(szClass));
			if (vOriginEntity[0] != 0 && vOriginEntity[1] != 1 && vOriginEntity[2] != 0 && Build_IsInRange(vOriginEntity, vOriginAim, fRange)) {
				if (StrEqual(szClass, "func_physbox"))
					AcceptEntityInput(iEntity, "kill", -1);
				else {
					DispatchKeyValue(iEntity, "targetname", "Del_Target");
					SetVariantString("Del_Target");
					AcceptEntityInput(Obj_Dissolver, "dissolve", iEntity, Obj_Dissolver, 0);
					DispatchKeyValue(iEntity, "targetname", "Del_Drop");
				}
				new iOwner = Build_ReturnEntityOwner(iEntity);
				if(iOwner != -1) {
					if(StrEqual(szClass, "prop_ragdoll"))
						Build_SetLimit(iOwner, -1, true);
					else
						Build_SetLimit(iOwner, -1);
						
					Build_RegisterEntityOwner(iEntity, -1);
				}
				iCount++;
			}
		}
	}
	AcceptEntityInput(Obj_Dissolver, "kill", -1);
	if (iCount > 0 && Build_IsClientValid(Client, Client))
		Build_PrintToChat(Client, "Deleted %i props.", iCount);
}

public OnPropBreak(const String:output[], iEntity, iActivator, Float:delay) {
	if (IsValidEntity(iEntity))
		CreateTimer(0.1, Timer_PropBreak, iEntity);
}

public Action:Timer_PropBreak(Handle:Timer, any:iEntity) {
	if (!IsValidEntity(iEntity))
		return;
	new iOwner = Build_ReturnEntityOwner(iEntity);
	if (iOwner > 0) {
		Build_SetLimit(iOwner, -1);
		Build_RegisterEntityOwner(iEntity, -1);
		AcceptEntityInput(iEntity, "kill", -1);
	}
}

stock DrowLine(Float:vPoint1[3], Float:vPoint2[3], Color[4], bool:bFinale = false) {
	if (bFinale)
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.5, 7.0, 7.0, 0, 0.0, Color, 20);
	else
		TE_SetupBeamPoints(vPoint1, vPoint2, g_Beam, g_Halo, 0, 66, 0.15, 7.0, 7.0, 0, 0.0, Color, 20);
	TE_SendToAll();
}

stock CreatePush(Float:vOrigin[3], Float:fMagnitude, Float:fRange, String:szSpawnFlags[8]) {
	new Push_Index = CreateEntityByName("point_push");
	TeleportEntity(Push_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Push_Index, "magnitude", fMagnitude);
	DispatchKeyValueFloat(Push_Index, "radius", fRange);
	DispatchKeyValueFloat(Push_Index, "inner_radius", fRange);
	DispatchKeyValue(Push_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Push_Index);
	return Push_Index;
}

stock CreateCore(Float:vOrigin[3], Float:fScale, String:szSpawnFlags[8]) {
	new Core_Index = CreateEntityByName("env_citadel_energy_core");
	TeleportEntity(Core_Index, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValueFloat(Core_Index, "scale", fScale);
	DispatchKeyValue(Core_Index, "spawnflags", szSpawnFlags);
	DispatchSpawn(Core_Index);
	return Core_Index;
}

stock CreateDissolver(String:szDissolveType[4]) {
	new Dissolver_Index = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(Dissolver_Index, "dissolvetype", szDissolveType);
	DispatchKeyValue(Dissolver_Index, "targetname", "Del_Dissolver");
	DispatchSpawn(Dissolver_Index);
	return Dissolver_Index;
}

