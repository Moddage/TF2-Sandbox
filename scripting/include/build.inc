#define BUILDMODAPI_VER 3
#define BUILDMOD_VER "0.71"
#define MAX_HOOK_ENTITIES 4096

/**
 * Register an entity owner.
 * 
 * @param entity_index		Entity index.
 * @param client_index		Client index.
 * @param Doll				Is prop_ragdoll?
 * @return					Ture on success. False on failure.
 */
native bool:Build_RegisterEntityOwner(entity_index, client_index, bool:Doll = false);

/**
 * Get an entity owner.
 * 
 * @param entity_index		Entity index.
 * @return					-1 on failure. Any other value indicates a Entity index owner.
 */
native Build_ReturnEntityOwner(entity_index);

/**
 * Set client props limit.
 *
 * @param client_index		Client index.
 * @param amount			Amount to increase or decrease. If amount = 0 then set limit to 0.
 * @param Doll				Is prop_ragdoll?
 * @noreturn
 */
native Build_SetLimit(client_index, amount, bool:Doll = false);

/**
 * Check client can use BuildMod.
 * 
 * @param client_index		Client index.
 * @return					True on success. False on failure.
 */
native bool:Build_AllowToUse(client_index);

/**
 * Check client can use Fly.
 * 
 * @param client_index		Client index.
 * @return					True on success. False on failure.
 */
native bool:Build_AllowFly(client_index);

/**
 * Get client admin.
 * 
 * @param client_index		Client index.
 * @param Level2			Level 2 access.
 * @return					True on admin. False on not.
 */
native bool:Build_IsAdmin(client_index, bool:Level2 = false);

/**
 * Get client aim entity.
 * 
 * @param client_index		Client index.
 * @param show_message		Show a message when entity invalid?
 * @param included_clients	Allow native to getting clients?
 * @return					-1 on failure. Any other value indicates a Entity index.
 */
native Build_ClientAimEntity(client_index, bool:show_message = true, bool:included_clients = false);

/**
 * Get an entity of owner is equal client.
 * 
 * @param client_index		Client index.
 * @param entity_index		Entity index.
 * @param bIngoreCvar		Ingore 'bm_nonowner' cvar?
 * @return					True on owner. False on not.
 */
native bool:Build_IsEntityOwner(client_index, entity_index, bool:bIngoreCvar = false);

/**
 * Logging commands and args.
 * 
 * @param client_index		Client index.
 * @param command			Command to log.
 * @param args				Args to log.
 * @noreturn
 */
native Build_Logging(client_index, const String:command[], const String:args[]);

/**
 * Prints a message with the BuildMod tag.
 *
 * @param client_index		Client index.
 * @param format			Formatting rules.
 * @param ...				Variable number of format parameters.
 * @noreturn
 */
native Build_PrintToChat(client_index, const String:format[], any:...);

/**
 * Prints a message to all clients with the BuildMod tag.
 *
 * @param format			Formatting rules.
 * @param ...				Variable number of format parameters.
 * @noreturn
 */
native Build_PrintToAll(const String:format[], any:...);

/**
 * Add client to blacklist.
 *
 * @param client_index		Client index.
 * @return					True on success. False on failure.
 */
native Build_AddBlacklist(client_index);

/**
 * Remove client from blacklist.
 *
 * @param client_index		Client index.
 * @return					True on success. False on failure.
 */
native Build_RemoveBlacklist(client_index);

/**
 * Get client is blacklisted.
 *
 * @param client_index		Client index.
 * @return					True on blacklisted. False on not.
 */
native bool:Build_IsBlacklisted(client_index);

/**
 * Check is target client valid.
 *
 * @param client_index		Client index.
 * @param target_index		Target index.
 * @param Alive				Check is target alive.
 * @param ReplyTarget		Alive result reply target client or self.
 * @return					True if target valid. Otherwise false.
 */
native bool:Build_IsClientValid(client_index, target_index, bool:Alive = false, bool:ReplyTarget = false);
