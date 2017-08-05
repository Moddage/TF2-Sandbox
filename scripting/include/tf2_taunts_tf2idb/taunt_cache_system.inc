/*
**
*/
#if defined _tf2_taunt_menu_tf2idb_included
 #endinput
#endif
#define _tf2_taunt_menu_tf2idb_included

enum _CTauntCacheSystem_Storage {
	_CTauntCacheSystem_Storage_ItemIDs = 0,
	_CTauntCacheSystem_Storage_ClassBF,
	_CTauntCacheSystem_Storage_Names,
	_CTauntCacheSystem_Storage_ClassesArrays,
	_CTauntCacheSystem_Storage_NOfElements,
	_CTauntCacheSystem_Storage_NamesMaxBuff,
}

#if defined _tf2idb_included
enum CTauntCacheSystem_FromTF2IDB_Error {
	CTauntCacheSystem_FromTF2IDB_Error_None = 0,
	CTauntCacheSystem_FromTF2IDB_Error_FindIDs,
	CTauntCacheSystem_FromTF2IDB_Error_FindMaxNameLength,
}
#endif

methodmap CTauntCacheSystem < ArrayList {
	public CTauntCacheSystem(int[] i_idxs, int[] i_bfields, char[][] s_names, int i_nof_items, int i_names_maxlen)
	{
		ArrayList h_this = CreateArray(1, view_as<int>(_CTauntCacheSystem_Storage));
		ArrayList h_ids = CreateArray(1, i_nof_items);
		ArrayList h_bfields = CreateArray(1, i_nof_items);
		ArrayList h_names = CreateArray(ByteCountToCells(i_names_maxlen), i_nof_items);
		ArrayList h_classes = CreateArray(1, view_as<int>(TFClassType));
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_ItemIDs, 		h_ids);
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_ClassBF, 		h_bfields);
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_Names, 		h_names);
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_NamesMaxBuff, i_names_maxlen);
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_ClassesArrays, h_classes);
		SetArrayCellIndexAsAny(h_this, _CTauntCacheSystem_Storage_NOfElements, 	i_nof_items);
	
		for (int i_class = 0; i_class < view_as<int>(TFClassType); i_class++)
		{
			SetArrayCell(h_classes, i_class, CreateArray());
		}
		
		for (int i_iter = 0; i_iter < i_nof_items; i_iter++)
		{
			SetArrayCell(h_ids, i_iter, i_idxs[i_iter]);
			SetArrayCell(h_bfields, i_iter, i_bfields[i_iter]);
			SetArrayString(h_names, i_iter, s_names[i_iter]);
			if (i_bfields[i_iter] == 0b1111111110)
			{
				PushArrayCell(GetArrayCell(h_classes, view_as<any>(TFClass_Unknown)), i_iter);
			}
			else
			{
				for (int i_class = 1; i_class < view_as<int>(TFClassType); i_class++)
				{
					if (i_bfields[i_iter] & (1 << i_class))
					{
						PushArrayCell(GetArrayCell(h_classes, i_class), i_iter);
					}
				}
			}
		}
		return view_as<CTauntCacheSystem>(h_this);
	}
	
