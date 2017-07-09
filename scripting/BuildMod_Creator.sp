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
#include <smlib>

new bool:g_bClientLang[MAXPLAYERS];
new Handle:g_hCookieClientLang;

new Handle:g_hCookieSDoorTarget;
new Handle:g_hCookieSDoorModel;

new Handle:g_hPropNameArray;
new Handle:g_hPropModelPathArray;
new Handle:g_hPropTypeArray;
new Handle:g_hPropStringArray;
new String:g_szFile[128];

new ColorBlue[4]	= {
		50,
		50,
		255,
		255};
		
new g_Halo;
new g_PBeam;

new bool:g_bBuffer[MAXPLAYERS + 1];

public Plugin:myinfo = {
	name = "TF2 Sandbox - Creator",
	author = "Danct12, DaRkWoRlD",
	description = "Create props to build.",
	version = BUILDMOD_VER,
	url = "http://twbz.net/"
};

public OnPluginStart() {
	// For better compatibility
	RegConsoleCmd("kill", Command_kill, "");
	RegConsoleCmd("noclip", Command_Fly, "");

	// Basic Spawn Commands
	RegAdminCmd("sm_spawnprop", Command_SpawnProp, 0, "Spawn a prop in command list!");
	RegAdminCmd("sm_prop", Command_SpawnProp, 0, "Spawn props in command list, too!");
	
	// More building useful stuffs
	RegAdminCmd("sm_skin", Command_Skin, 0, "Color a prop.");
	
	// Coloring Props and more
	RegAdminCmd("sm_color", Command_Color, 0, "Color a prop.");
	RegAdminCmd("sm_render", Command_Render, 0, "Render an entity.");
	
	// Rotating stuffs
	RegAdminCmd("sm_rotate", Command_Rotate, 0, "Rotate an entity.");
	RegAdminCmd("sm_r", Command_Rotate, 0, "Rotate an entity.");
	RegAdminCmd("sm_accuraterotate", Command_AccurateRotate, 0, "Accurate rotate a prop.");
	RegAdminCmd("sm_ar", Command_AccurateRotate, 0, "Accurate rotate a prop.");
	RegAdminCmd("sm_move", Command_Move, 0, "Move a prop to a position.");
	
	// Misc stuffs
	RegAdminCmd("sm_sdoor", Command_SpawnDoor, 0, "Doors creator.");
	RegAdminCmd("sm_lightforbesure", Command_LightDynamic, 0, "Dynamic Light.");
	RegAdminCmd("sm_fly", Command_Fly, 0, "I BELIEVE I CAN FLYYYYYYY, I BELIEVE THAT I CAN TOUCH DE SKY");
	RegAdminCmd("sm_setname", Command_SetName, 0, "SetPropname");
	RegAdminCmd("sm_simplelight", Command_SimpleLight, 0, "Spawn a Light, in a very simple way.");
	RegAdminCmd("sm_propdoor", Command_OpenableDoorProp, 0, "Making a door, in prop_door way.");
	RegAdminCmd("sm_propscale", Command_PropScale, ADMFLAG_ROOT, "Resizing a prop");
	
	g_hCookieSDoorTarget = RegClientCookie("cookie_SDoorTarget", "For SDoor.", CookieAccess_Private);
	g_hCookieSDoorModel = RegClientCookie("cookie_SDoorModel", "For SDoor.", CookieAccess_Private);
	g_hCookieClientLang = RegClientCookie("cookie_BuildModClientLang", "TF2SB Client Language.", CookieAccess_Private);
	g_hPropNameArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropModelPathArray = CreateArray(128, 2048);	// Max Prop List is 1024-->2048
	g_hPropTypeArray = CreateArray(33, 2048);		// Max Prop List is 1024-->2048
	g_hPropStringArray = CreateArray(256, 2048);
	
	ReadProps();
}

