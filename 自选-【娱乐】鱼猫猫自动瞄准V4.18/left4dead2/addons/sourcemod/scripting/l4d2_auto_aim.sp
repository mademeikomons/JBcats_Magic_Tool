#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks_lux_library>
#include <sdkhooks>
#include <sdktools>
#include <l4d_anim>
#include <adminmenu>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define PERMANENT_DURATION -1

#define SMOKER 1
#define BOOMER 2
#define HUNTER 3
#define SPITTER 5
#define JOCKEY 6
#define CHARGER 7
#define TANK 8

#define DEFAULT_MODE 			0		// 瞄准模式: 0=普通模式, 1=旋转模式
#define DEFAULT_ANGLE_LIMIT 	45.0	// 角度限制: 45度
#define DEFAULT_NEED_PRINT_TIP 	1		// 显示提示: 1=开启 0=关闭
#define DEFAULT_CI_ENABLE 		1		// 瞄准小怪: 1=开启 0=关闭
#define DEFAULT_SMOKER_ENABLE 	1		// 瞄准烟鬼: 1=开启 0=关闭
#define DEFAULT_BOOMER_ENABLE 	1		// 瞄准胖子: 1=开启 0=关闭
#define DEFAULT_HUNTER_ENABLE 	1		// 瞄准猎人: 1=开启 0=关闭
#define DEFAULT_SPITTER_ENABLE 	1		// 瞄准口水: 1=开启 0=关闭
#define DEFAULT_JOCKEY_ENABLE 	1		// 瞄准猴子: 1=开启 0=关闭
#define DEFAULT_CHARGER_ENABLE	1		// 瞄准牛牛: 1=开启 0=关闭
#define DEFAULT_TANK_ENABLE 	1		// 瞄准坦克: 1=开启 0=关闭
#define DEFAULT_WITCH_ENABLE 	1		// 瞄准女巫: 1=开启 0=关闭
#define DEFAULT_DURATION 		60		// 默认时长: 60秒
#define DEFAULT_MAX_USES 		3		// 最大使用次数: 3次
#define DEFAULT_ON_COOLDOWN 	60		// 开启冷却时间: 60秒
#define DEFAULT_OFF_COOLDOWN 	0		// 关闭冷却时间: 60秒
#define DEFAULT_AUTO_SHOVE 		1		// 自动推搡: 1=开启 0=关闭

int durations[MAXPLAYERS + 1];
Handle timers[MAXPLAYERS + 1];
int aimCounts[MAXPLAYERS + 1];
float lastOnAimTime[MAXPLAYERS + 1];
float lastOffAimTime[MAXPLAYERS + 1];

bool waitingForCustomInput[MAXPLAYERS + 1];
char customInputType[MAXPLAYERS + 1][32];
Handle customInputTimer[MAXPLAYERS + 1];

StringMap infecteds;
StringMap allowedWeapons;

ConVar mode;
ConVar angleLimit;
ConVar needPrintTip;
ConVar aimCommonInfected;

ConVar aimSmokerInfected;
ConVar aimBoomerInfected;
ConVar aimHunterInfected;
ConVar aimSpitterInfected;
ConVar aimJockeyInfected;
ConVar aimChargerInfected;
ConVar aimTankInfected;
ConVar aimWitchInfected;
ConVar defaultDuration;
ConVar maxAimUsesCvar; 
ConVar onCooldownCvar;
ConVar offCooldownCvar;
ConVar aimAutoShove;

TopMenu hTopMenu;
TopMenuObject hAimMenu = INVALID_TOPMENUOBJECT;

