/datum/sex_controller
	/// The user and the owner of the controller
	var/mob/living/carbon/human/user
	/// Target of our actions, can be ourself
	var/mob/living/carbon/human/target
	/// Whether the user desires to stop his current action
	var/desire_stop = FALSE
	/// What is the current performed action
	var/current_action = null
	/// Enum of desired speed
	var/speed = SEX_SPEED_MID
	/// Enum of desired force
	var/force = SEX_FORCE_MID
	/// Enum of manual arousal state
	var/manual_arousal = SEX_MANUAL_AROUSAL_DEFAULT
	/// Our arousal
	var/arousal = 0
	/// Our charge gauge
	var/charge = SEX_MAX_CHARGE
	/// Whether we want to screw until finished, or non stop
	var/arousal_frozen = FALSE
	var/do_until_finished = TRUE
	var/last_arousal_increase_time = 0
	var/last_ejaculation_time = 0
	var/last_moan = 0
	var/last_pain = 0
	var/msg_signature = ""
	var/last_msg_signature = 0
	var/aphrodisiac = 1

/datum/sex_controller/New(mob/living/carbon/human/owner)
	user = owner

/datum/sex_controller/Destroy()
	user = null
	target = null
	. = ..()

/proc/do_thrust_animate(atom/movable/user, atom/movable/target, pixels = 4, time = 2.7)
	var/oldx = user.pixel_x
	var/oldy = user.pixel_y
	var/target_x = oldx
	var/target_y = oldy
	var/dir = get_dir(user, target)
	if(user.loc == target.loc)
		dir = user.dir
	switch(dir)
		if(NORTH)
			target_y += pixels
		if(SOUTH)
			target_y -= pixels
		if(WEST)
			target_x -= pixels
		if(EAST)
			target_x += pixels

	animate(user, pixel_x = target_x, pixel_y = target_y, time = time)
	animate(pixel_x = oldx, pixel_y = oldy, time = time)

/datum/sex_controller/proc/do_message_signature(sigkey)
	var/properkey = "[speed][force][sigkey]"
	if(properkey == msg_signature && last_msg_signature + 4.0 SECONDS >= world.time)
		return FALSE
	msg_signature = properkey
	last_msg_signature = world.time
	return TRUE

/datum/sex_controller/proc/is_spent()
	if(charge < CHARGE_FOR_CLIMAX)
		return TRUE
	return FALSE

/datum/sex_controller/proc/finished_check()
	if(!do_until_finished)
		return FALSE
	if(!just_ejaculated())
		return FALSE
	return TRUE

/datum/sex_controller/proc/can_violate_victim(mob/living/carbon/human/victim)
	if(!victim.mind)
		return FALSE
	if(!victim.mind.key)
		return FALSE
	if(!user.client.prefs.violated[victim.mind.key])
		return FALSE
	if(user.client.prefs.violated[victim.mind.key] + VIOLATED_ALLOWED_TIME < world.time)
		return FALSE
	return TRUE

/datum/sex_controller/proc/need_to_be_violated(mob/living/carbon/human/victim)
	// Dont need to violate self
	if(user == victim)
		return FALSE
	// If user and victim both are not defiant, then no violation needs to happen
	if(!user.defiant && !victim.defiant)
		return FALSE
	// Need to violate AFK clients
	if(!victim.mind || !victim.mind.key || !victim.client) // Changed to OR statements to remove ZAPE of mobs without minds or keys
		return TRUE
	// Need to violate combat mode people - Include user to remove ZAPE
	if(victim.cmode || user.cmode)
		return TRUE
	// Need to violate unconscious people, or those surrendering to remove ZAPE
	if(victim.stat || victim.surrendering)
		return TRUE
	return FALSE

/datum/sex_controller/proc/violate_victim(mob/living/carbon/human/victim)
	if(!user.client)
		return
	if(!victim.mind)
		return
	if(!victim.mind.key)
		return
	if(user.client.prefs.violated[victim.mind.key] && user.client.prefs.violated[victim.mind.key] + VIOLATED_ALLOWED_TIME >= world.time)
		return
	var/pq_warning = pick(list("If I continue down this road, my soul will be burdened.", "I feel a terrible omen watching me...", "The forces of dark feel heavy on my soul."))
	to_chat(user, span_userdanger(pq_warning))
	var/alert = alert(user, "Do I really want to do this?", "Violate", "Yes", "No")
	if(alert != "Yes")
		return
	user.visible_message(span_boldwarning("[user] begins to violate [victim]!"))
	if(!do_after(user, 5 SECONDS, target = victim))
		return
	if(!need_to_be_violated(victim))
		return
	if(!user.client)
		return
	if(!victim.mind)
		return
	if(!victim.mind.key)
		return
	if(user.client.prefs.violated[victim.mind.key] && user.client.prefs.violated[victim.mind.key] + VIOLATED_ALLOWED_TIME >= world.time)
		return
	// ZAPED
	//to_chat(user, span_boldwarning(pick(list("I feel tainted...", "I feel less human...")))) ZAPE
	log_combat(user, victim, "Initiated noncon against")
	//adjust_playerquality(-4, user.ckey, reason = "Initiated noncon on an AFK/resisting person.") ZAPE
	user.client.prefs.violated[victim.mind.key] = world.time

