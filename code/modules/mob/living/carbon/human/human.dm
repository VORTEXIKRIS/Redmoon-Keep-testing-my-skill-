#ifdef MATURESERVER
/mob/living/carbon/human/MiddleClick(mob/user, params)
	..()
	if(!user)
		return
	var/obj/item/held_item = user.get_active_held_item()
	if(held_item && (user.zone_selected == BODY_ZONE_PRECISE_MOUTH))
		if(held_item.get_sharpness() && held_item.wlength == WLENGTH_SHORT)
			if(has_stubble)
				if(user == src)
					user.visible_message("<span class='danger'>[user] starts to shave [user.p_their()] stubble with [held_item].</span>")
				else
					user.visible_message("<span class='danger'>[user] starts to shave [src]'s stubble with [held_item].</span>")
				if(do_after(user, 50, needhand = 1, target = src))
					has_stubble = FALSE
					update_hair()
				else
					held_item.melee_attack_chain(user, src, params)
			else if(facial_hairstyle != "None")
				if(user == src)
					user.visible_message("<span class='danger'>[user] starts to shave [user.p_their()] facehairs with [held_item].</span>")
				else
					user.visible_message("<span class='danger'>[user] starts to shave [src]'s facehairs with [held_item].</span>")
				if(do_after(user, 50, needhand = 1, target = src))
					facial_hairstyle = "None"
					update_hair()
					if(dna?.species?.id == "dwarf")
						add_stress(/datum/stressevent/dwarfshaved)
				else
					held_item.melee_attack_chain(user, src, params)
		return
	if(user == src)
		if(get_num_arms(FALSE) < 1)
			return
		if(user.zone_selected == BODY_ZONE_PRECISE_GROIN)
			if(get_location_accessible(src, BODY_ZONE_PRECISE_GROIN, skipundies = TRUE))
				if(underwear == "Nude")
					return
				if(do_after(user, 30, needhand = 1, target = src))
					cached_underwear = underwear
					underwear = "Nude"
					update_body()
					var/obj/item/undies/U
					if(body_type == MALE)
						U = new/obj/item/undies(get_turf(src))
					else
						U = new/obj/item/undies/f(get_turf(src))
					U.color = underwear_color
					user.put_in_hands(U)
#endif

/mob/living/carbon/human/Initialize()
#ifdef MATURESERVER
	sexcon = new /datum/sex_controller(src)
#endif
	verbs += /mob/living/proc/lay_down

	icon_state = ""		//Remove the inherent human icon that is visible on the map editor. We're rendering ourselves limb by limb, having it still be there results in a bug where the basic human icon appears below as south in all directions and generally looks nasty.

	if(!body_type)
		body_type = gender
	
	//initialize limbs first
	create_bodyparts()

	setup_human_dna()

	if(dna.species)
		set_species(dna.species.type)

	//initialise organs
	create_internal_organs() //most of it is done in set_species now, this is only for parent call
	physiology = new()

	. = ..()

	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(clean_blood))
	AddComponent(/datum/component/personal_crafting)
	AddComponent(/datum/component/footstep, footstep_type, 1, 2)
	GLOB.human_list += src

/mob/living/carbon/human/ZImpactDamage(turf/T, levels)
	var/dam = levels * rand(10,50)
	add_stress(/datum/stressevent/felldown)
	var/list/obj/item/bodypart/candidates = list()
	for(var/candidate in list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_R_ARM, BODY_ZONE_L_ARM, BODY_ZONE_CHEST, BODY_ZONE_HEAD))
		var/the_organ = get_bodypart(candidate)
		if(the_organ)
			candidates += the_organ
	var/chat_message
	var/obj/item/bodypart/affecting = pick(candidates) // this should never be null, a mob should always have at least a chest
	if(affecting) // but just in case, check anyway
		chat_message = span_danger("I fall on my [affecting.name]!")
		if(affecting.body_zone == BODY_ZONE_CHEST)
			chat_message = span_danger("I fall flat! I'm winded!")
			emote("gasp")
			adjustOxyLoss(50)
		apply_damage(dam/2, BRUTE, affecting) // half the damage bypasses armour
		if(apply_damage(dam/2, BRUTE, affecting, run_armor_check(affecting, "blunt", damage = dam)))
			if(levels >= 1)
				//absurd damage to guarantee a crit
				affecting.try_crit(BCLASS_TWIST, 300)
		update_damage_overlays()

	if(chat_message)
		to_chat(src, chat_message)

	AdjustKnockdown(levels * 15)

/mob/living/carbon/human/proc/setup_human_dna()
	//initialize dna. for spawned humans; overwritten by other code
	create_dna(src)
	randomize_human(src)
	dna.initialize_dna()

