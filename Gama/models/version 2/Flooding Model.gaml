/**
* Name: Flooding Model with SpreadingSkill
* Author: Alexis Drogoul + SpreadingSkill
* Description: This model integrates the advanced SpreadingSkill water simulation
* with the original people evacuation and scoring system. Uses FSM for behavioral
* architecture and provides advanced dyke building with rain system.
*/
@no_experiment
@no_info

model Flooding

global control: fsm skills: [spreading] {
	
		image button_image_unselected;
	image button_image_selected;
	image check_image_unselected;
	image check_image_selected; 
		
 	bool save_results <- false;
 	
 	int num_step <- 350;
 	int num_step_add <- num_step;
 	
 	float diking_duration <- 60.0;
 	
 	float max_distance_to_be_saved <- 50 #m;
	
	int num_rounds <- 3;
	
	int current_round <- 1;
	
	float simplification_river_dist <- 30.0;
	
	bool use_tell <- true;
	
	float waiting_time_in_s <- 1.5;
	
	geometry init_river;
	list<geometry> all_river_parts;
	
	float score min: 0.0;
	
	float init_score <- 1000.0;	
	float casualties_impact <- 5.0;
	float border_impact <- 0.1;
	float price_meter_dyke <- 0.01;
	float price_meter_dam <- 0.1;
	
	float best_score <- 0.0;
	
	/*************************************************************
	 * SpreadingSkill Integration Variables
	 *************************************************************/
	
	// Display fields for visualization (synchronized with SpreadingSkill)
	field display_water_field;
	field display_dyke_field;
	
	// Dyke building state
	bool dyke_building_active <- false;
	point dyke_point1 <- nil;
	point dyke_point2 <- nil;
	bool waiting_for_first_point <- false;
	bool waiting_for_second_point <- false;
	
	/*************************************************************
	 * UI Colors and Styling (preserved from original)
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
	
	float cycle_duration <- 0.01;
	
	list<geometry> water_limit_drain;
	list<geometry> water_limit_well;
	list<geometry> water_limit_danger;
	
	/*************************************************************
	 * Built-in parameters (preserved)
	 *************************************************************/
	
	float step <- 30#mn;
	date current_date <- #now;
	
	/*************************************************************
	 * Flags and monitoring (preserved)
	 *************************************************************/

	bool need_to_recompute_graph <- false;
	bool keep_dykes;

	int casualties <- 0;
	int evacuated <- 0;
	int people_counter <- 0;

	/*************************************************************
	 * SpreadingSkill Parameters (replacing old water parameters)
	 *************************************************************/

	int nb_of_people <- 1000;
	float speed_of_people <- 20 #m / #h;
	
	// SpreadingSkill will manage these internally:
	// - water input, diffusion, rising rate
	// - dyke height and behavior
	// - rain system
	
	float limit_drown <- 0.1 const: true;
	
	list<cell> cells_at_stake;
	
	/*************************************************************
	 * Road network (preserved)
	 ************************************************************/ 
	
	graph<geometry, geometry> road_network;
	map<road, float> road_weights;
	
	/*************************************************************
	 * GIS input data (preserved)
	 *************************************************************/

	file river_shapefile <- file("../../includes/gis/river_clean.shp");
	file buildings_shapefile <- file("../../includes/gis/landuse_multipolygon.shp");
	file shape_file_evacuation <- file("../../includes/gis/amenity_point.shp");
	file shape_file_roads <- file("../../includes/gis/highway_line.shp");
	file dem_file <- file("../../includes/dem/terrain_large.tif");
	shape_file drain_shape_file <- shape_file("../../includes/gis/drain.shp");

	field elevation_map <- field(dem_file);
	geometry shape <- envelope(dem_file);
	
	/*************************************************************
	 * FSM States (preserved structure, updated implementation)
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
				water_height <- 0.0; // Reset cell water heights
			}
		}
		
		// REPLACED: Use SpreadingSkill instead of old water flow
		do spreading_simulation_step();
		do check_obstacles_drowning();
		do recompute_road_graph();
		do body_init();
		do update_score();
		current_step <- current_step + 1;
		
		exit {
			do exit_init();
			do restart();
		}
		transition to: s_diking when: init_over();
	}

	/**
	 * Dyke building state - now uses SpreadingSkill dyke system
	 */
	state s_diking {
		enter {
			do enter_diking();
			// Enable dyke building mode in SpreadingSkill
			do toggle_dyke_building_mode();
			dyke_building_active <- is_dyke_building_mode();
		}
		
		do body_diking();
		
		exit {
			do exit_diking();
			// Disable dyke building mode
			if (dyke_building_active) {
				do toggle_dyke_building_mode();
				dyke_building_active <- false;
			}
		}
		transition to: wait_flooding when: diking_over();
	}
	
	state wait_flooding {
		transition to: s_flooding when: flooding_ready();
	}
	
	/**
	 * Flooding state - now uses SpreadingSkill simulation
	 */
	state s_flooding {
		enter {
			ask cell {
				water_height <- 0.0; // Reset for sync
			}
			
			do enter_flooding();
			score <- init_score;
			people_counter <- 0;	
			
			// Start SpreadingSkill simulation
			do start_spreading_simulation();
		}		
		
		// REPLACED: Use SpreadingSkill instead of old water flow
		do spreading_simulation_step();
		do check_obstacles_drowning();
		do recompute_road_graph();
		do body_flooding();
		do update_score();
		current_step <- current_step + 1;
		
		exit {
			best_score <- max(best_score, score);
			do exit_flooding();
			// Stop SpreadingSkill simulation
			do stop_spreading_simulation();
		}
		transition to: s_start when: (current_round >= num_rounds) and flooding_over() {
			do restart();
		}
		transition to: s_diking when: (current_round < num_rounds) and flooding_over() {
			do restart();
		}
	}
	
	/*************************************************************
	 * NEW: SpreadingSkill Integration Actions
	 *************************************************************/
	
	/**
	 * Replaces the old add_water + flow_water + compute_river_shape sequence
	 */
	action spreading_simulation_step {
		// Execute SpreadingSkill simulation step
		if (is_simulation_active()) {
			do simulate_spreading_step();
		}
		
		// Sync water levels with cell grid for people navigation
		do sync_water_levels_to_cells();
		
		// Update display fields
		if (water_field != nil) {
			display_water_field <- water_field;
		}
		if (dyke_field != nil) {
			display_dyke_field <- dyke_field;
		}
	}
	
	/**
	 * Synchronizes SpreadingSkill water levels with cell grid for people navigation
	 */
	action sync_water_levels_to_cells {
		if (water_field != nil) {
			ask cell parallel: true {
				// Get water level from SpreadingSkill's field
				float water_level <- display_water_field[location];
				water_height <- water_level > 0.01 ? water_level : 0.0;
			}
		}
	}
	
	/**
	 * Dyke building click handler - integrates with SpreadingSkill
	 */
	action handle_dyke_click(point click_location) {
		if (dyke_building_active) {
			if (waiting_for_first_point) {
				dyke_point1 <- click_location;
				waiting_for_first_point <- false;
				waiting_for_second_point <- true;
				write "✓ First dyke point selected: " + dyke_point1;
				write "   → Click second point to complete dyke";
			} else if (waiting_for_second_point) {
				dyke_point2 <- click_location;
				waiting_for_second_point <- false;
				write "✓ Second dyke point selected: " + dyke_point2;
				write "   → Building dyke...";

				// Build dyke using SpreadingSkill
				bool success <- build_dyke(dyke_point1, dyke_point2);
				if (success) {
					write "🏗️ Dyke built successfully!";
					write "   Active dykes: " + get_active_dyke_count();
				} else {
					write "❌ Failed to build dyke";
				}

				// Reset for next dyke
				waiting_for_first_point <- true;
				dyke_point1 <- nil;
				dyke_point2 <- nil;
				write "   → Ready for next dyke (click first point)";
			}
		} else {
			// Show information at click location
			if (display_water_field != nil) {
				float water_level <- display_water_field[click_location];
				if (water_level > 0.01) {
					write "💧 Water level: " + (water_level with_precision 2) + "m";
				} else {
					write "🏞️ No water at this location";
				}
			}
			write "📍 Click coordinates: " + click_location;
		}
	}
	
	/*************************************************************
	 * Rain Control Actions (NEW)
	 *************************************************************/
	
	action start_light_rain {
		do start_rain(0.1, 1.0);
		write "🌧️ Light rain started";
	}
	
	action start_heavy_rain {
		do start_rain(0.3, 1.5);
		write "⛈️ Heavy rain started";
	}
	
	action stop_rain_completely {
		do stop_rain();
		write "☀️ Rain stopped";
	}
	
	/*************************************************************
	 * Dyke Control Actions (NEW)
	 *************************************************************/
	
	action toggle_dyke_building {
		do toggle_dyke_building_mode();
		dyke_building_active <- is_dyke_building_mode();
		if (dyke_building_active) {
			write "🔨 DYKE BUILDING MODE ACTIVATED";
			write "   → Click first point in the display";
			waiting_for_first_point <- true;
			waiting_for_second_point <- false;
		} else {
			write "🔨 DYKE BUILDING MODE DEACTIVATED";
			waiting_for_first_point <- false;
			waiting_for_second_point <- false;
		}
	}
	
	action clear_all_dykes_action {
		int dyke_count <- get_active_dyke_count();
		do clear_all_dykes();
		write "💥 All dykes cleared (" + dyke_count + " dyke cells removed)";
	}
	
	/*************************************************************
	 * Score Update (preserved, modified for SpreadingSkill)
	 *************************************************************/
	action update_score {
		// Calculate dyke costs using SpreadingSkill data
		float dyke_price <- get_active_dyke_count() * price_meter_dyke * 15.0; // Approximate cost
		float impact_border <- (cells_at_stake where (each.water_height > limit_drown)) sum_of (each.water_height * border_impact); 
		score <- init_score - casualties_impact * casualties - dyke_price - impact_border;
	}

	/*************************************************************
	 * Virtual functions (preserved)
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
	float current_timeout;
	
	/*************************************************************
	 * Game Management (preserved)
	 *************************************************************/
	 
	 action reset_game {
	 	if (save_results) {
	 		id_sim <- "Game_" + (#now).year +"_" + (#now).month+"_"+(#now).day+ "_"+(#now).hour+ "_"+(#now).minute;
	 		save "round,dyke_length,dam_length,evacuated,casualties" to:id_sim+"/evacuated_casualties.csv" rewrite: true format:"text";
		}
	 	current_round <- 1;
	 	if (use_tell) {
	 		do tell("Restart the new game",false);
	 	}
	 	do end_game_action();
	 }
	 
	 action end_game_action;

	action enter_flooding_base {
		if save_results {
			// Note: Dyke saving would need to be adapted for SpreadingSkill
			write "Saving dykes (SpreadingSkill format) for round " + current_round;
		}
	}
	
	action exit_flooding_base {
		if (save_results) {
			float dyke_length_est <- get_active_dyke_count() * 15.0; // Estimate
			save ""+current_round+","+ dyke_length_est+ ",0,"+evacuated+"," +casualties to:id_sim+"/evacuated_casualties.csv" rewrite: false format:"text";
		}
		current_round <- current_round + 1;
		if (current_round > num_rounds) {
			do reset_game();
		} else {
			if (use_tell) {
	 			do tell("Start of Round " + current_round,false);
	 		}
		}
		ask experiment {do compact_memory();}
	}
	
	action enter_init_base {
		current_step <- 0;
	}
	
	/*************************************************************
	 * Initialization (modified for SpreadingSkill)
	 *************************************************************/

	init {
		// Store river geometries
		all_river_parts <- river_shapefile.contents;
		init_river <- union(all_river_parts);
		
		if (use_tell) {
	 		do tell("Start the game: Round 1 (SpreadingSkill enabled)", false);
	 	}
	 	
		// Initialize agents (preserved)
		do initialize_agents();
		
		// Initialize SpreadingSkill
		do initialize_spreading_system();
	}
	
	/**
	 * NEW: Initialize SpreadingSkill with DEM and water data
	 */
	action initialize_spreading_system {
		write "=== INITIALIZING SPREADINGSKILL SYSTEM ===";
		
		// Create elevation field from DEM
		
		
		// Create dyke field with same dimensions as DEM
		field dyke_field_for_init <- field(elevation_map.columns, elevation_map.rows);
		loop i from: 0 to: elevation_map.columns - 1 {
			loop j from: 0 to: elevation_map.rows - 1 {
				dyke_field_for_init[i, j] <- 0.0;
			}
		}
		
		// Initialize SpreadingSkill with coordinate-aligned fields
		do initialize_spreading_grid_with_dyke_field(
			dem_field: elevation_map, 
			dyke_field: dyke_field_for_init,
			water_geometries: all_river_parts, 
			initial_water_depth: 1.5, 
			flow_threshold: 0.01, 
			rising_rate: 0.3, 
			min_flow_diff: 0.001, 
			equalization_threshold: 0.1
		);
		
		// Initialize display fields
		display_water_field <- water_field;
		display_dyke_field <- dyke_field;
		
		write "✓ SpreadingSkill system initialized successfully";
		write "✓ Grid dimensions: " + grid_width + "x" + grid_height;
		write "✓ Initial water cells: " + get_active_water_count();
		write "============================================";
	}
	
	action restart {
		casualties <- 0;
		evacuated <- 0;
		current_step <- 0; 
		
		// Reset SpreadingSkill simulation
		do reset_spreading_simulation(all_river_parts, 1.5);
		
		ask cell {
			water_height <- 0.0;
		}
		ask road+buildings {
			drowned <- false;
			do build();
		}
		ask people {
			do die();
		}
		do initialize_agents();
	}
	
	action initialize_agents {
		do init_buildings();
		do init_roads();
		do init_evac();
		do init_people();
		do init_drainage_system();
	}
	
	action init_people {
		create people number: nb_of_people {
			location <- init_loc != nil ? init_loc : any_location_in(one_of(buildings));
		}
	}

	action init_roads {
		if (empty(road)) {create road from: clean_network(list<geometry>(shape_file_roads.contents), 0.0, false, true);}
		road_network <- as_edge_graph(road) with_shortest_path_algorithm "NBAStar";
		road_weights <- road as_map (each::each.shape.perimeter);
	}
	
	action init_evac {
		if (empty(evacuation_point)) {create evacuation_point from: shape_file_evacuation;}
	}
	
	action init_buildings {
		if (empty(buildings)) {
			create buildings from: buildings_shapefile;
		}
	}
	
	/**
	 * Initialize drainage system (preserved from original)
	 */
	action init_drainage_system {
		int max_y <- (cell max_of each.grid_y);
		geometry border <- shape.contour;
		water_limit_well <- [];	
		geometry water_limit_d <- copy(border);
		water_limit_drain <- [];
		
		loop g over: drain_shape_file {
			water_limit_d <- water_limit_d - g;
			int is_drain_ <- int(g.attributes["drain"]);
			if is_drain_ = 0 {
				water_limit_well <- water_limit_well + (g inter border);
			} else {
				water_limit_drain <- water_limit_drain + (g inter border);
			}
		}
		
		water_limit_danger <- water_limit_d.geometries where (each.perimeter > 20);
		loop wl over: water_limit_danger {
			ask (cell overlapping wl) where (each.num_neigbors < 4) {
				is_stake <- true;
				cells_at_stake << self;
			}
		}	
	}

	/**
	 * Check obstacle drowning (preserved logic, updated for SpreadingSkill)
	 */
	action check_obstacles_drowning {
		ask buildings+road {
			if (!drowned) {do check_drowning();}
		}
	}

	/**
	 * Recompute road graph (preserved)
	 */
	action recompute_road_graph {
		if (!need_to_recompute_graph) {return;}
		road_weights <- road as_map (each::each.shape.perimeter * (each.drowned ? 3.0 : 1.0));
		road_network <- as_edge_graph(road where not each.drowned);
		need_to_recompute_graph <- false;
	}
}

/*************************************************************
* Obstacles (simplified - dykes now handled by SpreadingSkill)
*************************************************************/	
species obstacle {
	bool drowned <- false;
	float height <- 10.0;
	rgb color <- #gray;
	list<cell> cells_under <- (cell overlapping self);
	
	init {
		do compute_height();
		do build();
	}

	action break {
		ask cells_under {
			do update_after_destruction(myself);
		}
	}
	
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
* Buildings (preserved)
*************************************************************/	
species buildings parent: obstacle schedules: []{

	action compute_height {
		height <- 10.0;
	}
}

/*************************************************************
* Roads (preserved)
*************************************************************/	
species road parent: obstacle schedules: [] {
	action compute_height {
		height <- 0.5;
	}
	
	action build {}
	
	action break {
		need_to_recompute_graph <- true;
	}
}

/*************************************************************
* Cell grid (simplified - SpreadingSkill handles water flow)
*************************************************************/	
grid cell 	file: dem_file 
			neighbors: 4 
			frequency: 0 
			use_regular_agents: false 
			use_individual_shapes: false 
			use_neighbors_cache: true  
			schedules: [] {
	
	// Simplified - just for people navigation and obstacle management
	float altitude <- grid_value const: true;
	float water_height min: 0.0; // Synced from SpreadingSkill
	float height;
	list<obstacle> obstacles;
	float obstacle_height;
		
	bool is_drain <- false;
	bool is_stake <- false;
	int num_neigbors <- length(neighbors);
	
	action initialize {
		water_height <- 0.0;
		height <- 0.0;
		obstacle_height <- 0.0;
		obstacles <- [];
		is_drain <- false;
		is_stake <- false;
	}
	
	// Water flow logic removed - handled by SpreadingSkill
	
	action update_after_destruction (obstacle the_obstacle) {
		obstacles >> the_obstacle; 
		if (empty(obstacles)) {
			obstacle_height <- 0.0; 
		} else if (the_obstacle.height >= obstacle_height) {
			obstacle_height <- obstacles max_of (each.height);
		}
	}

	action update_after_construction(obstacle the_obstacle) {
		obstacles << the_obstacle;
		if (the_obstacle.height > obstacle_height) {obstacle_height <- the_obstacle.height;}
	}
}

/*************************************************************
* People (preserved - works with synced water levels)
*************************************************************/	
species people skills: [moving] control: fsm { 
	
	float speed <- speed_of_people;
	point init_loc <- nil;
	int evacuation_time <- -1;
	
	init {
		if (evacuation_time = -1) {
			evacuation_time <- rnd(50);
		}
		name <- "person" + people_counter;
		people_counter <- people_counter + 1;
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
		if my_path != nil {do follow(path: my_path, move_weights: road_weights);}
		transition to: s_evacuated when: target != nil and location distance_to target < max_distance_to_be_saved;
		transition to: s_drowned when: self.is_drowning();
		transition to: s_fleeing when: my_path = nil;
	}
	
	state s_evacuated final: true {
		enter{evacuated <- evacuated+1;}
	}
	
	state s_drowned final: true {
		enter {casualties <- casualties + 1;}
	}

	bool is_drowning {
		cell a_cell <- cell(location);
		return (a_cell != nil and a_cell.water_height > limit_drown);
	}
}
	
/*************************************************************
* Evacuation points (preserved)
*************************************************************/	
species evacuation_point schedules: [];