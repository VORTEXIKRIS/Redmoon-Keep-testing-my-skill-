///////////// OVERLAY EFFECTS /////////////
/obj/effect/overlay/water
	icon = 'icons/turf/newwater.dmi'
	icon_state = "bottom"
	density = 0
	mouse_opacity = 0
	layer = BELOW_MOB_LAYER
	anchored = TRUE

/obj/effect/overlay/water/top
	icon_state = "top"
	layer = BELOW_MOB_LAYER


/turf/open/water
	gender = PLURAL
	name = "water"
	desc = "Good enough to drink, wet enough to douse fires."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "together"
	baseturfs = /turf/open/water
	slowdown = 5
	turf_flags = NONE
	var/obj/effect/overlay/water/water_overlay
	var/obj/effect/overlay/water/top/water_top_overlay
	bullet_sizzle = TRUE
	bullet_bounce_sound = null //needs a splashing sound one day.
	smooth = SMOOTH_MORE
	canSmoothWith = list(/turf/closed/mineral,/turf/closed/wall/mineral/rogue, /turf/open/floor/rogue)
	footstep = null
	barefootstep = null
	clawfootstep = null
	heavyfootstep = null
	landsound = 'sound/foley/jumpland/waterland.wav'
	neighborlay_override = "edge"
	var/water_color = "#6a9295"
	var/water_reagent = /datum/reagent/water
	var/water_reagent_purified = /datum/reagent/water // If put through a water filtration device, provides this reagent instead
	water_level = 2
	var/wash_in = TRUE
	var/swim_skill = FALSE
	nomouseover = FALSE
	var/swimdir = FALSE

/turf/open/water/Initialize()
	.  = ..()
	water_overlay = new(src)
	water_top_overlay = new(src)
	update_icon()

/turf/open/water/update_icon()
	if(water_overlay)
		water_overlay.color = water_color
		water_overlay.icon_state = "bottom[water_level]"
	if(water_top_overlay)
		water_top_overlay.color = water_color
		water_top_overlay.icon_state = "top[water_level]"

/turf/open/water/Exited(atom/movable/AM, atom/newloc)
	. = ..()
	var/mob/living/user = AM
	if(isliving(user) && !user.is_floor_hazard_immune())
		for(var/obj/structure/S in src)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return
		if(water_overlay)
			if((get_dir(src, newloc) == SOUTH))
				water_overlay.layer = BELOW_MOB_LAYER
				water_overlay.plane = GAME_PLANE
			else
				spawn(6)
					if(!locate(/mob/living) in src)
						water_overlay.layer = BELOW_MOB_LAYER
						water_overlay.plane = GAME_PLANE
		var/drained = get_stamina_drain(user, get_dir(src, newloc))
		if(drained && !user.stamina_add(drained))
			user.Immobilize(30)
			addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living, Knockdown), 30), 1 SECONDS)

/turf/open/water/proc/get_stamina_drain(mob/living/swimmer, travel_dir)
	var/const/BASE_STAM_DRAIN = 15
	var/const/MIN_STAM_DRAIN = 1
	var/const/STAM_PER_LEVEL = 5
	var/const/NPC_SWIM_LEVEL = SKILL_LEVEL_APPRENTICE
	var/const/UNSKILLED_ARMOR_PENALTY = 40
	if(!isliving(swimmer))
		return 0
	if(!swim_skill)
		return 0 // no stam cost
	if(swimmer.is_floor_hazard_immune())
		return 0 // floating!
	if(swimdir && travel_dir && travel_dir == dir)
		return 0 // going with the flow
	if(swimmer.buckled)
		return 0
	var/swimming_skill_level = swimmer.mind ? swimmer.mind.get_skill_level(/datum/skill/misc/swimming) : NPC_SWIM_LEVEL
	. = max(BASE_STAM_DRAIN - (swimming_skill_level * STAM_PER_LEVEL), MIN_STAM_DRAIN)
//	. += (swimmer.checkwornweight()*2)
	if(!swimmer.check_armor_skill())
		. += UNSKILLED_ARMOR_PENALTY
	if(.) // this check is expensive so we only run it if we do expect to use stamina	
		for(var/obj/structure/S in src)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return 0
		for(var/D in GLOB.cardinals) //adjacent to a floor to hold onto
			if(istype(get_step(src, D), /turf/open/floor))
				return 0

