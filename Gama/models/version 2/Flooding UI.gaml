/**
* Name: FloodingUI
* A simple UI experiment to demonstrate the flooding in Quang Binh province 
* Author: Alexis Drogoul (with SpreadingSkill backend integration)
* Tags:   
*/

model FloodingUI 
  
import "Flooding Model.gaml"

global {   
	
	/*************************************************************
	 * UI Variables (from original UI)
	 *************************************************************/
	
	bool button_selected;
	bool check_selected;
	bool is_ok_dyke_construction <- false;
	   

	/************************************************************* 
	 * Functions that control the transitions between the states
	 *************************************************************/

	action enter_init {
	//	write "enter_init"; 
		do enter_init_base;
		   
		ask buildings {
			color <- one_of(building_colors); 
		} 
		// button_frame <- nil;
		// check_frame <- nil; 
		button_image_unselected <- nil;
		button_image_selected <- nil; 
		check_image_unselected <- nil;
		check_image_selected <- nil;  		
	}  
	
	action enter_start {
	}
	 
	action enter_diking {
		
		diking_over <- false;
		current_timeout <- gama.machine_time + diking_duration * 1000;
	}
	
	action enter_flooding {
		do enter_flooding_base;
		restart_requested <- false;	
	}
	
	action exit_flooding {
		float t <- gama.machine_time + (waiting_time_in_s * 1000);
		loop while: gama.machine_time < t {
			
		}
		do exit_flooding_base;
	}
	
	action exit_init {
		float t <- gama.machine_time + (waiting_time_in_s * 1000);
		loop while: gama.machine_time < t {
			
		}
	}  
	
 
	bool init_over  { 
		return (current_step > num_step) or restart_requested ;
	} 
	 
	bool diking_over { 
	//	write sample((current_timeout - gama.machine_time )/1000.0);
		return diking_over or gama.machine_time >= current_timeout;
	}
	
	bool flooding_over  { 
		return  (current_step > num_step) or restart_requested ;
	}	
	
	bool flooding_ready {
		return true;
	} 
	
	bool start_over {
		return true;
	}
	action body_init  {	
		
	}
	
	action body_flooding {
		
		
	}
	 
	/*************************************************************
	 * Flags to control the phases in the simulations
	 *************************************************************/

	// Is a restart requested by the user ? 
	bool restart_requested; 
	
	// Is the flooding state requested by the user ? 
	bool diking_over; 
	 
	
	
	/*************************************************************
	 * Reflex to update the color of the cells depending on their water height 
	 *************************************************************/

	reflex update_cell_colors {
		float max_water_height <- max(cell collect each.water_height);
		ask cell {
			if (water_height <= 0.01) { 
				color <- #transparent;
			} else {
				float val_water <-  255 * (1 - (water_height / max_water_height));
				color <- rgb([val_water/8, val_water/3, 150]);
			}
			grid_value <- water_height;
		}
	}
	
	
}

