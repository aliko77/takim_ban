#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "alikoc77"
#define PLUGIN_VERSION "1.00"
#define ptag "[Takim-Ban]"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <cstrike>

#pragma newdecls required

char g_sSQLBuffer[3096],
	ban_atan[MAXPLAYERS + 1][128],
	ban_sebep[MAXPLAYERS + 1][128];

Handle g_hDB = null;
bool g_bIsMySQl;

bool client_team_ban[MAXPLAYERS + 1],
	g_check_spam[MAXPLAYERS + 1];
int ban_miktar[MAXPLAYERS + 1] = 0,
	g_iSpam[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Takım Ban",
	author = PLUGIN_AUTHOR,
	description = "Bir oyuncunun takıma girmesini engelleme",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/alikoc77"
};

public void OnPluginStart(){
	RegAdminCmd("sm_takimban", com_takimban, ADMFLAG_BAN);
	RegAdminCmd("sm_takimunban", com_untakimban, ADMFLAG_BAN);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	AddCommandListener(JoinTeam, "jointeam");
	SQL_TConnect(sql_connect, "takim_bans");
}

public void OnClientPutInServer(int client){
	if(valid_client(client)){
		function_check_client_ban(client);
	}
}
public void OnClientDisconnect(int client){
	if(!IsFakeClient(client) && client_team_ban[client]){
		client_team_ban[client] = false;
		if(g_check_spam[client])g_check_spam[client] = false;
		ban_miktar[client] = 0;
		g_iSpam[client] = 0;
	}
}

