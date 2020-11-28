#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#pragma semicolon 1 
#pragma newdecls required

int takim_ban[MAXPLAYERS+1],
	g_iSpam[MAXPLAYERS + 1];
Handle takim_bantimer[MAXPLAYERS+1],
	g_check_spam[MAXPLAYERS + 1];
char bansebep[MAXPLAYERS + 1][999];
char banatan[MAXPLAYERS + 1][64];
char mydata[PLATFORM_MAX_PATH];

ConVar convar_tag;
char tag1[999];

public Plugin myinfo =
{
    name = "Takım Ban",
    author = "ali",
    description = "Basit bir takıma girme süreli engelleme/banlama",
    version = "1.0",
    url = "csgo.leaderclan.com"
};


public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_takimban", Command_takim_ban, ADMFLAG_BAN);
	RegAdminCmd("sm_takimunban", Command_CTUnBan, ADMFLAG_BAN);
	RegAdminCmd("sm_takimbanmi", Command_IsBanned, ADMFLAG_BAN);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	AddCommandListener(JoinTeam, "jointeam");
	convar_tag = CreateConVar("takimban_tag", "SM", "Tagı giriniz");
	HookConVarChange(convar_tag, CVarChange);
	GetCVars();
	BuildPath(Path_SM, mydata, sizeof(mydata), "configs/alispw77/takimban_database.cfg");
	for (int i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client){
	CreateTimer(1.0, Timer_Gettakim_banData, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client  = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client) && takim_ban[client] > 0){
		if(!event.GetBool("silent"))
		{
			event.BroadcastDisabled = true;
			if (IsValidClient(client)){
				CreateTimer(1.0, Timer_checkteam, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action JoinTeam(int client, const char[] Command, int ArgumentsCount)
{
	if (IsValidClient(client)){
		CreateTimer(0.1, Timer_checkteam, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_checkteam(Handle timer, int client)
{
	if (IsValidClient(client) && takim_ban[client] > 0){
		float minutes = takim_ban[client] / 60.0;
		if (minutes < 1)
			minutes += 1.0;
		if (g_iSpam[client] < 1){
			g_iSpam[client]++;
			CPrintToChat(client, "[%s] {green}Takıma Girişin {orange}%.0f {green}Dakikalığına Yasaklandı.[Sebep: {orange}%s{green}]", tag1, minutes, bansebep[client]);
		}
		if (!g_check_spam[client])g_check_spam[client] = CreateTimer(3.0, Timer_CheckSpam, client, TIMER_FLAG_NO_MAPCHANGE);
		ChangeClientTeam(client, 1);
	}	
	return Plugin_Continue;
}

public Action Timer_CheckSpam(Handle Timer, int client)
{
	g_iSpam[client] = 0;
	delete g_check_spam[client];
	return Plugin_Continue;
}

public Action Timer_Gettakim_banData(Handle timer, int client)
{
    Gettakim_banData(client);
    return Plugin_Continue;
}

public Action Command_takim_ban(int client, int args)
{
	if(args < 3) 
	{
		CReplyToCommand(client, "{green}Kullanım: sm_takimban [name|#userid] [dakika] [sebep]");
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32], arg3[40];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	int minutes = StringToInt(arg2);
	int target = FindTarget(client, arg1);
	if (target == -1) return Plugin_Handled;
	
	if(takim_ban[target] > 0)
	{
		CPrintToChat(client, "[%s] {orange}%N{green} oyuncunun zaten bir takım yasaklanması bulunmakta.[Atan: {orange}%s{green}][Sebep: {orange}%s{green}]", tag1, target, banatan[target], bansebep[target]);
		return Plugin_Handled;
	}
	char steamid[64];
	bansebep[target] = arg3;
	char name[64];
	GetClientName(client, name, sizeof(name));
	banatan[target] = name;	
	GetClientAuthId(target, AuthId_Steam2, steamid, 64);
	Handle kv = CreateKeyValues("takimban_database");
	FileToKeyValues(kv, mydata);
	KvJumpToKey(kv, steamid, true);
	KvSetString(kv, "takim_ban_time", arg2);
	KvSetString(kv, "Yasaklayan", name);
	KvSetString(kv, "Sebep", arg3);
	KvRewind(kv);
	KeyValuesToFile(kv, mydata);
	CloseHandle(kv);	
	takim_ban[target] = minutes * 60;
	takim_bantimer[target] = CreateTimer(1.0, Timer_TakimBan, target, TIMER_REPEAT);
	
	if (GetClientTeam(target) == 3 || GetClientTeam(target) == 2)
	{
		ChangeClientTeam(target, 1);
		ForcePlayerSuicide(target);
	}
	
	CPrintToChatAll("[%s] {orange}%N {green}adlı oyuncuya, {orange}%N {green}tarafından {orange}%s dakika {green}takım-yasaklanması uygulandı. {orange}[ %s ] {green}sebebiyle.", tag1, client, target, arg2, arg3);
	return Plugin_Continue;
}

public Action Command_CTUnBan(int client, int args)
{
    if(args < 1) 
    {
        CReplyToCommand(client, "{green}Kullanım: sm_takimunban [name|#userid]");
        return Plugin_Handled;
    }
    
    char arg1[32];

    GetCmdArg(1, arg1, sizeof(arg1));
    int target = FindTarget(client, arg1);
    if (target == -1) return Plugin_Handled;
    
    if(takim_ban[target] < 1)
    {
        CPrintToChat(client, "[%s] {orange}%N {green}adlı oyuncunun zaten bir takım-yasaklanması bulunmamakta", tag1, target);
        return Plugin_Handled;
    }
    takim_ban[target] = 0;
    CPrintToChatAll("[%s] {orange}%N {green}adlı oyuncunun takım-yasaklanması, {orange}%N {green}tarafından kaldırıldı.", tag1, target, client);
    delete takim_bantimer[target];
    Updatetakim_banData(target);
    return Plugin_Continue;
}

public Action Timer_TakimBan(Handle timer, int client)
{
    if (!takim_bantimer[client])
    	return Plugin_Stop;
    	
    if(takim_ban[client] < 1)
    {
        takim_ban[client] = 0;
        delete takim_bantimer[client];
        
        return Plugin_Stop;
    }  
    takim_ban[client]--;
    Updatetakim_banData(client);
    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    if (takim_bantimer[client])
    {
        delete (takim_bantimer[client]);
    }
}

public Action Command_IsBanned(int client, int args)
{
    if(args < 1) 
    {
        CReplyToCommand(client, "{green}Kullanım: sm_takimbanmi [name|#userid]");
        return Plugin_Handled;
    }
    
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    int target = FindTarget(client, arg1);
    if (target == -1) return Plugin_Handled;
    
    int minutes = takim_ban[client] / 60;
    minutes++;
    
    if(takim_ban[target] < 1)
        CPrintToChat(client, "[%s] {green}%N adlı oyuncunun takım-yasaklanması bulunmamakta.", tag1, target);
    else CPrintToChat(client, "[%s] {green}%N adlı oyuncunun {orange}%.1d {green}dakika takım-yasaklanması bulunmakta.", tag1, target, minutes);
    
    return Plugin_Continue;
}

void Updatetakim_banData(int client)
{
	char buffer[PLATFORM_MAX_PATH], steamauth[50];
	GetClientAuthId(client, AuthId_Steam2, steamauth, sizeof(steamauth));
	Format(buffer, sizeof(buffer), "%d", takim_ban[client]);
	Handle kv = CreateKeyValues("takimban_database");
	FileToKeyValues(kv, mydata);	
	KvJumpToKey(kv, steamauth);
	KvSetString(kv, "takim_ban_time", buffer);
	
	int length = StringToInt(buffer);
	if (length <= 0)
		KvDeleteThis(kv);
	
	KvRewind(kv);
	KeyValuesToFile(kv, mydata);
	CloseHandle(kv);	
}

void Gettakim_banData(int client)
{
	char sUserID[50];
	GetClientAuthId(client, AuthId_Steam2, sUserID, sizeof(sUserID));
	
	Handle kv = CreateKeyValues("takimban_database");
	FileToKeyValues(kv, mydata);
	if (KvJumpToKey(kv, sUserID, false))
	{
		char sTimeLeft[20];
		KvGetString(kv, "takim_ban_time", sTimeLeft, sizeof(sTimeLeft));
		
		if (StringToInt(sTimeLeft) > 0){
			takim_ban[client] = StringToInt(sTimeLeft);
			KvGetString(kv, "Yasaklayan", banatan[client], sizeof(banatan));
			KvGetString(kv, "Sebep", bansebep[client], sizeof(bansebep));
			if(!takim_bantimer[client])
				takim_bantimer[client] = CreateTimer(1.0, Timer_TakimBan, client, TIMER_REPEAT);
		}				
		else{
			takim_ban[client] = 0;
			if (takim_bantimer[client])delete takim_bantimer[client];
		}
	}
	else
	{
		takim_ban[client] = 0;
		if (takim_bantimer[client])delete takim_bantimer[client];
	}
	CloseHandle(kv);
}

bool IsValidClient(int client) 
{
    if (!( 1 <= client <= MaxClients ) || !IsClientInGame(client)) 
        return false; 
     
    return true; 
}

public void CVarChange(Handle convar_hndl, const char[] oldValue, const char[] newValue) {
	GetCVars();
}

public void GetCVars() {
	GetConVarString(convar_tag, tag1, sizeof(tag1));
}
