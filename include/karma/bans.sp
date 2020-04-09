#define MAX_ID_LENGTH 3
#define MAX_REASON_LENGTH 255
#define BANS_URL "l4d.dev/bans"

TopMenu g_bans_main_menu;

ArrayList AdtBanReasons;
ArrayList AdtUnbanReasons;

// Definición de current ban - INTEGER
#define CURRENT_BAN_INDEX_TARGET 0
#define CURRENT_BAN_INDEX_USERID 1
#define CURRENT_BAN_INDEX_REASON 2

// Definición de current ban - STRINGS
#define CURRENT_BAN_INDEX_STEAMID 0
#define CURRENT_BAN_INDEX_CLIENTIP 1

char sCurrentBan[MAXPLAYERS + 1][2][32];
int iCurrentBan[MAXPLAYERS + 1][3];

char sCurrentUnbanName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char iCurrentUnbanId[MAXPLAYERS + 1];

void vBansRegister() {
	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");
	
	RegAdminCmd("sm_ban", CommandBan, ADMFLAG_GENERIC, "sm_ban <#userid|name>");
	RegAdminCmd("sm_unban", CommandUnban, ADMFLAG_GENERIC, "sm_unban <steamid>");
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
		OnAdminMenuReady(topmenu);
	}
	
	AdtBanReasons = new ArrayList(MAX_REASON_LENGTH);
	AdtUnbanReasons = new ArrayList(MAX_REASON_LENGTH);
	
	g_database.Query(onBanFetchReasons, "SELECT `id`, `description` FROM `ks_bans_reasons`;", AdtBanReasons, DBPrio_High);
	g_database.Query(onBanFetchReasons, "SELECT `id`, `description` FROM `ks_unbans_reasons`;", AdtUnbanReasons, DBPrio_High);
}

public void onBanFetchReasons(Database db, DBResultSet results, const char[] error, ArrayList global) {
	if (db == null || results == null) {
		LogError("Query failed! %s", error);
		SetFailState("(onBanFetchReasons) Something is wrong: %s", error);
	} else if (results.RowCount == 0) {
		LogError("Please add ban reasons in DB");
		SetFailState("Please add ban reasons in DB");
	} else {
		while (results.FetchRow()) {
			char reason_id[MAX_ID_LENGTH];
			results.FetchString(0, reason_id, MAX_ID_LENGTH);
			char reason_description[MAX_REASON_LENGTH];
			results.FetchString(1, reason_description, MAX_REASON_LENGTH);
			ArrayList pack_reason = new ArrayList(MAX_REASON_LENGTH);
			pack_reason.PushString(reason_id);
			pack_reason.PushString(reason_description);
			global.Push(pack_reason);
		}
	}
	while (results.FetchMoreResults()) {}
}

// Funcion para cuando un jugador se conecta al servidor...
public void OnClientAuthorized(int client, const char[] auth) {
	if (!client)return;
	if (IsFakeClient(client))return;
	// Creando variables necesarias
	char steam_id[32], sql_command[255], client_ip[16];
	// Obteniendo el steam id del jugador
	GetClientIP(client, client_ip, 16);
	GetClientAuthId(client, AuthId_Steam2, steam_id, 32);
	// Formateando datos de actualizacion
	Format(sql_command, 255, "CALL KS_BAN_ACTIVED('%s', '%s');", steam_id, client_ip);
	g_database.Query(onPlayerFetch, sql_command, client, DBPrio_High);
}

public void onPlayerFetch(Database db, DBResultSet results, const char[] error, int client) {
	if (db == null || results == null) {
		LogError("Query failed! %s", error);
		return;
	} else if (results.RowCount > 0) {
		while (results.FetchRow()) {
			int ban_actived = results.FetchInt(0);
			if (ban_actived == 1) {
				char reason[255];
				results.FetchString(1, reason, 255);
				KickClient(client, "You're banned, reason: %s\nplease visit: %s", reason, BANS_URL);
			}
		}
	}
	while (results.FetchMoreResults()) {}
}

public Action CommandUnban(int client, int args) {
	FetchBanList(client);
	return Plugin_Handled;
}

void FetchBanList(int client) {
	PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 Wait a moment, fetching your ban list");
	char client_steam_id[32], sql_command[128];
	GetClientAuthId(client, AuthId_Steam2, client_steam_id, 32);
	Format(sql_command, sizeof(sql_command), "CALL KS_BANS_GET('%s');", client_steam_id);
	g_database.Query(onBanListFetch, sql_command, client);
}