/mob/living/carbon/human/ComponentInitialize()
	. = ..()
	if(!CONFIG_GET(flag/disable_human_mood))
		AddComponent(/datum/component/mood)

/mob/living/carbon/human/Destroy()
	QDEL_NULL(sexcon)
	STOP_PROCESSING(SShumannpc, src)
	QDEL_NULL(physiology)
	GLOB.human_list -= src
	return ..()

/mob/living/carbon/human/Stat()
	..()
	if(mind)
		var/datum/antagonist/vampirelord/VD = mind.has_antag_datum(/datum/antagonist/vampirelord)
		if(VD)
			if(statpanel("Stats"))
				stat("Vitae:",VD.vitae)
		if(skin_armor)
			stat("Skin Armor Integrity:", skin_armor.obj_integrity)
		if((mind.assigned_role == "Confessor") || (mind.assigned_role == "Inquisitor"))
			if(statpanel("Status"))
				stat("Confessions sent: [GLOB.confessors.len]")

	return //RTchange

/mob/living/carbon/human/show_inv(mob/user)
	user.set_machine(src)
	var/list/obscured = check_obscured_slots()
	var/list/dat = list()

	dat += "<table>"

	if(handcuffed)
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_HANDCUFFED]'>Remove [handcuffed]</A></td></tr>"
	if(legcuffed)
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_LEGCUFFED]'>Remove [legcuffed]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

	for(var/i in 1 to held_items.len)
		var/obj/item/I = get_item_for_held_index(i)
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_HANDS];hand_index=[i]'>[(I && !(I.item_flags & ABSTRACT)) ? I : "<font color=grey>[get_held_index_name(i)]</font>"]</a></td></tr>"

	dat += "<tr><td><hr></td></tr>"

//	if(has_breathable_mask && istype(back, /obj/item/tank))
//		dat += "&nbsp;<A href='?src=[REF(src)];internal=[SLOT_BACK]'>[internal ? "Disable Internals" : "Set Internals"]</A>"

//	dat += "<tr><td><B>HEAD</B></td></tr>"

	//head
	if(SLOT_HEAD in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_HEAD]'>[(head && !(head.item_flags & ABSTRACT)) ? head : "<font color=grey>Head</font>"]</A></td></tr>"

	if(SLOT_WEAR_MASK in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_WEAR_MASK]'>[(wear_mask && !(wear_mask.item_flags & ABSTRACT)) ? wear_mask : "<font color=grey>Mask</font>"]</A></td></tr>"

	if(SLOT_MOUTH in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_MOUTH]'>[(mouth && !(mouth.item_flags & ABSTRACT)) ? mouth : "<font color=grey>Mouth</font>"]</A></td></tr>"

	if(SLOT_NECK in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_NECK]'>[(wear_neck && !(wear_neck.item_flags & ABSTRACT)) ? wear_neck : "<font color=grey>Neck</font>"]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

//	dat += "<tr><td><B>BACK</B></td></tr>"

	if(SLOT_CLOAK in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_CLOAK]'>[(cloak && !(cloak.item_flags & ABSTRACT)) ? cloak : "<font color=grey>Cloak</font>"]</A></td></tr>"

	if(SLOT_BACK_R in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_BACK_R]'>[(backr && !(backr.item_flags & ABSTRACT)) ? backr : "<font color=grey>Back</font>"]</A></td></tr>"

	if(SLOT_BACK_L in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_BACK_L]'>[(backl && !(backl.item_flags & ABSTRACT)) ? backl : "<font color=grey>Back</font>"]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

//	dat += "<tr><td><B>TORSO</B></td></tr>"

	if(SLOT_ARMOR in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_ARMOR]'>[(wear_armor && !(wear_armor.item_flags & ABSTRACT)) ? wear_armor : "<font color=grey>Armor</font>"]</A></td></tr>"

	if(SLOT_SHIRT in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_SHIRT]'>[(wear_shirt && !(wear_shirt.item_flags & ABSTRACT)) ? wear_shirt : "<font color=grey>Shirt</font>"]</A></td></tr>"

	if(SLOT_GLOVES in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_GLOVES]'>[(gloves && !(gloves.item_flags & ABSTRACT)) ? gloves : "<font color=grey>Gloves</font>"]</A></td></tr>"

	if(SLOT_RING in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_RING]'>[(wear_ring && !(wear_ring.item_flags & ABSTRACT)) ? wear_ring : "<font color=grey>Ring</font>"]</A></td></tr>"

	if(SLOT_WRISTS in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_WRISTS]'>[(wear_wrists && !(wear_wrists.item_flags & ABSTRACT)) ? wear_wrists : "<font color=grey>Wrists</font>"]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

