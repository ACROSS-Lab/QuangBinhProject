/**
* Name: DEMmodification
* Based on the internal skeleton template. 
* Author: patricktaillandier
* Tags: 
*/

model DEMmodification

global {
	/** Insert the global definitions, variables and actions here */
	grid_file terrain_small_grid_file <- grid_file("../../includes/dem/dem_small.tif");
	float max_value;
	float min_value;
	
	shape_file river_shape_file <- shape_file("../../includes/gis/river.shp");

	geometry shape <- envelope(terrain_small_grid_file);
	
	init {
		
			
		max_value <- cell max_of (each.grid_value);
		min_value <- cell min_of (each.grid_value);
			
		ask cell {
			if grid_value <= 0 {
				color <- #magenta;
			} else {
				int val <- int(255 * ( 1  - (grid_value - min_value) /(max_value - min_value)));
				color <- rgb(val,val,val);
			
			}
		}
		list<cell> cells_r <- cell where (each.grid_value = 0 and ((each.neighbors sum_of each.grid_value) =0));
			
		
		/*geometry g <- union(cells_r collect (each.shape +0.1));
		g <- simplification(g, 30.0) ;
		create river with: (shape : g);
		save river format:"shp" to: "../../includes/gis/river_clean.shp";*/
	}
}
species river {
	aspect default {
		draw shape color: #blue;
	}
}
grid cell file: terrain_small_grid_file;



experiment DEMmodification type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		
		display dem type: 3d{
			grid cell border: #black ;
			species river transparency: 0.5;
			
			event #mouse_down {
				using (topology(world)) {
					ask cell overlapping (circle(50) at_location #user_location) {
						grid_value <- grid_value + 1.0;
						
						int val <- int(255 * ( 1  - (grid_value - min_value) /(max_value - min_value)));
						color <- rgb(val,val,val);
							
						
						
					}
					do update_outputs(true);
				}
			}
			event "s" {
				using (topology(world)) {
					save cell format: "geotiff" to:"../../includes/dem/dem_small.tif";
				}
			}
			
		}
	}
}
