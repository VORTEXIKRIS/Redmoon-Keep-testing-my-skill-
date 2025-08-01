///////////OFFHAND///////////////
/obj/item/grabbing
	name = "pulling"
	icon_state = "pulling"
	icon = 'icons/mob/roguehudgrabs.dmi'
	w_class = WEIGHT_CLASS_HUGE
	possible_item_intents = list(/datum/intent/grab/upgrade)
	item_flags = ABSTRACT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	grab_state = 0 //this is an atom/movable var i guess
	no_effect = TRUE
	force = 0
	experimental_inhand = FALSE
	var/atom/movable/grabbed //ref to what atom we are grabbing
	var/obj/item/bodypart/limb_grabbed		//ref to actual bodypart being grabbed if we're grabbing a carbo
	var/sublimb_grabbed		//ref to what precise (sublimb) we are grabbing (if any) (zone string or item ref)
	var/mob/living/carbon/grabbee
	var/bleed_suppressing = 0.5 //multiplier for how much we suppress bleeding, can accumulate so two grabs means 25% bleeding
	var/chokehold = FALSE

/atom/movable //reference to all obj/item/grabbing
	var/list/grabbedby

/obj/item/grabbing/Initialize()
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/obj/item/grabbing/process()
	valid_check()

/obj/item/grabbing/proc/valid_check()
	// We require adjacency to count the grab as valid
	if(grabbee.Adjacent(grabbed))
		return TRUE
	grabbee.stop_pulling(FALSE)
	qdel(src)
	return FALSE

/obj/item/grabbing/Click(location, control, params)
	var/list/modifiers = params2list(params)
	if(iscarbon(usr))
		var/mob/living/carbon/C = usr
		if(C != grabbee)
			qdel(src)
			return 1
		if(modifiers["right"])
			qdel(src)
			return 1
	return ..()

/obj/item/grabbing/proc/update_hands(mob/user)
	if(!user)
		return
	if(!iscarbon(user))
		return
	var/mob/living/carbon/C = user
	for(var/i in 1 to C.held_items.len)
		var/obj/item/I = C.get_item_for_held_index(i)
		if(I == src)
			if(i == 1)
				C.r_grab = src
			else
				C.l_grab = src

/obj/item/grabbing/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	LAZYREMOVE(grabbed.grabbedby, src)
	if(limb_grabbed)
		LAZYREMOVE(limb_grabbed.grabbedby, src)
		limb_grabbed = null
		sublimb_grabbed = null
	if(grabbee)
		if(grabbee.r_grab == src)
			grabbee.r_grab = null
		if(grabbee.l_grab == src)
			grabbee.l_grab = null
		if(grabbee.mouth == src)
			grabbee.mouth = null
	return ..()

/obj/item/grabbing/dropped(mob/living/user, show_message = TRUE)
	SHOULD_CALL_PARENT(FALSE)
	// Dont stop the pull if another hand grabs the person
	if(user.r_grab == src)
		if(user.l_grab && user.l_grab.grabbed == user.r_grab.grabbed)
			qdel(src)
			return
	if(user.l_grab == src)
		if(user.r_grab && user.r_grab.grabbed == user.l_grab.grabbed)
			qdel(src)
			return
	if(grabbed == user.pulling)
		user.stop_pulling(FALSE)
	if(!user.pulling)
		user.stop_pulling(FALSE)
	for(var/mob/M in user.buckled_mobs)
		if(M == grabbed)
			user.unbuckle_mob(M, force = TRUE)
	if(QDELETED(src))
		return
	qdel(src)

