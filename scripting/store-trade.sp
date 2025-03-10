#pragma semicolon 1

//////////////////////////////
//		DEFINITIONS			//
//////////////////////////////

#define PLUGIN_NAME "Store - Trade System"
#define PLUGIN_AUTHOR "Zephyrus"
#define PLUGIN_DESCRIPTION "A trade system for the Store plugin."
#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_URL ""

#define STORE_TRADE_MAX_OFFERS 16 // Usermessage may not be able to hold more at a time

//////////////////////////////
//			INCLUDES		//
//////////////////////////////

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <store>
#include <zephstocks>

//////////////////////////////
//			ENUMS			//
//////////////////////////////

//////////////////////////////////
//		GLOBAL VARIABLES		//
//////////////////////////////////

new g_cvarTradeEnabled = -1;
new g_cvarTradeCooldown = -1;
new g_cvarTradeReadyDelay = -1;

new bool:g_bReady[MAXPLAYERS+1] = {false, ...};
new bool:g_bMenuOpen[MAXPLAYERS+1] = {false, ...};

new g_iTraders[MAXPLAYERS+1] = {0, ...};
new g_iOfferedCredits[MAXPLAYERS+1] = {0, ...};
new g_iOffers[MAXPLAYERS+1][STORE_TRADE_MAX_OFFERS];
new g_iTradeCooldown[MAXPLAYERS+1] = {0, ...};

new Handle:g_hReadyTimers[MAXPLAYERS+1] = {INVALID_HANDLE};

//////////////////////////////
//			MODULES			//
//////////////////////////////

//////////////////////////////////
//		PLUGIN DEFINITION		//
//////////////////////////////////

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

//////////////////////////////
//		PLUGIN FORWARDS		//
//////////////////////////////

public OnPluginStart()
{
	IdentifyGame();

	// Supress warnings about unused variables.....
	if(g_bL4D || g_bL4D2 || g_bND) {}

	g_cvarTradeEnabled = RegisterConVar("sm_store_trade_enabled", "1", "Enable/disable the Store trade system", TYPE_INT);
	g_cvarTradeCooldown = RegisterConVar("sm_store_trade_cooldown", "300", "Time in seconds between trade ATTEMPTS", TYPE_INT);
	g_cvarTradeReadyDelay = RegisterConVar("sm_store_trade_ready_delay", "5", "Time in seconds before finishing trade", TYPE_INT);
	AutoExecConfig();

	Store_RegisterMenuHandler("trade", Trade_OnMenu, Trade_OnHandler);

	LoadTranslations("store.phrases");
	LoadTranslations("store-trade.phrases");

	RegConsoleCmd("sm_trade", Command_Trade);
	RegConsoleCmd("sm_offer", Command_Offer);

	CreateTimer(1.0, Timer_ShowPartnerMenu, _, TIMER_REPEAT);
}

public OnAllPluginsLoaded()
{
	g_cvarChatTag = HookConVar("sm_store_chat_tag", TYPE_STRING);
}

//////////////////////////////
//		CLIENT FORWARDS		//
//////////////////////////////

public OnClientConnected(client)
{
	g_iTradeCooldown[client] = 0;
	ResetTrade(client);
}

public OnClientDisconnect(client)
{
	new target = GetClientOfUserId(g_iTraders[client]);
	if(target && IsClientInGame(target))
		ResetTrade(target);
	ResetTrade(client);
}

public Action:Timer_ShowPartnerMenu(Handle:timer, any:data)
{
	LoopIngamePlayers(i)
	{
		if(!g_iTraders[i])
			continue;
		DisplayPartnerMenu(i);
	}
	return Plugin_Continue;
}

//////////////////////////////
//	    	COMMANDS 		//
//////////////////////////////

public Action:Command_Offer(client, args)
{
	if(!g_iTraders[client])
	{
		CPrintToChat(client, "%t", "Trade Not Active");
		return Plugin_Handled;
	}

	decl String:m_szCredits[11];
	GetCmdArg(1, STRING(m_szCredits));

	new m_iCredits = StringToInt(m_szCredits);
	if(m_iCredits < 0 || Store_GetClientCredits(client) < m_iCredits)
	{
		CPrintToChat(client, "%t", "Credit Invalid Amount");
		return Plugin_Handled;
	}

	g_iOfferedCredits[client]=m_iCredits;
	g_bReady[client] = false;
	DisplayTradeMenu(client);

	return Plugin_Handled;
}

