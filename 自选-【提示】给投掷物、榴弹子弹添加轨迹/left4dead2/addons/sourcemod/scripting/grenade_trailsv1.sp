#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define BEAM_MODEL "materials/sprites/laserbeam.vmt"

#define PLUGIN_NAME			"l4d2_grenade_trails"
#define PLUGIN_VERSION		"1.0"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"给投掷物、榴弹子弹添加轨迹"
#define PLUGIN_LINK			""

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url			= PLUGIN_LINK,
};

ConVar g_cvEnable;
ConVar g_cvLife;
ConVar g_cvWidth;

enum GrenadeType
{
	GrenadeType_Invalid = -1,
	GrenadeType_Molotov,			// 燃烧瓶
	GrenadeType_Pipe,		   		// 土质炸弹
	GrenadeType_Vomit,		  		// 胆汁炸弹
	GrenadeType_GrenadeLauncher, 	// 榴弹发射器
	GrenadeType_Count
}

int g_iDefaultColors[GrenadeType_Count][4];
int g_iMinColors[GrenadeType_Count][4];
int g_iMaxColors[GrenadeType_Count][4];

ConVar g_cvModes[GrenadeType_Count];

int g_iBeamSprite;

public void OnPluginStart()
{
	CreateConVar(PLUGIN_NAME ... "_version", PLUGIN_VERSION, "手雷轨迹插件版本", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cvEnable = CreateConVar(PLUGIN_NAME ... "_enable", "1", "启用/禁用插件", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLife = CreateConVar(PLUGIN_NAME ... "_life", "3.0", "轨迹持续时间(秒)", FCVAR_NOTIFY, true, 0.1, true, 10.0);
	g_cvWidth = CreateConVar(PLUGIN_NAME ... "_width", "0.5", "轨迹宽度", FCVAR_NOTIFY, true, 0.1, true, 5.0);
	
	g_cvModes[GrenadeType_Molotov] = CreateConVar(PLUGIN_NAME ... "_molotov_mode", "2", "燃烧瓶轨迹模式: 0=关闭, 1=固定颜色, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	CreateColorConVar(PLUGIN_NAME ... "_molotov_color", "255 0 0 255", "燃烧瓶固定颜色 (红 绿 蓝 透明度)", g_iDefaultColors[GrenadeType_Molotov]);
	CreateMinMaxConVars(PLUGIN_NAME ... "_molotov_random", "100 150 0 255", "255 150 0 255", "燃烧瓶随机颜色范围", g_iMinColors[GrenadeType_Molotov], g_iMaxColors[GrenadeType_Molotov]);
	
	g_cvModes[GrenadeType_Pipe] = CreateConVar(PLUGIN_NAME ... "_pipe_mode", "2", "土质炸弹轨迹模式: 0=关闭, 1=固定颜色, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	CreateColorConVar(PLUGIN_NAME ... "_pipe_color", "0 0 255 255", "土质炸弹固定颜色 (红 绿 蓝 透明度)", g_iDefaultColors[GrenadeType_Pipe]);
	CreateMinMaxConVars(PLUGIN_NAME ... "_pipe_random", "100 0 200 255", "150 0 255 255", "土质炸弹随机颜色范围", g_iMinColors[GrenadeType_Pipe], g_iMaxColors[GrenadeType_Pipe]);
	
	g_cvModes[GrenadeType_Vomit] = CreateConVar(PLUGIN_NAME ... "_vomit_mode", "2", "胆汁炸弹轨迹模式: 0=关闭, 1=固定颜色, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	CreateColorConVar(PLUGIN_NAME ... "_vomit_color", "0 255 0 255", "胆汁炸弹固定颜色 (红 绿 蓝 透明度)", g_iDefaultColors[GrenadeType_Vomit]);
	CreateMinMaxConVars(PLUGIN_NAME ... "_vomit_random", "0 200 100 255", "0 255 150 255", "胆汁炸弹随机颜色范围", g_iMinColors[GrenadeType_Vomit], g_iMaxColors[GrenadeType_Vomit]);
	
	g_cvModes[GrenadeType_GrenadeLauncher] = CreateConVar(PLUGIN_NAME ... "_grenade_mode", "2", "榴弹发射器轨迹模式: 0=关闭, 1=固定颜色, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	CreateColorConVar(PLUGIN_NAME ... "_grenade_color", "255 255 0 255", "榴弹发射器固定颜色 (红 绿 蓝 透明度)", g_iDefaultColors[GrenadeType_GrenadeLauncher]);
	CreateMinMaxConVars(PLUGIN_NAME ... "_grenade_random", "100 200 0 255", "150 255 0 255", "榴弹发射器随机颜色范围", g_iMinColors[GrenadeType_GrenadeLauncher], g_iMaxColors[GrenadeType_GrenadeLauncher]);
	
	AutoExecConfig(true, PLUGIN_NAME);
}

public void OnMapStart()
{
	g_iBeamSprite = PrecacheModel(BEAM_MODEL);
}



public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_cvEnable.BoolValue)
		return;
	
	GrenadeType grenadeType = GetGrenadeType(classname);
	if (grenadeType == GrenadeType_Invalid)
		return;
	
	int mode = g_cvModes[grenadeType].IntValue;
	if (mode == 0) 
		return;
	
	RequestFrame(OnGrenadeSpawned, EntIndexToEntRef(entity));
}

public void OnGrenadeSpawned(any data)
{
	int entity = EntRefToEntIndex(data);
	if (entity == INVALID_ENT_REFERENCE)
		return;
	
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return;
	
	GrenadeType grenadeType = GetGrenadeType(classname);
	if (grenadeType == GrenadeType_Invalid)
		return;
	
	int mode = g_cvModes[grenadeType].IntValue;
	if (mode == 0)
		return;
	
	CreateTrail(entity, grenadeType, mode);
}

GrenadeType GetGrenadeType(const char[] classname)
{
	if (StrContains(classname, "molotov_projectile", false) != -1)
		return GrenadeType_Molotov;
	else if (StrContains(classname, "pipe_bomb_projectile", false) != -1)
		return GrenadeType_Pipe;
	else if (StrContains(classname, "vomitjar_projectile", false) != -1)
		return GrenadeType_Vomit;
	else if (StrContains(classname, "grenade_launcher_projectile", false) != -1)
		return GrenadeType_GrenadeLauncher;
	
	return GrenadeType_Invalid;
}

void CreateTrail(int entity, GrenadeType grenadeType, int mode)
{
	int color[4];
	
	if (mode == 1)
	{
		color = g_iDefaultColors[grenadeType];
	}
	else if (mode == 2)
	{
		for (int i = 0; i < 4; i++)
		{
			int min = g_iMinColors[grenadeType][i];
			int max = g_iMaxColors[grenadeType][i];
			color[i] = GetRandomInt(min, max);
		}
	}
	
	float life = g_cvLife.FloatValue;
	float width = g_cvWidth.FloatValue;
	
	TE_SetupBeamFollow(entity, g_iBeamSprite, 0, life, width, width, 1, color);
	TE_SendToAll();
}

void CreateColorConVar(const char[] name, const char[] defaultValue, const char[] description, int colorArray[4])
{
	char buffer[64];
	
	char parts[4][8];
	if (ExplodeString(defaultValue, " ", parts, 4, 8) == 4)
	{
		// 红色
		Format(buffer, sizeof(buffer), "%s_r", name);
		ConVar cv = CreateConVar(buffer, parts[0], description, FCVAR_NOTIFY);
		colorArray[0] = StringToInt(parts[0]);
		
		// 绿色
		Format(buffer, sizeof(buffer), "%s_g", name);
		cv = CreateConVar(buffer, parts[1], description, FCVAR_NOTIFY);
		colorArray[1] = StringToInt(parts[1]);
		
		// 蓝色
		Format(buffer, sizeof(buffer), "%s_b", name);
		cv = CreateConVar(buffer, parts[2], description, FCVAR_NOTIFY);
		colorArray[2] = StringToInt(parts[2]);
		
		// 透明度
		Format(buffer, sizeof(buffer), "%s_a", name);
		cv = CreateConVar(buffer, parts[3], description, FCVAR_NOTIFY);
		colorArray[3] = StringToInt(parts[3]);
	}
}

void CreateMinMaxConVars(const char[] baseName, const char[] minDefault, const char[] maxDefault, 
						 const char[] description, int minArray[4], int maxArray[4])
{
	char buffer[64];
	
	char minParts[4][8];
	if (ExplodeString(minDefault, " ", minParts, 4, 8) == 4)
	{
		for (int i = 0; i < 4; i++)
		{
			char component = (i == 0 ? 'r' : i == 1 ? 'g' : i == 2 ? 'b' : 'a');
			Format(buffer, sizeof(buffer), "%s_min_%c", baseName, component);
			ConVar cv = CreateConVar(buffer, minParts[i], description, FCVAR_NOTIFY);
			minArray[i] = StringToInt(minParts[i]);
		}
	}
	
	char maxParts[4][8];
	if (ExplodeString(maxDefault, " ", maxParts, 4, 8) == 4)
	{
		for (int i = 0; i < 4; i++)
		{
			char component = (i == 0 ? 'r' : i == 1 ? 'g' : i == 2 ? 'b' : 'a');
			Format(buffer, sizeof(buffer), "%s_max_%c", baseName, component);
			ConVar cv = CreateConVar(buffer, maxParts[i], description, FCVAR_NOTIFY);
			maxArray[i] = StringToInt(maxParts[i]);
		}
	}
}