public OnMapStart() {
	g_Halo = PrecacheModel("materials/sprites/halo01.vmt");
	g_PBeam = PrecacheModel("materials/sprites/physbeam.vmt");
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
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

public Action:Command_OpenableDoorProp(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "Anti Spam Protection, please wait.");

		return Plugin_Handled;
	}

	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	new iDoor = CreateEntityByName("prop_door_rotating");
	if (Build_RegisterEntityOwner(iDoor, Client)) {
		new String:szRange[33], String:szBrightness[33], String:szColorR[33], String:szColorG[33], String:szColorB[33];
		new String:szNamePropDoor[64];
		new Float:fOriginAim[3];
		GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(2, szBrightness, sizeof(szBrightness));
		GetCmdArg(3, szColorR, sizeof(szColorR));
		GetCmdArg(4, szColorG, sizeof(szColorG));
		GetCmdArg(5, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(Client, fOriginAim);
		fOriginAim[2] += 50;
		
		if(!IsModelPrecached("models/props_manor/doorframe_01_door_01a.mdl"))
			PrecacheModel("models/props_manor/doorframe_01_door_01a.mdl");
		
		DispatchKeyValue(iDoor, "model", "models/props_manor/doorframe_01_door_01a.mdl");
		DispatchKeyValue(iDoor, "distance", "90");
		DispatchKeyValue(iDoor, "speed", "100");
		DispatchKeyValue(iDoor, "returndelay", "-1");
		DispatchKeyValue(iDoor, "dmg", "-20");
		DispatchKeyValue(iDoor, "opendir", "0");
		DispatchKeyValue(iDoor, "spawnflags", "8192");
		//DispatchKeyValue(iDoor, "OnFullyOpen", "!caller,close,,0,-1");
		DispatchKeyValue(iDoor, "hardware", "1");

		DispatchSpawn(iDoor);
		
		TeleportEntity(iDoor, fOriginAim, NULL_VECTOR, NULL_VECTOR);
		
		Format(szNamePropDoor, sizeof(szNamePropDoor), "TF2SB_Door%i", GetRandomInt(1000, 5000));
		DispatchKeyValue(iDoor, "targetname", szNamePropDoor);
		SetVariantString(szNamePropDoor);
	} else
		RemoveEdict(iDoor);
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_propdoor", szArgs);
	return Plugin_Handled;
}

public Action:Command_kill(Client, Args) {
	if (!Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	ForcePlayerSuicide(Client);
	
	//if (GetCmdArgs() > 0)
	//	Build_PrintToChat(Client, "Don't use unneeded args in kill");
	
	return Plugin_Handled;
}

public Action:Command_Render(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 5) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !render <透明度> <特效> <紅> <綠> <藍>");
			Build_PrintToChat(Client, "例. 閃爍綠: !render 150 4 15 255 0");
		} else {
			Build_PrintToChat(Client, "Usage: !render <fx amount> <fx> <R> <G> <B>");
			Build_PrintToChat(Client, "Ex. Flashing Green: !render 150 4 15 255 0");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szRenderAlpha[20], String:szRenderFX[20], String:szColorRGB[20][3], String:szColors[128];
		GetCmdArg(1, szRenderAlpha, sizeof(szRenderAlpha));
		GetCmdArg(2, szRenderFX, sizeof(szRenderFX));
		GetCmdArg(3, szColorRGB[0], sizeof(szColorRGB));
		GetCmdArg(4, szColorRGB[1], sizeof(szColorRGB));
		GetCmdArg(5, szColorRGB[2], sizeof(szColorRGB));
		
		Format(szColors, sizeof(szColors), "%s %s %s", szColorRGB[0], szColorRGB[1], szColorRGB[2]);
		if (StringToInt(szRenderAlpha) < 1)
			szRenderAlpha = "1";
		DispatchKeyValue(iEntity, "rendermode", "5");
		DispatchKeyValue(iEntity, "renderamt", szRenderAlpha);
		DispatchKeyValue(iEntity, "renderfx", szRenderFX);
		DispatchKeyValue(iEntity, "rendercolor", szColors);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_render", szArgs);
	return Plugin_Handled;
}