public void onBanListFetch(Database db, DBResultSet results, const char[] error, int client) {
	if (db == null || results == null) {
		LogError("Query failed! %s", error);
		return;
	} else if (results.RowCount == 0) {
		PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 You don't have bans registered");
	} else if(results.RowCount > 0) {
		Menu menu = new Menu(MenuHandler_UnbanSelected);
		menu.SetTitle("Ban list");
		menu.ExitBackButton = true;
		while (results.FetchRow()) {
			char player_name[MAX_NAME_LENGTH], ban_id[20];
			results.FetchString(0, sCurrentUnbanName[client], MAX_NAME_LENGTH);
			results.FetchString(0, player_name, MAX_NAME_LENGTH);
			results.FetchString(1, ban_id, 20);
			menu.AddItem(ban_id, player_name);
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
	while (results.FetchMoreResults()) {}
}

public int MenuHandler_UnbanSelected(Menu menu, MenuAction action, int client, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu) {
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		char data[255];
		menu.GetItem(param2, data, 255);
		int ban_id = StringToInt(data);
		iCurrentUnbanId[client] = ban_id;
		vDisplayBanReasonsMenu(client, MenuHandler_UnbanReason, "Unban reason", AdtUnbanReasons);
	}
}

public int MenuHandler_UnbanReason(Menu menu, MenuAction action, int client, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu) {
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		char data[255];
		menu.GetItem(param2, data, 255);
		int reason_id = StringToInt(data);
		Unban(client, iCurrentUnbanId[client], reason_id);
	}
}

public Action CommandBan(int client, int args) {
	if (args == 0) {
		DisplayBanTargetMenu(client);
		return Plugin_Handled;
	}
	
	char target_arg[64];
	GetCmdArg(1, target_arg, 64);
	ReplaceString(target_arg, sizeof(target_arg), "\"", "");
	int target = FindTarget(client, target_arg, true);
	if (target == -1) {
		PrintToChat(client, "\x04[\x05BAN\x04]\x01 Player %s not found", target_arg);
		return Plugin_Handled;
	}
	
	StoreBanTarget(client, target);
	
	vDisplayBanReasonsMenu(client, MenuHandler_BanReasonList, "Ban reason", AdtBanReasons);
	return Plugin_Handled;
}

void DisplayBanTargetMenu(int client) {
	Menu menu = new Menu(MenuHandler_BanPlayerList);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int client, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu) {
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		char info[32], name[32];
		int userid, target;
		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);
		if ((target = GetClientOfUserId(userid)) == 0) {
			PrintToChat(client, "\x04[\x05BAN\x04]\x01 Player no longer available");
		} else if (!CanUserTarget(client, target)) {
			PrintToChat(client, "\x04[\x05BAN\x04]\x01 Unable to target");
		} else {
			StoreBanTarget(client, target);
			vDisplayBanReasonsMenu(client, MenuHandler_BanReasonList, "Ban reason", AdtBanReasons);
		}
	}
}

void vDisplayBanReasonsMenu(int client, MenuHandler handler, const char[] title, ArrayList reasons) {
	Menu menu = new Menu(handler);
	menu.SetTitle("%s %N", title, GetBanTarget(client));
	menu.ExitBackButton = true;
	for (int i = 0, length = reasons.Length; i < length; i++) {
		ArrayList ban_reason = reasons.Get(i);
		char reason_id[MAX_ID_LENGTH];
		char reason_description[MAX_REASON_LENGTH];
		ban_reason.GetString(0, reason_id, MAX_ID_LENGTH);
		ban_reason.GetString(1, reason_description, MAX_REASON_LENGTH);
		menu.AddItem(reason_id, reason_description);
	}
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BanReasonList(Menu menu, MenuAction action, int client, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu) {
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		char char_reason_id[64];
		menu.GetItem(param2, char_reason_id, sizeof(char_reason_id));
		int reason_id = StringToInt(char_reason_id);
		SetBanReason(client, reason_id);
		AddBan(client);
	}
}

stock void StoreBanTarget(int client, int target) {
	SetBanTarget(client, target);
	SetBanUserId(client, target);
	SetBanSteamId(client, target);
	SetBanClientIp(client, target);
}

stock void SetBanSteamId(int client, int target) {
	char target_steam_id[32];
	GetClientAuthId(target, AuthId_Steam2, target_steam_id, 32);
	Format(sCurrentBan[client][CURRENT_BAN_INDEX_STEAMID], 32, "%s", target_steam_id);
}

