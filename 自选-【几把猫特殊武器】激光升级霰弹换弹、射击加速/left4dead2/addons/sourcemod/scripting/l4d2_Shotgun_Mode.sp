#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <WeaponHandling>

#define PLUGIN_NAME			"l4d2_Shotgun_Mode"
#define PLUGIN_VERSION 		"1.4"
#define UPGRADE_LASER_SIGHT (1 << 2)

ConVar g_cvShotgunSpeedModifier;
ConVar g_cvKillsRequired;
ConVar g_cvFireRateModifier;

int g_iShotgunKills[MAXPLAYERS + 1];	
bool g_bHasKillsUpgrade[MAXPLAYERS + 1];
bool g_bHasLaserUpgrade[MAXPLAYERS + 1];
bool g_bHasShownLaserHint[MAXPLAYERS + 1];
int g_iPlayerMode[MAXPLAYERS + 1]; 
int g_iLastButtons[MAXPLAYERS + 1];
bool g_bInZoom[MAXPLAYERS + 1];
float g_fLastModeSwitchTime[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin " ... PLUGIN_NAME ... " only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "L4D2 Shotgun Mode Switcher",
	author = "qy087、JBcat",
	description = "霰弹枪红点升级后，开镜切换换弹、射击加速",
	version = PLUGIN_VERSION,
	url = "https://space.bilibili.com/37743303"
};

public void OnPluginStart()
{ 
	CreateConVar( PLUGIN_NAME ... "_version", PLUGIN_VERSION, "Shotgun Mode Switcher Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	g_cvShotgunSpeedModifier = CreateConVar(
		PLUGIN_NAME ... "_reload_modifier",
		"1.67",
		"霰弹枪换弹加速倍率.",
		FCVAR_NONE,
		true, 1.0, false, 0.0);
	
	g_cvFireRateModifier = CreateConVar(
		PLUGIN_NAME ... "_firerate_modifier",
		"1.67",
		"霰弹枪射击加速倍率.",
		FCVAR_NONE,
		true, 1.0, false, 0.0);
	
	g_cvKillsRequired = CreateConVar(
		PLUGIN_NAME ... "_kills_required",
		"32",
		"需要使用霰弹枪击杀的特殊感染者数量",
		FCVAR_NOTIFY,
		true, 1.0);
	
	AutoExecConfig(true, PLUGIN_NAME);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("map_transition", Event_MapTransition);

	PrecacheSound("weapons/auto_shotgun/gunother/autoshotgun_boltback.wav");
	PrecacheSound("weapons/shotgun/gunother/shotgun_pump_1.wav");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClientState(i);
	}
}

public void OnMapStart()
{
	PrecacheSound("weapons/auto_shotgun/gunother/autoshotgun_boltback.wav");
	PrecacheSound("weapons/shotgun/gunother/shotgun_pump_1.wav");
}

void ResetClientState(int client)
{
	g_iShotgunKills[client] = 0;
	g_bHasKillsUpgrade[client] = false;
	g_bHasLaserUpgrade[client] = false;
	g_bHasShownLaserHint[client] = false;
	//g_iPlayerMode[client] = 0;
	g_iLastButtons[client] = 0;
	g_bInZoom[client] = false;
	g_fLastModeSwitchTime[client] = 0.0;
}

public void OnClientPutInServer(int client)
{
	ResetClientState(client);
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;
	
	if (!g_bHasKillsUpgrade[client] && !g_bHasLaserUpgrade[client])
		return;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon < 1 || !IsValidEntity(weapon))
		return;
	
	char classname[32];
	GetEntityClassname(weapon, classname, sizeof(classname));
	if (!IsShotgunClassname(classname))
		return;
	
	if ((buttons & IN_ZOOM) && !g_bInZoom[client])
	{
		g_bInZoom[client] = true;
		
		float now = GetGameTime();
		if (now - g_fLastModeSwitchTime[client] >= 0.2) // 冷却时间
		{
			TogglePlayerMode(client);
			g_fLastModeSwitchTime[client] = now;
		}
	}
	else if (!(buttons & IN_ZOOM) && g_bInZoom[client])
	{
		g_bInZoom[client] = false;
	}
}

void TogglePlayerMode(int client)
{
	g_iPlayerMode[client] = g_iPlayerMode[client] == 0 ? 1 : 0;

	PlayModeSound(g_iPlayerMode[client] == 1, client);

	/*
	if (g_iPlayerMode[client] == 0)
	{
		PrintToChat(client, "\x04[鱼猫猫]\x05 已切换到\x03 换弹加速\x05 模式喵");
	}
	else
	{
		PrintToChat(client, "\x04[鱼猫猫]\x05 已切换到\x03 射击加速\x05 模式喵");
	}*/
	
	ShowModeHint(client);
}

void ShowModeHint(int client)
{
	char info[128];
	if (g_iPlayerMode[client] == 0)
	{
		FormatEx(info, sizeof(info), "当前模式: 换弹加速\n↑ 换弹速度提升");
	}
	else
	{
		FormatEx(info, sizeof(info), "当前模式: 射击加速\n↑ 射击速度提升");
	}
	
	PrintHintText(client, "%s", info);
}

