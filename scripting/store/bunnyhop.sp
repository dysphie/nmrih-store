#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Bunnyhop_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif
	Store_RegisterHandler("bunnyhop", "", Bunnyhop_OnMapStart, Bunnyhop_Reset, Bunnyhop_Config, Bunnyhop_Equip, Bunnyhop_Remove, true);
}

public Bunnyhop_OnMapStart()
{
}

public Bunnyhop_Reset()
{
}

public Bunnyhop_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public Bunnyhop_Equip(client, id)
{
	return -1;
}

public Bunnyhop_Remove(client, id)
{
}

#if defined STANDALONE_BUILD
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
#else
public Action:Bunnyhop_OnPlayerRunCmd(client, &buttons)
#endif
{
	new m_iEquipped = Store_GetEquippedItem(client, "bunnyhop");
	if(m_iEquipped < 0)
		return Plugin_Continue;

	if (IsPlayerAlive(client))
    {
		if (buttons & IN_JUMP)
		{
			if (!(GetEntityFlags(client) & FL_ONGROUND))
			{
				if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
				{
					if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
					{
						buttons &= ~IN_JUMP;
					}
				}
			}
		}
    }

	return Plugin_Continue;
}