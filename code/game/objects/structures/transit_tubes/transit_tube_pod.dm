/obj/structure/transit_tube_pod
	icon = 'icons/obj/atmospherics/pipes/transit_tube.dmi'
	icon_state = "pod"
	animate_movement = FORWARD_STEPS
	anchored = TRUE
	density = TRUE
	var/moving = FALSE
	var/datum/gas_mixture/air_contents = new()
	var/occupied_icon_state = "pod_occupied"


/obj/structure/transit_tube_pod/Initialize()
	. = ..()
	air_contents.set_moles(GAS_O2, MOLES_O2STANDARD)
	air_contents.set_moles(GAS_N2, MOLES_N2STANDARD)
	air_contents.set_temperature(T20C)


/obj/structure/transit_tube_pod/Destroy()
	empty_pod()
	return ..()

/obj/structure/transit_tube_pod/update_icon_state()
	icon_state = contents.len ? occupied_icon_state : initial(icon_state)
	return ..()

/obj/structure/transit_tube_pod/attackby(obj/item/I, mob/user, params)
	if(I.tool_behaviour == TOOL_CROWBAR)
		if(!moving)
			I.play_tool_sound(src)
			if(contents.len)
				user.visible_message(span_notice("[user] empties \the [src]."), span_notice("You empty \the [src]."))
				empty_pod()
			else
				deconstruct(TRUE, user)
	else
		return ..()

/obj/structure/transit_tube_pod/deconstruct(disassembled = TRUE, mob/user)
	if(!(flags_1 & NODECONSTRUCT_1))
		var/atom/location = get_turf(src)
		if(user)
			location = user.loc
			add_fingerprint(user)
			user.visible_message(span_notice("[user] removes [src]."), span_notice("You remove [src]."))
		var/obj/structure/c_transit_tube_pod/R = new/obj/structure/c_transit_tube_pod(location)
		transfer_fingerprints_to(R)
		R.setDir(dir)
		empty_pod(location)
	qdel(src)

/obj/structure/transit_tube_pod/ex_act(severity, target)
	..()
	if(!QDELETED(src))
		empty_pod()

/obj/structure/transit_tube_pod/contents_explosion(severity, target)
	for(var/atom/movable/AM in contents)
		switch(severity)
			if(EXPLODE_DEVASTATE)
				SSexplosions.highobj += AM
			if(EXPLODE_HEAVY)
				SSexplosions.medobj += AM
			if(EXPLODE_LIGHT)
				SSexplosions.lowobj += AM

/obj/structure/transit_tube_pod/singularity_pull(S, current_size)
	..()
	if(current_size >= STAGE_FIVE)
		deconstruct(FALSE)

/obj/structure/transit_tube_pod/container_resist_act(mob/living/user)
	if(!user.incapacitated())
		empty_pod()
		return
	if(!moving)
		user.changeNext_move(CLICK_CD_BREAKOUT)
		user.last_special = world.time + CLICK_CD_BREAKOUT
		to_chat(user, span_notice("You start trying to escape from the pod..."))
		if(do_after(user, 1 MINUTES, target = src))
			to_chat(user, span_notice("You manage to open the pod."))
			empty_pod()

/obj/structure/transit_tube_pod/proc/empty_pod(atom/location)
	if(!location)
		location = get_turf(src)
	for(var/atom/movable/M in contents)
		M.forceMove(location)
	update_appearance()

/obj/structure/transit_tube_pod/Process_Spacemove()
	if(moving) //No drifting while moving in the tubes
		return TRUE
	else
		return ..()