stock void GetBanSteamId(int client, char[] steam_id, int size_of) {
	Format(steam_id, size_of, "%s", sCurrentBan[client][CURRENT_BAN_INDEX_STEAMID]);
}

stock void SetBanClientIp(int client, int target) {
	char target_ip[16];
	GetClientIP(target, target_ip, 16);
	Format(sCurrentBan[client][CURRENT_BAN_INDEX_CLIENTIP], 16, "%s", target_ip);
}

stock void GetBanClientIp(int client, char[] target_ip, int size_of) {
	Format(target_ip, size_of, "%s", sCurrentBan[client][CURRENT_BAN_INDEX_CLIENTIP]);
}

stock void SetBanTarget(int client, int target) {
	iCurrentBan[client][CURRENT_BAN_INDEX_TARGET] = target;
}

stock int GetBanTarget(int client) {
	return iCurrentBan[client][CURRENT_BAN_INDEX_TARGET];
}

stock void SetBanUserId(int client, int userid) {
	iCurrentBan[client][CURRENT_BAN_INDEX_USERID] = userid;
}

stock int GetBanUserId(int client) {
	return iCurrentBan[client][CURRENT_BAN_INDEX_USERID];
}

stock void SetBanReason(int client, int reason_id) {
	iCurrentBan[client][CURRENT_BAN_INDEX_REASON] = reason_id;
}

stock int GetBanReason(int client) {
	return iCurrentBan[client][CURRENT_BAN_INDEX_REASON];
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	
	/* Block us from being called twice */
	if (topmenu == g_bans_main_menu) return;
	
	/* Save the Handle */
	g_bans_main_menu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = g_bans_main_menu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT) {
		g_bans_main_menu.AddItem("sm_ban", AdminMenu_Ban, player_commands, "sm_ban", ADMFLAG_GENERIC);
	}
}

public void AdminMenu_Ban(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	if (action == TopMenuAction_DisplayOption) {
		Format(buffer, maxlength, "Ban player", param);
	} else if (action == TopMenuAction_SelectOption) {
		DisplayBanTargetMenu(param);
	}
}

void AddBan(int client) {
	char target_steam_id[32], target_ip[16];
	GetBanSteamId(client, target_steam_id, 32);
	GetBanClientIp(client, target_ip, 16);
	int reason_id = GetBanReason(client);
	char sql_command[128];
	char client_steam_id[32];
	GetClientAuthId(client, AuthId_Steam2, client_steam_id, 32);
	Format(sql_command, sizeof(sql_command), "CALL KS_BAN_ADD('%s', '%s', '%s', %d);", target_steam_id, target_ip, client_steam_id, reason_id);
	g_database.Query(onBanStored, sql_command, client);
}

public void onBanStored(Database db, DBResultSet results, const char[] error, int client) {
	int target = GetBanTarget(client);
	if (StrEqual(error, "")) {
		int reason_id = GetBanReason(client);
		char reason_description[MAX_REASON_LENGTH];
		ArrayList ban_reason = AdtBanReasons.Get(reason_id);
		ban_reason.GetString(1, reason_description, MAX_REASON_LENGTH);
		PrintToChat(client, "\x04[\x05BAN\x04]\x01 Ban for \x03%N\x01(reason: \x03%s\x01) has been added successfully", target, reason_description);
		KickClient(target, "You have been banned because %s,\n please visit: %s", reason_description, BANS_URL);
	} else {
		PrintToChat(client, "\x04[\x05BAN\x04]\x01 Ban for \x03%N\x01 couldn't be added because %s", target, error);
	}
}

stock void Unban(int client, int ban_id, int reason_id) {
	char sql_command[128], client_steam_id[32];
	GetClientAuthId(client, AuthId_Steam2, client_steam_id, 32);
	Format(sql_command, 128, "CALL KS_BAN_REMOVE('%s', %d, %d);", client_steam_id, ban_id, reason_id);
	g_database.Query(onUnban, sql_command, client);
}

public void onUnban(Database db, DBResultSet results, const char[] error, int client) {
	if (StrEqual(error, "")) {
		PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 Ban for \x03%s\x01 has been removed successfully", sCurrentUnbanName[client]);
	} else {
		PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 Ban for \x03%s\x01 couldn't be removed because %s", sCurrentUnbanName[client], error);
	}
}