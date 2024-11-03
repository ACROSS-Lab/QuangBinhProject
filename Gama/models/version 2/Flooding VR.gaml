model Flood_VR

import "Flooding Model.gaml"

global { 
	

	/*************************************************************
	 * Statuses of the player, once connected to the middleware (and to GAMA)
	 *************************************************************/
	 
	 // The player chooses a language and is doing the tutorial
	 string IN_TUTORIAL <- "IN_TUTORIAL";
	 
	 // The player has finished the tutorial and is "playing" the main scene (diking + flooding)
	 string IN_GAME <- "IN_GAME";


	/*************************************************************
	 * Functions that control the transitions between the states
	 *************************************************************/
 
	action enter_init {
		write "in init state";
		ask unity_player {do set_status(IN_TUTORIAL);}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + init_duration * 1000;
	} 
	
	action enter_diking {
		write "in diking state";
		ask unity_player {do set_status(IN_GAME);}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + diking_duration * 1000;
	}
	
	action enter_flooding {
		write "in flooding state";
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + flooding_duration * 1000;	
	}

	bool init_over  { 
		return tutorial_over or gama.machine_time >= current_timeout;
	} 
	
	bool diking_over { 
		return flooding_requested_from_gama or gama.machine_time >= current_timeout;
	}
	
	bool flooding_over  { 
		return flooding_over or gama.machine_time >= current_timeout;
	}	
	
	/*************************************************************
	 * Flags to control the phases in the simulations
	 *************************************************************/

	// Is a restart requested by the user ? 
	bool restart_requested_from_gama;
	
	// Is the flooding stage requested by the user ? 
	bool flooding_requested_from_gama;
	
	// Is the diking stage requested by the user ? 
	bool diking_requested_from_gama; 
	
	
	// Are all the players who entered ready or has GAMA sent the beginning of the game ? 
	bool tutorial_over ->  (diking_requested_from_gama or flooding_requested_from_gama) or (!empty(unity_player) and(unity_player none_matches each.in_tutorial))  ;
	
	// Are all the players in the not_ready state or has GAMA sent the end of the game ?
	bool flooding_over -> restart_requested_from_gama or (!empty(unity_player) and (unity_player all_match each.in_tutorial));

	// The maximum amount of time, in seconds, we wait for players to be ready 
	float init_duration <- 120.0;
	
	// The maximum amount of time, in seconds, for watching the water flow before restarting
	float flooding_duration <- 120.0;
	
	// The maximum amount of time, in seconds, for building dikes 
	float diking_duration <- 120.0;
	
	// The next timeout to occur for the different stages
	float current_timeout;

}