/datum/sex_controller/proc/adjust_speed(amt)
	speed = clamp(speed + amt, SEX_SPEED_MIN, SEX_SPEED_MAX)

/datum/sex_controller/proc/adjust_force(amt)
	force = clamp(force + amt, SEX_FORCE_MIN, SEX_FORCE_MAX)

/datum/sex_controller/proc/adjust_arousal_manual(amt)
	manual_arousal = clamp(manual_arousal + amt, SEX_MANUAL_AROUSAL_MIN, SEX_MANUAL_AROUSAL_MAX)

/datum/sex_controller/proc/update_pink_screen()
	var/severity = 0
	switch(arousal)
		if(1 to 10)
			severity = 1
		if(10 to 20)
			severity = 2
		if(20 to 30)
			severity = 3
		if(30 to 40)
			severity = 4
		if(40 to 50)
			severity = 5
		if(50 to 60)
			severity = 6
		if(60 to 70)
			severity = 7
		if(70 to 80)
			severity = 8
		if(80 to 90)
			severity = 9
		if(90 to INFINITY)
			severity = 10
	if(severity > 0)
		user.overlay_fullscreen("horny", /atom/movable/screen/fullscreen/love, severity)
	else
		user.clear_fullscreen("horny")

/datum/sex_controller/proc/start(mob/living/carbon/human/new_target)
	if(!ishuman(new_target))
		return

	if(HAS_TRAIT(user, TRAIT_EORA_CURSE))
		to_chat(user, "<span class='warning'>The idea repulses me!</span>")
		user.cursed_freak_out()
		return FALSE

	set_target(new_target)
	show_ui()

/datum/sex_controller/proc/cum_onto()
	log_combat(user, target, "Came onto the target")
	playsound(target, 'sound/misc/mat/endout.ogg', 50, TRUE, ignore_walls = FALSE)
	add_cum_floor(get_turf(target))
	after_ejaculation()

/datum/sex_controller/proc/cum_into(oral = FALSE, mob/living/target_mob = null) // REDMOON EDIT - baotha_steals_triumphs - добавлен target_mob для правильного просчёта, кого корраптят
	if(target_mob) // REDMOON ADD - baotha_steals_triumphs - для правильного просчёта, кого корраптят
		target = target_mob // REDMOON ADD
	log_combat(user, target, "Came inside the target")
	if(oral)
		playsound(target, pick(list('sound/misc/mat/mouthend (1).ogg','sound/misc/mat/mouthend (2).ogg')), 100, FALSE, ignore_walls = FALSE)
	else
		playsound(target, 'sound/misc/mat/endin.ogg', 50, TRUE, ignore_walls = FALSE)
	if(user.patron.type == /datum/patron/inhumen/baotha) // REDMOON ADD START - baotha_steals_triumphs
		baotha_process(user, target) // Баотит даёт
	else
		baotha_process(target, user) // REDMOON ADD END - баотит принимает
	target.reagents.add_reagent(/datum/reagent/erpjuice/cum, 3)
	after_ejaculation()
	after_intimate_climax()

/datum/sex_controller/proc/ejaculate()
	log_combat(user, user, "Ejaculated")
	user.visible_message(span_lovebold("[user] makes a mess!"))
	playsound(user, 'sound/misc/mat/endout.ogg', 50, TRUE, ignore_walls = FALSE)
	add_cum_floor(get_turf(user))
	after_ejaculation()

/datum/sex_controller/proc/ejaculate_container(obj/item/reagent_containers/glass/C)
	log_combat(user, user, "Ejaculated into a container")
	user.visible_message(span_lovebold("[user] spills into [C]!"))
	playsound(user, 'sound/misc/mat/endout.ogg', 50, TRUE, ignore_walls = FALSE)
	C.reagents.add_reagent(/datum/reagent/erpjuice/cum, 3)
	after_ejaculation()

/datum/sex_controller/proc/after_ejaculation()
	user.add_stress(/datum/stressevent/cumok)
	set_arousal(40)
	if(user.patron) // REDMOON ADD START - Эора и Баота позволяют своему юзверю быть очень выносливым
		if(user.patron.type != /datum/patron/inhumen/baotha || user.patron.type != /datum/patron/divine/eora)
			if(prob(10))
				to_chat(user, span_love((user.client.prefs.be_russian ? "Мой бог... даёт мне сил продолжать! Славься!" : "My god... Grants me power to continue! Praise!")))
	if(user.has_flaw(/datum/charflaw/addiction/lovefiend))
		user.sate_addiction()
	adjust_charge(-CHARGE_FOR_CLIMAX)
	user.emote("sexmoanhvy", forced = TRUE)
	user.playsound_local(user, 'sound/misc/mat/end.ogg', 100)
	last_ejaculation_time = world.time
	// if(HAS_TRAIT(user, TRAIT_BAOTHA_CURSE))
	user.apply_status_effect(/datum/status_effect/debuff/cumbrained)
	SSticker.cums++
