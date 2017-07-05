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
#include <vphysics>

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

new g_iCopyTarget[MAXPLAYERS];
new Float:g_fCopyPlayerOrigin[MAXPLAYERS][3];
new bool:g_bCopyIsRunning[MAXPLAYERS] = false;

new g_Beam;
new g_Halo;
new g_PBeam;

new bool:g_bBuffer[MAXPLAYERS + 1];

new String:CopyableProps[][] = {
	"prop_dynamic",
	"prop_dynamic_override",
	"prop_physics",
	"prop_physics_multiplayer",
	"prop_physics_override",
	"prop_physics_respawnable",
	"prop_ragdoll",
	"func_physbox",
	"player"
};

public Plugin:myinfo = {
	name = "TF2 Sandbox - Duplicator",
	author = "Danct12",
	description = "Copy props",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {
	RegAdminCmd("+copy", Command_Copy, 0, "Copy a prop.");
	RegAdminCmd("-copy", Command_Paste, 0, "Paste a copied prop.");
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
}

public OnMapStart() {
	g_Halo = PrecacheModel("materials/sprites/halo01.vmt");
	g_Beam = PrecacheModel("materials/sprites/laser.vmt");
	g_PBeam = PrecacheModel("materials/sprites/physbeam.vmt");
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

public Action:Command_Copy(Client, args) {
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "Anti Spam Protection, please wait.");

		return Plugin_Handled;
	}

	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	
	
	new iEntity = Build_ClientAimEntity(Client, true, true);
	if (iEntity == -1)
		return Plugin_Handled;
		
	if(!Build_IsAdmin(Client, true)) {
		if (GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (!Build_IsEntityOwner(Client, iEntity, true))
		return Plugin_Handled;
	
	if (g_bCopyIsRunning[Client]) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "你正在複製其他物件!");
		else
			Build_PrintToChat(Client, "You are already copying something!");
		return Plugin_Handled;
	}
	
	new String:szClass[33], bool:bCanCopy = false;
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	for (new i = 0; i < sizeof(CopyableProps); i++) {
		if(StrEqual(szClass, CopyableProps[i], false))
			bCanCopy = true;
	}
	
	new bool:IsDoll = false;
	if (StrEqual(szClass, "prop_ragdoll") || StrEqual(szClass, "player")) {
		if (Build_IsAdmin(Client, true)) {
			g_iCopyTarget[Client] = CreateEntityByName("prop_ragdoll");
			IsDoll = true;
		} else {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "你需要 \x04二級建造權限\x01 才能複製此物件!");
			else
				Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to copy this prop!");
			return Plugin_Handled;
		}
	} else {
		if (StrEqual(szClass, "func_physbox") && !Build_IsAdmin(Client, true)) {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "你無法複製此物件!");
			else
				Build_PrintToChat(Client, "You cant copy this prop!");
			return Plugin_Handled;
		}
		
		g_iCopyTarget[Client] = CreateEntityByName(szClass);
	}
	
	if (Build_RegisterEntityOwner(g_iCopyTarget[Client], Client, IsDoll)) {
		if (bCanCopy) {
			new Float:fEntityOrigin[3], Float:fEntityAngle[3];
			new String:szModelName[128];
			new String:szColorR[20], String:szColorG[20], String:szColorB[20], String:szColor[3][128], String:szColor2[255];
			
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
			GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
			if (StrEqual(szModelName, "models/props_c17/oildrum001_explosive.mdl") && !Build_IsAdmin(Client, true)) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "你需要 \x04二級建造權限\x01 才能複製此物件!");
				else
					Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to copy this prop!");
				RemoveEdict(g_iCopyTarget[Client]);
				return Plugin_Handled;
			}
			DispatchKeyValue(g_iCopyTarget[Client], "model", szModelName);
			
			
			GetEdictClassname(g_iCopyTarget[Client], szClass, sizeof(szClass));
			if (StrEqual(szClass, "prop_dynamic")) {
				SetEntProp(g_iCopyTarget[Client], Prop_Send, "m_nSolidType", 6);
				SetEntProp(g_iCopyTarget[Client], Prop_Data, "m_nSolidType", 6);
			}
			
			DispatchSpawn(g_iCopyTarget[Client]);
			TeleportEntity(g_iCopyTarget[Client], fEntityOrigin, fEntityAngle, NULL_VECTOR);
			
			if (Phys_IsPhysicsObject(g_iCopyTarget[Client]))
				Phys_EnableMotion(g_iCopyTarget[Client], false);
			
			GetCmdArg(1, szColorR, sizeof(szColorR));
			GetCmdArg(2, szColorG, sizeof(szColorG));
			GetCmdArg(3, szColorB, sizeof(szColorB));
			
			DispatchKeyValue(g_iCopyTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[Client], "renderamt", "150");
			DispatchKeyValue(g_iCopyTarget[Client], "renderfx", "4");
			
			if (args > 1) {
				szColor[0] = szColorR;
				szColor[1] = szColorG;
				szColor[2] = szColorB;
				ImplodeStrings(szColor, 3, " ", szColor2, 255);
				DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", szColor2);
			} else {
				DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", "50 255 255");
			}
			g_bCopyIsRunning[Client] = true;
			
			CreateTimer(0.01, Timer_CopyRing, Client);
			CreateTimer(0.01, Timer_CopyBeam, Client);
			CreateTimer(0.02, Timer_CopyMain, Client);
			return Plugin_Handled;
		} else {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "此物件無法複製.");
			else
				Build_PrintToChat(Client, "This prop was not copy able.");
			return Plugin_Handled;
		}
	} else {
		RemoveEdict(g_iCopyTarget[Client]);
		return Plugin_Handled;
	}
}

