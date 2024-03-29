#define Unicode_stocks "測試"
#include <sdktools>
new bool:g_bFirstRun = true;

public bool:TraceRayDontHitPlayers(entity, mask, any:data)
{
	if(0 < entity <= MaxClients)
		return false;
	return true;
}

//^
//This really should break it but it makes it work and i have no fucking idea why
stock Build_GetSteamID() {
	if (g_bFirstRun) {
		new g_Obj_Dfilter = FindEntityByClassname(0, "cat_First_Run");
		if (g_Obj_Dfilter == -1) {
			g_Obj_Dfilter = CreateEntityByName("info_target");
			DispatchKeyValue(g_Obj_Dfilter, "classname", "cat_First_Run");
			DispatchSpawn(g_Obj_Dfilter);
			g_bFirstRun = true;
		} else
			g_bFirstRun = false;
	}
}

stock Build_FirstRun() {
	if (g_bFirstRun) {
		new g_Obj_Dfilter = FindEntityByClassname(0, "cat_First_Run");
		if (g_Obj_Dfilter == -1) {
			g_Obj_Dfilter = CreateEntityByName("info_target");
			DispatchKeyValue(g_Obj_Dfilter, "classname", "cat_First_Run");
			DispatchSpawn(g_Obj_Dfilter);
			g_bFirstRun = true;
		} else
			g_bFirstRun = false;
	}
}

stock Build_ClientAimOrigin(Client, Float:pos[3]) {
	new Float:vOrigin[3], Float:vAngles[3];
	
	GetClientEyePosition(Client, vOrigin);
	GetClientEyeAngles(Client, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

public bool:TraceEntityFilterPlayer(entity, contentsMask) {
	return entity > MaxClients;
}

stock Build_IsInRange(Float:vEntityOrigin[3], Float:vPoint[3], Float:fRange) {
	if ((vPoint[0] + fRange) > vEntityOrigin[0] > (vPoint[0] - fRange) &&
		(vPoint[1] + fRange) > vEntityOrigin[1] > (vPoint[1] - fRange) &&
		(vPoint[2] + fRange) > vEntityOrigin[2] > (vPoint[2] - fRange))
		return true;
	else
		return false;
}

stock Build_IsInSquare(Float:vEntityOrigin[3], Float:vPoint1[3], Float:vPoint2[3]) {
	if ((vPoint1[0] > vEntityOrigin[0] > vPoint2[0] || vPoint2[0] > vEntityOrigin[0] > vPoint1[0]) &&
		(vPoint1[1] > vEntityOrigin[1] > vPoint2[1] || vPoint2[1] > vEntityOrigin[1] > vPoint1[1]) &&
		(vPoint1[2] > vEntityOrigin[2] > vPoint2[2] || vPoint2[2] > vEntityOrigin[2] > vPoint1[2]))
		return true;
	else
		return false;
}

stock bool IsBuildable(int client) //Is the place that client pointing is build-able?
{
	float flSightEnd[3];
	GetClientSightEnd(client, flSightEnd); //get client pointed place
	
	for(int i = 1; i < MAXPLAYERS; i++) //loop every client
	{
		if(IsValidClient(i))
		{
			float flOrigin[3];
			GetClientEyePosition(i, flOrigin);
			
			int iDistance = RoundFloat(GetVectorDistance(flOrigin, flSightEnd)); //get distance between clients and the client pointed place
			if(iDistance > 400)
			{
				return false;
			}
		}
	}
	return true;
}

stock GetClientSightEnd(client, Float:out[3])
{
	decl Float:m_fEyes[3];
	decl Float:m_fAngles[3];
	GetClientEyePosition(client, m_fEyes);
	GetClientEyeAngles(client, m_fAngles);
	TR_TraceRayFilter(m_fEyes, m_fAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);
	if(TR_DidHit())
		TR_GetEndPosition(out);
}


stock bool IsValidClient(int client) 
{ 
    if(client <= 0 ) return false; 
    if(client > MaxClients) return false; 
    if(!IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}

