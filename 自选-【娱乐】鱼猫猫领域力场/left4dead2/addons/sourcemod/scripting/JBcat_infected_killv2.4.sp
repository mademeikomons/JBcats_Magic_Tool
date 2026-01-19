#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

int OnGmKill[MAXPLAYERS + 1];
Handle g_hKillTimer[MAXPLAYERS + 1];

ConVar g_cvarKillCommon;
ConVar g_cvarKillSpecial;
ConVar g_cvarKillTank;
ConVar g_cvarKillWitch;
ConVar g_cvarKillRange;
ConVar g_cvarKillInterval;
ConVar g_cvarAutoEnableOnMenu;

bool g_bKillCommon;
bool g_bKillSpecial;
bool g_bKillTank;
bool g_bKillWitch;
float g_fKillRange;
float g_fKillInterval;
bool g_bAutoEnableOnMenu;

bool g_bPlayerKillCommon[MAXPLAYERS + 1];
bool g_bPlayerKillSpecial[MAXPLAYERS + 1];
bool g_bPlayerKillTank[MAXPLAYERS + 1];
bool g_bPlayerKillWitch[MAXPLAYERS + 1];
float g_fPlayerKillRange[MAXPLAYERS + 1];
float g_fPlayerKillInterval[MAXPLAYERS + 1];

bool playerLoad[MAXPLAYERS + 1];

#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"JBcat_infected_kill"
#define PLUGIN_VERSION		"2.4"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"鱼猫猫装逼菜单"
#define PLUGIN_LINK			""

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	version		= PLUGIN_VERSION,
	author		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	url			= PLUGIN_LINK,
};

public void OnPluginStart() 
{
	RegAdminCmd("sm_ymzb", Command_KillMenu, ADMFLAG_ROOT, "秒杀僵尸菜单");
	
	g_cvarKillCommon = CreateConVar(PLUGIN_NAME ... "_common", 		"1", 		"是否秒杀普通僵尸 (0=关闭, 1=开启)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarKillSpecial = CreateConVar(PLUGIN_NAME ... "_special", 	"1", 		"是否秒杀特殊感染者(不包括坦克) (0=关闭, 1=开启)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarKillTank = CreateConVar(PLUGIN_NAME ... "_tank", 			"0", 		"是否秒杀坦克 (0=关闭, 1=开启)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarKillWitch = CreateConVar(PLUGIN_NAME ... "_witch", 		"0", 		"是否秒杀女巫 (0=关闭, 1=开启)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarKillRange = CreateConVar(PLUGIN_NAME ... "_range", 		"256",		"秒杀范围", FCVAR_NONE, true, 50.0, true, 1000.0);
	g_cvarKillInterval = CreateConVar(PLUGIN_NAME ... "_interval", 	"0.5", 		"秒杀时间间隔(秒)", FCVAR_NONE, true, 0.1, true, 5.0);
	g_cvarAutoEnableOnMenu = CreateConVar(PLUGIN_NAME ... "_auto_enable", "0", 	"打开菜单时自动开启秒杀 (0=关闭, 1=开启)", FCVAR_NONE, true, 0.0, true, 1.0);
	
	GetCVarValues();
	
	g_cvarKillCommon.AddChangeHook(OnConVarChanged);
	g_cvarKillSpecial.AddChangeHook(OnConVarChanged);
	g_cvarKillTank.AddChangeHook(OnConVarChanged);
	g_cvarKillWitch.AddChangeHook(OnConVarChanged);
	g_cvarKillRange.AddChangeHook(OnConVarChanged);
	g_cvarKillInterval.AddChangeHook(OnConVarChanged);
	g_cvarAutoEnableOnMenu.AddChangeHook(OnConVarChanged);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	
	//AutoExecConfig(true, PLUGIN_NAME);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	GetCVarValues();
}

void GetCVarValues() 
{
	g_bKillCommon = g_cvarKillCommon.BoolValue;
	g_bKillSpecial = g_cvarKillSpecial.BoolValue;
	g_bKillTank = g_cvarKillTank.BoolValue;
	g_bKillWitch = g_cvarKillWitch.BoolValue;
	g_fKillRange = g_cvarKillRange.FloatValue;
	g_fKillInterval = g_cvarKillInterval.FloatValue;
	g_bAutoEnableOnMenu = g_cvarAutoEnableOnMenu.BoolValue;
}

public void OnMapStart() 
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (g_hKillTimer[i] != null) 
		{
			KillTimer(g_hKillTimer[i]);
			g_hKillTimer[i] = null;
		}
		OnGmKill[i] = 0;
	}
}

