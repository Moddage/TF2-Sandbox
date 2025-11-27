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

#pragma semicolon 1;

#include <clientprefs>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>
#include <build_stocks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <vphysics>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#tryinclude <tf2idb>
#tryinclude <tf2items_giveweapon>
#tryinclude <rtd2>
#define REQUIRE_PLUGIN
#tryinclude <advancedinfiniteammo>

#define UPDATE_URL ""

#if BUILDMODAPI_VER < 3
#error "build.inc is outdated. please update before compiling"
#endif

#pragma newdecls required

#include "tf2sb/core/protocols.sp"
#include "tf2sb/core/main.sp"

public Plugin myinfo = 
{
	name = "Team Fortress 2 Sandbox", 
	author = "TF2SB Studio, Maintained by Yuuki", 
	description = "The base gamemode plugin of Team Fortress 2 Sandbox. Includes all base Sandbox modules in one plugin.", 
	version = BUILDMOD_VER, 
	url = "https://sandbox.moddage.site/"
};

// TODO: Use arrays instead, idiot!

public void OnPluginStart() 
{
	OnPluginStart_Protocols();
	OnPluginStart_Main();
}

public void OnLibraryAdded(const char[] name)
{
	OnLibraryAdded_Protocols(name);
	OnLibraryAdded_Main(name);
}


public void OnMapStart() 
{
	OnMapStart_Protocols();
	OnMapStart_Main();
}

public void OnClientPutInServer(int client)
{
    OnClientPutInServer_Protocols(client);
	OnClientPutInServer_Main(client);
}
