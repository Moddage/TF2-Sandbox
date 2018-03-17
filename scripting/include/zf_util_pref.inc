////////////////////////////////////////////////////////////////////////////////
//
//  Z O M B I E - F O R T R E S S - [TF2]
//
//  ZF Utility Preferences File
//
//  Includes stock routines for client preferences.
//
////////////////////////////////////////////////////////////////////////////////

#if defined _ZF_UTIL_PREF_INC
  #endinput
#endif
#define _ZF_UTIL_PREF_INC

//#define ZF_PREF_LOG

//
// Fields
//
#define MAX_PREF_TRIE_SIZE 512

#define MAX_PREFS 7
enum ZFPref
{
  JoinState = 0,
  TeamPref,  
  SurPerk,
  SurPendPerk,
  ZomPerk,
  ZomPendPerk,
  PerkSelectMode
};
new const DEFAULT_PREFS[MAX_PREFS] = {
  0,                  // JoinState
  1,                  // TeamPref
  0,                  // SurPerk
  0,                  // SurPendPerk
  0,                  // ZomPerk
  0,                  // ZomPendPerk
  0                   // PerkSelectMode
};
  
//
// Field Definitions
//
#define ZF_JOINSTATE_SUR 0x1
#define ZF_JOINSTATE_ZOM 0x2

#define ZF_TEAMPREF_SUR  0
#define ZF_TEAMPREF_NONE 1
#define ZF_TEAMPREF_ZOM  2

//
// Objects
//
static Handle:prefTrie;
static prefCache[MAXPLAYERS+1][MAX_PREFS];

////////////////////////////////////////////////////////////
//
// Pref Init
//
////////////////////////////////////////////////////////////
utilPrefInit()
{
  prefTrie = CreateTrie();
}

////////////////////////////////////////////////////////////
//
// Pref Events
//
////////////////////////////////////////////////////////////
stock pref_OnClientConnect(client)
{
  decl String:steamID[32];  
  if(GetClientAuthString(client, steamID, sizeof(steamID)))
  {
    if(GetTrieArray(prefTrie, steamID, prefCache[client], sizeof(DEFAULT_PREFS)))
    {
      //
      // Client already present. Cache has been updated with trie data.
      //
#if defined ZF_PREF_LOG       
      LogMessage("[ZF] pref_OnClientConnect %d(%s) already present.", client, steamID);      
#endif      
    }
    else
    {
      //
      // Client not present. Update cache and trie with default data.
      //
#if defined ZF_PREF_LOG       
      LogMessage("[ZF] pref_OnClientConnect %d(%s) not present.", client, steamID);      
#endif      
      prefCache[client][JoinState]     = DEFAULT_PREFS[JoinState];
      prefCache[client][TeamPref]      = DEFAULT_PREFS[TeamPref];
      prefCache[client][SurPerk]       = DEFAULT_PREFS[SurPerk];
      prefCache[client][SurPendPerk]   = DEFAULT_PREFS[SurPendPerk];
      prefCache[client][ZomPerk]       = DEFAULT_PREFS[ZomPerk];      
      prefCache[client][ZomPendPerk]   = DEFAULT_PREFS[ZomPendPerk];
      prefCache[client][PerkSelectMode]= DEFAULT_PREFS[PerkSelectMode];
      SetTrieArray(prefTrie, steamID, prefCache[client], sizeof(DEFAULT_PREFS));
    }
  }
  else
  {
    //
    // Can't get client's STEAM_ID as string. Update cache with default data.
    //      
    prefCache[client][JoinState]      = DEFAULT_PREFS[JoinState];
    prefCache[client][TeamPref]       = DEFAULT_PREFS[TeamPref];
    prefCache[client][SurPerk]        = DEFAULT_PREFS[SurPerk];
    prefCache[client][SurPendPerk]    = DEFAULT_PREFS[SurPendPerk];
    prefCache[client][ZomPerk]        = DEFAULT_PREFS[ZomPerk];      
    prefCache[client][ZomPendPerk]    = DEFAULT_PREFS[ZomPendPerk];
    prefCache[client][PerkSelectMode] = DEFAULT_PREFS[PerkSelectMode];
    LogError("[ZF] pref_OnClientConnect %d can't get STEAM_ID as string.", client); 
  }  
  
  //
  // Maintain realistic trie size.
  // Clear trie if it gets too large. Connected clients will not lose their
  // preferences, as they will be reinserted into the trie on disconnect.
  //
  if(GetTrieSize(prefTrie) > MAX_PREF_TRIE_SIZE)
    ClearTrie(prefTrie);
}

stock pref_OnClientDisconnect(client)
{
  decl String:steamID[32];
  if(GetClientAuthString(client, steamID, sizeof(steamID)))
  {
    //
    // Update trie with cache data.
    //
#if defined ZF_PREF_LOG    
    LogMessage("[ZF] pref_OnClientDisconnect %d(%s).", client, steamID);
#endif    
    SetTrieArray(prefTrie, steamID, prefCache[client], sizeof(DEFAULT_PREFS));  
  }  
}

////////////////////////////////////////////////////////////
//
// Pref Cache Accessors
//
////////////////////////////////////////////////////////////
stock prefGet(client, ZFPref:pref)
{ return prefCache[client][pref]; }
stock prefSet(client, ZFPref:pref, value)
{ prefCache[client][pref]= value; }
