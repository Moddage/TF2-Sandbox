#define Unicode_stocks "測試"
bool g_bFirstRun = true;

stock void Build_GetSteamID() 
{
	if (g_bFirstRun) 
	{
		int g_iObj_Dfilter = FindEntityByClassname(0, "cat_First_Run");
		if (g_iObj_Dfilter == -1) 
		{
			g_iObj_Dfilter = CreateEntityByName("info_target");
			DispatchKeyValue(g_iObj_Dfilter, "classname", "cat_First_Run");
			DispatchSpawn(g_iObj_Dfilter);
			g_bFirstRun = true;
		} 
		else
			g_bFirstRun = false;
	}
}

stock void Build_FirstRun() 
{
	if (g_bFirstRun) 
	{
		int g_iObj_Dfilter = FindEntityByClassname(0, "cat_First_Run");
		if (g_iObj_Dfilter == -1) 
		{
			g_iObj_Dfilter = CreateEntityByName("info_target");
			DispatchKeyValue(g_iObj_Dfilter, "classname", "cat_First_Run");
			DispatchSpawn(g_iObj_Dfilter);
			g_bFirstRun = true;
		} 
		else
			g_bFirstRun = false;
	}
}

stock void Build_ClientAimOrigin(int Client, float pos[3]) 
{
	float vOrigin[3], vAngles[3];
	
	GetClientEyePosition(Client, vOrigin);
	GetClientEyeAngles(Client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients;
}

stock Build_IsInRange(float vEntityOrigin[3], float vPoint[3], float fRange) {
	if ((vPoint[0] + fRange) > vEntityOrigin[0] > (vPoint[0] - fRange) &&
		(vPoint[1] + fRange) > vEntityOrigin[1] > (vPoint[1] - fRange) &&
		(vPoint[2] + fRange) > vEntityOrigin[2] > (vPoint[2] - fRange))
		return true;
	else
		return false;
}

stock Build_IsInSquare(float vEntityOrigin[3], float vPoint1[3], float vPoint2[3]) {
	if ((vPoint1[0] > vEntityOrigin[0] > vPoint2[0] || vPoint2[0] > vEntityOrigin[0] > vPoint1[0]) &&
		(vPoint1[1] > vEntityOrigin[1] > vPoint2[1] || vPoint2[1] > vEntityOrigin[1] > vPoint1[1]) &&
		(vPoint1[2] > vEntityOrigin[2] > vPoint2[2] || vPoint2[2] > vEntityOrigin[2] > vPoint1[2]))
		return true;
	else
		return false;
}