//	dat += "<tr><td><B>WAIST</B></td></tr>"

	if(SLOT_BELT in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_BELT]'>[(belt && !(belt.item_flags & ABSTRACT)) ? belt : "<font color=grey>Belt</font>"]</A></td></tr>"

	if(SLOT_BELT_R in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_BELT_R]'>[(beltr && !(beltr.item_flags & ABSTRACT)) ? beltr : "<font color=grey>Hip</font>"]</A></td></tr>"

	if(SLOT_BELT_L in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_BELT_L]'>[(beltl && !(beltl.item_flags & ABSTRACT)) ? beltl : "<font color=grey>Hip</font>"]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

//	dat += "<tr><td><B>LEGS</B></td></tr>"

	if(SLOT_PANTS in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_PANTS]'>[(wear_pants && !(wear_pants.item_flags & ABSTRACT)) ? wear_pants : "<font color=grey>Trousers</font>"]</A></td></tr>"

	if(SLOT_SHOES in obscured)
		dat += "<tr><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_SHOES]'>[(shoes && !(shoes.item_flags & ABSTRACT)) ? shoes : "<font color=grey>Boots</font>"]</A></td></tr>"

	dat += "<tr><td><hr></td></tr>"

#ifdef MATURESERVER
	if(get_location_accessible(src, BODY_ZONE_PRECISE_GROIN, skipundies = TRUE))
		dat += "<tr><td><BR><B>Underwear:</B> <A href='?src=[REF(src)];undiesthing=1'>[underwear == "Nude" ? "Nothing" : "Remove"]</A></td></tr>"
#endif

	dat += {"</table>"}

	var/datum/browser/popup = new(user, "mob[REF(src)]", "[src]", 220, 690)
	popup.set_content(dat.Join())
	popup.open()

// called when something steps onto a human
// this could be made more general, but for now just handle mulebot
/mob/living/carbon/human/Crossed(atom/movable/AM)
	. = ..()
	spreadFire(AM)

/mob/living/carbon/human/proc/canUseHUD()
	return (mobility_flags & MOBILITY_USE)

/mob/living/carbon/human/can_inject(mob/user, error_msg, target_zone, penetrate_thick = 0)
	. = 1 // Default to returning true.
	if(user && !target_zone)
		target_zone = user.zone_selected
	if(HAS_TRAIT(src, TRAIT_PIERCEIMMUNE))
		. = 0
	// If targeting the head, see if the head item is thin enough.
	// If targeting anything else, see if the wear suit is thin enough.
	if (!penetrate_thick)
		if(above_neck(target_zone))
			if(head && istype(head, /obj/item/clothing))
				var/obj/item/clothing/CH = head
				if (CH.clothing_flags & THICKMATERIAL)
					. = 0
		else
			if(wear_armor && istype(wear_armor, /obj/item/clothing))
				var/obj/item/clothing/CS = wear_armor
				if (CS.clothing_flags & THICKMATERIAL)
					. = 0
	if(!. && error_msg && user)
		// Might need re-wording.
		to_chat(user, span_alert("There is no exposed flesh or thin material [above_neck(target_zone) ? "on [p_their()] head" : "on [p_their()] body"]."))


//Used for new human mobs created by cloning/goleming/podding
/mob/living/carbon/human/proc/set_cloned_appearance()
	if(gender == MALE)
		facial_hairstyle = "Full Beard"
	else
		facial_hairstyle = "Shaved"
	hairstyle = pick("Bedhead", "Bedhead 2", "Bedhead 3")
	underwear = "Nude"
	update_body()
	update_hair()