//	cuckold_check() // REDMOON REMOVAL - повышаем популярность семьи, убираем сообщения о куколдах в конце раунда

	if(target && target)
		SEND_SIGNAL(user, COMSIG_HUMAN_LEWD_FINISH, target, src)
		SEND_SIGNAL(target, COMSIG_HUMAN_LEWD_FINISHED_ON, user, src)

/datum/sex_controller/proc/after_milking()
	set_arousal(80)
	user.emote("sexmoanhvy", forced = TRUE)
	user.playsound_local(user, 'sound/misc/mat/end.ogg', 100)
	last_ejaculation_time = world.time

/datum/sex_controller/proc/after_intimate_climax()
	if(user == target)
		if(HAS_TRAIT(target, TRAIT_GOODLOVER))
			user.add_stress(/datum/stressevent/cumgood)
		return
	if(HAS_TRAIT(target, TRAIT_GOODLOVER))
		if(!user.mob_timers["cumtri"])
			user.mob_timers["cumtri"] = world.time
			user.adjust_triumphs(3) // REDMOON EDIT - выставлено 3 триумфа, по желанию Смайли
			to_chat(user, span_love("Our loving is a true TRIUMPH!"))
			user.add_stress(/datum/stressevent/cumgood)
			user.apply_status_effect(/datum/status_effect/buff/goodloving)
	if(HAS_TRAIT(user, TRAIT_GOODLOVER))
		if(!target.mob_timers["cumtri"])
			target.mob_timers["cumtri"] = world.time
			target.adjust_triumphs(3) // REDMOON EDIT - выставлено 3 триумфа, по желанию Смайли
			to_chat(target, span_love("Our loving is a true TRIUMPH!"))
			target.add_stress(/datum/stressevent/cumgood)
			target.apply_status_effect(/datum/status_effect/buff/goodloving)

/datum/sex_controller/proc/just_ejaculated()
	return (last_ejaculation_time + 2 SECONDS >= world.time)

/datum/sex_controller/proc/set_charge(amount)
	var/empty = (charge < CHARGE_FOR_CLIMAX)
	charge = clamp(amount, 0, SEX_MAX_CHARGE)
	var/after_empty = (charge < CHARGE_FOR_CLIMAX)
	if(empty && !after_empty)
		to_chat(user, span_notice("I feel like I'm not so spent anymore"))
	if(!empty && after_empty)
		to_chat(user, span_notice("I'm spent!"))

/datum/sex_controller/proc/adjust_charge(amount)
	set_charge(charge + amount)

/datum/sex_controller/proc/handle_charge(dt)
	if(user.has_flaw(/datum/charflaw/addiction/lovefiend))
		dt *= 2
	adjust_charge(dt * CHARGE_RECHARGE_RATE)
	if(is_spent())
		if(arousal > 60)
			to_chat(user, span_warning("I'm too spent!"))
			adjust_arousal(-20)
		adjust_arousal(-dt * SPENT_AROUSAL_RATE)

/datum/sex_controller/proc/set_arousal(amount)
	if(amount > arousal)
		last_arousal_increase_time = world.time
	arousal = clamp(amount, 0, MAX_AROUSAL)
	update_pink_screen()
	update_blueballs()
	update_erect_state()

/datum/sex_controller/proc/update_erect_state()
	var/obj/item/organ/penis/penis = user.getorganslot(ORGAN_SLOT_PENIS)
	if(user.mind)
		var/datum/antagonist/werewolf/W = user.mind.has_antag_datum(/datum/antagonist/werewolf/)
		if(W && W.transformed == TRUE)
			user.regenerate_icons()
	if(penis)
		penis.update_erect_state()

/datum/sex_controller/proc/adjust_arousal(amount)
	set_arousal(arousal + amount)

/datum/sex_controller/proc/perform_deepthroat_oxyloss(mob/living/carbon/human/action_target, oxyloss_amt)
	var/oxyloss_multiplier = 0
	switch(force)
		if(SEX_FORCE_LOW)
			oxyloss_multiplier = 0
		if(SEX_FORCE_MID)
			oxyloss_multiplier = 0
		if(SEX_FORCE_HIGH)
			oxyloss_multiplier = 1.0
		if(SEX_FORCE_EXTREME)
			oxyloss_multiplier = 2.0
	oxyloss_amt *= oxyloss_multiplier
	if(oxyloss_amt <= 0)
		return
	action_target.adjustOxyLoss(oxyloss_amt)
	// Indicate someone is choking through sex
	if(action_target.oxyloss >= 50 && prob(33))
		action_target.emote(pick(list("gag", "choke", "gasp")), forced = TRUE)

