#define MAX_ID_LENGTH 3
#define MAX_REASON_LENGTH 255
#define BANS_URL "l4d.dev/bans"

TopMenu g_bans_main_menu;

ArrayList AdtBanReasons;
ArrayList AdtUnbanReasons;

// Definición de current ban
#define CURRENT_BAN_INDEX_TARGET 0
#define CURRENT_BAN_INDEX_USERID 1
#define CURRENT_BAN_INDEX_REASON 2
#define CURRENT_BAN_INDEX_STEAMID 3

int g_current_ban[MAXPLAYERS + 1][4];

// fine
void vBansRegister()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");
	
	RegAdminCmd("sm_ban", CommandBan, ADMFLAG_GENERIC, "sm_ban <#userid|name> <reason>");
	// RegAdminCmd("sm_unban", CommandUnban, ADMFLAG_GENERIC, "sm_unban <steamid> <reason>");
	
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

// fine
public void onBanFetchReasons(Database db, DBResultSet results, const char[] error, ArrayList global)
{
	if (db == null || results == null) {
		LogError("Query failed! %s", error);
		SetFailState("(onBanFetchReasons) Something is wrong: %s", error);
	} else if (results.RowCount == 0) {
		LogError("Please add ban reasons in DB");
		SetFailState("Please add ban reasons in DB");
	}
	do {
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
	} while (results.FetchMoreResults());
}

// Funcion para cuando un jugador se conecta al servidor...
public void OnClientAuthorized(int client, const char[] auth) {
	if (!client)return;
	if (!IsFakeClient(client)) return;
	// Creando variables necesarias
	char steam_id[32], sql_command[255], client_ip[16];
	// Obteniendo el steam id del jugador
	GetClientIP(client, client_ip, 16);
	GetClientAuthId(client, AuthId_Steam2, steam_id, 32);
	// Formateando datos de actualizacion
	Format(sql_command, 255, "CALL KS_BAN_ACTIVED('%s', '%s');", steam_id, client_ip);
	g_database.Query(onPlayerFetch, sql_command, client, DBPrio_High);
}

// fine
public void onPlayerFetch(Database db, DBResultSet results, const char[] error, int client) {
	if (results == null) {
		LogError("Query failed! %s", error);
		SetFailState("(onPlayerFetch) Something is wrong: %s", error);
	} else if (results.RowCount > 0) {
		do {
			while (results.FetchRow()) {
				int ban_actived = results.FetchInt(0);
				if(ban_actived == 1) {
					char reason[255];
					results.FetchString(1, reason, 255);
					KickClient(client, "You're banned\n, reason: %s\nplease visit: %s", reason, BANS_URL);
					break;
				}
			}
		} while (results.FetchMoreResults());
	}
}

// fine
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
		ReplyToCommand(client, "[BAN] Player %s not found", target_arg);
		return Plugin_Handled;
	}
	
	SetBanTarget(client, target);
	SetBanUserId(client, GetClientUserId(target));
	
	// DisplayBanReasonMenu(client);
	vDisplayBanReasonsMenu(client, MenuHandler_BanReasonList, "Ban reason", AdtBanReasons);
	return Plugin_Handled;
}

// fine
void DisplayBanTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanPlayerList);
	
	char title[100];
	Format(title, sizeof(title), "%T:", "Ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

// fine
public int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu)
		{
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);
		
		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(client, "[BAN] Player no longer available");
		}
		else if (!CanUserTarget(client, target))
		{
			PrintToChat(client, "[BAN] Unable to target");
		}
		else
		{
			SetBanTarget(client, target);
			SetBanUserId(client, userid);
			vDisplayBanReasonsMenu(client, MenuHandler_BanReasonList, "Ban reason", AdtBanReasons);
		}
	}
}

// fine
void vDisplayBanReasonsMenu(int client, MenuHandler handler, char[] title, ArrayList reasons) {
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
	// TODO: valid action function
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_bans_main_menu) {
			g_bans_main_menu.Display(client, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		// TODO: REFORMATEAR
		char char_reason_id[64];
		menu.GetItem(param2, char_reason_id, sizeof(char_reason_id));
		int reason_id = StringToInt(char_reason_id);
		SetBanReason(client, reason_id);
		AddBan(client);
	}
}

