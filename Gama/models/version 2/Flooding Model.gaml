/**
* Name: Flooding Model with SpreadingSkill - VR Compatible
* Author: Alexis Drogoul + SpreadingSkill + Backward Compatibility
* Description: This model integrates the advanced SpreadingSkill water simulation
* with the original people evacuation and scoring system, while maintaining
* full backward compatibility with the VR model and original species.
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
 	
 	int num_step <- 7;
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
	
	// Compatibility mode toggle
	bool use_spreading_skill <- true; // Set to false to use original water system
	
	/*************************************************************
	 * BACKWARD COMPATIBILITY: Original water variables
	 *************************************************************/
	
	geometry main_river_part;
	float max_water_input <- 0.4 const: true;
	float initial_water_height <- 2.0 const: true;
	float diffusion_rate <- 0.4 const: true;
	float dyke_height <- 60.0 const: true;
	float dyke_width <- 15.0 const: true;
	float dyke_length <- 0.0;
	float dam_length <- 0.0;
	float limit_drown <- 0.1 const: true;
	list<cell> bed_cells;
	float total_water_to_add;
	
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
	point icon_position <- {-2850, 1600};
	point check_position <- {-2850, 1700};
	point check_text_position <- {-2600, 1900};
	
	bool river_in_3D <- false; 
	geometry button_frame;  
	geometry check_frame;
	bool button_selected;
	bool check_selected;
	
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
	 * SpreadingSkill Parameters
	 *************************************************************/

	int nb_of_people <- 1000;
	float speed_of_people <- 20 #m / #h;
	
	list<cell> cells_at_stake;
	bool is_ok_dyke_construction <- false;
	
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
	 * FSM States (backward compatible implementation)
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
			people_counter <- 0;
		}
		
		// Adaptive water simulation
		if (use_spreading_skill) {
			do spreading_simulation_step();
		} else {
			do add_water();
			do flow_water();
			do check_obstactles_drowning();
		}
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
	 * Dyke building state - supports both systems
	 */
	state s_diking {
		enter {
			do enter_diking();
			
			if (use_spreading_skill) {
				do toggle_dyke_building_mode();
				dyke_building_active <- is_dyke_building_mode();
			} else {
				do compute_river_shape();
			}
		}
		
		do body_diking();
		
		exit {
			do exit_diking();
			if (use_spreading_skill and dyke_building_active) {
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
	 * Flooding state - supports both systems
	 */
	state s_flooding {
		enter {
			ask cell {
				already <- false;
			}
			
			ask river {do die;}
			
			do enter_flooding();
			score <- init_score;
			people_counter <- 0;	
			
			if (use_spreading_skill) {
				do start_spreading_simulation();
			}
		}		
		
		// Adaptive water simulation
		if (use_spreading_skill) {
			do spreading_simulation_step();
		} else {
			do add_water();
			do flow_water();
			do check_obstactles_drowning();
		}
		do recompute_road_graph();
		do body_flooding();
		do update_score();
		current_step <- current_step + 1;
		
		exit {
			best_score <- max(best_score, score);
			do exit_flooding();
			if (use_spreading_skill) {
				do stop_spreading_simulation();
			}
		}
		transition to: s_start when: (current_round >= num_rounds) and flooding_over() {
			do restart();
		}
		transition to: s_diking when: (current_round < num_rounds) and flooding_over() {
			do restart();
		}
	}
	
	/*************************************************************
	 * BACKWARD COMPATIBILITY: Original water flow actions
	 *************************************************************/
	
	/**
	 * Original add_water action - for VR compatibility
	 */
	action add_water {
		if (current_step <= num_step_add) {
			list<cell> to_adds <- bed_cells where ((each.obstacle_height = 0) and (each.location overlaps main_river_part));
			float coeff_to_add <- total_water_to_add / (to_adds sum_of each.water_to_add);
			ask to_adds parallel: true{
				water_height <- water_height + water_to_add * max_water_input * coeff_to_add;
			}
		}
	}
	
	/**
	 * Original flow_water action - for VR compatibility
	 */
	action flow_water {
		ask cell parallel: true{
			water_height_tmp <- water_height;
		}
		ask cell parallel: true{
			do flow();
		}
		ask cell parallel: true{
			water_height <- water_height_tmp;
		}
		do compute_river_shape();
	}
	
	/**
	 * Original compute_river_shape action - for VR compatibility
	 */
	action compute_river_shape {
		list<cell> river_cells <- cell where (not each.already and (each.water_height > limit_drown));
		list<list<cell>> clusters <- list<list<cell>>(simple_clustering_by_distance(river_cells, 1));
		loop c over: clusters {
			ask c {already <- true;}
       		create river with: (cells:c);
       		ask river parallel: true {
       			do generate_shape();
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
		ask merging_rivers parallel: true {
			do update_shape();
		}
		ask river parallel: true {
			shape_to_export <- shape simplification simplification_river_dist;
			shape_to_export.attributes["name"] <- name;
		}
		
		if (empty(river)) {
			main_river_part <- init_river;
		} else {
			main_river_part <- river closest_to {world.location.x, world.shape.height};
			if (main_river_part = nil) {
				main_river_part <- river with_max_of(each.shape.area);
			}
		}
	}
	
	/**
	 * Enhanced create_dyke action - builds in both systems for synchronization
	 */
	bool create_dyke(point source, point target) {
		if (use_spreading_skill) {
			// STEP 1: Build dyke using SpreadingSkill (advanced physics)
			bool spreading_success <- build_dyke(source, target);
			
			if (spreading_success) {
				// STEP 2: Create corresponding dyke species for VR compatibility
				do create_dyke_species_from_line(source, target);
				return true;
			}
			return false;
		} else {
			// Use original dyke creation logic
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
	}
	
	/**
	 * Creates traditional dyke species to synchronize with SpreadingSkill dykes
	 */
	action create_dyke_species_from_line(point source, point target) {
		if (source distance_to target > 1.0) {
			geometry l <- line([source, target]);
			l <- l inter world;
			
			if (l != nil) {
				if (l overlaps init_river) {
					// Split into dam and dyke parts like original
					geometry gI <- l inter init_river;
					geometry gD <- l - init_river;
					
					if (gI != nil) {
						loop ggI over: gI.geometries {
							create dyke with:(
								is_dam: true, 
								shape: ggI,
								spreading_skill_synced: true
							);
						}
						if (gD != nil) {
							loop ggD over: gD.geometries {
								create dyke with:(
									shape: ggD,
									spreading_skill_synced: true
								);
							}
						}
					}
				} else {
					create dyke with:(
						shape: l,
						spreading_skill_synced: true
					);
				}
			}
		}
	}
	
	/**
	 * Original check_obstactles_drowning action - for VR compatibility
	 */
	action check_obstactles_drowning {
		ask buildings+road+dyke {
			if (!drowned) {do check_drowning();}
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
		
		// Update river representation for compatibility
		do update_rivers_from_spreading_skill();
	}
	
	/**
	 * Synchronizes SpreadingSkill water levels with cell grid
	 */
	action sync_water_levels_to_cells {
		if (water_field != nil) {
			ask cell parallel: true {
				float water_level <- display_water_field[location];
				water_height <- water_level > 0.01 ? water_level : 0.0;
			}
		}
	}
	
	/**
	 * Creates river agents from SpreadingSkill water field for VR compatibility
	 */
	action update_rivers_from_spreading_skill {
		ask river {do die;}
		
		list<cell> river_cells <- cell where (each.water_height > limit_drown);
		if (!empty(river_cells)) {
			list<list<cell>> clusters <- list<list<cell>>(simple_clustering_by_distance(river_cells, 1));
			loop c over: clusters {
	       		create river with: (cells:c);
			}
			ask river parallel: true {
	       		do generate_shape();
	       		shape_to_export <- shape simplification simplification_river_dist;
				shape_to_export.attributes["name"] <- name;
	       	}
		}
		
		// Update main river part
		if (empty(river)) {
			main_river_part <- init_river;
		} else {
			main_river_part <- river closest_to {world.location.x, world.shape.height};
			if (main_river_part = nil) {
				main_river_part <- river with_max_of(each.shape.area);
			}
		}
	}
	
	/*************************************************************
	 * Rain Control Actions (NEW)
	 *************************************************************/
	
	action start_light_rain {
		if (use_spreading_skill) {
			do start_rain(0.1, 1.0);
			write "🌧️ Light rain started";
		}
	}
	
	action start_heavy_rain {
		if (use_spreading_skill) {
			do start_rain(0.3, 1.5);
			write "⛈️ Heavy rain started";
		}
	}
	
	action stop_rain_completely {
		if (use_spreading_skill) {
			do stop_rain();
			write "☀️ Rain stopped";
		}
	}
	
	/*************************************************************
	 * Score Update (enhanced with synchronized counting)
	 *************************************************************/
	action update_score {
		float dyke_price;
		if (use_spreading_skill) {
			// Count from dyke species for accurate cost calculation
			dyke_price <- dyke sum_of (each.length * (each.is_dam ? price_meter_dam : price_meter_dyke));
		} else {
			dyke_price <- dyke sum_of (each.length * (each.is_dam ? price_meter_dam : price_meter_dyke));
		}
		float impact_border <- (cells_at_stake where (each.water_height > limit_drown)) sum_of (each.water_height * border_impact); 
		score <- init_score - casualties_impact * casualties - dyke_price - impact_border;
	}
	
	/*************************************************************
	 * Debug and Status Actions
	 *************************************************************/
	
	action show_dyke_sync_status {
		if (use_spreading_skill) {
			int spreading_dykes <- get_active_dyke_count();
			int species_dykes <- length(dyke);
			int synced_species <- length(dyke where each.spreading_skill_synced);
			
			write "=== DYKE SYNCHRONIZATION STATUS ===";
			write "SpreadingSkill dykes: " + spreading_dykes;
			write "Total dyke species: " + species_dykes;
			write "Synchronized species: " + synced_species;
			write "Non-synced species: " + (species_dykes - synced_species);
			write "===================================";
		} else {
			write "=== ORIGINAL SYSTEM STATUS ===";
			write "Total dykes: " + length(dyke);
			write "Dyke length: " + dyke_length + "m";
			write "Dam length: " + dam_length + "m";
			write "==============================";
		}
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
			if (use_spreading_skill) {
				write "Saving dykes (SpreadingSkill format) for round " + current_round;
			} else {
				save dyke to:id_sim+"/dykes_" + current_round + ".shp"  format:"shp";
			}
		}
	}
	
	action exit_flooding_base {
		if (save_results) {
			float dyke_length_val;
			float dam_length_val;
			if (use_spreading_skill) {
				dyke_length_val <- get_active_dyke_count() * 15.0; // Estimate
				dam_length_val <- 0.0;
			} else {
				dyke_length_val <- dyke_length;
				dam_length_val <- dam_length;
			}
			save ""+current_round+","+ dyke_length_val+ ","+ dam_length_val +","+evacuated+"," +casualties to:id_sim+"/evacuated_casualties.csv" rewrite: false format:"text";
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
	 * Initialization (backward compatible)
	 *************************************************************/

	init {
		// Store river geometries
		all_river_parts <- river_shapefile.contents;
		init_river <- union(all_river_parts);
		
		if (use_tell) {
			string system_name <- use_spreading_skill ? "SpreadingSkill enabled" : "Original system";
	 		do tell("Start the game: Round 1 (" + system_name + ")", false);
	 	}
	 	
		// Initialize agents
		do initialize_agents();
		
		// Initialize water system
		if (use_spreading_skill) {
			do initialize_spreading_system();
		}
	}
	
	/**
	 * Initialize SpreadingSkill with DEM and water data
	 */
	action initialize_spreading_system {
		write "=== INITIALIZING SPREADINGSKILL SYSTEM ===";
		
		// Create dyke field with same dimensions as DEM
		field dyke_field_for_init <- field(elevation_map.columns, elevation_map.rows);
		loop i from: 0 to: elevation_map.columns - 1 {
			loop j from: 0 to: elevation_map.rows - 1 {
				dyke_field_for_init[i, j] <- 0.0;
			}
		}
		
		// Initialize SpreadingSkill
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
		
		if (use_spreading_skill) {
			// Reset SpreadingSkill simulation AND clear traditional dyke species
			do reset_spreading_simulation(all_river_parts, 1.5);
			ask dyke where each.spreading_skill_synced {
				do die();
			}
		} else {
			// Reset original system
			ask dyke {
				do die();
			}
			dyke_length <- 0.0;
			dam_length <- 0.0;
		}
		
		ask river {do die();}
		ask cell {
			do initialize();
		}
		ask road+buildings+(keep_dykes ? dyke : []) {
			drowned <- false;
			do build();
		}
		ask people+(!keep_dykes ? dyke: []) {
			do die();
		}
		do initialize_agents();
		
		if (!use_spreading_skill) {
			main_river_part <- init_river;
		}
	}
	
	action initialize_agents {
		//Initialization of the river and the corresponding cells
		do init_river_computation();
		//Initialization of the obstacles (buildings, roads, etc.)
		do init_buildings();
		do init_roads();
		do init_evac();
		//Initialization of the people	
		do init_people();
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
			create river from: river_shapefile;
			
			ask cell overlapping init_river {
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
		do compute_river_shape();
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
* BACKWARD COMPATIBILITY: Original obstacle species
*************************************************************/	
species obstacle {
	bool drowned <- false;
	float height min: 0.0;
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
* BACKWARD COMPATIBILITY: Original buildings species
*************************************************************/	
species buildings parent: obstacle schedules: []{
	action compute_height {
		height <- 10.0;
	}
}

/*************************************************************
* BACKWARD COMPATIBILITY: Enhanced dyke species with sync support
*************************************************************/	
species dyke parent: obstacle schedules: []{
	float length;
	bool is_dam <- false;
	float rotation;
	int init_cells;
	float cell_percentage;
	bool spreading_skill_synced <- false; // NEW: Track if synced with SpreadingSkill
	
	init {
		length <- shape.perimeter;
		if (is_dam) {
			dam_length <- dam_length + length;
		} else {
			dyke_length <- dyke_length + length;
		}
		shape <- shape + 20;
		
		// Calculate rotation angle
        list<point> points <- shape.points;
        point start_point <- first(points);
        point end_point <- points[length(points) - 2];
        float dx <- end_point.x - start_point.x;
        float dy <- end_point.y - start_point.y;
        rotation <- dy = 0 ? (dx > 0 ? 180 / 2 : -180 / 2) : atan(dx/dy);
     
		do compute_height();
		do build();
		
		init_cells <- length(cells_under);
		cell_percentage <- 1.0;
	}
	
	action check_drowning {
		if (spreading_skill_synced and use_spreading_skill) {
			// For SpreadingSkill-synced dykes, use simplified drowning check
			// (SpreadingSkill handles the actual destruction)
			drowned <- (cells_under first_with (each.water_height > limit_drown)) != nil;
		} else {
			// Original drowning logic for non-synced dykes
			loop c over: (cells_under where (each.water_height > limit_drown)) {
				cells_under >> c;
				if (shape != nil) {shape <- shape - (c + 20.0);}
				c.obstacles >> self;
			}
			if (shape = nil or empty(cells_under)) {
				loop c over: cells_under {
					c.obstacles >> self;	
				}
				do die();
			}
			
			cell_percentage <- length(cells_under)/init_cells;
		}
	}
	
	action compute_height {
		height <- dyke_height;
	}
	
	user_command "Destroy" {
		do break();
		drowned <- true;
	}
}

/*************************************************************
* BACKWARD COMPATIBILITY: Original road species
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
* BACKWARD COMPATIBILITY: Original cell grid
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
	float altitude <- grid_value const: true;
	float water_height min: 0.0;
	float height;
	list<obstacle> obstacles;
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
	 * BACKWARD COMPATIBILITY: Original water flow algorithm
	 */ 
	action flow {
		if ((num_neigbors = 4 or !is_drain) and water_height > 0 ) {
			list<cell> neighbour_cells_al <- neighbors ;
			
			if (!empty(neighbour_cells_al)) {
				ask neighbour_cells_al {
					height <- altitude + water_height + obstacle_height;
				}
				
				height <- altitude + water_height;
				list<cell> flow_cells <- (neighbour_cells_al where (height > each.height));
				if (!empty(flow_cells)) {
					list<float> v <- flow_cells collect (height - each.height);
					float sum_v <- sum(v);
					float water_flowing <- water_height * diffusion_rate;
					water_height_tmp <- water_height_tmp - water_flowing;
					
					loop i from: 0 to: length(flow_cells) -1 {
						cell flow_cell <- flow_cells[i];
						flow_cell.water_height_tmp <- flow_cell.water_height_tmp + water_flowing * v[i]/sum_v;
					}
				}
			}
		} else {
			water_height_tmp <- water_height_tmp - (water_height * diffusion_rate);
		}
	}
	
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
		water_height <- 0.0;
		already <- false;
		if (the_obstacle.height > obstacle_height) {obstacle_height <- the_obstacle.height;}
	}
}

/*************************************************************
* BACKWARD COMPATIBILITY: Original river species
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
			do die();
		}
		to_merge <- [];
	}
	
	rgb color <-rnd_color(255);	
}

/*************************************************************
* BACKWARD COMPATIBILITY: Original people species
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
* BACKWARD COMPATIBILITY: Original evacuation_point species
*************************************************************/	
species evacuation_point schedules: [];