/obj/item/grabbing/attack(mob/living/M, mob/living/user)
	if(M != grabbed)
		return FALSE
	if(!valid_check())
		return FALSE
	user.changeNext_move(CLICK_CD_MELEE * 2 - user.STASPD) // 24 - the user's speed
	var/skill_diff = 0
	var/combat_modifier = 1
	if(user.mind)
		skill_diff += (user.mind.get_skill_level(/datum/skill/combat/wrestling))
	if(M.mind)
		skill_diff -= (M.mind.get_skill_level(/datum/skill/combat/wrestling))

	if(M.surrendering)
		combat_modifier = 2

	if(M.restrained())
		combat_modifier += 0.25

	if(!(M.mobility_flags & MOBILITY_STAND) && user.mobility_flags & MOBILITY_STAND)
		combat_modifier += 0.05

	if(user.cmode && !M.cmode)
		combat_modifier += 0.3
	else if(!user.cmode && M.cmode)
		combat_modifier -= 0.3

	if(sublimb_grabbed == BODY_ZONE_PRECISE_NECK && grab_state > 0) //grabbing aggresively the neck
		if(user && (M.dir == turn(get_dir(M,user), 180))) //is behind the grabbed
			chokehold = TRUE

	if(chokehold)
		combat_modifier += 0.15

	switch(user.used_intent.type)
		if(/datum/intent/grab/upgrade)
			if(!(M.status_flags & CANPUSH) || HAS_TRAIT(M, TRAIT_PUSHIMMUNE))
				to_chat(user, span_warning("Can't get a grip!"))
				return FALSE
			user.stamina_add(rand(7,15))
			M.grippedby(user)
		if(/datum/intent/grab/choke)
			if(limb_grabbed && grab_state > 0) //this implies a carbon victim
				if(iscarbon(M) && M != user)
					user.stamina_add(rand(1,3))
					var/mob/living/carbon/C = M
					if(get_location_accessible(C, BODY_ZONE_PRECISE_NECK))
						if(prob(25))
							C.emote("choke")
						if(chokehold)
							C.adjustOxyLoss(user.STASTR * 1.2)
						else
							C.adjustOxyLoss(user.STASTR)
						C.visible_message(span_danger("[user] [pick("chokes", "strangles")] [C][chokehold ? " with a chokehold" : ""]!"), \
								span_userdanger("[user] [pick("chokes", "strangles")] me[chokehold ? " with a chokehold" : ""]!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE, user)
						to_chat(user, span_danger("I [pick("choke", "strangle")] [C][chokehold ? " with a chokehold" : ""]!"))
		if(/datum/intent/grab/twist)
			if(limb_grabbed && grab_state > 0) //this implies a carbon victim
				if(iscarbon(M))
					user.stamina_add(rand(3,8))
					twistlimb(user)
		if(/datum/intent/grab/twistitem)
			if(limb_grabbed && grab_state > 0) //this implies a carbon victim
				if(ismob(M))
					user.stamina_add(rand(3,8))
					twistitemlimb(user)
		if(/datum/intent/grab/remove)
			user.stamina_add(rand(3,13))
			if(isitem(sublimb_grabbed))
				removeembeddeditem(user)
			else
				user.stop_pulling()
		if(/datum/intent/grab/shove)
			if(!(user.mobility_flags & MOBILITY_STAND))
				to_chat(user, span_warning("I must stand.."))
				return
			if(!(M.mobility_flags & MOBILITY_STAND))
				if(user.loc != M.loc)
					to_chat(user, span_warning("I must be on top of them."))
					return
				user.stamina_add(rand(10,15))
				M.visible_message(span_danger("[user] pins [M] to the ground!"), \
								span_userdanger("[user] pins me to the ground!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
				M.Stun(max(((65 + (skill_diff * 10) + (user.STASTR * 5) - (M.STASTR * 5)) * combat_modifier), 20))
				user.Immobilize(20 - skill_diff)
			if(usr.buckled)
				to_chat(user, span_warning("I can't be riding a mount."))
				return
			else
				user.stamina_add(rand(5,15))
				if(prob(clamp((((4 + (((user.STASTR - M.STASTR)/2) + skill_diff)) * 10 + rand(-5, 5)) * combat_modifier), 5, 95)))
					M.visible_message(span_danger("[user] shoves [M] to the ground!"), \
									span_userdanger("[user] shoves me to the ground!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
					M.Knockdown(max(10 + (skill_diff * 2), 1))
				else
					M.visible_message(span_warning("[user] tries to shove [M]!"), \
									span_danger("[user] tries to shove me!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
		if(/datum/intent/grab/disarm)
			var/obj/item/I
			if(sublimb_grabbed == BODY_ZONE_PRECISE_L_HAND && M.active_hand_index == 1)
				I = M.get_active_held_item()
			else
				if(sublimb_grabbed == BODY_ZONE_PRECISE_R_HAND && M.active_hand_index == 2)
					I = M.get_active_held_item()
				else
					I = M.get_inactive_held_item()
			user.stamina_add(rand(3,8))
			var/probby = clamp((((3 + (((user.STASTR - M.STASTR)/4) + skill_diff)) * 10) * combat_modifier), 5, 95)
			if(I)
				if(M.mind)
					if(I.associated_skill)
						probby -= M.mind.get_skill_level(I.associated_skill) * 5
				if(I.wielded)
					probby -= 20
				if(prob(probby))
					M.dropItemToGround(I, force = FALSE, silent = FALSE)
					user.stop_pulling()
					user.put_in_active_hand(I)
					M.visible_message(span_danger("[user] takes [I] from [M]'s hand!"), \
								span_userdanger("[user] takes [I] from my hand!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
					user.changeNext_move(12)//avoids instantly attacking with the new weapon
					playsound(src.loc, 'sound/combat/weaponr1.ogg', 100, FALSE, -1) //sound queue to let them know that they got disarmed
				else
					probby += 20
					if(prob(probby))
						M.dropItemToGround(I, force = FALSE, silent = FALSE)
						M.visible_message(span_danger("[user] disarms [M] of [I]!"), \
								span_userdanger("[user] disarms me of [I]!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
						M.Stun(6)//slight delay to pick up the weapon
					else
						user.Immobilize(10)
						M.Immobilize(10)
						M.visible_message(span_notice("[user.name] struggles to disarm [M.name]!"))
						playsound(src.loc, 'sound/foley/struggle.ogg', 100, FALSE, -1)
			else
				to_chat(user, span_warning("They aren't holding anything on that hand!"))
				return


/obj/item/grabbing/proc/twistlimb(mob/living/user) //implies limb_grabbed and sublimb are things
	var/mob/living/carbon/C = grabbed
	var/armor_block = C.run_armor_check(limb_grabbed, "blunt")
	var/damage = user.get_punch_dmg()

	// Scruffing
	if(ishuman(C))
		var/mob/living/carbon/human/H = C
		if((istype(H.dna?.species, /datum/species/tabaxi) || istype(H.dna?.species, /datum/species/lupian)) && sublimb_grabbed == BODY_ZONE_PRECISE_NECK)
			if(get_location_accessible(H, BODY_ZONE_PRECISE_NECK) && H.age == AGE_ADULT) // Is the neck accessible? Also, only applies to adults
				// Making it so it only works from behind, like chokeholds
				if(user && (H.dir == turn(get_dir(H, user), 180)))
					H.Paralyze(20) // 2 seconds of paralysis
					to_chat(H, span_userdanger("You go limp as your scruff is twisted!"))
					to_chat(user, span_warning("You twist [H]'s scruff, causing them to go limp!"))

	if(limb_grabbed.status == BODYPART_ROBOTIC)
		C.visible_message(span_notice("[user] starts twisting [limb_grabbed] of [C], twisting it out of its socket!"), span_notice("I start twisting [limb_grabbed] from [src]."))
		if(do_after(user, 60, target = src))
			C.visible_message(span_notice("[user] twists [limb_grabbed] of [C], popping it out of the socket!"), span_notice("I pop [limb_grabbed] from [src]."))
			limb_grabbed.drop_limb()
			return

	playsound(C.loc, "genblunt", 100, FALSE, -1)
	C.next_attack_msg.Cut()
	C.apply_damage(damage, BRUTE, limb_grabbed, armor_block)
	limb_grabbed.bodypart_attacked_by(BCLASS_TWIST, damage, user, sublimb_grabbed, crit_message = TRUE)
	C.visible_message(span_danger("[user] twists [C]'s [parse_zone(sublimb_grabbed)]![C.next_attack_msg.Join()]"), \
					span_userdanger("[user] twists my [parse_zone(sublimb_grabbed)]![C.next_attack_msg.Join()]"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE, user)
	to_chat(user, span_warning("I twist [C]'s [parse_zone(sublimb_grabbed)].[C.next_attack_msg.Join()]"))
	C.next_attack_msg.Cut()
	log_combat(user, C, "limbtwisted [sublimb_grabbed] ")

// if user is null, the twist is being initiated via a resist
/obj/item/grabbing/proc/twistitemlimb(mob/living/user) //implies limb_grabbed and sublimb are things
	var/mob/living/living_victim = grabbed
	var/damage = rand(5,10)
	var/obj/item/I = sublimb_grabbed
	playsound(living_victim.loc, "genblunt", 100, FALSE, -1)
	living_victim.apply_damage(damage, BRUTE, limb_grabbed)
	// use the user's intent if it's intentional, else use cut by default
	var/bclass_used = user?.used_intent?.blade_class || BCLASS_CUT
	if(istype(limb_grabbed))
		limb_grabbed.try_crit(bclass_used, damage, user || grabbee, silent = TRUE)
	else
		living_victim.simple_try_crit(bclass_used, damage, user || grabbee, silent = TRUE)
	if(user)
		living_victim.visible_message(span_danger("[user] twists [I] in [living_victim]'s wound!"), \
						span_userdanger("[user] twists [I] in my wound!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
		log_combat(user, living_victim, "itemtwisted [sublimb_grabbed] ")
	else
		living_victim.visible_message(span_danger("[living_victim] flails, twisting [I] in the wound!"), \
			span_userdanger("Your flailing twists [I] in the wound!"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE)
		log_combat(living_victim, living_victim, "self itemtwisted [sublimb_grabbed] ")

/obj/item/grabbing/proc/removeembeddeditem(mob/living/user) //implies limb_grabbed and sublimb are things
	var/mob/living/M = grabbed
	var/obj/item/bodypart/L = limb_grabbed
	playsound(M.loc, "genblunt", 100, FALSE, -1)
	log_combat(user, M, "itemremovedgrab [sublimb_grabbed] ")
	if(iscarbon(M))
		var/mob/living/carbon/C = M
		var/obj/item/I = locate(sublimb_grabbed) in L.embedded_objects
		if(QDELETED(I) || QDELETED(L) || !L.remove_embedded_object(I))
			return FALSE
		L.receive_damage(I.embedding.embedded_unsafe_removal_pain_multiplier*I.w_class) //It hurts to rip it out, get surgery you dingus.
		user.dropItemToGround(src) // this will unset vars like limb_grabbed
		user.put_in_hands(I)
		C.emote("paincrit", TRUE)
		playsound(C, 'sound/foley/flesh_rem.ogg', 100, TRUE, -2)
		if(usr == src)
			user.visible_message(span_notice("[user] rips [I] out of [user.p_their()] [L.name]!"), span_notice("I rip [I] from my [L.name]."))
		else
			user.visible_message(span_notice("[user] rips [I] out of [C]'s [L.name]!"), span_notice("I rip [I] from [C]'s [L.name]."))
	else if(HAS_TRAIT(M, TRAIT_SIMPLE_WOUNDS))
		var/obj/item/I = locate(sublimb_grabbed) in M.simple_embedded_objects
		if(QDELETED(I) || !M.simple_remove_embedded_object(I))
			return FALSE
		M.apply_damage(I.embedding.embedded_unsafe_removal_pain_multiplier*I.w_class, BRUTE) //It hurts to rip it out, get surgery you dingus.
		user.dropItemToGround(src) // this will unset vars like limb_grabbed
		user.put_in_hands(I)
		M.emote("paincrit", TRUE)
		playsound(M, 'sound/foley/flesh_rem.ogg', 100, TRUE, -2)
		if(user == M)
			user.visible_message(span_notice("[user] rips [I] out of [user.p_them()]self!"), span_notice("I rip [I] out of myself."))
		else
			user.visible_message(span_notice("[user] rips [I] out of [M]!"), span_notice("I rip [I] out of [src]."))
	user.update_grab_intents(grabbed)
	return TRUE

/obj/item/grabbing/attack_turf(turf/T, mob/living/user)
	if(!valid_check())
		return
	user.changeNext_move(CLICK_CD_MELEE)
	switch(user.used_intent.type)
		if(/datum/intent/grab/move)
			if(isturf(T))
				user.Move_Pulled(T)
		if(/datum/intent/grab/smash)
			if(!(user.mobility_flags & MOBILITY_STAND))
				to_chat(user, span_warning("I must stand.."))
				return
			if(limb_grabbed && grab_state > 0) //this implies a carbon victim
				if(isopenturf(T))
					if(iscarbon(grabbed))
						var/mob/living/carbon/C = grabbed
						if(!C.Adjacent(T))
							return FALSE
						if(C.mobility_flags & MOBILITY_STAND)
							return
						playsound(C.loc, T.attacked_sound, 100, FALSE, -1)
						smashlimb(T, user)
				else if(isclosedturf(T))
					if(iscarbon(grabbed))
						var/mob/living/carbon/C = grabbed
						if(!C.Adjacent(T))
							return FALSE
						if(!(C.mobility_flags & MOBILITY_STAND))
							return
						playsound(C.loc, T.attacked_sound, 100, FALSE, -1)
						smashlimb(T, user)

/obj/item/grabbing/attack_obj(obj/O, mob/living/user)
	if(!valid_check())
		return
	user.changeNext_move(CLICK_CD_MELEE)
	if(user.used_intent.type == /datum/intent/grab/smash)
		if(isstructure(O) && O.blade_dulling != DULLING_CUT)
			if(!(user.mobility_flags & MOBILITY_STAND))
				to_chat(user, span_warning("I must stand.."))
				return
			if(limb_grabbed && grab_state > 0) //this implies a carbon victim
				if(iscarbon(grabbed))
					var/mob/living/carbon/C = grabbed
					if(!C.Adjacent(O))
						return FALSE
					playsound(C.loc, O.attacked_sound, 100, FALSE, -1)
					smashlimb(O, user)


/obj/item/grabbing/proc/smashlimb(atom/A, mob/living/user) //implies limb_grabbed and sublimb are things
	var/mob/living/carbon/C = grabbed
	var/armor_block = C.run_armor_check(limb_grabbed, d_type)
	var/damage = user.get_punch_dmg()
	C.next_attack_msg.Cut()
	if(C.apply_damage(damage, BRUTE, limb_grabbed, armor_block))
		limb_grabbed.bodypart_attacked_by(BCLASS_BLUNT, damage, user, sublimb_grabbed, crit_message = TRUE)
		playsound(C.loc, "smashlimb", 100, FALSE, -1)
	else
		C.next_attack_msg += " <span class='warning'>Armor stops the damage.</span>"
	C.visible_message(span_danger("[user] smashes [C]'s [limb_grabbed.name] into [A]![C.next_attack_msg.Join()]"), \
					span_userdanger("[user] smashes my [limb_grabbed.name] into [A]![C.next_attack_msg.Join()]"), span_hear("I hear a sickening sound of pugilism!"), COMBAT_MESSAGE_RANGE, user)
	to_chat(user, span_warning("I smash [C]'s [limb_grabbed.name] against [A].[C.next_attack_msg.Join()]"))
	C.next_attack_msg.Cut()
	log_combat(user, C, "limbsmashed [limb_grabbed] ")

/datum/intent/grab
	unarmed = TRUE
	chargetime = 0
	noaa = TRUE
	candodge = FALSE
	canparry = FALSE
	no_attack = TRUE
	misscost = 2
	releasedrain = 2

/datum/intent/grab/move
	name = "grab move"
	desc = ""
	icon_state = "inmove"

/datum/intent/grab/upgrade
	name = "upgrade grab"
	desc = ""
	icon_state = "ingrab"

/datum/intent/grab/smash
	name = "smash"
	desc = ""
	icon_state = "insmash"

/datum/intent/grab/twist
	name = "twist"
	desc = ""
	icon_state = "intwist"

/datum/intent/grab/choke
	name = "choke"
	desc = ""
	icon_state = "inchoke"

/datum/intent/grab/shove
	name = "shove"
	desc = ""
	icon_state = "intackle"

/datum/intent/grab/twistitem
	name = "twist in wound"
	desc = ""
	icon_state = "intwist"

/datum/intent/grab/remove
	name = "remove"
	desc = ""
	icon_state = "intake"

/datum/intent/grab/disarm
	name = "disarm"
	desc = ""
	icon_state = "intake"

/obj/item/grabbing/bite
	name = "bite"
	icon_state = "bite"
	slot_flags = ITEM_SLOT_MOUTH
	bleed_suppressing = 1
	var/last_drink
	var/memorylost = FALSE

/obj/item/grabbing/bite/Click(location, control, params)
	var/list/modifiers = params2list(params)
	if(!valid_check())
		return
	if(iscarbon(usr))
		var/mob/living/carbon/C = usr
		if(C != grabbee || C.incapacitated(ignore_restraints = TRUE) || C.stat == DEAD)
			qdel(src)
			return 1
		if(modifiers["right"])
			qdel(src)
			return 1
		var/_y = text2num(params2list(params)["icon-y"])
		if(_y>=17)
			bitelimb(C)
		else
			drinklimb(C)
	return 1

/obj/item/grabbing/bite/proc/bitelimb(mob/living/carbon/human/user) //implies limb_grabbed and sublimb are things
	if(!user.Adjacent(grabbed))
		qdel(src)
		return
	if(world.time <= user.next_move)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	var/mob/living/carbon/C = grabbed
	var/armor_block = C.run_armor_check(sublimb_grabbed, d_type)
	var/damage = user.get_punch_dmg()
	if(HAS_TRAIT(user, TRAIT_STRONGBITE))
		damage = damage*2
	C.next_attack_msg.Cut()
	if(C.apply_damage(damage, BRUTE, limb_grabbed, armor_block))
		playsound(C.loc, "smallslash", 100, FALSE, -1)
		var/datum/wound/caused_wound = limb_grabbed.bodypart_attacked_by(BCLASS_BITE, damage, user, sublimb_grabbed, crit_message = TRUE)
		if(user.mind)
			if(user.mind.has_antag_datum(/datum/antagonist/werewolf))
				caused_wound?.werewolf_infect_attempt()
				if(prob(30))
					user.werewolf_feed(C)
			var/datum/antagonist/zombie/zombie_antag = user.mind.has_antag_datum(/datum/antagonist/zombie)
			if(zombie_antag || istype(user, /mob/living/carbon/human/species/deadite))
				var/datum/antagonist/zombie/existing_zomble = C.mind?.has_antag_datum(/datum/antagonist/zombie)
				if(caused_wound?.zombie_infect_attempt() && !existing_zomble)
					user.mind.adjust_triumphs(1)
			if(HAS_TRAIT(user, TRAIT_POISONBITE))
				if(C.reagents)
					var/poison = user.STACON/4 //more peak species level, more poison
					C.reagents.add_reagent(/datum/reagent/toxin/venom, poison)
					//C.reagents.add_reagent(/datum/reagent/medicine/soporpot, poison)
					to_chat(user, span_warning("You inject venom into [C]!"))
	else
		C.next_attack_msg += " <span class='warning'>Armor stops the damage.</span>"
	C.visible_message(span_danger("[user] bites [C]'s [parse_zone(sublimb_grabbed)]![C.next_attack_msg.Join()]"), \
					span_userdanger("[user] bites my [parse_zone(sublimb_grabbed)]![C.next_attack_msg.Join()]"), span_hear("I hear a sickening sound of chewing!"), COMBAT_MESSAGE_RANGE, user)
	to_chat(user, span_danger("I bite [C]'s [parse_zone(sublimb_grabbed)].[C.next_attack_msg.Join()]"))
	C.next_attack_msg.Cut()
	log_combat(user, C, "limb chewed [sublimb_grabbed] ")

//this is for carbon mobs being drink only
/obj/item/grabbing/bite/proc/drinklimb(mob/living/user) //implies limb_grabbed and sublimb are things
	if(!user.Adjacent(grabbed))
		qdel(src)
		return
	if(world.time <= user.next_move)
		return
	if(world.time < last_drink + 2 SECONDS)
		return
	if(!limb_grabbed.get_bleed_rate())
		to_chat(user, span_warning("Sigh. It's not bleeding."))
		return
	var/mob/living/carbon/C = grabbed
	if(istype(C, /mob/living/carbon/human/species/goblin)|| istype(C, /mob/living/carbon/human/species/goblinp))
		to_chat(user, span_warning("You recoil at the foul taste of graggar corrupted blood."))
		addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living/carbon, vomit), 0, TRUE), rand(8 SECONDS, 15 SECONDS))
		return
	if(C.dna?.species && (NOBLOOD in C.dna.species.species_traits))
		to_chat(user, span_warning("Sigh. No blood."))
		return
	if(C.blood_volume <= 0)
		to_chat(user, span_warning("Sigh. No blood."))
		return
	if(ishuman(C))
		var/mob/living/carbon/human/H = C
		if(istype(H.wear_neck, /obj/item/clothing/neck/roguetown/psicross/silver))
			to_chat(user, span_userdanger("SILVER! HISSS!!!"))
			return
	last_drink = world.time
	user.changeNext_move(CLICK_CD_MELEE)

	if(user.mind && C.mind)
		var/datum/antagonist/vampirelord/VDrinker = user.mind.has_antag_datum(/datum/antagonist/vampirelord)
		var/datum/antagonist/vurdalak/vurdalak_drinker = user.mind.has_antag_datum(/datum/antagonist/vurdalak)
		var/datum/antagonist/vampirelord/VVictim = C.mind.has_antag_datum(/datum/antagonist/vampirelord)
		var/zomwerewolf = C.mind.has_antag_datum(/datum/antagonist/werewolf)
		if(!zomwerewolf)
			if(C.stat != DEAD)
				zomwerewolf = C.mind.has_antag_datum(/datum/antagonist/zombie)
		if(VDrinker)
			if(zomwerewolf)
				to_chat(user, span_danger("I'm going to puke..."))
				addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living/carbon, vomit), 0, TRUE), rand(8 SECONDS, 15 SECONDS))
			else
				if(VVictim)
					to_chat(user, span_warning("It's vitae, just like mine."))
				else if (C.vitae_bank > 500)
					C.blood_volume = max(C.blood_volume-45, 0)
					C.vitae_bank -= 500
					if(!memorylost)	//has the person already gotten the memory loss callback?
						addtimer(CALLBACK(src, /obj/item/grabbing/bite/proc/apply_memory_loss, C, VDrinker), 15 SECONDS)
						memorylost = TRUE	//memory loss callback applied, skip applying on next drink
					if(ishuman(C))
						var/mob/living/carbon/human/H = C
						if(H.virginity)
							to_chat(user, "<span class='love'>Virgin blood, delicious!</span>")
							if(VDrinker.isspawn)
								VDrinker.handle_vitae(750, 750)
							else
								VDrinker.handle_vitae(750)
					if(VDrinker.isspawn)
						VDrinker.handle_vitae(500, 500)
					else
						VDrinker.handle_vitae(500)
				else
					to_chat(user, span_warning("No more vitae from this blood..."))
		else if(vurdalak_drinker)
			if(C.vitae_bank > 500)
				C.blood_volume = max(C.blood_volume-45, 0)
				C.vitae_bank -= 1500
				if(!C.vitae_bank)
					if(!(C.real_name in vurdalak_drinker.unique_victims))
						vurdalak_drinker.unique_victims += C.real_name
						vurdalak_drinker.handle_power_up()
			else
				to_chat(user, span_warning("No more vitae from this blood..."))
		else
			if(VVictim)
				to_chat(user, "<span class='notice'>A strange, sweet taste tickles my throat.</span>")
				addtimer(CALLBACK(user, .mob/living/carbon/human/proc/vampire_infect), 1 MINUTES) // I'll use this for succession later.
			else if(!HAS_TRAIT(user, TRAIT_ORGAN_EATER))
				to_chat(user, span_warning("I'm going to puke..."))
				addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living/carbon, vomit), 0, TRUE), rand(8 SECONDS, 15 SECONDS))
	else
		if(user.mind)
			if(user.mind.has_antag_datum(/datum/antagonist/vampirelord))
				var/datum/antagonist/vampirelord/VDrinker = user.mind.has_antag_datum(/datum/antagonist/vampirelord)
				C.blood_volume = max(C.blood_volume-45, 0)
				if(VDrinker.isspawn)
					VDrinker.handle_vitae(300, 300)
				else
					VDrinker.handle_vitae(300)
			else if(user.mind.has_antag_datum(/datum/antagonist/vurdalak))
				to_chat(user, span_warning("I feel no lifeforce in this blood... It's useless."))

	C.blood_volume = max(C.blood_volume-10, 0)
	C.handle_blood()
	if(HAS_TRAIT(user, TRAIT_ORGAN_EATER))
		user.adjust_hydration(10)

	playsound(user.loc, 'sound/misc/drink_blood.ogg', 100, FALSE, -4)

	C.visible_message(span_danger("[user] drinks from [C]'s [parse_zone(sublimb_grabbed)]!"), \
					span_userdanger("[user] drinks from my [parse_zone(sublimb_grabbed)]!"), span_hear("..."), COMBAT_MESSAGE_RANGE, user)
	to_chat(user, span_warning("I drink from [C]'s [parse_zone(sublimb_grabbed)]."))
	log_combat(user, C, "drank blood from ")

	if(ishuman(C) && C.mind)
		var/datum/antagonist/vampirelord/VDrinker = user.mind.has_antag_datum(/datum/antagonist/vampirelord)
		if(C.blood_volume <= BLOOD_VOLUME_SURVIVE)
			if(!VDrinker.isspawn)
				switch(alert("Would you like to sire a new spawn?",,"Yes","No"))
					if("Yes")
						user.visible_message("[user] begins to infuse dark magic into [C]")
						if(do_after(user, 30))
							C.visible_message("[C] rises as a new spawn!")
							var/datum/antagonist/vampirelord/lesser/new_antag = new /datum/antagonist/vampirelord/lesser()
							new_antag.sired = TRUE
							C.mind.add_antag_datum(new_antag)
							C.set_patron(/datum/patron/zizo)
							sleep(20)
							C.fully_heal()
							VDrinker.handle_vitae(0) // Updates pool max.
					if("No")
						to_chat(user, span_warning("I decide [C] is unworthy."))


/obj/item/grabbing/bite/proc/apply_memory_loss(mob/living/target, mob/living/user)
	to_chat(target, span_notice("You feel... something slipping away. You can't remember who bit you!"))
	target.visible_message(span_notice("[target] looks rather confused!"))
	target.drowsyness = min(target.drowsyness + 50, 150)
	log_game("[key_name(target)] has lost memory due to [key_name(user)]'s vampiric bite.")
	memorylost = FALSE	//after this proc is ran, it can be ran again