/datum/sex_controller/proc/perform_sex_action(mob/living/carbon/human/action_target, arousal_amt, pain_amt, giving)
	if(HAS_TRAIT(user, TRAIT_GOODLOVER))
		arousal_amt *=1.5
		if(prob(10))
			var/lovermessage = pick("This feels so good!","I am in heaven!","This is too good to be possible!","By the ten!","I can't stop, too good!")
			to_chat(action_target, span_love(lovermessage))
	if(HAS_TRAIT(user, TRAIT_DEATHBYSNUSNU))
		if(istype(user.rmb_intent, /datum/rmb_intent/strong))
			pain_amt *= 2
	action_target.sexcon.receive_sex_action(arousal_amt, pain_amt, giving, force, speed)

/datum/sex_controller/proc/receive_sex_action(arousal_amt, pain_amt, giving, applied_force, applied_speed)
	arousal_amt *= get_force_pleasure_multiplier(applied_force, giving)
	pain_amt *= get_force_pain_multiplier(applied_force)
	pain_amt *= get_speed_pain_multiplier(applied_speed)

	if(user.stat == DEAD)
		arousal_amt = 0
		pain_amt = 0

	if(!arousal_frozen)
		adjust_arousal(arousal_amt)

	damage_from_pain(pain_amt)
	try_do_moan(arousal_amt, pain_amt, applied_force, giving)
	try_do_pain_effect(pain_amt, giving)

/datum/sex_controller/proc/damage_from_pain(pain_amt)
	if(pain_amt < PAIN_MINIMUM_FOR_DAMAGE)
		return
	var/damage = (pain_amt / PAIN_DAMAGE_DIVISOR)
	var/obj/item/bodypart/part = user.get_bodypart(BODY_ZONE_CHEST)
	if(!part)
		return
	user.apply_damage(damage, BRUTE, part)

/datum/sex_controller/proc/try_do_moan(arousal_amt, pain_amt, applied_force, giving)
	if(arousal_amt < 1.5)
		return
	if(user.stat != CONSCIOUS)
		return
	if(last_moan + MOAN_COOLDOWN >= world.time)
		return
	if(prob(50))
		return
	var/chosen_emote
	switch(arousal_amt)
		if(0 to 5)
			chosen_emote = "sexmoanlight"
		if(5 to INFINITY)
			chosen_emote = "sexmoanhvy"

	if(pain_amt >= PAIN_MILD_EFFECT)
		if(giving)
			if(prob(30))
				chosen_emote = "groan"
		else
			if(prob(40))
				chosen_emote = "painmoan"
	if(pain_amt >= PAIN_MED_EFFECT)
		if(giving)
			if(prob(50))
				chosen_emote = "groan"
		else
			if(prob(60))
				// Because males have atrocious whimper noise
				if(user.gender == FEMALE && prob(50))
					chosen_emote = "whimper"
				else
					chosen_emote = "groan"

	last_moan = world.time
	user.emote(chosen_emote, forced = TRUE)

/datum/sex_controller/proc/try_do_pain_effect(pain_amt, giving)
	if(pain_amt < PAIN_MILD_EFFECT)
		return
	if(last_pain + PAIN_COOLDOWN >= world.time)
		return
	if(prob(50))
		return
	last_pain = world.time
	if(pain_amt >= PAIN_HIGH_EFFECT)
		var/pain_msg = pick(list("IT HURTS!!!", "IT NEEDS TO STOP!!!", "I CAN'T TAKE IT ANYMORE!!!"))
		to_chat(user, span_boldwarning(pain_msg))
		user.flash_fullscreen("redflash2")
		if(prob(70) && user.stat == CONSCIOUS)
			user.visible_message(span_warning("[user] shudders in pain!"))
	else if(pain_amt >= PAIN_MED_EFFECT)
		var/pain_msg = pick(list("It hurts!", "It pains me!"))
		to_chat(user, span_boldwarning(pain_msg))
		user.flash_fullscreen("redflash1")
		if(prob(40) && user.stat == CONSCIOUS)
			user.visible_message(span_warning("[user] shudders in pain!"))
	else
		var/pain_msg = pick(list("It hurts a little...", "It stings...", "I'm aching..."))
		to_chat(user, span_warning(pain_msg))

/datum/sex_controller/proc/update_blueballs()
	if(arousal >= BLUEBALLS_GAIN_THRESHOLD)
		user.add_stress(/datum/stressevent/blueb)
	else if (arousal <= BLUEBALLS_LOOSE_THRESHOLD)
		user.remove_stress(/datum/stressevent/blueb)