/mob/living/carbon/human/proc/do_cpr(mob/living/carbon/C)
	CHECK_DNA_AND_SPECIES(C)

	if(C.stat == DEAD || (HAS_TRAIT(C, TRAIT_FAKEDEATH)))
		to_chat(src, span_warning("[C.name] is dead!"))
		return
	if(is_mouth_covered())
		to_chat(src, span_warning("Remove your mask first!"))
		return 0
	if(C.is_mouth_covered())
		to_chat(src, span_warning("Remove [p_their()] mask first!"))
		return 0

	if(C.cpr_time < world.time + 30)
		visible_message(span_notice("[src] is trying to perform CPR on [C.name]!"), \
						span_notice("I try to perform CPR on [C.name]... Hold still!"))
		if(!do_mob(src, C))
			to_chat(src, span_warning("I fail to perform CPR on [C]!"))
			return 0

		var/they_breathe = !HAS_TRAIT(C, TRAIT_NOBREATH)
		var/they_lung = C.getorganslot(ORGAN_SLOT_LUNGS)

		if(C.health > C.crit_threshold)
			return

		src.visible_message(span_notice("[src] performs CPR on [C.name]!"), span_notice("I perform CPR on [C.name]."))
		SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "perform_cpr", /datum/mood_event/perform_cpr)
		C.cpr_time = world.time
		log_combat(src, C, "CPRed")

		if(they_breathe && they_lung)
			var/suff = min(C.getOxyLoss(), 7)
			C.adjustOxyLoss(-suff)
			C.updatehealth()
			to_chat(C, span_unconscious("I feel a breath of fresh air enter my lungs... It feels good..."))
		else if(they_breathe && !they_lung)
			to_chat(C, span_unconscious("I feel a breath of fresh air... but I don't feel any better..."))
		else
			to_chat(C, span_unconscious("I feel a breath of fresh air... which is a sensation I don't recognise..."))

/mob/living/carbon/human/cuff_resist(obj/item/I)
	if(..())
		dropItemToGround(I)

/mob/living/carbon/human/proc/clean_blood(datum/source, strength)
	if(strength < CLEAN_STRENGTH_BLOOD)
		return
	if(gloves)
		if(SEND_SIGNAL(gloves, COMSIG_COMPONENT_CLEAN_ACT, CLEAN_STRENGTH_BLOOD))
			update_inv_gloves()
	else
		if(bloody_hands)
			bloody_hands = 0
			update_inv_gloves()

//Turns a mob black, flashes a skeleton overlay
//Just like a cartoon!
/mob/living/carbon/human/proc/electrocution_animation(anim_duration)
	//Handle mutant parts if possible
	if(dna && dna.species)
		add_atom_colour("#000000", TEMPORARY_COLOUR_PRIORITY)
		var/static/mutable_appearance/electrocution_skeleton_anim
		if(!electrocution_skeleton_anim)
			electrocution_skeleton_anim = mutable_appearance(icon, "electrocuted_base")
			electrocution_skeleton_anim.appearance_flags |= RESET_COLOR|KEEP_APART
		add_overlay(electrocution_skeleton_anim)
		addtimer(CALLBACK(src, PROC_REF(end_electrocution_animation), electrocution_skeleton_anim), anim_duration)

	else //or just do a generic animation
		flick_overlay_view(image(icon,src,"electrocuted_generic",ABOVE_MOB_LAYER), src, anim_duration)

/mob/living/carbon/human/proc/end_electrocution_animation(mutable_appearance/MA)
	remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, "#000000")
	cut_overlay(MA)

/mob/living/carbon/human/canUseTopic(atom/movable/M, be_close=FALSE, no_dexterity=FALSE, no_tk=FALSE)
	if(!(mobility_flags & MOBILITY_UI))
		to_chat(src, span_warning("I can't do that right now!"))
		return FALSE
	if(!Adjacent(M) && (M.loc != src))
		if((be_close == FALSE) || (!no_tk && (tkMaxRangeCheck(src, M))))
			return TRUE
		to_chat(src, span_warning("I am too far away!"))
		return FALSE
	return TRUE

/mob/living/carbon/human/resist_restraints()
	if(wear_armor && wear_armor.breakouttime)
		changeNext_move(CLICK_CD_BREAKOUT)
		last_special = world.time + CLICK_CD_BREAKOUT
		cuff_resist(wear_armor)
	else
		..()

/mob/living/carbon/human/replace_records_name(oldname,newname) // Only humans have records right now, move this up if changed.
	for(var/list/L in list(GLOB.data_core.general,GLOB.data_core.medical,GLOB.data_core.security,GLOB.data_core.locked))
		var/datum/data/record/R = find_record("name", oldname, L)
		if(R)
			R.fields["name"] = newname

/mob/living/carbon/human/get_total_tint()
	. = ..()
	if(glasses)
		. += glasses.tint

/mob/living/carbon/human/update_tod_hud()
	if(!client || !hud_used)
		return
	if(hud_used.clock)
		hud_used.clock.update_icon()