#if defined _tf2idb_included //{
	public static CTauntCacheSystem FromTF2IDB(CTauntCacheSystem_FromTF2IDB_Error &i_error = CTauntCacheSystem_FromTF2IDB_Error_None)
	{
		ArrayList h_idxs = view_as<ArrayList>(TF2IDB_FindItemCustom("SELECT `id` FROM tf2idb_item WHERE `slot` IS 'taunt'"));
		if (h_idxs == INVALID_HANDLE)
		{
			i_error = CTauntCacheSystem_FromTF2IDB_Error_FindIDs;
			return view_as<CTauntCacheSystem>(INVALID_HANDLE);
		}
		int i_nof_items = GetArraySize(h_idxs);
		
		ArrayList h_name_maxlength = view_as<ArrayList>(TF2IDB_FindItemCustom("SELECT max(length(`name`)) FROM tf2idb_item WHERE `slot` IS 'taunt'"));
		if (h_name_maxlength == INVALID_HANDLE)
		{
			i_error = CTauntCacheSystem_FromTF2IDB_Error_FindMaxNameLength;
			CloseHandle(h_idxs);
			return view_as<CTauntCacheSystem>(INVALID_HANDLE);
		}
		int i_name_maxlength = GetArrayCell(h_name_maxlength, 0); CloseHandle(h_name_maxlength);
		
		int[] i_idxs = new int[i_nof_items];
		ArrayListOfIntsToIntArray(h_idxs, i_idxs);
		CloseHandle(h_idxs);
		
		char[][] s_names = new char[i_nof_items][i_name_maxlength];
		int[] i_bfields = new int[i_nof_items];
		
		//for each taunt
		for (int i_index = 0; i_index < i_nof_items; i_index++)
		{
			i_bfields[i_index] = TF2IDB_UsedByClasses_Compat(i_idxs[i_index]);
			TF2IDB_GetItemName(i_idxs[i_index], s_names[i_index], i_name_maxlength);
		}
		
		i_error = CTauntCacheSystem_FromTF2IDB_Error_None;
		
		return new CTauntCacheSystem(i_idxs, i_bfields, s_names, i_nof_items, i_name_maxlength);
	}
#endif //}

#if defined _tf2itemsinfo_included //{
	public static CTauntCacheSystem FromTF2II()
	{
		int i_nof_items;
		ArrayList h_idxs = view_as<ArrayList>(TF2II_FindItems("", "taunt"));
		i_nof_items = GetArraySize(h_idxs);
		
		int[] i_idxs = new int[i_nof_items];
		ArrayListOfIntsToIntArray(h_idxs, i_idxs);
		
		CloseHandle(h_idxs);
		
		char[][] s_names = new char[i_nof_items][TF2II_ITEMNAME_LENGTH];
		int[] i_bfields = new int[i_nof_items];
		
		
		for (int i_iter = 0; i_iter < i_nof_items; i_iter++)
		{
			TF2II_GetItemName(i_idxs[i_iter], s_names[i_iter], TF2II_ITEMNAME_LENGTH);
			
			for (int i_class = 1; i_class < view_as<int>(TFClassType); i_class++)
			{
				if (TF2II_IsItemUsedByClass(i_idxs[i_iter], view_as<TFClassType>(i_class)))
				{
					i_bfields[i_iter] |= (1 << i_class);
				}
			}
		}
		
		return new CTauntCacheSystem(i_idxs, i_bfields, s_names, i_nof_items, TF2II_ITEMNAME_LENGTH);
	}
