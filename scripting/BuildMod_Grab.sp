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

new g_Beam;
new g_Halo;
new g_PBeam;

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

new MoveType:g_mtGrabMoveType[MAXPLAYERS];
new g_iGrabTarget[MAXPLAYERS];
new Float:g_vGrabPlayerOrigin[MAXPLAYERS][3];
new bool:g_bGrabIsRunning[MAXPLAYERS];
new bool:g_bGrabFreeze[MAXPLAYERS];

public Plugin:myinfo = {
	name = "TF2 Sandbox - Grab",
	author = "Danct12",
	description = "Grab props to somewhere.",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {
	RegAdminCmd("+grab", Command_EnableGrab, 0, "Grab props.");
	RegAdminCmd("-grab", Command_DisableGrab, 0, "Grab props.");
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

public Action:Command_EnableGrab(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	g_iGrabTarget[Client] = Build_ClientAimEntity(Client, true, true);
	if (g_iGrabTarget[Client] == -1)
		return Plugin_Handled;
	
	if (g_bGrabIsRunning[Client]) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "你正在移動其他物件!");
		else
			Build_PrintToChat(Client, "You are already grabbing something!");
		return Plugin_Handled;
	}	
	
	if (!Build_IsAdmin(Client)) {
		if (GetEntityFlags(g_iGrabTarget[Client]) == (FL_CLIENT | FL_FAKECLIENT))
			return Plugin_Handled;
	}
	
	if (Build_IsEntityOwner(Client, g_iGrabTarget[Client])) {		
		decl String:szFreeze[20], String:szColorR[20], String:szColorG[20], String:szColorB[20], String:szColor[128];
		GetCmdArg(1, szFreeze, sizeof(szFreeze));
		GetCmdArg(2, szColorR, sizeof(szColorR));
		GetCmdArg(3, szColorG, sizeof(szColorG));
		GetCmdArg(4, szColorB, sizeof(szColorB));
		
		g_bGrabFreeze[Client] = true;
		if (StrEqual(szFreeze, "1"))
			g_bGrabFreeze[Client] = true;
		
		DispatchKeyValue(g_iGrabTarget[Client], "rendermode", "5");
		DispatchKeyValue(g_iGrabTarget[Client], "renderamt", "150");
		DispatchKeyValue(g_iGrabTarget[Client], "renderfx", "4");
		
		if (StrEqual(szColorR, ""))
			szColorR = "255";
		if (StrEqual(szColorG, ""))
			szColorG = "50";
		if (StrEqual(szColorB, ""))
			szColorB = "50";
		Format(szColor, sizeof(szColor), "%s %s %s", szColorR, szColorG, szColorB);
		DispatchKeyValue(g_iGrabTarget[Client], "rendercolor", szColor);
		
		g_mtGrabMoveType[Client] = GetEntityMoveType(g_iGrabTarget[Client]);
		g_bGrabIsRunning[Client] = true;
		
		CreateTimer(0.01, Timer_GrabBeam, Client);
		CreateTimer(0.01, Timer_GrabRing, Client);
		CreateTimer(0.05, Timer_GrabMain, Client);
	}
	return Plugin_Handled;
}

public Action:Command_DisableGrab(Client, args) {
	g_bGrabIsRunning[Client] = false;
	return Plugin_Handled;
}

public Action:Timer_GrabBeam(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		new Float:vOriginEntity[3], Float:vOriginPlayer[3];
		
		GetClientAbsOrigin(Client, g_vGrabPlayerOrigin[Client]);
		GetClientAbsOrigin(Client, vOriginPlayer);
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		vOriginPlayer[2] += 50;
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamPoints(vOriginEntity, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 0.1, 2.0, 2.0, 0, 0.0, iColor, 20);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.01, Timer_GrabBeam, Client);
	}
}

public Action:Timer_GrabRing(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		new Float:vOriginEntity[3];
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		
		new iColor[4];
		iColor[0] = GetRandomInt(50, 255);
		iColor[1] = GetRandomInt(50, 255);
		iColor[2] = GetRandomInt(50, 255);
		iColor[3] = 255;
		
		TE_SetupBeamRingPoint(vOriginEntity, 10.0, 15.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SetupBeamRingPoint(vOriginEntity, 80.0, 100.0, g_Beam, g_Halo, 0, 10, 0.6, 3.0, 0.5, iColor, 5, 0);
		TE_SendToAll();
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.3, Timer_GrabRing, Client);
	}
}

public Action:Timer_GrabMain(Handle:Timer, any:Client) {
	if(IsValidEntity(g_iGrabTarget[Client]) && Build_IsClientValid(Client, Client)) {
		if (!Build_IsAdmin(Client)) {
			if (Build_ReturnEntityOwner(g_iGrabTarget[Client]) != Client) {
				g_bGrabIsRunning[Client] = false;
				return;
			}
		}
		
		new Float:vOriginEntity[3], Float:vOriginPlayer[3];
		
		GetEntPropVector(g_iGrabTarget[Client], Prop_Data, "m_vecOrigin", vOriginEntity);
		GetClientAbsOrigin(Client, vOriginPlayer);
		
		vOriginEntity[0] += vOriginPlayer[0] - g_vGrabPlayerOrigin[Client][0];
		vOriginEntity[1] += vOriginPlayer[1] - g_vGrabPlayerOrigin[Client][1];
		vOriginEntity[2] += vOriginPlayer[2] - g_vGrabPlayerOrigin[Client][2];
		
		if(Phys_IsPhysicsObject(g_iGrabTarget[Client])) {
			Phys_EnableMotion(g_iGrabTarget[Client], false);
			Phys_Sleep(g_iGrabTarget[Client]);
		}
		SetEntityMoveType(g_iGrabTarget[Client], MOVETYPE_NONE);
		TeleportEntity(g_iGrabTarget[Client], vOriginEntity, NULL_VECTOR, NULL_VECTOR);
		
		if (g_bGrabIsRunning[Client])
			CreateTimer(0.001, Timer_GrabMain, Client);
		else {
			if (GetEntityFlags(g_iGrabTarget[Client]) & (FL_CLIENT | FL_FAKECLIENT))
				SetEntityMoveType(g_iGrabTarget[Client], MOVETYPE_WALK);
			else {
				if (!g_bGrabFreeze[Client] && Phys_IsPhysicsObject(g_iGrabTarget[Client])) {
					Phys_EnableMotion(g_iGrabTarget[Client], true);
					Phys_Sleep(g_iGrabTarget[Client]);
				}
				SetEntityMoveType(g_iGrabTarget[Client], g_mtGrabMoveType[Client]);
			}
			DispatchKeyValue(g_iGrabTarget[Client], "rendermode", "5");
			DispatchKeyValue(g_iGrabTarget[Client], "renderamt", "255");
			DispatchKeyValue(g_iGrabTarget[Client], "renderfx", "0");
			DispatchKeyValue(g_iGrabTarget[Client], "rendercolor", "255 255 255");
		}
	}
	return;
}