public Action:Command_Trade(client, args)
{
	if(g_iTraders[client])
	{
		//CPrintToChat(client, "%t", "Trade Active");
		DisplayTradeMenu(client);
		return Plugin_Handled;
	}

	if(g_iTradeCooldown[client] > GetTime())
	{
		CPrintToChat(client, "%t", "Trade Cooldown");
		return Plugin_Handled;
	}

	new Handle:m_hMenu = CreateMenu(MenuHandler_SelectPlayer);
	SetMenuTitle(m_hMenu, "%t", "Trade Select Player");

	decl String:m_szUserId[11];
	decl String:m_szClientName[64];
	LoopIngamePlayers(i)
	{
		if(i == client)
			continue;
		if(g_iTraders[i])
			continue;
		if(!Store_IsClientLoaded(i))
			continue;

		IntToString(GetClientUserId(i), STRING(m_szUserId));
		GetClientName(i, STRING(m_szClientName));
		AddMenuItem(m_hMenu, m_szUserId, m_szClientName);
	}
	DisplayMenu(m_hMenu, client, 0);

	return Plugin_Handled;
}

//////////////////////////////
//		 STORE TRADE		//
//////////////////////////////

public ResetTrade(client)
{
	new target = GetClientOfUserId(g_iTraders[client]);

	g_bReady[client] = false;
	g_iTraders[client] = 0;
	g_iOfferedCredits[client] = 0; 
	ClearTimer(g_hReadyTimers[client]);
	g_hReadyTimers[target] = INVALID_HANDLE;
	for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
		g_iOffers[client][i] = -1;
	PrintKeyHintText(client, "");
}

public MenuHandler_SelectPlayer(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		decl String:m_szUserId[11];
		GetMenuItem(menu, param2, STRING(m_szUserId));
		new target = GetClientOfUserId(StringToInt(m_szUserId));
		if(!target || !IsClientInGame(target))
		{
			CPrintToChat(client, "%t", "Player left");
			Command_Trade(client, 0);
			return;
		}

		g_iTradeCooldown[client] = GetTime() + g_eCvars[g_cvarTradeCooldown].aCache;
		g_iTraders[client] = GetClientUserId(target);

		CPrintToChat(client, "%t", "Waiting for confirmation");
		new Handle:m_hMenu = CreateMenu(MenuHandler_InitTrade);
		SetMenuTitle(m_hMenu, "%t", "Trade Confirm", client);
		SetMenuExitButton(m_hMenu, false);
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "yes", "%t", "Confirm_Yes");
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "no",  "%t", "Confirm_No");
		DisplayMenu(m_hMenu, target, 30);
	}
}

public MenuHandler_InitTrade(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Cancel && g_iTraders[client] == 0)
	{
		for(new i=1;i<=MaxClients;++i)
		{
			if(g_iTraders[i] == GetClientUserId(client))
			{
				CPrintToChat(i, "%t", "Trade Refused", client);
				g_iTraders[i] = 0;
				return;
			}
		}
	}
	else if (action == MenuAction_Select)
	{
		new target = 0;
		for(new i=1;i<=MaxClients;++i)
		{
			if(g_iTraders[i] == GetClientUserId(client))
			{
				target = i;
				break;
			}
		}

		if(target == 0)
			return;

		if(param2 == 1)
		{
			CPrintToChat(target, "%t", "Trade Refused", client);
			return;
		}

		if(!target)
		{
			CPrintToChat(client, "%t", "Player left");
			return;
		}

		g_iTraders[client] = GetClientUserId(target);

		g_bReady[client]=false;
		g_bReady[target]=false;

		DisplayTradeMenu(client);
		DisplayTradeMenu(target);
	}
}