// Mobs won't try to path through water if low on stamina,
// and will take advantage of water flow to move faster.
/turf/open/water/get_heuristic_slowdown(mob/traverser, travel_dir)
	/// Mobs will heavily avoid pathing through this turf if their stamina is too low.
	var/const/LOW_STAM_PENALTY = 7 // only go through this if we'd have to go offscreen otherwise
	. = ..()
	if(isliving(traverser) && !HAS_TRAIT(traverser, TRAIT_NOSTAMINA))
		var/mob/living/living_traverser = traverser
		var/remaining_stamina = (living_traverser.max_stamina - living_traverser.stamina)
		if(remaining_stamina < get_stamina_drain(living_traverser, travel_dir)) // not enough stamina reserved to cross
			. += LOW_STAM_PENALTY // really want to avoid this unless we don't have any better options

/turf/open/water/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum, d_type = "blunt")
	..()
	playsound(src, pick('sound/foley/water_land1.ogg','sound/foley/water_land2.ogg','sound/foley/water_land3.ogg'), 100, FALSE)


/turf/open/water/cardinal_smooth(adjacencies)
	roguesmooth(adjacencies)

/turf/open/water/roguesmooth(adjacencies)
	var/list/Yeah = ..()
	if(water_overlay)
		water_overlay.cut_overlays(TRUE)
		if(Yeah)
			water_overlay.add_overlay(Yeah)
	if(water_top_overlay)
		water_top_overlay.cut_overlays(TRUE)
		if(Yeah)
			water_top_overlay.add_overlay(Yeah)

/turf/open/water/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	var/mob/living/L = AM
	if(isliving(L) && !L.is_floor_hazard_immune())
		if(!(L.mobility_flags & MOBILITY_STAND) || water_level == 3)
			L.SoakMob(FULL_BODY)
		else
			if(water_level == 2)
				L.SoakMob(BELOW_CHEST)
		if(water_overlay)
			if(water_level > 1 && !istype(oldLoc, type))
				playsound(AM, 'sound/foley/waterenter.ogg', 100, FALSE)
			else
				playsound(AM, pick('sound/foley/watermove (1).ogg','sound/foley/watermove (2).ogg'), 100, FALSE)
			if(istype(oldLoc, type) && (get_dir(src, oldLoc) != SOUTH))
				water_overlay.layer = ABOVE_MOB_LAYER
				water_overlay.plane = GAME_PLANE_UPPER
			else
				spawn(6)
					if(AM.loc == src)
						water_overlay.layer = ABOVE_MOB_LAYER
						water_overlay.plane = GAME_PLANE_UPPER

/turf/open/water/attackby(obj/item/C, mob/user, params)
	if(user.used_intent.type == /datum/intent/fill)
		if(C.reagents)
			if(C.reagents.holder_full())
				to_chat(user, span_warning("[C] is full."))
				return
			playsound(user, 'sound/foley/drawwater.ogg', 100, FALSE)
			if(do_after(user, 8, target = src))
				user.changeNext_move(CLICK_CD_MELEE)
				C.reagents.add_reagent(water_reagent, 200)
				to_chat(user, span_notice("I fill [C] from [src]."))
				// If the user is filling a water purifier and the water isn't already clean...
				if (istype(C, /obj/item/reagent_containers/glass/bottle/waterskin/purifier) && water_reagent != water_reagent_purified)
					var/obj/item/reagent_containers/glass/bottle/waterskin/purifier/P = C
					P.cleanwater(user)
			return
	. = ..()

/turf/open/water/attack_right(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.stat != CONSCIOUS)
			return
		var/list/wash = list('sound/foley/waterwash (1).ogg','sound/foley/waterwash (2).ogg')
		playsound(user, pick_n_take(wash), 100, FALSE)
		var/item2wash = user.get_active_held_item()
		if(!item2wash)
			user.visible_message(span_info("[user] starts to wash in [src]."))
			if(do_after(L, 3 SECONDS, target = src))
				if(wash_in)
					wash_atom(user, CLEAN_STRONG)
				playsound(user, pick(wash), 100, FALSE)
