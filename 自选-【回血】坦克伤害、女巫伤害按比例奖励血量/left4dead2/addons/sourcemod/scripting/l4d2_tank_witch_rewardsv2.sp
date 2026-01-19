#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

int g_iTankRewardScale;
bool g_bTankRewardDisplay;
ConVar g_hTankRewardScale, g_hTankRewardDisplay;

int g_iWitchRewardScale;
bool g_bWitchRewardDisplay;
ConVar g_hWitchRewardScale, g_hWitchRewardDisplay;

int g_iMaxHealth;
ConVar g_hMaxHealth;

int g_iTankRewardIncrement;
int g_iWitchRewardIncrement;
ConVar g_hTankRewardIncrement, g_hWitchRewardIncrement;

int g_iTankDamage[MAXPLAYERS + 1];
bool g_bTankAlive;

float g_fSurvivorWitchHurt[MAXPLAYERS + 1][2048 + 1];

Handle g_hPainPillsDecay;

#define CVAR_FLAGS			FCVAR_NOTIFY
#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"l4d2_tank_witch_rewards"
#define PLUGIN_VERSION		"1.2.4"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"坦克伤害、女巫伤害按比例奖励血量"
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
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled);

	g_hMaxHealth = CreateConVar("l4d2_damage_reward_max_health", 			"120", 	"设置幸存者获得伤害奖励后的最高血量上限", CVAR_FLAGS);

	g_hTankRewardScale = CreateConVar("l4d2_tank_reward_scale", 			"200", 	"坦克伤害比例换算系数：造成100%伤害时获得多少血量奖励(基础值)", CVAR_FLAGS);
	g_hTankRewardDisplay = CreateConVar("l4d2_tank_reward_display", 		"1", 	"显示坦克伤害奖励提示", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hTankRewardIncrement = CreateConVar("l4d2_tank_reward_increment",		"50", 	"每增加4名生还者，坦克奖励系数增加的百分比(0-100)", CVAR_FLAGS, true, 0.0, true, 100.0);
	
	g_hWitchRewardScale = CreateConVar("l4d2_witch_reward_scale", 			"100", 	"女巫伤害比例换算系数：造成100%伤害时获得多少血量奖励(基础值)", CVAR_FLAGS);
	g_hWitchRewardDisplay = CreateConVar("l4d2_witch_reward_display", 		"1", 	"显示女巫伤害奖励提示", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hWitchRewardIncrement = CreateConVar("l4d2_witch_reward_increment",	"25", 	"每增加4名生还者，女巫奖励系数增加的百分比(0-100)", CVAR_FLAGS, true, 0.0, true, 100.0);
	
	g_hTankRewardScale.AddChangeHook(ConVarChangedSettings);
	g_hTankRewardDisplay.AddChangeHook(ConVarChangedSettings);
	g_hTankRewardIncrement.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardScale.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardDisplay.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardIncrement.AddChangeHook(ConVarChangedSettings);
	g_hMaxHealth.AddChangeHook(ConVarChangedSettings);
	
	g_hPainPillsDecay = FindConVar("pain_pills_decay_rate");
	if (g_hPainPillsDecay == null)
	{
		SetFailState("无法找到 'pain_pills_decay_rate' cvar");
	}
	
	//AutoExecConfig(true, PLUGIN_NAME);
}

public void OnMapStart()
{
	ResetDamageRecords();
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE)
	{
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
		return;
	
	if (StrEqual(classname, "witch"))
	{
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
}

public void OnConfigsExecuted()
{
	GetConVarChange();
}

public void OnClientDisconnect(int client)
{
	g_iTankDamage[client] = 0;
	for (int i = 0; i < 2048; i++)
	{
		g_fSurvivorWitchHurt[client][i] = 0.0;
	}
}

void ConVarChangedSettings(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarChange();
}

void GetConVarChange()
{
	g_iTankRewardScale = g_hTankRewardScale.IntValue;
	g_bTankRewardDisplay = g_hTankRewardDisplay.BoolValue;
	g_iTankRewardIncrement = g_hTankRewardIncrement.IntValue;
	
	g_iWitchRewardScale = g_hWitchRewardScale.IntValue;
	g_bWitchRewardDisplay = g_hWitchRewardDisplay.BoolValue;
	g_iWitchRewardIncrement = g_hWitchRewardIncrement.IntValue;
	
	g_iMaxHealth = g_hMaxHealth.IntValue;
	
	if (g_iMaxHealth < 1)
		g_iMaxHealth = 1;
}

// 指数增长
int GetDynamicRewardScale(int baseScale, int incrementPercent)
{
	int survivorCount = GetSurvivorCount();
	
	if (survivorCount <= 4)
		return baseScale;
	
	int extraGroups = (survivorCount - 1) / 4;
	
	float incrementMultiplier = 1.0 + (float(incrementPercent) / 100.0);
	// 计算总乘数：指数增长公式
	float multiplier = Pow(incrementMultiplier, float(extraGroups));
	
	int dynamicScale = RoundToNearest(float(baseScale) * multiplier);
	
	return dynamicScale > 0 ? dynamicScale : baseScale;
}

/*// 线性增长
int GetDynamicRewardScale(int baseScale, int incrementPercent)
{
	int survivorCount = GetSurvivorCount();
	
	if (survivorCount <= 4)
		return baseScale;
	
	int extraGroups = (survivorCount - 1) / 4;
	// 每增加4人增加0.5倍（即50%）
	float multiplier = 1.0 + (float(extraGroups) * 0.5);
	
	int dynamicScale = RoundToNearest(float(baseScale) * multiplier);
	
	return dynamicScale > 0 ? dynamicScale : baseScale;
}
*/ 
int GetSurvivorCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 2)
		{
			count++;
		}
	}
	return count;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerTank(client))
	{
		g_bTankAlive = true;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			g_iTankDamage[i] = 0;
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(victim) || GetClientTeam(victim) != 3)
		return;

	if (IsPlayerTank(victim))
	{
		CalculateTankReward();
		g_bTankAlive = false;
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidClient(attacker) || GetClientTeam(attacker) != 2)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_bTankAlive && IsPlayerTank(victim))
	{
		int damage = event.GetInt("dmg_health");
		g_iTankDamage[attacker] += damage;
	}
}

