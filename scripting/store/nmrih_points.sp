#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#endif

ConVar cvPointsPerKill;
ConVar cvPointsPerExtraction;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
void NMRiHPoints_OnPluginStart()
{
	cvPointsPerKill = CreateConVar("sm_store_nmrih_points_per_zombie_kill", "1", "Points per zombie kill");
	cvPointsPerExtraction = CreateConVar("sm_store_nmrih_points_per_extraction", "200", "Points to receive when getting extracted");

	HookEvent("npc_killed", Event_NPCKilled);
	HookEvent("player_extracted", Event_PlayerExtracted);
}

void Event_NPCKilled(Event event, const char[] name, bool dontBroadcast)
{
	int rewardPoints = cvPointsPerKill.IntValue;
	if (rewardPoints == 0) {
		return;
	}

	int killeridx = event.GetInt("killeridx");

	if (!IsEntityPlayerInGame(killeridx)) {
		return;
	}

	int curCredits = Store_GetClientCredits(killeridx);
	Store_SetClientCredits(killeridx, curCredits + rewardPoints);
}

void Event_PlayerExtracted(Event event, const char[] name, bool dontBroadcast)
{	
	int rewardPoints = cvPointsPerExtraction.IntValue;
	if (rewardPoints == 0) {
		return;
	}

	int playeridx = event.GetInt("playeridx");

	if (!IsEntityPlayerInGame(playeridx)) {
		return;
	}

	int curCredits = Store_GetClientCredits(playeridx);
	Store_SetClientCredits(playeridx, curCredits + rewardPoints);
}

bool IsEntityPlayerInGame(int entity)
{
	return 0 < entity <= MaxClients && IsClientInGame(entity);
}