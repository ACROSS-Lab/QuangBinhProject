/**
* Name: CreateSynthethicEnvironment
* Based on the internal skeleton template. 
* Author: patricktaillandier
* Tags: 
*/

model CreateSynthethicEnvironment

global {
	
	map<map<string, unknown>,float> building_proportions <- [
		["width"::10.0, "height":: 5.0, "color":: #yellow] :: 0.2,
		["width"::20.0, "height":: 10.0, "color":: #violet] :: 0.2,
		
		["width"::15.0, "height":: 15.0, "color":: #cyan] :: 0.2,
		["width"::20.0, "height":: 20.0, "color":: #magenta] :: 0.2,
		
		["width"::30.0, "height":: 30.0, "color":: #green] :: 0.2,
		["width"::50.0, "height":: 20.0, "color":: #blue] :: 0.1,
		["width"::100.0, "height":: 30.0, "color":: #orange] :: 0.05,
		["width"::30.0, "height":: 40.0, "color":: #magenta] :: 0.1
	];
	
	float dem_threshold <- 0.0;
	float dem_value_river <- -10.0;
	
	float max_density_building <- 0.05;
	
	
	
	file buildings_shapefile <- file("../../includes/gis/buildings.shp");
	file dem_file <- file("../../includes/dem/terrain89x211.asc");
	
	geometry shape <- envelope(file("../../includes/gis/QBBB.shp"));

	
	init {
		loop v over: building_proportions.keys {
			float w <- float(v["width"]);
			float h <- float(v["height"]);
			rgb c <- rgb(v["color"]);
			create building_template with: (width: w, height:h, color: c);
		
		}
		
		create building from: buildings_shapefile;
		
		do filter_dem;
		do generate_unity_building;
		
	}
	
	action filter_dem {
		list<cell> diffusion <- cell where ((each.grid_value <= dem_threshold) and (each.shape overlaps world.shape.contour));
		loop while: not empty(diffusion) {
			list<cell> cs;
			ask diffusion {
				grid_value <- dem_value_river;
				
			}
			ask diffusion {
				cs <- cs + neighbors where ((each.grid_value > dem_value_river) and (each.grid_value <= dem_threshold )) ;
		
			}
			diffusion <- remove_duplicates(cs);
		}
		ask cell where (each.grid_value != dem_value_river) {
			grid_value <- 0.0;
		}	 
	}
	action generate_unity_building {
		
		ask building {
			float current_density <- 0.0;
			map<map<string, unknown>,float> building_proportions_tmp <- copy( building_proportions);
			loop while: current_density <  max_density_building {
				map<string, unknown> bd_to_generate <-  building_proportions_tmp.keys[rnd_choice(building_proportions_tmp.values)];
				float w <- float(bd_to_generate["width"]);
				float h <- float(bd_to_generate["height"]);
				float bd_area <- w *h ;
				bool is_ok <- false;
				float orientation <- 0.0;
				float l;
				geometry gc<- (shape) simplification 2.0;
				loop i from: 0 to: length(gc.points) - 2 {
					float dist <- gc.points[i] distance_to  gc.points[i+1];
					if (dist > l) {
						l <- dist;
						orientation <- gc.points[i] towards  gc.points[i+1];
					}
				}
				
				
				geometry g <- remaining_shape - (min(h,w) );
				if (g != nil) {
					int cpt <- 0;
					loop while: not is_ok and cpt < 100 {
						cpt <- cpt +1;
						geometry rect <- rectangle(w,h) at_location (any_location_in(g));
						rect <- rect rotated_by orientation;
						if (remaining_shape covers rect) {
							create unity_building with:(color: rgb(bd_to_generate["color"]), shape: rect) {
								myself.remaining_shape <- myself.remaining_shape - shape;
								current_density <- 1 - (myself.remaining_shape.area/myself.shape.area);
								is_ok <- true;
							}	
														
						} else {
							
					
						}
					
					}
				}
						
				if not is_ok {
					remove key:bd_to_generate from: building_proportions_tmp;
					if (empty(building_proportions_tmp)) {
						break;
					}
				}
			
			}
			
		}
		
	}
}

species building_template {
	float proportion;
	float width;
	float height;
	rgb color;
	
}

species building {
	geometry remaining_shape <- copy(shape);
	 aspect default {
	 	draw shape color: #lightgray;
	 	
	 	
	 }	
}

species unity_building {
	rgb color;
	aspect default {
 		draw shape color: color;
 	}	
}
grid cell file: dem_file neighbors: 8;



experiment CreateSynthethicEnvironment type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display map {
			mesh cell grayscale: true triangulation: true scale: 10;
			species building;
			species unity_building;
		}
		display dem type: 3d{
			mesh cell grayscale: true triangulation: true scale: 10;
		}
	}
}
