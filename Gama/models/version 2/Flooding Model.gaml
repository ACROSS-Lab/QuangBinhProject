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
		
 	bool save_results <- false;
 	
 	int num_step <- 350;
 	int num_step_add <- num_step - 50;
 	
 	float diking_duration <- 120.0;
	
	int num_rounds <- 3;
	
	int current_round <- 1;
	
	float simplification_river_dist <- 30.0;
	
	bool use_tell <- true;
	
	
	float waiting_time_in_s <- 1.5;
	
	geometry init_river;
	
	float score min: 0.0;
	
	float init_score <- 1000.0;	
	float casualties_impact <- 5.0;
	float border_impact <- 0.1;
	float price_meter_dyke <- 0.01;
	float price_meter_dam <- 0.1;
	
	float best_score <- 0.0;
	
	/*************************************************************
	 * Attributes dedicated to the UI (images, colors, frames, etc.)
	 *************************************************************/
	
	rgb background_color <- #dimgray;
	rgb frame_color <- rgb(1, 95, 115);
	rgb river_color <- rgb(74, 169, 163);
	rgb people_color <-rgb(232, 215, 164);
	rgb people_drowned_color <- rgb(255, 0, 0);
	rgb people_evacuated_color <- rgb(0, 255, 0);
	rgb evacuation_color <- rgb(100, 200, 100);
	
	rgb road_color <- rgb(64, 64, 64);
	rgb line_color <- rgb(156, 34, 39);
	rgb dyke_color <- rgb(200, 200, 200);
	rgb dam_color <- rgb(140, 0, 255);
	rgb text_color <- rgb(232, 215, 164);
	list<rgb> building_colors <- [rgb(214, 168, 0),rgb(237, 155, 0),rgb(202, 103, 2),rgb(120, 167, 121)];
	
	geometry background <- rectangle(1700, 1400);
	point text_position <- {-3000, 600};
	point background_position <- text_position - {200, 200};
	point icon_position <- {-2850, 1600};
	point check_position <- {-2850, 1700};
	point check_text_position <- {-2600, 1900};
	
	bool river_in_3D <- false; 
	geometry button_frame;  
	geometry check_frame;
	image button_image_unselected;
	image button_image_selected;
	image check_image_unselected;
	image check_image_selected; 
	bool button_selected;
	bool check_selected;
	
	
	geometry main_river_part;
	
	float cycle_duration <- 0.01;
	
	list<geometry> water_limit_drain;
	list<geometry> water_limit_well;
	list<geometry> water_limit_danger;
	
	
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
	int nb_of_people <- 1000;
	
	// The average speed of people
	float speed_of_people <- 20 #m / #h;
	
	// The maximum water input
	float max_water_input <- 0.4 const: true;

	
	// The height of water in the river at the beginning
	float initial_water_height <- 2.0 const: true;
	
	//Diffusion rate
	float diffusion_rate <- 0.4 const: true;
	
	//Height of the dykes 
	float dyke_height <- 60.0 const: true;
	
	//Width of the dyke (15 m by default)
	float dyke_width <- 15.0 const: true;
	
	float dyke_length <- 0.0;
	float dam_length <- 0.0;
	
	
	float limit_drown <- 0.1 const: true;
	
	list<cell> cells_at_stake;
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
	file river_shapefile <- file("../../includes/gis/river_clean.shp");
	
	//if defined, used to create people agents
	shape_file people_shape_file <- shape_file("../../includes/gis/people.shp");

	//Shapefile for the buildings
	file buildings_shapefile <- file("../../includes/gis/buildings.shp");
	
	//Shapefile for the evacuation points
	file shape_file_evacuation <- file("../../includes/gis/evacuation_point.shp");
	
	//Shapefile for the roads
	file shape_file_roads <- file("../../includes/gis/road.shp");
	
	//Data elevation file : small, medium and large definition files are availables
	//file dem_file <- file("../../includes/dem/dem_small.tif");
	file dem_file <- file("../../includes/dem/terrain89x211.asc");
	
	
	shape_file drain_shape_file <- shape_file("../../includes/gis/drain.shp");

	//Shape of the environment using the bounding box of Quang Binh
	geometry shape <- envelope(file("../../includes/gis/QBBB.shp"));
	

	/*************************************************************
	 * Lists of the water cells used to schedule them 
	 *************************************************************/
	//List of the initial river cells ("bed" of the river)
	list<cell> bed_cells;
	 
	float total_water_to_add;
	
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
			score <- init_score;	
			ask cell {
				already <- false;
			}
			
			ask river {do die;}
		}
		do add_water();
		do flow_water();
		do check_obstactles_drowning();
		do recompute_road_graph();
		do body_init();
		do update_score;
		current_step <- current_step +1;
		exit {
			do exit_init();
			
			do restart;
		}
		transition to: s_diking when: init_over();
	}



	
	/**
	 * This state represents the state where the user(s) is(are) able to build dikes 
	 */
	state s_diking {
		enter {
			do enter_diking();
			
			do compute_river_shape;
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
			ask cell {
				already <- false;
			}
			
			ask river {do die;}
			
			do enter_flooding();
			score <- init_score;	
			
		}		
		do add_water();
		do flow_water();
		do check_obstactles_drowning();
		do recompute_road_graph();
		//do drain_water();
		do body_flooding();
		do update_score;
		current_step <- current_step +1;
		exit {
			best_score <- max(best_score, score);
			do exit_flooding();
		}
		transition to: s_start when: (current_round >= num_rounds) and  flooding_over() {
			do restart();
		}
		transition to: s_diking when: (current_round < num_rounds) and flooding_over() {
			do restart();
		}
		 
	}
	action update_score {
		float dyke_price <- dyke sum_of (each.length * (each.is_dam ? price_meter_dam : price_meter_dyke));	
		float impact_border <- (cells_at_stake where (each.water_height > limit_drown)) sum_of (each.water_height *border_impact); 
		score <- init_score - casualties_impact * casualties - dyke_price - impact_border;
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
		
	int current_step;
	
		// The next timeout to occur for the different stages
	float current_timeout;
	
	bool create_dyke(point source, point target) {
		if (source distance_to target > 1.0)  {
			geometry l <- line([source, target]);
			l <- l inter world;
			if (l != nil) {
				if (l overlaps init_river) {
					geometry gI <- l inter init_river;
					geometry gD <- l - init_river;
					if gI != nil {
						loop ggI over: gI.geometries {
							create dyke with:(is_dam: true, shape:ggI);
						}
						if (gD != nil) {
							loop ggD over: gD.geometries {
								create dyke with:(shape:ggD);
							}
						}
					}
				} else {
					create dyke with:(shape:l);
					return true;
				}	
			} else {
				return false;
			}
		}
		return false;
	}
		
	
	// The maximum amount of time, in seconds, for building dikes 
		 
	 
	 action reset_game {
	 	if (save_results) {
	 		id_sim <- "Game_" + (#now).year +"_" + (#now).month+"_"+(#now).day+ "_"+(#now).hour+ "_"+(#now).minute;
	 		save "round,dyke_length,dam_length,evacuated,casualties" to:id_sim+"/evacuated_casualties.csv" rewrite: true format:"text";
		}
	 	current_round <- 1;
	 	if (use_tell) {
	 		do tell("Restart the new game",false);
	 	}
	 	do end_game_action;
	 }
	 
	 action end_game_action;
	
	action enter_flooding_base {
		if save_results {
			save dyke to:id_sim+"/dykes_" + current_round + ".shp"  format:"shp";
		}
	}
	action exit_flooding_base {
		if (save_results) {
			save ""+current_round+","+ dyke_length+ ","+ dam_length +","+evacuated+"," +casualties to:id_sim+"/evacuated_casualties.csv" rewrite: false format:"text";
		}
		current_round <- current_round +1;
		if (current_round > num_rounds) {
			do reset_game;
		} else {
			if (use_tell) {
	 			do tell("Start of Round " + current_round,false);
	 		}
		}
		ask experiment {do compact_memory;}
	}
	
	action  enter_init_base {
	
		current_step <- 0;
	}
	
	/*************************************************************
	 * Initialization and reinitialization behaviors
	 *************************************************************/

	init {
		init_river  <- first(river_shapefile.contents); 
		if (use_tell) {
	 		do tell("Start the game: Round 1"  ,false);
	 	}
		do initialize_agents;
		//save people format: "shp" to: "../../includes/gis/people.shp" attributes:["evacuation_time"];
		/*
		ask cell_simple {
			list<cell> cs <- cell overlapping self;
			grid_value <- cs mean_of (each.grid_value);
		}
		save cell_simple to: "dem_low_resolution.tif" format:"geotiff"; */
	}
	
	action restart {
		casualties <- 0;
		evacuated <- 0;
		ask dyke {
			do die;
		}
		dyke_length <- 0.0;
		dam_length <- 0.0;
		
		
		current_step <- 0; 
		ask river {do die;}
			
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
		//do compute_river_shape;
		main_river_part <- init_river;
		
		
	}
	
	action initialize_agents {
		//Initialization of the river and the corresponding cells
		do init_river_computation;
		//Initialization of the obstacles (buildings, roads, etc.)
		do init_buildings;
		do init_roads;
		do init_evac;
		//Initialization of the people	
		do init_people;
	}
	
	action init_people {

		if (people_shape_file != nil) {
			create people from: people_shape_file with:(evacuation_time:int(get("evacuation")));
			
		} else {
			create people number: nb_of_people {
				location <- init_loc != nil ?init_loc : any_location_in(one_of(buildings));
			}
		}
		
	
	}

	action init_roads {
		if (empty(road)) {create road from: clean_network(shape_file_roads.contents, 0.0, false, true);}
		road_network <- as_edge_graph(road) with_shortest_path_algorithm "NBAStar";
		road_weights <- road as_map (each::each.shape.perimeter);
	}
	
	action init_evac {
		if (empty(evacuation_point)) {create evacuation_point from: shape_file_evacuation;}
	}
	
	/*
	 * Initializes the water cells according to the river shape file and the drain
	 */
	action init_river_computation {
		int max_y <- (cell max_of each.grid_y);
		geometry border <- shape.contour;
		water_limit_well <- [];	
		geometry water_limit_d <- copy(border);
		water_limit_drain <- [];
		loop g over: drain_shape_file {
			water_limit_d  <- water_limit_d - g;
			int is_drain_ <- int(g.attributes["drain"]);
			if is_drain_ = 0 {
				water_limit_well <- water_limit_well  + (g inter border);
			} else {
				water_limit_drain <- water_limit_drain + (g inter border);
				ask cell overlapping g {
					is_drain <- length(neighbors) < 4;
				}
			}
		}
		water_limit_danger <- water_limit_d.geometries where (each.perimeter > 20);
		loop wl over: water_limit_danger {
			ask (cell overlapping wl) where (each.num_neigbors < 4) {
				is_stake <- true;
				cells_at_stake << self;
			}
		}		
		if (empty(river)){ 
			bed_cells <- [];
			create river from:(river_shapefile);
			ask cell overlapping river[0] {
				bed_cells << self;
			}
			
		}
		ask bed_cells {
			if (grid_y > (max_y - 200)) {
				water_to_add <- max(0.1,(grid_y / max_y));
			}
			
		}
		total_water_to_add <- bed_cells sum_of each.water_to_add;
		
		ask bed_cells where (each.obstacle_height = 0){water_height <- initial_water_height;}
		do compute_river_shape;
		
	}
	

	action compute_river_shape {
		list<cell> river_cells <- cell where (not each.already and (each.water_height > limit_drown)) ;
		list<list<cell>> clusters <- list<list<cell>>(simple_clustering_by_distance(river_cells, 1));
		loop c over: clusters {
			ask c {already <- true;}
       		create river with: (cells:c);
       		ask river parallel: true {
       			do generate_shape;
       		}
		}
		
		list<list<river>> clusters_r <- list<list<river>>(simple_clustering_by_distance(river, 0.0));
		 
		 
		  
		list<river> merging_rivers;
		loop cr over: clusters_r {
			if length(cr) > 1 {
				first(cr).to_merge <- cr;
				merging_rivers << first(cr);
			}
		}
		ask merging_rivers parallel: true  {
			do update_shape;
		}
		ask river parallel: true {
			shape_to_export <- shape simplification simplification_river_dist;
			shape_to_export.attributes["name"] <- name;
		}
		
		/*loop cr over: clusters_r {
			if length(cr) > 1 {
				first(cr).shape <- union(cr);
				ask cr - first(cr) {do die;}
			}
		}*/
		main_river_part <- river closest_to {world.location.x, world.shape.height};
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
		if (current_step <= num_step_add) {
			list<cell> to_adds <- bed_cells where ((each.obstacle_height = 0) and (each.location overlaps main_river_part));
			float coeff_to_add <- total_water_to_add / (to_adds sum_of each.water_to_add);
			ask to_adds parallel: true{
				water_height <- water_height + water_to_add * max_water_input  * coeff_to_add ;
			}
		}
		
	}
	/**
	 * Action to flow the water according to the altitute and the obstacle
	 */
	action flow_water {
		ask cell parallel: true{
			water_height_tmp <- water_height;
		}
		ask cell parallel: true{
			do flow;
		}
		ask cell parallel: true{
			water_height <- water_height_tmp;
		}
		do compute_river_shape;
		
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
		drowned <- (cells_under first_with (each.water_height > limit_drown)) != nil;
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
		height <- 10.0 ;
	}
}

/*************************************************************
* Dykes are obstacles that are created dynamically by the user
*************************************************************/	
species dyke parent: obstacle schedules: []{
	float length;
	bool is_dam <- false;
	init {
		length <- shape.perimeter;
		if (is_dam) {
			dam_length <- dam_length + length;
		} else {
			dyke_length <- dyke_length + length;
		}
		shape <- shape + 20;
		do compute_height();
		do build();
	}
	action check_drowning {
		loop c over: (cells_under where (each.water_height > limit_drown)) {
			cells_under >> c;
			if (shape != nil) {shape <- shape - (c  + 20.0);}
			c.obstacles >> self;
		}
		if (shape = nil or empty(cells_under)) {
			loop c over: cells_under {
				c.obstacles >> self;	
			}
			do die;
		}
		/*if (drowned) {
			do break();
		}*/
	}
	
	//The height of the dyke is dyke_height minus the average height of the cells it overlaps
	action compute_height {
		height <- dyke_height;// - mean(cells_under collect (each.altitude));
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
	
	float water_to_add;
	bool already <- false;
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
		
	bool is_drain <- false;
	bool is_stake <- false;
	
	int num_neigbors <- length(neighbors);
	float water_height_tmp;
	action initialize {
		water_height <- 0.0;
		water_height_tmp <- 0.0;
		height <- 0.0;
		obstacle_height <- 0.0;
		obstacles <- [];
		is_drain <- false;
		is_stake <- false;
		water_to_add <- 0.0;
	}
	
	/**
	 * The main algorithmic part of water flowing
	 */ 
	action flow {
	//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if ((num_neigbors = 4 or !is_drain) and water_height > 0 ) {
		//We get all the cells  
			list<cell> neighbour_cells_al <- neighbors ;
			
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
					list<float> v <- flow_cells collect (height - each.height);
					float sum_v <- sum(v);
					float water_flowing <- water_height * diffusion_rate;
					water_height_tmp <- water_height_tmp - water_flowing;
					
					/*loop flow_cell over: shuffle(flow_cells) sort_by (each.height) {
						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * diffusion_rate])]);
						water_height <- water_height - water_flowing;
						flow_cell.water_height <- flow_cell.water_height + water_flowing;
						//height <- altitude + water_height;
					}*/
					loop i from: 0 to: length(flow_cells) -1 {
						cell flow_cell <- flow_cells[i];
						flow_cell.water_height_tmp <- flow_cell.water_height_tmp + water_flowing * v[i]/sum_v;
					}

				}

			}

		} else {
			water_height_tmp <- water_height_tmp  - (water_height *  diffusion_rate);
		}
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
		already <- false;
		if (the_obstacle.height > obstacle_height) {obstacle_height <- the_obstacle.height;}
	}
	
	/*reflex color_up {
		float cv <- 255 * (1 - water_height/20.0);
		color <- rgb(cv,cv,255);
	}*/
}

/*************************************************************
* The river's only purpose is to create a shape that gathers 
* the @code{cell}s covered by water
*************************************************************/	

species river {
	list<cell> cells;
	list<river> to_merge;
	geometry shape_to_export;
	action generate_shape {
		shape <- union(cells collect each.shape_union);
		cells <- [];
	}
	action update_shape {
		shape <- union (to_merge) ;
		ask to_merge - self{
			do die;
		}
		to_merge <- [];
	}
	rgb color <-rnd_color(255);	
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
	
	init {
		if (evacuation_time = -1) {
			evacuation_time <- rnd(50);
		}
	}

	state s_idle initial: true {
		transition to: s_fleeing when: world.state in ["s_flooding", "s_init"] and (evacuation_time = current_step);
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
		return (a_cell != nil and a_cell.water_height > limit_drown);
	}
}
	
/*************************************************************
* Evacuations points are simple landmarks read from a GIS file.
* No behaviour is attached to these agents
*************************************************************/	
species evacuation_point schedules: [];




