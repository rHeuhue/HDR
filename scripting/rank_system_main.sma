#include <amxmodx>

/* Common include libraries */
#include <amxmisc>
#include <fvault>
#tryinclude <cromchat>

#define PLUGIN  "Rank System"
#define VERSION "1.1"
#define AUTHOR  "Huehue @ AMXX-BG.INFO"
#define GAMETRACKER "rank_system"

#if !defined MAX_PLAYERS || AMXX_VERSION_NUM < 183
#define MAX_PLAYERS 32
#define client_disconnected client_disconnect
#endif

enum _:ePlayerData
{
	Experience,
	Level,
	NextLevel,
	IncreaseExperience,
	ConnectStatus,
	UserName[MAX_PLAYERS]
}

new g_iPlayerData[MAX_PLAYERS + 1][ePlayerData]

enum
{
	Negative = 0,
	Positive
}

new const g_szVault[] = "Rank_System_AMXXBG"

new Array:g_aRankName, Array:g_aRankExp
new iTotalRanks

enum
{
	SECTION_SETTINGS = 1,
	SECTION_RANKS
}

enum _:eSettings
{
	Prefix[32],
	VipFlag[6],
	HudColors[12],
	Float:HudX,
	Float:HudY,
	HudEffect,
	KillExp,
	HeadKillExp,
	GrenadeKillExp,
	KnifeKillExp,
	VipKillExp,
	VipHeadKillExp,
	VipGrenadeKillExp,
	VipKnifeKillExp,
	VipFlagBit
}

new g_eSettings[eSettings]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar(GAMETRACKER, AUTHOR, FCVAR_SERVER | FCVAR_SPONLY)
	set_cvar_string(GAMETRACKER, AUTHOR)

	register_event("DeathMsg", "eventDeathMsg", "a")

	register_clcmd("amx_reload_file", "Command_Reload_RanksFile", ADMIN_RCON, "- Reload settings and rank file..")

	#if defined _cromchat_included
	CC_SetPrefix(g_eSettings[Prefix])
	#endif
}

public plugin_precache()
{
	g_aRankName = ArrayCreate(128, 1)
	g_aRankExp = ArrayCreate(64, 1)
	
	Read_Ranks_File()
}

