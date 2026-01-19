#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define BEAM_MODEL "materials/sprites/laserbeam.vmt"

#define PLUGIN_NAME         "l4d2_grenade_trails"
#define PLUGIN_VERSION      "1.1"
#define PLUGIN_AUTHOR       "JBcat"
#define PLUGIN_DESCRIPTION  "给投掷物、榴弹子弹添加轨迹"
#define PLUGIN_LINK         ""

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_LINK,
};

ConVar g_cvEnable;
ConVar g_cvLife;
ConVar g_cvWidth;
ConVar g_cvRandomMin;
ConVar g_cvRandomMax;
ConVar g_cvTrailColor[4];
ConVar g_cvTrailMode[4];

int g_iBeamSprite;

enum GrenadeType
{
    GrenadeType_Invalid = -1,
    GrenadeType_Molotov,           // 燃烧瓶
    GrenadeType_Pipe,              // 土质炸弹
    GrenadeType_Vomit,             // 胆汁炸弹
    GrenadeType_GrenadeLauncher,   // 榴弹发射器
    GrenadeType_Count
}

public void OnPluginStart()
{
    CreateConVar(PLUGIN_NAME ... "_version", PLUGIN_VERSION, "手雷轨迹插件版本", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    g_cvEnable = CreateConVar(PLUGIN_NAME ... "_enable", "1", "启用/禁用插件", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvLife = CreateConVar(PLUGIN_NAME ... "_life", "3.0", "轨迹持续时间(秒)", FCVAR_NOTIFY, true, 0.1, true, 10.0);
    g_cvWidth = CreateConVar(PLUGIN_NAME ... "_width", "0.5", "轨迹宽度", FCVAR_NOTIFY, true, 0.1, true, 5.0);
    
    g_cvRandomMin = CreateConVar(PLUGIN_NAME ... "_random_min", "50", "随机颜色最小值 (0-255)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    g_cvRandomMax = CreateConVar(PLUGIN_NAME ... "_random_max", "255", "随机颜色最大值 (0-255)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
    
    g_cvTrailMode[GrenadeType_Molotov] = CreateConVar("sm_trail_molotov", "1", "燃烧瓶轨迹: 0=关闭, 1=启用, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvTrailColor[GrenadeType_Molotov] = CreateConVar("sm_trail_molotov_color", "255 50 0", "燃烧瓶颜色 (红 绿 蓝)", FCVAR_NOTIFY);
    
    g_cvTrailMode[GrenadeType_Pipe] = CreateConVar("sm_trail_pipe", "1", "土质炸弹轨迹: 0=关闭, 1=启用, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvTrailColor[GrenadeType_Pipe] = CreateConVar("sm_trail_pipe_color", "0 0 255", "土质炸弹颜色 (红 绿 蓝)", FCVAR_NOTIFY);
    
    g_cvTrailMode[GrenadeType_Vomit] = CreateConVar("sm_trail_vomit", "1", "胆汁炸弹轨迹: 0=关闭, 1=启用, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvTrailColor[GrenadeType_Vomit] = CreateConVar("sm_trail_vomit_color", "0 255 0", "胆汁炸弹颜色 (红 绿 蓝)", FCVAR_NOTIFY);
    
    g_cvTrailMode[GrenadeType_GrenadeLauncher] = CreateConVar("sm_trail_grenade", "1", "榴弹发射器轨迹: 0=关闭, 1=启用, 2=随机颜色", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvTrailColor[GrenadeType_GrenadeLauncher] = CreateConVar("sm_trail_grenade_color", "255 255 0", "榴弹发射器颜色 (红 绿 蓝)", FCVAR_NOTIFY);
    
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
    
    int mode = g_cvTrailMode[grenadeType].IntValue;
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
    
    int mode = g_cvTrailMode[grenadeType].IntValue;
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
        char colorStr[32];
        g_cvTrailColor[grenadeType].GetString(colorStr, sizeof(colorStr));
        
        char parts[3][8];
        if (ExplodeString(colorStr, " ", parts, 3, 8) == 3)
        {
            color[0] = StringToInt(parts[0]);  // R
            color[1] = StringToInt(parts[1]);  // G
            color[2] = StringToInt(parts[2]);  // B
            color[3] = 255;                    // A
        }
        else
        {
            color = grenadeType == GrenadeType_Molotov ? {255, 50, 0, 255} :
                    grenadeType == GrenadeType_Pipe ? {0, 0, 255, 255} :
                    grenadeType == GrenadeType_Vomit ? {0, 255, 0, 255} :
                    {255, 255, 0, 255};
        }
    }
    else if (mode == 2)
    {
        int min = g_cvRandomMin.IntValue;
        int max = g_cvRandomMax.IntValue;
        
        if (min > max)
        {
            int temp = min;
            min = max;
            max = temp;
        }
        
        color[0] = GetRandomInt(min, max);  // R
        color[1] = GetRandomInt(min, max);  // G
        color[2] = GetRandomInt(min, max);  // B
        color[3] = 225;                     // A
    }
    
    float life = g_cvLife.FloatValue;
    float width = g_cvWidth.FloatValue;
    
    TE_SetupBeamFollow(entity, g_iBeamSprite, 0, life, width, width, 1, color);
    TE_SendToAll();
}