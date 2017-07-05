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

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

public Plugin:myinfo = {
	name = "TF2 Sandbox - Banlist",
	author = "Danct12, DaRkWoRlD",
	description = "Add client to blacklist that cant use BuildMod.",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_bl", Command_AddBL, ADMFLAG_CONVARS, "Add client to blacklist");
	RegAdminCmd("sm_unbl", Command_RemoveBL, ADMFLAG_CONVARS, "Remove client from blacklist");
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "BuildMod Client Language.", CookieAccess_Private);
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

public Action:Command_AddBL(Client, args) {
	if (args < 1) {
		ReplyToCommand(Client, "[SM] Usage: sm_bl <#userid|name>");
		return Plugin_Handled;
	}
	
	new String:arg[33];
	GetCmdArg(1, arg, sizeof(arg));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, Client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(Client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++) {
		new target = target_list[i];
		
		if(Build_IsBlacklisted(target)) {
			Build_PrintToChat(Client, "%s is already blacklisted!", target_name);
			return Plugin_Handled;
		} else 
			Build_AddBlacklist(target);
	}
	
	for (new i = 0; i < MaxClients; i++) {
		if (Build_IsClientValid(i, i)) {
			if (g_bClientLang[i])
				Build_PrintToChat(i, "%N 將 %s 加入到黑名單 :(", Client, target_name);
			else
				Build_PrintToChat(i, "%N added %s to BuildMod blacklist :(", Client, target_name);
		}
	}
	return Plugin_Handled;
}

public Action:Command_RemoveBL(Client, args) {
	if (args < 1) {
		ReplyToCommand(Client, "[SM] Usage: sm_unbl <#userid|name>");
		return Plugin_Handled;
	}
	
	new String:arg[33];
	GetCmdArg(1, arg, sizeof(arg));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, Client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(Client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++) {
		new target = target_list[i];
		
		if(!Build_RemoveBlacklist(target)) {
			Build_PrintToChat(Client, "%s is not in blacklist!", target_name);
			return Plugin_Handled;
		}
	}
	
	if(tn_is_ml) {
		for (new i = 0; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i)) {
				if (g_bClientLang[i])
					Build_PrintToChat(i, "%N 將 %s 從黑名單移除 :)", Client, target_name);
				else
					Build_PrintToChat(i, "%N removed %s from BuildMod blacklist :)", Client, target_name);
			}
		}
	} else {
		for (new i = 0; i < MaxClients; i++) {
			if (Build_IsClientValid(i, i)) {
				if (g_bClientLang[i])
					Build_PrintToChat(i, "%N 將 %s 從黑名單移除 :)", Client, target_name);
				else
					Build_PrintToChat(i, "%N removed %s from BuildMod blacklist :)", Client, target_name);
			}
		}
	}
	
	return Plugin_Handled;
}
