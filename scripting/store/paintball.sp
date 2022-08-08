#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

new String:g_szPaintballDecals[STORE_MAX_ITEMS][32][PLATFORM_MAX_PATH];

new g_iPaintballDecalIDs[STORE_MAX_ITEMS][32];
new g_iPaintballDecals[STORE_MAX_ITEMS] = {0, ...};
new g_iPaintballItems = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Paintball_OnPluginStart()
#endif
{	
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	if(GAME_TF2)
		return;
	
	Store_RegisterHandler("paintball", "", Paintball_OnMapStart, Paintball_Reset, Paintball_Config, Paintball_Equip, Paintball_Remove, true);
}

public Paintball_OnMapStart()
{
	decl String:m_szFullPath[PLATFORM_MAX_PATH];
	for(new a=0;a<g_iPaintballItems;++a)
		for(new i=0;i<g_iPaintballDecals[a];++i)
		{
			g_iPaintballDecalIDs[a][i] = PrecacheDecal(g_szPaintballDecals[a][i], true);
			Format(m_szFullPath, sizeof(m_szFullPath), "materials/%s", g_szPaintballDecals[a][i]);
			Downloader_AddFileToDownloadsTable(m_szFullPath);
		}
}

public Paintball_Reset()
{
	for(new i=0;i<STORE_MAX_ITEMS;++i)
		g_iPaintballDecals[i] = 0;
	g_iPaintballItems = 0;
}

public Paintball_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iPaintballItems);

	KvJumpToKey(kv, "Decals");
	KvGotoFirstSubKey(kv);

	do
	{
		KvGetString(kv, "material", g_szPaintballDecals[g_iPaintballItems][g_iPaintballDecals[g_iPaintballItems]], PLATFORM_MAX_PATH);
		++g_iPaintballDecals[g_iPaintballItems];
	} while (KvGotoNextKey(kv));
	
	KvGoBack(kv);
	KvGoBack(kv);

	++g_iPaintballItems;

	return true;
}

public Paintball_Equip(client, id)
{
	return -1;
}

public Paintball_Remove(client, id)
{
}

Action Paintball_OnGunShot(int m_iPlayer, float m_vecOrigin[3], float m_vecAngles[3], int m_iSeed, float m_flSpread)
{
	if (!IsPlayer(m_iPlayer) || !IsClientInGame(m_iPlayer) || !IsPlayerAlive(m_iPlayer)) {
		return Plugin_Continue;
	}
	
	int m_iEquipped = Store_GetEquippedItem(m_iPlayer, "paintball");
	if (m_iEquipped < 0) {
		return Plugin_Continue;
	}

	// Here we recreate what normally happens on the client-side
	SetRandomSeed(++m_iSeed);
	float x = GetRandomFloat(-0.5, 0.5) + GetRandomFloat(-0.5, 0.5);
	float y = GetRandomFloat(-0.5, 0.5) + GetRandomFloat(-0.5, 0.5);
	Paintball_FireBullets(m_iPlayer, m_vecOrigin, m_vecAngles, m_flSpread, x, y, m_iEquipped);

	return Plugin_Continue;
}

void Paintball_FireBullets(int client, float vecSrc[3], float shootAngles[3], float vecSpread, float x, float y, int m_iEquipped)
{
	float vecDirShooting[3], vecRight[3], vecUp[3];
	GetAngleVectors(shootAngles, vecDirShooting, vecRight, vecUp);

	// add the spray
	float vecDir[3];
	vecDir[0] = vecDirShooting[0] + x * vecSpread * vecRight[0] + y * vecSpread * vecUp[0];
	vecDir[1] = vecDirShooting[1] + x * vecSpread * vecRight[1] + y * vecSpread * vecUp[1];
	vecDir[2] = vecDirShooting[2] + x * vecSpread * vecRight[2] + y * vecSpread * vecUp[2];

	NormalizeVector(vecDir, vecDir);

	float flMaxRange = 8000.0;

	// max bullet range is 8000 units
	float vecEnd[3];
	vecEnd[0] = vecSrc[0] + vecDir[0] * flMaxRange;
	vecEnd[1] = vecSrc[1] + vecDir[1] * flMaxRange;
	vecEnd[2] = vecSrc[2] + vecDir[2] * flMaxRange;

	TR_TraceRayFilter(vecSrc, vecEnd, MASK_SOLID | CONTENTS_DEBRIS | CONTENTS_HITBOX, RayType_EndPoint, Paintball_IgnoreOneEnt, client);

	float m_fImpact[3];
	TR_GetEndPosition(m_fImpact);

	new m_iData = Store_GetDataIndex(m_iEquipped);
		
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", m_fImpact);
	TE_WriteNum("m_nIndex", g_iPaintballDecalIDs[m_iData][GetRandomInt(0, g_iPaintballDecals[m_iData]-1)]);
	TE_SendToAll();

}

bool Paintball_IgnoreOneEnt(int entity, int contentsMask, int ignore)
{
	return entity != ignore;
}

