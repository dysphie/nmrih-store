#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new String:g_szWeapons[STORE_MAX_ITEMS][64];

new g_iWeapons = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Weapons_OnPluginStart()
#endif
{
	Store_RegisterHandler("weapon", "", Weapons_OnMapStart, Weapons_Reset, Weapons_Config, Weapons_Equip, Weapons_Remove, false);
}

public Weapons_OnMapStart()
{
}

public Weapons_Reset()
{
	g_iWeapons = 0;
}

public Weapons_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iWeapons);
	
	KvGetString(kv, "weapon", g_szWeapons[g_iWeapons], sizeof(g_szWeapons[]));
	
	++g_iWeapons;
	return true;
}

public Weapons_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	int weapon = GivePlayerItem(client, g_szWeapons[m_iData]);

	// In NMRiH, GivePlayerItem does not automatically equip the weapon
	// And EquipPlayerWeapon does not account for inventory weight
	if (weapon != -1 && GAME_NMRIH) 
	{
		float eyePos[3];
		GetClientEyePosition(client, eyePos);
		TeleportEntity(weapon, eyePos, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(weapon, "Use", client, client);
	}

	return 0;
}

public Weapons_Remove(client)
{
	return 0;
}