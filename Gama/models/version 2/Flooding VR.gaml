model Flood_VR

import "Flooding Model.gaml"
 
global { 
	

	bool use_tell <- false;
	bool ready_to_build_dyke <- false;
	 
	bool diking_over <- false;
	/*************************************************************
	 * Redefinition of initial parameters for people, water and obstacles
	 *************************************************************/


 
	/************************************************************* 
	 * "Winning" condition: determines whether the player 
	 * has "won" or "lost" depending on the number of lives he/she
	 * saved with the dykes
	 *************************************************************/
	
	
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
		//write "enter_init";
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
		//write "enter_start";
		ask unity_player {
			start_pressed <- false;
			do set_status(IN_TUTORIAL);
		}	
	}
	
	 action end_game_action {
	 	//ask unity_linker {do sendEndGame;}
	 }
	
	action exit_flooding {
		do exit_flooding_base;
		ask unity_linker {do send_message players: unity_player as list mes: ["score":: round(world.score)];}
	}
	
	action exit_init {
		//write "exit_init";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["end_init"::""];
		}
	}
	
	
	action exit_diking {
		//write "exit_diking";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["end_diking"::""];
		}
		current_timeout <- gama.machine_time + diking_duration * 1000;
		
	}
	
	action body_init  {
		
	}
	
	action body_flooding {
		
		do enter_flooding_base;

	} 
	
	action body_diking {
		if !(unity_player all_match each.in_dyke_building) {
			current_timeout <- gama.machine_time + diking_duration * 1000;
		}
		
	}
	
	action enter_diking {
		//write "enter_diking";
		diking_over <- false;
		
		//write "enter_diking";
		ask unity_linker {
			do send_static_geometries();
			do send_message players: unity_player as list mes: ["round":: current_round];
		}
		flooding_requested_from_gama <- false;
		diking_requested_from_gama <- false;
		restart_requested_from_gama <- false;	
		
		
	}
	
	action enter_flooding {
		write "enter_flooding";
		
		do enter_flooding_base;
		
		
	}
	
	bool flooding_ready {
		return unity_player all_match each.in_flood;
	} 
	
	// Are all the players who entered ready or has GAMA sent the beginning of the game ? 
	bool init_over  { 
		
		return (current_step > num_step) ;
	} 
	
	bool start_over {
		if (init_requested_from_gama) {return true;}
		if (empty(unity_player)) {return false;}
		return unity_player all_match each.start_pressed;
	}
	
	
	bool diking_over { 
		//write "diking_over: " + sample(diking_over) + " " + sample(gama.machine_time >= current_timeout);
		
		return  diking_over or gama.machine_time >= current_timeout;
	}
	
	// Are all the players in the not_ready state or has GAMA sent the end of the game ?
	bool flooding_over  { 
		if (current_step > num_step) {return true;} 
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
	unity_property up_dam;
	unity_property up_water;
	unity_property up_shelter;
	unity_property up_injuries;
	
	
	unity_property up_frontier_green;
	unity_property up_frontier_orange;
	unity_property up_frontier_red;
	bool do_send_world <- true;
	
	map<string, dyke> dykes;
	init {
		
		unity_aspect people_aspect <- prefab_aspect("Prefabs/Visual Prefabs/People/WalkingMen",400,0.2,1.0,-90.0, precision);
		unity_aspect people_aspect_injured <- prefab_aspect("Prefabs/Visual Prefabs/People/Injuries",400,0.2,1.0,-90.0, precision);
//		unity_aspect dyke_aspect <- geometry_aspect(40.0, "Materials/Dike/Dike", #gray,  precision);
//		unity_aspect dam_aspect <- geometry_aspect(40.0, "Materials/Dike/Dam", #magenta, precision);
		unity_aspect dyke_aspect <- prefab_aspect("Prefabs/DikeBlock", 3, 0.0, 1.0, 0.0, precision);
		unity_aspect dam_aspect <- prefab_aspect("Prefabs/DamBlock", 3, 0.0, 1.0, 0.0, precision);
	//	unity_aspect water_aspect <- geometry_aspect(5.0, #blue,precision);
		unity_aspect water_aspect <- geometry_aspect(10.0, "Materials/Water/Water Material",precision);
		
		unity_aspect shelter_aspect <- prefab_aspect("Prefabs/Shelter",150.0,0.0,1.0,0.0, precision);
		
		up_people<- geometry_properties("people", nil, people_aspect, #no_interaction, false);
		up_injuries<- geometry_properties("injury", nil, people_aspect_injured, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #ray_interactable, false);
		up_dam <- geometry_properties("dam", "dam", dam_aspect, #ray_interactable, false);
		up_water <- geometry_properties("water", nil, water_aspect, #no_interaction,false);
		up_shelter <- geometry_properties("shelter", nil, shelter_aspect,#ray_interactable,false);
		
		unity_aspect frontier_green_aspect <- geometry_aspect(50.0, #green,  precision);
		unity_aspect frontier_orange_aspect <- geometry_aspect(50.0, #orange,  precision);
		unity_aspect frontier_red_aspect <- geometry_aspect(50.0, #red,  precision);
	
		up_frontier_green<- geometry_properties("frontier_green", nil, frontier_green_aspect, #no_interaction, false);
		up_frontier_orange<- geometry_properties("frontier_orange", nil, frontier_orange_aspect, #no_interaction, false);
		up_frontier_red<- geometry_properties("frontier_red", nil, frontier_red_aspect, #no_interaction, false);
	
		
		unity_properties << up_frontier_green;
		unity_properties << up_frontier_orange;
		unity_properties << up_frontier_red;

		unity_properties << up_people;
		unity_properties << up_dyke;
		unity_properties << up_dam;
		unity_properties << up_water;
		unity_properties << up_shelter;
		unity_properties << up_injuries;
		
		//add the static_geometry agents as static agents/geometries to send to unity with the up_geom unity properties.
		do add_background_geometries(evacuation_point,up_shelter);
	
		//do add_background_geometries(water_limit_drain collect (each + 20),up_frontier_green);
		list<geometry> water_limit_well_ts;
		geometry ir <- init_river + 100;
		loop  wl over: water_limit_well {
			if (ir overlaps wl) {
				water_limit_well_ts <- water_limit_well_ts + (wl - ir).geometries where (each.perimeter > 100);
			} else {
				water_limit_well_ts << wl;
			}
		}
		do add_background_geometries(water_limit_well_ts collect (each + 20),up_frontier_orange);
		do add_background_geometries(water_limit_danger collect (each + 20),up_frontier_red);
	
		
	}
	
	action end_diking(string player_id) {
		diking_over <- true;
	}

	action sendEndGame { 
		//write "send_message score : " +  int(100*evacuated/nb_of_people);
		
		do send_message players: unity_player as list mes: ["score":: int(100* (1 - casualties/nb_of_people)), "round":: current_round, "endgame"::current_round >= num_rounds];
	}
	
	action sendLengthData {
		do send_message players: unity_player as list mes: ["dykeLength":: round(world.dyke_length)];
		do send_message players: unity_player as list mes: ["damLength":: round(world.dam_length)];
	}
	
	action add_to_send_world(map map_to_send) {
//		map_to_send["remaining_time"] <- int((current_timeout - gama.machine_time)/1000);
		map_to_send["state"] <- world.state;
		map_to_send["score"] <- round(world.score);
		map_to_send["casualties"] <- world.casualties;
		//map_to_send["winning"] <- winning;
	//	map_to_send["playback_finished"] <- playback_finished;
		 
		
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
		
		
		
		//create dyke with: (shape: line([converted_start_point, converted_end_point])) ;
		bool is_ok <- world.create_dyke(converted_start_point, converted_end_point);
		do send_message players: unity_player as list mes: ["ok_build_dyke_with_unity " + converted_start_point + "   " + converted_end_point :: is_ok];
		ask experiment {
			do update_outputs(true);  
		}
	}
 
	action destroy_dyke(string id) {
		dyke d <- dyke first_with (each.name = id);
		if (d != nil){
			
			ask d {
				if (is_dam) {
					dam_length <- dam_length - length; 
				} else {
					dyke_length <- dyke_length - length; 
				}
				loop c over: cells_under {
					c.obstacles >> self;
				 	if (c in bed_cells) {
				 		c.water_height <- initial_water_height;
				 	}
				 }
				 do die;
			}
		} 		
	}
	 
	
	
	/**
	 * Send dynamic geometries when it is necessary. 
	 */
	 
	 action send_static_geometries {
		do add_geometries_to_send(river,up_water);
	 }


	action add_people {
		list<people> fleeing_p <- people where (each.state = "s_fleeing");
		ask fleeing_p {
			name <- "fleeing_" + int(self);
		}
		list<people> injured_p <- people where (each.state = "s_drowned");
		ask injured_p {
			name <- "injury_" + int(self);
		}
		do add_geometries_to_send(fleeing_p,up_people);
		do add_geometries_to_send(injured_p,up_injuries);
	}
	/**
	 * What are the agents to send to Unity, and what are the agents that remain unchanged ? 
	 */
	reflex send_agents when: not empty(unity_player) {
		if (state = "s_init") {
			do add_people;
			// We send the river (supposed to change every step)
			do add_geometries_to_send(river collect each.shape_to_export,up_water);
			
		} else if (state = "s_diking") {
			// All the dykes are sent to Unity during the diking phass
			list<float> dykes_length <- (dyke where !each.is_dam) collect each.length;
			list<float> dykes_rotation <- (dyke where !each.is_dam) collect each.rotation; 
			map<string, list<float>> dykes_atts <- ["length" :: dykes_length ,"rotation" :: dykes_rotation];
			
			list<float> dams_length <- (dyke where each.is_dam) collect each.length;
			list<float> dams_rotation <- (dyke where each.is_dam) collect each.rotation;
			map<string, list<float>> dams_atts <- ["length" :: dams_length ,"rotation" :: dams_rotation];
			
			do add_geometries_to_send(dyke where !each.is_dam, up_dyke, dykes_atts);
			do add_geometries_to_send(dyke where each.is_dam, up_dam, dams_atts);
			
//			do add_geometries_to_keep(dyke);
			do sendLengthData;
			// The river is not changed so we keep it unchanged
			if (river_already_sent_in_diking_phase) {do add_geometries_to_keep(river);} 
			else {do add_geometries_to_send(river collect each.shape_to_export, up_water); river_already_sent_in_diking_phase <- true;}
			
		} else	if (state = "s_flooding") {
			// We only send the people who are evacuating 
			do add_people;
			// We send the river (supposed to change every step)
			do add_geometries_to_send(river collect each.shape_to_export,up_water);
			// We send only the dykes that are not underwater
			list<float> dykes_length <- (dyke where !each.is_dam) collect each.length;
			list<float> dykes_rotation <- (dyke where !each.is_dam) collect each.rotation; 
			map<string, list<float>> dykes_atts <- ["length" :: dykes_length ,"rotation" :: dykes_rotation];
			
			list<float> dams_length <- (dyke where each.is_dam) collect each.length;
			list<float> dams_rotation <- (dyke where each.is_dam) collect each.rotation;
			map<string, list<float>> dams_atts <- ["length" :: dams_length ,"rotation" :: dams_rotation];
			
			do add_geometries_to_send(dyke select (!each.is_dam and !each.drowned), up_dyke, dykes_atts);	
			do add_geometries_to_send(dyke select (each.is_dam and !each.drowned), up_dam, dams_atts);	 
		}
	}

	// Message sent by Unity to inform about the status of a specific player
	action set_status(string player_id, string status) {
		//write "NEW STATUS: " + status;
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
	float minimum_cycle_duration <- cycle_duration;
	
	point start_point; 
	point end_point;  
	geometry line; 
	 
	 
	 
	//action called by the middleware when a player connects to the simulation
	action create_player(string id) {
		ask unity_linker {
			do create_player(id);
		}
	}

	//action called by the middleware when a plyer is remove from the simulation
	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask first(unity_player where (each.name = id_input)) {
				do die;
			}
		}
	}
	
	output { 
		
		layout #none controls: false toolbars: false editors: false parameters: false consoles: false tabs: false;
		display map type: 3d axes: false background: background_color antialias: false{
			camera 'default' location: {1441.2246,3297.5234,8595.6544} target: {1441.2246,3297.3733,0.0};
			//	grid cell border: #black;
		 	species river visible:!river_in_3D{
				draw shape_to_export border: brighter(brighter(river_color)) width: 5 color: river_color;
			}	 

			species road {
				draw drowned ? shape : shape + 10 color: drowned ? darker(river_color) : road_color ;
			}
		 	species buildings {
		 		draw shape color: drowned ? river_color : color border: drowned ? darker(river_color):color;	
		 	}
		 	graphics "end_of_world" {
				loop d over: water_limit_danger {
					draw d + 20 color: #red;
				}
				loop d over: water_limit_well {
					draw d + 20 color: #orange;
				}
				loop d over: water_limit_drain {
					draw d + 20 color: #green;
				}
			}  
		 	species dyke {
		 		if (!is_dam) {
		 			draw shape + 5 color: drowned ? river_color : dyke_color border: drowned ? darker(river_color):#black;	
		 		} else {
		 			draw shape + 5 color: drowned ? river_color : dam_color border: drowned ? darker(river_color):#black;	
		 		}
		 		
			}  
			species people {
				draw circle(20)  color: (state = "s_drowned" ? people_drowned_color : (state = "s_evacuated" ?  people_evacuated_color : people_color)); 
			 	
			}
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: evacuation_color border: #black;
			}
			
			species unity_player {
				draw circle(30) at: location + {0, 0, 50} color: rgb(color, 0.5) ;
			}

			//mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D transparency: 0.5;
			//species water_particule; 
			
			event "r" {
				if (state != "s_diking") { return;}
				if (start_point != nil) {
					start_point <- nil;
					line <- nil;
				} else { 
					ask world {
						geometry g <- circle(10) at_location #user_location;
				 		list<dyke> dykes <- dyke overlapping g;
				 		if (not empty(dykes)) {
				 			bool recompute_river <- false;
				 			ask dykes closest_to #user_location {
				 				if (is_dam) {
				 					dam_length <- dam_length - length; 
				 				} else {
				 					dyke_length <- dyke_length - length; 
				 				}
				 				loop c over: cells_under {
				 					c.obstacles >> self;
				 					if (c in bed_cells) {
				 						recompute_river <- true;
				 						c.water_height <- initial_water_height;
				 					}
				 				}
				 				do die;
				 			}
				 			if (recompute_river) {
				 				do compute_river_shape;
				 			}
				 			
				 		}
					}
					 
				}
				
			}  
			event #mouse_down {
				
				if (check_selected) {
					keep_dykes <- !keep_dykes;
				}
				if (state != "s_diking") { return;}
				if (start_point = nil) {
		 			start_point <- #user_location; 
					line <- line([start_point, #user_location]);
				} else {
					ask simulation {
						do create_dyke(myself.start_point, #user_location);
					}
					start_point <- nil;
				 	end_point <- nil;
				}

			}
			
			graphics "Arrow" {
				draw image_file("../../includes/icons/arrow-23645_1280.png") size: 400 rotate: -90 at: {location.x/1.75, location.y *2 - 200};

			}
			
			
			graphics "General information" {
				int offset <- 0;
				draw rectangle(3500,1000) color: #gray border: #black at: {5000, 700+offset, -1.0};
				draw "General information" font: font ("Helvetica", 22, #bold) at: {3400, 300+offset} anchor: #top_left color: text_color;	
				
				
				draw "Round: " + current_round+"/" + num_rounds font: font ("Helvetica", 18, #bold) at: {3400, 600+offset} anchor: #top_left color: text_color;
				
				if  current_round > 1 {
					draw "best score: " +  round(best_score) font: font ("Helvetica", 18, #bold) at: {3400, 900+offset} anchor: #top_left color: text_color;
				
				}	
				
			}
			graphics "Hints" {
				if current_round = num_rounds {
					int offset <- 1500;
					draw rectangle(3500,1200) + 50 color: #lightgreen border: #black at: {5000, 800+offset, -2.0};
					draw rectangle(3500,1200) color: #gray border: #black at: {5000, 800+offset, -1.0};
					
					draw "Hint" font: font ("Helvetica", 22, #bold) at: {3400, 300+offset} anchor: #top_left color: #lightgreen;	
					string hint <- "One strategy to combat flooding is the developmentof flood\n\nexpansion zones. This involves designating an area where\n\nfloodwaters from a watercourse can spread quickly with minimal\n\nrisk to people and property";
					
					
					draw hint font: font ("Helvetica", 14, #bold) at: {3400, 600+offset} anchor: #top_left color: text_color;
					
				}				
			}
			
			
			
			
			graphics "Legend" {
				int offset <- 500;
				draw rectangle(3500,2500) color: #gray border: #black at: {-1870, 2650+offset, -1.0};
				draw "Legend" font: font ("Helvetica", 22, #bold) at: {-3500, 1500+offset} anchor: #top_left color: text_color;	
				
				draw  image_file("../../includes/icons/arrow-23645_1280.png") size: 180 rotate: -90  border: #black at: {-3450, 1850+offset};
				draw "Direction of river flow" font: font ("Helvetica", 14, #bold) at: {-3300, 1800+offset} anchor: #top_left color: text_color;	
				
				draw line([{-3500, 2100+offset},{-3400, 2100+offset}]) + 20 color: #green ;
				draw "Drain-type border (water run-off)" font: font ("Helvetica", 14, #bold) at: {-3300, 2060+offset} anchor: #top_left color: text_color;	
				draw line([{-3500, 2300+offset},{-3400, 2300+offset}]) + 20 color: #orange ;
				
				draw "Well-type border (prevents water run-off)" font: font ("Helvetica", 14, #bold) at: {-3300, 2260+offset} anchor: #top_left color: text_color;	
				
				draw line([{-3500, 2500+offset},{-3400, 2500+offset}]) + 20 color: #red ;
				draw "Stake-type border (prevents water run-off and leads to point loss)" font: font ("Helvetica", 14, #bold) at: {-3300, 2460+offset} anchor: #top_left color: text_color;	
				
				
				draw line([{-3500, 2800+offset},{-3400, 2800+offset}]) + 20 color: dyke_color border: #black;
				draw "Dyke - price : 1 point / meter" font: font ("Helvetica", 14, #bold) at: {-3300, 2760+offset} anchor: #top_left color: text_color;	
				draw line([{-3500, 3000+offset},{-3400, 3000+offset}]) + 20 color: dam_color border: #black;
				draw "Dam - price : 10 points / meter" font: font ("Helvetica", 14, #bold) at: {-3300, 2960+offset} anchor: #top_left color: text_color;	
				
				draw circle(30)  color: people_color at:  {-3450, 3300+offset} ; 
				draw "People evacuating" font: font ("Helvetica", 14, #bold) at: {-3300, 3260+offset} anchor: #top_left color: text_color;	
				draw circle(30)  color: people_drowned_color at:  {-3450, 3500+offset} ; 
				draw "People injured" font: font ("Helvetica", 14, #bold) at: {-3300, 3460+offset} anchor: #top_left color: text_color;	
				
				draw circle(60)  color: evacuation_color at:  {-3450, 3700+offset} ; 
				draw "Shelter (evacuation point)" font: font ("Helvetica", 14, #bold) at: {-3300, 3660+offset} anchor: #top_left color: text_color;	
				
			
			}
			
			graphics "Text and icon"   {
					
				
				string stage <- nil;
				string timer <- nil;
				string hint <- nil;
				string indicators <- nil;
				
				rgb color_indicators <- text_color;
				stage <- "Waiting for player";	 
				switch (state) {
					match "s_init" {
						stage <-  "Flood without dykes/dams";
						
						//\n\n" + "Casualties: " + casualties + '/' + nb_of_people;
						timer <- "End in " +max(0,(num_step - current_step)) + " minutes";
						indicators <- "Casualties: " + casualties + '/' + nb_of_people + "\n\nScore: " + round(score);
						if (score <= 900 and score > 700) or (casualties > 0 and casualties< 10){
							color_indicators <- #yellow;
						} else if (score <= 700 and score > 500) or (casualties >= 10 and casualties< 100) {
							color_indicators <- #orange;
						} else if (score <= 500) or (casualties > 100)   {
							color_indicators <- #red;
						} else {
							color_indicators <- #lightgreen;
						}
						
						//float left <- current_timeout - gama.machine_time;
						//timer <- button_selected ? "Restart now.": "Restarting in " + int(left / 1000) + " seconds.";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
					match "s_diking" {
						stage <-  "Build dykes/dams";
						indicators <- "Meters of dyke built: "+ round(dyke_length) + "m" + "\n\nMeters of dam built: "+ round(dam_length) + "m";
					
						//text <- "Build dykes/dams with the mouse.\n\n\tMeters of dyke built: "+ round(dyke_length) + "m" + "\n\n\tMeters of dam built: "+ round(dam_length) + "m";
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + max(0,int(left / 1000)) + " seconds.";
						hint <- "Press 'r' to remove a dyke/dam\nPress 'f' for skipping.";
						
						//\nPress 'f' to start immediately.";
					}	
					match "s_flooding" {
						 
						stage <-  "Flood";
						indicators <- "Casualties: " + casualties + '/' + nb_of_people + "\n\nScore: " + round(score);
						
						//text <- "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//hint <- "Press 'r' for restarting.";
						timer <- "End in " +max(0,(num_step - current_step)) + " minutes";
						
						if (score <= 900 and score > 700) or (casualties > 0 and casualties< 10){
							color_indicators <- #yellow;
						} else if (score <= 700 and score > 500) or (casualties >= 10 and casualties< 100) {
							color_indicators <- #orange;
						} else if (score <= 500) or (casualties > 100)   {
							color_indicators <- #red;
						}else {
							color_indicators <- #lightgreen;
						}
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
					
				}
 
				draw rectangle(3500,1600) color: #gray border: #black at: {-1870, 1000,-1.0};
				draw "Current stage: " + stage font: font ("Helvetica", 22, #bold) at: {-3500, 300} anchor: #top_left color: text_color;	
			
				
				//draw background color: darker(frame_color) width: 5 border: brighter(frame_color) at: background_position + {background.width / 2, background.height/2, -10} lighted: false ;
				point timer_position_ <- {-3300, 600};
				point indicators_position <- {-3300, 1000};
	
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 18, #bold) at: timer_position_ anchor: #top_left color: text_color;	
				}
				if (indicators != nil) { 
					draw indicators font: font ("Helvetica", 18, #bold) at: indicators_position anchor: #top_left color: color_indicators;	
				}
				/*if (keep != nil) {
					draw keep font: font ("Helvetica", 16, #plain) at: check_text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 14, #bold) at: text_position + {0, 630} anchor: #top_left color: text_color;	
				}	*/	
				
				
		
			}
			
		
			
			event "f" {
				if (state != "s_diking") {return;}
				diking_over <- true;
			}
		
			
			event #mouse_move { 
				if (state != "s_diking") {line <- nil; return;}
				if (start_point != nil) {
					line <- line([start_point, #user_location]);
					is_ok_dyke_construction <- true;
				} else {
					line <- nil;
				}
			}
			
			 
			
			graphics ll {
				if (line != nil) {
					draw line + dyke_width + 5 color: is_ok_dyke_construction ? dyke_color : #red border: #black;
				}
			}
		}

	}

}