public Action:Command_Paste(Client, args) {
	
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client))
		return Plugin_Handled;
		
	g_bCopyIsRunning[Client] = false;
	return Plugin_Handled;
}

public Action:Timer_CopyBeam(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginPlayer[3], Float:fOriginEntity[3];
		
		GetClientAbsOrigin(Client, g_fCopyPlayerOrigin[Client]);
		GetClientAbsOrigin(Client, fOriginPlayer);
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		fOriginPlayer[2] += 50;
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = GetRandomInt(255, 255);
		
		TE_SetupBeamPoints(fOriginEntity, fOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
		if (g_bCopyIsRunning[Client])
			CreateTimer(0.01, Timer_CopyBeam, Client);	
	}
}

public Action:Timer_CopyRing(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginEntity[3];
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(254, 255);
		iColor[2] = GetRandomInt(254, 255);
		iColor[3] = GetRandomInt(250, 255);
		
		TE_SetupBeamRingPoint(fOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(fOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
		if (g_bCopyIsRunning[Client])
			CreateTimer(0.3, Timer_CopyRing, Client);
	}
}

public Action:Timer_CopyMain(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iCopyTarget[Client]) && Build_IsClientValid(Client, Client)) {
		decl Float:fOriginEntity[3], Float:fOriginPlayer[3];
		
		GetEntPropVector(g_iCopyTarget[Client], Prop_Data, "m_vecOrigin", fOriginEntity);
		GetClientAbsOrigin(Client, fOriginPlayer);
		
		fOriginEntity[0] += fOriginPlayer[0] - g_fCopyPlayerOrigin[Client][0];
		fOriginEntity[1] += fOriginPlayer[1] - g_fCopyPlayerOrigin[Client][1];
		fOriginEntity[2] += fOriginPlayer[2] - g_fCopyPlayerOrigin[Client][2];
		
		if(Phys_IsPhysicsObject(g_iCopyTarget[Client])) {
			Phys_EnableMotion(g_iCopyTarget[Client], false);
			Phys_Sleep(g_iCopyTarget[Client]);
		}
		SetEntityMoveType(g_iCopyTarget[Client], MOVETYPE_NONE);
		TeleportEntity(g_iCopyTarget[Client], fOriginEntity, NULL_VECTOR, NULL_VECTOR);

		if (g_bCopyIsRunning[Client])
			CreateTimer(0.001, Timer_CopyMain, Client);
		else {
			if(Phys_IsPhysicsObject(g_iCopyTarget[Client])) {
				Phys_EnableMotion(g_iCopyTarget[Client], false);
				Phys_Sleep(g_iCopyTarget[Client]);
			}
			SetEntityMoveType(g_iCopyTarget[Client], MOVETYPE_VPHYSICS);
			
			DispatchKeyValue(g_iCopyTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iCopyTarget[Client], "renderamt", "255");
			DispatchKeyValue(g_iCopyTarget[Client], "renderfx", "0");
			DispatchKeyValue(g_iCopyTarget[Client], "rendercolor", "255 255 255");
		}
	}
}

public Action:Timer_CoolDown(Handle:hTimer, any:iBuffer)
{
	new iClient = GetClientFromSerial(iBuffer);

	if (g_bBuffer[iClient]) g_bBuffer[iClient] = false;
}