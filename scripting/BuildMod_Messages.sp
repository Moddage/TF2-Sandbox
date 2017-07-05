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

public Plugin:myinfo = {
	name = "TF2 Sandbox - Show Prop Info",
	author = "DaRkWoRlD",
	description = "Show props infomation.",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {
	LoadTranslations("common.phrases");
	CreateTimer(0.1, Display_Msgs, 0, TIMER_REPEAT);
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
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

public Action:Display_Msgs(Handle:timer) {	
	for (new Client = 1; Client <= MaxClients; Client++) {		
		if (Build_IsClientValid(Client, Client, true) && !IsFakeClient(Client)) {
			new iAimTarget = Build_ClientAimEntity(Client, false, true);
			if (iAimTarget != -1 && IsValidEdict(iAimTarget))
				EntityInfo(Client, iAimTarget);
		}
	}
	return;
}

public EntityInfo(Client, iTarget) {
	if (IsFunc(iTarget))
		return;
	
	SetHudTextParams(0.015, 0.08, 0.1, 255, 255, 255, 255, 0, 6.0, 0.1, 0.2);
	if (IsPlayer(iTarget)) {
		new iHealth = GetClientHealth(iTarget);
		if (iHealth <= 1)
			iHealth = 0;
		if (Build_IsAdmin(Client)) {
			new String:szSteamId[32], String:szIP[16];
			GetClientAuthString(iTarget, szSteamId, sizeof(szSteamId));
			GetClientIP(iTarget, szIP, sizeof(szIP));
			if (g_bClientLang[Client])
				ShowHudText(Client, -1, "玩家: %N\n血量: %i\n玩家編號: %i\nSteamID:%s", iTarget, iHealth, GetClientUserId(iTarget), szSteamId);
			else
				ShowHudText(Client, -1, "Player: %N\nHealth: %i\nUserID: %i\nSteamID:%s", iTarget, iHealth, GetClientUserId(iTarget), szSteamId);
		} else {
			if (g_bClientLang[Client])
				ShowHudText(Client, -1, "玩家: %N\n血量: %i", iTarget, iHealth);
			else
				ShowHudText(Client, -1, "Player: %N\nHealth: %i", iTarget, iHealth);
		}
		return;
	}
	new String:szClass[32];
	GetEdictClassname(iTarget, szClass, sizeof(szClass));
	if (IsNpc(iTarget)) {
		new iHealth = GetEntProp(iTarget, Prop_Data, "m_iHealth");
		if (iHealth <= 1)
			iHealth = 0;
		if (g_bClientLang[Client])
			ShowHudText(Client, -1, "類型: %s\n血量: %i", szClass, iHealth);
		else
			ShowHudText(Client, -1, "Classname: %s\nHealth: %i", szClass, iHealth);
		return;
	}
	
	new String:szModel[128], String:szOwner[32], String:szPropString[256];
	new String:szGetThoseString = GetEntPropString(iTarget, Prop_Data, "m_iName", szPropString, sizeof(szPropString));
	new iOwner = Build_ReturnEntityOwner(iTarget);
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	if (iOwner != -1)
		GetClientName(iOwner, szOwner, sizeof(szOwner));
	else if (iOwner > MAXPLAYERS){
		if (g_bClientLang[Client])
			szOwner = "*離線";
		else
			szOwner = "*Disconnectd";
	} else {
		if (g_bClientLang[Client])
			szOwner = "*無";
		else
			szOwner = "*World";
	}
	
	if (Phys_IsPhysicsObject(iTarget)) {
		SetHudTextParams(-1.0, 0.6, 0.1, 255, 0, 0, 255);
		if (StrContains(szClass, "prop_door_", false) == 0){
			ShowHudText(Client, -1, "%s \nbuilt by %s\nPress [TAB] to use", szPropString , szOwner);
		}
		else {
			ShowHudText(Client, -1, "%s \nbuilt by %s", szPropString , szOwner);
		}
		//if (g_bClientLang[Client])
			
			//ShowHudText(Client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s\n重量:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
		//else
			//ShowHudText(Client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s\nMass:%f", szClass, iTarget, szModel, szOwner, Phys_GetMass(iTarget));
	} else {
		if (g_bClientLang[Client])
			ShowHudText(Client, -1, "%s \nbuilt by %s", szPropString , szOwner);
			//ShowHudText(Client, -1, "類型: %s\n編號: %i\n模組: %s\n擁有者: %s", szClass, iTarget, szModel, szOwner);
		//else
			//ShowHudText(Client, -1, "Classname: %s\nIndex: %i\nModel: %s\nOwner: %s", szClass, iTarget, szModel, szOwner);
	}
	return;
}

bool:IsFunc(iEntity){
	new String:szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "func_", false) == 0 && !StrEqual(szClass, "func_physbox"))
		return true;
	return false;
}

bool:IsNpc(iEntity){
	new String:szClass[32];
	GetEdictClassname(iEntity, szClass, sizeof(szClass));
	if (StrContains(szClass, "npc_", false) == 0)
		return true;
	return false;
}

bool:IsPlayer(iEntity){
	if ((GetEntityFlags(iEntity) & (FL_CLIENT | FL_FAKECLIENT)))
		return true;
	return false;
}