public Action:Command_Color(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 3) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !color <紅> <綠> <藍>");
			Build_PrintToChat(Client, "例: 綠色: !color 0 255 0");
		} else {
			Build_PrintToChat(Client, "Usage: !color <R> <G> <B>");
			Build_PrintToChat(Client, "Ex: Green: !color 0 255 0");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szColorRGB[20][3], String:szColors[33];
		GetCmdArg(1, szColorRGB[0], sizeof(szColorRGB));
		GetCmdArg(2, szColorRGB[1], sizeof(szColorRGB));
		GetCmdArg(3, szColorRGB[2], sizeof(szColorRGB));
		
		Format(szColors, sizeof(szColors), "%s %s %s", szColorRGB[0], szColorRGB[1], szColorRGB[2]);
		DispatchKeyValue(iEntity, "rendermode", "5");
		DispatchKeyValue(iEntity, "renderamt", "255");
		DispatchKeyValue(iEntity, "renderfx", "0");
		DispatchKeyValue(iEntity, "rendercolor", szColors);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_color", szArgs);
	return Plugin_Handled;
}

public Action:Command_PropScale(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 1) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !propscale <編號>");
			Build_PrintToChat(Client, "註: 不是每個物件都有多個 skin");
		} else {
			Build_PrintToChat(Client, "Usage: !propscale <number>");
			Build_PrintToChat(Client, "Notice: Not every model have multiple skins.");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		
		//new Float:Scale2  = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
		new String:szPropScale[33];
		GetCmdArg(1, szPropScale, sizeof(szPropScale));
		
		new Float:Scale = StringToFloat(szPropScale);
		
		SetVariantString(szPropScale);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", Scale);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_propscale", szArgs);
	return Plugin_Handled;
}

public Action:Command_Skin(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !skin <編號>");
			Build_PrintToChat(Client, "註: 不是每個物件都有多個 skin");
		} else {
			Build_PrintToChat(Client, "Usage: !skin <number>");
			Build_PrintToChat(Client, "Notice: Not every model have multiple skins.");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szSkin[33];
		GetCmdArg(1, szSkin, sizeof(szSkin));
		
		SetVariantString(szSkin);
		AcceptEntityInput(iEntity, "skin", iEntity, Client, 0);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_skin", szArgs);
	return Plugin_Handled;
}

public Action:Command_Rotate(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 1) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !rotate/!r <x> <y> <z>");
			Build_PrintToChat(Client, "例: !rotate 0 90 0");
		} else {
			Build_PrintToChat(Client, "Usage: !rotate/!r <x> <y> <z>");
			Build_PrintToChat(Client, "Ex: !rotate 0 90 0");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szAngleX[8], String:szAngleY[8], String:szAngleZ[8];
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];
		GetCmdArg(1, szAngleX, sizeof(szAngleX));
		GetCmdArg(2, szAngleY, sizeof(szAngleY));
		GetCmdArg(3, szAngleZ, sizeof(szAngleZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		fEntityAngle[0] += StringToFloat(szAngleX);
		fEntityAngle[1] += StringToFloat(szAngleY);
		fEntityAngle[2] += StringToFloat(szAngleZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_rotate", szArgs);
	return Plugin_Handled;
}

public Action:Command_Fly(Client, args) {

	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;

	if (GetEntityMoveType(Client) != MOVETYPE_NOCLIP)
	{
		Build_PrintToChat(Client, "Noclip ON");
		SetEntityMoveType(Client, MOVETYPE_NOCLIP);
	}
	else
	{
		Build_PrintToChat(Client, "Noclip OFF");
		SetEntityMoveType(Client, MOVETYPE_WALK);
	}
	return Plugin_Handled;
}

public Action:Command_SimpleLight(Client, args) {

	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
		
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "Anti Spam Protection, please wait.");

		return Plugin_Handled;
	}

	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));

	FakeClientCommand(Client, "sm_lightforbesure 500 5 255 255 255");

	return Plugin_Handled;
}