/datum/sex_controller/proc/check_active_ejaculation()
	if(arousal < ACTIVE_EJAC_THRESHOLD)
		return FALSE
	if(is_spent())
		return FALSE
	if(!can_ejaculate())
		return FALSE
	return TRUE

/datum/sex_controller/proc/can_ejaculate()
	if(!user.getorganslot(ORGAN_SLOT_TESTICLES) && !user.getorganslot(ORGAN_SLOT_VAGINA))
		return FALSE
	if(HAS_TRAIT(user, TRAIT_LIMPDICK))
		return FALSE
	return TRUE

/datum/sex_controller/proc/handle_passive_ejaculation()
	if(arousal < PASSIVE_EJAC_THRESHOLD)
		return
	if(is_spent())
		return
	if(!can_ejaculate())
		return FALSE
	ejaculate()

/datum/sex_controller/proc/handle_container_ejaculation()
	if(arousal < PASSIVE_EJAC_THRESHOLD)
		return
	if(is_spent())
		return
	if(!can_ejaculate())
		return FALSE
	ejaculate_container(user.get_active_held_item())

/datum/sex_controller/proc/handle_cock_milking(mob/living/carbon/human/milker)
	if(arousal < ACTIVE_EJAC_THRESHOLD)
		return
	if(is_spent())
		return
	if(!can_ejaculate())
		return FALSE
	ejaculate_container(milker.get_active_held_item())

/datum/sex_controller/proc/can_use_penis()
	if(HAS_TRAIT(user, TRAIT_LIMPDICK))
		return TRUE //The fact that you can just go and manually stick a vampire's dick in you and bounce on it until you get off, but they cannot *personally* stick their dick in and need their partner to put it in, is stupid. Especially because they *can* titfuck or thighfuck you as is. This lets them ream you but still prevents cumming. Forever edging is the real curse :3
	return TRUE

/datum/sex_controller/proc/considered_limp()
	if(arousal >= AROUSAL_HARD_ON_THRESHOLD)
		return FALSE
	return TRUE

/datum/sex_controller/proc/process_sexcon(dt)
	handle_arousal_unhorny(dt)
	handle_charge(dt)
	handle_passive_ejaculation()

/datum/sex_controller/proc/handle_arousal_unhorny(dt)
	if(!can_ejaculate())
		adjust_arousal(-dt * IMPOTENT_AROUSAL_LOSS_RATE)
	if(last_arousal_increase_time + AROUSAL_TIME_TO_UNHORNY >= world.time)
		return
	var/rate
	switch(arousal)
		if(-INFINITY to 25)
			rate = AROUSAL_LOW_UNHORNY_RATE
		if(25 to 40)
			rate = AROUSAL_MID_UNHORNY_RATE
		if(40 to INFINITY)
			rate = AROUSAL_HIGH_UNHORNY_RATE
	adjust_arousal(-dt * rate)