#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"l4d2_auto_aim"
#define PLUGIN_VERSION		"4.18"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"自动瞄准"
#define PLUGIN_LINK			""
#define CUSTOM_CONFIG_PATH	"configs/" ... PLUGIN_NAME ... "_custom.cfg"

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url			= PLUGIN_LINK,
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion version = GetEngineVersion();
	if(version != Engine_Left4Dead2)
	{
		Format(error, err_max, "[JBcat] 此插件仅支持求生之路2喵");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	infecteds = new StringMap();
	allowedWeapons = new StringMap();

	allowedWeapons.SetValue("autoshotgun", true);
	allowedWeapons.SetValue("hunting_rifle", true);
	allowedWeapons.SetValue("pistol", true);
	allowedWeapons.SetValue("pistol_magnum", true);
	allowedWeapons.SetValue("pumpshotgun", true);
	allowedWeapons.SetValue("rifle", true);
	allowedWeapons.SetValue("rifle_ak47", true);
	allowedWeapons.SetValue("rifle_desert", true);
	allowedWeapons.SetValue("rifle_m60", true);
	allowedWeapons.SetValue("rifle_sg552", true);
	allowedWeapons.SetValue("shotgun_chrome", true);
	allowedWeapons.SetValue("shotgun_spas", true);
	allowedWeapons.SetValue("smg", true);
	allowedWeapons.SetValue("smg_mp5", true);
	allowedWeapons.SetValue("smg_silenced", true);
	allowedWeapons.SetValue("sniper_awp", true);
	allowedWeapons.SetValue("sniper_military", true);
	allowedWeapons.SetValue("sniper_scout", true);
	
	RegAdminCmd("sm_aimset", Command_AimMenu, ADMFLAG_ROOT, "自瞄菜单设置");
	RegAdminCmd("sm_aimmenu", Command_AimMenu, ADMFLAG_ROOT, "自瞄菜单设置");
	RegAdminCmd("sm_autoaimmenu", Command_AimMenu, ADMFLAG_ROOT, "自瞄菜单设置");

	RegConsoleCmd("sm_onaim", Command_OnAim, "开启自动瞄准");
	RegConsoleCmd("sm_offaim", Command_OffAim, "关闭自动瞄准");

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("infected_death", OnInfectedDeath);
	HookEvent("witch_spawn", OnWitchSpawn);
	HookEvent("weapon_fire", OnWeaponFire);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("finale_win", OnRoundEnd);
	HookEvent("mission_lost", OnRoundEnd);
	HookEvent("map_transition", OnRoundEnd);
	HookEvent("round_start", OnRoundStart);

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	char buffer[32];
	
	IntToString(DEFAULT_MODE, buffer, sizeof(buffer));
	mode = CreateConVar(PLUGIN_NAME ... "_mode", 							buffer, 	"自动瞄准模式, 0=普通模式, 1=旋转模式", 0, true, 0.0, true, 1.0);
	
	FloatToString(DEFAULT_ANGLE_LIMIT, buffer, sizeof(buffer));
	angleLimit = CreateConVar(PLUGIN_NAME ... "_limited_angle", 			buffer, 	"普通模式下生效，玩家视线与敌人头部的最大角度差", 0, true, 45.0, true, 90.0);
	
	IntToString(DEFAULT_NEED_PRINT_TIP, buffer, sizeof(buffer));
	needPrintTip = CreateConVar(PLUGIN_NAME ... "_need_print_tip", 			buffer, 	"是否显示开启、关闭自瞄提示 0=否, 1=是", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_CI_ENABLE, buffer, sizeof(buffer));
	aimCommonInfected = CreateConVar(PLUGIN_NAME ... "_ci_enable", 			buffer, 	"是否瞄准普通感染者 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_SMOKER_ENABLE, buffer, sizeof(buffer));
	aimSmokerInfected = CreateConVar(PLUGIN_NAME ... "_smoker_enable", 		buffer, 	"是否瞄准烟鬼 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_BOOMER_ENABLE, buffer, sizeof(buffer));
	aimBoomerInfected = CreateConVar(PLUGIN_NAME ... "_boomer_enable", 		buffer, 	"是否瞄准胖子 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_HUNTER_ENABLE, buffer, sizeof(buffer));
	aimHunterInfected = CreateConVar(PLUGIN_NAME ... "_hunter_enable", 		buffer, 	"是否瞄准猎人 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_SPITTER_ENABLE, buffer, sizeof(buffer));
	aimSpitterInfected = CreateConVar(PLUGIN_NAME ... "_spitter_enable", 	buffer, 	"是否瞄准口水 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_JOCKEY_ENABLE, buffer, sizeof(buffer));
	aimJockeyInfected = CreateConVar(PLUGIN_NAME ... "_jockey_enable", 		buffer, 	"是否瞄准猴子 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_CHARGER_ENABLE, buffer, sizeof(buffer));
	aimChargerInfected = CreateConVar(PLUGIN_NAME ... "_charger_enable", 	buffer, 	"是否瞄准牛牛 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_TANK_ENABLE, buffer, sizeof(buffer));
	aimTankInfected = CreateConVar(PLUGIN_NAME ... "_tank_enable", 			buffer, 	"是否瞄准坦克 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_WITCH_ENABLE, buffer, sizeof(buffer));
	aimWitchInfected = CreateConVar(PLUGIN_NAME ... "_witch_enable", 		buffer, 	"是否瞄准女巫 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	IntToString(DEFAULT_DURATION, buffer, sizeof(buffer));
	defaultDuration = CreateConVar(PLUGIN_NAME ... "_default_duration", 	buffer, 	"自动瞄准的持续时间(秒)", 0, true, 0.0);
	
	IntToString(DEFAULT_MAX_USES, buffer, sizeof(buffer));
	maxAimUsesCvar = CreateConVar(PLUGIN_NAME ... "_max_uses", 				buffer, 	"每章玩家最大使用次数", 0, true, 0.0); 
	
	IntToString(DEFAULT_ON_COOLDOWN, buffer, sizeof(buffer));
	onCooldownCvar = CreateConVar(PLUGIN_NAME ... "_on_cooldown", 			buffer, 	"开启的冷却时间（秒）", 0, true, 0.0);
	
	IntToString(DEFAULT_OFF_COOLDOWN, buffer, sizeof(buffer));
	offCooldownCvar = CreateConVar(PLUGIN_NAME ... "_off_cooldown", 		buffer, 	"关闭的冷却时间（秒）", 0, true, 0.0);
	
	IntToString(DEFAULT_AUTO_SHOVE, buffer, sizeof(buffer));
	aimAutoShove = CreateConVar(PLUGIN_NAME ... "_auto_shove", 				buffer, 	"自动推搡 0=禁用, 1=启用", 0, true, 0.0, true, 1.0);
	
	mode.AddChangeHook(OnConVarChanged);
	angleLimit.AddChangeHook(OnConVarChanged);
	needPrintTip.AddChangeHook(OnConVarChanged);
	aimCommonInfected.AddChangeHook(OnConVarChanged);
	aimSmokerInfected.AddChangeHook(OnConVarChanged);
	aimBoomerInfected.AddChangeHook(OnConVarChanged);
	aimHunterInfected.AddChangeHook(OnConVarChanged);
	aimSpitterInfected.AddChangeHook(OnConVarChanged);
	aimJockeyInfected.AddChangeHook(OnConVarChanged);
	aimChargerInfected.AddChangeHook(OnConVarChanged);
	aimTankInfected.AddChangeHook(OnConVarChanged);
	aimWitchInfected.AddChangeHook(OnConVarChanged);
	aimAutoShove.AddChangeHook(OnConVarChanged);
	defaultDuration.AddChangeHook(OnConVarChanged);
	maxAimUsesCvar.AddChangeHook(OnConVarChanged);
	onCooldownCvar.AddChangeHook(OnConVarChanged);
	offCooldownCvar.AddChangeHook(OnConVarChanged);
	
	//AutoExecConfig(true, PLUGIN_NAME);

	LoadCustomSettings();
}

void FormatFloatForDisplay(float value, char[] buffer, int size)
{
	if (value == float(RoundToNearest(value)))
	{
		Format(buffer, size, "%d", RoundToNearest(value));
	}
	else
	{
		float rounded = float(RoundToNearest(value * 10.0)) / 10.0;
		if (value == rounded)
		{
			Format(buffer, size, "%.1f", value);
		}
		else
		{
			Format(buffer, size, "%.2f", value);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu)
		return;
	
	hTopMenu = topmenu;
	
	TopMenuObject objDifficultyMenu = FindTopMenuCategory(hTopMenu, "OtherFeatures");
	if (objDifficultyMenu == INVALID_TOPMENUOBJECT)
		objDifficultyMenu = AddToTopMenu(hTopMenu, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler, INVALID_TOPMENUOBJECT);
	
	hAimMenu = AddToTopMenu(hTopMenu,"sm_aimset",TopMenuObject_Item,AimMenuHandler,objDifficultyMenu,"sm_aimset",ADMFLAG_ROOT);
}

public void AdminMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "★选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "★其它功能", param);
	}
}

public void AimMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hAimMenu)
			Format(buffer, maxlength, "★自瞄控制", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAimMenu)
			ShowMainAimMenu(param);
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char convarName[64];
	convar.GetName(convarName, sizeof(convarName));
	
	char displayName[64];
	char displayValue[64];
	
	if (StrEqual(convarName, PLUGIN_NAME ... "_mode"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准模式");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 0) ? "普通模式" : "旋转模式");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_limited_angle"))
	{
		strcopy(displayName, sizeof(displayName), "角度限制");
		float floatValue = StringToFloat(newValue);
		char formattedValue[32];
		FormatFloatForDisplay(floatValue, formattedValue, sizeof(formattedValue));
		FormatEx(displayValue, sizeof(displayValue), "%s度", formattedValue);
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_need_print_tip"))
	{
		strcopy(displayName, sizeof(displayName), "显示提示");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_ci_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准小怪");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_smoker_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准烟鬼");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_boomer_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准胖子");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_hunter_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准猎人");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_spitter_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准口水");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_jockey_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准猴子");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_charger_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准牛牛");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_tank_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准坦克");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_witch_enable"))
	{
		strcopy(displayName, sizeof(displayName), "瞄准女巫");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_default_duration"))
	{
		strcopy(displayName, sizeof(displayName), "默认时长");
		FormatEx(displayValue, sizeof(displayValue), "%s秒", newValue);
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_max_uses"))
	{
		strcopy(displayName, sizeof(displayName), "最大次数");
		strcopy(displayValue, sizeof(displayValue), newValue);
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_on_cooldown"))
	{
		strcopy(displayName, sizeof(displayName), "开启冷却");
		FormatEx(displayValue, sizeof(displayValue), "%s秒", newValue);
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_off_cooldown"))
	{
		strcopy(displayName, sizeof(displayName), "关闭冷却");
		FormatEx(displayValue, sizeof(displayValue), "%s秒", newValue);
	}
	else if (StrEqual(convarName, PLUGIN_NAME ... "_auto_shove"))
	{
		strcopy(displayName, sizeof(displayName), "自动推搡");
		strcopy(displayValue, sizeof(displayValue), (StringToInt(newValue) == 1) ? "开启" : "关闭");
	}
	else
	{
		strcopy(displayName, sizeof(displayName), convarName);
		strcopy(displayValue, sizeof(displayValue), newValue);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC, false))
		{
			PrintToChat(i, "\x04%s\x05设置 \x03%s\x05 已改为: \x03%s", 
				PREFIX, displayName, displayValue);
		}
	}
	
	SaveCustomSettings();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		aimCounts[i] = 0;
	}
	
	LoadCustomSettings();
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(durations[i] != 0)
		{
			if(durations[i] != PERMANENT_DURATION)
			{
				KillTimerSafety(timers[i]);
			}
			durations[i] = 0;
		}
		aimCounts[i] = 0;
	}
	delete infecteds;
	infecteds = new StringMap();
	
	SaveCustomSettings();
}

void SaveCustomSettings()
{
	KeyValues kv = new KeyValues("AutoAimSettings");
	
	kv.SetNum("mode", mode.IntValue);
	kv.SetFloat("limited_angle", angleLimit.FloatValue);
	kv.SetNum("need_print_tip", needPrintTip.IntValue);
	kv.SetNum("ci_enable", aimCommonInfected.IntValue);
	kv.SetNum("smoker_enable", aimSmokerInfected.IntValue);
	kv.SetNum("boomer_enable", aimBoomerInfected.IntValue);
	kv.SetNum("hunter_enable", aimHunterInfected.IntValue);
	kv.SetNum("spitter_enable", aimSpitterInfected.IntValue);
	kv.SetNum("jockey_enable", aimJockeyInfected.IntValue);
	kv.SetNum("charger_enable", aimChargerInfected.IntValue);
	kv.SetNum("tank_enable", aimTankInfected.IntValue);
	kv.SetNum("witch_enable", aimWitchInfected.IntValue);
	kv.SetNum("auto_shove", aimAutoShove.IntValue);
	kv.SetNum("default_duration", defaultDuration.IntValue);
	kv.SetNum("max_uses", maxAimUsesCvar.IntValue);
	kv.SetNum("on_cooldown", onCooldownCvar.IntValue);
	kv.SetNum("off_cooldown", offCooldownCvar.IntValue);
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CUSTOM_CONFIG_PATH);
	
	if (kv.ExportToFile(path))
	{
		LogMessage("已保存自定义自动瞄准设置到: %s", path);
	}
	else
	{
		LogError("无法保存自定义自动瞄准设置到: %s", path);
	}
	
	delete kv;
}

void LoadCustomSettings()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CUSTOM_CONFIG_PATH);
	
	if (!FileExists(path))
	{
		LogMessage("自定义设置文件不存在，使用默认设置");
		return;
	}
	
	KeyValues kv = new KeyValues("AutoAimSettings");
	
	if (!kv.ImportFromFile(path))
	{
		LogError("无法加载自定义自动瞄准设置从: %s", path);
		delete kv;
		return;
	}
	
	mode.IntValue = kv.GetNum("mode", DEFAULT_MODE);
	angleLimit.FloatValue = kv.GetFloat("limited_angle", DEFAULT_ANGLE_LIMIT);
	needPrintTip.IntValue = kv.GetNum("need_print_tip", DEFAULT_NEED_PRINT_TIP);
	aimCommonInfected.IntValue = kv.GetNum("ci_enable", DEFAULT_CI_ENABLE);
	aimSmokerInfected.IntValue = kv.GetNum("smoker_enable", DEFAULT_SMOKER_ENABLE);
	aimBoomerInfected.IntValue = kv.GetNum("boomer_enable", DEFAULT_BOOMER_ENABLE);
	aimHunterInfected.IntValue = kv.GetNum("hunter_enable", DEFAULT_HUNTER_ENABLE);
	aimSpitterInfected.IntValue = kv.GetNum("spitter_enable", DEFAULT_SPITTER_ENABLE);
	aimJockeyInfected.IntValue = kv.GetNum("jockey_enable", DEFAULT_JOCKEY_ENABLE);
	aimChargerInfected.IntValue = kv.GetNum("charger_enable", DEFAULT_CHARGER_ENABLE);
	aimTankInfected.IntValue = kv.GetNum("tank_enable", DEFAULT_TANK_ENABLE);
	aimWitchInfected.IntValue = kv.GetNum("witch_enable", DEFAULT_WITCH_ENABLE);
	aimAutoShove.IntValue = kv.GetNum("auto_shove", DEFAULT_AUTO_SHOVE);
	defaultDuration.IntValue = kv.GetNum("default_duration", DEFAULT_DURATION);
	maxAimUsesCvar.IntValue = kv.GetNum("max_uses", DEFAULT_MAX_USES);
	onCooldownCvar.IntValue = kv.GetNum("on_cooldown", DEFAULT_ON_COOLDOWN);
	offCooldownCvar.IntValue = kv.GetNum("off_cooldown", DEFAULT_OFF_COOLDOWN);
	
	LogMessage("已加载自定义自动瞄准设置从: %s", path);
	
	delete kv;
}

public Action Command_AimMenu(int client, int args)
{
	if (!IsValidClient(client)) 
	{
		ReplyToCommand(client, "%s 无效客户端!", PREFIX);
		return Plugin_Handled;
	}
	
	ShowMainAimMenu(client);
	return Plugin_Handled;
}

void ShowMainAimMenu(int client)
{
	char buffer[128];
	Menu menu = new Menu(MainAimMenuHandler);
	menu.SetTitle("鱼猫猫自瞄\n当前设置:");
	
	char modeText[8];
	strcopy(modeText, sizeof(modeText), mode.IntValue == 0 ? "普通" : "旋转");
	Format(buffer, sizeof(buffer), "瞄准模式: %s", modeText);
	menu.AddItem("mode", buffer);

	Format(buffer, sizeof(buffer), "自动推搡: %s", 
		aimAutoShove.BoolValue ? "开启" : "关闭");
	menu.AddItem("autoshove", buffer);
	
	Format(buffer, sizeof(buffer), "显示提示: %s", 
		needPrintTip.BoolValue ? "开启" : "关闭");
	menu.AddItem("tip", buffer);
	
	char angleDisplay[32];
	FormatFloatForDisplay(angleLimit.FloatValue, angleDisplay, sizeof(angleDisplay));
	Format(buffer, sizeof(buffer), "角度限制: %s度", angleDisplay); 
	menu.AddItem("angle", buffer);
	
	Format(buffer, sizeof(buffer), "锁定设置");
	menu.AddItem("targets", buffer);
	
	Format(buffer, sizeof(buffer), "玩家设置");
	menu.AddItem("player_settings", buffer);
	
	menu.AddItem("restore", "恢复默认");

	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MainAimMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "mode"))
		{
			int newMode = mode.IntValue == 0 ? 1 : 0;
			mode.SetInt(newMode);
			
			PrintToChat(client, "\x04%s\x05瞄准模式已切换为: \x03%s", PREFIX, 
				newMode == 0 ? "普通模式" : "旋转模式");
			
			if (newMode == 0)
			{
				PrintToChat(client, "\x04%s\x05普通模式: 需要目标在视线角度范围内才会自动瞄准", PREFIX);
				PrintToChat(client, "\x04%s\x05当前角度限制: \x03%.1f度", PREFIX, angleLimit.FloatValue);
			}
			else
			{
				PrintToChat(client, "\x04%s\x05旋转模式: 自动旋转视角瞄准范围内的目标", PREFIX);
			}
			
			ShowMainAimMenu(client);
		}
		else if (StrEqual(info, "targets"))
		{
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "player_settings"))
		{
			ShowPlayerSettingsMenu(client);
		}
		else if (StrEqual(info, "autoshove"))
		{
			bool newValue = !aimAutoShove.BoolValue;
			aimAutoShove.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05自动推搡: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowMainAimMenu(client);
		}
		else if (StrEqual(info, "tip"))
		{
			bool newValue = !needPrintTip.BoolValue;
			needPrintTip.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05显示提示: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowMainAimMenu(client);
		}
		else if (StrEqual(info, "angle"))
		{
			ShowAngleLimitMenu(client);
		}
		else if (StrEqual(info, "restore"))
		{
			RestoreDefaultSettings();
			PrintToChat(client, "\x04%s\x05已恢复默认设置", PREFIX);
			ShowMainAimMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowPlayerSettingsMenu(int client)
{
	char buffer[128];
	Menu menu = new Menu(PlayerSettingsMenuHandler);
	menu.SetTitle("玩家设置");
	
	char durationText[32];
	if (defaultDuration.IntValue == 0)
		strcopy(durationText, sizeof(durationText), "无限");
	else if (defaultDuration.IntValue == -1)
		strcopy(durationText, sizeof(durationText), "永久（管理员）");
	else
		Format(durationText, sizeof(durationText), "%d秒", defaultDuration.IntValue);
	
	Format(buffer, sizeof(buffer), "持续时间: %s", durationText);
	menu.AddItem("duration", buffer);
	
	char maxUsesText[32];
	if (maxAimUsesCvar.IntValue == 0)
		strcopy(maxUsesText, sizeof(maxUsesText), "无限");
	else
		Format(maxUsesText, sizeof(maxUsesText), "%d次", maxAimUsesCvar.IntValue);
	
	Format(buffer, sizeof(buffer), "使用次数: %s", maxUsesText);
	menu.AddItem("max_uses", buffer);
	
	char onCooldownText[32];
	if (onCooldownCvar.IntValue == 0)
		strcopy(onCooldownText, sizeof(onCooldownText), "无冷却");
	else
		Format(onCooldownText, sizeof(onCooldownText), "%d秒", onCooldownCvar.IntValue);
	
	Format(buffer, sizeof(buffer), "开启冷却: %s", onCooldownText);
	menu.AddItem("on_cooldown", buffer);
	
	char offCooldownText[32];
	if (offCooldownCvar.IntValue == 0)
		strcopy(offCooldownText, sizeof(offCooldownText), "无冷却");
	else
		Format(offCooldownText, sizeof(offCooldownText), "%d秒", offCooldownCvar.IntValue);
	
	Format(buffer, sizeof(buffer), "关闭冷却: %s", offCooldownText);
	menu.AddItem("off_cooldown", buffer);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowDurationMenu(int client)
{
	Menu menu = new Menu(DurationMenuHandler);
	
	char currentValue[64];
	if (defaultDuration.IntValue == 0)
		strcopy(currentValue, sizeof(currentValue), "无限");
	else if (defaultDuration.IntValue == -1)
		strcopy(currentValue, sizeof(currentValue), "永久（管理员）");
	else
		Format(currentValue, sizeof(currentValue), "%d秒", defaultDuration.IntValue);
	
	menu.SetTitle("设置持续时间\n当前: %s", currentValue);
	
	menu.AddItem("custom", "自定义数值");
	menu.AddItem("30", "30秒");
	menu.AddItem("60", "60秒");
	menu.AddItem("90", "90秒");
	menu.AddItem("120", "120秒");
	menu.AddItem("0", "无限");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DurationMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "custom"))
		{
			PrintToChat(client, "\x04%s\x05请输入持续时间（秒），输入 \x03cancel\x05 取消", PREFIX);
			waitingForCustomInput[client] = true;
			strcopy(customInputType[client], sizeof(customInputType[]), "duration");
			
			if (customInputTimer[client] != null)
			{
				delete customInputTimer[client];
			}
			customInputTimer[client] = CreateTimer(30.0, Timer_CancelCustomInput, GetClientUserId(client));
			
			ShowPlayerSettingsMenu(client);
		}
		else
		{
			int value = StringToInt(info);
			defaultDuration.SetInt(value);
			
			if (value == 0)
			{
				PrintToChat(client, "\x04%s\x05持续时间已设置为: \x03无限", PREFIX);
			}
			else
			{
				PrintToChat(client, "\x04%s\x05持续时间已设置为: \x03%d秒", PREFIX, value);
			}
			
			ShowPlayerSettingsMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowPlayerSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowMaxUsesMenu(int client)
{
	Menu menu = new Menu(MaxUsesMenuHandler);
	
	char currentValue[64];
	if (maxAimUsesCvar.IntValue == 0)
		strcopy(currentValue, sizeof(currentValue), "无限");
	else
		Format(currentValue, sizeof(currentValue), "%d次", maxAimUsesCvar.IntValue);
	
	menu.SetTitle("设置最大使用次数\n当前: %s", currentValue);
	
	menu.AddItem("custom", "自定义数值");
	menu.AddItem("1", "1次");
	menu.AddItem("3", "3次");
	menu.AddItem("5", "5次");
	menu.AddItem("10", "10次");
	menu.AddItem("0", "无限");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int MaxUsesMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "custom"))
		{
			PrintToChat(client, "\x04%s\x05请输入最大使用次数，输入 \x03cancel\x05 取消", PREFIX);
			waitingForCustomInput[client] = true;
			strcopy(customInputType[client], sizeof(customInputType[]), "max_uses");
			
			if (customInputTimer[client] != null)
			{
				delete customInputTimer[client];
			}
			customInputTimer[client] = CreateTimer(30.0, Timer_CancelCustomInput, GetClientUserId(client));
			
			ShowPlayerSettingsMenu(client);
		}
		else
		{
			int value = StringToInt(info);
			maxAimUsesCvar.SetInt(value);
			
			if (value == 0)
			{
				PrintToChat(client, "\x04%s\x05最大使用次数已设置为: \x03无限", PREFIX);
			}
			else
			{
				PrintToChat(client, "\x04%s\x05最大使用次数已设置为: \x03%d次", PREFIX, value);
			}
			
			ShowPlayerSettingsMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowPlayerSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowOnCooldownMenu(int client)
{
	Menu menu = new Menu(OnCooldownMenuHandler);
	
	char currentValue[64];
	if (onCooldownCvar.IntValue == 0)
		strcopy(currentValue, sizeof(currentValue), "无冷却");
	else
		Format(currentValue, sizeof(currentValue), "%d秒", onCooldownCvar.IntValue);
	
	menu.SetTitle("设置开启冷却时间\n当前: %s", currentValue);
	
	menu.AddItem("custom", "自定义数值");
	menu.AddItem("0", "无CD");
	menu.AddItem("30", "30秒");
	menu.AddItem("60", "60秒");
	menu.AddItem("90", "90秒");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OnCooldownMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "custom"))
		{
			PrintToChat(client, "\x04%s\x05请输入开启冷却时间（秒），输入 \x03cancel\x05 取消", PREFIX);
			waitingForCustomInput[client] = true;
			strcopy(customInputType[client], sizeof(customInputType[]), "on_cooldown");
			
			if (customInputTimer[client] != null)
			{
				delete customInputTimer[client];
			}
			customInputTimer[client] = CreateTimer(30.0, Timer_CancelCustomInput, GetClientUserId(client));
			
			ShowPlayerSettingsMenu(client);
		}
		else
		{
			int value = StringToInt(info);
			onCooldownCvar.SetInt(value);
			
			char tempBuffer[32];
			if (value == 0)
				strcopy(tempBuffer, sizeof(tempBuffer), "无CD");
			else
				Format(tempBuffer, sizeof(tempBuffer), "%d秒", value);
			
			PrintToChat(client, "\x04%s\x05开启冷却时间已设置为: \x03%s", PREFIX, tempBuffer);
			
			ShowPlayerSettingsMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowPlayerSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
void ShowOffCooldownMenu(int client)
{
	Menu menu = new Menu(OffCooldownMenuHandler);
	
	char currentValue[64];
	if (offCooldownCvar.IntValue == 0)
		strcopy(currentValue, sizeof(currentValue), "无冷却");
	else
		Format(currentValue, sizeof(currentValue), "%d秒", offCooldownCvar.IntValue);
	
	menu.SetTitle("设置关闭冷却时间\n当前: %s", currentValue);
	
	menu.AddItem("custom", "自定义数值");
	menu.AddItem("0", "无CD");
	menu.AddItem("30", "30秒");
	menu.AddItem("60", "60秒");
	menu.AddItem("90", "90秒");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OffCooldownMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "custom"))
		{
			PrintToChat(client, "\x04%s\x05请输入关闭冷却时间（秒），输入 \x03cancel\x05 取消", PREFIX);
			waitingForCustomInput[client] = true;
			strcopy(customInputType[client], sizeof(customInputType[]), "off_cooldown");
			
			if (customInputTimer[client] != null)
			{
				delete customInputTimer[client];
			}
			customInputTimer[client] = CreateTimer(30.0, Timer_CancelCustomInput, GetClientUserId(client));
			
			ShowPlayerSettingsMenu(client);
		}
		else
		{
			int value = StringToInt(info);
			offCooldownCvar.SetInt(value);
			
			char tempBuffer[32];
			if (value == 0)
				strcopy(tempBuffer, sizeof(tempBuffer), "无CD");
			else
				Format(tempBuffer, sizeof(tempBuffer), "%d秒", value);
			
			PrintToChat(client, "\x04%s\x05关闭冷却时间已设置为: \x03%s", PREFIX, tempBuffer);
			
			ShowPlayerSettingsMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowPlayerSettingsMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public int PlayerSettingsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "duration"))
		{
			ShowDurationMenu(client);
		}
		else if (StrEqual(info, "max_uses"))
		{
			ShowMaxUsesMenu(client);
		}
		else if (StrEqual(info, "on_cooldown"))
		{
			ShowOnCooldownMenu(client);
		}
		else if (StrEqual(info, "off_cooldown"))
		{
			ShowOffCooldownMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMainAimMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public Action Timer_CancelCustomInput(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && waitingForCustomInput[client])
	{
		waitingForCustomInput[client] = false;
		PrintToChat(client, "\x04%s\x05自定义输入已取消（超时）", PREFIX);
	}
	customInputTimer[client] = null;
	return Plugin_Stop;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!waitingForCustomInput[client] || !IsValidClient(client))
		return Plugin_Continue;
	
	if (StrEqual(sArgs, "cancel", false))
	{
		waitingForCustomInput[client] = false;
		if (customInputTimer[client] != null)
		{
			delete customInputTimer[client];
			customInputTimer[client] = null;
		}
		PrintToChat(client, "\x04%s\x05自定义输入已取消", PREFIX);
		ShowPlayerSettingsMenu(client);
		return Plugin_Handled;
	}
	
	int value = StringToInt(sArgs);
	
	if (StrEqual(customInputType[client], "duration"))
	{
		if (value < 0)
		{
			PrintToChat(client, "\x04%s\x05请输入有效的正数或0（0=无限）", PREFIX);
			return Plugin_Handled;
		}
		
		if (value == 0)
		{
			PrintToChat(client, "\x04%s\x05持续时间已设置为: \x03无限", PREFIX);
		}
		else
		{
			PrintToChat(client, "\x04%s\x05持续时间已设置为: \x03%d秒", PREFIX, value);
		}
		defaultDuration.SetInt(value);
	}
	else if (StrEqual(customInputType[client], "max_uses"))
	{
		if (value < 0)
		{
			PrintToChat(client, "\x04%s\x05请输入有效的正数或0（0=无限）", PREFIX);
			return Plugin_Handled;
		}
		
		if (value == 0)
		{
			PrintToChat(client, "\x04%s\x05最大使用次数已设置为: \x03无限", PREFIX);
		}
		else
		{
			PrintToChat(client, "\x04%s\x05最大使用次数已设置为: \x03%d次", PREFIX, value);
		}
		maxAimUsesCvar.SetInt(value);
	}
	else if (StrEqual(customInputType[client], "on_cooldown"))
	{
		if (value < 0)
		{
			PrintToChat(client, "\x04%s\x05请输入有效的正数或0（0=无冷却）", PREFIX);
			return Plugin_Handled;
		}
		
		onCooldownCvar.SetInt(value);
		
		char tempBuffer[32];
		if (value == 0)
			strcopy(tempBuffer, sizeof(tempBuffer), "无冷却");
		else
			Format(tempBuffer, sizeof(tempBuffer), "%d秒", value);
		
		PrintToChat(client, "\x04%s\x05开启冷却时间已设置为: \x03%s", PREFIX, tempBuffer);
	}
	else if (StrEqual(customInputType[client], "off_cooldown"))
	{
		if (value < 0)
		{
			PrintToChat(client, "\x04%s\x05请输入有效的正数或0（0=无冷却）", PREFIX);
			return Plugin_Handled;
		}
		
		offCooldownCvar.SetInt(value);
		
		char tempBuffer[32];
		if (value == 0)
			strcopy(tempBuffer, sizeof(tempBuffer), "无冷却");
		else
			Format(tempBuffer, sizeof(tempBuffer), "%d秒", value);
		
		PrintToChat(client, "\x04%s\x05关闭冷却时间已设置为: \x03%s", PREFIX, tempBuffer);
	}
	
	waitingForCustomInput[client] = false;
	if (customInputTimer[client] != null)
	{
		delete customInputTimer[client];
		customInputTimer[client] = null;
	}
	
	ShowPlayerSettingsMenu(client);
	
	return Plugin_Handled;
}