public Action:Command_AccurateRotate(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 1) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "用法: !ar <x> <y> <z>");
		else
			Build_PrintToChat(Client, "Usage: !ar <x> <y> <z>");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:szRotateX[33], String:szRotateY[33], String:szRotateZ[33];
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];
		GetCmdArg(1, szRotateX, sizeof(szRotateX));
		GetCmdArg(2, szRotateY, sizeof(szRotateY));
		GetCmdArg(3, szRotateZ, sizeof(szRotateZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		fEntityAngle[0] = StringToFloat(szRotateX);
		fEntityAngle[1] = StringToFloat(szRotateY);
		fEntityAngle[2] = StringToFloat(szRotateZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_accuraterotate", szArgs);
	return Plugin_Handled;
}

public Action:Command_LightDynamic(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
	
	if (args < 1) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "用法: !ld <範圍> <亮度> <紅> <綠> <藍>");
		else
			Build_PrintToChat(Client, "Usage: !ld <range> <brightness> <R> <G> <B>");
		return Plugin_Handled;
	}
	
	new Obj_LightDMelon = CreateEntityByName("prop_dynamic");
	if (Build_RegisterEntityOwner(Obj_LightDMelon, Client)) {
		new String:szRange[33], String:szBrightness[33], String:szColorR[33], String:szColorG[33], String:szColorB[33], String:szColor[33];
		new String:szNameMelon[64];
		new Float:fOriginAim[3];
		GetCmdArg(1, szRange, sizeof(szRange));
		GetCmdArg(2, szBrightness, sizeof(szBrightness));
		GetCmdArg(3, szColorR, sizeof(szColorR));
		GetCmdArg(4, szColorG, sizeof(szColorG));
		GetCmdArg(5, szColorB, sizeof(szColorB));
		
		Build_ClientAimOrigin(Client, fOriginAim);
		fOriginAim[2] += 50;
		
		if(!IsModelPrecached("models/props_2fort/lightbulb001.mdl"))
			PrecacheModel("models/props_2fort/lightbulb001.mdl");
		
		if (StrEqual(szBrightness, ""))
			szBrightness = "3";
		if (StringToInt(szColorR) < 100 || StrEqual(szColorR, ""))
			szColorR = "100";
		if (StringToInt(szColorG) < 100 || StrEqual(szColorG, ""))
			szColorG = "100";
		if (StringToInt(szColorB) < 100 || StrEqual(szColorB, ""))
			szColorB = "100";
		Format(szColor, sizeof(szColor), "%s %s %s", szColorR, szColorG, szColorB);
		
		DispatchKeyValue(Obj_LightDMelon, "model", "models/props_2fort/lightbulb001.mdl");
		//DispatchKeyValue(Obj_LightDMelon, "rendermode", "5");
		//DispatchKeyValue(Obj_LightDMelon, "renderamt", "150");
		//DispatchKeyValue(Obj_LightDMelon, "renderfx", "15");
		DispatchKeyValue(Obj_LightDMelon, "rendercolor", szColor);
		
		new Obj_LightDynamic = CreateEntityByName("light_dynamic");
		if (StringToInt(szRange) > 500) {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "範圍上限是 500!");
			else
				Build_PrintToChat(Client, "Max range is 500!");
			return Plugin_Handled;
		}
		if (StringToInt(szBrightness) > 7) {
			if (g_bClientLang[Client])
				Build_PrintToChat(Client, "亮度上限是 7!");
			else
				Build_PrintToChat(Client, "Max brightness is 7!");
			return Plugin_Handled;
		}
		SetVariantString(szRange);
		AcceptEntityInput(Obj_LightDynamic, "distance", -1);
		SetVariantString(szBrightness);
		AcceptEntityInput(Obj_LightDynamic, "brightness", -1);
		SetVariantString("2");
		AcceptEntityInput(Obj_LightDynamic, "style", -1);
		SetVariantString(szColor);
		AcceptEntityInput(Obj_LightDynamic, "color", -1);
		SetEntProp(Obj_LightDMelon, Prop_Send, "m_nSolidType", 6);
		
		DispatchSpawn(Obj_LightDMelon);
		TeleportEntity(Obj_LightDMelon, fOriginAim, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(Obj_LightDynamic);
		TeleportEntity(Obj_LightDynamic, fOriginAim, NULL_VECTOR, NULL_VECTOR);
		
		Format(szNameMelon, sizeof(szNameMelon), "Obj_LightDMelon%i", GetRandomInt(1000, 5000));
		DispatchKeyValue(Obj_LightDMelon, "targetname", szNameMelon);
		SetVariantString(szNameMelon);
		AcceptEntityInput(Obj_LightDynamic, "setparent", -1);
		AcceptEntityInput(Obj_LightDynamic, "turnon", Client, Client);
	} else
		RemoveEdict(Obj_LightDMelon);
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_lightforbesure", szArgs);
	return Plugin_Handled;
}