/datum/sex_controller/proc/show_ui()
	var/list/dat = list()
	var/force_name = get_force_string()
	var/speed_name = get_speed_string()
	var/manual_arousal_name = get_manual_arousal_string()
	if(!user.getorganslot(ORGAN_SLOT_PENIS))
		dat += "<center><a href='?src=[REF(src)];task=speed_down'>\<</a> [speed_name] <a href='?src=[REF(src)];task=speed_up'>\></a> ~|~ <a href='?src=[REF(src)];task=force_down'>\<</a> [force_name] <a href='?src=[REF(src)];task=force_up'>\></a></center>"
	else
		dat += "<center><a href='?src=[REF(src)];task=speed_down'>\<</a> [speed_name] <a href='?src=[REF(src)];task=speed_up'>\></a> ~|~ <a href='?src=[REF(src)];task=force_down'>\<</a> [force_name] <a href='?src=[REF(src)];task=force_up'>\></a> ~|~ <a href='?src=[REF(src)];task=manual_arousal_down'>\<</a> [manual_arousal_name] <a href='?src=[REF(src)];task=manual_arousal_up'>\></a></center>"
	if(usr?.client?.prefs?.be_russian)
		dat += "<center>| <a href='?src=[REF(src)];task=toggle_finished'>[do_until_finished ? "ДО ТЕХ ПОР, ПОКА Я НЕ ОСТАНОВЛЮСЬ" : "ДО ТЕХ ПОР, ПОКА Я НЕ ОСТАНОВЛЮСЬ"]</a> |</center>"
	else
		dat += "<center>| <a href='?src=[REF(src)];task=toggle_finished'>[do_until_finished ? "UNTIL IM FINISHED" : "UNTIL I STOP"]</a> |</center>"
	if(usr?.client?.prefs?.be_russian)
		dat += "<center><a href='?src=[REF(src)];task=set_arousal'>SET AROUSAL</a> | <a href='?src=[REF(src)];task=freeze_arousal'>[arousal_frozen ? "НЕ СДЕРЖИВАТЬСЯ" : "СДЕРЖИВАТЬСЯ"]</a></center>"
	else
		dat += "<center><a href='?src=[REF(src)];task=set_arousal'>SET AROUSAL</a> | <a href='?src=[REF(src)];task=freeze_arousal'>[arousal_frozen ? "UNFREEZE AROUSAL" : "FREEZE AROUSAL"]</a></center>"
	if(target == user)
		dat += "<center>Doing unto yourself</center>"
	else
		dat += "<center>| <a href='?src=[REF(src)];task=toggle_finished'>[do_until_finished ? "UNTIL I STOP" : "UNTIL I STOP"]</a> |</center>"
	if(target == user)
		if(usr?.client?.prefs?.be_russian)
			dat += "<center>Делаю себе хорошо</center>"
		else
			dat += "<center>Doing unto yourself</center>"
	else
		if(usr?.client?.prefs?.be_russian)
			dat += "<center>Делаю [target] хорошо</center>"
		else
			dat += "<center>Doing unto [target]'s</center>"
	if(current_action)
		if(usr?.client?.prefs?.be_russian)
			dat += "<center><a href='?src=[REF(src)];task=stop'>Остановить</a></center>"
		else
			dat += "<center><a href='?src=[REF(src)];task=stop'>Stop</a></center>"
	else
		dat += "<br>"
	dat += "<table width='100%'><td width='50%'></td><td width='50%'></td><tr>"
	var/i = 0
	for(var/action_type in GLOB.sex_actions)
		var/datum/sex_action/action = SEX_ACTION(action_type)
		if(!action.shows_on_menu(user, target))
			continue
		dat += "<td>"
		var/link = ""
		if(!can_perform_action(action_type))
			link = "linkOff"
		if(current_action == action_type)
			link = "linkOn"
		if(usr?.client?.prefs?.be_russian)
			dat += "<center><a class='[link]' href='?src=[REF(src)];task=action;action_type=[action_type]'>[action.ru_name]</a></center>"
		else
			dat += "<center><a class='[link]' href='?src=[REF(src)];task=action;action_type=[action_type]'>[action.name]</a></center>"
		dat += "</td>"
		i++
		if(i >= 2)
			i = 0
			dat += "</tr><tr>"

	dat += "</tr></table>"
	var/datum/browser/popup
	if(usr?.client?.prefs?.be_russian)
		popup = new(user, "sexcon", "<center>Утолить Желание</center>", 500, 550)
	else
		popup = new(user, "sexcon", "<center>Sate Desire</center>", 500, 550)
	popup.set_content(dat.Join())
	popup.open()
	return

/datum/sex_controller/Topic(href, href_list)
	if(usr != user)
		return
	switch(href_list["task"])
		if("action")
			var/action_path = text2path(href_list["action_type"])
			var/datum/sex_action/action = SEX_ACTION(action_path)
			if(!action)
				return
			try_start_action(action_path)
		if("stop")
			try_stop_current_action()
		if("speed_up")
			adjust_speed(1)
		if("speed_down")
			adjust_speed(-1)
		if("force_up")
			adjust_force(1)
		if("force_down")
			adjust_force(-1)
		if("manual_arousal_up")
			adjust_arousal_manual(1)
		if("manual_arousal_down")
			adjust_arousal_manual(-1)
		if("toggle_finished")
			do_until_finished = !do_until_finished
		if("set_arousal")
			var/amount = input(user, "Value above 120 will immediately cause orgasm!", "Set Arousal", arousal) as num
			set_arousal(amount)
		if("freeze_arousal")
			arousal_frozen = !arousal_frozen
	show_ui()

/datum/sex_controller/proc/try_stop_current_action()
	if(!current_action)
		return
	desire_stop = TRUE
	user.doing = FALSE

/datum/sex_controller/proc/stop_current_action()
	if(!current_action)
		return
	var/datum/sex_action/action = SEX_ACTION(current_action)
	action.on_finish(user, target)
	desire_stop = FALSE
	user.doing = FALSE
	current_action = null
	actions_made = 0 // REDMOON ADD - baotha_steals_triumphs

/datum/sex_controller/proc/try_start_action(action_type)
	if(action_type == current_action)
		try_stop_current_action()
		return
	if(current_action != null)
		try_stop_current_action()
		return
	if(!action_type)
		return
	if(!can_perform_action(action_type))
		return
//	if(need_to_be_violated(target) && !can_violate_victim(target))
//		violate_victim(target) - Commented out to disable the pop up and just disable all defiant ZAPE
	if(need_to_be_violated(target) && !can_violate_victim(target))
		return
	// Set vars
	desire_stop = FALSE
	current_action = action_type
	var/datum/sex_action/action = SEX_ACTION(current_action)
	log_combat(user, target, "Started sex action: [action.name]")
	INVOKE_ASYNC(src, PROC_REF(sex_action_loop))

