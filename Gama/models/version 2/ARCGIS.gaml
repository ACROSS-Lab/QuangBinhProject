model ArcGISFloodSimulation

global {
    // Declare the field variable to store DEM data
    file dem_file <- file("../../includes/dem/terrain_large.tif");
    field elevation_map <- field(dem_file);
    geometry shape <- envelope(dem_file);

    // Add water shapefile - load geometries directly (no species needed)
    file water_shapefile <- file("../../includes/gis/river_clean.shp");
    list<geometry> water_geometries <- [];

    // Create water field with same resolution as DEM
    field water_field;
    
    // ArcGIS Physics Parameters
    float gravity <- 9.81; // m/s²
    float cell_size; // Will be calculated from DEM
    float delta_t; // Internal time step for stability
    float delta_T; // External time step for progression
    
    // Flood simulation parameters
    float precipitation_rate <- 0.0; // mm/hr - can be changed during simulation
    float evaporation_rate <- 0.0; // mm/hr
    float infiltration_rate <- 2.0; // mm/hr - default soil infiltration
    float max_infiltration <- 100.0; // mm - maximum infiltration capacity
    
    // Initial water depth above terrain
    float initial_water_depth <- 1.5; // meters
    
    // Boundary conditions
    bool allow_water_exit <- true; // Water can flow out of boundaries
    
    // Simulation state
    bool water_simulation_active <- false;
    int simulation_step <- 0;
    float simulation_time <- 0.0; // Total simulation time in hours
    
    // Performance tracking
    list<water_cell> active_water_cells <- [];

    // Initialize the simulation
    init {
        write "=== ArcGIS Flood Simulation Initialization ===";
        write "DEM loaded successfully";
        write "DEM dimensions: " + elevation_map.columns + " x " + elevation_map.rows;
        write "Min elevation: " + min(elevation_map) + "m";
        write "Max elevation: " + max(elevation_map) + "m";

        // Calculate cell size from DEM (assuming square cells)
        cell_size <- shape.width / elevation_map.columns;
        write "Cell size: " + cell_size + "m";
        
        // Calculate time steps using ArcGIS formulas
        delta_t <- sqrt(cell_size) + 0.1 * 0.01416;
        delta_T <- 0.5 * cell_size;
        write "Internal time step (Δt): " + delta_t + "s";
        write "External time step (ΔT): " + delta_T + "s";

        // Load water geometries directly from shapefile
        water_geometries <- water_shapefile.contents;
        write "Number of water geometries loaded: " + length(water_geometries);

        // Create water field - rasterize the water polygons
        water_field <- field(elevation_map.columns, elevation_map.rows);
        write "Water field created";

        // Initialize water cells
        int water_cell_count <- 0;
        
        ask water_cell {
            // Get terrain elevation at this location
            terrain_elevation <- elevation_map[self.shape.location];
            
            // Check if this cell contains initial water
            bool cell_is_water <- not empty(water_geometries overlapping self.shape);
            
            if (cell_is_water) {
                is_water <- true;
                water_depth <- initial_water_depth;
                water_elevation <- terrain_elevation + water_depth;
                active_water_cells <- active_water_cells + self;
                water_cell_count <- water_cell_count + 1;
            } else {
                is_water <- false;
                water_depth <- 0.0;
                water_elevation <- terrain_elevation;
            }
            
            // Initialize flow rates and infiltration
            Q_L <- 0.0; Q_R <- 0.0; Q_T <- 0.0; Q_B <- 0.0;
            total_infiltrated <- 0.0;
        }

        write "Initial water cells: " + water_cell_count;
        
        // Initialize water field - set to terrain elevation for dry cells, water elevation for wet cells
        ask water_cell {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                if (is_water) {
                    water_field[field_i, field_j] <- water_elevation; // Show water surface
                } else {
                    water_field[field_i, field_j] <- terrain_elevation; // Show terrain (no water visible)
                }
            }
        }
        
        write "=== Initialization Complete ===";
        write "Ready for ArcGIS-based flood simulation";
        write "Press 'Start Simulation' to begin";
    }
    
    // Main ArcGIS flood simulation step
    action simulate_flood_step {
        simulation_step <- simulation_step + 1;
        simulation_time <- simulation_time + (delta_T / 3600.0); // Convert to hours
        
        // STEP 1: Calculate flow rate changes using momentum equation - OPTIMIZED
        ask active_water_cells parallel: true {
            // FAST neighbor access using grid coordinates
            int my_x <- int(grid_x);
            int my_y <- int(grid_y);
            
            // Get neighbors directly by grid coordinates (much faster!)
            water_cell left_neighbor <- (my_x > 0) ? water_cell[my_x - 1, my_y] : nil;
            water_cell right_neighbor <- (my_x < (elevation_map.columns - 1)) ? water_cell[my_x + 1, my_y] : nil;
            water_cell top_neighbor <- (my_y < (elevation_map.rows - 1)) ? water_cell[my_x, my_y + 1] : nil;
            water_cell bottom_neighbor <- (my_y > 0) ? water_cell[my_x, my_y - 1] : nil;
            
            // Calculate flow rate changes using momentum equation: ΔQ = Δt * g * l * (h_ij - h_mn)
            float flow_factor <- delta_t * gravity * cell_size;
            
            // Left flow
            if (left_neighbor != nil) {
                float delta_Q_L <- flow_factor * (water_elevation - left_neighbor.water_elevation);
                new_Q_L <- Q_L + delta_Q_L;
            } else {
                // Boundary condition
                if (allow_water_exit) {
                    float delta_Q_L <- flow_factor * (water_elevation - terrain_elevation);
                    new_Q_L <- Q_L + delta_Q_L;
                } else {
                    new_Q_L <- 0.0;
                }
            }
            
            // Right flow
            if (right_neighbor != nil) {
                float delta_Q_R <- flow_factor * (water_elevation - right_neighbor.water_elevation);
                new_Q_R <- Q_R + delta_Q_R;
            } else {
                if (allow_water_exit) {
                    float delta_Q_R <- flow_factor * (water_elevation - terrain_elevation);
                    new_Q_R <- Q_R + delta_Q_R;
                } else {
                    new_Q_R <- 0.0;
                }
            }
            
            // Top flow
            if (top_neighbor != nil) {
                float delta_Q_T <- flow_factor * (water_elevation - top_neighbor.water_elevation);
                new_Q_T <- Q_T + delta_Q_T;
            } else {
                if (allow_water_exit) {
                    float delta_Q_T <- flow_factor * (water_elevation - terrain_elevation);
                    new_Q_T <- Q_T + delta_Q_T;
                } else {
                    new_Q_T <- 0.0;
                }
            }
            
            // Bottom flow
            if (bottom_neighbor != nil) {
                float delta_Q_B <- flow_factor * (water_elevation - bottom_neighbor.water_elevation);
                new_Q_B <- Q_B + delta_Q_B;
            } else {
                if (allow_water_exit) {
                    float delta_Q_B <- flow_factor * (water_elevation - terrain_elevation);
                    new_Q_B <- Q_B + delta_Q_B;
                } else {
                    new_Q_B <- 0.0;
                }
            }
            
            // MASS CONSERVATION CORRECTION 1: No negative flows
            new_Q_L <- max(0.0, new_Q_L);
            new_Q_R <- max(0.0, new_Q_R);
            new_Q_T <- max(0.0, new_Q_T);
            new_Q_B <- max(0.0, new_Q_B);
            
            // MASS CONSERVATION CORRECTION 2: Flow scaling when outflow exceeds available water
            float total_outflow <- new_Q_L + new_Q_R + new_Q_T + new_Q_B;
            float available_volume <- water_depth * cell_size * cell_size;
            
            if (total_outflow * delta_t > available_volume) {
                float K <- available_volume / (total_outflow * delta_t);
                new_Q_L <- new_Q_L * K;
                new_Q_R <- new_Q_R * K;
                new_Q_T <- new_Q_T * K;
                new_Q_B <- new_Q_B * K;
            }
        }
        
        // STEP 1b: Reset flow rates for non-water cells (much faster than processing all)
        ask water_cell parallel: true {
            if (water_depth <= 0.001) {
                new_Q_L <- 0.0; new_Q_R <- 0.0; new_Q_T <- 0.0; new_Q_B <- 0.0;
            }
        }
        
        // STEP 2: Update all flow rates simultaneously
        ask water_cell {
            Q_L <- new_Q_L; Q_R <- new_Q_R; Q_T <- new_Q_T; Q_B <- new_Q_B;
        }
        
        // STEP 3: Calculate water elevation changes using continuity equation - OPTIMIZED
        ask active_water_cells parallel: true {
            // FAST inflow calculation using grid coordinates
            int my_x <- int(grid_x);
            int my_y <- int(grid_y);
            
            float inflow <- 0.0;
            
            // Add inflow from left neighbor (if exists)
            if (my_x > 0) {
                water_cell left_neighbor <- water_cell[my_x - 1, my_y];
                inflow <- inflow + left_neighbor.Q_R; // Left neighbor's right flow comes to me
            }
            
            // Add inflow from right neighbor (if exists)
            if (my_x < (elevation_map.columns - 1)) {
                water_cell right_neighbor <- water_cell[my_x + 1, my_y];
                inflow <- inflow + right_neighbor.Q_L; // Right neighbor's left flow comes to me
            }
            
            // Add inflow from top neighbor (if exists)
            if (my_y < (elevation_map.rows - 1)) {
                water_cell top_neighbor <- water_cell[my_x, my_y + 1];
                inflow <- inflow + top_neighbor.Q_B; // Top neighbor's bottom flow comes to me
            }
            
            // Add inflow from bottom neighbor (if exists)
            if (my_y > 0) {
                water_cell bottom_neighbor <- water_cell[my_x, my_y - 1];
                inflow <- inflow + bottom_neighbor.Q_T; // Bottom neighbor's top flow comes to me
            }
            
            // Calculate net volume change per unit time
            float outflow <- Q_L + Q_R + Q_T + Q_B;
            float net_flow <- inflow - outflow; // m³/s
            
            // Add precipitation (convert mm/hr to m/s)
            float precipitation_volume_rate <- (precipitation_rate / 1000.0 / 3600.0) * cell_size * cell_size;
            
            // Subtract evaporation (convert mm/hr to m/s)
            float evaporation_volume_rate <- (evaporation_rate / 1000.0 / 3600.0) * cell_size * cell_size;
            
            // Subtract infiltration (convert mm/hr to m/s, limited by max infiltration)
            float infiltration_volume_rate <- 0.0;
            if (water_depth > 0.0 and total_infiltrated < max_infiltration) {
                float max_infiltration_rate <- (max_infiltration - total_infiltrated) / 1000.0; // Convert to meters
                float current_infiltration_rate <- min(infiltration_rate / 1000.0 / 3600.0, 
                                                     max_infiltration_rate / delta_t);
                infiltration_volume_rate <- current_infiltration_rate * cell_size * cell_size;
                total_infiltrated <- total_infiltrated + (current_infiltration_rate * delta_t * 1000.0); // Track in mm
            }
            
            // Total volume change rate
            float total_volume_change_rate <- net_flow + precipitation_volume_rate - evaporation_volume_rate - infiltration_volume_rate;
            
            // Convert to depth change using continuity equation: Δh/Δt = (volume change rate) / (cell area)
            float depth_change_rate <- total_volume_change_rate / (cell_size * cell_size);
            
            // Update water depth
            float new_depth <- water_depth + (depth_change_rate * delta_t);
            new_depth <- max(0.0, new_depth); // Prevent negative depths
            
            new_water_depth <- new_depth;
            new_water_elevation <- terrain_elevation + new_water_depth;
        }
        
        // STEP 3b: Process dry cells separately - check if they should receive water
        list<water_cell> newly_wet_cells <- [];
        ask water_cell parallel: true {
            if (water_depth <= 0.001) {
                // Check if any neighbors are flowing water to this cell
                int my_x <- int(grid_x);
                int my_y <- int(grid_y);
                
                float inflow <- 0.0;
                
                // Check inflow from neighbors
                if (my_x > 0) {
                    water_cell left_neighbor <- water_cell[my_x - 1, my_y];
                    inflow <- inflow + left_neighbor.Q_R;
                }
                if (my_x < (elevation_map.columns - 1)) {
                    water_cell right_neighbor <- water_cell[my_x + 1, my_y];
                    inflow <- inflow + right_neighbor.Q_L;
                }
                if (my_y < (elevation_map.rows - 1)) {
                    water_cell top_neighbor <- water_cell[my_x, my_y + 1];
                    inflow <- inflow + top_neighbor.Q_B;
                }
                if (my_y > 0) {
                    water_cell bottom_neighbor <- water_cell[my_x, my_y - 1];
                    inflow <- inflow + bottom_neighbor.Q_T;
                }
                
                // Add precipitation
                float precipitation_volume_rate <- (precipitation_rate / 1000.0 / 3600.0) * cell_size * cell_size;
                
                if (inflow > 0.0 or precipitation_volume_rate > 0.0) {
                    float total_volume_change_rate <- inflow + precipitation_volume_rate;
                    float depth_change_rate <- total_volume_change_rate / (cell_size * cell_size);
                    float new_depth <- depth_change_rate * delta_t;
                    
                    if (new_depth > 0.001) { // Only add if significant water
                        new_water_depth <- new_depth;
                        new_water_elevation <- terrain_elevation + new_water_depth;
                        newly_wet_cells <- newly_wet_cells + self;
                    } else {
                        new_water_depth <- 0.0;
                        new_water_elevation <- terrain_elevation;
                    }
                } else {
                    new_water_depth <- 0.0;
                    new_water_elevation <- terrain_elevation;
                }
            }
        }
        
        // STEP 4: Update all water depths and elevations simultaneously - OPTIMIZED
        list<water_cell> cells_to_remove <- [];
        
        ask water_cell {
            water_depth <- new_water_depth;
            water_elevation <- new_water_elevation;
            
            // Update water status efficiently
            if (water_depth > 0.001) {
                if (!is_water) {
                    is_water <- true;
                    // Don't add to active list here - will be done in batch below
                }
            } else {
                if (is_water) {
                    is_water <- false;
                    cells_to_remove <- cells_to_remove + self;
                }
            }
        }
        
        // BATCH UPDATE active water cells list (much faster than individual operations)
        active_water_cells <- active_water_cells - cells_to_remove;
        active_water_cells <- active_water_cells + newly_wet_cells;
        
        // OPTIMIZED field update - only update changed cells
        ask newly_wet_cells {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                water_field[field_i, field_j] <- water_elevation;
            }
        }
        
        ask cells_to_remove {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                water_field[field_i, field_j] <- terrain_elevation; // Show terrain when water disappears
            }
        }
        
        // Update existing water cells in field (less frequently for performance)
        if (simulation_step mod 3 = 0) {
            ask active_water_cells {
                int field_i <- int(grid_x);
                int field_j <- int(grid_y);
                
                if (field_i >= 0 and field_i < water_field.columns and 
                    field_j >= 0 and field_j < water_field.rows) {
                    water_field[field_i, field_j] <- water_elevation;
                }
            }
        }
        
        // Progress reporting - reduce frequency for performance
        if (simulation_step mod 100 = 0) {
            write "Step " + simulation_step + 
                  " | Time: " + with_precision(simulation_time, 2) + "h" +
                  " | Active cells: " + length(active_water_cells) +
                  " | New cells: " + length(newly_wet_cells) +
                  " | Removed cells: " + length(cells_to_remove);
        }
    }
    
    // Simulation reflex - runs at each cycle when active
    reflex flood_simulation when: water_simulation_active {
        do simulate_flood_step();
    }
    
    // Control actions
    action start_simulation {
        water_simulation_active <- true;
        write "=== ArcGIS Flood Simulation Started ===";
        write "Parameters:";
        write "  - Cell size: " + cell_size + "m";
        write "  - Time steps: Δt=" + delta_t + "s, ΔT=" + delta_T + "s";
        write "  - Precipitation: " + precipitation_rate + "mm/h";
        write "  - Infiltration: " + infiltration_rate + "mm/h";
        write "  - Boundary exit: " + allow_water_exit;
    }
    
    action stop_simulation {
        water_simulation_active <- false;
        write "Flood simulation stopped at step " + simulation_step + 
              " (time: " + with_precision(simulation_time, 2) + "h)";
    }
    
    action reset_simulation {
        water_simulation_active <- false;
        simulation_step <- 0;
        simulation_time <- 0.0;
        active_water_cells <- [];
        
        // Reset all water cells to initial state
        ask water_cell {
            terrain_elevation <- elevation_map[self.shape.location];
            
            bool cell_is_water <- not empty(water_geometries overlapping self.shape);
            
            if (cell_is_water) {
                is_water <- true;
                water_depth <- initial_water_depth;
                water_elevation <- terrain_elevation + water_depth;
                active_water_cells <- active_water_cells + self;
            } else {
                is_water <- false;
                water_depth <- 0.0;
                water_elevation <- terrain_elevation;
            }
            
            Q_L <- 0.0; Q_R <- 0.0; Q_T <- 0.0; Q_B <- 0.0;
            total_infiltrated <- 0.0;
        }
        
        // Reset water field - set to terrain elevation for dry cells, water elevation for wet cells
        ask water_cell {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                if (is_water) {
                    water_field[field_i, field_j] <- water_elevation; // Show water surface
                } else {
                    water_field[field_i, field_j] <- terrain_elevation; // Show terrain (no water visible)
                }
            }
        }
        
        write "Simulation reset to initial state";
    }
}

