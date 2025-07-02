model CompleteArcGISFloodSimulation

global {
    // ============= CORE DATA FILES =============
    file dem_file <- file("../../includes/dem/terrain_large.tif");
    field elevation_map <- field(dem_file);
    geometry shape <- envelope(dem_file);

    // Water shapefile - initial water polygons
    file water_shapefile <- file("../../includes/gis/river_clean.shp");
    list<geometry> water_geometries <- [];

    // ============= ADDITIONAL ARCGIS DATA FILES =============
    // Optional raster files (set to nil if not used)
    file initial_water_depth_file <- nil; // Raster with initial water depths
    file infiltration_rate_file <- nil;   // Raster with spatially variable infiltration rates
    file max_infiltration_file <- nil;    // Raster with max infiltration values
    file buildings_shapefile <- nil;      // 3D buildings/obstacles shapefile
    
    // Optional vector files for dynamic features
    file water_sources_shapefile <- nil;  // Point/polygon water sources
    file channels_shapefile <- nil;       // Linear channels (cut through terrain)
    file barriers_shapefile <- nil;       // Linear barriers (raised terrain)

    // Create fields
    field water_field;
    field modified_elevation_map; // Terrain + buildings + barriers + channels
    field infiltration_rate_map;
    field max_infiltration_map;
    field initial_water_depth_map;
    
    // ============= ARCGIS PHYSICS PARAMETERS =============
    float gravity <- 9.81; // m/s²
    float cell_size; // Will be calculated from DEM
    float delta_t; // Internal time step for stability
    float delta_T; // External time step for progression
    
    // ============= FLOOD SIMULATION PARAMETERS =============
    float precipitation_rate <- 0.0; // mm/hr - can be changed during simulation
    float evaporation_rate <- 0.0; // mm/hr
    float infiltration_rate <- 2.0; // mm/hr - default soil infiltration (when no raster)
    float max_infiltration <- 100.0; // mm - maximum infiltration capacity (when no raster)
    
    // Initial water depth above terrain (when no raster)
    float initial_water_depth <- 1.5; // meters
    
    // Boundary conditions
    bool allow_water_exit <- true; // Water can flow out of boundaries
    
    // ============= DYNAMIC FEATURES =============
    list<geometry> water_source_geometries <- [];
    list<float> water_source_rates <- []; // m³/s for each source
    list<geometry> channel_geometries <- [];
    list<float> channel_widths <- [];
    list<float> channel_start_elevations <- [];
    list<float> channel_end_elevations <- [];
    list<geometry> barrier_geometries <- [];
    list<float> barrier_heights <- [];
    list<float> barrier_widths <- [];
    list<geometry> building_geometries <- [];
    list<float> building_heights <- [];
    
    // ============= SIMULATION STATE =============
    bool water_simulation_active <- false;
    int simulation_step <- 0;
    float simulation_time <- 0.0; // Total simulation time in hours
    
    // Performance tracking
    list<water_cell> active_water_cells <- [];

    // ============= INITIALIZATION =============
    init {
        write "=== Complete ArcGIS Flood Simulation Initialization ===";
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

        // ============= LOAD VECTOR DATA =============
        // Load initial water geometries
        water_geometries <- water_shapefile.contents;
        write "Number of initial water geometries loaded: " + length(water_geometries);

        // Load water sources (if file exists)
        if (water_sources_shapefile != nil) {
            water_source_geometries <- water_sources_shapefile.contents;
            // Initialize default flow rates (can be customized)
            loop i from: 0 to: length(water_source_geometries) - 1 {
                water_source_rates <- water_source_rates + 10.0; // Default 10 m³/s per source
            }
            write "Water sources loaded: " + length(water_source_geometries);
        }

        // Load channels (if file exists)
        if (channels_shapefile != nil) {
            channel_geometries <- channels_shapefile.contents;
            // Initialize default parameters (can be customized)
            loop i from: 0 to: length(channel_geometries) - 1 {
                channel_widths <- channel_widths + 5.0; // Default 5m width
                channel_start_elevations <- channel_start_elevations + 0.0; // Will be calculated
                channel_end_elevations <- channel_end_elevations + 0.0; // Will be calculated
            }
            write "Channels loaded: " + length(channel_geometries);
        }

        // Load barriers (if file exists)
        if (barriers_shapefile != nil) {
            barrier_geometries <- barriers_shapefile.contents;
            // Initialize default parameters
            loop i from: 0 to: length(barrier_geometries) - 1 {
                barrier_heights <- barrier_heights + 2.0; // Default 2m height
                barrier_widths <- barrier_widths + 1.0; // Default 1m width
            }
            write "Barriers loaded: " + length(barrier_geometries);
        }

        // Load buildings (if file exists)
        if (buildings_shapefile != nil) {
            building_geometries <- buildings_shapefile.contents;
            // Initialize default building heights
            loop i from: 0 to: length(building_geometries) - 1 {
                building_heights <- building_heights + 10.0; // Default 10m height
            }
            write "Buildings loaded: " + length(building_geometries);
        }

        // ============= CREATE MODIFIED ELEVATION MAP =============
        write "Creating modified elevation map (WYSIWYG approach)...";
        modified_elevation_map <- copy(elevation_map);
        
        // Add buildings to elevation
        if (length(building_geometries) > 0) {
            ask water_cell {
                float base_elevation <- elevation_map[self.shape.location];
                float max_building_height <- 0.0;
                
                loop i from: 0 to: length(building_geometries) - 1 {
                    if (building_geometries[i] overlaps self.shape) {
                        max_building_height <- max(max_building_height, building_heights[i]);
                    }
                }
                
                if (max_building_height > 0.0) {
                    int field_i <- int(grid_x);
                    int field_j <- int(grid_y);
                    modified_elevation_map[field_i, field_j] <- base_elevation + max_building_height;
                }
            }
            write "Buildings added to elevation map";
        }
        
        // Add barriers to elevation
        if (length(barrier_geometries) > 0) {
            ask water_cell {
                float current_elevation <- modified_elevation_map[int(grid_x), int(grid_y)];
                float max_barrier_height <- 0.0;
                
                loop i from: 0 to: length(barrier_geometries) - 1 {
                    if (barrier_geometries[i] distance_to self.shape <= barrier_widths[i] / 2.0) {
                        max_barrier_height <- max(max_barrier_height, barrier_heights[i]);
                    }
                }
                
                if (max_barrier_height > 0.0) {
                    int field_i <- int(grid_x);
                    int field_j <- int(grid_y);
                    modified_elevation_map[field_i, field_j] <- current_elevation + max_barrier_height;
                }
            }
            write "Barriers added to elevation map";
        }
        
        // Cut channels into elevation
        if (length(channel_geometries) > 0) {
            loop i from: 0 to: length(channel_geometries) - 1 {
                geometry channel <- channel_geometries[i];
                list<point> channel_points <- channel.points;
                
                if (length(channel_points) >= 2) {
                    point start_point <- channel_points[0];
                    point end_point <- channel_points[length(channel_points) - 1];
                    
                    // Get start and end elevations
                    float start_elev <- elevation_map[start_point];
                    float end_elev <- elevation_map[end_point];
                    channel_start_elevations[i] <- start_elev;
                    channel_end_elevations[i] <- end_elev;
                    
                    // Cut channel through terrain
                    ask water_cell {
                        if (channel distance_to self.shape <= channel_widths[i] / 2.0) {
                            float distance_ratio <- (channel distance_to start_point) / (channel distance_to start_point + channel distance_to end_point);
                            float channel_elevation <- start_elev + (end_elev - start_elev) * distance_ratio;
                            
                            int field_i <- int(grid_x);
                            int field_j <- int(grid_y);
                            float current_elev <- modified_elevation_map[field_i, field_j];
                            modified_elevation_map[field_i, field_j] <- min(current_elev, channel_elevation);
                        }
                    }
                }
            }
            write "Channels cut into elevation map";
        }

        // ============= LOAD RASTER DATA =============
        // Load initial water depth raster
        if (initial_water_depth_file != nil) {
            initial_water_depth_map <- field(initial_water_depth_file);
            write "Initial water depth raster loaded";
        } else {
            initial_water_depth_map <- field(elevation_map.columns, elevation_map.rows);
            initial_water_depth_map <- initial_water_depth_map * 0 + initial_water_depth;
            write "Using uniform initial water depth: " + initial_water_depth + "m";
        }

        // Load infiltration rate raster
        if (infiltration_rate_file != nil) {
            infiltration_rate_map <- field(infiltration_rate_file);
            write "Infiltration rate raster loaded";
        } else {
            infiltration_rate_map <- field(elevation_map.columns, elevation_map.rows);
            infiltration_rate_map <- infiltration_rate_map * 0 + infiltration_rate;
            write "Using uniform infiltration rate: " + infiltration_rate + "mm/h";
        }

        // Load max infiltration raster
        if (max_infiltration_file != nil) {
            max_infiltration_map <- field(max_infiltration_file);
            write "Max infiltration raster loaded";
        } else {
            max_infiltration_map <- field(elevation_map.columns, elevation_map.rows);
            max_infiltration_map <- max_infiltration_map * 0 + max_infiltration;
            write "Using uniform max infiltration: " + max_infiltration + "mm";
        }

        // Create water field
        water_field <- field(elevation_map.columns, elevation_map.rows);
        write "Water field created";

        // ============= INITIALIZE WATER CELLS =============
        int water_cell_count <- 0;
        
        ask water_cell {
            // Get terrain elevation from modified elevation map (includes buildings, barriers, channels)
            terrain_elevation <- modified_elevation_map[int(grid_x), int(grid_y)];
            
            // Get cell-specific parameters from rasters
            cell_infiltration_rate <- infiltration_rate_map[int(grid_x), int(grid_y)];
            cell_max_infiltration <- max_infiltration_map[int(grid_x), int(grid_y)];
            
            // Check if this cell contains initial water
            bool cell_is_water <- not empty(water_geometries overlapping self.shape);
            
            if (cell_is_water) {
                is_water <- true;
                // Get initial water depth from raster
                water_depth <- initial_water_depth_map[int(grid_x), int(grid_y)];
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
        
        // Initialize water field - ONLY for cells with actual water
        water_field <- water_field * 0;
        ask water_cell {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                if (is_water) {
                    water_field[field_i, field_j] <- water_elevation;
                } else {
                    water_field[field_i, field_j] <- 0.0; // No water = 0
                }
            }
        }
        
        write "=== Complete ArcGIS Initialization Complete ===";
        write "Features enabled:";
        write "  - Water sources: " + length(water_source_geometries);
        write "  - Channels: " + length(channel_geometries);
        write "  - Barriers: " + length(barrier_geometries);
        write "  - Buildings: " + length(building_geometries);
        write "  - Variable infiltration: " + (infiltration_rate_file != nil);
        write "  - Variable initial depth: " + (initial_water_depth_file != nil);
        write "Ready for complete ArcGIS-based flood simulation";
    }
    
    // ============= MAIN SIMULATION STEP =============
    action simulate_flood_step {
        simulation_step <- simulation_step + 1;
        simulation_time <- simulation_time + (delta_T / 3600.0); // Convert to hours
        
        // STEP 1: Calculate flow rate changes using momentum equation - UNIFIED PROCESSING
        // Process ALL cells uniformly (ArcGIS approach)
        ask water_cell parallel: true {
            if (water_depth > 0.001) { // Only calculate flows for cells with significant water
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
            } else {
                // No water, no flow
                new_Q_L <- 0.0; new_Q_R <- 0.0; new_Q_T <- 0.0; new_Q_B <- 0.0;
            }
        }
        
        // STEP 2: Update all flow rates simultaneously
        ask water_cell {
            Q_L <- new_Q_L; Q_R <- new_Q_R; Q_T <- new_Q_T; Q_B <- new_Q_B;
        }
        
        // STEP 3: Calculate water elevation changes using continuity equation - UNIFIED PROCESSING
        // Process ALL cells uniformly (ArcGIS approach)
        list<water_cell> newly_wet_cells <- [];
        ask water_cell parallel: true {
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
            
            // NEW: Add water sources (S) - ArcGIS Feature
            float source_input <- 0.0;
            if (length(water_source_geometries) > 0) {
                loop i from: 0 to: length(water_source_geometries) - 1 {
                    geometry source_geom <- water_source_geometries[i];
                    
                    // Check if this cell is within the water source
                    if (source_geom overlaps self.shape or source_geom distance_to self.shape <= 5.0) {
                        // For point sources: distribute over 5m radius
                        // For area sources: distribute over area
                        if (source_geom.area < 100.0) { // Point source
                            source_input <- source_input + (water_source_rates[i] / 25.0); // Distribute over ~25 cells
                        } else { // Area source
                            float overlap_ratio <- (source_geom intersection self.shape).area / self.shape.area;
                            source_input <- source_input + (water_source_rates[i] * overlap_ratio / source_geom.area * cell_size * cell_size);
                        }
                    }
                }
            }
            
            // Calculate net volume change per unit time
            float outflow <- Q_L + Q_R + Q_T + Q_B;
            float net_flow <- inflow - outflow + source_input; // m³/s
            
            // Add precipitation (convert mm/hr to m/s)
            float precipitation_volume_rate <- (precipitation_rate / 1000.0 / 3600.0) * cell_size * cell_size;
            
            // Subtract evaporation (convert mm/hr to m/s)
            float evaporation_volume_rate <- (evaporation_rate / 1000.0 / 3600.0) * cell_size * cell_size;
            
            // NEW: Variable infiltration (F) - ArcGIS Feature
            float infiltration_volume_rate <- 0.0;
            if (water_depth > 0.0 and total_infiltrated < cell_max_infiltration) {
                float max_infiltration_rate <- (cell_max_infiltration - total_infiltrated) / 1000.0; // Convert to meters
                float current_infiltration_rate <- min(cell_infiltration_rate / 1000.0 / 3600.0, 
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
            
            // Track cells that become wet
            if (water_depth <= 0.001 and new_water_depth > 0.001) {
                newly_wet_cells <- newly_wet_cells + self;
            }
        }
        
        // STEP 4: Update all water depths and elevations simultaneously - UNIFIED PROCESSING
        list<water_cell> cells_to_remove <- [];
        
        ask water_cell {
            water_depth <- new_water_depth;
            water_elevation <- new_water_elevation;
            
            // Update water status efficiently
            if (water_depth > 0.001) {
                if (!is_water) {
                    is_water <- true;
                }
            } else {
                if (is_water) {
                    is_water <- false;
                    cells_to_remove <- cells_to_remove + self;
                }
            }
        }
        
        // REBUILD active water cells list from scratch (more reliable than incremental updates)
        active_water_cells <- [];
        ask water_cell {
            if (water_depth > 0.001) {
                active_water_cells <- active_water_cells + self;
            }
        }
        
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
                water_field[field_i, field_j] <- 0.0;
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
                  " | Sources active: " + length(water_source_geometries);
        }
    }
    
    // Simulation reflex - runs at each cycle when active
    reflex flood_simulation when: water_simulation_active {
        do simulate_flood_step();
    }
    
    // ============= CONTROL ACTIONS =============
    action start_simulation {
        water_simulation_active <- true;
        write "=== Complete ArcGIS Flood Simulation Started ===";
        write "Parameters:";
        write "  - Cell size: " + cell_size + "m";
        write "  - Time steps: Δt=" + delta_t + "s, ΔT=" + delta_T + "s";
        write "  - Precipitation: " + precipitation_rate + "mm/h";
        write "  - Water sources: " + length(water_source_geometries);
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
            terrain_elevation <- modified_elevation_map[int(grid_x), int(grid_y)];
            cell_infiltration_rate <- infiltration_rate_map[int(grid_x), int(grid_y)];
            cell_max_infiltration <- max_infiltration_map[int(grid_x), int(grid_y)];
            
            bool cell_is_water <- not empty(water_geometries overlapping self.shape);
            
            if (cell_is_water) {
                is_water <- true;
                water_depth <- initial_water_depth_map[int(grid_x), int(grid_y)];
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
        
        // Reset water field - ONLY for cells that actually have water
        water_field <- water_field * 0;
        ask water_cell {
            int field_i <- int(grid_x);
            int field_j <- int(grid_y);
            
            if (field_i >= 0 and field_i < water_field.columns and 
                field_j >= 0 and field_j < water_field.rows) {
                if (is_water) {
                    water_field[field_i, field_j] <- water_elevation;
                } else {
                    water_field[field_i, field_j] <- 0.0; // No water = 0
                }
            }
        }
        
        write "Simulation reset to initial state";
    }
    
    // ============= DYNAMIC CONFIGURATION ACTIONS =============
    action add_water_source(point location, float flow_rate) {
        water_source_geometries <- water_source_geometries + circle(5.0) at_location location;
        water_source_rates <- water_source_rates + flow_rate;
        write "Water source added at " + location + " with rate " + flow_rate + " m³/s";
    }
    
    action modify_water_source_rate(int source_index, float new_rate) {
        if (source_index >= 0 and source_index < length(water_source_rates)) {
            water_source_rates[source_index] <- new_rate;
            write "Water source " + source_index + " rate changed to " + new_rate + " m³/s";
        }
    }
    
    action add_barrier(list<point> path_points, float height, float width) {
        if (length(path_points) >= 2) {
            barrier_geometries <- barrier_geometries + polyline(path_points);
            barrier_heights <- barrier_heights + height;
            barrier_widths <- barrier_widths + width;
            
            // Update elevation map for new barrier
            geometry new_barrier <- polyline(path_points);
            ask water_cell {
                if (new_barrier distance_to self.shape <= width / 2.0) {
                    int field_i <- int(grid_x);
                    int field_j <- int(grid_y);
                    float current_elevation <- modified_elevation_map[field_i, field_j];
                    modified_elevation_map[field_i, field_j] <- current_elevation + height;
                    terrain_elevation <- modified_elevation_map[field_i, field_j];
                }
            }
            
            write "Barrier added with height " + height + "m and width " + width + "m";
        }
    }
    
    action remove_all_water_sources {
        water_source_geometries <- [];
        water_source_rates <- [];
        write "All water sources removed";
    }
}

// ============= ENHANCED WATER GRID CELLS =============
grid water_cell width: elevation_map.columns height: elevation_map.rows parallel: true {
    // Water state
    bool is_water <- false;
    float water_depth <- 0.0; // Depth of water above terrain (d_ij)
    float water_elevation <- 0.0; // Absolute water surface elevation (h_ij)
    float terrain_elevation <- 0.0; // Terrain elevation (b_ij) - includes buildings, barriers, channels
    
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
    
    // Cell-specific parameters (from rasters)
    float cell_infiltration_rate <- 0.0; // mm/hr - varies by cell
    float cell_max_infiltration <- 0.0; // mm - varies by cell
    float total_infiltrated <- 0.0; // Total infiltration in mm
}

experiment CompleteArcGISFloodSimulation type: gui {
    
    // ============= PARAMETERS =============
    // Physics parameters
    parameter "Precipitation Rate (mm/h)" var: precipitation_rate min: 0.0 max: 50.0 step: 1.0;
    parameter "Evaporation Rate (mm/h)" var: evaporation_rate min: 0.0 max: 10.0 step: 0.5;
    parameter "Default Infiltration Rate (mm/h)" var: infiltration_rate min: 0.0 max: 20.0 step: 1.0;
    parameter "Default Max Infiltration (mm)" var: max_infiltration min: 0.0 max: 500.0 step: 10.0;
    parameter "Default Initial Water Depth (m)" var: initial_water_depth min: 0.1 max: 5.0 step: 0.1;
    parameter "Allow Water Exit" var: allow_water_exit;
    
    // File parameters (optional - set paths to enable features)
    parameter "Initial Water Depth Raster" var: initial_water_depth_file;
    parameter "Infiltration Rate Raster" var: infiltration_rate_file;
    parameter "Max Infiltration Raster" var: max_infiltration_file;
    parameter "Buildings Shapefile" var: buildings_shapefile;
    parameter "Water Sources Shapefile" var: water_sources_shapefile;
    parameter "Channels Shapefile" var: channels_shapefile;
    parameter "Barriers Shapefile" var: barriers_shapefile;
    
    action _init_ {
        create simulation;
    }

    output {
        display "Complete_ArcGIS_Flood_3D" type: opengl refresh: true {
            // Display modified DEM as mesh (terrain + buildings + barriers + channels)
            mesh modified_elevation_map
                scale: 10
                grayscale: true
                smooth: false
                triangulation: true;

            // Display water as mesh - complete physics-based water flow
            mesh water_field
                scale: 10
                color: rgb(0, 100, 255, 150) // Semi-transparent blue water
                smooth: false  
                triangulation: true;
                
            // Optional: Display water sources as red spheres
            species water_source aspect: base;
        }
        
        display "Enhanced_Simulation_Info" refresh: true {
            chart "Water Statistics" type: series {
                data "Active Water Cells" value: length(active_water_cells) color: #blue;
                data "Simulation Time (h)" value: simulation_time color: #red;
                data "Water Sources" value: length(water_source_geometries) color: #green;
            }
        }
        
//        display "Infiltration_Map" refresh: false {
//            mesh infiltration_rate_map 
//                color: palette([#white, #brown])
//                scale: 1
//                triangulation: true;
//        }
    }
    
    // ============= USER COMMANDS =============
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
    
    user_command "Add Water Source (10m³/s)" {
        ask simulation { do add_water_source(#user_location, 10.0); }
    }
    
    user_command "Add Large Water Source (50m³/s)" {
        ask simulation { do add_water_source(#user_location, 50.0); }
    }
    
    user_command "Remove All Water Sources" {
        ask simulation { do remove_all_water_sources(); }
    }
    
    user_command "Emergency Barrier (2m high)" {
        list<point> barrier_path <- [#user_location + {-50, 0}, #user_location + {50, 0}];
        ask simulation { do add_barrier(barrier_path, 2.0, 2.0); }
    }
}

// Optional species for visualizing water sources
species water_source {
    aspect base {
        draw sphere(5) color: #red;
    }
}