void ShowTargetSettingsMenu(int client)
{
	char buffer[128];
	Menu menu = new Menu(TargetSettingsMenuHandler);
	menu.SetTitle("瞄准目标设置");

	bool allEnabled = 
	aimCommonInfected.BoolValue &&
	aimSmokerInfected.BoolValue &&
	aimBoomerInfected.BoolValue &&
	aimHunterInfected.BoolValue &&
	aimSpitterInfected.BoolValue &&
	aimJockeyInfected.BoolValue &&
	aimChargerInfected.BoolValue &&
	aimTankInfected.BoolValue &&
	aimWitchInfected.BoolValue;

	Format(buffer, sizeof(buffer), "全部瞄准: %s", 
		allEnabled ? "开启" : "关闭");
	menu.AddItem("all_toggle", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准小怪: %s", 
		aimCommonInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("common", buffer);

	Format(buffer, sizeof(buffer), "瞄准坦克: %s", 
		aimTankInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("tank", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准女巫: %s", 
		aimWitchInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("witch", buffer);

	Format(buffer, sizeof(buffer), "瞄准烟鬼: %s", 
		aimSmokerInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("smoker", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准胖子: %s", 
		aimBoomerInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("boomer", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准猎人: %s", 
		aimHunterInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("hunter", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准口水: %s", 
		aimSpitterInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("spitter", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准猴子: %s", 
		aimJockeyInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("jockey", buffer);
	
	Format(buffer, sizeof(buffer), "瞄准牛牛: %s", 
		aimChargerInfected.BoolValue ? "开启" : "关闭");
	menu.AddItem("charger", buffer);

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int TargetSettingsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "all_toggle"))
		{
			bool allEnabled = 
			aimCommonInfected.BoolValue &&
			aimSmokerInfected.BoolValue &&
			aimBoomerInfected.BoolValue &&
			aimHunterInfected.BoolValue &&
			aimSpitterInfected.BoolValue &&
			aimJockeyInfected.BoolValue &&
			aimChargerInfected.BoolValue &&
			aimTankInfected.BoolValue &&
			aimWitchInfected.BoolValue;
			
			bool newValue = !allEnabled;
			
			aimCommonInfected.SetBool(newValue);
			aimSmokerInfected.SetBool(newValue);
			aimBoomerInfected.SetBool(newValue);
			aimHunterInfected.SetBool(newValue);
			aimSpitterInfected.SetBool(newValue);
			aimJockeyInfected.SetBool(newValue);
			aimChargerInfected.SetBool(newValue);
			aimTankInfected.SetBool(newValue);
			aimWitchInfected.SetBool(newValue);
			
			PrintToChat(client, "\x04%s\x05全部瞄准已\x03%s\x05!", PREFIX, 
				newValue ? "开启" : "关闭");
			
			if (newValue)
			{
				PrintToChat(client, "\x04%s\x05已\x03开启\x05全部瞄准", PREFIX);
			}
			else
			{
				PrintToChat(client, "\x04%s\x05已\x03关闭\x05全部瞄准", PREFIX);
			}
			
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "common"))
		{
			bool newValue = !aimCommonInfected.BoolValue;
			aimCommonInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准小怪: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "tank"))
		{
			bool newValue = !aimTankInfected.BoolValue;
			aimTankInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准坦克: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "witch"))
		{
			bool newValue = !aimWitchInfected.BoolValue;
			aimWitchInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准女巫: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "smoker"))
		{
			bool newValue = !aimSmokerInfected.BoolValue;
			aimSmokerInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准烟鬼: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "boomer"))
		{
			bool newValue = !aimBoomerInfected.BoolValue;
			aimBoomerInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准胖子: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "hunter"))
		{
			bool newValue = !aimHunterInfected.BoolValue;
			aimHunterInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准猎人: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "spitter"))
		{
			bool newValue = !aimSpitterInfected.BoolValue;
			aimSpitterInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准口水: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "jockey"))
		{
			bool newValue = !aimJockeyInfected.BoolValue;
			aimJockeyInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准猴子: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
		else if (StrEqual(info, "charger"))
		{
			bool newValue = !aimChargerInfected.BoolValue;
			aimChargerInfected.SetBool(newValue);
			PrintToChat(client, "\x04%s\x05瞄准牛牛: \x03%s", PREFIX, 
				newValue ? "开启" : "关闭");
			ShowTargetSettingsMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMainAimMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowAngleLimitMenu(int client)
{
	Menu menu = new Menu(AngleLimitMenuHandler);
	char angleDisplay[32];
	FormatFloatForDisplay(angleLimit.FloatValue, angleDisplay, sizeof(angleDisplay));
	menu.SetTitle("调整角度限制\n当前: %s度\n\n普通模式下，目标必须在视线角度范围内才会自动瞄准", angleDisplay);
	
	menu.AddItem("30", "30度");
	menu.AddItem("45", "45度");
	menu.AddItem("60", "60度");
	menu.AddItem("75", "75度");
	menu.AddItem("90", "90度");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int AngleLimitMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		float newAngle = StringToFloat(info);
		angleLimit.SetFloat(newAngle);
		
		char angleDisplay[32];
		FormatFloatForDisplay(newAngle, angleDisplay, sizeof(angleDisplay));
		PrintToChat(client, "\x04%s\x05角度限制已设置为: \x03%s度", PREFIX, angleDisplay);
		ShowMainAimMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowMainAimMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void RestoreDefaultSettings()
{
	mode.SetInt(DEFAULT_MODE);
	angleLimit.SetFloat(DEFAULT_ANGLE_LIMIT);
	needPrintTip.SetInt(DEFAULT_NEED_PRINT_TIP);
	aimCommonInfected.SetInt(DEFAULT_CI_ENABLE);
	aimSmokerInfected.SetInt(DEFAULT_SMOKER_ENABLE);
	aimBoomerInfected.SetInt(DEFAULT_BOOMER_ENABLE);
	aimHunterInfected.SetInt(DEFAULT_HUNTER_ENABLE);
	aimSpitterInfected.SetInt(DEFAULT_SPITTER_ENABLE);
	aimJockeyInfected.SetInt(DEFAULT_JOCKEY_ENABLE);
	aimChargerInfected.SetInt(DEFAULT_CHARGER_ENABLE);
	aimTankInfected.SetInt(DEFAULT_TANK_ENABLE);
	aimWitchInfected.SetInt(DEFAULT_WITCH_ENABLE);
	aimAutoShove.SetInt(DEFAULT_AUTO_SHOVE);
	defaultDuration.SetInt(DEFAULT_DURATION);
	maxAimUsesCvar.SetInt(DEFAULT_MAX_USES);
	onCooldownCvar.SetInt(DEFAULT_ON_COOLDOWN);
	offCooldownCvar.SetInt(DEFAULT_OFF_COOLDOWN);
	
	SaveCustomSettings();
	
	LogMessage("已恢复默认设置");
}

bool IsValidClient(int client) 
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

public void OnClientPutInServer(int client)
{
	lastOnAimTime[client] = 0.0;
	lastOffAimTime[client] = 0.0;
	waitingForCustomInput[client] = false;
	customInputTimer[client] = null;
}

public void OnClientConnected(int client)
{
	LoadCustomSettings();
}

public void OnClientDisconnect(int client)
{
	SaveCustomSettings();
}

Action Command_OnAim(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		PrintToConsole(client, "[JBcat] 此命令只能在游戏内使用喵.");
		return Plugin_Handled;
	}
	
	bool isAdmin = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	if (!isAdmin)
	{
		float currentTime = GetEngineTime();
		float onCooldown = GetConVarFloat(onCooldownCvar);
		
		if (currentTime - lastOnAimTime[client] < onCooldown)
		{
			float remaining = onCooldown - (currentTime - lastOnAimTime[client]);
			PrintToChat(client, "\x04%s\x05开启自瞄冷却中，请等待 \x03%.1f \x05秒喵.", PREFIX, remaining);
			return Plugin_Handled;
		}
		lastOnAimTime[client] = currentTime;
	}
	
	int duration = GetConVarInt(defaultDuration);
	int maxUses = GetConVarInt(maxAimUsesCvar);
	
	if (!isAdmin)
	{
		if (maxUses > 0 && aimCounts[client] >= maxUses)
		{
			PrintToChat(client, "\x04%s\x05每章地图只能使用 \x03%d \x05次自瞄喵.", PREFIX, maxUses);
			return Plugin_Handled;
		}
		aimCounts[client]++;
	}
	
	if(isAdmin)
	{
		duration = PERMANENT_DURATION;
	}
	
	if(GetConVarBool(needPrintTip))
	{
		if(isAdmin)
		{
			PrintToChat(client, "\x04%s\x03%N\x05开启了自动瞄准喵\x04（仅自己可见）\x05.", PREFIX, client);
		}
		else
		{
			int remainingUses = maxUses - aimCounts[client];
			PrintToChatAll("\x04%s\x03%N \x05开启了自动瞄准（\x03%d秒\x05）\x05，剩余次数：\x05（\x03%d\x05/\x04%d\x05）喵", PREFIX, client, duration, remainingUses, maxUses);
		}
	}
	
	if(durations[client] > 0 || durations[client] == PERMANENT_DURATION)
	{
		if(!isAdmin)
		{
			durations[client] += duration;
		}
	}
	else
	{
		durations[client] = duration;
		
		if(!isAdmin)
		{
			timers[client] = CreateTimer(1.0, CountDown, client, TIMER_REPEAT);
		}
	}
	return Plugin_Handled;
}

Action Command_OffAim(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		PrintToConsole(client, "[JBcat] 此命令只能在游戏内使用喵.");
		return Plugin_Handled;
	}
	
	bool isAdmin = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	if (!isAdmin)
	{
		float currentTime = GetEngineTime();
		float offCooldown = GetConVarFloat(offCooldownCvar);
		
		if (currentTime - lastOffAimTime[client] < offCooldown)
		{
			float remaining = offCooldown - (currentTime - lastOffAimTime[client]);
			PrintToChat(client, "\x04%s\x05关闭自瞄冷却中，请等待 \x03%.1f \x05秒喵.", PREFIX, remaining);
			return Plugin_Handled;
		}
		lastOffAimTime[client] = currentTime;
	}
	
	if (durations[client] != 0)
	{
		bool wasPermanent = (durations[client] == PERMANENT_DURATION);
		durations[client] = 0;
		
		if(!wasPermanent)
		{
			KillTimerSafety(timers[client]);
			timers[client] = null;
		}
		
		if(GetConVarBool(needPrintTip))
		{
			if(wasPermanent)
			{
				PrintToChat(client, "\x04%s\x03您\x05关闭了自动瞄准喵\x04（仅自己可见）\x05.", PREFIX);
			}
			else
			{
				PrintToChatAll("\x04%s\x03%N \x05关闭了自动瞄准喵.", PREFIX, client);
			}
		}
	}
	return Plugin_Handled;
}

Action CountDown(Handle timer, int client)
{
	if(!IsClientValid(client))
	{
		return Plugin_Stop;
	}
	
	if(durations[client] == PERMANENT_DURATION)
	{
		return Plugin_Continue;
	}
	
	durations[client]--;
	if(durations[client] <= 0)
	{
		if(GetConVarBool(needPrintTip))
		{
			PrintToChatAll("\x04%s\x03%N \x05的自动瞄准时间结束喵.", PREFIX, client);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "infected", false) && GetConVarBool(aimCommonInfected))
	{
		SDKHook(EntIndexToEntRef(entity), SDKHook_SpawnPost, OnCommonCreatedPost);
	}
	else if(StrEqual(classname, "witch", false) && GetConVarBool(aimWitchInfected))
	{
		SDKHook(EntIndexToEntRef(entity), SDKHook_SpawnPost, OnWitchCreatedPost);
	}
}

void OnCommonCreatedPost(int entityRef)
{
	SDKUnhook(entityRef, SDKHook_SpawnPost, OnCommonCreatedPost);
	int entity = EntRefToEntIndex(entityRef);
	if(!IsValidEntity(entity))
		return;

	AddToMap(entity, 2);
}

void OnWitchCreatedPost(int entityRef)
{
	SDKUnhook(entityRef, SDKHook_SpawnPost, OnWitchCreatedPost);
	int entity = EntRefToEntIndex(entityRef);
	if(!IsValidEntity(entity))
		return;

	AddToMap(entity, 2);
}

bool IsSpecialInfectedAimEnabled(int zombieClass)
{
	switch(zombieClass)
	{
		case SMOKER: return GetConVarBool(aimSmokerInfected);
		case BOOMER: return GetConVarBool(aimBoomerInfected);
		case HUNTER: return GetConVarBool(aimHunterInfected);
		case SPITTER: return GetConVarBool(aimSpitterInfected);
		case JOCKEY: return GetConVarBool(aimJockeyInfected);
		case CHARGER: return GetConVarBool(aimChargerInfected);
		case TANK: return GetConVarBool(aimTankInfected);
		default: return false;
	}
}

public void OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(durations[client] == 0)
		return;
	
	char weaponName[32];
	GetEventString(event, "weapon", weaponName, sizeof(weaponName));
	if (!allowedWeapons.ContainsKey(weaponName))
		return;
	
	float eye[3];
	GetClientEyePosition(client, eye);
	float eyeAngle[3];
	GetClientEyeAngles(client, eyeAngle);
	float eyeDir[3];
	GetAngleVectors(eyeAngle, eyeDir, NULL_VECTOR, NULL_VECTOR);

	int closestTarget = -1;
	float minDistance = 999999999.0;
	float targetAngle[3];

	float pos[3];
	float dir[3];
	float angle[3];

	Handle trace = null;

	StringMapSnapshot shots = infecteds.Snapshot();
	char num[8];
	int type;

	for(int i = 0; i < shots.Length; i++)
	{
		shots.GetKey(i, num, 8);
		
		if(!infecteds.GetValue(num, type))
			continue;
		int entity = StringToInt(num);

		if(entity <= 0 || !IsValidEntity(entity))
		{
			RemoveFromMap(entity);
			continue;
		}
		
		if(type == 2)
		{
			if(IsCommonInfected(entity))
			{
				if(!GetConVarBool(aimCommonInfected))
					continue;
				int curHp = GetEntProp(entity, Prop_Data, "m_iHealth");
				if(curHp <= 0)
					continue;
				if(!GetAttachmentVectors(entity, "forward", pos, dir))
				{
					GetAbsOrigin(entity, pos);
					pos[2] += 50.0;
				}
			}
			else if(IsWitch(entity))
			{
				if(!GetConVarBool(aimWitchInfected))
					continue;
				int curHp = GetEntProp(entity, Prop_Data, "m_iHealth");
				if(curHp <= 0)
					continue;
				if(!GetAttachmentVectors(entity, "forward", pos, dir))
				{
					GetAbsOrigin(entity, pos);
					pos[2] += 50.0;
				}
			}
			else
			{
				RemoveFromMap(entity);
				continue;
			}
		}
		else if(type == 1)
		{
			int zombieClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
			
			if(zombieClass == TANK)
			{
				if(!GetConVarBool(aimTankInfected))
					continue;
					
				GetClientEyePosition(entity, pos);
			}
			else 
			{
				if(!IsSpecialInfectedAimEnabled(zombieClass))
					continue;
					
				L4D_GetBonePosition(entity, L4D_GetZombieBone(entity, Bone_Head), pos);
			}
		}
		else
		{
			RemoveFromMap(entity);
			continue;
		}

		MakeVectorFromPoints(eye, pos, dir);
		if(GetConVarInt(mode) == 0)
		{
			if(GetAngleBetweenTwoDirection(eyeDir, dir) > GetConVarFloat(angleLimit))
				continue;
		}
		GetVectorAngles(dir, angle);
		
		if(type == 2)
			trace = TR_TraceRayFilterEx(eye, angle, MASK_SHOT, RayType_Infinite, TraceFilterCommonOrWitch, client);
		else if(type == 1)
			trace = TR_TraceRayFilterEx(eye, angle, MASK_SHOT, RayType_Infinite, TraceFilterSpecial, client);
			
		if(trace == null)
			continue;
			
		if(TR_DidHit(trace))
		{
			float endPoint[3];
			TR_GetEndPosition(endPoint, trace);

			float originDis = GetVectorDistance(eye, pos);
			float hitDis = GetVectorDistance(eye, endPoint);
			if(FloatAbs(originDis - hitDis) < 15.0 && minDistance > hitDis)
			{
				closestTarget = entity;
				minDistance = hitDis;
				targetAngle[0] = angle[0];
				targetAngle[1] = angle[1];
				targetAngle[2] = angle[2];
			}
		}
		CloseHandle(trace);
	}
	CloseHandle(shots);
	if(closestTarget != -1)
	{
		TeleportEntity(client, NULL_VECTOR, targetAngle);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!GetConVarBool(aimAutoShove))
		return Plugin_Continue;

	if (durations[client] == 0)
		return Plugin_Continue;

	if (!IsSurvivor(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	if (GetGameTime() < GetEntPropFloat(client, Prop_Send, "m_flNextShoveTime"))
		return Plugin_Continue;

	int closestZombie = GetClosestZombie(client);
	if (closestZombie != -1)
	{
		buttons |= IN_ATTACK2;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

int GetClosestZombie(int client)
{
	int target = -1;
	float temp, distance = 99999.0;
	float myPos[3], targetPos[3];
	
	GetClientAbsOrigin(client, myPos);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i))
			continue;

		int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zombieClass == 6 || zombieClass == 8)
			continue;

		GetClientAbsOrigin(i, targetPos);
		temp = GetVectorDistance(myPos, targetPos);
		if (temp < distance && temp <= 75.0)
		{
			distance = temp;
			target = i;
		}
	}

	return target;
}

