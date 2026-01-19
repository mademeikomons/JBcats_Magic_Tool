#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define CVAR_FLAGS FCVAR_NOTIFY

int g_iDefibrillator, g_iReviveSuccess, g_iHealSuccess, g_iSurvivorRescued, g_iLimitHealth;
ConVar g_hDefibrillator, g_hReviveSuccess, g_hHealSuccess, g_hSurvivorRescued, g_hLimitHealth;

#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"l4d2_medical_rescue_rewards"
#define PLUGIN_VERSION		"1.0"
#define PLUGIN_AUTHOR		"豆瓣酱な、JBcat"
#define PLUGIN_DESCRIPTION	"电击器复活、治愈队友、救起倒地、营救队友奖励血量"
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
	HookEvent("defibrillator_used", Event_DefibrillatorUsed); //电击
	HookEvent("revive_success", Event_ReviveSuccess); //倒地
	HookEvent("heal_success", Event_HealSuccess); //治愈
	HookEvent("survivor_rescued", Event_SurvivorRescued); //营救
	
	g_hDefibrillator = CreateConVar(PLUGIN_NAME ... "_defibrillator", 		"15", 	"电击复活队友的幸存者奖励多少血. 0=禁用(设置小于0等于启用加血但是不显示提示).", CVAR_FLAGS);
	g_hReviveSuccess = CreateConVar(PLUGIN_NAME ... "_reviveSuccess", 		"15", 	"救起倒地的幸存者奖励多少血. 0=禁用(设置小于0等于启用加血但是不显示提示).", CVAR_FLAGS);
	g_hHealSuccess = CreateConVar(PLUGIN_NAME ... "_healSuccess", 			"15", 	"治愈队友的幸存者奖励多少血. 0=禁用(设置小于0等于启用加血但是不显示提示).", CVAR_FLAGS);
	g_hSurvivorRescued = CreateConVar(PLUGIN_NAME ... "_survivorRescued", 	"15", 	"营救队友的幸存者奖励多少血. 0=禁用(设置小于0等于启用加血但是不显示提示).", CVAR_FLAGS);
	g_hLimitHealth = CreateConVar(PLUGIN_NAME ... "_health_Limit", 			"100", 	"设置幸存者获得血量奖励的最高上限.", CVAR_FLAGS);
	
	g_hDefibrillator.AddChangeHook(ConVarChangedHealth);
	g_hReviveSuccess.AddChangeHook(ConVarChangedHealth);
	g_hHealSuccess.AddChangeHook(ConVarChangedHealth);
	g_hSurvivorRescued.AddChangeHook(ConVarChangedHealth);
	g_hLimitHealth.AddChangeHook(ConVarChangedHealth);
	
	AutoExecConfig(true, PLUGIN_NAME);
}

public void OnMapStart()
{
	GetConVarChange();
}

public void ConVarChangedHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarChange();
}

