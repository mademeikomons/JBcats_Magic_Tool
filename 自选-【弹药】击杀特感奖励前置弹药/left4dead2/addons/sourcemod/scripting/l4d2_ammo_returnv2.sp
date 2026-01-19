#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar 
	hCountPistolAmmoHead, 
	hCountPistolAmmoShot, 
	hCountMagnumAmmoHead, 
	hCountMagnumAmmoShot, 
	hCountRifleAmmoHead, 
	hCountRifleAmmoShot, 
	hCountSmgAmmoHead, 
	hCountSmgAmmoShot, 
	hCountShotgunAmmoHead, 
	hCountShotgunAmmoShot,
	hCountChainsawHead, 
	hCountChainsawShot,
	hCountAutoshotAmmoHead, 
	hCountAutoshotAmmoShot, 
	hCountHuntingAmmoHead, 
	hCountHuntingAmmoShot, 
	hCountSniperAmmoHead, 
	hCountSniperAmmoShot, 
	hCountGrenadeAmmoHead, 
	hCountGrenadeAmmoShot,
	hCountM60AmmoHead, 
	hCountM60AmmoShot, 
	hCountMinigunAmmoHead, 
	hCountMinigunAmmoShot, 
	hCountTurretAmmoHead, 
	hCountTurretAmmoShot,
	hPluginEnabled,
	hShowKillMessages,
	hCountTankAmmo, 
	hCountWitchAmmo,
	hCountWitchOneShotAmmo;

int 
	CountPistolAmmoHead, 
	CountPistolAmmoShot, 
	CountMagnumAmmoHead, 
	CountMagnumAmmoShot, 
	CountRifleAmmoHead, 
	CountRifleAmmoShot, 
	CountSmgAmmoHead, 
	CountSmgAmmoShot, 
	CountShotgunAmmoHead, 
	CountShotgunAmmoShot,
	CountChainsawHead, 
	CountChainsawShot,
	CountAutoshotAmmoHead, 
	CountAutoshotAmmoShot, 
	CountHuntingAmmoHead, 
	CountHuntingAmmoShot, 
	CountSniperAmmoHead, 
	CountSniperAmmoShot, 
	CountGrenadeAmmoHead, 
	CountGrenadeAmmoShot,
	CountM60AmmoHead, 
	CountM60AmmoShot, 
	CountMinigunAmmoHead, 
	CountMinigunAmmoShot, 
	CountTurretAmmoHead,
	CountTurretAmmoShot,
	bPluginEnabled,
	bShowKillMessages,
	CountTankAmmo,
	CountWitchAmmo,
	CountWitchOneShotAmmo;

char 
	slName1[16], 
	slName2[16], 
	slName3[16], 
	slName4[16], 
	slName5[16], 
	slName6[16],
	clientName[32],
	classname[128];


