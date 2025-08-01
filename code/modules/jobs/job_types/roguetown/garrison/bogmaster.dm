/datum/job/roguetown/bogmaster
	title = "Warden"
	flag = BOGMASTER
	department_flag = GARRISON
	faction = "Station"
	total_positions = 1
	spawn_positions = 1
	allowed_patrons = ALL_NON_INHUMEN_PATRONS
	allowed_sexes = list(MALE, FEMALE)
	allowed_races = RACES_TOLERATED_UP // REDMOON EDIT - goblins_jobs_changes - WAS: RACES_VERY_SHUNNED_UP
	allowed_ages = list(AGE_MIDDLEAGED, AGE_OLD)
	tutorial = "An experienced soldier of the Duke's retinue, you have been tasked with overseeing the newly constructed Bastion. \
				You report to the Royal Marshal and their Councillors, \
				and your job is to keep the vanguard in line and to ensure the routes to the town remain safe.\
				The Bastion must not fall."
	display_order = JDO_BOGMASTER
	whitelist_req = TRUE

	spells = list(SPELL_CONVERT_ROLE_BOG)
	outfit = /datum/outfit/job/roguetown/bogmaster

	give_bank_account = 35
	min_pq = 8
	max_pq = null
	can_leave_round = FALSE
	// cmode_music = 'sound/music/combat_bog.ogg'

/datum/job/roguetown/bogmaster/after_spawn(mob/living/L, mob/M, latejoin = TRUE)
	. = ..()
	if(ishuman(L))
		var/mob/living/carbon/human/H = L
		if(istype(H.cloak, /obj/item/clothing/cloak/shadow))
			var/obj/item/clothing/cloak/S = H.cloak
			var/index = findtext(H.real_name, " ")
			if(index)
				index = copytext(H.real_name, 1,index)
			if(!index)
				index = H.real_name
			S.name = "warden cloak ([index])"
			S.visual_name = index // REDMOON ADD - tabard_fix

/datum/outfit/job/roguetown/bogmaster/pre_equip(mob/living/carbon/human/H)
	. = ..()
	head = /obj/item/clothing/head/roguetown/helmet/sallet/visored
	pants = /obj/item/clothing/under/roguetown/chainlegs
	cloak = /obj/item/clothing/cloak/shadow
	shirt = /obj/item/clothing/suit/roguetown/armor/chainmail
	armor = /obj/item/clothing/suit/roguetown/armor/plate/half
	neck = /obj/item/clothing/neck/roguetown/bervor
	wrists = /obj/item/clothing/wrists/roguetown/bracers
	gloves = /obj/item/clothing/gloves/roguetown/chain
	shoes = /obj/item/clothing/shoes/roguetown/armor
	beltl = /obj/item/storage/keyring/bog_master
	beltr = /obj/item/rogueweapon/sword
	belt = /obj/item/storage/belt/rogue/leather
	backr = /obj/item/storage/backpack/rogue/satchel
	backl = /obj/item/rogueweapon/shield/tower
	backpack_contents = list(/obj/item/rogueweapon/huntingknife/idagger/steel/special = 1, /obj/item/signal_horn = 1)
	if(H.mind)
		H.mind.adjust_skillrank(/datum/skill/combat/axes, 4, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/swords, 4, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/maces, 4, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/wrestling, 5, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/unarmed, 4, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/polearms, 3, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/crossbows, 3, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/bows, 2, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/whipsflails, 3, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/knives, 2, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/swimming, 2, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/climbing, 2, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/athletics, 3, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/reading, 1, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/medicine, 1, TRUE)
		H.mind.adjust_skillrank(/datum/skill/misc/riding, 4, TRUE)
		H.mind.adjust_skillrank(/datum/skill/combat/firearms, 4, TRUE)
		H.change_stat("strength", 3)
		H.change_stat("constitution", 2)
		H.change_stat("perception", 2)
		H.change_stat("endurance", 2)
	H.dna.species.soundpack_m = new /datum/voicepack/male/knight()
	ADD_TRAIT(H, TRAIT_HEAVYARMOR, TRAIT_GENERIC)
	ADD_TRAIT(H, TRAIT_WANTED_POSTER_READ, TRAIT_GENERIC)

/obj/effect/proc_holder/spell/self/convertrole/bog
	name = "Recruit Vanguard"
	new_role = "Vanguard"
	overlay_state = "recruit_bog"
	recruitment_faction = "Vanguard"
	recruitment_message = "Serve the vanguard, %RECRUIT!"
	accept_message = "FOR THE VANGUARDs!"
	refuse_message = "I refuse."

/obj/effect/proc_holder/spell/self/convertrole/bog/convert(mob/living/carbon/human/recruit, mob/living/carbon/human/recruiter)
	. = ..()
	if(!.)
		return
	recruit.advjob = new_role // REDMOON ADD - исправляет, что при выдачи роли авангарда у человека в описании пишется только раса
	recruit.verbs |= /mob/proc/haltyell
