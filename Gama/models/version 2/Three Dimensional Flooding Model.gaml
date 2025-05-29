model ThreeDimensionalFloodingModel

global {
    // Declare the field variable to store DEM data
    file dem_file <- file("../../includes/dem/SRTM_DEM_NHATLE_30M_RESIZED_BY_FOUR.tif");

    field elevation_map <- field(dem_file);
    geometry shape <- envelope(dem_file);

    // Add water shapefile - load geometries directly (no species needed)
    file water_shapefile <- file("../../includes/gis/water_multipolygon.shp");

    list<geometry> water_geometries <- [];

    // Create water field with same resolution as DEM
    field water_field;
    
    // Water flow simulation parameters - FAST & DRAMATIC
    float flow_threshold <- 0.01#m;  // Very low threshold - water flows easily
    float rising_rate <- 0.3#m;     // Moderate rising for better equalization visibility
    float min_flow_diff <- 0.001#m; // Very small difference needed for flow
    float equalization_threshold <- 0.1#m; // Level difference threshold for equalization
    
    // Simulation state
    bool water_simulation_active <- false;
    int simulation_step <- 0;
    
    // OPTIMIZATION: Track only active/edge water cells
    list<water_cell> active_water_cells <- [];
    list<water_cell> edge_water_cells <- [];

    // Initialize the simulation
    init {
        write "DEM loaded successfully";
        write "DEM dimensions: " + elevation_map.columns + " x " + elevation_map.rows;
        write "Min elevation: " + min(elevation_map);
        write "Max elevation: " + max(elevation_map);

        // Load water geometries directly from shapefile
        water_geometries <- water_shapefile.contents;
        write "Number of water geometries loaded: " + length(water_geometries);

        // Create water field - rasterize the water polygons
        water_field <- field(elevation_map.columns, elevation_map.rows);
        write "Water field created";

        // Initialize water cells and build active list
        int water_cell_count <- 0;
        
        ask water_cell {
            bool cell_is_water <- false;
            
            // Check intersection with water geometries directly
            cell_is_water <- not empty(water_geometries overlapping self.shape);
            
            if (cell_is_water) {
                is_water <- true;
                
                // Get terrain elevation at this location
                float terrain_elev <- elevation_map[self.shape.location];
                
                // Set initial water elevation above terrain - HIGHER for visibility
                water_elevation <- terrain_elev + 1.5#m; // 1.5m initial water depth!
                terrain_elevation <- terrain_elev;
                
                // Add to active water cells list
                active_water_cells <- active_water_cells + self;
                water_cell_count <- water_cell_count + 1;
            } else {
                is_water <- false;
                water_elevation <- 0.0;
                terrain_elevation <- elevation_map[self.shape.location];
            }
        }

        write "Initial water cells: " + water_cell_count;
        
        // Initialize water field efficiently
        water_field <- water_field * 0;
        
        // Set only actual water cells and build initial edge list
        ask active_water_cells {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                water_field[field_i, field_j] <- water_elevation;
            }
            
            // Check if this cell is an edge cell initially
            bool is_edge <- false;
            ask neighbors {
                if (!is_water) {
                    is_edge <- true;
                }
            }
            if (is_edge) {
                is_edge_cell <- true;
                edge_water_cells <- edge_water_cells + self;
            }
        }
        
        write "Initial edge cells: " + length(edge_water_cells);
        write "Initialization complete. Water flow simulation ready.";
        write "Press PLAY to start water flow simulation.";
    }
    
    // INCREMENTAL EDGE UPDATE - Only update changed edges
    action update_edge_cells(list<water_cell> new_water_cells, list<water_cell> affected_neighbors) {
        int edges_added <- 0;
        int edges_removed <- 0;
        
        // 1. Check new water cells - are they edges?
        ask new_water_cells {
            bool is_edge <- false;
            ask neighbors {
                if (!is_water) {
                    is_edge <- true;
                }
            }
            if (is_edge and !is_edge_cell) {
                is_edge_cell <- true;
                edge_water_cells <- edge_water_cells + self;
                edges_added <- edges_added + 1;
            }
        }
        
        // 2. Check affected neighbors of new water - are old edges still edges?
        ask affected_neighbors {
            if (is_water and is_edge_cell) {
                bool still_edge <- false;
                ask neighbors {
                    if (!is_water) {
                        still_edge <- true;
                    }
                }
                if (!still_edge) {
                    // No longer an edge - remove from edge list
                    is_edge_cell <- false;
                    edge_water_cells <- edge_water_cells - self;
                    edges_removed <- edges_removed + 1;
                }
            }
        }
        
        if (simulation_step mod 10 = 0 and (edges_added > 0 or edges_removed > 0)) {
            write "Step " + simulation_step + ": Edge update - Added: " + edges_added + ", Removed: " + edges_removed + ". Total edges: " + length(edge_water_cells);
        }
    }
    
    // SUPER FAST water flow simulation step - INCREMENTAL OPTIMIZATION
    action simulate_water_flow {
        simulation_step <- simulation_step + 1;
        
        // 1. SPREAD WATER - only from current edge cells (no recalculation needed!)
        list<water_cell> new_water_cells <- [];
        list<water_cell> affected_neighbors <- [];
        
        ask edge_water_cells {
            if (water_elevation > terrain_elevation + flow_threshold) {
                // Try to flow to neighbors that can receive water
                ask neighbors {
                    if (!is_water and 
                        (myself.water_elevation - terrain_elevation) > min_flow_diff) {
                        // FAST SPREADING
                        is_water <- true;
                        water_elevation <- max(terrain_elevation + flow_threshold, 
                                             myself.water_elevation - 0.05#m);
                        new_water_cells <- new_water_cells + self;
                        
                        // Track neighbors that might have edge status changes
                        ask neighbors {
                            if (is_water and !(affected_neighbors contains self)) {
                                affected_neighbors <- affected_neighbors + self;
                            }
                        }
                        
                        // Update field immediately for this cell
                        int field_i <- int(grid_x);
                        int field_j <- int(grid_y);
                        
                        if (field_i >= 0 and field_i < water_field.columns and 
                            field_j >= 0 and field_j < water_field.rows) {
                            water_field[field_i, field_j] <- water_elevation;
                        }
                    }
                }
            }
        }
        
        // 2. Update active water cells list and edge list incrementally
        if (length(new_water_cells) > 0) {
            active_water_cells <- active_water_cells + new_water_cells;
            
            // INCREMENTAL EDGE UPDATE - Only check changed areas
            do update_edge_cells(new_water_cells, affected_neighbors);
            
            if (simulation_step mod 5 = 0) {
                write "Step " + simulation_step + ": " + length(new_water_cells) + " new cells (from " + length(edge_water_cells) + " edge cells). Total: " + length(active_water_cells);
            }
        }
        
        // 3. RISE WATER - REALISTIC PHYSICS: Equalize levels first, then rise together
        if (length(new_water_cells) = 0) {
            // Find current water level range
            float min_water_level <- #max_float;
            float max_water_level <- #min_float;
            
            ask active_water_cells {
                if (water_elevation < min_water_level) {
                    min_water_level <- water_elevation;
                }
                if (water_elevation > max_water_level) {
                    max_water_level <- water_elevation;
                }
            }
            
            float level_difference <- max_water_level - min_water_level;
            
            // If there's a significant difference, equalize first
            if (level_difference > equalization_threshold) {
                // Only raise water that's below the maximum level
                ask active_water_cells {
                    if (water_elevation < (max_water_level - 0.01)) {
                        water_elevation <- min(water_elevation + rising_rate, max_water_level);
                        
                        // Update field for raised water
                        int field_i <- int(grid_x);
                        int field_j <- int(grid_y);
                        
                        if (field_i >= 0 and field_i < water_field.columns and 
                            field_j >= 0 and field_j < water_field.rows) {
                            water_field[field_i, field_j] <- water_elevation;
                        }
                    }
                }
                
                if (simulation_step mod 3 = 0) {
                    write "Step " + simulation_step + ": Equalizing water levels (range: " + with_precision(level_difference, 2) + "m)";
                }
            } else {
                // All water at same level - rise everything together
                ask active_water_cells {
                    water_elevation <- water_elevation + rising_rate;
                    
                    // Update field for raised water
                    int field_i <- int(grid_x);
                    int field_j <- int(grid_y);
                    
                    if (field_i >= 0 and field_i < water_field.columns and 
                        field_j >= 0 and field_j < water_field.rows) {
                        water_field[field_i, field_j] <- water_elevation;
                    }
                }
                
                if (simulation_step mod 5 = 0) {
                    write "Step " + simulation_step + ": All water raised uniformly by " + rising_rate + "m (level: " + with_precision(max_water_level, 1) + "m)";
                }
            }
        }
    }
    
    // ULTRA-FAST simulation reflex
    reflex water_flow_simulation when: water_simulation_active {
        do simulate_water_flow();
    }
    
    // Control actions
    action start_water_simulation {
        water_simulation_active <- true;
        write "OPTIMIZED Water flow simulation started";
    }
    
    action stop_water_simulation {
        water_simulation_active <- false;
        write "Water flow simulation stopped";
    }
    
    action reset_water_simulation {
        water_simulation_active <- false;
        simulation_step <- 0;
        active_water_cells <- [];
        edge_water_cells <- [];
        
        // Reset water cells to initial state
        ask water_cell {
            if (water_geometries overlapping self.shape != []) {
                is_water <- true;
                water_elevation <- terrain_elevation + 1.5#m;
                is_edge_cell <- false; // Will be recalculated
                active_water_cells <- active_water_cells + self;
            } else {
                is_water <- false;
                water_elevation <- 0.0;
                is_edge_cell <- false;
            }
        }
        
        // Reset field
        water_field <- water_field * 0;
        
        // Rebuild initial edge list
        ask active_water_cells {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                water_field[field_i, field_j] <- water_elevation;
            }
            
            // Check if this cell is an edge cell
            bool is_edge <- false;
            ask neighbors {
                if (!is_water) {
                    is_edge <- true;
                }
            }
            if (is_edge) {
                is_edge_cell <- true;
                edge_water_cells <- edge_water_cells + self;
            }
        }
        
        write "Water simulation reset to initial state. Edge cells: " + length(edge_water_cells);
    }
}