/datum/sex_controller/proc/sex_action_loop()
	// Do action loop
	var/performed_action_type = current_action
	var/datum/sex_action/action = SEX_ACTION(current_action)
	action.on_start(user, target)
	while(TRUE)
		if(!user.stamina_add(action.stamina_cost * get_stamina_cost_multiplier()))
			break
		if(!do_after(user, (action.do_time / get_speed_multiplier()), target = target))
			break
		if(current_action == null || performed_action_type != current_action)
			break
		if(need_to_be_violated(target) && !can_violate_victim(target))
			break
		if(!can_perform_action(current_action))
			break
		if(action.is_finished(user, target))
			break
		if(desire_stop)
			break
		action.on_perform(user, target)
		actions_made++ // REDMOON ADD - baotha_steals_triumphs
		if(target.sexcon) // REDMOON ADD - baotha_steals_triumphs
			target.sexcon.actions_made++ // REDMOON ADD - baotha_steals_triumphs
		// It could want to finish afterwards the performed action
		if(action.is_finished(user, target))
			break
		if(!action.continous)
			break
	stop_current_action()

/datum/sex_controller/proc/can_perform_action(action_type)
	if(!action_type)
		return FALSE
	var/datum/sex_action/action = SEX_ACTION(action_type)
	if(!inherent_perform_check(action_type))
		return FALSE
	if(!action.can_perform(user, target))
		return FALSE
	return TRUE

/datum/sex_controller/proc/inherent_perform_check(action_type)
	var/datum/sex_action/action = SEX_ACTION(action_type)
	if(!target)
		return FALSE
	if(user.stat != CONSCIOUS)
		return FALSE
	if(!user.Adjacent(target))
		return FALSE
	if(action.check_incapacitated && user.incapacitated())
		return FALSE
	if(action.check_same_tile)
		var/same_tile = (get_turf(user) == get_turf(target))
		var/grab_bypass = (action.aggro_grab_instead_same_tile && user.get_highest_grab_state_on(target) == GRAB_AGGRESSIVE)
		if(!same_tile && !grab_bypass)
			return FALSE
	if(action.require_grab)
		var/grabstate = user.get_highest_grab_state_on(target)
		if(grabstate == null || grabstate < action.required_grab_state)
			return FALSE
	return TRUE

/datum/sex_controller/proc/set_target(mob/living/carbon/human/new_target)
	target = new_target

/datum/sex_controller/proc/get_speed_multiplier()
	switch(speed)
		if(SEX_SPEED_LOW)
			return 1.0
		if(SEX_SPEED_MID)
			return 1.5
		if(SEX_SPEED_HIGH)
			return 2.0
		if(SEX_SPEED_EXTREME)
			return 2.5

/datum/sex_controller/proc/get_stamina_cost_multiplier()
	switch(force)
		if(SEX_FORCE_LOW)
			return 1.0
		if(SEX_FORCE_MID)
			return 1.5
		if(SEX_FORCE_HIGH)
			return 2.0
		if(SEX_SPEED_EXTREME)
			return 2.5

/datum/sex_controller/proc/get_force_pleasure_multiplier(passed_force, giving)
	switch(passed_force)
		if(SEX_FORCE_LOW)
			if(giving)
				return 0.8
			else
				return 0.8
		if(SEX_FORCE_MID)
			if(giving)
				return 1.2
			else
				return 1.2
		if(SEX_FORCE_HIGH)
			if(giving)
				return 1.6
			else
				return 1.2
		if(SEX_FORCE_EXTREME)
			if(giving)
				return 2.0
			else
				return 0.8

/datum/sex_controller/proc/get_force_pain_multiplier(passed_force)
	switch(passed_force)
		if(SEX_FORCE_LOW)
			return 0.5
		if(SEX_FORCE_MID)
			return 1.0
		if(SEX_FORCE_HIGH)
			return 2.0
		if(SEX_FORCE_EXTREME)
			return 3.0

/datum/sex_controller/proc/get_speed_pain_multiplier(passed_speed)
	switch(passed_speed)
		if(SEX_SPEED_LOW)
			return 0.8
		if(SEX_SPEED_MID)
			return 1.0
		if(SEX_SPEED_HIGH)
			return 1.2
		if(SEX_SPEED_EXTREME)
			return 1.4

/datum/sex_controller/proc/get_force_string()
	switch(force)
		if(SEX_FORCE_LOW)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#eac8de'>ОСТОРОЖНО</font>"
			else
				return "<font color='#eac8de'>GENTLE</font>"
		if(SEX_FORCE_MID)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#e9a8d1'>АКТИВНО</font>"
			else
				return "<font color='#e9a8d1'>FIRM</font>"
		if(SEX_FORCE_HIGH)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#f05ee1'>ГРУБО</font>"
			else
				return "<font color='#f05ee1'>ROUGH</font>"
		if(SEX_FORCE_EXTREME)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#d146f5'>БРУТАЛЬНО</font>"
			else
				return "<font color='#d146f5'>BRUTAL</font>"