// Water grid cells with ArcGIS physics variables
grid water_cell width: elevation_map.columns height: elevation_map.rows parallel: true {
    // Water state
    bool is_water <- false;
    float water_depth <- 0.0; // Depth of water above terrain (d_ij)
    float water_elevation <- 0.0; // Absolute water surface elevation (h_ij)
    float terrain_elevation <- 0.0; // Terrain elevation (b_ij)
    
    // Flow rates in 4 cardinal directions (m³/s)
    float Q_L <- 0.0; // Left flow
    float Q_R <- 0.0; // Right flow  
    float Q_T <- 0.0; // Top flow
    float Q_B <- 0.0; // Bottom flow
    
    // Temporary variables for synchronized updates
    float new_Q_L <- 0.0;
    float new_Q_R <- 0.0;
    float new_Q_T <- 0.0;
    float new_Q_B <- 0.0;
    float new_water_depth <- 0.0;
    float new_water_elevation <- 0.0;
    
    // Infiltration tracking
    float total_infiltrated <- 0.0; // Total infiltration in mm
}

experiment ArcGISFloodSimulation type: gui {
    
    // Physics parameters
    parameter "Precipitation Rate (mm/h)" var: precipitation_rate min: 0.0 max: 50.0 step: 1.0;
    parameter "Evaporation Rate (mm/h)" var: evaporation_rate min: 0.0 max: 10.0 step: 0.5;
    parameter "Infiltration Rate (mm/h)" var: infiltration_rate min: 0.0 max: 20.0 step: 1.0;
    parameter "Max Infiltration (mm)" var: max_infiltration min: 0.0 max: 500.0 step: 10.0;
    parameter "Initial Water Depth (m)" var: initial_water_depth min: 0.1 max: 5.0 step: 0.1;
    parameter "Allow Water Exit" var: allow_water_exit;
    
    action _init_ {
        create simulation;
    }

    output {
        display "ArcGIS_Flood_Simulation_3D" type: opengl refresh: true {
            // Display DEM as mesh first (terrain)
            mesh elevation_map
                scale: 10
                grayscale: true
                smooth: false
                triangulation: true;

            // Display water as mesh - only show where there's actual water
            mesh water_field
                scale: 10
                color: rgb(0, 100, 255, 180) // Semi-transparent blue water
                smooth: false  
                triangulation: true;
                
            // Display water cells as agents for better visibility during rain
            ask water_cell {
                if (water_depth > 0.01) { // Only show cells with significant water
                    draw shape scaled_by 0.8 color: rgb(0, 150, 255, 100);
                }
            }
        }
        
        display "Simulation_Info" refresh: true {
            chart "Water Statistics" type: series {
                data "Active Water Cells" value: length(active_water_cells) color: #blue;
                data "Simulation Time (h)" value: simulation_time color: #red;
                data "Precipitation (mm/h)" value: precipitation_rate color: #green;
            }
        }
    }
    
    // User commands for controlling simulation
    user_command "Start Simulation" {
        ask simulation { do start_simulation(); }
    }
    
    user_command "Stop Simulation" {
        ask simulation { do stop_simulation(); }
    }
    
    user_command "Reset Simulation" {
        ask simulation { do reset_simulation(); }
    }
    
    user_command "Add Heavy Rain" {
        ask simulation { precipitation_rate <- 25.0; }
        write "Heavy rain activated: 25mm/h";
    }
    
    user_command "Stop Rain" {
        ask simulation { precipitation_rate <- 0.0; }
        write "Rain stopped";
    }
}