void GetConVarChange()
{
	g_iDefibrillator = g_hDefibrillator.IntValue;
	g_iReviveSuccess = g_hReviveSuccess.IntValue;
	g_iHealSuccess = g_hHealSuccess.IntValue;
	g_iSurvivorRescued = g_hSurvivorRescued.IntValue;
	g_iLimitHealth = g_hLimitHealth.IntValue;
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(g_iDefibrillator != 0 && IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(IsValidClient(subject) && GetClientTeam(subject) == 2 && client != subject)
		{
			int iReward = g_iDefibrillator;
			if(SetSurvivorHealth(client, GetRewardHealth(iReward), g_iLimitHealth))
			{
				if(iReward > 0)
					PrintToChatAll("\x04%s\x03%s\x05复活了\x03%s\x05，奖励\x03%d\x04hp\x05喵.", PREFIX, GetTrueName(client), GetTrueName(subject), GetRewardHealth(iReward));
			}
			else if(iReward > 0)
			{
				PrintToChatAll("\x04%s\x03%s\x05复活了\x03%s\x05，血量已达\x03%d\x04hp\x05上限喵.", PREFIX, GetTrueName(client), GetTrueName(subject), g_iLimitHealth);
			}
		}
	}
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(g_iReviveSuccess != 0 && IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(IsValidClient(subject) && GetClientTeam(subject) == 2 && client != subject)
		{
			int iReward = g_iReviveSuccess;
			if(SetSurvivorHealth(client, GetRewardHealth(iReward), g_iLimitHealth))
			{
				if(iReward > 0)
					PrintToChatAll("\x04%s\x03%s\x05救起了\x03%s\x05，奖励\x03%d\x04hp\x05喵.", PREFIX, GetTrueName(client), GetTrueName(subject), GetRewardHealth(iReward));
			}
			else if(iReward > 0)
			{
				PrintToChatAll("\x04%s\x03%s\x05救起了\x03%s\x05，血量已达\x03%d\x04hp\x05上限喵.", PREFIX, GetTrueName(client), GetTrueName(subject), g_iLimitHealth);
			}
		}
	}
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(g_iHealSuccess != 0 && IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(IsValidClient(subject) && GetClientTeam(subject) == 2 && client != subject)
		{
			int iReward = g_iHealSuccess;
			if(SetSurvivorHealth(client, GetRewardHealth(iReward), g_iLimitHealth))
			{
				if(iReward > 0)
					PrintToChatAll("\x04%s\x03%s\x05治疗了\x03%s\x05，奖励\x03%d\x04hp\x05喵.", PREFIX, GetTrueName(client), GetTrueName(subject), GetRewardHealth(iReward));
			}
			else if(iReward > 0)
			{
				PrintToChatAll("\x04%s\x03%s\x05治疗了\x03%s\x05，血量已达\x03%d\x04hp\x05上限喵.", PREFIX, GetTrueName(client), GetTrueName(subject), g_iLimitHealth);
			}
		}
	}
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int rescuer = GetClientOfUserId(event.GetInt("rescuer"));
	int client = GetClientOfUserId(event.GetInt("victim"));

	if(g_iSurvivorRescued != 0 && IsValidClient(client) && GetClientTeam(client) == 2)
	{
		if(IsValidClient(rescuer) && GetClientTeam(rescuer) == 2 && client != rescuer)
		{
			int iReward = g_iSurvivorRescued;
			if(SetSurvivorHealth(rescuer, GetRewardHealth(iReward), g_iLimitHealth))
			{
				if(iReward > 0)
					PrintToChatAll("\x04%s\x03%s\x05营救了\x03%s\x05，奖励\x03%d\x04hp\x05喵.", PREFIX, GetTrueName(rescuer), GetTrueName(client), GetRewardHealth(iReward));
			}
			else if(iReward > 0)
			{
				PrintToChatAll("\x04%s\x03%s\x05营救了\x03%s\x05，血量已达\x03%d\x04hp\x05上限喵.", PREFIX, GetTrueName(rescuer), GetTrueName(client), g_iLimitHealth);
			}
		}
	}
}

bool SetSurvivorHealth(int client, int iReward, int iMaxHealth)
{
	int iHealth = GetClientHealth(client);
	int tHealth = GetPlayerTempHealth(client);
	
	if (tHealth == -1)
		tHealth = 0;
	
	if (iHealth + tHealth + iReward > iMaxHealth)
	{
		float overhealth = float(iHealth + tHealth + iReward - iMaxHealth);
		float fakehealth = (tHealth < overhealth) ? 0.0 : float(tHealth) - overhealth;
		
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
	}
	
	if ((iHealth + iReward) < iMaxHealth)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", iHealth + iReward);
		return true;
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iHealth", (iHealth > iMaxHealth) ? iHealth : iMaxHealth);
	}
	return false;
}

int GetRewardHealth(int iReward)
{
	return (iReward < 0) ? iReward * -1 : iReward;
}

char[] GetTrueName(int client)
{
	char sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(sName, sizeof(sName), "闲置:%N", Bot);
	else
		GetClientName(client, sName, sizeof(sName));
	return sName;
}

int GetPlayerTempHealth(int client)
{
	static Handle painPillsDecayCvar = null;
	if (painPillsDecayCvar == null)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == null)
			return -1;
	}
	
	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return (tempHealth < 0) ? 0 : tempHealth;
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