/mob/living/carbon/human/update_health_hud()
	if(!client || !hud_used)
		return
	if(dna.species.update_health_hud())
		return
	else
		if(hud_used.bloods)
			// small check for no_blood trait (currently for liches)
			if(HAS_TRAIT(src, TRAIT_NO_BLOOD))
				// instead of utilizing blood volume, we're going to use limb damage for our health_hud
				var/total_damage = 0
				var/total_max = 0
				for(var/X in bodyparts)
					var/obj/item/bodypart/BP = X
					total_damage += (BP.brute_dam + BP.burn_dam)
					total_max += BP.max_damage
				
				var/damage_percent = 0
				if(total_max > 0)
					damage_percent = (total_damage / total_max) * 100

				// here we use limb damage for our health_hud hehe
				if(damage_percent <= 0)
					hud_used.bloods.icon_state = "dam0"
				else
					var/used = round(damage_percent, 10)
					if(used <= 80)
						hud_used.bloods.icon_state = "dam[used]"
					else
						hud_used.bloods.icon_state = "damelse"
			else
				// normal blood hud flow etc
				var/bloodloss = ((BLOOD_VOLUME_NORMAL - blood_volume) / BLOOD_VOLUME_NORMAL) * 100

				var/burnhead = 0
				var/brutehead = 0
				var/obj/item/bodypart/head = get_bodypart(BODY_ZONE_HEAD)
				if(head)
					burnhead = (head.burn_dam / head.max_damage) * 100
					brutehead = (head.brute_dam / head.max_damage) * 100

				var/toxloss = getToxLoss()
				var/oxloss = getOxyLoss()

				var/hungloss = nutrition*-1 //this is smart i think

				var/usedloss = 0
				if(bloodloss > 0)
					usedloss = bloodloss
				if(burnhead > usedloss)
					usedloss = burnhead
				if(brutehead > usedloss)
					usedloss = brutehead
				if(toxloss > usedloss)
					usedloss = toxloss
				if(oxloss > usedloss)
					usedloss = oxloss
				if(hungloss > usedloss)
					usedloss = hungloss

				if(usedloss <= 0)
					hud_used.bloods.icon_state = "dam0"
				else
					var/used = round(usedloss, 10)
					if(used <= 80)
						hud_used.bloods.icon_state = "dam[used]"
					else
						hud_used.bloods.icon_state = "damelse"

/*		if(hud_used.healthdoll)
			hud_used.healthdoll.cut_overlays()
			if(stat != DEAD)
				hud_used.healthdoll.icon_state = "healthdoll_OVERLAY"
				for(var/X in bodyparts)
					var/obj/item/bodypart/BP = X
					var/damage = BP.burn_dam + BP.brute_dam
					var/comparison = (BP.max_damage/5)
					var/icon_num = 0
					if(damage)
						icon_num = 1
					if(damage > (comparison))
						icon_num = 2
					if(damage > (comparison*2))
						icon_num = 3
					if(damage > (comparison*3))
						icon_num = 4
					if(damage > (comparison*4))
						icon_num = 5
					if(hal_screwyhud == SCREWYHUD_HEALTHY)
						icon_num = 0
					if(icon_num)
						hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[BP.body_zone][icon_num]"))
				for(var/t in get_missing_limbs()) //Missing limbs
					hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[t]6"))
				for(var/t in get_disabled_limbs()) //Disabled limbs
					hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[t]7"))
			else
				hud_used.healthdoll.icon_state = "healthdoll_DEAD"*/

		if(hud_used.stamina)
			if(stat != DEAD)
				. = 1
				if(stamina >= max_stamina)
					hud_used.stamina.icon_state = "fat0"
				else if(stamina > max_stamina*0.90)
					hud_used.stamina.icon_state = "fat10"
				else if(stamina > max_stamina*0.80)
					hud_used.stamina.icon_state = "fat20"
				else if(stamina > max_stamina*0.70)
					hud_used.stamina.icon_state = "fat30"
				else if(stamina > max_stamina*0.60)
					hud_used.stamina.icon_state = "fat40"
				else if(stamina > max_stamina*0.50)
					hud_used.stamina.icon_state = "fat50"
				else if(stamina > max_stamina*0.40)
					hud_used.stamina.icon_state = "fat60"
				else if(stamina > max_stamina*0.30)
					hud_used.stamina.icon_state = "fat70"
				else if(stamina > max_stamina*0.20)
					hud_used.stamina.icon_state = "fat80"
				else if(stamina > max_stamina*0.10)
					hud_used.stamina.icon_state = "fat90"
				else if(stamina >= 0)
					hud_used.stamina.icon_state = "fat100"
		if(hud_used.energy)
			if(stat != DEAD)
				. = 1
				if(energy <= 0)
					hud_used.energy.icon_state = "stam0"
				else if(energy > max_energy*0.90)
					hud_used.energy.icon_state = "stam100"
				else if(energy > max_energy*0.80)
					hud_used.energy.icon_state = "stam90"
				else if(energy > max_energy*0.70)
					hud_used.energy.icon_state = "stam80"
				else if(energy > max_energy*0.60)
					hud_used.energy.icon_state = "stam70"
				else if(energy > max_energy*0.50)
					hud_used.energy.icon_state = "stam60"
				else if(energy > max_energy*0.40)
					hud_used.energy.icon_state = "stam50"
				else if(energy > max_energy*0.30)
					hud_used.energy.icon_state = "stam40"
				else if(energy > max_energy*0.20)
					hud_used.energy.icon_state = "stam30"
				else if(energy > max_energy*0.10)
					hud_used.energy.icon_state = "stam20"
				else if(energy > 0)
					hud_used.energy.icon_state = "stam10"

		if(hud_used.zone_select)
			hud_used.zone_select.update_icon()