void PlayModeSound(bool isShootingMode, int client)
{
	char SoundPath[2][128] = { "weapons/auto_shotgun/gunother/autoshotgun_boltback.wav", "weapons/shotgun/gunother/shotgun_pump_1.wav" };
	
	static bool soundsPrecached = false;
	if (!soundsPrecached)
	{
		PrecacheSound(SoundPath[0]);
		PrecacheSound(SoundPath[1]);
		soundsPrecached = true;
	}
	
	EmitSoundToClient(client, SoundPath[isShootingMode ? 0 : 1], _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidClient(attacker) && IsValidClient(victim) && GetClientTeam(victim) == 3)
	{
		int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");

		if (zombieClass >= 1 && zombieClass <= 8)
		{
			char weapon[32];
			event.GetString("weapon", weapon, sizeof(weapon));
			
			if (IsShotgunWeapon(weapon))
			{
				if (g_bHasLaserUpgrade[attacker])
					return;
				
				g_iShotgunKills[attacker]++;
				
				if (g_iShotgunKills[attacker] >= g_cvKillsRequired.IntValue && !g_bHasKillsUpgrade[attacker])
				{
					g_bHasKillsUpgrade[attacker] = true;
					
					if (!IsFakeClient(attacker))
					{
						PrintToChat(attacker, "\x04[鱼猫猫]\x05 已通过击杀获得\x04换弹\x05or\x04射击加速\x05喵（\x03 开镜键\x05 切换模式）");
					}
				}
				
				if (!IsFakeClient(attacker) && !g_bHasKillsUpgrade[attacker] && g_iShotgunKills[attacker] % 8 == 0)
				{
					PrintToChat(attacker, "\x04[鱼猫猫]\x03 升级进度: \x03%d\x05/\x04%d\x05 杀特",
								g_iShotgunKills[attacker], g_cvKillsRequired.IntValue);
				}
			}
		}
	}
}

bool IsShotgunWeapon(const char[] weapon)
{
	return (StrEqual(weapon, "pumpshotgun") || 
			StrEqual(weapon, "shotgun_chrome") || 
			StrEqual(weapon, "autoshotgun") || 
			StrEqual(weapon, "shotgun_spas"));
}

bool IsShotgunClassname(const char[] classname)
{
	return (StrEqual(classname, "weapon_pumpshotgun") || 
			StrEqual(classname, "weapon_shotgun_chrome") || 
			StrEqual(classname, "weapon_autoshotgun") || 
			StrEqual(classname, "weapon_shotgun_spas"));
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) 
{
	switch (weapontype) 
	{
		case L4D2WeaponType_Pumpshotgun, L4D2WeaponType_PumpshotgunChrome, 
			 L4D2WeaponType_Autoshotgun, L4D2WeaponType_AutoshotgunSpas:
		{
			bool hasUpgrade = false;
			
			if (weapon != -1 && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
			{
				int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				if (upgrades & UPGRADE_LASER_SIGHT)
				{
					hasUpgrade = true;
					g_bHasLaserUpgrade[client] = true;

					if (!g_bHasShownLaserHint[client] && !IsFakeClient(client))
					{
						PrintToChat(client, "\x04[鱼猫猫]\x05 已通过激光获得\x04换弹\x05or\x04射击加速\x05喵（按\x03 开镜键\x05 切换模式）");
						g_bHasShownLaserHint[client] = true;
					}
				}
			}
			
			if (!hasUpgrade && g_bHasKillsUpgrade[client])
			{
				hasUpgrade = true;
			}
			
			if (hasUpgrade && g_iPlayerMode[client] == 0)
			{
				speedmodifier = ShotgunSpeedModifier(speedmodifier);
			}
		}
	}
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	switch (weapontype) 
	{
		case L4D2WeaponType_Pumpshotgun, L4D2WeaponType_PumpshotgunChrome, 
			 L4D2WeaponType_Autoshotgun, L4D2WeaponType_AutoshotgunSpas:
		{
			bool hasUpgrade = false;
			
			if (weapon != -1 && HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
			{
				int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				if (upgrades & UPGRADE_LASER_SIGHT)
				{
					hasUpgrade = true;
					g_bHasLaserUpgrade[client] = true;
					
					if (!g_bHasShownLaserHint[client] && !IsFakeClient(client))
					{
						PrintToChat(client, "\x04[鱼猫猫]\x05 已通过激光获得\x04换弹\x05or\x04射击加速\x05喵（按\x03 开镜键\x05 切换模式）");
						g_bHasShownLaserHint[client] = true;
					}
				}
			}
			
			if (!hasUpgrade && g_bHasKillsUpgrade[client])
			{
				hasUpgrade = true;
			}
			
			if (hasUpgrade && g_iPlayerMode[client] == 1)
			{
				speedmodifier = FireRateModifier(speedmodifier);
			}
		}
	}
}

float ShotgunSpeedModifier(float speedmodifier) 
{
	float modifier = g_cvShotgunSpeedModifier.FloatValue;
	
	if (modifier <= 0.0) 
	{
		return speedmodifier;
	}
	speedmodifier = speedmodifier * modifier;
	return speedmodifier;
}

float FireRateModifier(float speedmodifier) 
{
	float modifier = g_cvFireRateModifier.FloatValue;
	
	if (modifier <= 0.0) 
	{
		return speedmodifier;
	}
	speedmodifier = speedmodifier * modifier;
	return speedmodifier;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			g_iShotgunKills[i] = 0;
			g_bHasShownLaserHint[i] = false;
			g_iLastButtons[i] = 0;
		}
	}
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			g_iShotgunKills[i] = 0;
			g_bHasShownLaserHint[i] = false;
		}
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}