stock void SetBanTarget(int client, int target) {
	g_current_ban[client][CURRENT_BAN_INDEX_TARGET] = target;
}

stock int GetBanTarget(int client) {
	return g_current_ban[client][CURRENT_BAN_INDEX_TARGET];
}

stock void SetBanUserId(int client, int userid) {
	g_current_ban[client][CURRENT_BAN_INDEX_USERID] = userid;
}

stock int GetBanUserId(int client) {
	return g_current_ban[client][CURRENT_BAN_INDEX_USERID];
}

stock void SetBanReason(int client, int reason_id) {
	g_current_ban[client][CURRENT_BAN_INDEX_REASON] = reason_id;
}

stock int GetBanReason(int client) {
	return g_current_ban[client][CURRENT_BAN_INDEX_REASON];
}

// fine
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	
	/* Block us from being called twice */
	if (topmenu == g_bans_main_menu)
	{
		return;
	}
	
	/* Save the Handle */
	g_bans_main_menu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = g_bans_main_menu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		g_bans_main_menu.AddItem("sm_ban", AdminMenu_Ban, player_commands, "sm_ban", ADMFLAG_GENERIC);
	}
}

// fine
public void AdminMenu_Ban(TopMenu topmenu, 
	TopMenuAction action, 
	TopMenuObject object_id, 
	int param, 
	char[] buffer, 
	int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Ban player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayBanTargetMenu(param);
	}
}

public void AddBan(int client)
{
	PrintToChat(client, "User: %N\nReason: %d\nUser Id: %d", GetBanTarget(client), GetBanReason(client), GetBanUserId(client));
}

// void AddBan(int client, constchar[] target_authid, int time, const char[] reason, char[] buffer, int buffer_length) {
// 	char banned_name_by[MAX_NAME_LENGTH * 2] = "Vote";
// 	char client_authid[64] = "server";
// 	if (client) {
// 		GetClientName(client, banned_name_by, sizeof(banned_name_by));
// 		SQL_EscapeString(g_database, banned_name_by, banned_name_by, sizeof(banned_name_by));
// 		GetClientAuthId(client, AuthId_Steam2, client_authid, sizeof(client_authid));

// 		g_database.Query()
// 		if (StrEqual(client_authid, target_authid)) {
// 			Format(buffer, buffer_length, "%s", "[BAN] You can't ban your self");
// 		}
// 	}
// 	int BanTime = 0;
// 	if (!time) {
// 		BanTime = 0;
// 	} else {
// 		BanTime = GetTime() + time * 3600;
// 	}
// 	char reason_fixed[128];
// 	SQL_EscapeString(g_database, reason, reason_fixed, sizeof(reason_fixed));
// 	char sql_command[512];
// 	Format(sql_command, sizeof(sql_command), "INSERT IGNORE INTO mb_bans (player_name, steam_id, admin_steamid, ban_length, ban_time, ban_reason, banned_by, timestamp) VALUES ('%s', '%s', '%s', '%d', '%d', '%s', '%s', CURRENT_TIMESTAMP)", "unknown", target_authid, client_authid, time, BanTime, reason_fixed, banned_name_by);
// 	DBResultSet player_ban;
// 	if ((player_ban = SQL_Query(g_database, sql_command)) != null) {
// 		if (player_ban.AffectedRows) {
// 			Format(buffer, buffer_length, "%s%d%s", "[BAN] The player was successfully banned by ", time, " hours");
// 		} else {
// 			Format(buffer, buffer_length, "%s", "[BAN] The player it's already banned");
// 		}
// 		player_ban.FetchMoreResults();
// 	} else {
// 		Format(buffer, buffer_length, "%s", "[BAN] Something went wrong, the player was not banned");
// 	}
// }