/*				if(water_reagent == /datum/reagent/water) //become shittified, checks so bath water can be naturally gross but not discolored
					water_reagent = /datum/reagent/water/gross
					water_color = "#a4955b"
					update_icon()*/
		else
			user.visible_message(span_info("[user] starts to wash [item2wash] in [src]."))
			if(do_after(L, 30, target = src))
				if(wash_in)
					wash_atom(item2wash, CLEAN_STRONG)
				playsound(user, pick(wash), 100, FALSE)
		return
	..()

/turf/open/water/onbite(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.stat != CONSCIOUS)
			return
		if(iscarbon(user))
			var/mob/living/carbon/C = user
			if(C.is_mouth_covered())
				return
		playsound(user, pick('sound/foley/waterwash (1).ogg','sound/foley/waterwash (2).ogg'), 100, FALSE)
		user.visible_message(span_info("[user] starts to drink from [src]."))
		if(do_after(L, 25, target = src))
			var/list/waterl = list()
			waterl[water_reagent] = 5
			var/datum/reagents/reagents = new()
			reagents.add_reagent_list(waterl)
			reagents.trans_to(L, reagents.total_volume, transfered_by = user, method = INGEST)
			playsound(user,pick('sound/items/drink_gen (1).ogg','sound/items/drink_gen (2).ogg','sound/items/drink_gen (3).ogg'), 100, TRUE)
			onbite(user)
		return
	..()

/turf/open/water/Destroy()
	. = ..()
	if(water_overlay)
		QDEL_NULL(water_overlay)
	if(water_top_overlay)
		QDEL_NULL(water_top_overlay)

/turf/open/water/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum, d_type = "blunt")
	if(isobj(AM))
		var/obj/O = AM
		O.extinguish()

/turf/open/water/get_slowdown(mob/user)
	if(user.is_floor_hazard_immune())
		return 0

	var/returned = slowdown
	if(user?.mind && swim_skill)
		returned = returned - (user.mind.get_skill_level(/datum/skill/misc/swimming))
	return returned

//turf/open/water/Initialize()
//	dir = pick(NORTH,SOUTH,WEST,EAST)
//	. = ..()


/turf/open/water/bath
	name = "water"
	desc = "Faintly yellow colored.. Suspicious."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "bathtileW"
	water_level = 2
	water_color = "#FFFFFF"
	slowdown = 3
	water_reagent = /datum/reagent/water/gross

/turf/open/water/bath/Initialize()
	.  = ..()
	icon_state = "bathtile"

/turf/open/water/sewer
	name = "sewage"
	desc = "This dark water smells like dead rats and sulphur!"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "pavingW"
	water_level = 1
	water_color = "#705a43"
	slowdown = 1
	wash_in = FALSE
	water_reagent = /datum/reagent/water/gross

/turf/open/water/sewer/Initialize()
	icon_state = "paving"
	water_color = pick("#705a43","#697043")
	.  = ..()

/turf/open/water/swamp
	name = "murk"
	desc = "Weeds and algae cover the surface of the water."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "dirtW2"
	water_level = 2
	water_color = "#705a43"
	slowdown = 3
	wash_in = TRUE
	water_reagent = /datum/reagent/water/gross
	var/leech_chance = 3

/turf/open/water/swamp/Initialize()
	icon_state = "dirt"
	dir = pick(GLOB.cardinals)
	water_color = pick("#705a43")
	.  = ..()

/turf/open/water/swamp/proc/get_leech_zones()
	var/static/leech_zones = list(BODY_ZONE_R_LEG,BODY_ZONE_L_LEG)
	return leech_zones

/turf/open/water/swamp/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	var/mob/living/carbon/C = AM
	if(!iscarbon(C) || C.is_floor_hazard_immune() || !prob(leech_chance))
		return
	if(C.blood_volume <= 0)
		return
	var/zonee = get_leech_zones()
	for(var/X in zonee)
		var/obj/item/bodypart/BP = C.get_bodypart(X)
		if(!BP)
			continue
		if(BP.skeletonized)
			continue
		var/obj/item/natural/worms/leech/I = new(C)
		BP.add_embedded_object(I, silent = TRUE)
		return .

/turf/open/water/sea
	name = "shallows"
	desc = "Shallow salty seawater, gentle waves lap across the surface"
	water_level = 2
	water_color = "#034ea4"
	water_reagent = /datum/reagent/water/salty

/turf/open/water/sea/deep
	name = "sea"
	desc = "Deep salty seawater, who knows what dwells beneath the surface?"
	water_level = 3
	water_color = "#02014b"
	slowdown = 5
	swim_skill = TRUE