void CalculateTankReward()
{
	if (g_iTankRewardScale <= 0)
		return;
		
	int totalDamage = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 2)
		{
			totalDamage += g_iTankDamage[i];
		}
	}
	
	if (totalDamage <= 0)
		return;
	
	int dynamicScale = GetDynamicRewardScale(g_iTankRewardScale, g_iTankRewardIncrement);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;
		
		int playerDamage = g_iTankDamage[i];
		if (playerDamage <= 0)
			continue;
		
		float damagePercent = float(playerDamage) / float(totalDamage) * 100.0;
		
		int reward = RoundToNearest(float(dynamicScale) * damagePercent / 100.0);
		
		if (reward < 1 && playerDamage > 0)
			reward = 1;
		
		if (SetSurvivorHealth(i, reward))
		{
			if (g_bTankRewardDisplay)
			{
				int survivorCount = GetSurvivorCount();
				float multiplier = float(dynamicScale) / float(g_iTankRewardScale);
				PrintToChat(i, "\x04%s\x05你对坦克造成\x03%d\x05点伤害(\x04%.1f%%\x05)，当前生还者\x03%d\x05人，奖励系数\x04%.1f\x05倍，奖励\x03%d\x04hp\x05喵.", 
					PREFIX, playerDamage, damagePercent, survivorCount, multiplier, reward);
			}
		}
		else if (g_bTankRewardDisplay)
		{
			PrintToChat(i, "\x04%s\x05你对坦克造成\x03%d\x05点伤害(\x04%.1f%%\x05)，血量已达\x03%d\x04hp\x05上限喵.", 
				PREFIX, playerDamage, damagePercent, g_iMaxHealth);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[i] = 0;
	}
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witchId = event.GetInt("witchid");
	if (IsValidEntity(witchId))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			g_fSurvivorWitchHurt[i][witchId] = 0.0;
		}
	}
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsValidClient(attacker) && GetClientTeam(attacker) == 2 && IsWitch(victim))
	{
		float witchHealth = float(GetEntProp(victim, Prop_Data, "m_iHealth"));
		
		float actualDamage = damage > witchHealth ? (witchHealth < 0.0 ? 0.0 : witchHealth) : damage;
		
		int iBot = IsClientIdle(attacker);
		int actualAttacker = iBot != 0 ? iBot : attacker;
		
		if (IsValidClient(actualAttacker))
		{
			g_fSurvivorWitchHurt[actualAttacker][victim] += actualDamage;
		}
	}
	
	return Plugin_Continue;
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witchId = event.GetInt("witchid");
	
	if (IsValidEntity(witchId))
	{
		CalculateWitchReward(witchId);
	}
}

