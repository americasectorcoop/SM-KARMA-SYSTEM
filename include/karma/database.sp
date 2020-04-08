#define DB_CONF_NAME "karma-system"
Database g_database = null;

/**
 * Funcion for connect to Database
 */
public void vStartSQL()
{
	if (SQL_CheckConfig(DB_CONF_NAME)) {
		Database.Connect(vGotDatabase, DB_CONF_NAME);
	} else {
		LogError("database.cfg missing '%s' entry!", DB_CONF_NAME);
		SetFailState("database.cfg missing '%s' entry!", DB_CONF_NAME);
	}
}

public void vGotDatabase(Database database, const char[] error, any data)
{
	if (database == null) {
		LogError("Failed to connect to database: %s", error);
		SetFailState("Failed to connect to database: %s", error);
	}
	database.SetCharset("utf8");
	g_database = database;
	OnDatabaseConnected();
}

public void onAnyQuery(Database db, DBResultSet results, const char[] error, any data) {
	
} 