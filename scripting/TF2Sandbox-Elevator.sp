#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Elevator v2",
	author = PLUGIN_AUTHOR,
	description = "A better elevator on TF2Sandbox, support multi floor and button controls.",
	version = PLUGIN_VERSION,
	url = "https://github.com/TF2-Sandbox-Studio/Module-Elevator"
};

#define ELEVATOR_SPEED 5.0
#define ELEVATOR_IDLE 5.0

#define SOUND_ELEVATOR_BELL "plats/elevbell1.wav"

#define SOUND_ELEVATOR_DOOR_CLOSE "doors/door_metal_thin_close2.wav"
#define SOUND_ELEVATOR_DOOR_OPEN "doors/door_metal_thin_open1.wav"
#define SOUND_ELEVATOR_DOOR_MOVE "doors/door_metal_thin_move1.wav"

#define SOUND_ELEVATOR_BUTTON_PRESS "buttons/lever7.wav"

#define SOUND_ELEVATOR_START "plats/elevator_start1.wav"
#define SOUND_ELEVATOR_STOP "plats/elevator_stop.wav"
#define SOUND_ELEVATOR_MOVE_LOOP "plats/elevator_move_loop1.wav"

#define MODEL_ELEVATOR_GROUND "models/props_trainyard/crane_platform001.mdl"
#define MODEL_ELEVATOR_BODY "models/props_lab/freightelevator.mdl"
#define MODEL_ELEVATOR_BUTTON "models/props_lab/freightelevatorbutton.mdl"
#define MODEL_ELEVATOR_DOOR "models/props_lab/elevatordoor.mdl"

#define MODEL_LIGHT_UP "materials/sprites/redglow2.vmt"
#define MODEL_LIGHT_DOWN "materials/sprites/greenglow1.vmt"
#define MODEL_LASER "materials/sprites/laserbeam.vmt"

int g_LightUp, g_LightDown, g_Laser;

bool g_bIsDebug[MAXPLAYERS + 1];
bool g_bIN_SCORE[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_elevator_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	RegAdminCmd("sm_lift", Command_CreateElevator, 0, "Spawn a elevator");
	RegAdminCmd("sm_elevator", Command_CreateElevator, 0, "Spawn a elevator");
	RegAdminCmd("sm_liftb", Command_CreateElevatorButton, 0, "Spawn a elevator button");
	RegAdminCmd("sm_elevatorb", Command_CreateElevatorButton, 0, "Spawn a elevator button");
	RegAdminCmd("sm_liftdebug", Command_ElevatorDebug, 0, "Enable/Disable Debug");
	RegAdminCmd("sm_elevatordebug", Command_ElevatorDebug, 0, "Enable/Disable Debug");
}

