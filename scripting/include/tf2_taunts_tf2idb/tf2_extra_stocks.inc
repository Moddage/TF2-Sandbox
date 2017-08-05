/*
**
*/
#if defined _tf2_extra_stocks_included
 #endinput
#endif
#define _tf2_extra_stocks_included

#define TF_MAX_CLASS_NAME_LENGTH	9

stock int TF2_ClassEnumToString(TFClassType i_class, char s_class[TF_MAX_CLASS_NAME_LENGTH])
{
	switch (i_class)
	{
			case TFClass_Scout: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "scout");
			case TFClass_Soldier: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "soldier");
			case TFClass_Pyro: 		return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "pyro");
			case TFClass_DemoMan: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "demoman");
			case TFClass_Heavy: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "heavy");
			case TFClass_Medic: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "medic");
			case TFClass_Sniper: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "sniper");
			case TFClass_Spy: 		return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "spy");
			case TFClass_Engineer: 	return Format(s_class, TF_MAX_CLASS_NAME_LENGTH, "engineer");
	}
	return 0;
}