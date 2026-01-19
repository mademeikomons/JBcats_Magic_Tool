#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define CVAR_FLAGS FCVAR_NOTIFY

Handle g_hRestartTimer;
int	g_iEmptyTime;
ConVar g_hEnable, g_hLog, g_hSystem, g_hType, g_hCheckInterval, g_hRestartDelay;
char   g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name		= "空服X分钟自动重启 + 管理员炸服",
	author		= "UoNeko",
	description	= "服务器无人时自动重启 + 输入!boom执行炸服重启",
	version		= "1.4",
	url			= ""
};

public void OnPluginStart()
{
	g_hEnable			= CreateConVar("l4d2_restart_enable", 	"1", 	"启用空服自动重启功能 0=禁用, 1=启用", CVAR_FLAGS);
	g_hCheckInterval	= CreateConVar("l4d2_restart_check", 	"5.0", 	"空服检测间隔时间（秒）", CVAR_FLAGS, true, 1.0);
	g_hRestartDelay		= CreateConVar("l4d2_restart_delay", 	"60", 	"空服后重启延迟时间（秒）", CVAR_FLAGS, true, 1.0);
	g_hLog				= CreateConVar("l4d2_restart_log", 		"1", 	"记录重启日志 0=禁用, 1=启用", CVAR_FLAGS);
	g_hSystem			= CreateConVar("l4d2_restart_system", 	"3", 	"允许的系统类型: 1=Linux, 2=Windows, 3=Both", CVAR_FLAGS);
	g_hType				= CreateConVar("l4d2_restart_type", 	"3", 	"服务器类型: 1=专用, 2=本地, 3=Both", CVAR_FLAGS);


	RegAdminCmd("sm_boom", Command_Restart, ADMFLAG_ROOT, "重启服务器");
	
	AutoExecConfig(true, "l4d2_restart");
	CreateTimer(g_hCheckInterval.FloatValue, Timer_CheckPlayers, _, TIMER_REPEAT);
}

public Action Command_Restart(int client, int args)
{
	int iSystem = L4D_GetServerOS();
	bool isDedicated = IsDedicatedServer();
	
	if (!CheckSystem(iSystem) || !CheckServerType(isDedicated))
	{
		ReplyToCommand(client, "当前服务器配置不允许重启");
		return Plugin_Handled;
	}
	//PrintToChatAll("\x05[鱼猫猫] \x03服务器爆炸了！");
	if (g_hLog.BoolValue)
	{
		char date[16], time[16], system[16], type[16], adminName[32];
		FormatTime(date, sizeof(date), "%y%m%d", GetTime());
		FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
		BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "/logs/ReStart%s.log", date);

		FormatEx(system, sizeof(system), iSystem ? "Linux" : "Windows");
		FormatEx(type, sizeof(type), isDedicated ? "专用" : "本地");
		GetClientName(client, adminName, sizeof(adminName));

		LogToFile(g_sLogPath, "[%s] [手动重启] 系统: %s | 类型: %s | 由管理员 %s 执行",
				  time, system, type, adminName);
	}
	
	KickAllPlayers();
	
	CreateTimer(1.0, Timer_DelayedRestart);
	
	return Plugin_Handled;
}

void KickAllPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			KickClient(i, "服务器爆炸了！！！");
		}
	}
}

public Action Timer_DelayedRestart(Handle timer)
{
	RestartServer();
	return Plugin_Stop;
}

public Action Timer_CheckPlayers(Handle timer)
{
	if (!g_hEnable.BoolValue) return Plugin_Continue;

	int	players = GetRealClientCount();
	float fDelay  = g_hRestartDelay.FloatValue;

	if (players == 0)
	{
		if (g_hRestartTimer == null)
		{
			g_iEmptyTime	= GetTime();
			g_hRestartTimer = CreateTimer(fDelay, Timer_RestartServer);
			LogMessage("检测到男娘跑光了，%.1f秒后重启...", fDelay);
		}
	}
	else
	{
		if (g_hRestartTimer != null)
		{
			KillTimer(g_hRestartTimer);
			g_hRestartTimer = null;
			LogMessage("检测到有男娘加入，取消重启");
		}
	}
	return Plugin_Continue;
}

public Action Timer_RestartServer(Handle timer)
{
	int iSystem = L4D_GetServerOS();
	if (!CheckSystem(iSystem)) return Plugin_Stop;

	bool isDedicated = IsDedicatedServer();
	if (!CheckServerType(isDedicated)) return Plugin_Stop;

	if (g_hLog.BoolValue)
	{
		char date[16], time[16], system[16], type[16];
		FormatTime(date, sizeof(date), "%y%m%d", GetTime());
		FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
		BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "/logs/ReStart%s.log", date);

		FormatEx(system, sizeof(system), iSystem ? "Linux" : "Windows");
		FormatEx(type, sizeof(type), isDedicated ? "专用" : "本地");

		LogToFile(g_sLogPath, "[%s] [自动重启] 系统: %s | 类型: %s | 空服时长: %d秒",
				  time, system, type, GetTime() - g_iEmptyTime);
	}

	RestartServer();
	return Plugin_Stop;
}

public void OnConfigsExecuted()
{
	CreateTimer(g_hCheckInterval.FloatValue, Timer_CheckPlayers, _, TIMER_REPEAT);
}

int GetRealClientCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			count++;
		}
	}
	return count;
}

bool CheckSystem(int system)
{
	int allowed = g_hSystem.IntValue;
	return (system == 0 && (allowed & 2)) || (system == 1 && (allowed & 1));
}

bool CheckServerType(bool isDedicated)
{
	int allowed = g_hType.IntValue;
	return (isDedicated && (allowed & 1)) || (!isDedicated && (allowed & 2));
}

void RestartServer()
{
	int iSystem = L4D_GetServerOS();
	

	if (iSystem == 1) // Lux
	{
		UnloadAccelerator();
		SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
		ServerCommand("crash");
	}
	else // Win
	{
		ServerCommand("_restart");
	}
}

// Lux
void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}