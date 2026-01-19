#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

int g_iTankHP[MAXPLAYERS+1];
int g_iTankHurt[MAXPLAYERS+1];
int g_iSurvivorTankHurt[MAXPLAYERS+1][MAXPLAYERS+1];
int g_iTankSlayer[MAXPLAYERS+1][MAXPLAYERS+1];

int g_iTankRewardScale;
bool g_bTankRewardDisplay;
ConVar 
	g_hTankRewardScale, 
	g_hTankRewardDisplay;

int g_iWitchRewardScale;
bool g_bWitchRewardDisplay;
ConVar 
	g_hWitchRewardScale, 
	g_hWitchRewardDisplay;

int g_iMaxHealth;
ConVar 
	g_hMaxHealth;

int g_iTankRewardIncrement;
int g_iWitchRewardIncrement;
ConVar 
	g_hTankRewardIncrement, 
	g_hWitchRewardIncrement;

int g_iTankRewardThreshold;
int g_iWitchRewardThreshold;
ConVar 
	g_hTankRewardThreshold, 
	g_hWitchRewardThreshold;

float g_fSurvivorWitchHurt[MAXPLAYERS + 1][2048 + 1];

Handle g_hPainPillsDecay;

#define CVAR_FLAGS			FCVAR_NOTIFY
#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"l4d2_tank_witch_rewards"
#define PLUGIN_VERSION		"1.3.0"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"坦克伤害、女巫伤害按比例奖励血量"
#define PLUGIN_LINK			""
#define MAX_SIZE			128

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

	g_hMaxHealth = CreateConVar("l4d2_damage_reward_max_health",			"120",	"设置幸存者获得伤害奖励后的最高血量上限", CVAR_FLAGS);

	g_hTankRewardDisplay = CreateConVar("l4d2_tank_reward_display",			"1",	"显示坦克伤害奖励提示", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hTankRewardScale = CreateConVar("l4d2_tank_reward_scale",			 	"200",	"坦克伤害比例换算系数：造成100%伤害时获得多少血量奖励(基础值)", CVAR_FLAGS, true, 0.0, false);
	g_hTankRewardIncrement = CreateConVar("l4d2_tank_reward_increment",		"50",	"每增加指定人数生还者，坦克奖励系数增加的百分比", CVAR_FLAGS, true, 0.0, false);
	g_hTankRewardThreshold = CreateConVar("l4d2_tank_reward_threshold",		"4",	"每多少名生还者增加一次坦克奖励系数(最小为1)", CVAR_FLAGS, true, 1.0);
	
	g_hWitchRewardDisplay = CreateConVar("l4d2_witch_reward_display",		"1",	"显示女巫伤害奖励提示", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hWitchRewardScale = CreateConVar("l4d2_witch_reward_scale",			"100",	"女巫伤害比例换算系数：造成100%伤害时获得多少血量奖励(基础值)", CVAR_FLAGS, true, 0.0, false);
	g_hWitchRewardIncrement = CreateConVar("l4d2_witch_reward_increment",	"25",	"每增加指定人数生还者，女巫奖励系数增加的百分比", CVAR_FLAGS, true, 0.0, false);
	g_hWitchRewardThreshold = CreateConVar("l4d2_witch_reward_threshold",	"4",	"每多少名生还者增加一次女巫奖励系数(最小为1)", CVAR_FLAGS, true, 1.0);
	
	g_hTankRewardScale.AddChangeHook(ConVarChangedSettings);
	g_hTankRewardDisplay.AddChangeHook(ConVarChangedSettings);
	g_hTankRewardIncrement.AddChangeHook(ConVarChangedSettings);
	g_hTankRewardThreshold.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardScale.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardDisplay.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardIncrement.AddChangeHook(ConVarChangedSettings);
	g_hWitchRewardThreshold.AddChangeHook(ConVarChangedSettings);
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
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iSurvivorTankHurt[client][i] = 0;
		g_iTankSlayer[client][i] = 0;
	}
	
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
	g_iTankRewardThreshold = g_hTankRewardThreshold.IntValue;
	
	g_iWitchRewardScale = g_hWitchRewardScale.IntValue;
	g_bWitchRewardDisplay = g_hWitchRewardDisplay.BoolValue;
	g_iWitchRewardIncrement = g_hWitchRewardIncrement.IntValue;
	g_iWitchRewardThreshold = g_hWitchRewardThreshold.IntValue;
	
	g_iMaxHealth = g_hMaxHealth.IntValue;
	
	if (g_iMaxHealth < 1)
		g_iMaxHealth = 1;
}