// Water grid cells - MINIMAL properties + edge tracking
grid water_cell width: elevation_map.columns height: elevation_map.rows parallel: true {
    bool is_water <- false;
    float water_elevation <- 0.0;
    float terrain_elevation <- 0.0;
    bool is_edge_cell <- false; // NEW: Track if this cell is currently an edge
}

experiment main type: gui {
    
    parameter "Flow Threshold (m)" var: flow_threshold min: 0.000 max: 0.1 step: 0.001;
    parameter "Rising Rate (m/step)" var: rising_rate min: 0.1 max: 3.0 step: 0.1;
    parameter "Min Flow Difference (m)" var: min_flow_diff min: 0.0000 max: 0.01 step: 0.0001;
    parameter "Equalization Threshold (m)" var: equalization_threshold min: 0.00 max: 1.0 step: 0.01;
    
    action _init_ {
        create simulation;
    }

    output {
        display "DEM_3D_with_Dynamic_Water" type: opengl refresh: true{
            // Display DEM as mesh first (terrain)
            mesh elevation_map
                scale: 10
                grayscale: true
                smooth: false
                triangulation: true;

            // Display water as mesh - dynamic water flow
            mesh water_field
                scale: 10
                color: rgb(100, 150, 255, 180) // Semi-transparent blue water
                smooth: false  
                triangulation: true;
        }
    }
    
    // User actions for controlling simulation
    user_command "Start Water Flow" {
        ask simulation { do start_water_simulation(); }    }
    
    user_command "Stop Water Flow" {
        ask simulation { do stop_water_simulation(); }
    }
    
    user_command "Reset Water" {
        ask simulation { do reset_water_simulation(); }
    }
}