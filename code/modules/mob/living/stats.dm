
/mob/living
	var/STASTR = 10
	var/STAPER = 10
	var/STAINT = 10
	var/STACON = 10
	var/STAEND = 10
	var/STASPD = 10
	var/STALUC = 10
	//buffers, the 'true' amount of each stat
	var/BUFSTR = 0
	var/BUFPER = 0
	var/BUFINT = 0
	var/BUFCON = 0
	var/BUFEND = 0
	var/BUFSPE = 0
	var/BUFLUC = 0
	var/statbuf = FALSE
	var/list/statindex = list()
	var/datum/patron/patron = /datum/patron/godless

/mob/living/proc/init_faith()
	set_patron(/datum/patron/godless)

/mob/living/proc/set_patron(datum/patron/new_patron)
	if(!new_patron)
		return TRUE
	if(ispath(new_patron))
		new_patron = GLOB.patronlist[new_patron]
	if(!istype(new_patron))
		return TRUE
	if(istype(patron))
		patron.on_loss(src)
	patron = new_patron
	new_patron.on_gain(src)
	return TRUE

/mob/living/proc/roll_stats()
	STASTR = 10
	STAPER = 10
	STAINT = 10
	STACON = 10
	STAEND = 10
	STASPD = 10
	STALUC = 10
	for(var/S in MOBSTATS)
		var/how_much = pick(-1, 0, 1)
		change_stat(S, how_much)
	if(ishuman(src))
		var/mob/living/carbon/human/H = src
		if(H.dna.species)
			// Species stats
			for(var/S in H.dna.species.specstats)
				change_stat(S, H.dna.species.specstats[S])
			if(gender == FEMALE)
				// Female species stats
				for(var/S in H.dna.species.specstats_f)
					change_stat(S, H.dna.species.specstats_f[S])
			else
				// Male species stats
				for(var/S in H.dna.species.specstats_m)
					change_stat(S, H.dna.species.specstats_m[S])
		switch(H.age)
			if(AGE_MIDDLEAGED)
				change_stat("speed", -1)
				change_stat("endurance", 1)
			if(AGE_OLD)
				change_stat("strength", -1)
				change_stat("speed", -2)
				change_stat("perception", -1)
				change_stat("constitution", -2)
				change_stat("intelligence", 3)
				change_stat("fortune", 1)
		if(HAS_TRAIT(src, TRAIT_LEPROSY))
			change_stat("strength", -5)
			change_stat("speed", -5)
			change_stat("endurance", -2)
			change_stat("constitution", -2)
			change_stat("intelligence", -5)
			change_stat("fortune", -5)
		if(HAS_TRAIT(src, TRAIT_ROTTOUCHED))
			change_stat("fortune", -3)
		if(HAS_TRAIT(src, TRAIT_PUNISHMENT_CURSE))
			change_stat("strength", -3)
			change_stat("speed", -3)
			change_stat("endurance", -3)
			change_stat("constitution", -3)
			change_stat("intelligence", -3)
			change_stat("fortune", -3)
			H.voice_color = "c71d76"
			set_eye_color(H, "#c71d76", "#c71d76")
		if(isseelie(src))	//Check necessary to prevent seelie getting default stats when no other changes apply
			change_stat("strength", -9)
	save_stats_as_roundstarted() // REDMOON ADD - after_death_stats_fix

/mob/living/proc/change_stat(stat, amt, index)
	if(!stat)
		return
	if(amt == 0 && index)
		if(statindex[index])
			change_stat(statindex[index]["stat"], -1*statindex[index]["amt"])
			statindex[index] = null
		return
	if(!amt)
		return
	if(index)
		if(statindex[index])
			return //we cannot make a new index
		else
			statindex[index] = list("stat" = stat, "amt" = amt)
//			statindex[index]["stat"] = stat
//			statindex[index]["amt"] = amt
//	var/newamt = 0 - REDMOON REMOVAL - не востребованная переменная
	switch(stat)
		if("strength")
			if(isseelie(src))
				STASTR = 1
				return