/obj/structure/transit_tube_pod/proc/follow_tube()
	set waitfor = 0
	if(moving)
		return

	moving = TRUE

	var/obj/structure/transit_tube/current_tube = null
	var/next_dir
	var/next_loc
	var/last_delay = 0
	var/exit_delay

	for(var/obj/structure/transit_tube/tube in loc)
		if(tube.has_exit(dir))
			current_tube = tube
			break

	while(current_tube)
		next_dir = current_tube.get_exit(dir)

		if(!next_dir)
			break

		exit_delay = current_tube.exit_delay(src, dir)
		last_delay += exit_delay

		sleep(exit_delay)

		next_loc = get_step(loc, next_dir)

		current_tube = null
		for(var/obj/structure/transit_tube/tube in next_loc)
			if(tube.has_entrance(next_dir))
				current_tube = tube
				break

		if(current_tube == null)
			setDir(next_dir)
			Move(get_step(loc, dir), dir, DELAY_TO_GLIDE_SIZE(exit_delay)) // Allow collisions when leaving the tubes.
			break

		last_delay = current_tube.enter_delay(src, next_dir)
		sleep(last_delay)
		setDir(next_dir)
		set_glide_size(DELAY_TO_GLIDE_SIZE(last_delay + exit_delay))
		forceMove(next_loc) // When moving from one tube to another, skip collision and such.
		density = current_tube.density

		if(current_tube && current_tube.should_stop_pod(src, next_dir))
			current_tube.pod_stopped(src, dir)
			break

	density = TRUE
	moving = FALSE

	var/obj/structure/transit_tube/TT = locate(/obj/structure/transit_tube) in loc
	if(!TT || (!(dir in TT.tube_dirs) && !(turn(dir,180) in TT.tube_dirs)))	//landed on a turf without transit tube or not in our direction
		outside_tube()

/obj/structure/transit_tube_pod/proc/outside_tube()
	var/list/savedcontents = contents.Copy()
	var/saveddir = dir
	var/turf/destination = get_edge_target_turf(src,saveddir)
	visible_message(span_warning("[src] ejects its insides out!"))
	deconstruct(FALSE)//we automatically deconstruct the pod
	for(var/i in savedcontents)
		var/atom/movable/AM = i
		AM.throw_at(destination,rand(1,3),5)

/obj/structure/transit_tube_pod/return_air()
	return air_contents

/obj/structure/transit_tube_pod/return_analyzable_air()
	return air_contents

/obj/structure/transit_tube_pod/assume_air(datum/gas_mixture/giver)
	return air_contents.merge(giver)

/obj/structure/transit_tube_pod/assume_air_moles(datum/gas_mixture/giver, moles)
	return giver.transfer_to(air_contents, moles)

/obj/structure/transit_tube_pod/assume_air_ratio(datum/gas_mixture/giver, ratio)
	return giver.transfer_ratio_to(air_contents, ratio)

/obj/structure/transit_tube_pod/remove_air(amount)
	return air_contents.remove(amount)

/obj/structure/transit_tube_pod/remove_air_ratio(ratio)
	return air_contents.remove_ratio(ratio)

/obj/structure/transit_tube_pod/transfer_air(datum/gas_mixture/taker, moles)
	return air_contents.transfer_to(taker, moles)

/obj/structure/transit_tube_pod/transfer_air_ratio(datum/gas_mixture/taker, ratio)
	return air_contents.transfer_ratio_to(taker, ratio)

/obj/structure/transit_tube_pod/relaymove(mob/mob, direction)
	if(istype(mob) && mob.client)
		if(!moving)
			for(var/obj/structure/transit_tube/station/station in loc)
				if(!station.pod_moving)
					if(direction == turn(station.boarding_dir,180))
						if(station.open_status == STATION_TUBE_OPEN)
							mob.forceMove(loc)
							update_appearance()
						else
							station.open_animation()

					else if(direction in station.tube_dirs)
						setDir(direction)
						station.launch_pod()
				return

			for(var/obj/structure/transit_tube/TT in loc)
				if(dir in TT.tube_dirs)
					if(TT.has_exit(direction))
						setDir(direction)
						return

/obj/structure/transit_tube_pod/return_temperature()
	return air_contents.return_temperature()

//special pod made by the dispenser, it fizzles away when reaching a station.

/obj/structure/transit_tube_pod/dispensed
	name = "temporary transit tube pod"
	desc = "Hits the skrrrt (tube station), then hits the dirt (nonexistence). You know how it is."
	icon_state = "temppod"
	occupied_icon_state = "temppod_occupied"

/obj/structure/transit_tube_pod/dispensed/outside_tube()
	qdel(src)
