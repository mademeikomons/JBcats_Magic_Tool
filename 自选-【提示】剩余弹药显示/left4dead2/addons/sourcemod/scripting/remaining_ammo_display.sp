#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <sdktools>

#define PREFIX				"[鱼猫猫]"
#define PLUGIN_NAME			"remaining_ammo_display"
#define PLUGIN_VERSION		"1.2"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"剩余弹药显示"
#define PLUGIN_LINK			""

StringMap allowedWeapons;
StringMap ignoreWeapons;

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
	allowedWeapons = new StringMap();
	allowedWeapons.SetValue("smg", true);
	allowedWeapons.SetValue("smg_silenced", true);
	allowedWeapons.SetValue("smg_mp5", true);

	allowedWeapons.SetValue("pumpshotgun", true);
	allowedWeapons.SetValue("shotgun_chrome", true);
	
	allowedWeapons.SetValue("rifle", true);
	allowedWeapons.SetValue("rifle_ak47", true);
	allowedWeapons.SetValue("rifle_desert", true);
	allowedWeapons.SetValue("rifle_sg552", true);

	allowedWeapons.SetValue("autoshotgun", true);
	allowedWeapons.SetValue("shotgun_spas", true);

	allowedWeapons.SetValue("hunting_rifle", true);
	allowedWeapons.SetValue("sniper_military", true);
	
	allowedWeapons.SetValue("sniper_scout", true);
	allowedWeapons.SetValue("sniper_awp", true);
	
	allowedWeapons.SetValue("grenade_launcher", true);
	allowedWeapons.SetValue("rifle_m60", true);
	
	ignoreWeapons = new StringMap();
	ignoreWeapons.SetValue("pistol", true); 
	ignoreWeapons.SetValue("dual_pistols", true);
	ignoreWeapons.SetValue("pistol_magnum", true);
	ignoreWeapons.SetValue("chainsaw", true);
	ignoreWeapons.SetValue("melee", true);

	HookEvent("weapon_reload", Event_WeaponReload, EventHookMode_Post);
}

public Action Event_WeaponReload(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
		return Plugin_Continue;
	
	char weaponClass[64];
	GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
	
	char baseWeapon[64];
	strcopy(baseWeapon, sizeof(baseWeapon), weaponClass[7]);
	
	bool isIgnored;
	if (ignoreWeapons.GetValue(baseWeapon, isIgnored) && isIgnored)
		return Plugin_Continue;
	
	bool isAllowed;
	if (!allowedWeapons.GetValue(baseWeapon, isAllowed) || !isAllowed)
		return Plugin_Continue;
	
	int bakammo = GetWeaponBackupAmmo(client, weapon);
	
	if (bakammo > 950)
	{
		if (bakammo < 1020)
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