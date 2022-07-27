#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#include <chat-processor>
#endif

#define MAX_NAMETAG_LENGTH 128
#define MAX_COLORTAG_LENGTH 32

ArrayList g_NameTags;
ArrayList g_NameColors;
ArrayList g_MessageColors;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public SCPSupport_OnPluginStart()
#endif
{	
	if (!LibraryExists("chat-processor"))
	{
		LogError("Chat Processor isn't installed or failed to load. Chat goodies will be disabled.");
		return;
	}

	g_NameTags = new ArrayList(ByteCountToCells(MAX_NAMETAG_LENGTH));
	g_NameColors = new ArrayList(ByteCountToCells(MAX_COLORTAG_LENGTH));
	g_MessageColors = new ArrayList(ByteCountToCells(MAX_COLORTAG_LENGTH));

	Store_RegisterHandler("namecolor", "color", SCPSupport_OnMapStart, SCPSupport_Reset, NameColors_Config, NameColors_Equip, NameColors_Remove, true);
	Store_RegisterHandler("nametag", "tag", SCPSupport_OnMapStart, SCPSupport_Reset, NameTags_Config, NameTags_Equip, NameTags_Remove, true);
	Store_RegisterHandler("msgcolor", "color", SCPSupport_OnMapStart, SCPSupport_Reset, MsgColors_Config, MsgColors_Equip, MsgColors_Remove, true);
}

public SCPSupport_OnMapStart()
{
}

public SCPSupport_Reset()
{
	g_NameTags.Clear();
	g_NameColors.Clear();
	g_MessageColors.Clear();
}

bool NameTags_Config(KeyValues& kv, int itemid)
{
	Store_SetDataIndex(itemid, g_NameTags.Length);

	char nameTag[MAX_NAMETAG_LENGTH];
	KvGetString(kv, "tag", nameTag, sizeof(nameTag));
	g_NameTags.PushString(nameTag);
	
	return true;
}

bool NameColors_Config(KeyValues& kv, int itemid)
{
	Store_SetDataIndex(itemid, g_NameColors.Length);

	char nameColor[MAX_COLORTAG_LENGTH];
	KvGetString(kv, "color", nameColor, sizeof(nameColor));

	g_NameColors.PushString(nameColor);

	return true;
}

bool MsgColors_Config(KeyValues& kv, int itemid)
{
	Store_SetDataIndex(itemid, g_MessageColors.Length);

	char msgColor[MAX_COLORTAG_LENGTH];
	kv.GetString("color", msgColor, sizeof(msgColor));
	
	g_MessageColors.PushString(msgColor);
	return true;
}

void NameTags_Equip(int client, int id)
{
	int equipped = Store_GetEquippedItem(client, "nametag");
	if (0 <= equipped < g_NameTags.Length) {
		Store_UnequipItem(client, equipped);
	}

	int index = Store_GetDataIndex(id);

	char nameTag[MAX_NAMETAG_LENGTH];
	g_NameTags.GetString(index, nameTag, sizeof(nameTag));

	ChatProcessor_AddClientTag(client, nameTag);
}

void NameTags_Remove(int client, int id)
{
	int index = Store_GetDataIndex(id);

	char nameTag[MAX_NAMETAG_LENGTH];
	g_NameTags.GetString(index, nameTag, sizeof(nameTag));

	ChatProcessor_RemoveClientTag(client, nameTag);
}

void NameColors_Equip(int client, int id)
{
	int equipped = Store_GetEquippedItem(client, "namecolor");
	if (0 <= equipped < g_NameColors.Length) {
		Store_UnequipItem(client, equipped);
	}

	int index = Store_GetDataIndex(id);

	char nameColor[MAX_COLORTAG_LENGTH];
	g_NameColors.GetString(index, nameColor, sizeof(nameColor));

	ChatProcessor_SetNameColor(client, nameColor);
}

void NameColors_Remove(int client, int id)
{
	ChatProcessor_SetNameColor(client, "");
}

void MsgColors_Equip(int client, int id)
{
	int equipped = Store_GetEquippedItem(client, "msgcolor");
	if (0 <= equipped < g_MessageColors.Length) {
		Store_UnequipItem(client, equipped);
	}

	int index = Store_GetDataIndex(id);

	char msgColor[MAX_COLORTAG_LENGTH];
	g_MessageColors.GetString(index, msgColor, sizeof(msgColor));

	ChatProcessor_SetChatColor(client, msgColor);

}

void MsgColors_Remove(int client, int id)
{
	ChatProcessor_SetChatColor(client, "");
}