/datum/sex_controller/proc/get_speed_string()
	switch(speed)
		if(SEX_SPEED_LOW)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#eac8de'>МЕДЛЕННО</font>"
			else
				return "<font color='#eac8de'>SLOW</font>"
		if(SEX_SPEED_MID)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#e9a8d1'>НОРМАЛЬНО</font>"
			else
				return "<font color='#e9a8d1'>STEADY</font>"
		if(SEX_SPEED_HIGH)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#f05ee1'>БЫСТРО</font>"
			else
				return "<font color='#f05ee1'>QUICK</font>"
		if(SEX_SPEED_EXTREME)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#d146f5'>СТРЕМИТЕЛЬНО</font>"
			else
				return "<font color='#d146f5'>UNRELENTING</font>"

/datum/sex_controller/proc/get_manual_arousal_string()
	switch(manual_arousal)
		if(SEX_MANUAL_AROUSAL_DEFAULT)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#eac8de'>ЕСТЕСТВЕННО</font>"
			else
				return "<font color='#eac8de'>NATURAL</font>"
		if(SEX_MANUAL_AROUSAL_UNAROUSED)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#e9a8d1'>НЕВОЗБУЖДЕННЫЙ</font>"
			else
				return "<font color='#e9a8d1'>UNAROUSED</font>"
		if(SEX_MANUAL_AROUSAL_PARTIAL)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#f05ee1'>ЧАСТИЧНОЕ ВОЗБУЖДЕНИЕ</font>"
			else
				return "<font color='#f05ee1'>PARTIALLY ERECT</font>"
		if(SEX_MANUAL_AROUSAL_FULL)
			if(usr?.client?.prefs?.be_russian)
				return "<font color='#d146f5'>ПОЛНОЕ ВОЗБУЖДЕНИЕ</font>"
			else
				return "<font color='#d146f5'>FULLY ERECT</font>"

/datum/sex_controller/proc/get_generic_force_adjective()
	switch(force)
		if(SEX_FORCE_LOW)
			if(usr?.client?.prefs?.be_russian)
				return pick(list("аккуратно", "деликатно", "осторожно", "бережно", "ласково", "тактично"))
			else
				return pick(list("gently", "carefully", "tenderly", "gingerly", "delicately", "lazily"))
		if(SEX_FORCE_MID)
			if(usr?.client?.prefs?.be_russian)
				return pick(list("активно", "с нетерпением", "неуклонно", "интенсивно", "энергично"))
			else
				return pick(list("firmly", "vigorously", "eagerly", "steadily", "intently"))
		if(SEX_FORCE_HIGH)
			if(usr?.client?.prefs?.be_russian)
				return pick(list("грубо", "небрежно", "с силой", "пылко", "свирепо"))
			else
				return pick(list("roughly", "carelessly", "forcefully", "fervently", "fiercely"))
		if(SEX_FORCE_EXTREME)
			if(usr?.client?.prefs?.be_russian)
				return pick(list("брутально", "безжалостно", "зверски", "жестоко", "дико", "беспощадно", "нещадно"))
			else
				return pick(list("brutally", "savagely", "cruelly", "wildly", "savagely", "unmercifully"))

/datum/sex_controller/proc/spanify_force(string)
	switch(force)
		if(SEX_FORCE_LOW)
			return "<span class='love_low'>[string]</span>"
		if(SEX_FORCE_MID)
			return "<span class='love_mid'>[string]</span>"
		if(SEX_FORCE_HIGH)
			return "<span class='love_high'>[string]</span>"
		if(SEX_FORCE_EXTREME)
			return "<span class='love_extreme'>[string]</span>"

/datum/sex_controller/proc/cuckold_check()
	//First, check if the target has a family.
	var/datum/family/F = target.getFamily(TRUE)
	if(!F)
		return


	//Second, check if target has a spouse relation.
	var/list/rels = F.getRelations(target,REL_TYPE_SPOUSE)

	if(!length(rels))
		return

	for(var/datum/relation/R in rels) //Loop through all the spouses (Should only be one.)
		var/mob/living/carbon/human/cuckold = R.target:resolve()
		if(!cuckold || cuckold == user)
			continue
		GLOB.cuckolds |= "[cuckold.job] [cuckold.real_name] (by [user.real_name])"

/datum/sex_controller/proc/try_pelvis_crush(mob/living/carbon/human/target)
	if(istype(user.rmb_intent, /datum/rmb_intent/strong))
		if(!target.has_wound(/datum/wound/fracture/groin))
			if(prob(10))
				var/obj/item/bodypart/groin = target.get_bodypart(check_zone(BODY_ZONE_PRECISE_GROIN))
				groin.add_wound(/datum/wound/fracture)
