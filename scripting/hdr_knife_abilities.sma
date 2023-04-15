#include <amxmodx>
#include <hdr_const>

new const PLUGIN[] = "HDR: Knife Abilites"
new const PLUGIN_CVAR[] = "hdr_knife_abilities"

/*
	Times in Days to Seconds:
	1 Day 	= 86400
	2 Days 	= 172800
	3 Days 	= 259200
	4 Days 	= 345600
	5 Days 	= 432000
	6 Days 	= 518400
	7 Days 	= 604800
*/

//#define DEBUG
#define VIP_CAN_USE_TIMEPLAYED

native hdr_get_user_playtime(id)
native get_user_exp(id)
native set_user_exp(id, iExp)

new g_bKnifeModels[33]
new g_bKnifeClass[33]
new g_iKnife
new g_iExpMultiplier[33]
new gCylinderSprite

enum
{
	Crowbar = 1,
	Tracker,
	Knuckle,
	GoldenSatur,
	DaedricDagger,
	TimePlayedKnife
}

enum _:iData
{
	g_szItemName[32],
	g_szItemDescription[64],
	g_iSetKnife,
	Float:g_fGravity,
	Float:g_fSpeed,
	Float:g_fDamage,
	g_szModel_V[64],
	g_szModel_P[64]
}

#if defined DEBUG
new gKnives[][iData] =
{
	{ }, // Passing the god damn ZERO ( 0 ) 		Set    	 GRAV  SPEED  DMG     	V_MODELS			      	P_MODELS	
	{ "Crowbar", 		"Double Damage", 	1, 	800.0, 250.0, 2.0, "models/v_knife.mdl", 	"models/p_knife.mdl" },
	{ "Tracker", 		"No FootSteps", 		1, 	800.0, 250.0, 1.0, "models/v_knife.mdl", 	"models/p_knife.mdl" },
	{ "Knuckle", 		"High Speed", 		1, 	800.0, 350.0, 1.0, "models/v_knife.mdl", 	"models/p_knife.mdl" },
	{ "Golden Satur", 	"Low Gravity", 		1, 	430.0, 200.0, 1.0, "models/v_knife.mdl", 	"models/p_knife.mdl" },
	{ "Daedric Dagger", 	"Gravity + Speed", 	1, 	420.0, 350.0, 1.0, "models/v_knife.mdl", 	"models/p_knife.mdl" },
	{ "Trench",		"Gravity + Speed",	1,	450.0, 300.0, 1.0, "models/v_knife.mdl",	"models/p_knife.mdl" }
}
#else
new gKnives[][iData] =
{
	{ }, // Passing the god damn ZERO ( 0 ) 		Set    	 GRAV  SPEED  DMG     	V_MODELS			      	P_MODELS	
	{ "Crowbar", 		"Double Damage", 	1, 	800.0, 250.0, 2.0, "models/hdr_knives/crowbar.mdl", 		"models/p_knife.mdl" },
	{ "Tracker", 		"No FootSteps", 		1, 	800.0, 250.0, 1.0, "models/hdr_knives/tracker.mdl", 		"models/p_knife.mdl" },
	{ "Knuckle", 		"High Speed", 		1, 	800.0, 350.0, 1.0, "models/hdr_knives/knuckle.mdl", 		"models/p_knife.mdl" },
	{ "Golden Satur", 	"Low Gravity", 		1, 	430.0, 200.0, 1.0, "models/hdr_knives/golden_satur.mdl", 	"models/p_knife.mdl" },
	{ "Daedric Dagger", 	"Gravity + Speed", 	1, 	420.0, 350.0, 1.0, "models/hdr_knives/daedric_dagger.mdl", 	"models/p_knife.mdl" },
	{ "Trench",		"Gravity + Speed",	1,	450.0, 300.0, 1.0, "models/hdr_knives/trench.mdl",		"models/p_knife.mdl" }
}
#endif
new const g_szKnifeCommands[][] =
{
	"say /knife", "say_team /knife"
}
new const g_szHideSkinCommands[][] =
{
	"say /skin", "say_team /skin", "say /skins", "say_team /skins"
}

enum _:eRandom
{
	STR[16], INT
}

new gRandomStuff[][eRandom] =
{
	{ "+50 Health", 50 },
	{ "HE Grenade", 1 },
	{ "Frost + HE", 1 },
	{ "Double XP", 2 },
	{ "Bonus 5 XP", 5 }
}

