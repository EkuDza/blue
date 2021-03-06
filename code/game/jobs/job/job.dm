/datum/job

	//The name of the job
	var/title = "BASIC"
	//Job access. The use of minimal_access or access is determined by a config setting: config.jobs_have_minimal_access
	var/list/minimal_access = list()      // Useful for servers which prefer to only have access given to the places a job absolutely needs (Larger server population)
	var/list/access = list()              // Useful for servers which either have fewer players, so each person needs to fill more than one role, or servers which like to give more access, so players can't hide forever in their super secure departments (I'm looking at you, chemistry!)
	var/flag = 0 	                      // Bitflags for the job
	var/department_flag = 0
	var/faction = "None"	              // Players will be allowed to spawn in as jobs that are set to "Station"
	var/total_positions = 0               // How many players can be this job
	var/spawn_positions = 0               // How many players can spawn in as this job
	var/current_positions = 0             // How many players have this job
	var/supervisors = null                // Supervisors, who this person answers to directly
	var/selection_color = "#ffffff"       // Selection screen color
	var/list/alt_titles                   // List of alternate titles, if any
	var/req_admin_notify                  // If this is set to 1, a text is printed to the player when jobs are assigned, telling him that he should let admins know that he has to disconnect.
	var/minimal_player_age = 0            // If you have use_age_restriction_for_jobs config option enabled and the database set up, this option will add a requirement for players to be at least minimal_player_age days old. (meaning they first signed in at least that many days before.)
	var/department = null                 // Does this position have a department tag?
	var/head_position = 0                 // Is this position Command?
	var/idtype = /obj/item/weapon/card/id // The type of the ID the player will have
	var/custom_survival_gear = null       // Custom box for spawn in backpack

	//job equipment
	var/implanted = 0
	var/uniform = /obj/item/clothing/under/color/grey
	var/shoes = /obj/item/clothing/shoes/black
	var/pda = /obj/item/device/pda
	var/hat = null
	var/suit = null
	var/gloves = null
	var/mask = null
	var/belt = null
	var/ear = /obj/item/device/radio/headset
	var/hand = null
	var/glasses = null
	var/suit_store = null

	var/backpack = /obj/item/weapon/storage/backpack
	var/satchel = /obj/item/weapon/storage/backpack/satchel_norm
	var/duffle = /obj/item/weapon/storage/backpack/duffle

	var/list/backpacks = list(
		/obj/item/weapon/storage/backpack,\
		/obj/item/weapon/storage/backpack/satchel_norm,\
		/obj/item/weapon/storage/backpack/satchel
	)

	//This will be put in backpack. List ordered by priority!
	var/list/put_in_backpack = list()

/*
For copy-pasting:

	implanted =
	uniform =
	pda =
	ear =
	shoes =
	suit =
	suit_store =
	gloves =
	mask =
	belt =
	hand =
	glasses =
	hat =

	backpack =
	satchel =
	duffle =

	put_in_backpack = list(\
	)
*/

/datum/job/proc/equip(var/mob/living/carbon/human/H, var/spawn_loadout = 0)
	if(!H)	return 0

	if(!H.client || !H.client.prefs.toggles & PREFER_NEWSETUP)
		spawn_loadout = 0

	//Put items in hands
	if(hand) H.equip_to_slot_or_del(new hand (H), slot_l_hand)

	//Put items in backpack
	if( H.backbag != 1 )
		var/backpack = backpacks[H.backbag-1]
		var/obj/item/weapon/storage/backpack/BPK = new backpack(H)
		if(H.equip_to_slot_or_del(BPK, slot_back,1))
			for( var/path in put_in_backpack )
				new path(BPK)

	//Survival equipment
	H.equip_survival_gear(custom_survival_gear)

	//No-check items (suits, gloves, etc)
	if(ear)
		H.equip_to_slot_or_del(new ear (H), slot_l_ear)
		H << "<b>To speak on your department's radio channel use :h. For the use of other channels, examine your headset.</b>"
	if(shoes)		H.equip_to_slot_or_del(new shoes (H), slot_shoes)
	if(uniform)		H.equip_to_slot_or_del(new uniform (H), slot_w_uniform)
	if(suit)		H.equip_to_slot_or_del(new suit (H), slot_wear_suit)
	if(suit_store)	H.equip_to_slot_or_del(new suit_store (H), slot_s_store)
	if(mask)		H.equip_to_slot_or_del(new mask (H), slot_wear_mask)
	if(hat)			H.equip_to_slot_or_del(new hat (H), slot_head)
	if(gloves)		H.equip_to_slot_or_del(new gloves (H), slot_gloves)
	if(glasses)		H.equip_to_slot_or_del(new glasses (H), slot_glasses)

	//Belt and PDA
	if(belt)
		H.equip_to_slot_or_del(new belt (H), slot_belt)
		H.equip_to_slot_or_del(new pda (H), slot_l_store)
	else
		H.equip_to_slot_or_del(new pda (H), slot_belt)

	if(!H.back || !istype(H.back, /obj/item/weapon/storage/backpack))
		var/list/slots = list( slot_belt, slot_r_store, slot_l_store, slot_r_hand, slot_l_hand, slot_s_store )
		for( var/path in put_in_backpack )
			if( !slots.len ) break
			var/obj/item/I = new path(H)
			for( var/slot in slots )
				if( H.equip_to_slot_if_possible(I, slot, 0, 1, 0) )
					slots -= slot
					break
			if(istype(H.r_hand,/obj/item/weapon/storage))
				new path(H.r_hand)
			else if(istype(H.l_hand, /obj/item/weapon/storage))
				new path(H.l_hand)

	//Loyalty implant
	if(implanted) H.implant_loyalty(H)

	return 1

/datum/job/proc/get_access()
	if(!config || config.jobs_have_minimal_access)
		return src.minimal_access.Copy()
	else
		return src.access.Copy()

//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns 1
/datum/job/proc/player_old_enough(client/C)
	return (available_in_days(C) == 0) //Available in 0 days = available right now = player is old enough to play.

/datum/job/proc/available_in_days(client/C)
	if(C && config.use_age_restriction_for_jobs && isnum(C.player_age) && isnum(minimal_player_age))
		return max(0, minimal_player_age - C.player_age)
	return 0

/datum/job/proc/apply_fingerprints(var/mob/living/carbon/human/target)
	if(!istype(target))
		return 0
	for(var/obj/item/item in target.contents)
		apply_fingerprints_to_item(target, item)
	return 1

/datum/job/proc/apply_fingerprints_to_item(var/mob/living/carbon/human/holder, var/obj/item/item)
	item.add_fingerprint(holder,1)
	if(item.contents.len)
		for(var/obj/item/sub_item in item.contents)
			apply_fingerprints_to_item(holder, sub_item)

/datum/job/proc/is_position_available()
	return (current_positions < total_positions) || (total_positions == -1)
