model NewModel_model_VR

import "GameModel.gaml"

global {
	action after_creating_dyke {
		ask unity_linker {
			
			list<geometry> geoms <- dyke collect (each.shape + 10.0);
			do add_geometries_to_send( geoms,up_dyke);	
			
			
			
			do send_world;
			do send_current_message;
		}
	}
	
}

species unity_linker parent: abstract_unity_linker {
	string player_species <- string(unity_player);
	int max_num_players  <- -1;
	int min_num_players  <- 10;
	list<point> init_locations <- define_init_locations();
	unity_property up_people;
	unity_property up_dyke;

	action add_to_send_world(map map_to_send) {
		map_to_send["score"] <- score;
		map_to_send["budget"] <- budget;
	}
	list<point> define_init_locations {
		return [world.location];
	}
	
	action update_score(float diff_value)
	{
		score <- world.update_score_global(diff_value);
	}
	
	action update_budget(float diff_value)
	{
		budget <- world.update_budget_global(diff_value);
	}
	
	list<float> convert_string_to_array_of_float(string my_string)
	{
    	
    	return (my_string split_with ",") collect float(each);
    	/*list<float> float_array <- [];
    	
    	
    	string temp_string <- "";

    	int length <- length(my_string);
    	loop i from: 0 to: (length - 1) 
    	{
        	if (my_string at i = ',') 
        	{
            	float_array <- float_array + (temp_string as float);
            	temp_string <- "";
        	} 
        	else 
        	{
            	temp_string <- temp_string + my_string at i;
        	}
    	}

    	float_array <- float_array + (temp_string as float);
    	
    	return float_array;*/
	}
	
	unknown action_management_with_unity(string unity_start_point, string unity_end_point)
	{
		write sample(unity_start_point);
		write sample(unity_end_point);
		
		list<float> unity_start_point_float <- convert_string_to_array_of_float(unity_start_point);
		list<float> unity_end_point_float <- convert_string_to_array_of_float(unity_end_point);
		write sample(unity_start_point_float);
		write sample(unity_end_point_float);
		point converted_start_point <- {unity_start_point_float[0], unity_start_point_float[1], unity_start_point_float[2]};
		point converted_end_point <- {unity_end_point_float[0], unity_end_point_float[1], unity_end_point_float[2]};
		
		let l <- world.action_management_with_unity_global(converted_start_point, converted_end_point);
		write sample(ok_build_dyke_with_unity);
		do send_message players: unity_player as list mes: ["ok_build_dyke_with_unity":: ok_build_dyke_with_unity];
		return l;
	}
	
	init {
		//define the unity properties
		do define_properties;
		
	}
	
	//action that defines the different unity properties
	action define_properties {
		
		//define a unity_aspect called tree_aspect that will display in Unity the agents with the SM_arbres_001 prefab, with a scale of 2.0, no y-offset, 
		//a rotation coefficient of 1.0 (no change of rotation from the prefab), no rotation offset, and we use the default precision. 
		unity_aspect car_aspect <- prefab_aspect("Prefabs/Visual Prefabs/City/Vehicles/Car",100,0.2,1.0,-90.0, precision);
		unity_aspect dyke_aspect <- geometry_aspect(10.0, #green, precision);
	
		//define the up_car unity property, with the name "car", no specific layer, the car_aspect unity aspect, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_people<- geometry_properties("car", nil, car_aspect, #no_interaction, false);
		up_dyke <- geometry_properties("dyke", "dyke", dyke_aspect, #no_interaction, false);
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_people;
		unity_properties << up_dyke;
		
	}
	
	reflex send_agents when: not empty(unity_player) {
		do add_geometries_to_send(people where (each.my_path != nil),up_people);
		do add_geometries_to_send(dyke collect (each.shape + 10.0) ,up_dyke);	
	}
	


}

species unity_player parent: abstract_unity_player{
	float player_size <- 1.0;
	rgb color <- #red;	
	float cone_distance <- 10.0 * player_size;
	float cone_amplitude <- 90.0;
	float player_rotation <- 90.0;
	bool to_display <- true;
	aspect default {
		if to_display {
			if selected {
				 draw circle(player_size) at: location + {0, 0, 4.9} color: rgb(#blue, 0.5);
			}
			draw circle(player_size/2.0) at: location + {0, 0, 5} color: color ;
			draw player_perception_cone() color: rgb(color, 0.5);
		}
	}
}

experiment vr_xp parent:game autorun: false type: unity {
	float minimum_cycle_duration <- 0.05;
	string unity_linker_species <- string(unity_linker);
	list<string> displays_to_hide <- ["map"];
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
		 display map_VR parent:map{
			 species unity_player;
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