public plugin_init()
{
	register_plugin(PLUGIN, MOD_VERSION, MOD_AUTHOR)
	register_cvar(PLUGIN_CVAR, MOD_VERSION, FCVAR_SERVER | FCVAR_SPONLY)
	set_cvar_string(PLUGIN_CVAR, MOD_VERSION)

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", false)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy")
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed", true)
	
	for(new i = 0; i < sizeof g_szKnifeCommands; i++) register_clcmd(g_szKnifeCommands[i], "Command_Knife")
	for(new i = 0; i < sizeof g_szHideSkinCommands; i++) register_clcmd(g_szHideSkinCommands[i], "Command_HideSkin")
}
public Command_HideSkin(id)
{
	g_bKnifeModels[id] = !g_bKnifeModels[id]
	set_knife(id, gKnives[g_bKnifeClass[id]][g_iSetKnife])
	PCC(id, "Switched to !g%s!y skin!", g_bKnifeModels[id] ? "new" : "original")
	return PLUGIN_HANDLED
}
public plugin_precache()
{
	for(new i = 1; i < sizeof(gKnives); i++)
	{
		precache_model(gKnives[i][g_szModel_V])
		precache_model(gKnives[i][g_szModel_P])
	}
	gCylinderSprite = precache_model("sprites/shockwave.spr")
}
public plugin_natives()
{
	register_native("get_user_knife_name", "_get_knife_name")
	register_native("get_user_knife", "_get_user_knife")
	register_native("is_knife_hidden", "_is_knife_hidden")
	register_native("knife_multiplier_xp", "_knife_multiplier_xp")
	register_native("get_user_knife_gravity", "_get_user_knife_gravity", 1)
	register_native("get_user_knife_speed", "_get_user_knife_speed", 1)
	register_native("get_user_knife_damage", "_get_user_knife_damage", 1)
	register_native("get_user_knife_footsteps", "_get_user_knife_footsteps", 1)
}
public Float:_get_user_knife_gravity(id)
{
	return gKnives[g_bKnifeClass[id]][g_fGravity]
}
public Float:_get_user_knife_speed(id)
{
	return gKnives[g_bKnifeClass[id]][g_fSpeed]
}
public Float:_get_user_knife_damage(id)
{
	return gKnives[g_bKnifeClass[id]][g_fDamage]
}
public _get_user_knife_footsteps(id)
{
	if (g_bKnifeClass[id] == Tracker)
		return 1
	else
		return 0
}
public _get_knife_name(iPlugin, iParams)
{
	new id = get_param(1)
	
	if ( !is_user_connected(id))
		return false
	
	set_string(2, gKnives[g_bKnifeClass[id]][g_szItemName], get_param(3))
	return true
}
public _is_knife_hidden(iPlugin, iParams)
{
	return g_bKnifeModels[get_param(1)]
}
public _knife_multiplier_xp(iPlugin, iParams)
{
	return g_iExpMultiplier[get_param(1)]
}
public _get_user_knife(iPlugin, iParams)
{
	return g_bKnifeClass[get_param(1)]
}
public client_connect(id)
{
	g_bKnifeClass[id] = GoldenSatur
	g_bKnifeModels[id] = true
	g_iExpMultiplier[id] = 1
}
public Command_Knife(id)
{
	static szTitle[128], szText[64], szTempID[11]
	formatex(szTitle, charsmax(szTitle), "\wChoose knife:")
	
	new iMenu = menu_create(szTitle, "KnivesAbilities_Handler")
	
	for(new i = 1; i < sizeof(gKnives); i++)
	{
		if (i == DaedricDagger)
		{
			formatex(szText, charsmax(szText), "%s%s \w[\r %s \w]^n", g_bKnifeClass[id] == i ? "\d" : "\y", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			num_to_str(i, szTempID, charsmax(szTempID))
			menu_additem(iMenu, szText, szTempID)
		}
		else if (i == TimePlayedKnife)
		{
			#if defined VIP_CAN_USE_TIMEPLAYED
			if (hdr_get_user_playtime(id) >= 86400 || get_user_flags(id) & read_flags("r"))
			{
				formatex(szText, charsmax(szText), "%s%s \w[\y %s \w]", g_bKnifeClass[id] == i ? "\d" : "\r", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			}
			else
			{
				formatex(szText, charsmax(szText), "\d%s [ %s ]", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			}
			#else
			if (hdr_get_user_playtime(id) >= 86400)
			{
				formatex(szText, charsmax(szText), "%s%s \w[\y %s \w]", g_bKnifeClass[id] == i ? "\d" : "\r", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			}
			else
			{
				formatex(szText, charsmax(szText), "\d%s [ %s ]", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			}
			#endif

			num_to_str(i, szTempID, charsmax(szTempID))
			menu_additem(iMenu, szText, szTempID)
		}
		else
		{
			formatex(szText, charsmax(szText), "%s%s \y[\r %s \y]", g_bKnifeClass[id] == i ? "\d" : "\w", gKnives[i][g_szItemName], gKnives[i][g_szItemDescription])
			num_to_str(i, szTempID, charsmax(szTempID))
			menu_additem(iMenu, szText, szTempID)
		}
	}
	
	menu_setprop(iMenu, MPROP_EXITNAME, "Close Menu")
	
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}

public KnivesAbilities_Handler(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return HDR_HANDLED
	}
	
	new szInfo[6], iName[64], iAccess, iCallBack, iKey
	menu_item_getinfo(iMenu, Item, iAccess, szInfo, charsmax(szInfo), iName, charsmax(iName), iCallBack)
	
	iKey = str_to_num(szInfo)
	new Float:fHealth = rg_get_user_health(id)
	
	if (fHealth > 100.0)
		rg_set_user_health(id, 100.0)
		
	if (iKey == DaedricDagger)
	{
		if(get_user_flags(id) & read_flags("r"))
		{
			g_bKnifeClass[id] = DaedricDagger
		}
		else
		{
			PCC(id, "You must be !tVIP User!y to use this knife! !t[!g%s!t]", MOD_AUTHOR_DISCORD)
			menu_destroy(iMenu)
			return HDR_CONTINUE
		}
	}
	else if (iKey == TimePlayedKnife)
	{
		#if defined VIP_CAN_USE_TIMEPLAYED
		if (hdr_get_user_playtime(id) >= 86400 || get_user_flags(id) & read_flags("r"))
		{
			g_bKnifeClass[id] = TimePlayedKnife
		}
		else
		{
			PCC(id, "You must have played for !t(!g1 Day!t)!y or you to be !tVIP User !yto use this knife! !t[!g%s!t]", MOD_AUTHOR_DISCORD)
			PCC(id, "!yCheck your PlayTime with command: !g/pt")
			menu_destroy(iMenu)
			return HDR_CONTINUE
		}
		#else
		if (hdr_get_user_playtime(id) >= 86400)
		{
			g_bKnifeClass[id] = TimePlayedKnife
		}
		else
		{
			PCC(id, "You must have played for !t(!g1 Day!t) !yto use this knife! !t[!yCheck your PlayTime with command: !g/pt!t]")
			menu_destroy(iMenu)
			return HDR_CONTINUE
		}
		#endif
	}
	else
	{
		g_bKnifeClass[id] = iKey
	}
	
	g_iKnife = g_bKnifeClass[id]
	
	PCC(id, "You've chosen !t%s !y[!g %s !y]", gKnives[g_iKnife][g_szItemName], gKnives[g_iKnife][g_szItemDescription])
	
	set_knife(id, gKnives[g_iKnife][g_iSetKnife])
	
	FadePlayer(id, (1<<10), (1<<10), (1<<12), random(256), random(256), random(256), 75)
	
	menu_destroy(iMenu)
	return HDR_HANDLED
}

public CBasePlayer_ResetMaxSpeed(id)
{
	if (is_user_alive(id))
	{
		if (rg_get_user_active_weapon(id) == WEAPON_KNIFE)
		{
			rg_set_user_maxspeed(id, gKnives[g_bKnifeClass[id]][g_fSpeed])
		}
	}
}

public CBasePlayerWeapon_DefaultDeploy(const iItem, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], iSkipLocal)
{
	if (is_nullent(iItem))
		return HC_CONTINUE

	static id
	id = get_member(iItem, m_pPlayer)

	if (!is_user_alive(id))
		return HC_CONTINUE

	if (rg_get_user_active_weapon(id) == WEAPON_KNIFE)
	{
		g_iKnife = g_bKnifeClass[id]

		if (g_bKnifeModels[id])
		{
			SetHookChainArg(2, ATYPE_STRING, gKnives[g_iKnife][g_szModel_V])
			SetHookChainArg(3, ATYPE_STRING, gKnives[g_iKnife][g_szModel_P])
		}

		new Float:flGravity = gKnives[g_iKnife][g_fGravity] / 800.0

		rg_set_user_gravity(id, flGravity)
				
		if (g_iKnife == Tracker)
			rg_set_user_footsteps(id, true)
	}
	else
	{
		rg_reset_maxspeed(id)
		rg_set_user_gravity(id, 1.0)
		rg_set_user_footsteps(id, false)
	}
	return HC_CONTINUE
}

public CBasePlayer_Spawn(id)
{
	if (is_user_alive(id))
	{
		if (g_bKnifeClass[id] == TimePlayedKnife)
			set_task(1.0, "DelayedBonuses", id)
	}
}

public DelayedBonuses(id)
{
	if (is_user_alive(id))
	{
		g_iExpMultiplier[id] = 1
				
		new iRandomItem = random(sizeof gRandomStuff)
		new iR, iG, iB
		
		switch (iRandomItem)
		{
			case 0:
			{
				set_task(0.5, "updatehp", id)
				iR = 0
				iG = 255
				iB = 0
			}
			case 1:
			{
				rg_give_item(id, "weapon_hegrenade")
				rg_set_user_bpammo(id, WEAPON_HEGRENADE, (rg_has_item_by_name(id, "weapon_hegrenade") ? (gRandomStuff[1][INT]+1) : (gRandomStuff[1][INT])))
				iR = 255
				iG = 0
				iB = 0
			}
			case 2:
			{
				rg_give_item(id, "weapon_smokegrenade")
				rg_give_item(id, "weapon_hegrenade")
				rg_set_user_bpammo(id, WEAPON_HEGRENADE, (rg_has_item_by_name(id, "weapon_hegrenade") ? (gRandomStuff[2][INT]+1) : (gRandomStuff[2][INT])))
				rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, (rg_has_item_by_name(id, "weapon_smokegrenade") ? (gRandomStuff[2][INT]+1) : (gRandomStuff[2][INT])))
				iR = 0
				iG = 0
				iB = 255
			}
			case 3:
			{
				g_iExpMultiplier[id] = gRandomStuff[3][INT]
				iR = random(256)
				iG = random(256)
				iB = random(256)
			}
			case 4:
			{
				set_user_exp(id, get_user_exp(id) + gRandomStuff[4][INT])
				iR = 255
				iG = 255
				iB = 0
			}
		}
		PCC(id, "You got !g%s !yfor using !t%s", gRandomStuff[iRandomItem][STR], gKnives[TimePlayedKnife][g_szItemName])
				
		new iOrigin[3]
		get_user_origin(id, iOrigin)
				
		Create_BeamCylinder(iOrigin, 120, gCylinderSprite, 0, 0, 6, 16, 0, iR, iG, iB, 255, 0)
	}
}

public updatehp(id)
{
	if (is_user_alive(id))
	{
		rg_set_user_health(id, rg_get_user_health(id) + gRandomStuff[0][INT])
		remove_task(id)
	}
}
public CBasePlayer_TakeDamage(iVictim, Inflictor, iAttacker, Float:flDamage, iDamageBits)
{
	if (!is_user_connected(iAttacker) || rg_get_user_active_weapon(iAttacker) != WEAPON_KNIFE || iVictim == iAttacker)
		return HC_CONTINUE

	g_iKnife = g_bKnifeClass[iAttacker]
	if(gKnives[g_iKnife][g_fDamage] > 10.0) 
		SetHookChainArg(4, ATYPE_FLOAT, gKnives[g_iKnife][g_fDamage])
	else
		SetHookChainArg(4, ATYPE_FLOAT, flDamage * gKnives[g_iKnife][g_fDamage])

	return HC_CONTINUE
}

public client_infochanged(id)
{
	if (!is_user_connected(id))
		goto Handled
	
	new szNewName[32], szOldName[32]
	get_user_name(id, szOldName, charsmax(szOldName))
	get_user_info(id, "name", szNewName, charsmax(szNewName))
	
	if (!equal(szNewName, szOldName))
	{
		g_bKnifeClass[id] = GoldenSatur
		set_knife(id, 1)
		goto Handled
	}
	
	Handled:
	return PLUGIN_HANDLED
}

stock set_knife(id, set = 1)
{
	if(set)
	{
		rg_remove_item(id, "weapon_knife")
		rg_give_item(id, "weapon_knife")
		client_cmdex(id, "weapon_knife")
	}
	else
	{
		rg_remove_item(id, "weapon_knife")
		rg_give_item(id, "weapon_knife")
	}
	return 1
}


stock FadePlayer(id, iDuration, iHoldTime, iFlags, iRed, iGreen ,iBlue, iAlpha)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), { 0, 0, 0 }, id)
	write_short(iDuration)
	write_short(iHoldTime)
	write_short(iFlags)
	write_byte(iRed)
	write_byte(iGreen)
	write_byte(iBlue) 
	write_byte(iAlpha)
	message_end()
}

stock Create_BeamCylinder(origin[3], addrad, sprite, startfrate, framerate, life, width, amplitude, red, green, blue, brightness, speed)
{
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BEAMCYLINDER)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2] + addrad)
	write_short(sprite)
	write_byte(startfrate)
	write_byte(framerate)
	write_byte(life)
	write_byte(width)
	write_byte(amplitude)
	write_byte(red)
	write_byte(green)
	write_byte(blue)
	write_byte(brightness)
	write_byte(speed)
	message_end()
}