species unity_linker parent: abstract_unity_linker { 
	string player_species <- string(unity_player);
	int max_num_players  <- -1;
	int min_num_players  <- 10;
	list<point> init_locations <- define_init_locations();
	unity_property up_people;
	unity_property up_dyke;
	unity_property up_water;
	
	
	
	init {
		
		unity_aspect car_aspect <- prefab_aspect("Prefabs/Visual Prefabs/City/Vehicles/Car",100,0.2,1.0,-90.0, precision);
		unity_aspect dyke_aspect <- geometry_aspect(40.0, "Materials/Dike/Dike", rgb(0, 0, 0, 0.0), precision);
		unity_aspect water_aspect <- geometry_aspect(40.0, "Materials/MAT_LOW_POLY_SHADER_TEST", rgb(0, 0, 0, 0.0), precision);
 	
		up_people<- geometry_properties("car", nil, car_aspect, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #collider, false);
		up_water <- geometry_properties("water", nil, water_aspect, #no_interaction,false);
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_people;
		unity_properties << up_dyke;
		unity_properties << up_water;
		
	}

	action add_to_send_world(map map_to_send) {
		map_to_send["score"] <- int(100*evacuated/nb_of_people);
		map_to_send["tutorial_over"] <- tutorial_over;
		map_to_send["remaining_time"] <- int((current_timeout - gama.machine_time)/1000);
	}
	list<point> define_init_locations {
		return [world.location + {0,0,100}];
	} 

	list<float> convert_string_to_array_of_float(string my_string) {
    	return (my_string split_with ",") collect float(each);
	}
	
	action action_management_with_unity(string unity_start_point, string unity_end_point) {
		list<float> unity_start_point_float <- convert_string_to_array_of_float(unity_start_point);
		list<float> unity_end_point_float <- convert_string_to_array_of_float(unity_end_point);
		point converted_start_point <- {unity_start_point_float[0], unity_start_point_float[1], unity_start_point_float[2]};
		point converted_end_point <- {unity_end_point_float[0], unity_end_point_float[1], unity_end_point_float[2]};
		float price <- converted_start_point distance_to (converted_end_point) with_precision 1;
		create dyke with: (shape: line([converted_start_point, converted_end_point]));
		do after_creating_dyke;
		do send_message players: unity_player as list mes: ["ok_build_dyke_with_unity":: true];
		ask experiment {
			do update_outputs(true); 
		}
	}
	
	action after_creating_dyke {
			list<geometry> geoms <- dyke collect ((each.shape + 5.0) at_location {each.location.x, each.location.y, 10.0});
			loop i from:0 to: length(geoms) -1 {
				geoms[i].attributes['name'] <- dyke[i].name;
			}
				
			do add_geometries_to_send(geoms,up_dyke);	
			do add_geometries_to_send(river,up_water);
			
			do send_world;
			do send_current_message;
	}
	

	action repair_dyke_with_unity(string dyke_name)
	{
		ask dyke where (each.name = dyke_name)
		{
			drowned <- false;
			do build();
		}
	}
	
	action break_dyke_with_unity(string dyke_name)
	{
		ask dyke where (each.name = dyke_name)
		{
			drowned <- true;
			do break();
		}
	}
	
	action remove_dyke_with_unity(string dyke_name)
	{
		ask dyke where (each.name = dyke_name) {
			do die;
		}
	}

	
	reflex send_agents when: not empty(unity_player) {
		do add_geometries_to_send(people where (each.state = "s_fleeing"),up_people);
		
		if (not empty(dyke)) {
			list<geometry> geoms <- dyke collect ((each.shape + 5.0) at_location {each.location.x, each.location.y, 10});
			loop i from:0 to: length(geoms) -1 {
				geoms[i].attributes['name'] <- dyke[i].name;
			}
				
			do add_geometries_to_send(geoms ,up_dyke);	 
		}
		do add_geometries_to_send(river,up_water);
		
		
	}
	// Message sent by Unity to inform about the status of a specific player
	action set_status(string player_id, string status) {
		unity_player player <- player_agents[player_id];
		if (player != nil) {
			ask player {do set_status(status);}
		}
	}
	

 
}

species unity_player parent: abstract_unity_player{
	
	bool in_tutorial;
	
	init {
		do set_status(IN_TUTORIAL);
	}
	
	action set_status(string status) {
		in_tutorial <- status = IN_TUTORIAL;
	}
	

}

experiment Launch parent:"Base" autorun: true type: unity {

	string unity_linker_species <- string(unity_linker);
	float t_ref;

	action create_player(string id) {
		ask unity_linker {
			do create_player(id);
		}
	}

	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask first(unity_player where (each.name = id_input)) {
				do die;
			}
		}
	}

	output {
		 display map_VR type: 3d background: #dimgray axes: false{
		 	
			camera 'default' location: {1419.7968,8667.7995,4069.6711} target: {1419.7968,4303.6116,0.0};
		 	species river transparency: 0.7 {
				draw shape color: #lightseagreen depth: 10 at: location - {0, 0, 5};
			}
			species road {
				draw shape color: drowned ? (#cadetblue) : color depth: height border: drowned ? #white:color;
			}
		 	species buildings {
		 		draw shape color: drowned ? (#cadetblue) : color depth: height * 2 border: drowned ? #white:color;	
		 	}
		 	species dyke {
		 		draw shape + 5 color: drowned ? (#cadetblue) : color depth: height * 2 border: drowned ? #white:color;	
			}
			species people {
				draw sphere(18) color:#darkseagreen;
			}
			species evacuation_point;

			event "r" {
				write "restart requested";
				world.restart_requested_from_gama <- true ;
			}
		
			event "d" {
				write "diking requested";
				world.diking_requested_from_gama <- true ;
			}
			
			event "f" {
				write "flooding requested";
				world.flooding_requested_from_gama <- true ;
			}
		 	
		 	
			species unity_player {
				draw circle(30) at: location + {0, 0, 50} color: rgb(color, 0.5) ;
			}
			event #mouse_down{
				 float t <- gama.machine_time;
				 if (t - t_ref) > 500 {
					 ask unity_linker {
						 move_player_event <- true;
					 }
					 t_ref <- t;
				 }
			 }
		 }
	}
}
