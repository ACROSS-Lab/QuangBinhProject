/**
* Name: Flooding Model
* Author: Alexis Drogoul
* Description: This model is based on the toy model called "Hydrological Model" 
* and uses a simple flow diffusion model to simulate a flooding in a subset of Dong Hoi city
* (Quang Binh province).
* Tags: SIMPLE
*/
model Flooding

global control: fsm {
	
	/*************************************************************
	 * Global states
	 *************************************************************/	
	
	state s_init initial: true{
		enter {
			do enter_init();
		}
		transition to: s_diking when: init_over();
	}
	
	state s_restart {
		do restart();
		transition to: s_init;
	}
	
	/**
	 * This state represents the state where the user(s) is(are) able to build dikes 
	 */
	state s_diking {
		enter {
			do enter_diking();
		}
		transition to: s_flooding when: diking_over();
		
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
		do recompute_road_graph();
		do drain_water();
		
		transition to: s_restart when: flooding_over();
	}

	/*************************************************************
	 * Functions that control the transitions between the states. 
	 * Must be redefined in sub-models
	 *************************************************************/
	 
	action enter_init virtual: true;
	
	action enter_diking virtual: true;
	
	action enter_flooding virtual: true;

	bool init_over virtual: true;
	
	bool diking_over virtual: true;
	
	bool flooding_over virtual: true;
 	
	/*************************************************************
	 * Built-in parameters to control the simulations
	 *************************************************************/
	
	// Random seed 
	float seed <- 0.0;
	
	//Step of the simulation
	float step <- 30#mn;
	
	// Current date is fixed to #now
	date current_date <- #now;
	
	/*************************************************************
	 * Flags to control some functions in the simulations
	 *************************************************************/

	// Do we need to recompute the road graph ? 
	bool need_to_recompute_graph <- false;
	
	// Do we need to update the "drowned" status of people and obstacles ?
	bool update_drowning -> cycle != 0;

	
	/*************************************************************
	 * Global monitoring variables
	 *************************************************************/
	 
	// Number of casualties (drowned people)
	int casualties <- 0;
	
	// Number of evacuated people
	int evacuated <- 0;

	/*************************************************************
	 * Initial conditions for people, water and obstacles
	 *************************************************************/

	// Initial number of people
	int nb_of_people <- 500;
	
	// The initial (and current) maximum level of water
	float max_water_height <- 10.0;
	
	// The height of water in the river at the beginning
	float initial_water_height <- 5.0;
	
	//Diffusion rate
	float diffusion_rate <- 0.5;
	
	//Height of the dykes (15 m by default)
	float dyke_height <- 15.0;
	
	//Width of the dyke (15 m by default)
	float dyke_width <- 15.0;
	
	/*************************************************************
	 * Road network
	 *************************************************************/
	
	// Complete initial road network
	graph<geometry, geometry> road_network;
	
	// Road network w/o the drowned roads
	graph<geometry, geometry> road_network_usable;
	
	// Weights associated with the road network
	map<road, float> new_weights;

	
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
	
	//Data elevation file
	file dem_file <- file("../../includes/dem/terrain143x331.tif");
	
	//Shape of the environment using the bounding box of Quang Binh
	geometry shape <- envelope(file("../../includes/gis/QBBB.shp"));
	
	
	/*************************************************************
	 * Lists of the water cells used to schedule them 
	 *************************************************************/

	//List of the drain cells ("end" of the river)
	list<cell> drain_cells;
	
	//List of the initial river cells ("bed" of the river)
	list<cell> river_cells;



	init {
		//Initialization of the cells
		do init_cells;
		//Initialization of the water cells
		do init_water;
		//Initialization of the obstacles (buildings, roads, etc.)
		do init_buildings;
		do init_roads;
		do init_evac;
		//Set the height of each cell
		ask cell {
			obstacle_height <- compute_highest_obstacle();
			do update_color;
		}
		//Initialization of the people	
		do init_people;
	}
	
	
	action add_casualty {
		casualties <- casualties + 1;
	}
	
	action add_evacuated {
		evacuated <- evacuated + 1;
	}
	
	action restart {
		ask road+dyke+people+buildings+river {
			do die;
		}
		ask cell {
			water_height <- 0.0;
			already <- false;
			obstacle_height <- 0.0;
			obstacles <- [];
		}
		do init_water;
		do init_buildings;
		do init_roads;
		ask cell {
			obstacle_height <- compute_highest_obstacle();
			do update_color;
		}
		do init_people;
	}
	
	action init_people {
		create people number: nb_of_people {
			location <- any_location_in(one_of(buildings));
		}
	}

	action init_roads {
		create road from: clean_network(shape_file_roads.contents, 0.0, false, true);
		road_network <- as_edge_graph(road);
		road_network_usable <- as_edge_graph(road);
		new_weights <- road as_map (each::each.shape.perimeter);
	}
	
	action init_evac {
		create evacuation_point from: shape_file_evacuation;
	}
	
	//Action to initialize the altitude value of the cell according to the dem file
	action init_cells {
		ask cell {
			altitude <- grid_value;
			neighbour_cells <- (self neighbors_at 1);
		}

	}
	//action to initialize the water cells according to the river shape file and the drain
	action init_water {
		create river from:(river_shapefile);
		ask cell overlapping river[0] {
			water_height <- initial_water_height;
			is_river <- true;
			is_drain <- grid_y = 0;
		}
		//Initialization of the river cells
		river_cells <- cell where (each.is_river);
		//Initialization of the drain cells
		drain_cells <- cell where (each.is_drain);

	}
	//initialization of the obstacles (the buildings and the dykes)
	action init_buildings {
		create buildings from: buildings_shapefile {
			do init_color();
		}
	}
	
	//Reflex to add water among the water cells
	action add_water {
		float water_input <- rnd(100) / 100;
		ask river_cells {
			water_height <- water_height + water_input;
		}

	}
	//Reflex to flow the water according to the altitute and the obstacle
	action flow_water {
		list<cell> cells <- cell sort_by ((each.altitude + each.water_height + each.obstacle_height));
		ask cells {
			already <- false;
			do flow;
		}

	}
	
	//Reflex to update the color of the cell
	action update_cell_color {
		ask cell {
			do update_color;
		}
	}

	//Reflex for recomputing the graph 
	action recompute_road_graph {
		if (!need_to_recompute_graph) {return;}
		new_weights <- road as_map (each::each.shape.perimeter * (each.drowned ? 3.0 : 1.0));
		road_network_usable <- as_edge_graph(road where not each.drowned);
		need_to_recompute_graph <- false;
	}

	//Reflex for the drain cells to drain water
	action drain_water {
		ask drain_cells {
			water_height <- 0.0;
		}

	}

}
//Species which represent the obstacle
species obstacle {
	bool drowned <- false;
	//height of the obstacle
	float height min: 0.0;
	//Color of the obstacle
	rgb color <- #gray;

	//List of cells concerned
	list<cell> cells_under;

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

	//Action to update the cells
	init init_cells {
	//All the cells concerned by the obstacle are the ones overlapping the obstacle
		cells_under <- (cell overlapping self);
		//The height is now computed
		do compute_height();
		do build();
	}
	
	reflex check_drowning when: !drowned and update_drowning {
		drowned <- (cells_under first_with (each.water_height > height)) != nil;
		if (drowned) {
			do break();
		}
	}

	action compute_height;


}
//Species buildings  derivated from obstacle
species buildings parent: obstacle {
//The building has a height randomly chosed between 5 and 10 meters
	float height <- 5.0 + rnd(10.0) ;
	
	action init_color {
		color <- one_of (#orange, darker(#orange), #brown);
	}
}
//Species dyke which is derivated from obstacle
species dyke parent: obstacle {
	//Action to compute the height of the dyke as the dyke_height without the mean height of the cells it overlaps
	action compute_height {
		height <- dyke_height - mean(cells_under collect (each.altitude));
	}
	//user command which allows the possibility to destroy the dyke for the user
	user_command "Destroy" {
		do break;
		drowned <- true;
	}
}
//Grid cell to discretize space, initialized using the dem file
grid cell file: dem_file neighbors: 4 frequency: 0 use_regular_agents: false use_individual_shapes: false use_neighbors_cache: false schedules: [] {
	geometry shape_union <- shape + 0.1;

	//Altitude of the cell
	float altitude;
	//Height of the water in the cell
	float water_height <- 0.0 min: 0.0;
	//Height of the cell
	float height;
	//List of the neighbour cells
	list<cell> neighbour_cells;
	//Boolean to know if it is a drain cell
	bool is_drain <- false;
	//Boolean to know if it is a river cell
	bool is_river <- false;
	//List of all the obstacles overlapping the cell
	list<obstacle> obstacles;
	//Height of the obstacles
	float obstacle_height <- 0.0;
	bool already <- false;

	//Action to compute the highest obstacle among the obstacles
	float compute_highest_obstacle {
		if (empty(obstacles)) {
			return 0.0;
		} else {
			return obstacles max_of (each.height);
		}

	}
	//Action to flow the water 
	action flow {
	//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if (water_height > 0) {
		//We get all the cells already done
			list<cell> neighbour_cells_al <- neighbour_cells where (each.already);
			//If there are cells already done then we continue
			if (!empty(neighbour_cells_al)) {
			//We compute the height of the neighbours cells according to their altitude, water_height and obstacle_height
				ask neighbour_cells_al {
					height <- altitude + water_height + obstacle_height;
				}
				//The height of the cell is equals to its altitude and water height
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
		if (water_height > max_water_height) {
			max_water_height <- water_height;
		}
		already <- true;
	}
	//Update the color of the cell
	action update_color {
		if (water_height <= 0.01) {
			color <- #transparent;
		} else {
			float val_water <-  255 * (1 - (water_height / max_water_height));
			color <- rgb([val_water/2, val_water/2, 255]);
		}
		grid_value <- water_height;
	}
	//action to compute the destruction of the obstacle
	action update_after_destruction (obstacle the_obstacle) {
		remove the_obstacle from: obstacles;
		obstacle_height <- compute_highest_obstacle();
	}
	
	action update_after_construction(obstacle the_obstacle) {
		obstacles << the_obstacle;
		obstacle_height <- compute_highest_obstacle();
		water_height <- 0.0;
	}

}

species river {
	reflex {
		shape <- union((cell where (each.water_height > 0)) collect each.shape_union) simplification 0.2;
	}
}

species people skills: [moving] {
	float height_pp <- 1.7 #m;
	bool alerted <- false;
	point target <- nil;
	float perception_distance;
	float speed <- 50 #m / #h;
	path my_path;

	reflex become_alerted when: state="s_flooding" and not alerted and flip(0.1) {
		alerted <- true;
	}

	reflex alert_target when: alerted {
		if target = nil {
			using (topology(road_network_usable)) {
				evacuation_point ep <- (evacuation_point closest_to self);
				target <- ep.location;
			}
			my_path <- road_network_usable path_between (location, target);
		}

		if my_path != nil {
			do follow(path: my_path, move_weights: new_weights);
			if (location = target) {
				ask world {do add_evacuated;}
				target <- nil;
				do die;
			} }
		}

	reflex check_drowning {
		cell a_cell <- cell(location);
		if (a_cell != nil and a_cell.water_height > 0.2 and flip(0.5)) {
			ask world {do add_casualty;}
			do die;
		}
	}
}
	

species evacuation_point {

	aspect default {
		draw triangle(50) color: #red;
	}

}

species road parent: obstacle {
	float height <- 0.5;
	
	action break {
		need_to_recompute_graph <- true;
	}

}