public void OnWitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!GetConVarBool(aimWitchInfected))
		return;
		
	int witch = event.GetInt("witchid");
	if(IsValidEntity(witch))
	{
		AddToMap(witch, 2);
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int infected = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsInfected(infected))
	{
		int zombieClass = GetEntProp(infected, Prop_Send, "m_zombieClass");
		
		if(zombieClass == TANK)
		{
			if(GetConVarBool(aimTankInfected))
				AddToMap(infected, 1);
		}
		else if(IsSpecialInfectedAimEnabled(zombieClass))
		{
			AddToMap(infected, 1);
		}
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int infected = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsInfected(infected))
	{
		RemoveFromMap(infected);
	}
}

public void OnInfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int infected = GetEventInt(event, "infected_id");
	RemoveFromMap(infected);
}

void AddToMap(int entity, int headRefEntity)
{
	char num[8];
	Format(num, 8, "%d", entity);
	if(!infecteds.ContainsKey(num))
	{
		infecteds.SetValue(num, headRefEntity);
	}
}

void RemoveFromMap(int entity)
{
	char num[8];
	Format(num, 8, "%d", entity);
	if(infecteds.ContainsKey(num))
	{
		infecteds.Remove(num);
	}
}

public bool TraceFilterCommonOrWitch(int entity, int contentsMask, int self)
{
	if(!IsCommonInfected(entity) && !IsWitch(entity))
	{
		return false;
	}
	return true;
}

