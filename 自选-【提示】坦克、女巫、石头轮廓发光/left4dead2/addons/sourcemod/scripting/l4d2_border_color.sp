#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define ENTITY_TANK "tank"
#define ENTITY_WITCH "witch"
#define ENTITY_TANK_ROCK "tank_rock"
#define GLOW_TYPE 3
#define GLOW_RANGE 0
#define PLUGIN_NAME			"l4d2_border_color"
#define PLUGIN_VERSION		"1.1"
#define PLUGIN_AUTHOR		"JBcat"
#define PLUGIN_DESCRIPTION	"坦克、女巫、石头轮廓发光"
#define PLUGIN_LINK			""

public Plugin myinfo = 
{
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url			= PLUGIN_LINK,
};

enum EntityType
{
	ENTITY_TYPE_INVALID = -1,
	ENTITY_TYPE_TANK = 0,
	ENTITY_TYPE_WITCH,
	ENTITY_TYPE_TANKROCK,
	ENTITY_TYPE_COUNT
}

StringMap g_smEntityGlow;
ConVar g_hCvarColors[ENTITY_TYPE_COUNT];
int g_iCvarColors[ENTITY_TYPE_COUNT];

public void OnPluginStart() 
{
	CreateConVar(PLUGIN_NAME ... "_version", PLUGIN_VERSION, "插件版本", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_hCvarColors[ENTITY_TYPE_TANK] = CreateConVar(PLUGIN_NAME ... "_tank", 			"220 20 60", 	"Tank轮廓颜色 (格式: R G B, 0-255, 留空=禁用)", FCVAR_NOTIFY);
	g_hCvarColors[ENTITY_TYPE_WITCH] = CreateConVar(PLUGIN_NAME ... "_witch", 			"248 248 255", 	"Witch轮廓颜色 (格式: R G B, 0-255, 留空=禁用)", FCVAR_NOTIFY);
	g_hCvarColors[ENTITY_TYPE_TANKROCK] = CreateConVar(PLUGIN_NAME ... "_tankstone", 	"255 105 180", 	"Tank Rock轮廓颜色 (格式: R G B, 0-255, 留空=禁用)", FCVAR_NOTIFY);

	AutoExecConfig(true, PLUGIN_NAME);

	for (int i = 0; i < ENTITY_TYPE_COUNT; i++)
	{
		g_hCvarColors[i].AddChangeHook(OnConVarChanged);
	}
	
	g_smEntityGlow = new StringMap();
	g_smEntityGlow.SetValue(ENTITY_TANK, ENTITY_TYPE_TANK);
	g_smEntityGlow.SetValue(ENTITY_WITCH, ENTITY_TYPE_WITCH);
	g_smEntityGlow.SetValue(ENTITY_TANK_ROCK, ENTITY_TYPE_TANKROCK);
	
	InitColors();
}

public void OnMapStart()
{
	InitColors();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	InitColors();
}

void InitColors()
{
	char sColor[16];
	
	for (int i = 0; i < ENTITY_TYPE_COUNT; i++)
	{
		g_hCvarColors[i].GetString(sColor, sizeof(sColor));
		g_iCvarColors[i] = ParseColor(sColor);
	}
}

int ParseColor(const char[] sColor)
{
	if (strlen(sColor) == 0)
		return 0;
	
	char sColors[3][4];
	int parts = ExplodeString(sColor, " ", sColors, 3, 4);
	
	if (parts != 3)
		return 0;
	
	int r = StringToInt(sColors[0]);
	int g = StringToInt(sColors[1]);
	int b = StringToInt(sColors[2]);
	
	if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255)
		return 0;
	
	return r + (g << 8) + (b << 16);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= 0 || !IsValidEntity(entity))
		return;
	EntityType entityType;
	if (!g_smEntityGlow.GetValue(classname, entityType))
		return;
	if (g_iCvarColors[entityType] <= 0)
		return;
	SetEntityGlow(entity, g_iCvarColors[entityType]);
}

void SetEntityGlow(int entity, int color)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", GLOW_TYPE);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	
	if (HasEntProp(entity, Prop_Send, "m_nGlowRange"))
		SetEntProp(entity, Prop_Send, "m_nGlowRange", GLOW_RANGE);
	
	if (HasEntProp(entity, Prop_Send, "m_nGlowRangeMin"))
		SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
	
	if (HasEntProp(entity, Prop_Send, "m_nGlowRangeMax"))
		SetEntProp(entity, Prop_Send, "m_nGlowRangeMax", 99999);
}