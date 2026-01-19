#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <sdktools>

#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"remaining_ammo_display"
#define PLUGIN_VERSION		"1.0"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"剩余弹药显示"
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
	HookEvent("weapon_reload", Event_WeaponReload, EventHookMode_Post);
}

public Action Event_WeaponReload(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (!IsValidEntity(weapon))
		return Plugin_Continue;
	
	int bakammo = GetWeaponBackupAmmo(client, weapon);
	
	if (bakammo > 950)
	{
		if (bakammo < 980)
			PrintToChat(client, "\x04%s\x05当剩余弹药低于\x03950\x05后将不再提示", PREFIX);
		
		PrintToChat(client, "\x04%s\x05剩余弹药: \x03%d", PREFIX, bakammo);
	}
	
	return Plugin_Continue;
}

int GetWeaponBackupAmmo(int client, int weapon)
{
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"));
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}