public void OnClientPutInServer(int client)
{
	g_bIsDebug[client] = false;
	g_bIN_SCORE[client] = false;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_ELEVATOR_BELL);
	
	PrecacheSound(SOUND_ELEVATOR_DOOR_CLOSE);
	PrecacheSound(SOUND_ELEVATOR_DOOR_OPEN);
	PrecacheSound(SOUND_ELEVATOR_DOOR_MOVE);
	
	PrecacheSound(SOUND_ELEVATOR_BUTTON_PRESS);
	
	PrecacheSound(SOUND_ELEVATOR_START);
	PrecacheSound(SOUND_ELEVATOR_STOP);
	PrecacheSound(SOUND_ELEVATOR_MOVE_LOOP);
	
	PrecacheModel(MODEL_ELEVATOR_GROUND);
	PrecacheModel(MODEL_ELEVATOR_BODY);
	PrecacheModel(MODEL_ELEVATOR_BUTTON);
	PrecacheModel(MODEL_ELEVATOR_DOOR);
	
	g_LightUp = PrecacheModel(MODEL_LIGHT_UP);
	g_LightDown = PrecacheModel(MODEL_LIGHT_DOWN);
	g_Laser = PrecacheModel(MODEL_LASER);
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1)
	{
		if (IsElevatorButton(i))
		{
			CreateTimer(0.1, Timer_ButtonLightBySkin, EntIndexToEntRef(i), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "prop_dynamic") != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

public void OnEntitySpawned(int entity)
{
	if (IsElevatorButton(entity))
	{
		CreateTimer(0.1, Timer_ButtonLightBySkin, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (IsElevator(entity))
	{
		DataPack pack;
		CreateDataTimer(0.01, Timer_ElevatorControl, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(EntIndexToEntRef(entity));
		pack.WriteCell(-1);
		pack.WriteCell(3);
		pack.WriteCell(true);
		pack.WriteCell(false);
	}
	else
	{
		char strModelName[64];
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));

		if (StrEqual(strModelName, MODEL_ELEVATOR_GROUND))
		{
			RequestFrame(OnElevatorSpawnPost, EntIndexToEntRef(entity));
		}
	}
}

void OnElevatorSpawnPost(int elevatorRef)
{
	RequestFrame(OnElevatorSpawnPostPost, elevatorRef);
}

void OnElevatorSpawnPostPost(int elevatorRef)
{
	int elevator = EntRefToEntIndex(elevatorRef);
	if (elevator == -1) { return; }
	
	if (FloatAbs(GetEntPropFloat(elevator, Prop_Send, "m_flModelScale") - 0.435314) > 0.00001) { return; }
	if (GetEntProp(elevator, Prop_Send, "m_nSolidType") == 6)
	{
		float pos[3], angles[3];
		GetEntPropVector(elevator, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(elevator, Prop_Data, "m_angRotation", angles);
		int client = Build_ReturnEntityOwner(elevator);
		AcceptEntityInput(elevator, "Kill");
		Build_SetLimit(client, -1);
		CreateElevator(client, pos, angles);
	}
}

#define BUTTON_NULL 0
#define BUTTON_UP 1
#define BUTTON_DOWN 2
#define BUTTON_UPANDDOWN 3
#define BUTTON_CANCEL 4
public Action Timer_ButtonLightBySkin(Handle timer, int buttonRef)
{
	int button = EntRefToEntIndex(buttonRef);
	if (button == -1) { return Plugin_Handled; }

	float buttonVecOrigin[3], upPos[3], downPos[3];
	GetEntPropVector(button, Prop_Send, "m_vecOrigin", buttonVecOrigin);
	upPos = buttonVecOrigin;
	upPos[2] += 13.5;
	downPos = buttonVecOrigin;
	downPos[2] += 9.5;

	int presses = GetEntProp(button, Prop_Send, "m_nSkin");
	if (presses == BUTTON_UPANDDOWN || presses == BUTTON_UP)
	{
		TE_SetupGlowSprite(upPos, g_LightUp, 0.3, 0.1, 100);
		TE_SendToAll();
	}
	
	if (presses == BUTTON_UPANDDOWN || presses == BUTTON_DOWN)
	{
		TE_SetupGlowSprite(downPos, g_LightDown, 0.3, 0.1, 100);
		TE_SendToAll();
	}
	
	if (presses >= 4)
	{
		EmitSoundToAll(SOUND_ELEVATOR_BELL, button, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		SetEntProp(button, Prop_Send, "m_nSkin", BUTTON_NULL);
	}
	
	return Plugin_Continue;
}

#define ELEVATOR_DOOR_CLOSED 0
#define ELEVATOR_DOOR_OPEN_START 1
#define ELEVATOR_DOOR_CLOSE_START 2
#define ELEVATOR_DOOR_OPENED 3
#define ELEVATOR_DOOR_OPEN_START_WITH_BELL 4
#define ELEVATOR_DOOR_CLOSE_WITH_DELAY 16
public Action Timer_ElevatorActionBySkin(Handle timer, DataPack pack)
{
	pack.Reset();
	int ground = EntRefToEntIndex(pack.ReadCell());
	int body = EntRefToEntIndex(pack.ReadCell());
	int button = EntRefToEntIndex(pack.ReadCell());
	int door = EntRefToEntIndex(pack.ReadCell());
	
	if (ground == -1 || body == -1 || button == -1 || door == -1)
	{
		AcceptEntityInputSafe(ground, "Kill");
		AcceptEntityInputSafe(body, "Kill");
		AcceptEntityInputSafe(button, "Kill");
		AcceptEntityInputSafe(door, "Kill");
		
		return Plugin_Handled;
	}
	
	int doorState = GetEntProp(ground, Prop_Send, "m_nSkin");
	
	if (doorState == ELEVATOR_DOOR_OPEN_START)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPENED);
		SetVariantString("open");
		AcceptEntityInput(door, "SetAnimation");
		EmitSoundToAll(SOUND_ELEVATOR_DOOR_OPEN, door, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
	else if (doorState == ELEVATOR_DOOR_CLOSE_START)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_CLOSED);
		SetVariantString("close");
		AcceptEntityInput(door, "SetAnimation");
		EmitSoundToAll(SOUND_ELEVATOR_DOOR_CLOSE, door, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
	else if (doorState == ELEVATOR_DOOR_OPEN_START_WITH_BELL)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", 15);
		EmitSoundToAll(SOUND_ELEVATOR_BELL, button, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
	else if (16 > doorState && doorState > 4)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", (doorState == 5) ? ELEVATOR_DOOR_OPEN_START : --doorState);
	}
	else if (doorState == ELEVATOR_DOOR_CLOSE_WITH_DELAY)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", 25);
		SetVariantString("close");
		AcceptEntityInput(door, "SetAnimation");
		EmitSoundToAll(SOUND_ELEVATOR_DOOR_CLOSE, door, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
	else if (26 > doorState && doorState > 16)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", (doorState == 17) ? ELEVATOR_DOOR_CLOSED : --doorState);
	}
	
	return Plugin_Continue;
}

#define ELEVATOR_ANY 0
#define ELEVATOR_UP 1
#define ELEVATOR_DOWN 2
public Action Timer_ElevatorControl(Handle timer, DataPack pack)
{
	DataPack pack2;
	
	pack.Reset();
	int ground = EntRefToEntIndex(pack.ReadCell());
	int currentButtonRef = pack.ReadCell();
	int currentButton = (currentButtonRef == -1) ? -1 : EntRefToEntIndex(currentButtonRef);
	int direction = pack.ReadCell();
	bool isIdle = pack.ReadCell();
	bool playStartSound = pack.ReadCell();

	if (ground == -1) { return Plugin_Handled; }
	int client = Build_ReturnEntityOwner(ground);
	
	float groundVecOrigin[3];
	GetEntPropVector(ground, Prop_Send, "m_vecOrigin", groundVecOrigin);
	
	int color[4] = { 255, 255, 255, 255 };
	int red[4] = { 255, 0, 0, 255 };
	int green[4] = { 0, 255, 0, 255 };
	
	int nextButton = GetElevatorNextButton(ground, direction);

	// Debug: Verticle Line
	if (client > 0 && client <= MaxClients && g_bIsDebug[client])
	{
		if (nextButton != -1)
		{
			float buttonVecOrigin[3];
			GetEntPropVector(nextButton, Prop_Send, "m_vecOrigin", buttonVecOrigin);
			TE_SetupBeamPoints(groundVecOrigin, buttonVecOrigin, g_Laser, g_Laser, 0, 1, 0.1, 1.0, 1.0, 0, 0.0, red, 1);
			TE_SendToAll();
		}
		
		float topPointPos[3], bottomPointPos[3];
		topPointPos = groundVecOrigin;
		topPointPos[2] += 1000.0;
		bottomPointPos = groundVecOrigin;
		bottomPointPos[2] -= 1000.0;
		TE_SetupBeamPoints(topPointPos, bottomPointPos, g_Laser, g_Laser, 0, 1, 0.5, 1.0, 1.0, 0, 0.0, (direction == ELEVATOR_UP) ? red : green, 1);
		TE_SendToAll();
	}

	int datas[3];
	datas = GetElevatorCurrentAndTotalFloor(ground);
	if (datas[1] == 0)
	{
		CreateDataTimer(0.001, Timer_ElevatorControl, pack2, TIMER_FLAG_NO_MAPCHANGE);
		pack2.WriteCell(EntIndexToEntRef(ground));
		pack2.WriteCell((currentButton == -1) ? -1 : EntIndexToEntRef(currentButton));
		pack2.WriteCell(direction);
		pack2.WriteCell(isIdle);
		pack2.WriteCell(playStartSound);
		
		return Plugin_Continue;
	}

	float longestDistance = -1.0, temp;
	int pressedButton = -1;
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1)
	{
		if (IsElevatorButton(i) && IsElevatorButtonValidInRange(ground, i))
		{
			if (Build_ReturnEntityOwner(i) != Build_ReturnEntityOwner(ground)) { continue; }
			
			int targetFloor = GetEntProp(ground, Prop_Send, "m_nSequence");
			if (isIdle && targetFloor == 0)
			{
				int presses = GetEntProp(i, Prop_Send, "m_nSkin");
				if (0 < presses && presses < 4)
				{
					float tempPos[3];
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", tempPos);
					tempPos[0] = groundVecOrigin[0];
					tempPos[1] = groundVecOrigin[1];
					
					temp = GetVectorDistance(groundVecOrigin, tempPos);
					if (longestDistance == -1.0 || temp > longestDistance)
					{
						longestDistance = temp;
						pressedButton = i;
					}		
				}
			}
			
			if (client > 0 && client <= MaxClients && g_bIsDebug[client])
			{
				if (nextButton != i)
				{
					float buttonVecOrigin[3];
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", buttonVecOrigin);
					TE_SetupBeamPoints(groundVecOrigin, buttonVecOrigin, g_Laser, g_Laser, 0, 1, 0.1, 1.0, 1.0, 0, 0.0, color, 1);
					TE_SendToAll();
				}
			}
		}
	}
	
	if (pressedButton != -1)
	{
		int floor = GetEntProp(pressedButton, Prop_Data, "m_iHealth");
		SetEntProp(ground, Prop_Send, "m_nSequence", floor);
	}
	
	// Try to get next button if current button is -1
	if (currentButton == -1) { currentButton = GetElevatorNextButton(ground, direction); }
	
	// If the door close, do actions
	if (GetEntProp(ground, Prop_Send, "m_nSkin") == ELEVATOR_DOOR_CLOSED)
	{
		// If the elevator reach another button or -1
		if (currentButton != nextButton || currentButton == -1)
		{
			// If the nextButton is -1, change the direction
			if (nextButton == -1)
			{
				if (GetEntProp(ground, Prop_Send, "m_nSkin") == ELEVATOR_DOOR_CLOSED)
				{
					SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPEN_START_WITH_BELL);
					if (currentButton != -1) { SetEntProp(currentButton, Prop_Send, "m_nSkin", BUTTON_NULL); }
				}
				
				direction = (direction == ELEVATOR_UP) ? ELEVATOR_DOWN : ELEVATOR_UP;
				
				//nextButton = GetElevatorNextButton(ground, direction);
				//if (nextButton != -1)
				{
					//float nextButtonPos[3];
					//GetEntPropVector(nextButton, Prop_Send, "m_vecOrigin", nextButtonPos);
					//nextButtonPos[0] = groundVecOrigin[0];
					//nextButtonPos[1] = groundVecOrigin[1];
					//nextButtonPos[2] -= 44.0 + ((direction == ELEVATOR_UP) ? -ELEVATOR_SPEED : ELEVATOR_SPEED);
					//DispatchKeyValueVectorSafe(ground, "origin", nextButtonPos);
				}
				
				groundVecOrigin[2] += (direction == ELEVATOR_UP) ? ELEVATOR_SPEED : ELEVATOR_SPEED*-1.0;
				DispatchKeyValueVectorSafe(ground, "origin", groundVecOrigin);
			}
			
			// Stop the elavater and cancel the button light
			if (currentButton != nextButton)
			{
				if (datas[0] == GetEntProp(ground, Prop_Send, "m_nSequence"))
				{
					SetEntProp(ground, Prop_Send, "m_nSequence", 0);
					SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPEN_START_WITH_BELL);
					StopSound(ground, SNDCHAN_AUTO, SOUND_ELEVATOR_MOVE_LOOP);
					EmitSoundToAll(SOUND_ELEVATOR_STOP, ground, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					isIdle = true;
				}
				
				int presses = GetEntProp(currentButton, Prop_Send, "m_nSkin");
				if ((presses == BUTTON_UP || presses == BUTTON_UPANDDOWN) && direction == ELEVATOR_UP)
				{
					SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPEN_START_WITH_BELL);
					SetEntProp(currentButton, Prop_Send, "m_nSkin", (presses == BUTTON_UPANDDOWN) ? BUTTON_DOWN : BUTTON_NULL);
					StopSound(ground, SNDCHAN_AUTO, SOUND_ELEVATOR_MOVE_LOOP);
					EmitSoundToAll(SOUND_ELEVATOR_STOP, ground, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);	
					isIdle = true;					
				}
				else if ((presses == BUTTON_DOWN || presses == BUTTON_UPANDDOWN) && direction == ELEVATOR_DOWN)
				{
					SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPEN_START_WITH_BELL);
					SetEntProp(currentButton, Prop_Send, "m_nSkin", (presses == BUTTON_UPANDDOWN) ? BUTTON_UP : BUTTON_NULL);
					StopSound(ground, SNDCHAN_AUTO, SOUND_ELEVATOR_MOVE_LOOP);
					EmitSoundToAll(SOUND_ELEVATOR_STOP, ground, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					isIdle = true;
				}
			}
			
			currentButton = nextButton;
			
			if (GetEntProp(ground, Prop_Send, "m_nSkin") == ELEVATOR_DOOR_OPEN_START_WITH_BELL)
			{
				CreateTimer(ELEVATOR_IDLE, Timer_CloseElevatorDoorAfterIdle, EntIndexToEntRef(ground), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		// Move the elevator with direction when not idle
		else
		{
			if (!isIdle)
			{
				groundVecOrigin[2] += (direction == ELEVATOR_UP) ? ELEVATOR_SPEED : ELEVATOR_SPEED * -1;
				DispatchKeyValueVectorSafe(ground, "origin", groundVecOrigin);
				
				if (playStartSound)
				{
					playStartSound = false;
					EmitSoundToAll(SOUND_ELEVATOR_START, ground, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					EmitSoundToAll(SOUND_ELEVATOR_MOVE_LOOP, ground, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
				}
			}
		}
	}

	// When the elevator is idle, someone press the button on that floor, open the door, and cancel the button
	int closestButton = GetElevatorClosestButton(ground);
	if (closestButton != -1 && isIdle)
	{
		int presses = GetEntProp(closestButton, Prop_Send, "m_nSkin");
		if (0 < presses && presses < 4)
		{
			if (direction == presses || presses == BUTTON_UPANDDOWN)
			{
				// Remove the light on the button
				SetEntProp(closestButton, Prop_Send, "m_nSkin", (direction == BUTTON_UP) ? ((presses == BUTTON_UPANDDOWN) ? BUTTON_DOWN : BUTTON_NULL) : ((presses == BUTTON_UPANDDOWN) ? BUTTON_UP : BUTTON_NULL));
				
				// Open the door obly if it is closed
				if (GetEntProp(ground, Prop_Send, "m_nSkin") == ELEVATOR_DOOR_CLOSED)
				{
					SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_OPEN_START);
					CreateTimer(ELEVATOR_IDLE, Timer_CloseElevatorDoorAfterIdle, EntIndexToEntRef(ground), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
	
	// When someone inside the elevator and press the floor, stop Idle
	int targetFloor = GetEntProp(ground, Prop_Send, "m_nSequence");
	targetFloor = (targetFloor > datas[1]) ? datas[1] : targetFloor;
	targetFloor = (targetFloor < 0) ? 0 : targetFloor;
	if (targetFloor > 0)
	{
		if (targetFloor > datas[0])
		{
			direction = ELEVATOR_UP;
			if (isIdle)
			{
				isIdle = false;
				playStartSound = true;
			}
		}
		else if (targetFloor < datas[0])
		{
			direction = ELEVATOR_DOWN;
			if (isIdle)
			{
				isIdle = false;
				playStartSound = true;
			}
		}
		
		if (isIdle)
		{
			if (datas[0] == targetFloor)
			{
				SetEntProp(ground, Prop_Send, "m_nSequence", 0);
			}
		}
	}

	//PrintCenterTextAll("Now Floor: %i Total Floor: %i\nTarget Button: %i Current Button: %i", datas[0], datas[1], GetEntProp(ground, Prop_Send, "m_nSequence"), currentButton);
	
	CreateDataTimer(0.001, Timer_ElevatorControl, pack2, TIMER_FLAG_NO_MAPCHANGE);
	pack2.WriteCell(EntIndexToEntRef(ground));
	pack2.WriteCell((currentButton == -1) ? -1 : EntIndexToEntRef(currentButton));
	pack2.WriteCell(direction);
	pack2.WriteCell(isIdle);
	pack2.WriteCell(playStartSound);
	
	return Plugin_Continue;
}

public Action Timer_CloseElevatorDoorAfterIdle(Handle timer, int groundRef)
{
	int ground = EntRefToEntIndex(groundRef);
	if (ground == -1) { return Plugin_Handled; }
	
	if (GetEntProp(ground, Prop_Send, "m_nSkin") != ELEVATOR_DOOR_CLOSED)
	{
		SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_CLOSE_WITH_DELAY);
	}

	return Plugin_Continue;
}

public Action Command_CreateElevator(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		float angles[3] = { 0.0, 0.0, 0.0 };
		CreateElevator(client, GetClientAimPosition(client), angles);
	}
}

public Action Command_CreateElevatorButton(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		CreateElevatorButton(client);
	}
}

public Action Command_ElevatorDebug(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		g_bIsDebug[client] = !g_bIsDebug[client];
		Build_PrintToChat(client, "Elevator Debug: %s", g_bIsDebug[client] ? "ON" : "OFF");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int entity = GetClientAimTarget(client, false);
	if (!IsValidEntity(entity)) { return Plugin_Continue; }
	
	// Return if not within the distance
	float entityVecOrigin[3], clientVecOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityVecOrigin);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientVecOrigin);
	if (GetVectorDistance(entityVecOrigin, clientVecOrigin) > 100.0)
	{
		return Plugin_Continue;
	}
	
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	
	// 
	if (StrEqual(strModelName, MODEL_ELEVATOR_BUTTON))
	{
		SetHudTextParams(-1.0, 0.55, 0.01, 124, 252, 0, 255, 1, 6.0, 0.5, 0.5);
		int floor = GetEntProp(entity, Prop_Data, "m_iHealth");
		int presses = GetEntProp(entity, Prop_Send, "m_nSkin");
		bool up = (presses == BUTTON_UPANDDOWN || presses == BUTTON_UP);
		bool down = (presses == BUTTON_UPANDDOWN || presses == BUTTON_DOWN);
		if (presses < BUTTON_UPANDDOWN)
		{
			if (buttons & IN_ATTACK && !up)
			{
				SetEntProp(entity, Prop_Send, "m_nSkin", (down) ? BUTTON_UPANDDOWN : BUTTON_UP);
				EmitSoundToAll(SOUND_ELEVATOR_BUTTON_PRESS, entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
			}
			if (buttons & IN_ATTACK2 && !down)
			{
				SetEntProp(entity, Prop_Send, "m_nSkin", (up) ? BUTTON_UPANDDOWN : BUTTON_DOWN);
				EmitSoundToAll(SOUND_ELEVATOR_BUTTON_PRESS, entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
			}
		}
		
		ShowHudText(client, -1, "Floor: %i\n\n▲ - [MOUSE1] to press\n▼ - [MOUSE2] to press", floor);
	}
	else if (StrEqual(strModelName, MODEL_ELEVATOR_GROUND))
	{
		if (buttons & IN_SCORE)
		{
			if (!g_bIN_SCORE[client])
			{
				g_bIN_SCORE[client] = true;
				ShowElevatorPanel(client, entity);
			}
			
			g_bIN_SCORE[client] = true;
		}
		else
		{
			g_bIN_SCORE[client] = false;
		}
		
		if (!(buttons & IN_SCORE))
		{
			int datas[3];
			datas = GetElevatorCurrentAndTotalFloor(entity);
			char strFloor[5] = "---";
			if (datas[0] != 0)
			{
				Format(strFloor, sizeof(strFloor), "%iF", datas);
			}

			SetHudTextParams(-1.0, 0.55, 0.01, 124, 252, 0, 255, 1, 6.0, 0.5, 0.5);
			ShowHudText(client, -1, "Press [TAB] to open Elevator Panel\n\n[ %s ]", strFloor);
		}
	}
	
	return Plugin_Continue;
}

void ShowElevatorPanel(int client, int ground)
{
	int datas[3];
	datas = GetElevatorCurrentAndTotalFloor(ground);
	int targetFloor = GetEntProp(ground, Prop_Send, "m_nSequence");
	char strTarget[5] = "---";
	if (targetFloor != 0)
	{
		Format(strTarget, sizeof(strTarget), "%iF", targetFloor);
	}
	
	char menuinfo[255];
	Menu menu = new Menu(Handler_ElevatorPanel);
	
	int owner = Build_ReturnEntityOwner(ground);
	if (owner == -1)
	{
		Format(menuinfo, sizeof(menuinfo), "Unknown's Elevator Panel\n \nTarget: %s\n ", strTarget);
	}
	else
	{
		Format(menuinfo, sizeof(menuinfo), "%N's Elevator Panel\n \nTarget: %s\n ", owner, strTarget);
	}
	menu.SetTitle(menuinfo);

	int goundRef = EntIndexToEntRef(ground);
	char strGroundRef[64];
	IntToString(goundRef, strGroundRef, sizeof(strGroundRef));
	Format(menuinfo, sizeof(menuinfo), "▶◀ Close\n ");
	menu.AddItem(strGroundRef, menuinfo);
	
	for (int i = 1; i <= datas[1]; i++)
	{
		char floor[10];
		IntToString(i, floor, sizeof(floor));
		if (datas[0] == i)
		{
			Format(menuinfo, sizeof(menuinfo), "%sF - Current", floor);
			menu.AddItem(strGroundRef, menuinfo, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), "%sF", floor);
			menu.AddItem(strGroundRef, menuinfo);
		}
	}
	
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);
}

public int Handler_ElevatorPanel(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char strGroundRef[64];
		menu.GetItem(selection, strGroundRef, sizeof(strGroundRef));
		int groundRef = StringToInt(strGroundRef);
		int ground = EntRefToEntIndex(groundRef);
		if (ground == -1) { return; }

		if (selection == 0) // Close
		{
			if (GetEntProp(ground, Prop_Send, "m_nSkin") == ELEVATOR_DOOR_OPENED)
			{
				SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_CLOSE_WITH_DELAY);
			}
			
			ShowElevatorPanel(client, ground);
		}
		else
		{
			int datas[3];
			datas = GetElevatorCurrentAndTotalFloor(ground);
			if (GetEntProp(ground, Prop_Send, "m_nSequence") != datas[0])
			{
				SetEntProp(ground, Prop_Send, "m_nSequence", selection);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

int GetElevatorNextButton(int ground, int direction)
{
	float groundPos[3], tempPos[3];
	GetEntPropVector(ground, Prop_Send, "m_vecOrigin", groundPos);
	groundPos[2] += 44.0; // 52.0 - 8.0 -- Button pos - Ground pos
	
	int nextButton = -1;
	float shortestDistance = -1.0, temp;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1)
	{
		if (IsElevatorButton(i) && IsElevatorButtonValidInRange(ground, i))
		{
			if (Build_ReturnEntityOwner(i) != Build_ReturnEntityOwner(ground)) { continue; }
			
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", tempPos);
			if (direction == ELEVATOR_UP) { if (groundPos[2] >= tempPos[2]) { continue; } }
			else if (direction == ELEVATOR_DOWN) { if (groundPos[2] <= tempPos[2]) { continue; } }

			temp = GetVectorDistance(groundPos, tempPos);
			if (shortestDistance == -1.0 || shortestDistance > temp)
			{
				shortestDistance = temp;
				nextButton = i;
			}
		}
	}
	
	return nextButton;
}

int GetElevatorClosestButton(int ground)
{
	float groundPos[3], tempPos[3];
	GetEntPropVector(ground, Prop_Send, "m_vecOrigin", groundPos);
	groundPos[2] += 44.0; // 52.0 - 8.0 -- Button pos - Ground pos
	
	int closestButton = -1;
	float shortestDistance = -1.0, temp;
	
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1)
	{
		if (IsElevatorButton(i) && IsElevatorButtonValidInRange(ground, i))
		{
			if (Build_ReturnEntityOwner(i) != Build_ReturnEntityOwner(ground)) { continue; }
			
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", tempPos);
			tempPos[0] = groundPos[0];
			tempPos[1] = groundPos[1];
			
			temp = GetVectorDistance(groundPos, tempPos);
			if (shortestDistance == -1.0 || shortestDistance > temp)
			{
				shortestDistance = temp;
				closestButton = i;
			}
		}
	}
	
	return closestButton;
}

// [0] - current floor number, [1] - total floor, [2] current floor button
int[] GetElevatorCurrentAndTotalFloor(int ground)
{
	float groundPos[3], tempPos[3];
	GetEntPropVector(ground, Prop_Send, "m_vecOrigin", groundPos);
	groundPos[2] += 44.0; // 52.0 - 8.0 -- Button pos - Ground pos

	int closestButton = -1;
	float shortestDistance = -1.0, closestButtonZ, temp;

	ArrayList floorZData = new ArrayList();
	ArrayList floorButtons = new ArrayList();
	int i = -1;
	while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1)
	{
		if (IsElevatorButton(i) && IsElevatorButtonValidInRange(ground, i))
		{
			if (Build_ReturnEntityOwner(i) != Build_ReturnEntityOwner(ground)) { continue; }
			
			floorButtons.Push(i);
			
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", tempPos);
			tempPos[0] = groundPos[0];
			tempPos[1] = groundPos[1];
			floorZData.Push(tempPos[2]);
			
			temp = GetVectorDistance(groundPos, tempPos);
			if (shortestDistance == -1.0 || shortestDistance > temp)
			{
				shortestDistance = temp;
				closestButton = i;
				closestButtonZ = tempPos[2];
			}
		}
	}
	
	int returns[3];
	
	if (closestButton != -1)
	{
		float[] fTemp = new float[floorZData.Length];
		for (int j = 0; j < floorZData.Length; j++)
		{
			fTemp[j] = floorZData.Get(j);
		}
		
		SortFloats(fTemp, floorZData.Length);
		
		for (int j = 0; j < floorZData.Length; j++)
		{
			// Set button Floor
			for (int k = 0; k < floorButtons.Length; k++)
			{
				int button = floorButtons.Get(k);
				GetEntPropVector(button, Prop_Send, "m_vecOrigin", tempPos);
				if (tempPos[2] == fTemp[j])
				{
					SetEntProp(button, Prop_Data, "m_iHealth", j + 1);
					break;
				}
			}
			
			if (closestButtonZ == fTemp[j])
			{
				returns[0] = j + 1;
			}
		}
		
		//floorZData.Sort(Sort_Ascending, Sort_Float); // SM 1.10 :(
		//returns[0] = floorZData.FindValue(closestButtonZ) + 1; // SM 1.10 :(
		returns[1] = floorZData.Length;
		returns[2] = closestButton;
	}
	
	delete floorZData;
	delete floorButtons;
	
	return returns;
} 

bool IsElevatorButtonValidInRange(int ground, int button, float range = 200.0)
{
	float groundPos[3], buttonPos[3];
	GetEntPropVector(ground, Prop_Send, "m_vecOrigin", groundPos);
	GetEntPropVector(button, Prop_Send, "m_vecOrigin", buttonPos);
	groundPos[2] = buttonPos[2];
	
	return (GetVectorDistance(groundPos, buttonPos) < range);
}

int CreateElevator(int client, const float pos[3], const float angles[3])
{
	int ground = CreateEntityByName("prop_dynamic_override");
	int body = CreateEntityByName("prop_dynamic_override");
	int button = CreateEntityByName("prop_dynamic_override");
	int door = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(body) && IsValidEntity(ground) && IsValidEntity(button) && IsValidEntity(door))
	{
		Build_RegisterEntityOwner(ground, client);
		
		// Set up ground
		SetEntProp(ground, Prop_Send, "m_nSolidType", 2); // an AABB
		SetEntProp(ground, Prop_Data, "m_nSolidType", 2);
		SetEntPropFloat(ground, Prop_Send, "m_flModelScale", 0.435314);
		SetEntityRenderMode(ground, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ground, _, _, _, 0);
		SetEntityModel(ground, MODEL_ELEVATOR_GROUND);
		float groundPos[3];
		groundPos = pos;
		groundPos[2] += 8.0;
		TeleportEntity(ground, groundPos, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(ground, Prop_Send, "m_nSkin", ELEVATOR_DOOR_CLOSED);
		DispatchSpawn(ground);
		
		// Set up body
		SetEntProp(body, Prop_Send, "m_nSolidType", 0); // no solid model
		SetEntProp(body, Prop_Data, "m_nSolidType", 0);
		SetEntityModel(body, MODEL_ELEVATOR_BODY);
		TeleportEntity(body, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(body);
		SetVariantString("!activator");
		AcceptEntityInput(body, "SetParent", ground);
		
		// Set up button
		SetEntProp(button, Prop_Send, "m_nSolidType", 0); // no solid model
		SetEntProp(button, Prop_Data, "m_nSolidType", 0);
		SetEntityModel(button, MODEL_ELEVATOR_BUTTON);
		float buttonPos[3];
		buttonPos = pos;
		buttonPos[0] += 64.0;
		buttonPos[1] -= 60.2;
		buttonPos[2] += 52.0;
		float angle[3] = {0.0, 180.0, 0.0};
		TeleportEntity(button, buttonPos, angle, NULL_VECTOR);
		DispatchSpawn(button);
		SetVariantString("!activator");
		AcceptEntityInput(button, "SetParent", ground);
		
		// Set up door
		SetEntProp(door, Prop_Send, "m_nSolidType", 0); // no solid model
		SetEntProp(door, Prop_Data, "m_nSolidType", 0);
		SetEntPropFloat(door, Prop_Send, "m_flModelScale", 0.97);
		SetEntityModel(door, MODEL_ELEVATOR_DOOR);
		float doorPos[3];
		doorPos = pos;
		doorPos[0] += 70.0;
		doorPos[2] += 8.0;
		TeleportEntity(door, doorPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(door);
		SetVariantString("!activator");
		AcceptEntityInput(door, "SetParent", ground);
		
		TeleportEntity(ground, NULL_VECTOR, angles, NULL_VECTOR);
		
		if (Build_ReturnEntityOwner(ground) == client)
		{
			DataPack pack;
			CreateDataTimer(0.1, Timer_ElevatorActionBySkin, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(EntIndexToEntRef(ground));
			pack.WriteCell(EntIndexToEntRef(body));
			pack.WriteCell(EntIndexToEntRef(button));
			pack.WriteCell(EntIndexToEntRef(door));
			
			return ground;
		}
	}

	AcceptEntityInputSafe(ground, "Kill");
	AcceptEntityInputSafe(body, "Kill");
	AcceptEntityInputSafe(button, "Kill");
	AcceptEntityInputSafe(door, "Kill");

	return -1;
}

int CreateElevatorButton(int client)
{
	int button = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(button))
	{
		Build_RegisterEntityOwner(button, client);

		SetEntProp(button, Prop_Send, "m_nSolidType", 6);
		SetEntProp(button, Prop_Data, "m_nSolidType", 6);
		SetEntityModel(button, MODEL_ELEVATOR_BUTTON);
		TeleportEntity(button, GetClientAimPosition(client), NULL_VECTOR, NULL_VECTOR);
		SetEntProp(button, Prop_Data, "m_takedamage", 1);
		DispatchSpawn(button);
		SDKHook(button, SDKHook_OnTakeDamage, OnButtonTakeDamage);
		
		if (Build_ReturnEntityOwner(button) == client)
		{
			return button;
		}
	}

	AcceptEntityInputSafe(button, "Kill");

	return -1;
}

public Action OnButtonTakeDamage(int button, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	SetEntProp(button, Prop_Send, "m_nSkin", 4);
}

bool IsElevator(int entity)
{
	if (!IsValidEntity(entity)) { return false; }
	
	if (GetEntPropFloat(entity, Prop_Send, "m_flModelScale") != 0.435314) { return false; }
	
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	if (!StrEqual(strModelName, MODEL_ELEVATOR_GROUND)) { return false; }
	
	return true;
}

bool IsElevatorButton(int entity)
{
	if (!IsValidEntity(entity)) { return false; }
	
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	if (!StrEqual(strModelName, MODEL_ELEVATOR_BUTTON)) { return false; }
	
	return true;
}

void AcceptEntityInputSafe(int entity, char[] input)
{
	if (IsValidEntity(entity))
	{
		AcceptEntityInput(entity, input);
	}
}

void DispatchKeyValueVectorSafe(int entity, char[] keyName, float vec[3])
{
	// When physics gun v5 return
	if (FloatAbs(vec[0]) < 80.0 && FloatAbs(vec[1]) < 80.0 && FloatAbs(vec[2]) < 80.0)
	{
		return;
	}
	
	DispatchKeyValueVector(entity, keyName, vec);
}

float[] GetClientEyePositionEx(int client)
{
	float pos[3]; 
	GetClientEyePosition(client, pos);
	
	return pos;
}

float[] GetClientEyeAnglesEx(int client)
{
	float angles[3]; 
	GetClientEyeAngles(client, angles);
	
	return angles;
}

float[] GetClientAimPosition(int client)
{
	float endpos[3];
	
	Handle trace = TR_TraceRayFilterEx(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(endpos, trace);
	}
	
	CloseHandle(trace);
	
	return endpos;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	return (IsValidEntity(entity) && entity != client && MaxClients < entity);
}