public Read_Ranks_File()
{
	static szConfigsDir[64], iFile, szRankFile[64]
	get_configsdir(szConfigsDir, charsmax(szConfigsDir))
	formatex(szRankFile, charsmax(szRankFile), "/Rank_System.ini")
	add(szConfigsDir, charsmax(szConfigsDir), szRankFile)
	iFile = fopen(szConfigsDir, "rt")
	
	if(!file_exists(szConfigsDir))
	{
		server_print("File not found, creating new one..")
		new iFile = fopen(szConfigsDir, "wt")
		
		if (iFile)
		{
			new szNewFile[512]
			formatex(szNewFile, charsmax(szNewFile), "[SETTINGS]\
				^nPREFIX = &x04[&x03Rank System&x04]\
				^nVIP_FLAG = b\
				^nHUD_COLORS = 255 0 0\
				^nHUD_X_POSITION = 0.80\
				^nHUD_Y_POSITION = -1.0\
				^nHUD_EFFECT = 0\
				^nKILL_EXP = 2\
				^nHEADSHOT_KILL_EXP = 3\
				^nGRENADE_KILL_EXP = 4\
				^nKNIFE_KILL_EXP = 6\
				^nVIP_KILL_EXP = 3\
				^nVIP_HEADSHOT_KILL_EXP = 5\
				^nVIP_GRENADE_KILL_EXP = 6\
				^nVIP_KNIFE_KILL_EXP = 8\
				^n^n[RANKS]\
				^n;Rank Name = XP\
				^nNewbie = 0\
				^nPro = 25\
				^nMaster = 50")
			fputs(iFile, szNewFile)
		}
		fclose(iFile)
		Read_Ranks_File()
		return
	}
	
	new iLine
	
	if (iFile)
	{
		static szLineData[160], iSection, szValue[160], szKey[64]
		
		while (!feof(iFile))
		{
			fgets(iFile, szLineData, charsmax(szLineData))
			trim(szLineData)
			
			if (szLineData[0] == EOS || szLineData[0] == ';' || (szLineData[0] == '/' && szLineData[1] == '/'))
				continue

			switch(szLineData[0])
			{
				case EOS, ';': continue
				case '[':
				{
					if (szLineData[strlen(szLineData) - 1] == ']')
					{
						if (containi(szLineData, "settings") != -1)
							iSection = SECTION_SETTINGS
						else if (containi(szLineData, "ranks") != -1)
							iSection = SECTION_RANKS
					}
					else
						continue
				}
				default:
				{
					switch(iSection)
					{
						case SECTION_SETTINGS:
						{
							strtok(szLineData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
							trim(szKey)
							trim(szValue)

							if (szValue[0] == EOS)
								continue

							if (equal(szKey, "PREFIX"))
								copy(g_eSettings[Prefix], charsmax(g_eSettings[Prefix]), szValue)
							else if (equal(szKey, "VIP_FLAG"))
							{
								copy(g_eSettings[VipFlag], charsmax(g_eSettings[VipFlag]), szValue)
								g_eSettings[VipFlagBit] = read_flags(g_eSettings[VipFlag])
							}
							else if (equal(szKey, "HUD_COLORS"))
								copy(g_eSettings[HudColors], charsmax(g_eSettings[HudColors]), szValue)
							else if (equal(szKey, "HUD_X_POSITION"))
								g_eSettings[HudX] = _:str_to_float(szValue)
							else if (equal(szKey, "HUD_Y_POSITION"))
								g_eSettings[HudY] = _:str_to_float(szValue)
							else if (equal(szKey, "HUD_EFFECT"))
								g_eSettings[HudEffect] = str_to_num(szValue)
							else if (equal(szKey, "KILL_EXP"))
								g_eSettings[KillExp] = str_to_num(szValue)
							else if (equal(szKey, "HEADSHOT_KILL_EXP"))
								g_eSettings[HeadKillExp] = str_to_num(szValue)
							else if (equal(szKey, "GRENADE_KILL_EXP"))
								g_eSettings[GrenadeKillExp] = str_to_num(szValue)
							else if (equal(szKey, "KNIFE_KILL_EXP"))
								g_eSettings[KnifeKillExp] = str_to_num(szValue)
							else if (equal(szKey, "VIP_KILL_EXP"))
								g_eSettings[VipKillExp] = str_to_num(szValue)
							else if (equal(szKey, "VIP_HEADSHOT_KILL_EXP"))
								g_eSettings[VipHeadKillExp] = str_to_num(szValue)
							else if (equal(szKey, "VIP_GRENADE_KILL_EXP"))
								g_eSettings[VipGrenadeKillExp] = str_to_num(szValue)
							else if (equal(szKey, "VIP_KNIFE_KILL_EXP"))
								g_eSettings[VipKnifeKillExp] = str_to_num(szValue)
						}
						case SECTION_RANKS:
						{
							strtok(szLineData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
							trim(szKey)
							trim(szValue)

							if (szValue[0] == EOS)
								continue

							ArrayPushString(g_aRankName, szKey)
							ArrayPushCell(g_aRankExp, str_to_num(szValue))

							iLine++
						}
					}
				}
			}
		}
		fclose(iFile)
	}
	iTotalRanks = iLine - 1
	server_print(">> Loaded %i Ranks from file", iTotalRanks)
}

public client_putinserver(id)
{
	arrayset(g_iPlayerData[id], 0, sizeof(g_iPlayerData[]))

	get_user_name(id, g_iPlayerData[id][UserName], charsmax(g_iPlayerData[][UserName]))
	set_task(0.1, "Load_Data", id, g_iPlayerData[id][UserName], sizeof(g_iPlayerData[][UserName]))
}

public client_disconnected(id)
{
	if (g_iPlayerData[id][ConnectStatus])
	{
		Save_Data(id, g_iPlayerData[id][UserName])
		g_iPlayerData[id][ConnectStatus] = false
	}
}

public client_infochanged(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	
	static szNames[2][32]
	get_user_name(id, szNames[0], charsmax(szNames[]))
	get_user_info(id, "name", szNames[1], charsmax(szNames[]))

	if (!equali(szNames[1], szNames[0]))
	{
		Save_Data(id, szNames[0])
		set_task(0.1, "Load_Data", id, szNames[1], sizeof(szNames[]))
		g_iPlayerData[id][UserName] = szNames[1]
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public Command_Reload_RanksFile(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	ArrayClear(g_aRankName)
	ArrayClear(g_aRankExp)
	
	Read_Ranks_File()
	
	return PLUGIN_HANDLED
}

public CheckRank(id, iType)
{
	if(g_iPlayerData[id][Level] <= 0)
	{
		g_iPlayerData[id][Level] = 0
		g_iPlayerData[id][NextLevel] = 1
	}
		
	if (g_iPlayerData[id][Experience] < 0)
		g_iPlayerData[id][Experience] = 0
		
	switch(iType)
	{
		case Negative:
		{
			while (g_iPlayerData[id][Level] <= iTotalRanks)
			{
				new iExp = ArrayGetCell(g_aRankExp, g_iPlayerData[id][Level])
				
				if(g_iPlayerData[id][Experience] >= iExp)
					break
				
				g_iPlayerData[id][Level]--
				g_iPlayerData[id][NextLevel]--
				
				new szRankName[64]
				ArrayGetString(g_aRankName, g_iPlayerData[id][NextLevel], szRankName, charsmax(szRankName))

				#if defined _cromchat_included
				CC_SendMatched(0, CC_COLOR_GREY, "&x03Player &x04%s&x03 has lost &x04Level %i &x03- &x04%s", g_iPlayerData[id][UserName], g_iPlayerData[id][NextLevel], szRankName)
				#else
				client_print(0, print_chat, "* Player %s has lost Level %i - %s", g_iPlayerData[id][UserName], g_iPlayerData[id][NextLevel], szRankName)
				#endif
			}
		}
		case Positive:
		{
			while (g_iPlayerData[id][Level] < iTotalRanks)
			{
				new iNextLevelExp = ArrayGetCell(g_aRankExp, g_iPlayerData[id][NextLevel])
				
				if (g_iPlayerData[id][Experience] < iNextLevelExp)
					break
				
				g_iPlayerData[id][Level]++
				g_iPlayerData[id][NextLevel]++
				
				new szRankName[64]
				ArrayGetString(g_aRankName, g_iPlayerData[id][Level], szRankName, charsmax(szRankName))
				
				#if defined _cromchat_included
				CC_SendMatched(0, CC_COLOR_GREY, "&x03Player &x04%s &x03has achieved &x04Level %i &x03- &x04%s", g_iPlayerData[id][UserName], g_iPlayerData[id][Level], szRankName)
				#else
				client_print(0, print_chat, "* Player %s has achieved Level %i - %s", g_iPlayerData[id][UserName], g_iPlayerData[id][Level], szRankName)
				#endif
			}
		}
	}
}

/* =============================================
	Events
============================================= */
public eventDeathMsg()
{
	new iKiller = read_data(1), iVictim = read_data(2)
	
	if (is_user_connected(iKiller) && iKiller != iVictim)
	{
		new szWeapon[32]
		read_data(4, szWeapon, charsmax(szWeapon))
		if (equal(szWeapon, "grenade"))
		{
			if (get_user_flags(iKiller) & g_eSettings[VipFlagBit])
				g_iPlayerData[iKiller][IncreaseExperience] = g_eSettings[VipGrenadeKillExp]
			else
				g_iPlayerData[iKiller][IncreaseExperience] = g_eSettings[GrenadeKillExp]
		}
		else if (equal(szWeapon, "knife"))
		{
			if (get_user_flags(iKiller) & g_eSettings[VipFlagBit])
				g_iPlayerData[iKiller][IncreaseExperience] = g_eSettings[VipKnifeKillExp]
			else
				g_iPlayerData[iKiller][IncreaseExperience] = g_eSettings[KnifeKillExp]
		}
		else
		{
			new iHeadShot = read_data(3)

			if (get_user_flags(iKiller) & g_eSettings[VipFlagBit])
				g_iPlayerData[iKiller][IncreaseExperience] = iHeadShot ? g_eSettings[VipHeadKillExp] : g_eSettings[VipKillExp]
			else
				g_iPlayerData[iKiller][IncreaseExperience] = iHeadShot ? g_eSettings[HeadKillExp] : g_eSettings[KillExp]
		}

		g_iPlayerData[iKiller][Experience] += g_iPlayerData[iKiller][IncreaseExperience]

		CheckRank(iKiller, Positive)
	}
}

/* =============================================
	Load & Save
============================================= */
public Load_Data(szName[], id)
{
	if(!is_user_connected(id))
		return
	
	new szData[64]
			
	if(fvault_get_data(g_szVault, szName, szData, charsmax(szData)))
	{
		replace_all(szData, charsmax(szData), "#", " ")
		
		new szExp[10], szLevel[10]
		parse(szData, szExp, charsmax(szExp), szLevel, charsmax(szLevel))

		g_iPlayerData[id][Experience] = str_to_num(szExp)
		g_iPlayerData[id][Level] = str_to_num(szLevel)
		g_iPlayerData[id][NextLevel] = g_iPlayerData[id][Level]
		g_iPlayerData[id][NextLevel]++
	} 
	else 
	{
		g_iPlayerData[id][Experience] = 0
		g_iPlayerData[id][Level] = 0
		g_iPlayerData[id][NextLevel] = 1
	}

	g_iPlayerData[id][ConnectStatus] = true
}

public Save_Data(id, szName[])
{
	new szData[64]
	formatex(szData, charsmax(szData), "%i#%i", g_iPlayerData[id][Experience], g_iPlayerData[id][Level])
	fvault_set_data(g_szVault, szName, szData)
}


/* =============================================
	Natives
============================================= */
public plugin_natives()
{
	register_library("rank_system_huehue")
	
	register_native("get_user_level", "native_get_user_level")
	register_native("set_user_level", "native_set_user_level")
	register_native("get_user_exp", "native_get_user_exp")
	register_native("set_user_exp", "native_set_user_exp")
	register_native("get_user_rank_name", "native_get_user_rank_name")
	register_native("get_user_next_exp", "native_get_user_next_exp")
	register_native("get_user_next_level", "native_get_user_next_level")
	register_native("get_user_next_rank_name", "native_get_user_next_rank_name")
	register_native("get_rank_name_by_level", "native_get_rank_name_by_level")
	register_native("get_rank_exp", "native_get_rank_exp")
	register_native("get_total_ranks", "native_get_total_ranks")
	register_native("update_rank_info", "native_update_rank_info")
	register_native("set_user_rank", "native_set_user_rank")
	register_native("get_plugin_prefix", "native_get_plugin_prefix")
	register_native("get_vip_flag", "native_get_vip_flag")

	register_native("get_hud_colors", "native_get_hud_colors")
	register_native("get_hud_position_x", "native_get_hud_position_x")
	register_native("get_hud_position_y", "native_get_hud_position_y")
	register_native("get_hud_effect", "native_get_hud_effect")
}

public native_get_user_level(iPlugin, iParams)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
		return -1
	
	return g_iPlayerData[id][Level]
}
public native_set_user_level(iPlugin, iParams)
{
	new id = get_param(1), iLevel = get_param(2)
	
	if (!is_user_connected(id))
		return false
		
	if (g_iPlayerData[id][Level] < iLevel)
	{
		g_iPlayerData[id][Level] = iLevel
		CheckRank(id, Positive)
	}
	else
	{
		g_iPlayerData[id][Level] = iLevel
		CheckRank(id, Negative)
	}
	return true
	
}
public native_get_user_exp(iPlugin, iParams)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
		return -1
	
	return g_iPlayerData[id][Experience]
}
public native_set_user_exp(iPlugin, iParams)
{
	new id = get_param(1), iExp = get_param(2)
	
	if (!is_user_connected(id))
		return false
		
	if (g_iPlayerData[id][Experience] < iExp)
	{
		g_iPlayerData[id][Experience] = iExp
		CheckRank(id, Positive)
	}
	else
	{
		g_iPlayerData[id][Experience] = iExp
		CheckRank(id, Negative)
	}
	return true
	
}
public native_get_user_rank_name(iPlugin, iParams)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
		return false
	
	new szRankName[64]
	ArrayGetString(g_aRankName, g_iPlayerData[id][Level], szRankName, charsmax(szRankName))
	
	set_string(2, szRankName, get_param(3))
	return true
}

public native_get_user_next_exp(iPlugin, iParams)
{
	new id = get_param(1)
	
	if (g_iPlayerData[id][Level] > iTotalRanks-1)
	{
		return 0
	}
	else
	{
		new iNextLevelExp = ArrayGetCell(g_aRankExp, g_iPlayerData[id][NextLevel])
	
		return iNextLevelExp
	}
	#if AMXX_VERSION_NUM < 183
	return 0
	#endif
}
public native_get_user_next_level(iPlugin, iParams)
{
	new id = get_param(1)

	if (g_iPlayerData[id][Level] > iTotalRanks-1)
	{
		return 0
	}
	else
	{
		return g_iPlayerData[id][NextLevel]
	}
	#if AMXX_VERSION_NUM < 183
	return 0
	#endif
}
public native_get_user_next_rank_name(iPlugin, iParams)
{
	new id = get_param(1)

	if (g_iPlayerData[id][Level] > iTotalRanks-1)
	{
		return 0
	}
	else
	{
		new szRankName[64]
		ArrayGetString(g_aRankName, g_iPlayerData[id][NextLevel], szRankName, charsmax(szRankName))

		set_string(2, szRankName, get_param(3))
	}
	return true
}
public native_get_rank_name_by_level(iPlugin, iParams)
{
	new iLevel = get_param(1)
	
	if (iLevel > iTotalRanks + 1)
	{
		return 0
	}
	
	new szRankName[64]
	ArrayGetString(g_aRankName, iLevel, szRankName, charsmax(szRankName))
	
	set_string(2, szRankName, get_param(3))
	return true
}

public native_get_total_ranks(iPlugin, iParams)
{
	return iTotalRanks
}

public native_update_rank_info(iPlugin, iParams)
{
	new id = get_param(1), iType = get_param(2)

	if (!is_user_connected(id))
		return false

	CheckRank(id, iType)
	return true
}

public native_get_rank_exp(iPlugin, iParams)
{
	new iExp = ArrayGetCell(g_aRankExp, get_param(1))

	return iExp
}

public native_set_user_rank(iPlugin, iParams)
{
	new id = get_param(1), iRankNum = get_param(2)

	if (!is_user_connected(id))
		return false

	new iExpAmount = ArrayGetCell(g_aRankExp, iRankNum)

	g_iPlayerData[id][Level] = iRankNum
	g_iPlayerData[id][Experience] = iExpAmount
	g_iPlayerData[id][NextLevel] = g_iPlayerData[id][Level]
	g_iPlayerData[id][NextLevel]++

	return true
}

public native_get_plugin_prefix(iPlugin, iParams)
{
	return set_string(1, g_eSettings[Prefix], get_param(2))
}

public native_get_vip_flag(iPlugin, iParams)
{
	return set_string(1, g_eSettings[VipFlag], get_param(2))
}

public native_get_hud_colors(iPlugin, iParams)
{
	return set_string(1, g_eSettings[HudColors], get_param(2))
}

public Float:native_get_hud_position_x(iPlugin, iParams)
{
	return g_eSettings[HudX]
}

public Float:native_get_hud_position_y(iPlugin, iParams)
{
	return g_eSettings[HudY]
}
public native_get_hud_effect(iPlugin, iParams)
{
	return g_eSettings[HudEffect]
}