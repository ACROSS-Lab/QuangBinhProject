/**
* Name: Flooding Model
* Author: Alexis Drogoul
* Description: This model is based on the toy model called "Hydrological Model" 
* and uses a simple flow diffusion model to simulate a flooding in a subset of Dong Hoi city
* (Quang Binh province). All interesting agents (the world and people) use fsm for their behavioral
* architecture. 
* This model can be experimented using either the classical UI of GAMA (see Flooding UI.gaml)
* or a VR environment (see Flooding VR.gaml)
*/
@no_experiment
@no_info

model Flooding

global control: fsm {
	
	
	bool recording <- false;
 	
 	bool save_results <- false;
 	
 	int num_step <- 120;
 	
 	float diking_duration <- 20.0;
	
	int num_rounds <- 2;
	
	int current_round <- 1;
	
	bool use_tell <- true;
	
	float cycle_duration <- 0.1;
 	
 	int number_of_milliseconds_to_wait_in_playback <- 10;//100;
	
	 float waiting_time_in_s <- 1.5;
	
		
	
	/*************************************************************
	 * Attributes dedicated to the UI (images, colors, frames, etc.)
	 *************************************************************/
	
	rgb background_color <- #dimgray;
	rgb frame_color <- rgb(1, 95, 115);
	rgb river_color <- rgb(74, 169, 163);
	rgb people_color <-rgb(232, 215, 164);
	rgb evacuation_color <- rgb(176, 32, 19);
	rgb road_color <- rgb(64, 64, 64);
	rgb line_color <- rgb(156, 34, 39);
	rgb dyke_color <- rgb(34, 156, 39);
	rgb text_color <- rgb(232, 215, 164);
	list<rgb> building_colors <- [rgb(214, 168, 0),rgb(237, 155, 0),rgb(202, 103, 2),rgb(120, 167, 121)];
	
	geometry background <- rectangle(1700, 1400);
	point text_position <- {-1500, 500};
	point background_position <- text_position - {200, 200};
	point timer_position <- {-1100, 1000};
	point icon_position <- {-1350, 1000};
	point check_position <- {-1350, 1300};
	point check_text_position <- {-1100, 1300};
	
	bool river_in_3D <- false; 
	geometry button_frame;  
	geometry check_frame;
	image button_image_unselected;
	image button_image_selected;
	image check_image_unselected;
	image check_image_selected; 
	bool button_selected;
	bool check_selected;
	
	/*************************************************************
	 * Global states
	 *************************************************************/	
	
	state s_start initial: true {
		enter {
			do enter_start();
		}
		
		transition to: s_init when: start_over();
	}
	
	state s_init {
		enter {
			do enter_init();
			
		}
		do body_init();
		exit {
			ask people {
				do die;
			}
			do init_people;
			do exit_init();
		}
		transition to: s_diking when: init_over();
	}



	
	/**
	 * This state represents the state where the user(s) is(are) able to build dikes 
	 */
	state s_diking {
		enter {
			do enter_diking();
		}
		do body_diking();
		exit {
			do exit_diking();
		}
		transition to: wait_flooding when: diking_over();
		
	}
	
	state wait_flooding {
		transition to: s_flooding when: flooding_ready() ;
	}
	
	/**
	 * This state represents the state where the flooding dynamics is simulated 
	 */
	state s_flooding {
		enter {
			do enter_flooding();
		}		
		do add_water();
		do flow_water();
		do check_obstactles_drowning();
		do recompute_road_graph();
		do drain_water();
		do body_flooding();
		exit {
			do exit_flooding();
		}
		transition to: s_start when: (current_round >= num_rounds) and  flooding_over() {
			do restart();
		}
		 transition to: s_diking when: (current_round < num_rounds) and flooding_over() {
			do restart();
		}
		 
	}

	/*************************************************************
	 * Functions that control the transitions between the states. 
	 * Must be redefined in sub-models
	 *************************************************************/
	 
	action enter_init virtual: true;
	
	action enter_diking virtual: true;
	
	action enter_flooding virtual: true;
	
	action enter_start virtual: true;
	
	action exit_flooding;
	
	action exit_diking;
	
	action exit_init;
	
	
	bool flooding_ready virtual: true;

	bool init_over virtual: true;
	
	bool diking_over virtual: true;
	
	bool flooding_over virtual: true;
	
	bool start_over virtual: true;
	
	action body_init {}
	
	action body_diking {}
	
	action body_flooding {}
 	
 
	
 	string id_sim <- "Game_" + (#now).year +"_" + (#now).month+"_"+(#now).day+ "_"+(#now).hour+ "_"+(#now).minute;
	
	list<list<point>> people_positions;
	list<list<int>> people_evacuated_casualties;
	list<geometry> river_geometries;
	
	int current_step;
	bool playback_finished;
	
		// The next timeout to occur for the different stages
	float current_timeout;
	
	
		
	
	// The maximum amount of time, in seconds, for building dikes 
		 
	 
	 action reset_game {
	 	if (save_results and not recording) {
	 		id_sim <- "Game_" + (#now).year +"_" + (#now).month+"_"+(#now).day+ "_"+(#now).hour+ "_"+(#now).minute;
	 		save "round,dyke_length,evacuated,casualties" to:id_sim+"/evacuated_casualties.csv" rewrite: true format:"text";
		}
	 	current_round <- 1;
	 	if (use_tell) {
	 		do tell("Restart the new game",false);
	 	}
	 }
	 action playback {
	 	playback_finished <- current_step = length(people_positions);
		if playback_finished {
			return;
		}
		int first <- first(people).index;
		ask people {
			point prev_loc <- copy(location);
			location <- people_positions[current_step][self.index - first];
			if (evacuation_time = -1 and current_step > 0 and location != prev_loc) {
				evacuation_time <- current_step;
			}
		}
		if current_step = 0 {
	 		ask people {
				init_loc <- location;
			}
	 	}
		ask river {
			shape <- river_geometries[current_step];
		}
		float t2 <- gama.machine_time + number_of_milliseconds_to_wait_in_playback;
		loop while: gama.machine_time < t2 {}
		evacuated <- people_evacuated_casualties[current_step][0];
		casualties <- people_evacuated_casualties[current_step][1];
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
		people_evacuated_casualties<< [evacuated,casualties];
	}
	
	action enter_flooding_base {
		if save_results and not recording{
			save dyke to:id_sim+"/dykes_" + current_round + ".shp"  format:"shp";
		}
		
		
	}
	action exit_flooding_base {
		if (recording) {
			string total <- "";
			loop i from: 0 to: current_step - 1 {
				list<point> pp <- i >= length(people_positions) ? last(people_positions) : people_positions[i];
				loop p over: pp {
					total <- total + float(i) + "," + p.x + "," + p.y + "\n";
				}
			}
			save total to: "people_positions.csv" format:"txt";
			save river_geometries to: "river_geometries.shp" format: "shp";
			
			string states_ <- "";
			loop i from: 0 to: current_step - 1 {
				list<int> pp <- i >= length(people_evacuated_casualties) ? last(people_evacuated_casualties) : people_evacuated_casualties[i]; 
				states_ <- states_ + pp[0] + "," + pp[1]+ "\n";
				
			}
			save states_ to: "people_states.csv" format:"txt";
		} else {
			if (save_results and not recording) {
				save ""+current_round+","+ dyke_length+","+evacuated+"," +casualties to:id_sim+"/evacuated_casualties.csv" rewrite: false format:"text";
			}
			current_round <- current_round +1;
			if (current_round > num_rounds) {
				do reset_game;
			} else {
				if (use_tell) {
	 				do tell("Start of Round " + current_round,false);
	 			}
			}
		}
		ask experiment {do compact_memory;}
	}
	
	action  enter_init_base {
		if (!recording and empty(people_positions)) {
			matrix<float> mf <- matrix(csv_file("people_positions.csv", ",",float));
			people_positions <- [];
			loop times: mf.rows / nb_of_people {
				people_positions << [];
			}
			loop line over: rows_list(mf) {
				people_positions[int(line[0])] << point(line[1],line[2]);
 			}
 			
 			matrix<int> ms <- matrix(csv_file("people_states.csv", ",",int));
			people_evacuated_casualties <- [];
			loop i from: 0 to: ms.rows -1{
				people_evacuated_casualties << ms row_at i;
			}
			
			river_geometries <- shape_file("river_geometries.shp").contents;
			//write "steps " + length(people_positions);
			//write "size of pop " + length(people_positions[0]);
		}

		current_step <- 0;
	}
	/*************************************************************
	 * Built-in parameters to control the simulations
	 *************************************************************/
	
	//Step of the simulation
	float step <- 30#mn;
	
	// Current date is fixed to #now
	date current_date <- #now;
	
	/*************************************************************
	 * Flags to control some functions in the simulations
	 *************************************************************/

	// Do we need to recompute the road graph ? 
	bool need_to_recompute_graph <- false;
	
	// Do we keep the previous dykes from one simulation to the other ? 
	bool keep_dykes;

	/*************************************************************
	 * Global monitoring variables
	 *************************************************************/
	 
	// Number of casualties (drowned people)
	int casualties <- 0;
	
	// Number of evacuated people
	int evacuated <- 0;

	/*************************************************************
	 * Initial parameters for people, water and obstacles
	 *************************************************************/

	// Initial number of people
	int nb_of_people <- 500;
	
	// The average speed of people
	float speed_of_people <- 20 #m / #h;
	
	// The maximum water input
	float max_water_input <- 0.5;

	
	// The height of water in the river at the beginning
	float initial_water_height <- 3.0;
	
	//Diffusion rate
	float diffusion_rate <- 0.5;
	
	//Height of the dykes (30 m by default)
	float dyke_height <- 30.0;
	
	//Width of the dyke (15 m by default)
	float dyke_width <- 15.0;
	
	float dyke_length_max <- 10000.0;
	
	float dyke_length <- 0.0;
	/*************************************************************
	 * Road network
	 *************************************************************/
	
	// Road network w/o the drowned roads
	graph<geometry, geometry> road_network;
	
	// Weights associated with the road network
	map<road, float> road_weights;
	
	bool is_ok_dyke_construction <- false;
	
	/*************************************************************
	 * GIS input data
	 *************************************************************/

	//Shapefile for the river
	file river_shapefile <- file("../../includes/gis/river.shp");
	
	//Shapefile for the buildings
	file buildings_shapefile <- file("../../includes/gis/buildings.shp");
	
	//Shapefile for the evacuation points
	file shape_file_evacuation <- file("../../includes/gis/evacuation_point.shp");
	
	//Shapefile for the roads
	file shape_file_roads <- file("../../includes/gis/road.shp");
	
	//Data elevation file : small, medium and large definition files are availables
	file dem_file <- file("../../includes/dem/terrain_small.tif");
	
	//Shape of the environment using the bounding box of Quang Binh
	geometry shape <- envelope(file("../../includes/gis/QBBB.shp"));
	
	/*************************************************************
	 * Lists of the water cells used to schedule them 
	 *************************************************************/

	//List of the drain cells ("end" of the river)
	list<cell> drain_cells;
	
	//List of the initial river cells ("bed" of the river)
	list<cell> bed_cells;
	 
	/*************************************************************
	 * Initialization and reinitialization behaviors
	 *************************************************************/

	init {
		if (use_tell) {
	 		do tell("Start the game: Round 1"  ,false);
	 	}
		do initialize_agents;
	}
	
	action restart {
		casualties <- 0;
		evacuated <- 0;
		ask dyke {
			do die;
		}
		dyke_length <- 0.0;
		ask cell {
			do initialize();
		}
		ask road+buildings+(keep_dykes ? dyke : []) {
			drowned <- false;
			do build();
		}
		ask people+(!keep_dykes ? dyke: []) {
			do die;
		}
		do initialize_agents;
		
	}
	
	action initialize_agents {
		//Initialization of the river and the corresponding cells
		do init_river;
		//Initialization of the obstacles (buildings, roads, etc.)
		do init_buildings;
		do init_roads;
		do init_evac;
		//Initialization of the people	
		do init_people;
	}
	
	action init_people {
		create people number: nb_of_people {
			location <- init_loc != nil ?init_loc : any_location_in(one_of(buildings));
		}
	}

	action init_roads {
		if (empty(road)) {create road from: clean_network(shape_file_roads.contents, 0.0, false, true);}
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
	}
	
	action init_evac {
		if (empty(evacuation_point)) {create evacuation_point from: shape_file_evacuation;}
	}
	
	/*
	 * Initializes the water cells according to the river shape file and the drain
	 */
	action init_river {
		if (empty(river)){ 
			create river from:(river_shapefile);
			ask cell overlapping river[0] {
				bed_cells << self;
				if (grid_y = 0) {drain_cells << self;}
			}
		}
		ask bed_cells {water_height <- initial_water_height;}
		ask river {do compute_shape;}
	}
	
	/*
	 * Initializes the buildings */
	action init_buildings {
		if (empty(buildings)) {
			create buildings from: buildings_shapefile;
		}
	}
	
	/*************************************************************
	 * Waterflow dynamics, directly managed by the world in the 
	 * s_flooding state
	 *************************************************************/
	
	/**
	 * Action to add water to the river cells
	 */
	action add_water {
		ask bed_cells {
			water_height <- water_height + max_water_input * rnd(100) / 100;
		}
	}

	/**
	 * Action to flow the water according to the altitute and the obstacle
	 */
	action flow_water {
		ask cell sort_by ((each.altitude + each.water_height + each.obstacle_height)) {
			already <- false;
			do flow;
		}
	}

	/**
	 * Action for recomputing the road graph if a road has been invalitated
	 */
	action recompute_road_graph {
		if (!need_to_recompute_graph) {return;}
		road_weights <- road as_map (each::each.shape.perimeter * (each.drowned ? 3.0 : 1.0));
		road_network <- as_edge_graph(road where not each.drowned);
		need_to_recompute_graph <- false;
	}
	
	action check_obstactles_drowning {
		ask buildings+road+dyke {
			if (!drowned) {do check_drowning;}
		}
	}

	/**
	 * Action for the drain cells to drain water
	 */
	action drain_water {
		ask drain_cells {
			water_height <- 0.0;
		}

	}

}
/*************************************************************
* Obstacles represent the attributes and behaviors common to 
* buildings, roads and dikes. 
*************************************************************/	
species obstacle {
	// Is the obstacle under water ? 
	bool drowned <- false;
	//The height of the obstacle
	float height min: 0.0;
	//The color of the obstacle
	rgb color <- #gray;
	//The list of cells overlapped by this obstacle
	list<cell> cells_under <- (cell overlapping self);
	
	/**
	 * Initializes the height of the obstacle and that of its cells
	*/
	init {
		do compute_height();
		do build();
	}

	/**
	 * When an obstacle breaks (or is drowned), it tells the 
	 * cells under to recompute their height.
	*/
	action break {
		ask cells_under {
			do update_after_destruction(myself);
		}
	}
	
	/**
	 * When an obstacle is built, it tells the 
	 * cells under to recompute their height.
	*/
	action build {
		ask cells_under {
			do update_after_construction(myself);
		}
	}

	
	action check_drowning {
		drowned <- (cells_under first_with (each.water_height > height)) != nil;
		if (drowned) {
			do break();
		}
	}

	action compute_height virtual: true;


}

/*************************************************************
* Buildings are obstacles that can host people
*************************************************************/	

species buildings parent: obstacle schedules: []{
	//The height of the building is randomly chosed between 5 and 15 meters
	action compute_height {
		height <- 5.0 + rnd(10.0) ;
	}
}

/*************************************************************
* Dykes are obstacles that are created dynamically by the user
*************************************************************/	
species dyke parent: obstacle schedules: []{
	float length;
	init {
		shape <- shape + 20;
	}
	
	//The height of the dyke is dyke_height minus the average height of the cells it overlaps
	action compute_height {
		height <- dyke_height - mean(cells_under collect (each.altitude));
	}
	
	//Allows a user to destroy the dyke by ctrl-clicking on it
	user_command "Destroy" {
		do break;
		drowned <- true;
	}
}


/*************************************************************
* A road allows people to evacuate. Breaking a road makes 
* the graph to be recomputed
*************************************************************/	
species road parent: obstacle schedules: [] {
	
	action compute_height {
		height <- 0.5;
	}
	
	action build {
		
	}
	
	action break {
		need_to_recompute_graph <- true;
	}
}





/*************************************************************
* Cells are the support of water flowing. To save memory (and 
* speed) they are not scheduled but managed by the world directly
*************************************************************/	
grid cell 	file: dem_file 
			neighbors: 4 
			frequency: 0 
			use_regular_agents: false 
			use_individual_shapes: false 
			use_neighbors_cache: true 
			schedules: [] {
	
	geometry shape_union <- shape + 0.1;
	//Altitude of the cell as read from the DEM
	float altitude <- grid_value const: true;
	//Height of the water in the cell
	float water_height min: 0.0;
	//Height of the cell (dynamic addition of its altitude, obstacle_height and water_height)
	float height;
	//List of all the obstacles overlapping the cell
	list<obstacle> obstacles;
	//Height of the obstacles
	float obstacle_height;
	//Has the cell been already processed during the current step ? 
	bool already;

	action initialize {
		water_height <- 0.0;
		height <- 0.0;
		already <- false;
		obstacle_height <- 0.0;
		obstacles <- [];
	}
	
	/**
	 * The main algorithmic part of water flowing
	 */ 
	action flow {
	//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if (water_height > 0) {
		//We get all the cells already done
			list<cell> neighbour_cells_al <- neighbors where (each.already);
			//If there are cells already done then we continue
			if (!empty(neighbour_cells_al)) {
			//We compute the height of the neighbours cells according to their altitude, water_height and obstacle_height
				ask neighbour_cells_al {
					height <- altitude + water_height + obstacle_height;
				}
				//The height of the cell is equal to its altitude and water height
				height <- altitude + water_height;
				//The water of the cells will flow to the neighbour cells which have a height less than the height of the actual cell
				list<cell> flow_cells <- (neighbour_cells_al where (height > each.height));
				//If there are cells, we compute the water flowing
				if (!empty(flow_cells)) {
					loop flow_cell over: shuffle(flow_cells) sort_by (each.height) {
						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * diffusion_rate])]);
						water_height <- water_height - water_flowing;
						flow_cell.water_height <- flow_cell.water_height + water_flowing;
						height <- altitude + water_height;
					}

				}

			}

		}
		already <- true;
	}

	
	//action to recompute the height after the destruction of the obstacle
	action update_after_destruction (obstacle the_obstacle) {
		obstacles >>  the_obstacle; 
		if (empty(obstacles)) {
			obstacle_height <- 0.0; 
		} else if (the_obstacle.height >= obstacle_height) {
			obstacle_height <- obstacles max_of (each.height);
		}
	}

	//action to recompute the height after the construction of the obstacle
	action update_after_construction(obstacle the_obstacle) {
		obstacles << the_obstacle;
		water_height <- 0.0;
		if (the_obstacle.height > obstacle_height) {obstacle_height <- the_obstacle.height;}
	}
}

