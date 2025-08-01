
/obj/item/ammo_holder
	desc = ""
	icon = 'icons/roguetown/weapons/ammo.dmi'
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = NONE
	max_integrity = 0
	equip_sound = 'sound/blank.ogg'
	bloody_icon_state = "bodyblood"
	alternate_worn_layer = UNDER_CLOAK_LAYER
	strip_delay = 20
	var/max_storage
	var/list/ammo = list()
	sewrepair = TRUE
	var/list/ammo_type

/obj/item/ammo_holder/quiver
	name = "quiver"
	icon_state = "quiver0"
	item_state = "quiver"
	lefthand_file = 'icons/mob/inhands/equipment/backpack_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/backpack_righthand.dmi'
	slot_flags = ITEM_SLOT_HIP|ITEM_SLOT_BACK
	max_storage = 20
	ammo_type = list (/obj/item/ammo_casing/caseless/rogue/arrow, /obj/item/ammo_casing/caseless/rogue/bolt)
	grid_width = 64
	grid_height = 64

/obj/item/ammo_holder/bullet
	name = "bullet pouch"
	icon_state = "pouch0"
	item_state = "pouch"
	slot_flags = ITEM_SLOT_HIP|ITEM_SLOT_NECK
	max_storage = 10
	ammo_type = list(/obj/item/ammo_casing) //common denominator type for runelock and arquebus bullets
	grid_width = 32
	grid_height = 64

/obj/item/ammo_holder/quiver/attack_turf(turf/T, mob/living/user)
	if(ammo.len >= max_storage)
		to_chat(user, span_warning("Your [src.name] is full!"))
		return
	to_chat(user, span_notice("You begin to gather the ammunition..."))
	for(var/obj/item/ammo_casing/caseless/rogue/arrow in T.contents)
		if(do_after(user, 5))
			if(!eatarrow(arrow))
				break

/obj/item/ammo_holder/quiver/proc/eatarrow(obj/A)
	if(A.type in subtypesof(/obj/item/ammo_casing/caseless/rogue))
		if(ammo.len < max_storage)
			A.forceMove(src)
			ammo += A
			update_icon()
			return TRUE
		else
			return FALSE

/obj/item/ammo_holder/attackby(obj/A, loc, params)
	for(var/i in ammo_type)
		if(istype(A, i))
			if(ammo.len < max_storage)
				A.forceMove(src)
				ammo += A
				update_icon()
			else
				to_chat(loc, span_warning("Full!"))
			return
	if(istype(A, /obj/item/gun/ballistic/revolver/grenadelauncher/bow))
		var/obj/item/gun/ballistic/revolver/grenadelauncher/bow/B = A
		if(ammo.len && !B.chambered)
			for(var/AR in ammo)
				if(istype(AR, /obj/item/ammo_casing/caseless/rogue/arrow))
					ammo -= AR
					B.attackby(AR, loc, params)
					break
		return
	..()

/obj/item/ammo_holder/attack_right(mob/user)
	if(ammo.len)
		var/obj/O = ammo[ammo.len]
		ammo -= O
		O.forceMove(user.loc)
		user.put_in_hands(O)
		update_icon()
		return TRUE

/obj/item/ammo_holder/examine(mob/user)
	. = ..()
	if(ammo.len)
		. += span_notice("[ammo.len] inside.")

/obj/item/ammo_holder/update_icon()
	if(ammo.len)
		icon_state = "[item_state]1"
	else
		icon_state = "[item_state]0"

/obj/item/ammo_holder/quiver/arrows/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/rogue/arrow/iron/A = new()
		ammo += A
	update_icon()

/obj/item/ammo_holder/quiver/bolts/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/rogue/bolt/A = new()
		ammo += A
	update_icon()

/obj/item/ammo_holder/bullet/runed/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/runelock/R = new()
		ammo += R
	update_icon()

/obj/item/ammo_holder/bullet/lead/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/lead/B = new()
		ammo += B
	update_icon()

/obj/item/ammo_holder/bullet/grapeshot/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/grapeshot/B = new()
		ammo += B
	update_icon()

/*
/obj/item/ammo_holder/Parrows/Initialize()
	..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/rogue/arrow/poison/A = new()
		arrows += A
	update_icon()

/obj/item/ammo_holder/Pbolts/Initialize()
	..()
	for(var/i in 1 to max_storage)
		var/obj/item/ammo_casing/caseless/rogue/bolt/poison/A = new()
		arrows += A
	update_icon()
*/

/obj/item/ammo_holder/bomb
	name = "bomb pouch"
	icon_state = "pouch0"
	item_state = "pouch"
	slot_flags = ITEM_SLOT_HIP|ITEM_SLOT_NECK
	max_storage = 6
	ammo_type = list(/obj/item/smokebomb)
	color = "#b5b5b5"

/obj/item/ammo_holder/bomb/smokebombs/Initialize()
	. = ..()
	for(var/i in 1 to max_storage)
		var/obj/item/smokebomb/A = new()
		ammo += A
	update_icon()

/obj/item/ammo_holder/quiver/sling
	name = "sling bullet pouch"
	desc = "This pouch holds the ouch." //i came up with this line on an impulse
	icon = 'icons/roguetown/weapons/ammo.dmi'
	icon_state = "slingpouch"
	item_state = "slingpouch"
	slot_flags = ITEM_SLOT_HIP | ITEM_SLOT_NECK
	max_storage = 20
	w_class = WEIGHT_CLASS_NORMAL
	grid_height = 64
	grid_width = 32

/obj/item/ammo_holder/quiver/sling/attack_turf(turf/T, mob/living/user)
	if(ammo.len >= max_storage)
		to_chat(user, span_warning("My [src.name] is full!"))
		return
	to_chat(user, span_notice("I begin to gather the ammunition..."))
	for(var/obj/item/ammo_casing/caseless/rogue/sling_bullet in T.contents)
		if(do_after(user, 5))
			if(!eatarrow(sling_bullet))
				break

/obj/item/ammo_holder/quiver/sling/attackby(obj/A, loc, params)
	if(A.type in subtypesof(/obj/item/ammo_casing/caseless/rogue/sling_bullet))
		if(ammo.len < max_storage)
			if(ismob(loc))
				var/mob/M = loc
				M.doUnEquip(A, TRUE, src, TRUE, silent = TRUE)
			else
				A.forceMove(src)
			ammo += A
			update_icon()
		else
			to_chat(loc, span_warning("Full!"))
		return
	if(istype(A, /obj/item/gun/ballistic/revolver/grenadelauncher/sling))
		var/obj/item/gun/ballistic/revolver/grenadelauncher/sling/B = A
		if(ammo.len && !B.chambered)
			for(var/AR in ammo)
				if(istype(AR, /obj/item/ammo_casing/caseless/rogue/sling_bullet))
					ammo -= AR
					B.attackby(AR, loc, params)
					break
		return
	..()

/obj/item/ammo_holder/quiver/sling/attack_right(mob/user)
	if(ammo.len)
		var/obj/O = ammo[ammo.len]
		ammo -= O
		O.forceMove(user.loc)
		user.put_in_hands(O)
		update_icon()
		return TRUE

/obj/item/ammo_holder/quiver/sling/update_icon()
	return
