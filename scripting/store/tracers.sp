#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

new g_cvarTracerMaterial = -1;
new g_cvarTracerLife = -1;
new g_cvarTracerWidth = -1;

new g_aColors[STORE_MAX_ITEMS][4];
new bool:g_bRandom[STORE_MAX_ITEMS];

new g_iColors = 0;
new g_iBeam = -1;

int _TF_IgnoreEnt1 = -1;
int _TF_IgnoreEnt2 = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Tracers_OnPluginStart()
#endif
{	
	AddTempEntHook("Shotgun Shot", OnTE_FireBullets);

	g_cvarTracerMaterial = RegisterConVar("sm_store_tracer_material", "materials/sprites/laserbeam.vmt", "Material to be used with tracers", TYPE_STRING);
	g_cvarTracerLife = RegisterConVar("sm_store_tracer_life", "0.5", "Life of a tracer in seconds", TYPE_FLOAT);
	g_cvarTracerWidth = RegisterConVar("sm_store_tracer_width", "1.0", "Life of a tracer in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("tracer", "color", Tracers_OnMapStart, Tracers_Reset, Tracers_Config, Tracers_Equip, Tracers_Remove, true);
}

public Tracers_OnMapStart()
{
	g_iBeam = PrecacheModel2(g_eCvars[g_cvarTracerMaterial].sCache, true);
}

public Tracers_Reset()
{
	g_iColors = 0;
}

public Tracers_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iColors);

	KvGetColor(kv, "color", g_aColors[g_iColors][0], g_aColors[g_iColors][1], g_aColors[g_iColors][2], g_aColors[g_iColors][3]);
	if(g_aColors[g_iColors][3]==0)
		g_aColors[g_iColors][3] = 255;
	g_bRandom[g_iColors] = KvGetNum(kv, "rainbow", 0)?true:false;
	
	++g_iColors;
	
	return true;
}

public Tracers_Equip(client, id)
{
	return -1;
}

public Tracers_Remove(client, id)
{
}

Action OnTE_FireBullets(const char[] te_name, const int[] Players, int numClients, float delay)
{
	// player is off by 1, thanks newpsw for the hint!
	int   m_iPlayer  = TE_ReadNum("m_iPlayer") + 1; 

	if (!IsPlayer(m_iPlayer) || !IsClientInGame(m_iPlayer) || !IsPlayerAlive(m_iPlayer)) {
		return Plugin_Continue;
	}

	float m_vecOrigin[3];
	TE_ReadVector("m_vecOrigin", m_vecOrigin);
	
	int m_iEquipped = Store_GetEquippedItem(m_iPlayer, "tracer");
	if (m_iEquipped < 0) {
		return Plugin_Continue;
	}

	float m_vecAngles[3];
	m_vecAngles[0] = TE_ReadFloat("m_vecAngles[0]");
	m_vecAngles[1] = TE_ReadFloat("m_vecAngles[1]");

	// int m_iWeaponID = TE_ReadNum("m_iWeaponID");
	// int m_iMode     = TE_ReadNum("m_iMode");
	// TODO: Use above vars to determine how many bullets to fire, currently only one is fired


	int m_iSeed    = TE_ReadNum("m_iSeed");

	float m_flSpread = TE_ReadFloat("m_flSpread");

	// Here we recreate what normally happens on the client-side
	SetRandomSeed(++m_iSeed);
	float x = GetRandomFloat(-0.5, 0.5) + GetRandomFloat(-0.5, 0.5);
	float y = GetRandomFloat(-0.5, 0.5) + GetRandomFloat(-0.5, 0.5);
	FireBullets(m_iPlayer, m_vecOrigin, m_vecAngles, m_flSpread, x, y, m_iEquipped);

	return Plugin_Continue;
}

void FireBullets(int client, float vecSrc[3], float shootAngles[3], float vecSpread, float x, float y, int m_iEquipped)
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

	_TF_IgnoreEnt1 = client;
	//_TF_IgnoreEnt2 = GetLastHitEntity(client);
	_TF_IgnoreEnt2 = -1;
	TR_TraceRayFilter(vecSrc, vecEnd, MASK_SOLID | CONTENTS_DEBRIS | CONTENTS_HITBOX, RayType_EndPoint, TF_IgnoreTwoEnts);

	float m_fImpact[3];
	TR_GetEndPosition(m_fImpact);

	int idx = Store_GetDataIndex(m_iEquipped);

	while (g_bRandom[idx]) {
		idx = GetRandomInt(0, g_iColors);
	} 

	float m_fOrigin[3];
	GetClientEyePosition(client, m_fOrigin);
	
	TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iBeam, 0, 0, 0, Float:g_eCvars[g_cvarTracerLife].aCache, Float:g_eCvars[g_cvarTracerWidth].aCache, Float:g_eCvars[g_cvarTracerWidth].aCache, 1, 0.0, g_aColors[idx], 0);
	TE_SendToAll();
}

bool TF_IgnoreTwoEnts(int entity, int contentsMask)
{
	return !IsPlayer(entity) && entity != _TF_IgnoreEnt1 && entity != _TF_IgnoreEnt2;
}

bool IsPlayer(int client)
{
	return 0 < client <= MaxClients;
}

// int GetLastHitEntity(int client)
// {
// 	return GetEntDataEnt2(client, 0x1324);    // FIXME: Gamedata
// }