public void OnClientPutInServer(int client) 
{
	if (IsFakeClient(client))
		return;
	
	if (!playerLoad[client])
	{
		g_bPlayerKillCommon[client] = g_bKillCommon;
		g_bPlayerKillSpecial[client] = g_bKillSpecial;
		g_bPlayerKillTank[client] = g_bKillTank;
		g_bPlayerKillWitch[client] = g_bKillWitch;
		g_fPlayerKillRange[client] = g_fKillRange;
		g_fPlayerKillInterval[client] = g_fKillInterval;
		OnGmKill[client] = 0;
		
		playerLoad[client] = true;
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!client || !IsValidClient(client) || IsFakeClient(client))
		return;
	
	if (g_hKillTimer[client] != null) 
	{
		KillTimer(g_hKillTimer[client]);
		g_hKillTimer[client] = null;
	}
	
	OnGmKill[client] = 0;
	
	g_bPlayerKillCommon[client] = false;
	g_bPlayerKillSpecial[client] = false;
	g_bPlayerKillTank[client] = false;
	g_bPlayerKillWitch[client] = false;
	g_fPlayerKillRange[client] = 0.0;
	g_fPlayerKillInterval[client] = 0.0;
	
	playerLoad[client] = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (g_hKillTimer[i] != null) 
		{
			KillTimer(g_hKillTimer[i]);
			g_hKillTimer[i] = null;
		}
		OnGmKill[i] = 0;
	}
	return Plugin_Continue;
}

public Action Command_KillMenu(int client, int args)
{
	if (!IsValidClient(client)) 
	{
		ReplyToCommand(client, "%s 无效客户端!", PREFIX);
		return Plugin_Handled;
	}
	
	// 新增：如果开启了自动开启功能且玩家秒杀功能未开启，则自动开启
	if (g_bAutoEnableOnMenu && OnGmKill[client] == 0)
	{
		ToggleKillFunction(client);
		PrintToChat(client, "\x04%s\x05自动开启秒杀功能已生效！", PREFIX);
	}
	
	ShowMainMenu(client);
	return Plugin_Handled;
}