/mob/living/carbon/human/fully_heal(admin_revive = FALSE)
	dna?.species.spec_fully_heal(src)
	if(admin_revive)
		regenerate_limbs()
		regenerate_organs()
	spill_embedded_objects()
	set_heartattack(FALSE)
	drunkenness = 0
	..()

/mob/living/carbon/human/check_weakness(obj/item/weapon, mob/living/attacker)
	. = ..()
	if (dna && dna.species)
		. += dna.species.check_species_weakness(weapon, attacker)

/mob/living/carbon/human/is_literate()
	if(mind)
		if(mind.get_skill_level(/datum/skill/misc/reading) > 0)
			return TRUE
		else
			return FALSE
	return TRUE

/mob/living/carbon/human/can_hold_items()
	return TRUE

/mob/living/carbon/human/update_gravity(has_gravity,override = 0)
	if(dna && dna.species) //prevents a runtime while a human is being monkeyfied
		override = dna.species.override_float
	..()

/mob/living/carbon/human/vomit(lost_nutrition = 100, blood = 0, stun = 1, distance = 0, message = 1, toxic = 0)
	if(blood && (NOBLOOD in dna.species.species_traits) && !HAS_TRAIT(src, TRAIT_TOXINLOVER))
		if(message)
			visible_message(span_warning("[src] dry heaves!"), \
							span_danger("I try to throw up, but there's nothing in my stomach!"))
		if(stun)
			Immobilize(200)
		return 1
	..()

/mob/living/carbon/human/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---------")
	VV_DROPDOWN_OPTION(VV_HK_APPLY_SPECIAL, "Apply Special Trait")
	VV_DROPDOWN_OPTION(VV_HK_REAPPLY_PREFS, "Reapply Preferences")
	VV_DROPDOWN_OPTION(VV_HK_COPY_OUTFIT, "Copy Outfit")
	VV_DROPDOWN_OPTION(VV_HK_SET_SPECIES, "Set Species")

/mob/living/carbon/human/vv_do_topic(list/href_list)
	. = ..()
	if(href_list[VV_HK_REAPPLY_PREFS])
	
		if(!check_rights(R_SPAWN))
			return
		if(!client || !client.prefs)
			return
		client.prefs.copy_to(src, TRUE, FALSE)
	if(href_list[VV_HK_APPLY_SPECIAL])
		if(!check_rights(R_SPAWN))
			return
		var/mob/admin_user = usr
		message_admins("Admin [key_name_admin(admin_user)] is applying a special trait to [key_name(src)].")
		var/first_result = input(admin_user, "Chosen or random?","Apply Special") as null|anything in list("Choose", "Random")
		if(!first_result)
			return
		var/trait_type
		if(first_result == "Choose")
			var/trait_result = input(admin_user, "Choose special to apply","Apply Special") as null|anything in GLOB.special_traits
			if(!trait_result)
				return
			trait_type = trait_result
		else
			trait_type = get_random_special_for_char(src, src.client)
		if(!trait_type)
			return
		var/silent_result = input(admin_user, "Trait: [trait_type]\nGive player the trait greet text?","Apply Special") as null|anything in list("Yes", "No", "Cancel")
		var/silent = FALSE
		if(!silent_result || silent_result == "Cancel")
			return
		if(silent_result == "No")
			silent = TRUE
		message_admins("Admin [key_name_admin(admin_user)] applied special [trait_type] to [key_name(src)]. [first_result == "Chosen" ? "(Chosen)" : "(Random)"][silent_result == "No" ? "(Silent)" : ""]")
		apply_special_trait(src, trait_type, silent)
	if(href_list[VV_HK_COPY_OUTFIT])
		if(!check_rights(R_SPAWN))
			return
		copy_outfit()

	if(href_list[VV_HK_SET_SPECIES])
		if(!check_rights(R_SPAWN))
			return
		var/result = input(usr, "Please choose a new species","Species") as null|anything in GLOB.species_list
		if(result)
			var/newtype = GLOB.species_list[result]
			admin_ticket_log("[key_name_admin(usr)] has modified the bodyparts of [src] to [result]")
			set_species(newtype)

