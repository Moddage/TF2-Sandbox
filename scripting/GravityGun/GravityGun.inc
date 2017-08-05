/* #if defined _gravitygun_included
 #endinput
#endif
#define _gravitygun_included */

//u can stop client`s grab try by this forward. return continue to allow grab of current entity or any other value to stop
forward Action:OnClientGrabEntity(client, entity);

//u can stop client`s drag try by this forward. return continue to allow drag of current entity or any other value to stop
forward Action:OnClientDragEntity(client, entity);

//u can stop client`s punt(when cilents not helding target entity)
forward Action:OnClientEmptyShootEntity(client, entity);

//u can stop client`s throw(when cilents helding target entity)
forward Action:OnClientShootEntity(client, entity);

//get current held entity of cilent, it will return -1 if cilent is dead or no held entity
native GG_GetCurrentHeldEntity(client);

//force to drop any entity if player is holding some, returns false on fail
native bool:GG_ForceDropHeldEntity(client);

//this will let u make able to change cilent`s grabbed entity.
//return : true on success, false on fail(bad entity index, cilent not valid, already holded by other client ect...)
native bool:GG_ForceGrabEntity(client, entity);

public SharedPlugin:__pl_gravitygun = 
{
	name = "GravityGun",
	file = "GravityGun.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif

};
 
public __pl_gravitygun_SetNTVOptional()
{
	MarkNativeAsOptional("GG_GetCurrentHeldEntity");
	MarkNativeAsOptional("GG_ForceDropHeldEntity");
	MarkNativeAsOptional("GG_ForceGrabEntity");
}