/*			newamt = STASTR + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFSTR < 0)
				BUFSTR = BUFSTR + amt
				if(BUFSTR > 0)
					newamt = STASTR + BUFSTR
					BUFSTR = 0
			if(BUFSTR > 0)
				BUFSTR = BUFSTR + amt
				if(BUFSTR < 0)
					newamt = STASTR + BUFSTR
					BUFSTR = 0
			while(newamt < 1)
				newamt++
				BUFSTR--
			while(newamt > 20)
				newamt--
				BUFSTR++
			STASTR = newamt - REDMOON REMOVAL END*/
			BUFSTR += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STASTR = CLAMP(ROUNDSTART_STASTR + BUFSTR, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов

		if("perception")
/*			newamt = STAPER + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFPER < 0)
				BUFPER = BUFPER + amt
				if(BUFPER > 0)
					newamt = STAPER + BUFPER
					BUFPER = 0
			if(BUFPER > 0)
				BUFPER = BUFPER + amt
				if(BUFPER < 0)
					newamt = STAPER + BUFPER
					BUFPER = 0
			while(newamt < 1)
				newamt++
				BUFPER--
			while(newamt > 20)
				newamt--
				BUFPER++
			STAPER = newamt	- REDMOON REMOVAL END*/
			BUFPER += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STAPER = CLAMP(ROUNDSTART_STAPER + BUFPER, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			see_override = initial(src.see_invisible) + (STAPER/2.78) // This may be a mistake.
			update_sight() //Needed.
			update_fov_angles()

		if("intelligence")
/*			newamt = STAINT + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFINT < 0)
				BUFINT = BUFINT + amt
				if(BUFINT > 0)
					newamt = STAINT + BUFINT
					BUFINT = 0
			if(BUFINT > 0)
				BUFINT = BUFINT + amt
				if(BUFINT < 0)
					newamt = STAINT + BUFINT
					BUFINT = 0
			while(newamt < 1)
				newamt++
				BUFINT--
			while(newamt > 20)
				newamt--
				BUFINT++
			STAINT = newamt - REDMOON REMOVAL END*/
			BUFINT += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STAINT = CLAMP(ROUNDSTART_STAINT + BUFINT, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов

		if("constitution")
/*			newamt = STACON + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFCON < 0)
				BUFCON = BUFCON + amt
				if(BUFCON > 0)
					newamt = STACON + BUFCON
					BUFCON = 0
			if(BUFCON > 0)
				BUFCON = BUFCON + amt
				if(BUFCON < 0)
					newamt = STACON + BUFCON
					BUFCON = 0
			while(newamt < 1)
				newamt++
				BUFCON--
			while(newamt > 20)
				newamt--
				BUFCON++
			STACON = newamt - REDMOON REMOVAL END*/
			BUFCON += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STACON = CLAMP(ROUNDSTART_STACON + BUFCON, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов

		if("endurance")
/*			newamt = STAEND + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFEND < 0)
				BUFEND = BUFEND + amt
				if(BUFEND > 0)
					newamt = STAEND + BUFEND
					BUFEND = 0
			if(BUFEND > 0)
				BUFEND = BUFEND + amt
				if(BUFEND < 0)
					newamt = STAEND + BUFEND
					BUFEND = 0
			while(newamt < 1)
				newamt++
				BUFEND--
			while(newamt > 20)
				newamt--
				BUFEND++
			STAEND = newamt - REDMOON REMOVAL END*/
			BUFEND += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STAEND = CLAMP(ROUNDSTART_STAEND + BUFEND, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов

		if("speed")
/*			newamt = STASPD + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFSPE < 0)
				BUFSPE = BUFSPE + amt
				if(BUFSPE > 0)
					newamt = STASPD + BUFSPE
					BUFSPE = 0
			if(BUFSPE > 0)
				BUFSPE = BUFSPE + amt
				if(BUFSPE < 0)
					newamt = STASPD + BUFSPE
					BUFSPE = 0
			while(newamt < 1)
				newamt++
				BUFSPE--
			while(newamt > 20)
				newamt--
				BUFSPE++
			STASPD = newamt - REDMOON REMOVAL END*/
			BUFSPE += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STASPD = CLAMP(ROUNDSTART_STASPD + BUFSPE, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			update_move_intent_slowdown()

		if("fortune")
/*			newamt = STALUC + amt - REDMOON REMOVAL START - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			if(BUFLUC < 0)
				BUFLUC = BUFLUC + amt
				if(BUFLUC > 0)
					newamt = STALUC + BUFLUC
					BUFLUC = 0
			if(BUFLUC > 0)
				BUFLUC = BUFLUC + amt
				if(BUFLUC < 0)
					newamt = STALUC + BUFLUC
					BUFLUC = 0
			while(newamt < 1)
				newamt++
				BUFLUC--
			while(newamt > 20)
				newamt--
				BUFLUC++
			STALUC = newamt - REDMOON REMOVAL END*/
			BUFLUC += amt // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов
			STALUC = CLAMP(ROUNDSTART_STALUC + BUFLUC, 1, 20) // REDMOON ADD - after_death_stats_fix - фикс для статов после смерти и оверкапа статов

/// Calculates a luck value in the range [1, 400] (calculated as STALUC^2), then maps the result linearly to the given range
/// min must be >= 0, max must be <= 100, and min must be <= max
/// For giving 
/mob/living/proc/get_scaled_sq_luck(min, max)
	if (min < 0)
		min = 0
	if (max > 100)
		max = 100
	if (min > max)
		var/temp = min
		min = max
		max = temp
	var/adjusted_luck = (src.STALUC * src.STALUC) / 400
	
	return LERP(min, max, adjusted_luck)


/proc/generic_stat_comparison(userstat as num, targetstat as num)
	var/difference = userstat - targetstat
	if(difference > 1 || difference < -1)
		return difference * 10
	else
		return 0

/mob/living/proc/badluck(multi = 3)
	if(STALUC < 10)
		return prob((10 - STALUC) * multi)

/mob/living/proc/goodluck(multi = 3)
	if(STALUC > 10)
		return prob((STALUC - 10) * multi)