public Action:Command_SpawnDoor(Client, args) {
	if(!Build_AllowToUse(Client) || Build_IsBlacklisted(Client))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
		
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "Anti Spam Protection, please wait.");

		return Plugin_Handled;
	}

	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	decl String:szDoorTarget[16], String:szType[4], String:szFormatStr[64], String:szNameStr[8];
	decl Float:iAim[3];
	Build_ClientAimOrigin(Client, iAim);
	GetCmdArg(1, szType, sizeof(szType));
	static iEntity;
	new String:szModel[128];
	
	if (StrEqual(szType[0], "1") || StrEqual(szType[0], "2") || StrEqual(szType[0], "3") || StrEqual(szType[0], "4") || StrEqual(szType[0], "5") || StrEqual(szType[0], "6") || StrEqual(szType[0], "7")) {
		new Obj_Door = CreateEntityByName("prop_dynamic");
		
		switch(szType[0]) {
			case '1': szModel = "models/props_lab/blastdoor001c.mdl";
			case '2': szModel = "models/props_lab/blastdoor001c.mdl";
			case '3': szModel = "models/props_lab/blastdoor001c.mdl";
			case '4': szModel = "models/props_lab/blastdoor001c.mdl";
			case '5': szModel = "models/props_lab/blastdoor001c.mdl";
			case '6': szModel = "models/props_lab/blastdoor001c.mdl";
			case '7': szModel = "models/props_lab/blastdoor001c.mdl";
		}
		
		DispatchKeyValue(Obj_Door, "model", szModel);
		SetEntProp(Obj_Door, Prop_Send, "m_nSolidType", 6);
		if(Build_RegisterEntityOwner(Obj_Door, Client)){
			TeleportEntity(Obj_Door, iAim, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(Obj_Door);
		}
	} else if (StrEqual(szType[0], "a") || StrEqual(szType[0], "b") || StrEqual(szType[0], "c")) {
	
		iEntity = Build_ClientAimEntity(Client);
		if (iEntity == -1)
			return Plugin_Handled;
		
		switch(szType[0]) {
			case 'a': {
				new iName = GetRandomInt(1000, 5000);
				
				IntToString(iName, szNameStr, sizeof(szNameStr));
				Format(szFormatStr, sizeof(szFormatStr), "door%s", szNameStr);
				DispatchKeyValue(iEntity, "targetname", szFormatStr);
				
				GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				SetClientCookie(Client, g_hCookieSDoorTarget, szFormatStr);
				SetClientCookie(Client, g_hCookieSDoorModel, szModel);
			}
			case 'b': {
				GetClientCookie(Client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(Client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				
				if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,dog_open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,DisableCollision,,1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,5", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,EnableCollision,,5.1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				} else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Drop,7", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				} else {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", szDoorTarget);
					DispatchKeyValue(iEntity, "OnHealthChanged", szFormatStr);
				}
			}
			case 'c': {
				GetClientCookie(Client, g_hCookieSDoorTarget, szDoorTarget, sizeof(szDoorTarget));
				GetClientCookie(Client, g_hCookieSDoorModel, szModel, sizeof(szModel));
				DispatchKeyValue(iEntity, "spawnflags", "258");
				
				if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,dog_open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,DisableCollision,,1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,5", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,EnableCollision,,5.1", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				} else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl")) {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,RavenDoor_Drop,7", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				} else {
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
					Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", szDoorTarget);
					DispatchKeyValue(iEntity, "OnPlayerUse", szFormatStr);
				}
			}
		}
	} else {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !sdoor <選擇>");
			Build_PrintToChat(Client, "!sdoor 1~7 = 叫出門 door");
			Build_PrintToChat(Client, "!sdoor a = 選擇一個門");
			Build_PrintToChat(Client, "!sdoor b = 選擇按鈕 (射擊按鈕開門)");
			Build_PrintToChat(Client, "!sdoor c = 選擇按鈕 (按E使用開門)");
		} else {
			Build_PrintToChat(Client, "Usage: !sdoor <choose>");
			Build_PrintToChat(Client, "!sdoor 1~7 = Spawn door");
			Build_PrintToChat(Client, "!sdoor a = Select door");
			Build_PrintToChat(Client, "!sdoor b = Select button (Shoot to open)");
			Build_PrintToChat(Client, "!sdoor c = Select button (Press to open)");
			Build_PrintToChat(Client, "NOTE: Not all doors movable using PhysGun, use the !move command!");
		}
	}
	return Plugin_Handled;
}