void CalculateWitchReward(int witchId)
{
	if (g_iWitchRewardScale <= 0)
		return;
		
	float totalDamage = 0.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 2)
		{
			totalDamage += g_fSurvivorWitchHurt[i][witchId];
		}
	}
	
	if (totalDamage <= 0.0)
		return;
	
	int dynamicScale = GetDynamicRewardScale(g_iWitchRewardScale, g_iWitchRewardIncrement);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;
		
		float playerDamage = g_fSurvivorWitchHurt[i][witchId];
		if (playerDamage <= 0.0)
			continue;
		
		float damagePercent = playerDamage / totalDamage * 100.0;
		
		int reward = RoundToNearest(float(dynamicScale) * damagePercent / 100.0);
		
		if (reward < 1 && playerDamage > 0.0)
			reward = 1;
		
		if (SetSurvivorHealth(i, reward))
		{
			if (g_bWitchRewardDisplay)
			{
				int survivorCount = GetSurvivorCount();
				float multiplier = float(dynamicScale) / float(g_iWitchRewardScale);
				PrintToChat(i, "\x04%s\x05你对女巫造成\x03%.0f\x05点伤害(\x04%.1f%%\x05)，当前生还者\x03%d\x05人，奖励系数\x04%.1f\x05倍，奖励\x03%d\x04hp\x05喵.", 
					PREFIX, playerDamage, damagePercent, survivorCount, multiplier, reward);
			}
		}
		else if (g_bWitchRewardDisplay)
		{
			PrintToChat(i, "\x04%s\x05你对女巫造成\x03%.0f\x05点伤害(\x04%.1f%%\x05)，血量已达\x03%d\x04hp\x05上限喵.", 
				PREFIX, playerDamage, damagePercent, g_iMaxHealth);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fSurvivorWitchHurt[i][witchId] = 0.0;
	}
}

bool SetSurvivorHealth(int client, int iReward)
{
	if (iReward <= 0)
		return false;
	
	int iHealth = GetClientHealth(client);
	int tHealth = GetPlayerTempHealth(client);
	
	if (tHealth == -1)
		tHealth = 0;
	
	int totalHealth = iHealth + tHealth + iReward;
	
	if (totalHealth > g_iMaxHealth)
	{
		int overflow = totalHealth - g_iMaxHealth;
		
		if (tHealth > 0)
		{
			if (tHealth >= overflow)
			{
				SetTempHealth(client, float(tHealth - overflow));
				SetEntProp(client, Prop_Send, "m_iHealth", iHealth + iReward);
				return true;
			}
			else
			{
				overflow -= tHealth;
				SetTempHealth(client, 0.0);
			}
		}
		
		if (overflow > 0)
		{
			iReward -= overflow;
			if (iReward < 0)
				iReward = 0;
		}
	}
	
	if (iReward > 0)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", iHealth + iReward);
		return true;
	}
	
	return false;
}

int GetPlayerTempHealth(int client)
{
	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(g_hPainPillsDecay))) - 1;
	return (tempHealth < 0) ? 0 : tempHealth;
}

void SetTempHealth(int client, float fHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

int IsClientIdle(int client) 
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;
	
	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

bool IsPlayerTank(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		if (L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
			return true;
	}
	return false;
}

bool IsWitch(int entity)
{
	if (!IsValidEntity(entity))
		return false;
	
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	return StrEqual(classname, "witch");
}

void ResetDamageRecords()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[i] = 0;
		for (int j = 0; j < 2048; j++)
		{
			g_fSurvivorWitchHurt[i][j] = 0.0;
		}
	}
	g_bTankAlive = false;
}