/turf/open/water/swamp/deep
	name = "murk"
	desc = "Deep water with several weeds and algae on the surface."
	icon_state = "dirtW"
	water_level = 3
	water_color = "#705a43"
	slowdown = 5
	swim_skill = TRUE
	leech_chance = 8

/turf/open/water/swamp/deep/get_leech_zones()
	var/static/deep_leech_zones = list(BODY_ZONE_CHEST,BODY_ZONE_R_LEG,BODY_ZONE_L_LEG,BODY_ZONE_R_ARM,BODY_ZONE_L_ARM)
	return deep_leech_zones

/turf/open/water/cleanshallow
	name = "water"
	desc = "Clear and shallow water, what a blessing!"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "rockw2"
	water_level = 2
	slowdown = 3
	wash_in = TRUE
	water_reagent = /datum/reagent/water

/turf/open/water/cleanshallow/Initialize()
	icon_state = "rock"
	dir = pick(GLOB.cardinals)
	.  = ..()


/turf/open/water/river
	name = "river"
	desc = "Crystal clear water! Flowing swiftly along the river."
	icon_state = "rivermove"
	icon = 'icons/turf/roguefloor.dmi'
	water_level = 3
	slowdown = 5
	wash_in = TRUE
	swim_skill = TRUE
	var/river_processing
	swimdir = TRUE

/turf/open/water/river/update_icon()
	if(water_overlay)
		water_overlay.color = water_color
		water_overlay.icon_state = "riverbot"
		water_overlay.dir = dir
	if(water_top_overlay)
		water_top_overlay.color = water_color
		water_top_overlay.icon_state = "rivertop"
		water_top_overlay.dir = dir

/turf/open/water/river/Initialize()
	icon_state = "rock"
	.  = ..()

/turf/open/water/river/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	if(!river_processing)
		for(var/obj/structure/S in src)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return
		river_processing = addtimer(CALLBACK(src, PROC_REF(process_river)), 0.5 SECONDS, TIMER_STOPPABLE)

/turf/open/water/river/get_heuristic_slowdown(mob/traverser, travel_dir)
	var/const/UPSTREAM_PENALTY = 2
	var/const/DOWNSTREAM_BONUS = -2
	. = ..()
	if(traverser.is_floor_hazard_immune())
		return
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	if(travel_dir == dir) // downriver
		. += DOWNSTREAM_BONUS // faster!
	else if(travel_dir == GLOB.reverse_dir[dir]) // upriver
		. += UPSTREAM_PENALTY // slower

/turf/open/water/river/proc/process_river()
	river_processing = null
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	for(var/atom/movable/A in contents)
		if((A.loc == src) && A.has_gravity())
			if(ismob(A))
				var/mob/the_mob = A
				if(the_mob.is_floor_hazard_immune())
					continue // floating seelie, jumping, etc
			A.ConveyorMove(dir)

/turf/open/water/sea/thermalwater //heals u and has better chance to catch rare fish IT SUPPOSED TO BE BOG ONLY BECAUSE GIVES +25% CHANCE TO CATCH RARE FISH
	name = "healing hot spring"
	desc = "A warm spring with gentle ripples. Standing here soothes your body."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "together"
	water_color = "#23b9df"
	water_level = 2
	wash_in = TRUE
	water_reagent = /datum/reagent/water
	var/heal_interval = 5 SECONDS
	var/heal_amount = 20
	var/last_heal = 0

/turf/open/water/sea/thermalwater/Initialize()  // I REPEAT ITS BOG ONLY YOU RRRRRRRRRRRRRRRRRRRRRRRRRRRRR
	. = ..()
	START_PROCESSING(SSobj, src)

/turf/open/water/sea/thermalwater/process()
	if(world.time < last_heal + heal_interval)
		return

	for(var/mob/living/carbon/M in src)
		if(M.stat == DEAD) continue

		if(M.getBruteLoss())
			M.adjustBruteLoss(-heal_amount)
		if(M.getFireLoss())
			M.adjustFireLoss(-heal_amount)
		if(M.getToxLoss())
			M.adjustToxLoss(-heal_amount)
		if(M.getOxyLoss())
			M.adjustOxyLoss(-heal_amount*2)

		M.visible_message(span_notice("[M] looks a bit better after soaking in the spring."))

	last_heal = world.time