public DisplayTradeMenu(client)
{
	new target = GetClientOfUserId(g_iTraders[client]);
	if(!target || !IsClientInGame(target))
		return;

	g_bMenuOpen[client] = true;

	new Handle:m_hMenu = CreateMenu(MenuHandler_Trade);
	SetMenuTitle(m_hMenu, "%t", "Trade Title", target, g_iOfferedCredits[client]);
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "ready", "%t", "Ready", (g_bReady[client]?"X":" "));
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "cancel", "%t", "Cancel");
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "offer", "%t\n\n\n", "Offer");

	Store_Item m_eItem;
	Type_Handler m_eHandler;
	decl String:m_szItemID[11];

	for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
	{
		if(g_iOffers[client][i] == -1)
			continue;
		Store_GetItem(g_iOffers[client][i], m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);

		IntToString(g_iOffers[client][i], STRING(m_szItemID));
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, m_szItemID, "%s %s", m_eItem.szName, m_eHandler.szType);
	}

	DisplayMenu(m_hMenu, client, 0);
}

public DisplayPartnerMenu(client)
{
	new target = GetClientOfUserId(g_iTraders[client]);
	if(!target || !IsClientInGame(target))
		return;

	if(g_iTraders[target] == 0)
		return;

	new bool:m_bRedisplay = false;
	new bool:m_bRedisplayTarget = false;
	if(g_iOfferedCredits[client] > Store_GetClientCredits(client))
	{
		g_iOfferedCredits[client] = 0;
		g_bReady[client] = false;
		m_bRedisplay = true;
	}

	if(!g_bMenuOpen[client])
	{
		CPrintToChat(client, "%t", "Trade Menu");
	}

	decl String:m_szMessage[256];
	new idx = 0;
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", (g_bReady[target]?"Partner Ready":"Partner Not Ready"));
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", "Partner Credit Offer", g_iOfferedCredits[target]);
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", "Partner Item Offer");

	Store_Item m_eItem;
	Type_Handler m_eHandler;

	new index = 0;
	for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
	{
		if(g_iOffers[target][i] == -1)
			continue;
		if(!Store_HasClientItem(target, g_iOffers[target][i]))
		{
			g_iOffers[target][i] = -1;
			g_bReady[target] = false;
			m_bRedisplayTarget = true;
			continue;
		}
		Store_GetItem(g_iOffers[target][i], m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%d. %s %s\n", ++index, m_eItem.szName, m_eHandler.szType);
	}

	if(m_bRedisplay)
		DisplayTradeMenu(client);
	if(m_bRedisplayTarget)
		DisplayTradeMenu(target);

	PrintKeyHintText(client, m_szMessage);
}

public MenuHandler_Trade(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
	{
		if(0<client<=MaxClients)
			g_bMenuOpen[client] = false;
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			g_bReady[client] = !g_bReady[client];
			DisplayTradeMenu(client);

			new target = GetClientOfUserId(g_iTraders[client]);

			if(g_bReady[client] && g_bReady[target])
			{
				g_hReadyTimers[client] = CreateTimer(0.0, Timer_ReadyTimer, g_eCvars[g_cvarTradeReadyDelay].aCache);
				g_hReadyTimers[target] = g_hReadyTimers[client];
			}
			else if(g_hReadyTimers[client] != INVALID_HANDLE)
			{
				ClearTimer(g_hReadyTimers[client]);
				g_hReadyTimers[client] = INVALID_HANDLE;
				g_hReadyTimers[target] = INVALID_HANDLE;
			}
		}
		else if(param2 == 1)
		{
			if(Store_ShouldConfirm())
			{
				new Handle:m_hMenu = CreateMenu(MenuHandler_Cancel);
				SetMenuTitle(m_hMenu, "%t", "Trade Confirm Cancel", client);
				SetMenuExitButton(m_hMenu, false);
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "yes", "%t", "Confirm_Yes");
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "no",  "%t", "Confirm_No");
				DisplayMenu(m_hMenu, client, 0);
			}
			else
			{
				MenuHandler_Cancel(INVALID_HANDLE, MenuAction_Select, client, 0);
			}
		} else if(param2 == 2)
		{
			FakeClientCommandEx(client, "sm_inventory");
		}
		else
		{
			new String:m_szItemId[11];
			GetMenuItem(menu, param2, STRING(m_szItemId));
			new m_iItemID = StringToInt(m_szItemId);

			for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
			{
				if(g_iOffers[client][i] == m_iItemID)
				{
					g_iOffers[client][i] = -1;
					break;
				}
			}
			DisplayTradeMenu(client);
		}
	}
}

