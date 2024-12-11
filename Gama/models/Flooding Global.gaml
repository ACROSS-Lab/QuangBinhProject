/**
* Name: FloddingGlobal
* Based on the internal empty template. 
* Author: drogoul
* Tags: 
*/

@no_experiment

model FloddingGlobal

import "Flooding Model.gaml"

/* Insert your model definition here */


global control: fsm {
		
	 
	bool river_already_sent_in_diking_phase;
	
	/*************************************************************
	 * Statuses of the player, once connected to the middleware (and to GAMA)
	 *************************************************************/
	 
	 // The player should choose a language 
	 string IN_START <- "IN_START";
	 
	 // The player has chosen a language and is now waiting for the playback to run
	 string WAITING_FOR_PLAYBACK <- "WAITING_FOR_PLAYBACK";
	 
	 // The player is in the "playback" scene
	 string IN_PLAYBACK <- "IN_PLAYBACK";
	 
	 // The player is in the diking scene
	 string IN_DIKING <- "IN_DIKING";
	 	 
	 // The player has finished diking and is now waiting for the other players to finish as well
	 string WAITING_FOR_FLOODING <- "WAITING_FOR_FLOODING";

	 // The player is in the flooding scene
	 string IN_FLOODING <- "IN_FLOODING";

	
	
	/*************************************************************
	 * Record and playback the initial state
	 *************************************************************/
	 
	bool recording <- false;
	int number_of_milliseconds_to_wait_in_playback <- 10;//100;
	
	list<list<point>> people_positions;
	list<geometry> river_geometries;
	
	int current_step;
	bool playback_finished;
	
	action playback {
		playback_finished <- current_step = length(people_positions);
		if playback_finished {
			return;
		}
		int first <- first(people).index;
		ask people {
			location <- people_positions[current_step][self.index - first];
		}
		ask river {
			shape <- river_geometries[current_step];
		}
		float t2 <- gama.machine_time + number_of_milliseconds_to_wait_in_playback;
		loop while: gama.machine_time < t2 {}
		current_step <- current_step + 1;

	}
	
	action record {
		list<point> to_save <- [];
		ask people {
			to_save << self.location;
		}
		people_positions << to_save;
		ask river {
			river_geometries << copy(shape);
		}
		current_step <- current_step +1 ;
	}
	
	string path_to_include <- "../includes/";
	
	
	
	map<string, float> state_durations <- ["START"::60,"PLAYBACK"::120,"DIKING"::120,"FLOODING"::120] const: true;
	map<string, string> state_titles <- ["START"::"Initial phase","PLAYBACK"::"Playback phase","DIKING"::"Diking phase","FLOODING"::"Flooding phase"];
	map<string, string> state_next <- ["START"::"PLAYBACK","PLAYBACK"::"DIKING","DIKING"::"FLOODING","FLOODING"::"START"];
	
	/*************************************************************
	 * Global functions used by states
	 *************************************************************/	

	action enter_state {
		skipped_in_gama <- false;
		current_timeout <- gama.machine_time + state_durations[state] * 1000;
	}
	
	/*************************************************************
	 * Global functions that control the transitions between the states. 
	 *************************************************************/
	 
	 
	float current_timeout;
	bool skipped_in_gama;
	
	bool timeout {
		return gama.machine_time >= current_timeout;
	}
	
	bool overriden {
		return skipped_in_gama;
	}
	
	
	bool everyone_in(string status) {
		if (empty(unity_player)) {return false;}
		return unity_player all_match (each.status = status);
	}
	
	
	/*************************************************************
	 * Global states
	 *************************************************************/	
	 
	 
	state START initial: true {
		
		enter /* START */ {
			do enter_state();
			if (!recording and empty(people_positions)) {
				matrix<float> mf <- matrix(csv_file("people_positions.csv", ",",float));
				people_positions <- [];
				loop times: mf.rows / nb_of_people {
					people_positions << [];
				}
				loop line over: rows_list(mf) { 
					people_positions[int(line[0])] << point(line[1],line[2]);
 				}
				river_geometries <- shape_file("river_geometries.shp").contents;
			}
			ask unity_player {do set_status(IN_START);}
			current_step <- 0;
		}
		

		
		
		exit /* START */ {
			
		}
		
		transition to: PLAYBACK when: timeout() or overriden() or everyone_in(WAITING_FOR_PLAYBACK);
		
		
	} 
	
	
	state PLAYBACK {
		
		enter /* PLAYBACK */ {
			do enter_state();

			ask unity_player {
				do set_status(IN_PLAYBACK);
			}	
			
		}
		
		if (!recording) {do playback();}
		
		
		exit /* PLAYBACK */ {
			
		}
		
		transition to: DIKING when: timeout() or overriden() ;
		
		
	} 
	
	
		
	/**
	 * This state represents the state where the user(s) is(are) able to build dikes 
	 */
	state DIKING {
		
		enter /* DIKING */ {
			do enter_state();	
			ask unity_linker {do send_static_geometries();}
			ask unity_player {
				do set_status(IN_DIKING);
			}			
		}
		
		
		
		exit /* DIKING */ {
			
		}
		
		transition to: FLOODING when: timeout() or overriden() or everyone_in(WAITING_FOR_FLOODING);
		
		
	} 
	
	/**
	 * This state represents the state where the flooding dynamics is simulated 
	 */
	state FLOODING {
		
		enter /* FLOODING */ {
			do enter_state();
			ask unity_player {
				do set_status(IN_FLOODING);
			}	
			river_already_sent_in_diking_phase <- false;
			current_step <- 0;		
		}
		
		
		do add_water();
		do flow_water();
		do check_obstactles_drowning();
		do recompute_road_graph();
		do drain_water();
		if (recording) {do record();}
		
		
		
		exit /* FLOODING */ {
			ask unity_linker {do sendEndGame;}
			if (recording) {
				string total <- "";
				loop i from: 0 to: current_step - 1 {
					list<point> pp <- people_positions[i];
					loop p over: pp {
						total <- total + float(i) + "," + p.x + "," + p.y + "\n";
					}
				}
				save total to: "people_positions.csv" format:"txt";
				save river_geometries to: "river_geometries.shp" format: "shp";
			}
			ask experiment {do compact_memory;}
		}
		
		transition to: START when: timeout() or overriden() {
			do restart();
		}
		
		
	} 


	
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
		unity_aspect dyke_aspect <- geometry_aspect(40.0, "Materials/Dike/Dike", rgb(204, 119, 34, 1.0), precision);
		unity_aspect water_aspect <- geometry_aspect(20.0, rgb(90, 188, 216, 0.0), precision);
 	
		up_people<- geometry_properties("car", nil, car_aspect, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #collider, false);
		up_water <- geometry_properties("water", nil, water_aspect, #no_interaction,false);

		unity_properties << up_people;
		unity_properties << up_dyke;
		unity_properties << up_water;
		
	}

	action sendEndGame {
		//write "send_message score : " +  int(100*evacuated/nb_of_people);
		
		do send_message players: unity_player as list mes: ["score":: int(100*evacuated/nb_of_people)];
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
		unity_player player <- player_agents[player_id];
		//write "set status: " + sample(player_id) + " " + sample(player) + " " + sample(status);
		if (player != nil) {
			ask player {do set_status(status);}
		}
	}
	

 
}

species unity_player parent: abstract_unity_player{
	
	string status <- 'IN_START';
	rgb color <- #red;
	
	action set_status(string new_status) {
		self.status <- new_status;
	}
	

}