// void PrepareBan(int client, int target, int reason, char[] buffer, int buffer_length) {
// 	if (client == target) {
// 		Format(buffer, buffer_length, "%s", "[BAN] You can't ban your self");
// 		return;
// 	}
// 	int originalTarget = GetClientOfUserId(g_ban_target_user_id[client]);
// 	if (originalTarget != target) {
// 		Format(buffer, buffer_length, "%s", "[BAN] Player no longer available");
// 		return;
// 	}
// 	int BanTime = 0;
// 	if (!time) {
// 		BanTime = 0;
// 	} else {
// 		BanTime = GetTime() + time * 3600;
// 	}
// 	char target_authid[64], 
// 	target_name[32], 
// 	target_ip[16];
// 	GetClientAuthId(target, AuthId_Steam2, target_authid, 64);
// 	GetClientIP(target, target_ip, 16);
// 	GetClientName(target, target_name, 32);
// 	char target_name_fixed[MAX_NAME_LENGTH * 2];
// 	SQL_EscapeString(g_database, target_name, target_name_fixed, sizeof(target_name_fixed));

// 	char reason_fixed[128];
// 	SQL_EscapeString(g_database, reason, reason_fixed, sizeof(reason_fixed));

// 	char banned_name_by[MAX_NAME_LENGTH * 2] = "Vote";
// 	char client_authid[64] = "server";
// 	if (client) {
// 		GetClientName(client, banned_name_by, sizeof(banned_name_by));
// 		SQL_EscapeString(g_database, banned_name_by, banned_name_by, sizeof(banned_name_by));
// 		GetClientAuthId(client, AuthId_Steam2, client_authid, 64);
// 	}

// 	char sql_command[512];
// 	Format(sql_command, sizeof(sql_command), "INSERT IGNORE INTO mb_bans (player_name, steam_id, ban_length, ban_time, ban_reason, banned_by, ip, admin_steamid, timestamp) VALUES ('%s', '%s', '%d', '%d', '%s', '%s', '%s', '%s', CURRENT_TIMESTAMP);", target_name_fixed, target_authid, time, BanTime, reason_fixed, banned_name_by, target_ip, client_authid);

// 	DBResultSet insertResult;

// 	KickClient(target, "You have been banned.\nVisit: %s for more info", BANS_URL);
// 	if ((insertResult = SQL_Query(g_database, sql_command)) != null) {
// 		if (insertResult.AffectedRows) {
// 			Format(buffer, buffer_length, "%s%d%s", "[BAN] The player was successfully banned by ", time, " hours");
// 		} else {
// 			Format(buffer, buffer_length, "%s", "[BAN] The player it's already banned");
// 		}
// 		insertResult.FetchMoreResults();
// 	} else {
// 		Format(buffer, buffer_length, "%s", "[BAN] Something went wrong, the player was not banned");
// 	}
// }



// public Action Command_AddBan(int client, int args)
// {
//   if (args < 2)
//   {
//     ReplyToCommand(client, "[BAN] Usage: sm_addban <time> <steamid> [reason]");
//     return Plugin_Handled;
//   }

//   char arg_string[256];
//   char time[50];
//   char authid[50];

//   GetCmdArgString(arg_string, sizeof(arg_string));

//   int len, total_len;

//   /* Get time */
//   if ((len = BreakString(arg_string, time, sizeof(time))) == -1)
//   {
//     ReplyToCommand(client, "[BAN] Usage: sm_addban <time> <steamid> [reason]");
//     return Plugin_Handled;
//   }	
//   total_len += len;

//   /* Get steamid */
//   if ((len = BreakString(arg_string[total_len], authid, sizeof(authid))) != -1) {
//     total_len += len;
//   } else {
//     total_len = 0;
//     arg_string[0] = '\0';
//   }
//   if (strncmp(authid, "STEAM_", 6) != 0 || authid[7] != ':') {
//     ReplyToCommand(client, "[BAN] Invalid SteamID specified: %s", authid);
//     return Plugin_Handled;
//   }

//   char buffer[255] = "Something its wrong";
//   int hours = StringToInt(time);
//   AddBan(client, authid, hours, arg_string[total_len], buffer, 255);
//   ReplyToCommand(client, "%s", buffer);

//   return Plugin_Handled;
// } 

// public Action CommandUnban(int client, int args) {
//   if (args < 2) {
//     ReplyToCommand(client, "[BAN] Usage: sm_unban <steamid> <reason>");
//     return Plugin_Handled;
//   }