//Target = what was clicked on, User = thing doing the clicking
/mob/living/carbon/human/MouseDrop_T(mob/living/target, mob/living/user)
	if(isseelie(target) && !(HAS_TRAIT(src, TRAIT_TINY)) && istype(user.rmb_intent, /datum/rmb_intent/weak))
		if(can_piggyback(target))
			shoulder_ride(target)
			return TRUE

	if(user == target)
		return FALSE
	if(pulling == target && stat == CONSCIOUS)
		//If they dragged themselves and we're currently aggressively grabbing them try to piggyback
		if(user == target && can_piggyback(target))
			piggyback(target)
			return TRUE
		//If you dragged them to you and you're aggressively grabbing try to carry them
		else if(user != target && can_be_firemanned(target))
			var/obj/G = get_active_held_item()
			if(G)
				if(istype(G, /obj/item/grabbing))
					fireman_carry(target)
					return TRUE
	. = ..()

/mob/living/carbon/human/proc/shoulder_ride(mob/living/carbon/target)
	buckle_mob(target, TRUE, TRUE, FALSE, 0, 0)
	visible_message(span_notice("[target] gently sits on [src]'s shoulder."))
	//target.set_mob_offsets("shoulder_ride", _x = 5, _y = 10)

//src is the user that will be carrying, target is the mob to be carried
/mob/living/carbon/human/proc/can_piggyback(mob/living/carbon/target)
	return (istype(target) && target.stat == CONSCIOUS)

/mob/living/carbon/human/proc/can_be_firemanned(mob/living/carbon/target)
	return (ishuman(target) && !(target.mobility_flags & MOBILITY_STAND))

/mob/living/carbon/human/proc/fireman_carry(mob/living/carbon/target)
	var/carrydelay = 50 //if you have latex you are faster at grabbing

	if(HAS_TRAIT(src, TRAIT_TINY))
		to_chat(src, span_warning("I'm too small to carry [target]."))
		return

	var/backnotshoulder = FALSE
	if(r_grab && l_grab)
		if(r_grab.grabbed == target)
			if(l_grab.grabbed == target)
				backnotshoulder = TRUE

	if(can_be_firemanned(target) && !incapacitated(FALSE, TRUE))
		if(backnotshoulder)
			visible_message(span_notice("[src] starts lifting [target] onto their back.."))
		else
			visible_message(span_notice("[src] starts lifting [target] onto their shoulder.."))
		if(do_after(src, carrydelay, TRUE, target))
			//Second check to make sure they're still valid to be carried
			if(can_be_firemanned(target) && !incapacitated(FALSE, TRUE))
				buckle_mob(target, TRUE, TRUE, 90, 0, 0)
				return
	to_chat(src, span_warning("I fail to carry [target]."))

/mob/living/carbon/human/proc/piggyback(mob/living/carbon/target)
	if(can_piggyback(target))
		visible_message(span_notice("[target] starts to climb onto [src]..."))
		if(do_after(target, 15, target = src))
			if(can_piggyback(target))
				if(target.incapacitated(FALSE, TRUE) || incapacitated(FALSE, TRUE))
					to_chat(target, span_warning("I can't piggyback ride [src]."))
					return
				buckle_mob(target, TRUE, TRUE, FALSE, 0, 0)
	else
		to_chat(target, span_warning("I can't piggyback ride [src]."))

/mob/living/carbon/human/buckle_mob(mob/living/target, force = FALSE, check_loc = TRUE, lying_buckle = FALSE, hands_needed = 0, target_hands_needed = 0)
	if(!force)//humans are only meant to be ridden through piggybacking and special cases
		return
	if(!is_type_in_typecache(target, can_ride_typecache))
		target.visible_message(span_warning("[target] really can't seem to mount [src]..."))
		return
	buckle_lying = lying_buckle
	var/datum/component/riding/human/riding_datum = LoadComponent(/datum/component/riding/human)
	if(target_hands_needed)
		riding_datum.ride_check_rider_restrained = TRUE
	if(buckled_mobs && ((target in buckled_mobs) || (buckled_mobs.len >= max_buckled_mobs)) || buckled)
		return
	var/equipped_hands_self
	var/equipped_hands_target
	if(hands_needed)
		equipped_hands_self = riding_datum.equip_buckle_inhands(src, hands_needed, target)
	if(target_hands_needed)
		equipped_hands_target = riding_datum.equip_buckle_inhands(target, target_hands_needed)

	if(hands_needed || target_hands_needed)
		if(hands_needed && !equipped_hands_self)
			src.visible_message(span_warning("[src] can't get a grip on [target] because their hands are full!"),
				span_warning("I can't get a grip on [target] because my hands are full!"))
			return
		else if(target_hands_needed && !equipped_hands_target)
			target.visible_message(span_warning("[target] can't get a grip on [src] because their hands are full!"),
				span_warning("I can't get a grip on [src] because my hands are full!"))
			return

	//stop_pulling()
	riding_datum.handle_vehicle_layer()
	. = ..(target, force, check_loc)

