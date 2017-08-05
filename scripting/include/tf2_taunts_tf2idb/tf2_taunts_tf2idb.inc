/*
**
*/
#if defined _tf2_taunts_tf2idb_included
 #endinput
#endif
#define _tf2_taunts_tf2idb_included

#define INT_HEX_LENGTH	10

enum TauntExecution {
	TauntExecution_Success = 0,
	TauntExecution_InvalidClient,
	TauntExecution_ClientNotInGame,
	TauntExecution_ClientIsUnassigned,
	TauntExecution_ClientIsSpectator,
	TauntExecution_InvalidClass,
	TauntExecution_TargetIsDead,
	TauntExecution_WrongClass,
	TauntExecution_IvalidIDX,
	TauntExecution_TauntFailed,
}

enum InitializationStatus {
	InitializationStatus_Success = 0,
	InitializationStatus_InvalidGamedataFile,
	InitializationStatus_InvalidGamedataOutdated,
#if defined _tf2idb_included //{
	InitializationStatus_FromTF2IDB_Error,
#endif //}
}

stock void ReplyToTauntTarget(int i_target, TauntExecution i_result)
{
	switch (i_result)
	{
		case TauntExecution_InvalidClient:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__InvalidClient");
		}
		case TauntExecution_ClientIsSpectator:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__ClientIsSpectator");
		}
		case TauntExecution_ClientIsUnassigned:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__ClientIsUnassigned");
		}
		case TauntExecution_InvalidClass:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__InvalidClass");
		}
		case TauntExecution_TargetIsDead:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__TargetIsDead");
		}
		case TauntExecution_WrongClass:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__WrongClass");
		}
		case TauntExecution_IvalidIDX:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__IvalidIDX");
		}
		case TauntExecution_TauntFailed:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target__TauntFailed");
		}
	}
}

stock void ReplyToTauntTargetOther(int i_target, TauntExecution i_result)
{
	switch (i_result)
	{
		case TauntExecution_InvalidClient:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__InvalidClient");
		}
		case TauntExecution_ClientIsSpectator:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__ClientIsSpectator");
		}
		case TauntExecution_ClientIsUnassigned:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__ClientIsUnassigned");
		}
		case TauntExecution_InvalidClass:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__InvalidClass");
		}
		case TauntExecution_TargetIsDead:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__TargetIsDead");
		}
		case TauntExecution_WrongClass:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__WrongClass");
		}
		case TauntExecution_IvalidIDX:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__IvalidIDX");
		}
		case TauntExecution_TauntFailed:
		{
			ReplyToCommand(i_target, "[SM] %t", "tf2_taunts_tf2idb__failed_to_target_other__TauntFailed");
		}
	}
}

stock TauntExecution CheckOnly(int i_target, TFClassType &i_class = TFClass_Unknown)
{
	if (!(i_target > 0 && i_target <= MaxClients))
	{
		return TauntExecution_InvalidClient;
	}
	if (!IsClientInGame(i_target))
	{
		return TauntExecution_ClientNotInGame;
	}
	if (TF2_GetClientTeam(i_target) == TFTeam_Unassigned)
	{
		return TauntExecution_ClientIsUnassigned;
	}
	if (TF2_GetClientTeam(i_target) == TFTeam_Spectator)
	{
		return TauntExecution_ClientIsSpectator;
	}
	if ((i_class = TF2_GetPlayerClass(i_target)) == TFClass_Unknown)
	{
		return TauntExecution_InvalidClass;
	}
	if (!IsPlayerAlive(i_target))
	{
		return TauntExecution_TargetIsDead;
	}
	return TauntExecution_Success;
}

stock TauntExecution CheckClassToo(int i_target, int i_idx, CTauntCacheSystem h_taunts, TFClassType &i_class = TFClass_Unknown)
{
	TauntExecution i_check_only_result;
	if ((i_check_only_result = CheckOnly(i_target, i_class)) != TauntExecution_Success) { return i_check_only_result; }
	
	int i_index;
	if (h_taunts.IsValidTaunt(i_idx, i_class, i_index))
	{
		return TauntExecution_Success;
	}
	else
	{
		if (i_index != -1)	//if IsValidTaunt returns false but the index is not -1, the idx is valid, but the classes don't match
		{
			return TauntExecution_WrongClass;
		}
		else
		{
			return TauntExecution_IvalidIDX;
		}
	}
}

stock TauntExecution CheckAndTaunt(int i_target, int i_idx, CTauntEnforcer h_enforcer, CTauntCacheSystem h_taunts, TFClassType &i_class = TFClass_Unknown)
{
	TauntExecution i_check_only_result;
	if ((i_check_only_result = CheckClassToo(i_target, i_idx, h_taunts, i_class)) != TauntExecution_Success) { return i_check_only_result; }
	
	if (h_enforcer.ForceTaunt(i_target, i_idx))
	{
		return TauntExecution_Success;
	}
	else
	{
		return TauntExecution_TauntFailed;
	}
}

stock int GetCmdArgInt(int i_argnum, int i_length = 12, int i_base = 10)
{
	char[] s_buffer = new char[i_length];
	GetCmdArg(i_argnum, s_buffer, i_length);
	return StringToInt(s_buffer, i_base);
}

stock bool AddDataToMenuAsInvisibleItem(Handle h_menu, any a_data)
{
	char s_data[INT_HEX_LENGTH];
	Format(s_data, sizeof(s_data), "%x", a_data);
	return AddMenuItem(h_menu, s_data, "", ITEMDRAW_IGNORE);
}

stock any GetDataFromInvisibleMenuItem(Handle h_menu, bool b_last_position = true, int i_position = -1, bool &b_success = false)
{
	char s_data[INT_HEX_LENGTH];
	if (b_last_position)
	{
		i_position = GetMenuItemCount(h_menu) - 1;
	}
	b_success = GetMenuItem(h_menu, i_position, s_data, sizeof(s_data));
	return view_as<any>(StringToInt(s_data, 16));
}

stock int AddTauntsToMenu(Handle h_menu, TFClassType i_class, CTauntCacheSystem h_taunts)
{
	ArrayList h_list_for_class = h_taunts.GetListForClass(i_class);
	int i_name_maxlen = h_taunts.m_iMaxNameLength;
	char[] s_name = new char[i_name_maxlen];
	char s_hex_idx[10];
	
	for (int i_iter = 0; i_iter < GetArraySize(h_list_for_class); i_iter++)
	{
		int i_index = GetArrayCell(h_list_for_class, i_iter);
		h_taunts.GetTauntName(i_index, s_name, i_name_maxlen);
		Format(s_hex_idx, sizeof(s_hex_idx), "%x", h_taunts.GetTauntItemID(i_index));
		AddMenuItem(h_menu, s_hex_idx, s_name);
	}
	
	for (int i_iter = 0; i_iter < GetArraySize(h_taunts.m_hAllClassTaunts); i_iter++)
	{
		int i_index = GetArrayCell(h_taunts.m_hAllClassTaunts, i_iter);
		h_taunts.GetTauntName(i_index, s_name, i_name_maxlen);
		Format(s_hex_idx, sizeof(s_hex_idx), "%x", h_taunts.GetTauntItemID(i_index));
		AddMenuItem(h_menu, s_hex_idx, s_name);
	}
}