//   char client_authid[MAX_NAME_LENGTH] = "server";
//   if(client) {
//     GetClientAuthId(client, AuthId_Steam2, client_authid, sizeof(client_authid));
//   }

//   char target_authid[64];
//   GetCmdArg(1, target_authid, 64);
//   ReplaceString(target_authid, sizeof(target_authid), "\"", "");
//   char unbanned_reason[128] = "Without reason";
//   GetCmdArg(2, unbanned_reason, 128);
//   ReplaceString(unbanned_reason, sizeof(unbanned_reason), "\"", "");
//   char sql_command[128];
//   // Formateando datos de actualizacion
//   // Format(sql_command, 128, "SELECT `steam_id`, `ban_time`, `admin_steamid` FROM `mb_bans` WHERE `steam_id` = '%s' LIMIT 1;", target_authid);
//   Format(sql_command, sizeof(sql_command), "SELECT `admin_steamid` FROM `mb_bans` WHERE `steam_id` = '%s' LIMIT 1;", target_authid);
//   // LogError(sql_command);
//   DBResultSet player_data;
//   // Verficando que se haya enviado correctamente
//   if((player_data = SQL_Query(g_database, sql_command)) != null) {
//     // Extrayendo datos
//     if(player_data.FetchRow()) {
//       // STEAM ID del cliente
//       // char steam_id_sql[MAX_NAME_LENGTH];
//       // player_data.FetchString(0, steam_id_sql, MAX_NAME_LENGTH);
//       // TIEMPO DEL BAN
//       // int ban_expired = player_data.FetchInt(1);
//       // STEAM id del admin
//       char admin_authid[MAX_NAME_LENGTH];
//       player_data.FetchString(0, admin_authid, MAX_NAME_LENGTH);
//       // Verificando si es igual
//       if(StrEqual(client_authid, admin_authid) || StrEqual(admin_authid, "server") || StrEqual(client_authid, "server")) {
//         char queryupdate[128];
//         Format(queryupdate, sizeof(queryupdate), "UPDATE mb_bans SET unbanned_by = '%s', unbanned_reason = '%s' WHERE steam_id = '%s'", client_authid, unbanned_reason, target_authid);
//         char querydel[128];
//         Format(querydel, sizeof(querydel), "DELETE FROM mb_bans WHERE steam_id = '%s'", target_authid);
//         Transaction transaction = new Transaction();
//         transaction.AddQuery(queryupdate);
//         transaction.AddQuery(querydel);
//         g_database.Execute(transaction, onBanUpdated, onUnbanFailed, client, DBPrio_High);
//         ReplyToCommand(client, "[BAN] The player has been removed of bans.");
//       } else {
//         ReplyToCommand(client, "[BAN] You can't unban bans of another admin/mod");
//       }
//       player_data.FetchMoreResults();
//     } else {
//       ReplyToCommand(client, "[BAN] The player with the steam id %s does not exist", target_authid);
//     }
//   } else {
//     char error[255];
//     SQL_GetError(g_database, error, sizeof(error));
//     LogError("[%s] Failed to query (error: %s)", DB_CONF_NAME, error);
//     ReplyToCommand(client, "[BAN] Something it's wrong, please report to Aleexxx :'v");
//   }
//   return Plugin_Handled;
// }

// public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
//     PrepareBan(client, g_ban_target[client], g_ban_time[client], sArgs, buffer, sizeof(buffer));
//     PrintToChat(client, "%s", buffer);
//     return Plugin_Stop;
//   }
//   return Plugin_Continue;
// }


// public void onBanUpdated(Database db, int client, int numQueries, DBResultSet[] results, any[] queryData) {

// }

// public void onUnbanFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
//   LogError("(unban) Error in Database Execution: %s", error);
// }


// public void unban(int client, int target) {
// 	Format(sql_command, 255, "SELECT UNIX_TIMESTAMP(dt_ban_expiration) FROM bans_active WHERE player_id = %s LIMIT 1;", steam_id);
// 	g_database.Query(onAnyQuery, sql_command, client, DBPrio_High);
// }