/mob/living/carbon/human/proc/is_shove_knockdown_blocked() //If you want to add more things that block shove knockdown, extend this
	var/list/body_parts = list(head, wear_mask, wear_armor, wear_pants, back, gloves, shoes, belt, s_store, glasses, ears, wear_ring) //Everything but pockets. Pockets are l_store and r_store. (if pockets were allowed, putting something armored, gloves or hats for example, would double up on the armor)
	for(var/bp in body_parts)
		if(istype(bp, /obj/item/clothing))
			var/obj/item/clothing/C = bp
			if(C.clothing_flags & BLOCKS_SHOVE_KNOCKDOWN)
				return TRUE
	return FALSE

/mob/living/carbon/human/proc/clear_shove_slowdown()
	remove_movespeed_modifier(MOVESPEED_ID_SHOVE)
	var/active_item = get_active_held_item()
	if(is_type_in_typecache(active_item, GLOB.shove_disarming_types))
		visible_message(span_warning("[src] regains their grip on \the [active_item]!"), span_warning("I regain my grip on \the [active_item]!"), null, COMBAT_MESSAGE_RANGE)

/mob/living/carbon/human/do_after_coefficent()
	. = ..()
	. *= physiology.do_after_speed

/mob/living/carbon/human/updatehealth()
	. = ..()
	dna?.species.spec_updatehealth(src)
	if(HAS_TRAIT(src, TRAIT_IGNOREDAMAGESLOWDOWN))
		remove_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN)
		remove_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN_FLYING)
		return
	var/health_deficiency = max((maxHealth - health), 0)
	if(health_deficiency >= 80)
		add_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN, override = TRUE, multiplicative_slowdown = (health_deficiency / 75), blacklisted_movetypes = FLOATING|FLYING)
		add_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN_FLYING, override = TRUE, multiplicative_slowdown = (health_deficiency / 25), movetypes = FLOATING)
	else
		remove_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN)
		remove_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN_FLYING)

/mob/living/carbon/human/adjust_nutrition(change) //Honestly FUCK the oldcoders for putting nutrition on /mob someone else can move it up because holy hell I'd have to fix SO many typechecks
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/set_nutrition(change) //Seriously fuck you oldcoders.
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/adjust_hydration(change)
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/set_hydration(change)
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/species
	var/race = null

/mob/living/carbon/human/species/Initialize()
	. = ..()
	if(race)
		set_species(race)

/*======
Try slip
======*/
/mob/living/carbon/human/proc/try_slip(obj/item/I, difficulty_mod = 0)
	var/athletics = mind.get_skill_level(/datum/skill/misc/athletics)
	var/chance = rand(0, 6) + difficulty_mod
	var/failed = TRUE
	if(athletics > chance) //Should be easier to roll against if you have any skills.
		failed = FALSE
	chance = rand(10, 20) + difficulty_mod // Fallback check, should be harder.
	if(STAPER >= chance)
		failed = FALSE
	
	// we could also do a check here but I think it's fair you
	// could sneak over almost anything without punishment.
	if(m_intent == MOVE_INTENT_SNEAK)
		failed = FALSE

	if(failed)
		slip(I)
/*==
Slip
==*/
/mob/living/carbon/human/slip(obj/item/I)
	visible_message(span_warn("[name] falls overs \the [I.name]!"))
	Knockdown(20)

/// Removes all existing genital organs from a human mob.
/mob/living/carbon/human/proc/remove_genitalia()

	// I don't know why we need two lists for internal organs.
	var/obj/item/organ/PP = internal_organs_slot["penis"]
	internal_organs_slot.Remove("penis")
	if(PP)
		internal_organs.Remove(PP)

	var/obj/item/organ/TT = internal_organs_slot["testicles"]
	internal_organs_slot.Remove("testicles")
	if(TT)
		internal_organs.Remove(TT)

	var/obj/item/organ/VV = internal_organs_slot["vagina"]
	internal_organs_slot.Remove("vagina")
	if(VV)
		internal_organs.Remove(VV)
