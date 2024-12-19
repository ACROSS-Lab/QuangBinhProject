model Flood_VR

import "Flooding Model.gaml"

global { 
	

	bool use_tell <- false;
	bool ready_to_build_dyke <- false;
	/*************************************************************
	 * Redefinition of initial parameters for people, water and obstacles
	 *************************************************************/


 
	/************************************************************* 
	 * "Winning" condition: determines whether the player 
	 * has "won" or "lost" depending on the number of lives he/she
	 * saved with the dykes
	 *************************************************************/
	 
	int max_number_of_casualties <- round(nb_of_people / 5);

	//bool winning -> casualties < max_number_of_casualties;
	
	
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
	 
	 
	 string START_PRESSED <- "START_PRESSED";

	string IN_FLOOD <- "IN_FLOOD";
	
	string IN_DYKE_BUILDING <- "IN_DYKE_BUILDING";

	/*************************************************************
	 * Functions that control the transitions between the states
	 *************************************************************/
	 
	bool river_already_sent_in_diking_phase;
	
  
	action enter_init {
		write "enter_init";
		do enter_init_base;
		ask unity_player {do set_status(IN_TUTORIAL);}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		button_frame <- nil;
		button_image_unselected <- nil;
		button_image_selected <- nil;
	}
	
	action enter_start {
		write "enter_start";
		init_requested_from_gama <- false;
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		ask unity_player {
			start_pressed <- false;
			do set_status(IN_TUTORIAL);
		}	
		button_frame <- nil;
		button_image_unselected <- nil;
		button_image_selected <- nil;
	}
	
	
	action exit_flooding {
		write "exit_flooding";
		
		ask unity_linker {do sendEndGame;}
		do exit_flooding_base;
	}
	
	action exit_init {
		write "exit_init";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["end_init"::""];
		}
	}
	
	
	action exit_diking {
		write "exit_diking";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["end_diking"::""];
		}
	}
	
	action body_init  {
		write "body_init";
		if (!recording) {do playback();}
	}
	
	action body_flooding {
		write "body_flooding";
		
		if (recording) {do record();} 
		current_step <- current_step +1;
	}
	
	action body_diking {
		if !(unity_player all_match each.in_dyke_building) {
			current_timeout <- gama.machine_time + diking_duration * 1000;
		}
		
	}
	
	action enter_diking {
		write "enter_diking";
		ask unity_linker {do send_static_geometries();}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		button_image_unselected <- image("../../includes/icons/flood-line.png") * rgb(232, 215, 164);
		button_image_selected <- image("../../includes/icons/flood-fill.png") * rgb(232, 215, 164);
	}
	
	action enter_flooding {
		write "enter_flooding";
		
		river_already_sent_in_diking_phase <- false;
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		button_image_unselected <- image("../../includes/icons/restart-line.png");
		button_image_selected <- image("../../includes/icons/restart-fill.png");
		current_step <- 0;
		
	}
	
	bool flooding_ready {
		return unity_player all_match each.in_flood;
	} 
	
	// Are all the players who entered ready or has GAMA sent the beginning of the game ? 
	bool init_over  { 
		
		return playback_finished;
	} 
	
	bool start_over {
		if (init_requested_from_gama) {return true;}
		if (empty(unity_player)) {return false;}
		return unity_player all_match each.start_pressed;
	}
	
	
	bool diking_over { 
		if (flooding_requested_from_gama) {return true;}
		if (gama.machine_time >= current_timeout) {return true;}
		return false;
	}
	
	// Are all the players in the not_ready state or has GAMA sent the end of the game ?
	bool flooding_over  { 
		if (restart_requested_from_gama) {return true;}
		if (current_step > num_step) {return true;} 
		if (empty(unity_player)) {return false;}
		return unity_player all_match each.in_tutorial;
	}	
	 
	
	/*************************************************************
	 * Record and playback the initial state
	 *************************************************************/
	 
	
	/*************************************************************
	 * Flags to control the phases in the simulations
	 *************************************************************/

	// Is a restart requested by the user ? 
	bool restart_requested_from_gama;
	
	// Is the flooding stage requested by the user ? 
	bool flooding_requested_from_gama;
	
	// Is the initial flooding stage requested by the user ? 
	bool init_requested_from_gama;
	
	// Is the diking stage requested by the user ? 
	bool diking_requested_from_gama; 

 
}