#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"l4d2_ammo_return"
#define PLUGIN_VERSION		"1.1"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"击杀特感奖励前置弹药"
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
	RegAdminCmd("sm_Magazine", Cmd_Magazine, ADMFLAG_ROOT, "切换奖励前置弹药开关");
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("tank_killed", Event_TankKilled);
	
	hPluginEnabled 			= CreateConVar("l4d2_ammo_enabled", 				"1", 	"启用击杀特感弹药奖励插件? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	hShowKillMessages 		= CreateConVar("l4d2_ammo_show_messages", 			"0", 	"显示击杀特感提示? 0=不显示, 1=显示.", FCVAR_NOTIFY);
	
	hCountPistolAmmoHead	= CreateConVar("l4d2_ammo_pistol_head", 			"8", 	"小手枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountPistolAmmoShot	= CreateConVar("l4d2_ammo_pistol_shot", 			"24", 	"小手枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountMagnumAmmoHead	= CreateConVar("l4d2_ammo_magnum_head", 			"2", 	"马格南击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountMagnumAmmoShot	= CreateConVar("l4d2_ammo_magnum_shot", 			"5", 	"马格南爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountSmgAmmoHead		= CreateConVar("l4d2_ammo_smg_head", 				"6", 	"冲锋枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountSmgAmmoShot		= CreateConVar("l4d2_ammo_smg_shot", 				"18", 	"冲锋枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountRifleAmmoHead		= CreateConVar("l4d2_ammo_rifle_head", 				"5", 	"步枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountRifleAmmoShot		= CreateConVar("l4d2_ammo_rifle_shot", 				"15", 	"步枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountShotgunAmmoHead	= CreateConVar("l4d2_ammo_shotgun_head", 			"2", 	"单喷击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountShotgunAmmoShot	= CreateConVar("l4d2_ammo_shotgun_shot", 			"6", 	"单喷爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountAutoshotAmmoHead	= CreateConVar("l4d2_ammo_autoshotgun_head", 		"2", 	"连喷击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountAutoshotAmmoShot	= CreateConVar("l4d2_ammo_autoshotgun_shot", 		"6", 	"连喷爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountHuntingAmmoHead	= CreateConVar("l4d2_ammo_huntingrifle_head", 		"3", 	"猎枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountHuntingAmmoShot	= CreateConVar("l4d2_ammo_huntingrifle_shot", 		"6", 	"猎枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountSniperAmmoHead	= CreateConVar("l4d2_ammo_sniperrifle_head", 		"2", 	"狙击枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountSniperAmmoShot	= CreateConVar("l4d2_ammo_sniperrifle_shot", 		"4", 	"狙击枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountGrenadeAmmoHead	= CreateConVar("l4d2_ammo_grenadelauncher_head", 	"1", 	"榴弹发射器击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountGrenadeAmmoShot	= CreateConVar("l4d2_ammo_grenadelauncher_shot", 	"10", 	"榴弹发射器爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountChainsawHead		= CreateConVar("l4d2_ammo_chainsaw_head", 			"5", 	"电锯击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountChainsawShot		= CreateConVar("l4d2_ammo_chainsaw_shot", 			"10", 	"电锯爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountM60AmmoHead		= CreateConVar("l4d2_ammo_m60_head", 				"3", 	"M60击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountM60AmmoShot 		= CreateConVar("l4d2_ammo_m60_shot", 				"5", 	"M60爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountMinigunAmmoHead	= CreateConVar("l4d2_ammo_minigun_head", 			"0", 	"Minigun击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountMinigunAmmoShot	= CreateConVar("l4d2_ammo_minigun_shot", 			"2", 	"Minigun爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountTurretAmmoHead	= CreateConVar("l4d2_ammo_turret_head", 			"1", 	"固定机枪击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountTurretAmmoShot	= CreateConVar("l4d2_ammo_turret_shot", 			"3", 	"固定机枪爆头击杀一个特感奖励多少前置弹药.", FCVAR_NOTIFY);

	hCountTankAmmo 			= CreateConVar("l4d2_ammo_tank", 					"100", 	"击杀坦克奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountWitchAmmo 		= CreateConVar("l4d2_ammo_witch", 					"100", 	"击杀女巫奖励多少前置弹药.", FCVAR_NOTIFY);
	hCountWitchOneShotAmmo	= CreateConVar("l4d2_ammo_witch_oneshot", 			"200", 	"秒杀女巫奖励多少前置弹药.", FCVAR_NOTIFY);
	
	//AutoExecConfig(true, PLUGIN_NAME);

	hPluginEnabled.AddChangeHook(ConVarChanged);
	hShowKillMessages.AddChangeHook(ConVarChanged);
	hCountPistolAmmoHead.AddChangeHook(ConVarChanged);
	hCountPistolAmmoShot.AddChangeHook(ConVarChanged);
	hCountMagnumAmmoHead.AddChangeHook(ConVarChanged);
	hCountMagnumAmmoShot.AddChangeHook(ConVarChanged);
	hCountRifleAmmoHead.AddChangeHook(ConVarChanged);
	hCountRifleAmmoShot.AddChangeHook(ConVarChanged);
	hCountSmgAmmoHead.AddChangeHook(ConVarChanged);
	hCountSmgAmmoShot.AddChangeHook(ConVarChanged);
	hCountShotgunAmmoHead.AddChangeHook(ConVarChanged);
	hCountShotgunAmmoShot.AddChangeHook(ConVarChanged);
	hCountAutoshotAmmoHead.AddChangeHook(ConVarChanged);
	hCountAutoshotAmmoShot.AddChangeHook(ConVarChanged);
	hCountHuntingAmmoHead.AddChangeHook(ConVarChanged);
	hCountHuntingAmmoShot.AddChangeHook(ConVarChanged);
	hCountSniperAmmoHead.AddChangeHook(ConVarChanged);
	hCountSniperAmmoShot.AddChangeHook(ConVarChanged);
	hCountGrenadeAmmoHead.AddChangeHook(ConVarChanged);
	hCountGrenadeAmmoShot.AddChangeHook(ConVarChanged);
	hCountChainsawHead.AddChangeHook(ConVarChanged);
	hCountChainsawShot.AddChangeHook(ConVarChanged);
	hCountM60AmmoHead.AddChangeHook(ConVarChanged);
	hCountM60AmmoShot.AddChangeHook(ConVarChanged);
	hCountMinigunAmmoHead.AddChangeHook(ConVarChanged);
	hCountMinigunAmmoShot.AddChangeHook(ConVarChanged);
	hCountTurretAmmoHead.AddChangeHook(ConVarChanged);
	hCountTurretAmmoShot.AddChangeHook(ConVarChanged);
	hCountTankAmmo.AddChangeHook(ConVarChanged);
	hCountWitchAmmo.AddChangeHook(ConVarChanged);
	hCountWitchOneShotAmmo.AddChangeHook(ConVarChanged);

}

public void OnMapStart()
{
	LoadConVarValues();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	LoadConVarValues();
}

void LoadConVarValues()
{
	bPluginEnabled = hPluginEnabled.IntValue;
	bShowKillMessages = hShowKillMessages.IntValue;
	CountPistolAmmoHead = hCountPistolAmmoHead.IntValue;
	CountPistolAmmoShot = hCountPistolAmmoShot.IntValue;
	CountMagnumAmmoHead = hCountMagnumAmmoHead.IntValue;
	CountMagnumAmmoShot = hCountMagnumAmmoShot.IntValue;
	CountRifleAmmoHead = hCountRifleAmmoHead.IntValue;
	CountRifleAmmoShot = hCountRifleAmmoShot.IntValue;
	CountSmgAmmoHead = hCountSmgAmmoHead.IntValue;
	CountSmgAmmoShot = hCountSmgAmmoShot.IntValue;
	CountShotgunAmmoHead = hCountShotgunAmmoHead.IntValue;
	CountShotgunAmmoShot = hCountShotgunAmmoShot.IntValue;
	CountChainsawHead = hCountChainsawHead.IntValue;
	CountChainsawShot = hCountChainsawShot.IntValue;
	CountAutoshotAmmoHead = hCountAutoshotAmmoHead.IntValue;
	CountAutoshotAmmoShot = hCountAutoshotAmmoShot.IntValue;
	CountHuntingAmmoHead = hCountHuntingAmmoHead.IntValue;
	CountHuntingAmmoShot = hCountHuntingAmmoShot.IntValue;
	CountSniperAmmoHead = hCountSniperAmmoHead.IntValue;
	CountSniperAmmoShot = hCountSniperAmmoShot.IntValue;
	CountGrenadeAmmoHead = hCountGrenadeAmmoHead.IntValue;
	CountGrenadeAmmoShot = hCountGrenadeAmmoShot.IntValue;
	CountM60AmmoHead = hCountM60AmmoHead.IntValue;
	CountM60AmmoShot = hCountM60AmmoShot.IntValue;
	CountMinigunAmmoHead = hCountMinigunAmmoHead.IntValue;
	CountMinigunAmmoShot = hCountMinigunAmmoShot.IntValue;
	CountTurretAmmoHead = hCountTurretAmmoHead.IntValue;
	CountTurretAmmoShot = hCountTurretAmmoShot.IntValue;
	CountTankAmmo = hCountTankAmmo.IntValue;
	CountWitchAmmo = hCountWitchAmmo.IntValue;
	CountTankAmmo = hCountTankAmmo.IntValue;
	CountWitchAmmo = hCountWitchAmmo.IntValue;
	CountWitchOneShotAmmo = hCountWitchOneShotAmmo.IntValue;
}

public Action Cmd_Magazine(int client, int args)
{

	if(bPluginEnabled == 1)
	{
		hPluginEnabled.SetInt(0);
		PrintToChatAll("\x04%s\x05插件已关闭.", PREFIX);
	}
	else
	{
		hPluginEnabled.SetInt(1);
		PrintToChatAll("\x04%s\x05插件已开启.", PREFIX);
	}
	return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(bPluginEnabled == 0)
		return;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int headshot = GetEventBool(event, "headshot");
	int HLZClass;
	
	if(!IsValidClient(attacker) || GetClientTeam(attacker) != 2 || !IsValidClient(client) || GetClientTeam(client) != 3)
		return;
	
	HLZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if(HLZClass >= 1 && HLZClass <= 6)
	{
		FormatEx(slName1, sizeof(slName1), "%N", client);
		SplitString(slName1, "Smoker", slName1, sizeof(slName1));
		
		FormatEx(slName2, sizeof(slName2), "%N", client);
		SplitString(slName2, "Boomer", slName2, sizeof(slName2));
		
		FormatEx(slName3, sizeof(slName3), "%N", client);
		SplitString(slName3, "Hunter", slName3, sizeof(slName3));
		
		FormatEx(slName4, sizeof(slName4), "%N", client);
		SplitString(slName4, "Spitter", slName4, sizeof(slName4));
		
		FormatEx(slName5, sizeof(slName5), "%N", client);
		SplitString(slName5, "Jockey", slName5, sizeof(slName5));
		
		FormatEx(slName6, sizeof(slName6), "%N", client);
		SplitString(slName6, "Charger", slName6, sizeof(slName6));
	}
	
	int Weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEdict(Weapon))
		return;
	
	int PrimType = GetEntProp(Weapon, Prop_Send, "m_iPrimaryAmmoType");
	int Clip = GetEntProp(Weapon, Prop_Data, "m_iClip1");
	GetEntityClassname(Weapon, classname, sizeof(classname));
	
	int ammoReward = 0;
	bool changed = false;
	
	char weaponname[64];
	GetEventString(event, "weapon", weaponname, sizeof(weaponname));
	
	if(HLZClass == 8) // 坦克
	{
		ammoReward = CountTankAmmo;
		changed = true;
	}
	else if(HLZClass == 7) // 女巫
	{
		ammoReward = CountWitchAmmo;
		headshot = 0;
		changed = true;
	}
	else
	{
		if(StrEqual(weaponname, "sniper_awp", false)) // Minigun
		{
			if(headshot == 0)
				ammoReward = CountMinigunAmmoHead;
			else
				ammoReward = CountMinigunAmmoShot;
		}
		else if(StrEqual(weaponname, "sniper_scout", false)) // 固定机枪
		{
			if(headshot == 0)
				ammoReward = CountTurretAmmoHead;
			else
				ammoReward = CountTurretAmmoShot;
		}
		else
		{
			switch(headshot)
			{
				case 0: // 击杀
				{
					switch(PrimType)
					{
						case 1: ammoReward = CountPistolAmmoHead; 		// 小手枪
						case 2: ammoReward = CountMagnumAmmoHead; 		// 马格南
						case 3: ammoReward = CountRifleAmmoHead; 		// 步枪
						case 5: ammoReward = CountSmgAmmoHead; 			// 冲锋枪
						case 6: ammoReward = CountM60AmmoHead; 			// M60
						case 7: ammoReward = CountShotgunAmmoHead; 		// 单喷
						case 8: ammoReward = CountAutoshotAmmoHead; 	// 连喷
						case 9: ammoReward = CountHuntingAmmoHead; 		// 猎枪
						case 10: ammoReward = CountSniperAmmoHead; 		// 狙击枪
						case 17: ammoReward = CountGrenadeAmmoHead; 	// 榴弹发射器
						case 19: ammoReward = CountChainsawHead; 		// 电锯
					}
				}
				case 1: // 爆头
				{
					switch(PrimType)
					{
						case 1: ammoReward = CountPistolAmmoShot; 		// 小手枪
						case 2: ammoReward = CountMagnumAmmoShot; 		// 马格南
						case 3: ammoReward = CountRifleAmmoShot; 		// 步枪
						case 5: ammoReward = CountSmgAmmoShot; 			// 冲锋枪
						case 6: ammoReward = CountM60AmmoShot; 			// M60
						case 7: ammoReward = CountShotgunAmmoShot; 		// 单喷
						case 8: ammoReward = CountAutoshotAmmoShot; 	// 连喷
						case 9: ammoReward = CountHuntingAmmoShot; 		// 猎枪
						case 10: ammoReward = CountSniperAmmoShot; 		// 狙击枪
						case 17: ammoReward = CountGrenadeAmmoShot; 	// 榴弹发射器
						case 19: ammoReward = CountChainsawShot; 		// 电锯
					}
				}
			}
		}
		
		if(ammoReward > 0)
		{
			changed = true;
		}
	}
	
	if(ammoReward > 0 && changed)
	{
		int newClip = Clip + ammoReward;
		if(newClip > 255) newClip = 255;
		SetEntProp(Weapon, Prop_Send, "m_iClip1", newClip);
	}
	
	if(bShowKillMessages && changed)
	{
		GetTrueName(attacker, clientName);
		ShowKillMessage(attacker, HLZClass, ammoReward, headshot, weaponname);
	}
}

public void Event_TankKilled(Event event, const char[] name, bool dontBroadcast)
{
	if(bPluginEnabled == 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	// 检查是否为幸存者击杀坦克
	if(!IsValidClient(attacker) || GetClientTeam(attacker) != 2)
		return;
	
	// 获取攻击者的武器
	int Weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEdict(Weapon))
		return;
	
	int Clip = GetEntProp(Weapon, Prop_Data, "m_iClip1");
	
	// 给予坦克击杀弹药奖励
	if(CountTankAmmo > 0)
	{
		int newClip = Clip + CountTankAmmo;
		if(newClip > 255) newClip = 255;
		SetEntProp(Weapon, Prop_Send, "m_iClip1", newClip);
		
		// 显示提示
		if(bShowKillMessages)
		{
			GetTrueName(attacker, clientName);
			PrintToChatAll("\x04%s\x03%s\x05击杀\x03坦克\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, CountTankAmmo);
		}
	}
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	if(bPluginEnabled == 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	bool oneShot = GetEventBool(event, "oneshot");
	
	if(!IsValidClient(client) || GetClientTeam(client) != 2)
		return;
	
	int Weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEdict(Weapon))
		return;
	
	int Clip = GetEntProp(Weapon, Prop_Data, "m_iClip1");
	int ammoReward = 0;
	
	if(oneShot && CountWitchOneShotAmmo > 0)
	{
		ammoReward = CountWitchOneShotAmmo;
	}
	else if(CountWitchAmmo > 0)
	{
		ammoReward = CountWitchAmmo;
	}
	
	if(ammoReward > 0)
	{
		int newClip = Clip + ammoReward;
		if(newClip > 255) newClip = 255;
		SetEntProp(Weapon, Prop_Send, "m_iClip1", newClip);
		
		if(bShowKillMessages)
		{
			GetTrueName(client, clientName);
			if(oneShot)
				PrintToChatAll("\x04%s\x03%s\x05秒杀\x03女巫\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, ammoReward);
			else
				PrintToChatAll("\x04%s\x03%s\x05击杀\x03女巫\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, ammoReward);
		}
	}
}

bool IsPlayerTank(int client)
{
	if(!IsValidClient(client) || GetClientTeam(client) != 3)
		return false;
	
	return (GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}

void ShowKillMessage(int client, int HLZClass, int ammoReward, int headshot, const char[] weaponname)
{
	char message[256];
	
	char infectedName[32];
	switch(HLZClass)
	{
		case 1: Format(infectedName, sizeof(infectedName), "舌头%s", slName1);
		case 2: Format(infectedName, sizeof(infectedName), "胖子%s", slName2);
		case 3: Format(infectedName, sizeof(infectedName), "猎人%s", slName3);
		case 4: Format(infectedName, sizeof(infectedName), "口水%s", slName4);
		case 5: Format(infectedName, sizeof(infectedName), "猴子%s", slName5);
		case 6: Format(infectedName, sizeof(infectedName), "牛牛%s", slName6);
		case 7: Format(infectedName, sizeof(infectedName), "女巫"); 
		case 8: Format(infectedName, sizeof(infectedName), "坦克"); 
	}
	
	char weaponType[32];
	if(StrEqual(weaponname, "sniper_awp", false))
		Format(weaponType, sizeof(weaponType), "Minigun");
	else if(StrEqual(weaponname, "sniper_scout", false))
		Format(weaponType, sizeof(weaponType), "固定机枪");
	else
		Format(weaponType, sizeof(weaponType), "");
	
	if(HLZClass == 8 || HLZClass == 7)
	{
		if(strlen(weaponType) > 0)
			Format(message, sizeof(message), "\x04%s\x03%s\x05使用\x03%s\x05击杀\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, weaponType, infectedName, ammoReward);
		else
			Format(message, sizeof(message), "\x04%s\x03%s\x05击杀\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, infectedName, ammoReward);
	}
	else if(headshot == 1)
	{
		if(strlen(weaponType) > 0)
			Format(message, sizeof(message), "\x04%s\x03%s\x05使用\x03%s\x05爆头特感\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, weaponType, infectedName, ammoReward);
		else
			Format(message, sizeof(message), "\x04%s\x03%s\x05爆头特感\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, infectedName, ammoReward);
	}
	else
	{
		if(strlen(weaponType) > 0)
			Format(message, sizeof(message), "\x04%s\x03%s\x05使用\x03%s\x05击杀特感\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, weaponType, infectedName, ammoReward);
		else
			Format(message, sizeof(message), "\x04%s\x03%s\x05击杀特感\x03%s\x04,\x05奖励\x03%d\x05前置弹药.", PREFIX, clientName, infectedName, ammoReward);
	}
	
	PrintToChat(client, message);
}
bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

void GetTrueName(int bot, char[] savename)
{
	int tbot = IsClientIdle(bot);
	
	if(tbot != 0)
		Format(savename, 32, "★闲置:%N★", tbot);
	else
		GetClientName(bot, savename, 32);
}

int IsClientIdle(int bot)
{
	if(IsClientInGame(bot) && GetClientTeam(bot) == 2 && IsFakeClient(bot))
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if(strcmp(sNetClass, "SurvivorBot") == 0)
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));			
			if(client > 0 && IsClientInGame(client))
				return client;
		}
	}
	return 0;
}