public Action:Command_Move(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 1) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !move <x> <y> <z>");
			Build_PrintToChat(Client, "例 往上移50: !move 0 0 50");
		} else {
			Build_PrintToChat(Client, "Usage: !move <x> <y> <z>");
			Build_PrintToChat(Client, "Ex, move up 50: !move 0 0 50");
		}
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new Float:fEntityOrigin[3], Float:fEntityAngle[3];	
		new String:szArgX[33], String:szArgY[33], String:szArgZ[33];
		GetCmdArg(1, szArgX, sizeof(szArgX));
		GetCmdArg(2, szArgY, sizeof(szArgY));
		GetCmdArg(3, szArgZ, sizeof(szArgZ));
		
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fEntityAngle);
		
		fEntityOrigin[0] += StringToFloat(szArgX);
		fEntityOrigin[1] += StringToFloat(szArgY);
		fEntityOrigin[2] += StringToFloat(szArgZ);
		
		TeleportEntity(iEntity, fEntityOrigin, fEntityAngle, NULL_VECTOR);
		
		new Float:vOriginPlayer[3], Float:vOriginAim[3];
		
		Build_ClientAimOrigin(Client, vOriginAim);
		GetClientAbsOrigin(Client, vOriginPlayer);
		vOriginPlayer[2] = vOriginPlayer[2] + 50;
		
		TE_SetupBeamPoints(vOriginAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
		TE_SendToAll();
		
		new random = GetRandomInt(0,1);
		if (random == 1) {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		} else {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		}
	}
	
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_move", szArgs);
	return Plugin_Handled;
}

public Action:Command_SetName(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (args < 1) {
		Build_PrintToChat(Client, "Usage: !setname <name you want it to be>");
		Build_PrintToChat(Client, "Ex: !setname \"A teddy bear\"");
		Build_PrintToChat(Client, "Ex: !setname \"Gabe Newell\"");
		return Plugin_Handled;
	}
	
	new iEntity = Build_ClientAimEntity(Client);
	if (iEntity == -1) 
		return Plugin_Handled;
	
	if (Build_IsEntityOwner(Client, iEntity)) {
		new String:newpropname[256];
		GetCmdArg(args, newpropname, sizeof(newpropname));
		SetEntPropString(iEntity, Prop_Data, "m_iName", newpropname);
	}
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_setname", szArgs);
	return Plugin_Handled;	
}