void ShowMainMenu(int client)
{
	char buffer[128];
	Menu menu = new Menu(MainMenuHandler);
	menu.SetTitle("鱼猫猫装逼菜单\n当前状态：%s\n自动开启：%s", 
		OnGmKill[client] == 1 ? "开启" : "关闭",
		g_bAutoEnableOnMenu ? "开启" : "关闭");
	
	Format(buffer, sizeof(buffer), "%s秒杀", OnGmKill[client] == 1 ? "关闭" : "开启");
	menu.AddItem("toggle", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀设置");
	menu.AddItem("settings", buffer);
	
	Format(buffer, sizeof(buffer), "当前设置");
	menu.AddItem("info", buffer);
	
	Format(buffer, sizeof(buffer), "重置设置");
	menu.AddItem("reset", buffer);
	
	Format(buffer, sizeof(buffer), "自动开启：%s", g_bAutoEnableOnMenu ? "开启" : "关闭");
	menu.AddItem("auto_toggle", buffer, ADMFLAG_ROOT); // 仅限管理员
	
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "toggle"))
		{
			ToggleKillFunction(client);
			ShowMainMenu(client);
		}
		else if (StrEqual(info, "settings"))
		{
			ShowSettingsMenu(client);
		}
		else if (StrEqual(info, "info"))
		{
			ShowCurrentSettings(client);
			ShowMainMenu(client);
		}
		else if (StrEqual(info, "reset"))
		{
			ResetPlayerSettings(client);
			ShowMainMenu(client);
		}
		else if (StrEqual(info, "auto_toggle"))
		{
			// 新增：切换自动开启状态
			if (CheckCommandAccess(client, "sm_ymzb", ADMFLAG_ROOT))
			{
				g_bAutoEnableOnMenu = !g_bAutoEnableOnMenu;
				g_cvarAutoEnableOnMenu.SetBool(g_bAutoEnableOnMenu);
				PrintToChat(client, "\x04%s\x05自动开启功能已%s！", PREFIX, g_bAutoEnableOnMenu ? "开启" : "关闭");
			}
			else
			{
				PrintToChat(client, "\x04%s\x05你没有权限修改此设置！", PREFIX);
			}
			ShowMainMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ToggleKillFunction(int client)
{
	if (!IsValidClient(client)) 
	{
		return;
	}
	
	if (OnGmKill[client] == 1) 
	{
		OnGmKill[client] = 0;
		if (g_hKillTimer[client] != null) 
		{
			KillTimer(g_hKillTimer[client]);
			g_hKillTimer[client] = null;
		}
		PrintToChat(client, "\x04%s\x05装逼功能已\x03关闭\x05喵！", PREFIX);
	} 
	else 
	{
		OnGmKill[client] = 1;
		
		if (g_hKillTimer[client] != null)
		{
			KillTimer(g_hKillTimer[client]);
			g_hKillTimer[client] = null;
		}
		
		if (IsPlayerAlive(client))
		{
			g_hKillTimer[client] = CreateTimer(g_fPlayerKillInterval[client], Timer_KillZombies, client, TIMER_REPEAT);
		}
		
		PrintToChat(client, "\x04%s\x05装逼功能已\x03开启\x05喵！", PREFIX);
		PrintToChat(client, "\x04%s\x05秒杀僵尸: \x03%s", PREFIX, g_bPlayerKillCommon[client] ? "是" : "否");
		PrintToChat(client, "\x04%s\x05秒杀特感: \x03%s", PREFIX, g_bPlayerKillSpecial[client] ? "是" : "否");
		PrintToChat(client, "\x04%s\x05秒杀坦克: \x03%s", PREFIX, g_bPlayerKillTank[client] ? "是" : "否");
		PrintToChat(client, "\x04%s\x05秒杀女巫: \x03%s", PREFIX, g_bPlayerKillWitch[client] ? "是" : "否");
		PrintToChat(client, "\x04%s\x05秒杀范围: \x03%.1f", PREFIX, g_fPlayerKillRange[client]);
		PrintToChat(client, "\x04%s\x05秒杀间隔: \x03%.1f秒", PREFIX, g_fPlayerKillInterval[client]);
	}
}

void ShowSettingsMenu(int client)
{
	char buffer[128];
	Menu menu = new Menu(SettingsMenuHandler);
	menu.SetTitle("秒杀设置\n当前状态：%s\n自动开启：%s", 
		OnGmKill[client] == 1 ? "开启" : "关闭",
		g_bAutoEnableOnMenu ? "开启" : "关闭");
	
	Format(buffer, sizeof(buffer), "秒杀僵尸: %s", g_bPlayerKillCommon[client] ? "是" : "否");
	menu.AddItem("common", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀特感: %s", g_bPlayerKillSpecial[client] ? "是" : "否");
	menu.AddItem("special", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀坦克: %s", g_bPlayerKillTank[client] ? "是" : "否");
	menu.AddItem("tank", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀女巫: %s", g_bPlayerKillWitch[client] ? "是" : "否");
	menu.AddItem("witch", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀范围: %.0f", g_fPlayerKillRange[client]);
	menu.AddItem("range", buffer);
	
	Format(buffer, sizeof(buffer), "秒杀间隔: %.1f秒", g_fPlayerKillInterval[client]);
	menu.AddItem("interval", buffer);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int SettingsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "common"))
		{
			g_bPlayerKillCommon[client] = !g_bPlayerKillCommon[client];
			PrintToChat(client, "\x04%s\x05 秒杀僵尸: \x03%s", PREFIX, 
				g_bPlayerKillCommon[client] ? "开启" : "关闭");
			ShowSettingsMenu(client);
		}
		else if (StrEqual(info, "special"))
		{
			g_bPlayerKillSpecial[client] = !g_bPlayerKillSpecial[client];
			PrintToChat(client, "\x04%s\x05 秒杀特感: \x03%s", PREFIX, 
				g_bPlayerKillSpecial[client] ? "开启" : "关闭");
			ShowSettingsMenu(client);
		}
		else if (StrEqual(info, "tank"))
		{
			g_bPlayerKillTank[client] = !g_bPlayerKillTank[client];
			PrintToChat(client, "\x04%s\x05 秒杀坦克: \x03%s", PREFIX, 
				g_bPlayerKillTank[client] ? "开启" : "关闭");
			ShowSettingsMenu(client);
		}
		else if (StrEqual(info, "witch"))
		{
			g_bPlayerKillWitch[client] = !g_bPlayerKillWitch[client];
			PrintToChat(client, "\x04%s\x05 秒杀女巫: \x03%s", PREFIX, 
				g_bPlayerKillWitch[client] ? "开启" : "关闭");
			ShowSettingsMenu(client);
		}
		else if (StrEqual(info, "range"))
		{
			ShowRangeMenu(client);
		}
		else if (StrEqual(info, "interval"))
		{
			ShowIntervalMenu(client);
		}
		else if (StrEqual(info, "back"))
		{
			ShowMainMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMainMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowRangeMenu(int client)
{
	Menu menu = new Menu(RangeMenuHandler);
	menu.SetTitle("秒杀范围\n当前: %.0f", g_fPlayerKillRange[client]);
	
	menu.AddItem("50", "50");
	menu.AddItem("100", "100");
	menu.AddItem("200", "200");
	menu.AddItem("250", "250");
	menu.AddItem("300", "300");
	menu.AddItem("500", "500");
	menu.AddItem("1000", "1000");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int RangeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "back"))
		{
			ShowSettingsMenu(client);
			return 0;
		}
		
		float range = StringToFloat(info);
		g_fPlayerKillRange[client] = range;
		
		PrintToChat(client, "\x04%s\x05 秒杀范围已设置为: \x03%.0f", PREFIX, range);
		ShowSettingsMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void ShowIntervalMenu(int client)
{
	Menu menu = new Menu(IntervalMenuHandler);
	menu.SetTitle("秒杀间隔\n当前: %.1f秒", g_fPlayerKillInterval[client]);
	
	menu.AddItem("0.1", "0.1秒");
	menu.AddItem("0.2", "0.2秒");
	menu.AddItem("0.5", "0.5秒");
	menu.AddItem("1.0", "1.0秒");
	menu.AddItem("2.0", "2.0秒");
	menu.AddItem("2.5", "2.5秒");
	menu.AddItem("5.0", "5.0秒");

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int IntervalMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "back"))
		{
			ShowSettingsMenu(client);
			return 0;
		}
		
		float interval = StringToFloat(info);
		g_fPlayerKillInterval[client] = interval;
		
		if (OnGmKill[client] == 1 && g_hKillTimer[client] != null)
		{
			KillTimer(g_hKillTimer[client]);
			if (IsPlayerAlive(client))
			{
				g_hKillTimer[client] = CreateTimer(g_fPlayerKillInterval[client], Timer_KillZombies, client, TIMER_REPEAT);
			}
		}
		
		PrintToChat(client, "\x04%s\x05 秒杀间隔已设置为: \x03%.1f秒", PREFIX, interval);
		ShowSettingsMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void ShowCurrentSettings(int client)
{
	PrintToChat(client, "\x04%s\x05 ======== 当前装逼设置 ========", PREFIX);
	PrintToChat(client, "\x04%s\x05秒杀僵尸: \x03%s", PREFIX, 
		g_bPlayerKillCommon[client] ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05秒杀特感: \x03%s", PREFIX, 
		g_bPlayerKillSpecial[client] ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05秒杀坦克: \x03%s", PREFIX, 
		g_bPlayerKillTank[client] ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05秒杀女巫: \x03%s", PREFIX, 
		g_bPlayerKillWitch[client] ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05秒杀范围: \x03%.0f", PREFIX, 
		g_fPlayerKillRange[client]);
	PrintToChat(client, "\x04%s\x05秒杀间隔: \x03%.1f秒", PREFIX, 
		g_fPlayerKillInterval[client]);
	PrintToChat(client, "\x04%s\x05秒杀功能: \x03%s", PREFIX, 
		OnGmKill[client] == 1 ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05自动开启: \x03%s", PREFIX,
		g_bAutoEnableOnMenu ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05 ===============================", PREFIX);
}

void ResetPlayerSettings(int client)
{
	g_bPlayerKillCommon[client] = g_bKillCommon;
	g_bPlayerKillSpecial[client] = g_bKillSpecial;
	g_bPlayerKillTank[client] = g_bKillTank;
	g_bPlayerKillWitch[client] = g_bKillWitch;
	g_fPlayerKillRange[client] = g_fKillRange;
	g_fPlayerKillInterval[client] = g_fKillInterval;
	
	PrintToChat(client, "\x04%s\x05 已重置为默认设置！", PREFIX);
	
	if (OnGmKill[client] == 1 && g_hKillTimer[client] != null)
	{
		KillTimer(g_hKillTimer[client]);
		if (IsPlayerAlive(client))
		{
			g_hKillTimer[client] = CreateTimer(g_fPlayerKillInterval[client], Timer_KillZombies, client, TIMER_REPEAT);
		}
	}
}

public Action Timer_KillZombies(Handle timer, any client) 
{
	if (!IsValidClient(client) || !OnGmKill[client]) 
	{
		return Plugin_Stop;
	}
	
	if (!IsPlayerAlive(client)) 
	{
		return Plugin_Continue;
	}
	
	float fClientPos[3];
	GetClientAbsOrigin(client, fClientPos);
	
	bool useCommon = g_bPlayerKillCommon[client];
	bool useSpecial = g_bPlayerKillSpecial[client];
	bool useTank = g_bPlayerKillTank[client];
	bool useWitch = g_bPlayerKillWitch[client];
	float useRange = g_fPlayerKillRange[client];
	
	// 小僵尸
	if (useCommon) 
	{
		int iEntity = MaxClients + 1;
		while ((iEntity = FindEntityByClassname(iEntity, "infected")) != -1) 
		{ 
			if (IsValidEntity(iEntity)) 
			{ 
				int health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
				if (health > 0) 
				{
					float fEntPos[3];
					GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntPos);
					
					if (GetVectorDistance(fClientPos, fEntPos) <= useRange) 
					{
						DealDamage(client, iEntity, health + 1, DMG_GENERIC);
					}
				}
			}
		}
	}
	
	// 特感
	if (useSpecial || useTank) 
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
			{
				int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
				bool isTank = (zombieClass == 8);
				
				if ((isTank && useTank) || (!isTank && useSpecial)) 
				{
					float fEntPos[3];
					GetClientAbsOrigin(i, fEntPos);
					
					if (GetVectorDistance(fClientPos, fEntPos) <= useRange)
					{
						int health = GetClientHealth(i);
						DealDamage(client, i, health + 1, DMG_GENERIC);
					}
				}
			}
		}
	}
	
	// Witch
	if (useWitch) 
	{
		int iEntity = MaxClients + 1;
		while ((iEntity = FindEntityByClassname(iEntity, "witch")) != -1) 
		{ 
			if (IsValidEntity(iEntity)) 
			{ 
				int health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
				if (health > 0) 
				{
					float fEntPos[3];
					GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntPos);
					
					if (GetVectorDistance(fClientPos, fEntPos) <= useRange) 
					{
						DealDamage(client, iEntity, health + 1, DMG_GENERIC);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

bool IsValidClient(int client) 
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

void DealDamage(int attacker, int victim, int damage, int dmgType) 
{
	if (!IsValidEntity(victim)) return;
	
	char sDamage[16];
	IntToString(damage, sDamage, sizeof(sDamage));
	
	char sDmgType[32];
	IntToString(dmgType, sDmgType, sizeof(sDmgType));
	
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt != -1) 
	{
		char targetname[32];
		Format(targetname, sizeof(targetname), "ymzb_target_%d", victim);
		
		DispatchKeyValue(victim, "targetname", targetname);
		DispatchKeyValue(pointHurt, "DamageTarget", targetname);
		DispatchKeyValue(pointHurt, "Damage", sDamage);
		DispatchKeyValue(pointHurt, "DamageType", sDmgType);
		DispatchSpawn(pointHurt);
		
		AcceptEntityInput(pointHurt, "Hurt", (attacker && IsValidClient(attacker)) ? attacker : -1);
		RemoveEntity(pointHurt);
	}
}

public void OnClientDisconnect(int client) 
{
	if (g_hKillTimer[client] != null) 
	{
		KillTimer(g_hKillTimer[client]);
		g_hKillTimer[client] = null;
	}
}