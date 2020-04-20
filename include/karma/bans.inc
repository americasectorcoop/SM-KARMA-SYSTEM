#define CHECK_BAN_ON_AUTHORIZATION true
#define MAX_ID_LENGTH 3
#define MAX_REASON_LENGTH 255
#define BANS_URL "l4d.dev/bans"

TopMenu g_bans_main_menu;

ArrayList AdtBanReasons;
ArrayList AdtUnbanReasons;

enum struct PlayerBan {
  int target;
  int reason_id;
  char authid[32];
  char ipv4[16];
}

enum struct PlayerUnban {
  int log_id;
  char name[MAX_NAME_LENGTH];
}

PlayerBan iBanDetails[MAXPLAYERS + 1];
PlayerUnban iUnbanDetails[MAXPLAYERS + 1];

void vBansRegister() {
  
  RegAdminCmd("sm_ban", CommandBan, ADMFLAG_GENERIC, "sm_ban <#userid|name>");
  RegAdminCmd("sm_unban", CommandUnban, ADMFLAG_GENERIC, "sm_unban <steamid>");
  
  /* Account for late loading */
  TopMenu topmenu;
  if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
    OnAdminMenuReady(topmenu);
  }
  
  AdtBanReasons = new ArrayList(MAX_REASON_LENGTH);
  AdtUnbanReasons = new ArrayList(MAX_REASON_LENGTH);
  
  g_database.Query(onBanFetchReasons, "SELECT `id`, `description` FROM `ks_bans_reasons` ORDER BY `id`;", AdtBanReasons, DBPrio_High);
  g_database.Query(onBanFetchReasons, "SELECT `id`, `description` FROM `ks_unbans_reasons` ORDER BY `id`;", AdtUnbanReasons, DBPrio_High);
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

#if CHECK_BAN_ON_AUTHORIZATION
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
    char hostname[96];
    FindConVar("hostname").GetString(hostname, sizeof(hostname));
    while (results.FetchRow()) {
      int ban_actived = results.FetchInt(0);
      if (ban_actived == 1) {
        char reason[255];
        results.FetchString(1, reason, 255);
        KickClient(client, "%s\n\nYou're banned, reason: %s\n\nPlease visit: %s", hostname, reason, BANS_URL);
      }
    }
  }
  while (results.FetchMoreResults()) {}
}
#endif

public Action CommandUnban(int client, int args) {
  FetchBanListForUnban(client);
  return Plugin_Handled;
}

void FetchBanListForUnban(int client) {
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
      results.FetchString(0, iUnbanDetails[client].name, MAX_NAME_LENGTH);
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
    iUnbanDetails[client].log_id = ban_id;
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
    Unban(client, iUnbanDetails[client].log_id, reason_id);
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
  Format(title, 100, "Ban player");
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
  menu.SetTitle("%s %N", title, iBanDetails[client].target);
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
    iBanDetails[client].reason_id = reason_id;
    ExecBan(client);
  }
}

stock void StoreBanTarget(int client, int target) {
  iBanDetails[client].target = target;
  char target_steam_id[32], target_ip[16];
  GetClientAuthId(target, AuthId_Steam2, target_steam_id, 32);
  Format(iBanDetails[client].authid, 32, "%s", target_steam_id);
  GetClientIP(target, target_ip, 16);
  Format(iBanDetails[client].ipv4, 16, "%s", target_ip);
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
    g_bans_main_menu.AddItem("sm_unban", AdminMenu_Unban, player_commands, "sm_unban", ADMFLAG_GENERIC);
  }
}

public void AdminMenu_Ban(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength) {
  if (action == TopMenuAction_DisplayOption) {
    Format(buffer, maxlength, "Ban player", client);
  } else if (action == TopMenuAction_SelectOption) {
    DisplayBanTargetMenu(client);
  }
}

public void AdminMenu_Unban(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength) {
  if (action == TopMenuAction_DisplayOption) {
    Format(buffer, maxlength, "Unban player", client);
  } else if (action == TopMenuAction_SelectOption) {
    FetchBanListForUnban(client);
  }
}

void ExecBan(int client) {
  char sql_command[128];
  char client_steam_id[32];
  GetClientAuthId(client, AuthId_Steam2, client_steam_id, 32);
  Format(sql_command, 128, "CALL KS_BAN_ADD('%s', '%s', '%s', %d);", iBanDetails[client].authid, iBanDetails[client].ipv4, client_steam_id, iBanDetails[client].reason_id);
  g_database.Query(onBanStored, sql_command, client);
}

public void onBanStored(Database db, DBResultSet results, const char[] error, int client) {
  if (StrEqual(error, "")) {
    char reason_description[MAX_REASON_LENGTH];
    // FIX: this patch just work if from QUERY ban reasons are ordered by id 
    int index = iBanDetails[client].reason_id - 1;
    ArrayList ban_reason = AdtBanReasons.Get(index);
    ban_reason.GetString(1, reason_description, MAX_REASON_LENGTH);
    PrintToChat(client, "\x04[\x05BAN\x04]\x01 Ban for \x03%N\x01(reason: \x03%s\x01) has been added successfully", iBanDetails[client].target, reason_description);
    char hostname[96];
    FindConVar("hostname").GetString(hostname, sizeof(hostname));
    KickClient(iBanDetails[client].target, "%s\n\nYou have been banned because: %s,\n\n Please visit: %s", hostname, reason_description, BANS_URL);
  } else {
    PrintToChat(client, "\x04[\x05BAN\x04]\x01 Ban for \x03%N\x01 couldn't be added because %s", iBanDetails[client].target, error);
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
    PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 Ban for \x03%s\x01 has been removed successfully", iUnbanDetails[client].name);
  } else {
    PrintToChat(client, "\x04[\x05UNBAN\x04]\x01 Ban for \x03%s\x01 couldn't be removed because %s", iUnbanDetails[client].name, error);
  }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("KarmaBan", KarmaBan);
  return APLRes_Success;
}

public int KarmaBan(Handle plugin, int numParams) {
  if(numParams < 3) LogError("Se requieren 3 parametros para KarmaBan");
  int client = GetNativeCell(1);
  int target = GetNativeCell(2);
  int reason_id = GetNativeCell(3);
  StoreBanTarget(client, target);
  iBanDetails[client].reason_id = reason_id;
  ExecBan(client);
  return true;
}