public Action:Timer_ReadyTimer(Handle:timer, any:data)
{
	new client = 0;
	new target = 0;
	for(new i=1;i<=MaxClients;++i)
		if(g_hReadyTimers[i] == timer)
		{
			if(data > 0)
				CPrintToChat(i, "%t", "Ready Timer", data);
			if(client == 0)
				client = i;
			else
				target = i;
		}

	if(data != 0)
	{
		g_hReadyTimers[client] = CreateTimer(1.0, Timer_ReadyTimer, data-1);
		g_hReadyTimers[target] = g_hReadyTimers[client];
	}
	else
	{
		for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
		{
			if(g_iOffers[client][i] != -1)
				Store_GiveClientItem(client, target, g_iOffers[client][i]);
			if(g_iOffers[target][i] != -1)
				Store_GiveClientItem(target, client, g_iOffers[target][i]);
		}
		Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iOfferedCredits[target]-g_iOfferedCredits[client]);
		Store_SetClientCredits(target, Store_GetClientCredits(target)+g_iOfferedCredits[client]-g_iOfferedCredits[target]);

		ResetTrade(target);
		ResetTrade(client);

		CPrintToChat(target, "%t", "Trade Successful");
		CPrintToChat(client, "%t", "Trade Successful");

		if(g_bMenuOpen[client] == true)
			CancelClientMenu(client);
		if(g_bMenuOpen[target] == true)
			CancelClientMenu(target);
	}

	return Plugin_Continue;
}

public MenuHandler_Cancel(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Cancel && g_iTraders[client] == 0)
	{
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			ResetTrade(client);
			new target = GetClientOfUserId(g_iTraders[client]);
			if(!target || !IsClientInGame(target))
				return;
			ResetTrade(target);
			CPrintToChat(target, "%t", "Trade Cancelled");
		}
		else
			DisplayTradeMenu(client);
	}
}

//////////////////////////////
//		STORE CALLBACKS		//
//////////////////////////////

public Trade_OnMenu(&Handle:menu, client, itemid)
{
	new target = Store_GetClientTarget(client);
	if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid) && g_iTraders[client])
	{
		RemoveAllMenuItems(menu);
		AddMenuItemEx(menu, ITEMDRAW_DEFAULT, "add_to_offer", "%t", "Offer item");
	}
	else if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid) && !g_iTraders[client])
	{
		AddMenuItemEx(menu, ITEMDRAW_DEFAULT, "trade_this_item", "%t", "Trade item");
	}
}

public bool:Trade_OnHandler(client, String:info[], itemid)
{
	if(!g_eCvars[g_cvarTradeEnabled].aCache)
		return false;

	if(strcmp(info, "add_to_offer")==0)
	{
		Store_Item m_eItem;
		Type_Handler m_eHandler;
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		char m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Offer_Item", m_eItem.szName, m_eHandler.szType);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Trade_MenuHandler, itemid);
		else
			Trade_MenuHandler(INVALID_HANDLE, MenuAction_Select, client, itemid);
	} else if(strcmp(info, "trade_this_item")==0)
	{
		Store_Item m_eItem;
		Type_Handler m_eHandler;
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		decl String:m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Trade_Item", m_eItem.szName, m_eHandler.szType);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Trade_ConfirmTradeHandler, itemid);
		else
			Trade_ConfirmTradeHandler(INVALID_HANDLE, MenuAction_Select, client, itemid);
	}
	return false;
}

public Trade_MenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			new target = Store_GetClientTarget(client);
			for(new i=0;i<STORE_TRADE_MAX_OFFERS;++i)
			{
				if(g_iOffers[target][i] == -1)
				{
					g_iOffers[target][i] = param2;
					break;
				}
			}
			g_bReady[target] = false;
			DisplayTradeMenu(target);
		}
	}
}

public Trade_ConfirmTradeHandler(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			g_iOffers[client][0] = param2;
			Command_Trade(client, 0);
		}
	}
}