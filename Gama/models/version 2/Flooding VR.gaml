model Flood_VR

import "Flooding Model.gaml"

global { 
	
	
	/*************************************************************
	 * Redefinition of initial parameters for people, water and obstacles
	 *************************************************************/

	// Initial number of people
	int nb_of_people <- 500;
	
	// The average speed of people
	float speed_of_people <- 20 #m / #h;
	
	// The maximum water input
	float max_water_input <- 0.5;

	
	// The height of water in the river at the beginning
	float initial_water_height <- 2.0;
	
	//Diffusion rate
	float diffusion_rate <- 0.5;
	
	//Height of the dykes (30 m by default)
	float dyke_height <- 15.0;
	
	//Width of the dyke (15 m by default)
	float dyke_width <- 15.0;


	/*************************************************************
	 * "Winning" condition: determines whether the player 
	 * has "won" or "lost" depending on the number of lives he/she
	 * saved with the dykes
	 *************************************************************/
	 
	int max_number_of_casualties <- round(nb_of_people / 5);

	bool winning -> casualties < max_number_of_casualties;
	
	
	/*************************************************************
	 * Attributes dedicated to the UI in GAMA (images, colors, etc.)
	 *************************************************************/
	
	rgb text_color <- rgb(232, 215, 164);
	
	
	point text_position <- {-1500, 500};
	point timer_position <- {-1100, 1000};
	point icon_position <- {-1350, 1000};
	
	geometry button_frame;  
	image button_image_unselected;
	image button_image_selected;
	bool button_selected;
	
	reflex change_building_colors {
		ask buildings {
			int nb <- cells_under count (each.water_height > 0);
			switch (nb) {
				match 0 {color <- #gray;}
				match_one [1,2] {color <- rgb(214, 168, 0);}
				match_one [3,4] {color <- rgb(237, 155, 0);}
				default {color <- rgb(176, 32, 19);}
			}
		}
	}
	

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
		ask unity_player {do set_status(IN_TUTORIAL);}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + init_duration * 1000;
		button_frame <- nil;
		button_image_unselected <- nil;
		button_image_selected <- nil;
	} 
	
	action enter_diking {
		ask unity_linker {do send_static_geometries();}
		ask unity_player {do set_status(IN_GAME);}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + diking_duration * 1000;
		button_image_unselected <- image("../../includes/icons/flood-line.png") * rgb(232, 215, 164);
		button_image_selected <- image("../../includes/icons/flood-fill.png") * rgb(232, 215, 164);
	}
	
	action enter_flooding {
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		current_timeout <- gama.machine_time + flooding_duration * 1000;	
		button_image_unselected <- image("../../includes/icons/restart-line.png");
		button_image_selected <- image("../../includes/icons/restart-fill.png");
	}
	
	// Are all the players who entered ready or has GAMA sent the beginning of the game ? 
	bool init_over  { 
		if (flooding_requested_from_gama or diking_requested_from_gama) {return true;}
		if (empty(unity_player)) {return false;}
		return unity_player none_matches each.in_tutorial;
	} 
	
	bool diking_over { 
		if (flooding_requested_from_gama) {return true;}
		if (gama.machine_time >= current_timeout) {return true;}
		return false;
	}
	
	// Are all the players in the not_ready state or has GAMA sent the end of the game ?
	bool flooding_over  { 
		if (restart_requested_from_gama) {return true;}
		if (gama.machine_time >= current_timeout) {return true;}
		if (empty(unity_player)) {return false;}
		return unity_player all_match each.in_tutorial;
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
	int min_num_players  <- -1;
	list<point> init_locations <- define_init_locations();
	unity_property up_people;
	unity_property up_dyke;
	unity_property up_water;
	
	
	
	init {
		
		unity_aspect car_aspect <- prefab_aspect("Prefabs/Visual Prefabs/People/WalkingMen",250,0.2,1.0,-90.0, precision);
		unity_aspect dyke_aspect <- geometry_aspect(40.0, "Materials/Dike/Dike", rgb(0, 0, 0, 0.0), precision);
		unity_aspect water_aspect <- geometry_aspect(40.0, rgb(0, 0, 255, 0.0), precision);
 	
		up_people<- geometry_properties("car", nil, car_aspect, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #collider, false);
		up_water <- geometry_properties("water", nil, water_aspect, #no_interaction,false);

		unity_properties << up_people;
		unity_properties << up_dyke;
		unity_properties << up_water;
		
	}

	action add_to_send_world(map map_to_send) {
		map_to_send["evacuated"] <- int(evacuated);
		map_to_send["score"] <- int(100*evacuated/nb_of_people);
		map_to_send["remaining_time"] <- int((current_timeout - gama.machine_time)/1000);
		map_to_send["state"] <- world.state;
		map_to_send["winning"] <- winning;
	} 
	list<point> define_init_locations {
		return [world.location + {0,0,1000}];
	} 

	list<float> convert_string_to_array_of_float(string my_string) {
    	return (my_string split_with ",") collect float(each);
	}
	
	action action_management_with_unity(string unity_start_point, string unity_end_point) {
		list<float> unity_start_point_float <- convert_string_to_array_of_float(unity_start_point);
		list<float> unity_end_point_float <- convert_string_to_array_of_float(unity_end_point);
		point converted_start_point <- {unity_start_point_float[0], unity_start_point_float[1], unity_start_point_float[2]};
		point converted_end_point <- {unity_end_point_float[0], unity_end_point_float[1], unity_end_point_float[2]};
		create dyke with: (shape: line([converted_start_point, converted_end_point]));
		do send_message players: unity_player as list mes: ["ok_build_dyke_with_unity " + converted_start_point + "   " + converted_end_point :: true];
		ask experiment {
			do update_outputs(true); 
		}
	}
 
	
	
	/**
	 * Send dynamic geometries when it is necessary. 
	 */
	 
	 action send_static_geometries {
		do add_geometries_to_send(river,up_water);
	 }



	/**
	 * What are the agents to send to Unity, and what are the agents that remain unchanged ? 
	 */
	reflex send_agents when: not empty(unity_player) {
		if (state = "s_diking") {
			// All the dykes are sent to Unity during the diking phass
			do add_geometries_to_send(dyke, up_dyke);
			// The river is not changed so we keep it unchanged
			do add_geometries_to_keep(river);
		} else	if (state = "s_flooding") {
			// We only send the people who are evacuating 
			do add_geometries_to_send(people where (each.state = "s_fleeing"),up_people);
			// We send the river (supposed to change every step)
			do add_geometries_to_send(river,up_water);
			// We send only the dykes that are not underwater
			do add_geometries_to_send(dyke select !each.drowned, up_dyke);	 
		}
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
	rgb color <- #red;
	init {
		do set_status(IN_TUTORIAL);
		//ask unity_linker {do send_static_geometries();}
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
			write sample(id);
		}
	}

	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask unity_linker {
				unity_player pl <- player_agents[id_input];
				write sample(pl);
				if (pl != nil) {
					remove key: id_input from: player_agents ;
					ask pl {do die;}
				}
				write sample(player_agents);
			}
			
		}
	}

	output {
		
		layout #none controls: false toolbars: false editors: false parameters: false consoles: false tabs: false;
		
		
		 display map_VR type: 3d background: #dimgray axes: false{
		 	
		 	species river transparency: 0.2 {
		 		//draw shape + 30 color: #white wireframe: false width: 5;
		 		//draw shape + 15 color: brighter(brighter(#lightseagreen)) wireframe: false width: 5 at: location + {0, 0, 0.5};
		 		//draw shape color: #lightseagreen wireframe: false width: 5 at: location + {0, 0, 1};
				draw shape border: brighter(brighter(#lightseagreen)) width: 5 color: #lightseagreen  at: location + {0, 0, 5};
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
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: rgb(232, 215, 164);
			}
			
			event #mouse_down {
				if (button_selected) {
					if (state = "s_diking") {flooding_requested_from_gama <- true; return;} else
					if (state = "s_flooding") {restart_requested_from_gama <- true; return;}
				}
			}
			
			event #mouse_move { 
				button_selected <- button_frame != nil and button_frame overlaps #user_location;
			}

			event "r" {
				world.restart_requested_from_gama <- true ;
			}
		
			event "d" {
				world.diking_requested_from_gama <- true ;
			}
			
			event "f" {
				world.flooding_requested_from_gama <- true ;
			}
		 	
		 	
			species unity_player {
				draw circle(30) at: location + {0, 0, 50} color: rgb(color, 0.5) ;
			}
			
			
			graphics "Text and icon"   {
				string text <- nil;
				string hint <- nil;
				string timer <- nil;

								
				switch (state) {
					match "s_diking" {
						text <- "Diking phase.";
						hint <- "Press 'f' for skipping.";
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + int(left / 1000) + " seconds.";
					}	
					match "s_flooding" {
						text <- "Casualties: " + casualties + '/' + nb_of_people;
						hint <- "Press 'r' for restarting.";
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Restart now.": "Restarting in " + int(left / 1000) + " seconds.";
					}
					match "s_init" {
						text <- "Tutorial phase in VR.";
						hint <- "Press 'd' for diking.";
					}
				}
				if (text != nil) {
					draw text font: font ("Helvetica", 18, #bold) at: text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 10, #bold) at: text_position + {0, 100} anchor: #top_left color: text_color;	
				}
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 14, #plain) at: timer_position anchor: #top_left color: text_color;	
				}
				
				if (button_image_unselected != nil) { 
					button_frame <- square(300) at_location icon_position;
					draw button_selected ? button_image_selected : button_image_unselected size: 300 at: icon_position;
				}
			}

		 }
	}
}
