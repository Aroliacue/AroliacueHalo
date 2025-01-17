
/mob/living/simple_animal/hostile/flood/combat_form
	var/next_infestor_spawn = 0
	var/our_infestor
	var/melee_infect = 0

	var/obj/item/weapon/gun/our_gun

	var/corpse_pulped = 0 //1 = cannot be revived, -1 = can be revived infinitely.
	var/list/spawn_with_gun = null //If this is set, we'll spawn with a gun (or try to)
	var/gun_spawn_chance = 100
	var/list/inventory //list of objects to select from for drop on death

/mob/living/simple_animal/hostile/flood/combat_form/Initialize()
	. = ..()
	if(!isnull(spawn_with_gun) && (gun_spawn_chance == 100 || prob(gun_spawn_chance)))
		var/gun_type_spawn = pick(spawn_with_gun)
		pickup_gun(new gun_type_spawn (loc))

/mob/living/simple_animal/hostile/flood/combat_form/examine(var/examiner)
	. = ..()
	if(corpse_pulped == 1)
		to_chat(examiner,"<span class = 'notice'>[src] has been heavily damaged. Once dead, it's dead for good.</span>")
	if(corpse_pulped == -1)
		to_chat(examiner,"<span class = 'notice'>[src]'s flesh looks tougher than normal. It could likely endure the revivification process many times.</span>")

/mob/living/simple_animal/hostile/flood/combat_form/proc/spawn_infestor()
	if(world.time < next_infestor_spawn)
		if(client)
			to_chat(src,"<span class = 'notice'>Your biomass hasn't recovered from the previous formation.</span>")
		return
	next_infestor_spawn = world.time + COMBAT_FORM_INFESTOR_SPAWN_DELAY
	our_infestor = new /mob/living/simple_animal/hostile/flood/infestor (src.loc)
	visible_message("<span class = 'warning'>[src]'s flesh writhes for a moment, blood-red feelers emerging, followed by a singular infection form.</span>")

/mob/living/simple_animal/hostile/flood/combat_form/verb/create_infestor_form()
	set name = "Create Infestor Form"
	set category = "Abilities"

	if(stat == DEAD)
		to_chat(usr,"<span class = 'notice'>You can't do that, you're dead!</span>")
		return

	spawn_infestor()

/mob/living/simple_animal/hostile/flood/combat_form/verb/smash_airlocks_nearby()
	set name = "Destroy Weld"
	set category = "Abilities"

	if(stat == DEAD)
		to_chat(usr,"<span class = 'notice'>You can't do that, you're dead!</span>")
		return
	smash_airlock()

/mob/living/simple_animal/hostile/flood/combat_form/proc/smash_airlock()
	for(var/obj/machinery/door/airlock/door in view(1,src))
		if(door.welded == 1)
			visible_message("<span class = 'danger'>[name] swipes at [door], swiftly slicing the crude welding apart!</span>")
			door.welded = 0
			door.update_icon()
			playsound(src.loc, 'sound/effects/grillehit.ogg', 80)

/mob/living/simple_animal/hostile/flood/combat_form/IsAdvancedToolUser()
	if(our_gun) //Only class us as an advanced tool user if we need it to use our gun.
		return 1
	return 0

/mob/living/simple_animal/hostile/flood/combat_form/can_wield_item(var/obj/item)
	if(istype(item,/obj/item/weapon/gun))
		return TRUE
	return FALSE

/mob/living/simple_animal/hostile/flood/combat_form/UnarmedAttack(var/atom/attacked)
	. = ..(attacked)
	if(!. && istype(attacked,/mob/living))
		return 0
	var/mob/living/carbon/human/h = attacked
	if(istype(h) && melee_infect)
		h.bloodstr.add_reagent(/datum/reagent/floodinfectiontoxin,melee_damage_lower/4)
	pickup_gun(attacked)

/mob/living/simple_animal/hostile/flood/combat_form/RangedAttack(var/atom/attacked, mob/user)
	if(!our_gun)
		return
	
	our_gun.afterattack(attacked,src)
	
	if(!ckey && our_gun.ammo_check(user) == 0) //If the gun has no ammo left we drop it
		drop_gun()

/mob/living/simple_animal/hostile/flood/combat_form/proc/pickup_gun(var/obj/item/weapon/gun/G)
	if(!istype(G))
		return
	if(our_gun)
		drop_gun()
		
	var/ammo = G.ammo_check() 
	if(ammo == 0 && !ckey)  //If a gun has no ammo we ignore it, players can still pick up though if they want
		return
	visible_message("<span class = 'notice'>[name] picks up [G.name]</span>")
	our_gun = G
	contents += our_gun
	ranged = 1

/mob/living/simple_animal/hostile/flood/combat_form/proc/drop_gun()
	if(our_gun)
		visible_message("<span class = 'notice'>[name] drops [our_gun.name]</span>")
		our_gun.forceMove(loc)
		contents -= our_gun
		ranged = 0
		our_gun = 0 //So an NPC can pick up a new gun

/mob/living/simple_animal/hostile/flood/combat_form/proc/human_in_sight()
	for(var/mob/living/carbon/human/h in view(7,src))
		return 1

/mob/living/simple_animal/hostile/flood/combat_form/proc/dump_inventory()
	if(inventory)
		var/i = pick(src.inventory)
		new i(loc)

/mob/living/simple_animal/hostile/flood/combat_form/death()
	drop_gun()
	dump_inventory()
	. = ..()

/mob/living/simple_animal/hostile/flood/combat_form/Move()
	. = ..()
	if(stat == DEAD)
		return
	if(health <= 0)
		death()
		return
	if(ckey || client)
		return
	/*if(human_in_sight() && isnull(our_infestor))
		spawn_infestor()*/
	var/list/viewlist = view(1,src)
	if(locate(/obj/machinery/door/airlock) in viewlist)
		smash_airlock()
	if(!our_gun || our_gun == 0)
		for(var/obj/item/weapon/gun/G in viewlist)
			pickup_gun(G)
			return

/mob/living/simple_animal/hostile/flood/combat_form/MoveToTarget()
	stop_automated_movement = 1
	if(!target_mob || SA_attackable(target_mob))
		stance = HOSTILE_STANCE_IDLE
	var/list/targlist = ListTargets(7)
	if(target_mob in targlist)
		if(ranged || istype(loc,/obj/vehicles))
			if(target_mob in targlist)
				walk(src, 0)
				OpenFire(target_mob)
		hostilemob_walk_to(target_mob,1,move_to_delay) //Flood should chase down people even if ranged and use their arm to attack
		spawn(get_dist(src,target_mob)*move_to_delay) //If the target is within range after our original move, we attack them.
			AttackTarget()
		
	else
		target_mob = null
		stance = HOSTILE_STANCE_IDLE