experiment Run  type:gui autorun: true{
	float minimum_cycle_duration <- cycle_duration;
	
	point start_point; 
	point end_point;  
	geometry line; 
	  
	output { 
		
		layout #none controls: false toolbars: false editors: false parameters: false consoles: false tabs: false;
		display map type: 3d axes: false background: background_color antialias: false{
			camera 'default' location: {1441.2246,3297.5234,8595.6544} target: {1441.2246,3297.3733,0.0};
			
			// NEW: Add mesh visualization for terrain (DEM)
			mesh dem_file scale: 20 triangulation: true grayscale: true transparency: 0.1 refresh: false;
			
			// NEW: Add mesh visualization for water field (from SpreadingSkill)
			mesh display_water_field scale: 20 triangulation: true color: rgb(0, 100, 255, 180) refresh: true;
			
			// NEW: Add mesh visualization for dyke field (from SpreadingSkill)  
			mesh display_dyke_field scale: 20 triangulation: true color: rgb(139, 69, 19, 255) refresh: true;
				
			//	grid cell border: #black;
	

			species road {
				draw drowned ? shape : shape + 10 color: drowned ? darker(river_color) : road_color at:{location.x, location.y, elevation_map[location] + 20} ;
			}
		 	species buildings {
		 		draw shape color: drowned ? river_color : color border: drowned ? darker(river_color):color at:{location.x, location.y, elevation_map[location] + 20};	
		 	} 
		 	graphics "end_of_world" {
				loop d over: water_limit_danger {
					draw d + 20 color: #red;
				}
				loop d over: water_limit_well {
					draw d + 20 color: #orange;
				}
				loop d over: water_limit_drain {
					draw d + 20 color: #green;
				}
			}   
		 	// Note: dyke species visualization removed since SpreadingSkill handles dykes internally
		 	// Dykes are now visualized through the dyke_field in the backend
		 	
			species people  {
				draw circle(20)  color: (state = "s_drowned" ? people_drowned_color : (state = "s_evacuated" ?  people_evacuated_color : people_color)) at:{location.x, location.y, elevation_map[location] + 20}; 
			 	
			}
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: evacuation_color border: #black;
			}

			//mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D transparency: 0.5;
			//species water_particule; 
			
			event "r" {
				if (state != "s_diking") { return;}
				if (start_point != nil) {
					start_point <- nil;
					line <- nil;
				} else { 
					ask world {
						// Note: Dyke removal now handled differently with SpreadingSkill
						// For now, use clear_all_dykes as approximation
						if (get_active_dyke_count() > 0) {
							do clear_all_dykes();
							write "All dykes cleared (SpreadingSkill)";
						}
					}
					 
				}
				
			} 
			event #mouse_down {
				if (button_selected) {
					if (state = "s_diking") {diking_over <- true; start_point <- nil; end_point<- nil; return;} else
					if (state = "s_flooding") {restart_requested <- true; start_point <- nil; end_point<- nil;return;}
				}
				if (check_selected) {
					keep_dykes <- !keep_dykes;
				}
				if (state != "s_diking") { return;}
				if (start_point = nil) {
		 			start_point <- #user_location; 
					line <- line([start_point, #user_location]);
				} else {
					ask simulation {
						// UPDATED: Use SpreadingSkill's build_dyke method instead of create_dyke
						bool success <- build_dyke(myself.start_point, #user_location);
						if (success) {
							write "Dyke built using SpreadingSkill";
						} else {
							write "Failed to build dyke";
						}
					}
					start_point <- nil;
				 	end_point <- nil;
				}

			}
			
			graphics "Arrow" {
				draw image_file("../../includes/icons/arrow-23645_1280.png") size: 400 rotate: -90 at: {location.x/1.75, location.y *2 - 200};

			}
			
			
			graphics "General information" {
				int offset <- 0;
				draw rectangle(3500,1000) color: #gray border: #black at: {5000, 700+offset, -1.0};
				draw "General information" font: font ("Helvetica", 22, #bold) at: {3400, 300+offset} anchor: #top_left color: text_color;	
				
				
				draw "Round: " + current_round+"/" + num_rounds font: font ("Helvetica", 18, #bold) at: {3400, 600+offset} anchor: #top_left color: text_color;
				
				if  current_round > 1 {
					draw "best score: " +  round(best_score) font: font ("Helvetica", 18, #bold) at: {3400, 900+offset} anchor: #top_left color: text_color;
				
				}	
				
			}
			graphics "Hints" {
				if current_round = num_rounds {
					int offset <- 1500;
					draw rectangle(3500,1200) + 50 color: #lightgreen border: #black at: {5000, 800+offset, -2.0};
					draw rectangle(3500,1200) color: #gray border: #black at: {5000, 800+offset, -1.0};
					
					draw "Hint" font: font ("Helvetica", 22, #bold) at: {3400, 300+offset} anchor: #top_left color: #lightgreen;	
					string hint <- "One strategy to combat flooding is the developmentof flood\n\nexpansion zones. This involves designating an area where\n\nfloodwaters from a watercourse can spread quickly with minimal\n\nrisk to people and property";
					
					
					draw hint font: font ("Helvetica", 14, #bold) at: {3400, 600+offset} anchor: #top_left color: text_color;
					
				}				
			}
			
			
			
			
			graphics "Legend" {
				int offset <- 500;
				draw rectangle(3500,2500) color: #gray border: #black at: {-1870, 2650+offset, -1.0};
				draw "Legend" font: font ("Helvetica", 22, #bold) at: {-3500, 1500+offset} anchor: #top_left color: text_color;	
				
				draw  image_file("../../includes/icons/arrow-23645_1280.png") size: 180 rotate: -90  border: #black at: {-3450, 1850+offset};
				draw "Direction of river flow" font: font ("Helvetica", 14, #bold) at: {-3300, 1800+offset} anchor: #top_left color: text_color;	
				
				draw line([{-3500, 2100+offset},{-3400, 2100+offset}]) + 20 color: #green ;
				draw "Drain-type border (water run-off)" font: font ("Helvetica", 14, #bold) at: {-3300, 2060+offset} anchor: #top_left color: text_color;	
				draw line([{-3500, 2300+offset},{-3400, 2300+offset}]) + 20 color: #orange ;
				
				draw "Well-type border (prevents water run-off)" font: font ("Helvetica", 14, #bold) at: {-3300, 2260+offset} anchor: #top_left color: text_color;	
				
				draw line([{-3500, 2500+offset},{-3400, 2500+offset}]) + 20 color: #red ;
				draw "Stake-type border (prevents water run-off and leads to point loss)" font: font ("Helvetica", 14, #bold) at: {-3300, 2460+offset} anchor: #top_left color: text_color;	
				
				
				draw line([{-3500, 2800+offset},{-3400, 2800+offset}]) + 20 color: dyke_color border: #black;
				draw "Dyke - price : 1 point / meter" font: font ("Helvetica", 14, #bold) at: {-3300, 2760+offset} anchor: #top_left color: text_color;	
				draw line([{-3500, 3000+offset},{-3400, 3000+offset}]) + 20 color: dam_color border: #black;
				draw "Dam - price : 10 points / meter" font: font ("Helvetica", 14, #bold) at: {-3300, 2960+offset} anchor: #top_left color: text_color;	
				
				draw circle(30)  color: people_color at:  {-3450, 3300+offset} ; 
				draw "People evacuating" font: font ("Helvetica", 14, #bold) at: {-3300, 3260+offset} anchor: #top_left color: text_color;	
				draw circle(30)  color: people_drowned_color at:  {-3450, 3500+offset} ; 
				draw "People injured" font: font ("Helvetica", 14, #bold) at: {-3300, 3460+offset} anchor: #top_left color: text_color;	
				
				draw circle(60)  color: evacuation_color at:  {-3450, 3700+offset} ; 
				draw "Shelter (evacuation point)" font: font ("Helvetica", 14, #bold) at: {-3300, 3660+offset} anchor: #top_left color: text_color;	
				
			
			}
			
			graphics "Text and icon"   {
					
				
				string stage <- nil;
				string timer <- nil;
				string hint <- nil;
				string indicators <- nil;
				
				rgb color_indicators <- text_color;
								 
				switch (state) {
					match "s_init" {
						stage <-  "Flood without dykes/dams";
						
						//\n\n" + "Casualties: " + casualties + '/' + nb_of_people;
						timer <- "End in " +max(0,(num_step - current_step)) + " minutes";
						indicators <- "Casualties: " + casualties + '/' + nb_of_people + "\n\nScore: " + round(score);
						if (score <= 900 and score > 700) or (casualties > 0 and casualties< 10){
							color_indicators <- #yellow;
						} else if (score <= 700 and score > 500) or (casualties >= 10 and casualties< 100) {
							color_indicators <- #orange;
						} else if (score <= 500) or (casualties > 100)   {
							color_indicators <- #red;
						} else {
							color_indicators <- #lightgreen;
						}
						
						//float left <- current_timeout - gama.machine_time;
						//timer <- button_selected ? "Restart now.": "Restarting in " + int(left / 1000) + " seconds.";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
					match "s_diking" { 
						stage <-  "Build dykes/dams";
						// UPDATED: Use SpreadingSkill dyke count instead of length
						indicators <- "Active dykes: "+ get_active_dyke_count() + " cells" + "\n\nWater cells: "+ get_active_water_count();
					
						//text <- "Build dykes/dams with the mouse.\n\n\tMeters of dyke built: "+ round(dyke_length) + "m" + "\n\n\tMeters of dam built: "+ round(dam_length) + "m";
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + max(0,int(left / 1000)) + " seconds.";
						hint <- "Press 'r' to remove all dykes\nPress 'f' for skipping.";
						
						//\nPress 'f' to start immediately.";
					}	
					match "s_flooding" {
						 
						stage <-  "Flood";
						indicators <- "Casualties: " + casualties + '/' + nb_of_people + "\n\nScore: " + round(score);
						
						//text <- "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//hint <- "Press 'r' for restarting.";
						timer <- "End in " +max(0,(num_step - current_step)) + " minutes";
						
						if (score <= 900 and score > 700) or (casualties > 0 and casualties< 10){
							color_indicators <- #yellow;
						} else if (score <= 700 and score > 500) or (casualties >= 10 and casualties< 100) {
							color_indicators <- #orange;
						} else if (score <= 500) or (casualties > 100)   {
							color_indicators <- #red;
						}else {
							color_indicators <- #lightgreen;
						}
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
				}
 
				draw rectangle(3500,1600) color: #gray border: #black at: {-1870, 1000,-1.0};
				draw "Current stage: " + stage font: font ("Helvetica", 22, #bold) at: {-3500, 300} anchor: #top_left color: text_color;	
			
				
				//draw background color: darker(frame_color) width: 5 border: brighter(frame_color) at: background_position + {background.width / 2, background.height/2, -10} lighted: false ;
				point timer_position <- {-3300, 600};
				point indicators_position <- {-3300, 1000};
	
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 18, #bold) at: timer_position anchor: #top_left color: text_color;	
				}
				if (indicators != nil) { 
					draw indicators font: font ("Helvetica", 18, #bold) at: indicators_position anchor: #top_left color: color_indicators;	
				}
				/*if (keep != nil) {
					draw keep font: font ("Helvetica", 16, #plain) at: check_text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 14, #bold) at: text_position + {0, 630} anchor: #top_left color: text_color;	
				}	*/	
				
				
		
			}
			
		
			
			event "f" {
				if (state != "s_diking") {return;}
				diking_over <- true;
			}
		
			
			event #mouse_move { 
				if (state != "s_diking") {line <- nil; return;}
				if (start_point != nil) {
					line <- line([start_point, #user_location]);
					is_ok_dyke_construction <- true;
				} else {
					line <- nil;
				}
			}
		
		}

	}

}