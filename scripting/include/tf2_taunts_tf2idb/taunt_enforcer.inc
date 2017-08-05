/*
**
*/
#if defined _taunt_enforcer_included
 #endinput
#endif
#define _taunt_enforcer_included

#include "tf2items.inc"

typedef TauntMultipleFilter = function bool(int i_target);

methodmap CTauntEnforcer < Handle {
	public CTauntEnforcer(Handle h_game_config, const char[] s_prop_name = "CTFPlayer::PlayTauntSceneFromItem")
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(h_game_config, SDKConf_Signature, s_prop_name);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		return view_as<CTauntEnforcer>(EndPrepSDKCall());
	}
	
	public bool CBasePlayer_PlayTauntSceneFromItem(int i_client, Address i_pointer)
	{
		return SDKCall(this, i_client, i_pointer);
	}
	
	property Handle m_hBaseTauntItem
	{
		public get() 
		{
			static Handle h_item;
			if (h_item == INVALID_HANDLE)
			{
				h_item = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
				TF2Items_SetClassname(h_item, "tf_wearable_vm");
				TF2Items_SetQuality(h_item, 6);
				TF2Items_SetLevel(h_item, 1);
			}
			return h_item;
		}
	}
	
	public static void MakeCEconViewItem(int i_defindex, int i_particle_id = 0)
	{
		//since the getter for ``m_hBaseTauntItem`` won't reference ``this``
		CTauntEnforcer i_null_instance = view_as<CTauntEnforcer>(null);
		Handle h_item = i_null_instance.m_hBaseTauntItem;
		
		TF2Items_SetItemIndex(h_item, i_defindex);
		TF2Items_SetNumAttributes(h_item, i_particle_id ? 1 : 0);
		if (i_particle_id) { TF2Items_SetAttribute(h_item, 0, 2041, float(i_particle_id)); }
	}
	
	public bool ForceTaunt(int i_client, int i_defindex, int i_particle_id = 0)
	{
		CTauntEnforcer.MakeCEconViewItem(i_defindex, i_particle_id);
		int i_ent_index = TF2Items_GiveNamedItem(i_client, this.m_hBaseTauntItem);
		if (!IsValidEntity(i_ent_index))
		{
			return false;
			//:TODO: Add error checks
		}
		
		Address i_pointer = GetEntityAddress(i_ent_index) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
		bool b_success = this.CBasePlayer_PlayTauntSceneFromItem(i_client, i_pointer);
		
		AcceptEntityInput(i_ent_index, "Kill");
		return b_success;
	}
	
	public int ForceTauntMultiple(const int[] i_targets, bool[] b_success, int i_nof_targets, int i_defindex, int i_particle_id = 0)
	{
		CTauntEnforcer.MakeCEconViewItem(i_defindex, i_particle_id);
		// a dummy client will actually hold the taunt, but others can pkay it
		int i_ent_index = TF2Items_GiveNamedItem(i_targets[0], this.m_hBaseTauntItem);
		if (!IsValidEntity(i_ent_index))
		{
			return 0;
			//:TODO: Add error checks
		}
		
		Address i_pointer = GetEntityAddress(i_ent_index) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
		
		int i_hits = 0;
		
		for (int i_iter = 0; i_iter < i_nof_targets; i_iter++)
		{
			b_success[i_iter] = this.CBasePlayer_PlayTauntSceneFromItem(i_targets[i_iter], i_pointer);
			if (b_success[i_iter]) { i_hits++; }
		}
		
		AcceptEntityInput(i_ent_index, "Kill");
		return i_hits;
	}
	
	public int ForceTauntMultipleFiltered(const int[] i_targets, bool[] b_success, int i_nof_targets, int i_defindex, TauntMultipleFilter f_filter, int i_particle_id = 0)
	{
		CTauntEnforcer.MakeCEconViewItem(i_defindex, i_particle_id);
		// a dummy client will actually hold the taunt, but others can pkay it
		int i_ent_index = TF2Items_GiveNamedItem(i_targets[0], this.m_hBaseTauntItem);
		if (!IsValidEntity(i_ent_index))
		{
			return 0;
			//:TODO: Add error checks
		}
		
		Address i_pointer = GetEntityAddress(i_ent_index) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
		
		int i_hits = 0;
		bool b_continue;
		
		for (int i_iter = 0; i_iter < i_nof_targets; i_iter++)
		{
			Call_StartFunction(INVALID_HANDLE, f_filter);
			Call_PushCell(i_targets[i_iter]);
			Call_Finish(b_continue);
			if (b_continue)
			{
				b_success[i_iter] = this.CBasePlayer_PlayTauntSceneFromItem(i_targets[i_iter], i_pointer);
			}
			if (b_success[i_iter]) { i_hits++; }
		}
		
		AcceptEntityInput(i_ent_index, "Kill");
		return i_hits;
	}
}