/*************************************************************
* The river's only purpose is to create a shape that gathers 
* the @code{cell}s covered by water
*************************************************************/	

species river {

	reflex {
		if (state != "s_init") {do compute_shape();}
	}

	action compute_shape {
		shape <- /*without_holes*/(union((cell where (each.water_height > 0)) collect each.shape_union) simplification 30) ;
	}
}

/*************************************************************
* People are moving agents that can be in different states 
* (idle, fleeing, drowned, evacuated). When evacuating, they 
* try to move to the closest @code{evacuation_point}
*************************************************************/	

species people skills: [moving] control: fsm { 
	
	float speed <- speed_of_people;
	
	point init_loc <- nil;
	int evacuation_time <- -1;

	state s_idle initial: true {
		transition to: s_fleeing when: world.state = "s_flooding" and ((evacuation_time > -1) ? evacuation_time = current_step :flip(0.2));
		transition to: s_drowned when: self.is_drowning();
	}
	
	state s_fleeing {
		enter {
			path my_path <- nil;
			point target;
			using (topology(road_network)) {
				evacuation_point ep <- (evacuation_point closest_to self);
				if (ep != nil) {target <- ep.location;}
			}
			if (target != nil) {my_path <- road_network path_between (location, target);}
		}
		if my_path != nil {do follow(path: my_path, move_weights: road_weights); }
		transition to: s_evacuated when: location = target;
		transition to: s_drowned when: self.is_drowning();
		transition to: s_fleeing when: my_path = nil;
	}
	
	state s_evacuated final: true {
		enter{evacuated <- evacuated+1;}
		//do die;
	}
	
	state s_drowned final: true {
		enter {casualties <- casualties + 1;}
		//do die;
	}

	bool is_drowning {
		cell a_cell <- cell(location);
		return (a_cell != nil and a_cell.water_height > 0.2 and flip(0.5));
	}
}
	
/*************************************************************
* Evacuations points are simple landmarks read from a GIS file.
* No behaviour is attached to these agents
*************************************************************/	
species evacuation_point schedules: [];