// 指数增长
int GetDynamicRewardScale(int baseScale, int incrementPercent, int threshold)
{
	int survivorCount = GetSurvivorCount();
	
	if (survivorCount <= threshold)
		return baseScale;
	
	int extraGroups = (survivorCount - 1) / threshold;
	
	float incrementMultiplier = 1.0 + (float(incrementPercent) / 100.0);

	float multiplier = Pow(incrementMultiplier, float(extraGroups));
	
	int dynamicScale = RoundToNearest(float(baseScale) * multiplier);
	
	return dynamicScale > 0 ? dynamicScale : baseScale;
}

/*// 线性增长
int GetDynamicRewardScale(int baseScale, int incrementPercent, int threshold)
{
	int survivorCount = GetSurvivorCount();
	
	if (survivorCount <= threshold)
		return baseScale;
	
	int extraGroups = (survivorCount - 1) / threshold;

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
		RequestFrame(IsTankHealthFrame, GetClientUserId(client));
		IsResetVariable(client);
	}
}

void IsTankHealthFrame(int client)
{
	if ((client = GetClientOfUserId(client)))
	{
		if (IsValidClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsPlayerTank(client))
		{
			for (int i = 1; i <= MaxClients; i++)
				g_iTankSlayer[i][client] = 0;
				
			g_iTankHP[client] = g_iTankHurt[client] = GetClientHealth(client);
		}
	}
}

void IsResetVariable(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iTankSlayer[i][client] = 0;
		g_iSurvivorTankHurt[i][client] = 0;
	}
	g_iTankHurt[client] = 0;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDmg = event.GetInt("dmg_health");
	
	if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		if(IsValidClient(victim) && GetClientTeam(victim) == 3 && IsPlayerAlive(victim) && IsPlayerTank(victim))
		{
			if (IsPlayerState(victim))
			{
				g_iTankHurt[victim] = GetClientHealth(victim);
				
				int iBot = IsClientIdle(attacker);
				int actualAttacker = !iBot ? attacker : iBot;
				
				if (IsValidClient(actualAttacker))
				{
					g_iSurvivorTankHurt[actualAttacker][victim] += iDmg;
				}
			}
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if(IsValidClient(victim) && GetClientTeam(victim) == 3 && IsPlayerTank(victim))
	{
		if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
		{
			int iBot = IsClientIdle(attacker);
			int actualAttacker = iBot != 0 ? iBot : attacker;
			
			if (IsValidClient(actualAttacker))
			{
				g_iTankSlayer[actualAttacker][victim] = 1;
				g_iSurvivorTankHurt[actualAttacker][victim] += g_iTankHurt[victim];
			}
		}
		
		CalculateTankReward(victim);
		IsResetVariable(victim);
	}
}

void CalculateTankReward(int tankClient)
{
	if (g_iTankRewardScale <= 0 || !IsValidClient(tankClient))
		return;
		
	int totalDamage = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);
			int actualPlayer = !iBot ? i : iBot;
			
			if (IsValidClient(actualPlayer))
			{
				totalDamage += g_iSurvivorTankHurt[actualPlayer][tankClient];
			}
		}
	}
	
	if (totalDamage <= 0)
		return;
	
	int dynamicScale = GetDynamicRewardScale(g_iTankRewardScale, g_iTankRewardIncrement, g_iTankRewardThreshold);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;
		
		int iBot = IsClientIdle(i);
		int actualPlayer = !iBot ? i : iBot;
		
		if (!IsValidClient(actualPlayer))
			continue;
		
		int playerDamage = g_iSurvivorTankHurt[actualPlayer][tankClient];
		if (playerDamage <= 0)
			continue;
		
		float damagePercent = float(playerDamage) / float(totalDamage) * 100.0;
		
		int reward = RoundToNearest(float(dynamicScale) * damagePercent / 100.0);
		
		if (reward < 1 && playerDamage > 0)
			reward = 1;
		
		if (SetSurvivorHealth(actualPlayer, reward))
		{
			if (g_bTankRewardDisplay)
			{
				char sReward[32], sDamage[32], sPercent[32];
				FormatEx(sReward, sizeof(sReward), "%d", reward);
				FormatEx(sDamage, sizeof(sDamage), "%d", playerDamage);
				FormatEx(sPercent, sizeof(sPercent), "%.1f", damagePercent);
				
				int iMaxReward = strlen(sReward);
				int iMaxDamage = strlen(sDamage);
				int iMaxPercent = strlen(sPercent);
				
				char sRewardSpaces[16] = "", sDamageSpaces[16] = "", sPercentSpaces[16] = "";
				
				for (int j = 0; j < (4 - iMaxReward); j++) Format(sRewardSpaces, sizeof(sRewardSpaces), "%s ", sRewardSpaces);
				for (int j = 0; j < (6 - iMaxDamage); j++) Format(sDamageSpaces, sizeof(sDamageSpaces), "%s ", sDamageSpaces);
				for (int j = 0; j < (6 - iMaxPercent); j++) Format(sPercentSpaces, sizeof(sPercentSpaces), "%s ", sPercentSpaces);
				
				PrintToChat(actualPlayer, "\x04%s\x05你对坦克造成%s\x03%d\x05点伤害(%s\x04%.1f%%\x05)，奖励%s\x03%d\x04hp\x05喵.", 
					PREFIX, sDamageSpaces, playerDamage, sPercentSpaces, damagePercent, sRewardSpaces, reward);
			}
		}
		else if (g_bTankRewardDisplay)
		{
			char sDamage[32], sPercent[32];
			FormatEx(sDamage, sizeof(sDamage), "%d", playerDamage);
			FormatEx(sPercent, sizeof(sPercent), "%.1f", damagePercent);
			
			int iMaxDamage = strlen(sDamage);
			int iMaxPercent = strlen(sPercent);
			
			char sDamageSpaces[16] = "", sPercentSpaces[16] = "";
			
			for (int j = 0; j < (6 - iMaxDamage); j++) Format(sDamageSpaces, sizeof(sDamageSpaces), "%s ", sDamageSpaces);
			for (int j = 0; j < (6 - iMaxPercent); j++) Format(sPercentSpaces, sizeof(sPercentSpaces), "%s ", sPercentSpaces);
			
			PrintToChat(actualPlayer, "\x04%s\x05你对坦克造成%s\x03%d\x05点伤害(%s\x04%.1f%%\x05)，血量已达\x03%d\x04hp\x05上限喵.", 
				PREFIX, sDamageSpaces, playerDamage, sPercentSpaces, damagePercent, g_iMaxHealth);
		}
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
	
	int dynamicScale = GetDynamicRewardScale(g_iWitchRewardScale, g_iWitchRewardIncrement, g_iWitchRewardThreshold);
	
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
				char sReward[32], sDamage[32], sPercent[32];
				FormatEx(sReward, sizeof(sReward), "%d", reward);
				FormatEx(sDamage, sizeof(sDamage), "%.0f", playerDamage);
				FormatEx(sPercent, sizeof(sPercent), "%.1f", damagePercent);
				
				int iMaxReward = strlen(sReward);
				int iMaxDamage = strlen(sDamage);
				int iMaxPercent = strlen(sPercent);
				
				char sRewardSpaces[16] = "", sDamageSpaces[16] = "", sPercentSpaces[16] = "";
				
				for (int j = 0; j < (4 - iMaxReward); j++) Format(sRewardSpaces, sizeof(sRewardSpaces), "%s ", sRewardSpaces);
				for (int j = 0; j < (6 - iMaxDamage); j++) Format(sDamageSpaces, sizeof(sDamageSpaces), "%s ", sDamageSpaces);
				for (int j = 0; j < (6 - iMaxPercent); j++) Format(sPercentSpaces, sizeof(sPercentSpaces), "%s ", sPercentSpaces);
				
				PrintToChat(i, "\x04%s\x05你对女巫造成%s\x03%.0f\x05点伤害(%s\x04%.1f%%\x05)，奖励%s\x03%d\x04hp\x05喵.", 
					PREFIX, sDamageSpaces, playerDamage, sPercentSpaces, damagePercent, sRewardSpaces, reward);
			}
		}
		else if (g_bWitchRewardDisplay)
		{
			char sDamage[32], sPercent[32];
			FormatEx(sDamage, sizeof(sDamage), "%.0f", playerDamage);
			FormatEx(sPercent, sizeof(sPercent), "%.1f", damagePercent);
			
			int iMaxDamage = strlen(sDamage);
			int iMaxPercent = strlen(sPercent);
			
			char sDamageSpaces[16] = "", sPercentSpaces[16] = "";
			
			for (int j = 0; j < (6 - iMaxDamage); j++) Format(sDamageSpaces, sizeof(sDamageSpaces), "%s ", sDamageSpaces);
			for (int j = 0; j < (6 - iMaxPercent); j++) Format(sPercentSpaces, sizeof(sPercentSpaces), "%s ", sPercentSpaces);
			
			PrintToChat(i, "\x04%s\x05你对女巫造成%s\x03%.0f\x05点伤害(%s\x04%.1f%%\x05)，血量已达\x03%d\x04hp\x05上限喵.", 
				PREFIX, sDamageSpaces, playerDamage, sPercentSpaces, damagePercent, g_iMaxHealth);
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
		g_iTankHP[i] = 0;
		g_iTankHurt[i] = 0;
		for (int j = 1; j <= MaxClients; j++)
		{
			g_iSurvivorTankHurt[i][j] = 0;
			g_iTankSlayer[i][j] = 0;
		}
		for (int j = 0; j < 2048; j++)
		{
			g_fSurvivorWitchHurt[i][j] = 0.0;
		}
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}