public bool TraceFilterSpecial(int entity, int contentsMask, int self)
{
	if(!IsInfected(entity))
	{
		return false;
	}
	return true;
}

stock float GetAngleBetweenTwoDirection(float a[3], float b[3])
{
	float modA = SquareRoot(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
	float modB = SquareRoot(b[0] * b[0] + b[1] * b[1] + b[2] * b[2]);
	float dotProd = GetVectorDotProduct(a, b);
	float cos = dotProd	/ (modA * modB);
	return RadToDeg(ArcCosine(cos));
}

stock bool IsTank(int entity)
{
	if(IsClientValid(entity))
	{
		return GetEntProp(entity, Prop_Send, "m_zombieClass") == TANK;
	}
	return false;
}

stock bool IsClientValid(int client)
{
	return 1 <= client <= MaxClients && IsClientInGame(client);
}

stock bool IsInfected(int client)
{
	return IsClientValid(client) && GetClientTeam(client) == TEAM_INFECTED;
}

stock bool IsSurvivor(int client)
{
	return IsClientValid(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock void KillTimerSafety(Handle& timer)
{
	if(timer != null)
	{
		delete timer;
	}
	timer = null;
}

stock bool IsCommonInfected(int entity)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		char classname[16];
		GetEntityClassname(entity, classname, 16);
		return StrEqual(classname, "infected", false);
	}
	return false;
}

stock bool IsWitch(int entity)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		char classname[16];
		GetEntityClassname(entity, classname, 16);
		return StrEqual(classname, "witch", false);
	}
	return false;
}
/*
void ShowCurrentAimSettings(int client)
{
	PrintToChat(client, "\x04%s\x05 ======= \x04瞄准设置\x05 =======", PREFIX);
	PrintToChat(client, "\x04%s\x05瞄准模式: \x03%s", PREFIX, 
		mode.IntValue == 0 ? "普通" : "旋转");
	PrintToChat(client, "\x04%s\x05角度限制: \x03%.1f度", PREFIX, 
		angleLimit.FloatValue);
	PrintToChat(client, "\x04%s\x05自动推搡: \x03%s", PREFIX, 
		aimAutoShove.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05显示提示: \x03%s", PREFIX, 
		needPrintTip.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05 ======= \x04锁定设置\x05 =======", PREFIX);
	PrintToChat(client, "\x04%s\x05瞄准小怪: \x03%s", PREFIX, 
		aimCommonInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准坦克: \x03%s", PREFIX, 
		aimTankInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准女巫: \x03%s", PREFIX, 
		aimWitchInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准烟鬼: \x03%s", PREFIX, 
		aimSmokerInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准胖子: \x03%s", PREFIX, 
		aimBoomerInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准猎人: \x03%s", PREFIX, 
		aimHunterInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准口水: \x03%s", PREFIX, 
		aimSpitterInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准猴子: \x03%s", PREFIX, 
		aimJockeyInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05瞄准牛牛: \x03%s", PREFIX, 
		aimChargerInfected.BoolValue ? "开启" : "关闭");
	PrintToChat(client, "\x04%s\x05 ======= \x04玩家设置\x05 =======", PREFIX);
	PrintToChat(client, "\x04%s\x05持续时间: \x03%s", PREFIX, 
		defaultDuration.IntValue == 0 ? "无限" : Format("%d秒", defaultDuration.IntValue));
	PrintToChat(client, "\x04%s\x05最大使用次数: \x03%s", PREFIX, 
		maxAimUsesCvar.IntValue == 0 ? "无限" : Format("%d次", maxAimUsesCvar.IntValue));
	PrintToChat(client, "\x04%s\x05开启冷却: \x03%s", PREFIX, 
		onCooldownCvar.IntValue == 0 ? "无冷却" : Format("%d秒", onCooldownCvar.IntValue));
	PrintToChat(client, "\x04%s\x05关闭冷却: \x03%s", PREFIX, 
		offCooldownCvar.IntValue == 0 ? "无冷却" : Format("%d秒", offCooldownCvar.IntValue));
	PrintToChat(client, "\x04%s\x05 ===========================", PREFIX);
}


void RestoreDefaultSettings()
{
	char buffer[64];
	
	GetConVarDefault(mode, buffer, sizeof(buffer));
	mode.SetInt(StringToInt(buffer));
	
	GetConVarDefault(angleLimit, buffer, sizeof(buffer));
	angleLimit.SetFloat(StringToFloat(buffer));
	
	GetConVarDefault(needPrintTip, buffer, sizeof(buffer));
	needPrintTip.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimCommonInfected, buffer, sizeof(buffer));
	aimCommonInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimSmokerInfected, buffer, sizeof(buffer));
	aimSmokerInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimBoomerInfected, buffer, sizeof(buffer));
	aimBoomerInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimHunterInfected, buffer, sizeof(buffer));
	aimHunterInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimSpitterInfected, buffer, sizeof(buffer));
	aimSpitterInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimJockeyInfected, buffer, sizeof(buffer));
	aimJockeyInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimChargerInfected, buffer, sizeof(buffer));
	aimChargerInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimTankInfected, buffer, sizeof(buffer));
	aimTankInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimWitchInfected, buffer, sizeof(buffer));
	aimWitchInfected.SetInt(StringToInt(buffer));
	
	GetConVarDefault(aimAutoShove, buffer, sizeof(buffer));
	aimAutoShove.SetInt(StringToInt(buffer));
	
	GetConVarDefault(defaultDuration, buffer, sizeof(buffer));
	defaultDuration.SetInt(StringToInt(buffer));
	
	GetConVarDefault(maxAimUsesCvar, buffer, sizeof(buffer));
	maxAimUsesCvar.SetInt(StringToInt(buffer));
	
	GetConVarDefault(onCooldownCvar, buffer, sizeof(buffer));
	onCooldownCvar.SetInt(StringToInt(buffer));
	
	GetConVarDefault(offCooldownCvar, buffer, sizeof(buffer));
	offCooldownCvar.SetInt(StringToInt(buffer));
	
	SaveCustomSettings();
	
	LogMessage("已恢复默认设置");
}
*/
