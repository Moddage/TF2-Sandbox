#if defined _GravityGunCvar_included
#endinput
#endif
#define _GravityGunCvar_included

new Handle:cvar_maxdragdistance = INVALID_HANDLE;
new Handle:cvar_maxpickupdistance = INVALID_HANDLE;
new Handle:cvar_maxpulldistance = INVALID_HANDLE;

new Handle:cvar_dragforce = INVALID_HANDLE;
new Handle:cvar_pullforce = INVALID_HANDLE;
new Handle:cvar_grabforcemultiply = INVALID_HANDLE;

new Handle:cvar_pull_delay = INVALID_HANDLE;
new Handle:cvar_grab_delay = INVALID_HANDLE;

new Handle:cvar_grab_maxdistance = INVALID_HANDLE;
new Handle:cvar_grab_mindistance = INVALID_HANDLE;
new Handle:cvar_grab_defaultdistance = INVALID_HANDLE;

new Handle:cvar_strictmousecontrol = INVALID_HANDLE;
new Handle:cvar_disablemousecontrol = INVALID_HANDLE;

new Handle:g_cvarEnableMotionControl = INVALID_HANDLE;

new Handle:cvar_enablesound = INVALID_HANDLE;

new Handle:cvar_blueteam_enable = INVALID_HANDLE;
new Handle:cvar_redteam_enable = INVALID_HANDLE;
new Handle:cvar_unassignedteam_enable = INVALID_HANDLE;

new Handle:g_cvarWeaponEnableGrab = INVALID_HANDLE;

new Handle:g_cvarWeaponSwitchRule = INVALID_HANDLE;

creategravityguncvar(){

	//콘바 생성
	CreateConVar("physgun_version", BUILDMOD_VER, "plugin info cvar", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	cvar_maxdragdistance = CreateConVar("physgun_maxdragdistance", "600", "max distance to allow drag");
	cvar_maxpickupdistance = CreateConVar("physgun_maxpickupdistance", "200", "max distance to allow grab");
	cvar_maxpulldistance = CreateConVar("physgun_maxpulldistance", "200", "max distance to allow pull");
	
	cvar_dragforce = CreateConVar("physgun_dragforce", "400", "drag force");
	cvar_pullforce = CreateConVar("physgun_pullforce", "1600", "pull force");
	cvar_grabforcemultiply = CreateConVar("physgun_grabforcemultiply", "10", "multiply grab force by this value");
	
	cvar_pull_delay = CreateConVar("physgun_pull_delay", "0.5", "pull delay");
	cvar_grab_delay = CreateConVar("physgun_grab_delay", "0.2", "grab delay");
	
	cvar_grab_maxdistance = CreateConVar("physgun_grab_maxdistance", "1000.0", "grab distance max limit");
	cvar_grab_mindistance = CreateConVar("physgun_grab_mindistance", "100.0", "grab distance min limit");
	cvar_grab_defaultdistance = CreateConVar("physgun_grab_defaultdistance", "100.0", "grab distance for default");
	
	cvar_strictmousecontrol = CreateConVar("physgun_strictmousecontrol", "0", "force players to hold speed button to use mouse button for gravity gun function");
	cvar_disablemousecontrol = CreateConVar("physgun_disablemousecontrol", "0", "disable grab/pull by mouse button");
	
	g_cvarEnableMotionControl = CreateConVar("physgun_enablemotioncontrol", "1", "enable motion disale/enable to held object");
	
	cvar_enablesound = CreateConVar("physgun_enablesound", "1", "1 for enable 0 for disable");

	cvar_blueteam_enable = CreateConVar("physgun_blueteam_enable", "1", "1 for enable 0 for disable");
	cvar_redteam_enable = CreateConVar("physgun_redteam_enable", "1", "1 for enable 0 for disable");
	cvar_unassignedteam_enable = CreateConVar("physgun_unassignedteam_enable", "1", "1 for enable 0 for disable");
	
	g_cvarWeaponEnableGrab = CreateConVar("physgun_WeaponEnableGrab", "tf_weapon_builder", "list of weapon that allow grab, empty means all weapon can grab");
	
	g_cvarWeaponSwitchRule = CreateConVar("physgun_WeaponSwitchRule", "2", "0 = doesnt allow weapon switch when u holding some prop, \n1 = u can change weapon but held prop will auto released, \n2 = u can change weapon and u can keep hold yo prop if changed weapon also has gravitygun function.");
	
	AutoExecConfig();
	
}

stock bool:strictmousecontrol(){

	return GetConVarBool(cvar_strictmousecontrol);

}

stock bool:teamcanusegravitygun(teamnum){
	
	if((teamnum == 3) && GetConVarBool(cvar_blueteam_enable)){
	
		return true;
	
	}else if((teamnum == 2) && GetConVarBool(cvar_redteam_enable)){
	
		return true;
		
	}else  if((teamnum == 0) && GetConVarBool(cvar_unassignedteam_enable)){
	
		return true;
	
	}
	
	return false;

}

stock bool:soundenabled(){

	return GetConVarBool(cvar_enablesound);

}

stock bool:isWeaponGrabber(entity){
	
	if(entity != -1){
	
		decl String:weaponname[64];
		GetEdictClassname(entity, weaponname, sizeof(weaponname));
		
		decl String:cvarstring[256];
		
		GetConVarString(g_cvarWeaponEnableGrab, cvarstring, 256);
		if((StrContains(cvarstring, weaponname, false) != -1) || StrEqual(cvarstring, "", false)){
			
			return true;
			
		}
		
	}
	
	return false;
	
}