#endif //}

	property int m_iNOfItems
	{
		public get() { return GetArrayCell(this, _CTauntCacheSystem_Storage_NOfElements); }
	}

	property ArrayList m_hTauntIDXs
	{
		public get() { return GetArrayCell(this, _CTauntCacheSystem_Storage_ItemIDs); }
	}

	property ArrayList m_hAllClassTaunts
	{
		public get() { return GetArrayCell(GetArrayCell(this, _CTauntCacheSystem_Storage_ClassesArrays), view_as<int>(TFClass_Unknown)); }
	}
	
	property int m_iMaxNameLength
	{
		public get() { return GetArrayCell(this, _CTauntCacheSystem_Storage_NamesMaxBuff); }
	}
	
	public ArrayList GetListForClass(TFClassType i_class)
	{
		if (i_class == TFClass_Unknown)
		{
			return view_as<ArrayList>(INVALID_HANDLE);
		}
		return GetArrayCellIndexAsAny(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ClassesArrays), i_class);
	}
	
	public int FindTauntByDefIndex(int i_idx)
	{
		return FindValueInArray(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ItemIDs), i_idx);
	}
	
	public int GetClasses(int i_index, bool b_classes[TFClassType])
	{
		int i_bitfield = GetArrayCell(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ClassBF), i_index);
		int i_hits;
		for (int i_class = 1; i_class < view_as<int>(TFClassType); i_class++)
		{
			if (i_bitfield & (1 << i_class))
			{
				b_classes[i_class] = true;
				i_hits++;
			}
		}
		return i_hits;
	}
	
	public bool IsAllClass(int i_idx)
	{
		return GetArrayCell(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ClassBF), i_idx) == 0b1111111110;
	}
	
	public bool IsValidTaunt(int i_idx, TFClassType i_class = TFClass_Unknown, int &i_index = 0)
	{
		i_index = FindValueInArray(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ItemIDs), i_idx);
		if (i_index == -1)
		{
			return false;
		}
		else if (i_class != TFClass_Unknown)
		{
			return ((FindValueInArray(this.GetListForClass(i_class), i_index) != -1) || (FindValueInArray(this.m_hAllClassTaunts, i_index) != -1));
		}
		else
		{
			return true;
		}
	}
	 
	public int GetTauntName(int i_index, char[] s_name, int i_name_maxlen)
	{
		return GetArrayString(GetArrayCell(this, _CTauntCacheSystem_Storage_Names), i_index, s_name, i_name_maxlen);
	}
	
	public int GetTauntItemID(int i_index)
	{
		return GetArrayCell(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ItemIDs), i_index);
	}
	
	public void CloseChild()
	{
		CloseHandle(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ItemIDs));
		CloseHandle(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ClassBF));
		CloseHandle(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_Names));
		for (int i_class = 0; i_class < view_as<int>(TFClassType); i_class++)
		{
			CloseHandle(GetArrayCell(GetArrayCell(this, _CTauntCacheSystem_Storage_ClassesArrays), i_class));
		}
		CloseHandle(GetArrayCellIndexAsAny(this, _CTauntCacheSystem_Storage_ClassesArrays));
	}
}

#if defined _tf2idb_included //{
//older versions of tf2idb don't include TF2IDB_UsedByClasses
//this function gets around that restriction
//if you know a better way to do this, let me know plz
stock int TF2IDB_UsedByClasses_Compat(int i_id)
{
	char s_query[255 /* the query without the id is ~249 chars */ - 2 + 12];
	
	Format(s_query, sizeof(s_query), 
		"SELECT replace(replace(replace(replace(replace(replace(replace(replace(replace(" ... 
		"`class`, 'scout', 1), 'sniper', 2), 'soldier', 3), 'demoman', 4), 'medic', 5), 'heavy', 6), 'pyro', 7), 'spy', 8), 'engineer', 9) " ... 
		"FROM `tf2idb_class` WHERE `id` IS %d",
		i_id);
	
	ArrayList h_classes = view_as<ArrayList>(TF2IDB_FindItemCustom(s_query));
	int i_bitmask;
	
	for (int i_iter = 0; i_iter < GetArraySize(h_classes); i_iter++)
	{
		i_bitmask |= (1 << GetArrayCell(h_classes, i_iter));
	}
	return i_bitmask;
}
#endif //}

stock any GetArrayCellIndexAsAny(Handle array, any index, int block=0, bool asChar=false)
{
	return GetArrayCell(array, view_as<int>(index), block, asChar);
}

stock any SetArrayCellIndexAsAny(Handle array, any index, any value, int block=0, bool asChar=false)
{
	return SetArrayCell(array, view_as<int>(index), value, block, asChar);
}

stock void ArrayListOfIntsToIntArray(ArrayList h_ints, int[] i_ints)
{
	for (int i_iter = 0; i_iter < GetArraySize(h_ints); i_iter++)
	{
		i_ints[i_iter] = GetArrayCell(h_ints, i_iter);
	}
}