species unity_linker parent: abstract_unity_linker { 
	string player_species <- string(unity_player);
	int max_num_players  <- -1;
	int min_num_players  <- -1;
	list<point> init_locations <- define_init_locations();
	unity_property up_people;
	unity_property up_dyke;
	unity_property up_water;
	bool do_send_world <- true;
	
	map<string, dyke> dykes;
	init {
		
		unity_aspect car_aspect <- prefab_aspect("Prefabs/Visual Prefabs/People/WalkingMen",250,0.2,1.0,-90.0, precision);
		unity_aspect dyke_aspect <- geometry_aspect(40.0, "Materials/Dike/Dike", rgb(204, 119, 34, 1.0), precision);
		unity_aspect water_aspect <- geometry_aspect(20.0, rgb(90, 188, 216, 0.0), precision);
 	
		up_people<- geometry_properties("car", nil, car_aspect, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #ray_interactable, false);
		up_water <- geometry_properties("water", nil, water_aspect, #no_interaction,false);

		unity_properties << up_people;
		unity_properties << up_dyke;
		unity_properties << up_water;
		
	}

	action sendEndGame { 
		//write "send_message score : " +  int(100*evacuated/nb_of_people);
		
		do send_message players: unity_player as list mes: ["score":: int(100* (1 - casualties/nb_of_people)), "round":: current_round, "endgame"::current_round >= num_rounds];
	}
	action add_to_send_world(map map_to_send) {
		map_to_send["remaining_time"] <- int((current_timeout - gama.machine_time)/1000);
		map_to_send["state"] <- world.state;
		//map_to_send["winning"] <- winning;
		map_to_send["playback_finished"] <- playback_finished;
		
		
		//write sample(world.state) + " " + sample(playback_finished);
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
 
	action destroy_dyke(string id) {
		dyke d <- dyke first_with (each.name = id);
		if (d != nil){
			ask d { do die;}
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
		if (state = "s_init" and !recording) and not playback_finished {
			do add_geometries_to_send(people, up_people);
			do add_geometries_to_send(river, up_water);
		} else if (state = "s_diking") {
			// All the dykes are sent to Unity during the diking phass
			do add_geometries_to_send(dyke, up_dyke);
			// The river is not changed so we keep it unchanged
			if (river_already_sent_in_diking_phase) {do add_geometries_to_keep(river);} else {do add_geometries_to_send(river, up_water); river_already_sent_in_diking_phase <- true;}
			
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
		write "NEW STATUS: " + status;
		unity_player player <- player_agents[player_id];
		//write "set status: " + sample(player_id) + " " + sample(player) + " " + sample(status);
		if (player != nil) {
			ask player {do set_status(status);}
		}
	}
	

 
}

species unity_player parent: abstract_unity_player{
	
	bool in_tutorial;
	bool in_flood;
	bool start_pressed;
	bool in_dyke_building;
	rgb color <- #red;
	init {
		do set_status(IN_TUTORIAL);
	}
	
	action set_status(string status) {
		in_tutorial <- status = IN_TUTORIAL;
		start_pressed <- status = START_PRESSED;
		in_flood <- status = IN_FLOOD;
		in_dyke_building <- status = IN_DYKE_BUILDING;
	}
	

} 

experiment Launch  autorun: true type: unity {


	string unity_linker_species <- string(unity_linker);
	float t_ref;
	float minimum_cycle_duration <- cycle_duration;
	 	
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

	output synchronized: true{
		
		layout #none controls: false toolbars: true editors: false parameters: false consoles: true tabs: false;
		
		
		display map type: 3d axes: false background: background_color antialias: false{
 	
		 	species river visible: !river_in_3D {
				draw shape border: brighter(brighter(river_color)) width: 5 color: river_color;
			}			 

			species road {
				draw drowned ? shape : shape + 10 color: drowned ? darker(river_color) : road_color ;
			}
		 	species buildings {
		 		draw shape color: drowned ? river_color : color border: drowned ? darker(river_color):color;	
		 	}
		 	species dyke {
		 		draw shape + 5 color: drowned ? river_color : dyke_color border: drowned ? darker(river_color):dyke_color;	
			} 
			species people {
				draw circle(20)  color: people_color;
			}
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: evacuation_color;
			}

			mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D transparency: 0.5;
			
			
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
				string timer <- nil;
				string hint <- nil;
				string keep <- nil;

								
				switch (state) {
					match "s_start" {
						text <- "Waiting for player to begin.";
					}match "s_init" {
						text <-  "Previous Flood !\n" + "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//timer <- button_selected ? "Restart now.": "Restarting in " + int(left / 1000) + " seconds.";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
					match "s_diking" {
						text <- "Build dykes with the mouse. Meters of dyke built: "+ round(dyke_length) + "/" + round(dyke_length_max);
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + int(left / 1000) + " seconds.";
						hint <- "Press 'r' to remove a dyke\nPress 'f' for skipping.";
						
						//\nPress 'f' to start immediately.";
					}	
					match "s_flooding" {text <- "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//hint <- "Press 'r' for restarting.";
						timer <- "End in " +(num_step - current_step) + " minutes";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
				}
				//draw background color: darker(frame_color) width: 5 border: brighter(frame_color) at: background_position + {background.width / 2, background.height/2, -10} lighted: false ;
				if (text != nil) {
					draw text font: font ("Helvetica", 18, #bold) at: text_position anchor: #top_left color: text_color;	
				}
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 14, #plain) at: timer_position anchor: #top_left color: text_color;	
				}
				if (keep != nil) {
					draw keep font: font ("Helvetica", 14, #plain) at: check_text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 10, #bold) at: text_position + {0, 130} anchor: #top_left color: text_color;	
				}		
			}	
			

		 }
	}
}