public Action:Command_SpawnProp(Client, args) {
	if (!Build_AllowToUse(Client) || Build_IsBlacklisted(Client) || !Build_IsClientValid(Client, Client, true))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(Client))
	{
		Build_PrintToChat(Client, "You must be alive to use this command!");

		return Plugin_Handled;
	}
	
	if (args < 1) {
		if (g_bClientLang[Client]) {
			Build_PrintToChat(Client, "用法: !spawnprop/!prop <物件名稱> ");
			Build_PrintToChat(Client, "例: !spawnprop goldbar");
			Build_PrintToChat(Client, "例: !spawnprop alyx");
		} else {
			Build_PrintToChat(Client, "Usage: !spawnprop/!s <Prop name>");
			Build_PrintToChat(Client, "Ex: !spawnprop goldbar");
			Build_PrintToChat(Client, "Ex: !spawnprop alyx");
		}
		return Plugin_Handled;
	}
	
	new String:szPropName[32], String:szPropFrozen[32], String:szPropString[256], String:szModelPath[128];
	GetCmdArg(1, szPropName, sizeof(szPropName));
	GetCmdArg(2, szPropFrozen, sizeof(szPropFrozen));
	
	new IndexInArray = FindStringInArray(g_hPropNameArray, szPropName);
	
	if (StrEqual(szPropName, "explosivecan") && !Build_IsAdmin(Client, true)) {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "你需要 \x04二級建造權限\x01 才能叫出此物件!");
		else
			Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to spawn this prop!");
		return Plugin_Handled;
	}
	
	if (g_bBuffer[Client])
	{
		Build_PrintToChat(Client, "Anti Spam Protection, please wait.");

		return Plugin_Handled;
	}

	g_bBuffer[Client] = true;
	CreateTimer(0.5, Timer_CoolDown, GetClientSerial(Client));
	
	if (IndexInArray != -1) {
		new bool:bIsDoll = false;
		new String:szEntType[33];
		GetArrayString(g_hPropTypeArray, IndexInArray, szEntType, sizeof(szEntType));
		
		if (!Build_IsAdmin(Client, true)) {
			if (StrEqual(szPropName, "explosivecan") || StrEqual(szEntType, "prop_ragdoll")) {
				if (g_bClientLang[Client])
					Build_PrintToChat(Client, "你需要 \x04二級建造權限\x01 才能叫出此物件!");
				else
					Build_PrintToChat(Client, "You need \x04L2 Build Access\x01 to spawn this prop!");
				return Plugin_Handled;
			}
		}
		if (StrEqual(szEntType, "prop_ragdoll"))
			bIsDoll = true;
		
		new iEntity = CreateEntityByName(szEntType);

		if (Build_RegisterEntityOwner(iEntity, Client, bIsDoll)) {
			new Float:fOriginWatching[3], Float:fOriginFront[3], Float:fAngles[3], Float:fRadiansX, Float:fRadiansY;
			
			decl Float:iAim[3];
			new Float:vOriginPlayer[3];
			
			GetClientEyePosition(Client, fOriginWatching);
			GetClientEyeAngles(Client, fAngles);
			
			fRadiansX = DegToRad(fAngles[0]);
			fRadiansY = DegToRad(fAngles[1]);
			
			fOriginFront[0] = fOriginWatching[0] + (100 * Cosine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[1] = fOriginWatching[1] + (100 * Sine(fRadiansY) * Cosine(fRadiansX));
			fOriginFront[2] = fOriginWatching[2] - 20;
			
			GetArrayString(g_hPropModelPathArray, IndexInArray, szModelPath, sizeof(szModelPath));
			
			
			GetArrayString(g_hPropStringArray, IndexInArray, szPropString, sizeof(szPropString));
			
			if (!IsModelPrecached(szModelPath))
				PrecacheModel(szModelPath);
			
			DispatchKeyValue(iEntity, "model", szModelPath);
			
			//DispatchKeyValue(iEntity, "propnametf2sb", szPropString);
			SetEntPropString(iEntity, Prop_Data, "m_iName", szPropString);
			
			if (StrEqual(szEntType, "prop_dynamic"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			if (StrEqual(szEntType, "prop_dynamic_override"))
				SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
			
			Build_ClientAimOrigin(Client, iAim);
			iAim[2] = iAim[2] + 10;
			
			GetClientAbsOrigin(Client, vOriginPlayer);
			vOriginPlayer[2] = vOriginPlayer[2] + 50;
			
			
			DispatchSpawn(iEntity);
			TeleportEntity(iEntity, iAim, NULL_VECTOR, NULL_VECTOR);
			
			
			
			TE_SetupBeamPoints(iAim, vOriginPlayer, g_PBeam, g_Halo, 0, 66, 1.0, 3.0, 3.0, 0, 0.0, ColorBlue, 20);
			TE_SendToAll();
			
			new random = GetRandomInt(0,1);
			if (random == 1) {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			} else {
				EmitAmbientSound("buttons/button3.wav", iAim, iEntity, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
				EmitAmbientSound("buttons/button3.wav", vOriginPlayer, Client, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
			}
			
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 0);
			
			// Debugging issues
			//PrintToChatAll(szPropString);
			
			new PlayerSpawnCheck;
			
			
			while((PlayerSpawnCheck = FindEntityByClassname(PlayerSpawnCheck, "info_player_teamspawn")) != INVALID_ENT_REFERENCE)
			{
				if(Entity_InRange(iEntity,PlayerSpawnCheck,400.0))
				{
					Build_PrintToChat(Client, "You're too near the spawn!");
					Build_SetLimit(Client, -1);
					AcceptEntityInput(iEntity, "kill");
					
				}
			}
			
			
			if (!StrEqual(szPropFrozen, "")) {
				if (Phys_IsPhysicsObject(iEntity))
					Phys_EnableMotion(iEntity, false);
			}
		} else
			RemoveEdict(iEntity);
	} else {
		if (g_bClientLang[Client])
			Build_PrintToChat(Client, "該物件不存在: %s", szPropName);
		else
			Build_PrintToChat(Client, "Prop not found: %s", szPropName);
	}
	new String:szTemp[33], String:szArgs[128];
	for (new i = 1; i <= GetCmdArgs(); i++) {
		GetCmdArg(i, szTemp, sizeof(szTemp));
		Format(szArgs, sizeof(szArgs), "%s %s", szArgs, szTemp);
	}
	Build_Logging(Client, "sm_spawnprop", szArgs);
	return Plugin_Handled;
}

ReadProps() {
	BuildPath(Path_SM, g_szFile, sizeof(g_szFile), "configs/buildmod/props.ini");
	
	new Handle:iFile = OpenFile(g_szFile, "rt");
	if (iFile == INVALID_HANDLE)
		return;
	
	new iCountProps = 0;
	while (!IsEndOfFile(iFile))
	{
		decl String:szLine[255];
		if (!ReadFileLine(iFile, szLine, sizeof(szLine)))
			break;
		
		/* 略過註解 */
		new iLen = strlen(szLine);
		new bool:bIgnore = false;
		
		for (new i = 0; i < iLen; i++) {
			if (bIgnore) {
				if (szLine[i] == '"')
					bIgnore = false;
			} else {
				if (szLine[i] == '"')
					bIgnore = true;
				else if (szLine[i] == ';') {
					szLine[i] = '\0';
					break;
				} else if (szLine[i] == '/' && i != iLen - 1 && szLine[i+1] == '/') {
					szLine[i] = '\0';
					break;
				}
			}
		}
		
		TrimString(szLine);
		
		if ((szLine[0] == '/' && szLine[1] == '/') || (szLine[0] == ';' || szLine[0] == '\0'))
			continue;
	
		ReadPropsLine(szLine, iCountProps++);
	}
	CloseHandle(iFile);
}

ReadPropsLine(const String:szLine[], iCountProps) {
	decl String:szPropInfo[4][128];
	ExplodeString(szLine, ", ", szPropInfo, sizeof(szPropInfo), sizeof(szPropInfo[]));
	
	StripQuotes(szPropInfo[0]);
	SetArrayString(g_hPropNameArray, iCountProps, szPropInfo[0]);
	
	StripQuotes(szPropInfo[1]);
	SetArrayString(g_hPropModelPathArray, iCountProps, szPropInfo[1]);
	
	StripQuotes(szPropInfo[2]);
	SetArrayString(g_hPropTypeArray, iCountProps, szPropInfo[2]);
	
	StripQuotes(szPropInfo[3]);
	SetArrayString(g_hPropStringArray, iCountProps, szPropInfo[3]);
}



public Action:Timer_CoolDown(Handle:hTimer, any:iBuffer)
{
	new iClient = GetClientFromSerial(iBuffer);

	if (g_bBuffer[iClient]) g_bBuffer[iClient] = false;
}