public Action com_takimban(int client, int args){
	if(valid_client(client)){
		if(args < 3) 
		{
			CReplyToCommand(client, "{green}Kullanım: sm_takimban [name|#userid] [dakika] [sebep]");
			return;
		}
		char ctarget[32], cminutes[32], csebep[40];
		GetCmdArg(1, ctarget, sizeof(ctarget));
		GetCmdArg(2, cminutes, sizeof(cminutes));
		GetCmdArg(3, csebep, sizeof(csebep));
		
		int minutes = StringToInt(cminutes);
		int target = FindTarget(client, ctarget);
		if (target == -1)return;
		if(client_team_ban[target]){
			CPrintToChat(client, "{darkred}%s {green}Bu oyuncunun takım-ban ı bulunmakta.", ptag);
			return;
		}
		function_save_client_ban(client, target, minutes, csebep);
		CPrintToChatAll("{darkred}%s {orange}%N {green}adlı oyuncuya, {orange}%N {green}tarafından {orange}%i dakika {green}takım-yasaklanması uygulandı. {orange}[ %s ] {green}sebebiyle.", ptag, target, client, minutes, csebep);
	}
}
public Action com_untakimban(int client, int args){
	if(valid_client(client)){
		if(args < 3) 
		{
			CReplyToCommand(client, "{green}Kullanım: sm_takimunban [name|#userid]");
			return;
		}
		char ctarget[32];
		GetCmdArg(1, ctarget, sizeof(ctarget));
		int target = FindTarget(client, ctarget);
		if (target == -1)return;
		if(!client_team_ban[target]){
			CPrintToChat(client, "{darkred}%s {green}Bu oyuncunun takım-ban ı zaten bulunmamakta.", ptag);
			return;
		}
		function_del_client_ban(target);
		CPrintToChatAll("{darkred}%s {orange}%N {green}adlı oyuncunun takım-yasaklanması, {orange}%N {green}tarafından kaldırıldı.", ptag, target, client);
	}
}
//sql
public void sql_connect(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null){
		LogError("Database failure: %s", error);
		SetFailState("Databases dont work");
	}
	else{
		g_hDB = hndl;
		SQL_SetCharset(g_hDB, "utf8mb4");
		SQL_GetDriverIdent(SQL_ReadDriver(g_hDB), g_sSQLBuffer, sizeof(g_sSQLBuffer));
		g_bIsMySQl = StrEqual(g_sSQLBuffer,"mysql", false) ? true : false;
		
		if(g_bIsMySQl)
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `team_bans` (`steamid` varchar(32) PRIMARY KEY NOT NULL, `sebep` varchar(128) NOT NULL, `banlayan` varchar(128) NOT NULL, `ban_time` int(64) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer, 0);
		}
		else{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS team_bans (steamid varchar(32) PRIMARY KEY NOT NULL, sebep varchar(128) NOT NULL, banlayan varchar(128) NOT NULL, ban_time int(64) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer, 0);	
		}
	}
}
public int OnSQLConnectCallback(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null)
	{
		LogError("Query failure: %s", error);
		return;
	}
	if(data == 0){
		for(int client = 1; client <= MaxClients; client++)
		{
			if(valid_client(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}
//functions
void function_save_client_ban(int client, int target, int minutes, char[] sebep){
	if (valid_client(target) && valid_client(client)){
		client_team_ban[target] = true;
		char query[256], steamid[64], client_name[128];
		if(!GetClientName(client, client_name, sizeof(client_name))){
			Format(client_name, sizeof(client_name), "<noname>");
		}
		else{
			GetClientName(client, client_name, sizeof(client_name));
		}		
		GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));
		Format(query, sizeof(query), "INSERT INTO team_bans(`steamid`, `sebep`, `banlayan`, `ban_time`) VALUES('%s', \"%s\", \"%s\", '%d');", steamid, sebep, client_name, GetTime() + (minutes * 60));
		SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, target);
		client_team_ban[target] = true;
		ban_miktar[target] = GetTime() + (minutes * 60);
		if(GetClientTeam(target) != 1)ChangeClientTeam(target, 1);
	}
}
void function_check_client_ban(int client){
	if (!valid_client(client))return;
	char steamid[64], query[256];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	Format(query, sizeof(query), "SELECT sebep, banlayan, ban_time FROM team_bans WHERE steamid = '%s'", steamid);
	SQL_TQuery(g_hDB, CheckSQLSteamIDCallback, query, GetClientUserId(client));
}
void function_del_client_ban(int client){
	if (!valid_client(client))return;
	char steamid[64], query[256];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	client_team_ban[client] = false;
	Format(query, sizeof(query), "DELETE FROM `team_bans` WHERE steamid = '%s';", steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, client);
}
bool valid_client(int client){
	return (IsClientInGame(client) && !IsFakeClient(client));
}
//sql
public int SaveSQLPlayerCallback(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null)
	{
		LogError("Query failure: %s", error);
	}
}
public int CheckSQLSteamIDCallback(Handle owner, Handle hndl, char [] error, any data){
	int client,
		ban_time;
	if((client = GetClientOfUserId(data)) == 0){
		return;
	}
	if(hndl == null){
		LogError("Query failure: %s", error);
		return;
	}
	if(!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
		function_del_client_ban(client);
		return;
	}
	ban_time = SQL_FetchInt(hndl, 2);
	if(GetTime() > ban_time){
		function_del_client_ban(client);
		return;
	}
	SQL_FetchString(hndl, 1, ban_atan[client],sizeof(ban_atan[]));
	SQL_FetchString(hndl, 0, ban_sebep[client],sizeof(ban_sebep[]));
	client_team_ban[client] = true;
}
//hooks
public Action JoinTeam(int client, const char[] Command, int ArgumentsCount)
{
	if (valid_client(client) && client_team_ban[client]){
		char steamid[64], query[256];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		Format(query, sizeof(query), "SELECT sebep, banlayan, ban_time FROM team_bans WHERE steamid = '%s'", steamid);
		SQL_TQuery(g_hDB, CheckSQLSteamIDCallback, query, GetClientUserId(client));
		if(GetClientTeam(client) != 1)ChangeClientTeam(client, 1);
		int minutes = ban_miktar[client] - GetTime();
		if (g_iSpam[client] < 1){
			g_iSpam[client]++;
			g_check_spam[client] = true;
			CPrintToChat(client, "{darkred}%s {green}Takıma Girişin {orange}%i {green}saniyeliğine Yasaklandı.[Sebep: {orange}%s{green}]", ptag, minutes, ban_sebep[client]);
		}
		if (g_check_spam[client])CreateTimer(3.0, Timer_CheckSpam, client, TIMER_FLAG_NO_MAPCHANGE);		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client  = GetClientOfUserId(GetEventInt(event, "userid"));
	if (valid_client(client) && client_team_ban[client]){
		if(!event.GetBool("silent"))
		{
			event.BroadcastDisabled = true;
		}
	}
}
//timers
public Action Timer_CheckSpam(Handle Timer, any client)
{
	g_iSpam[client] = 0;
	g_check_spam[client] = false;
	return Plugin_Continue;
}