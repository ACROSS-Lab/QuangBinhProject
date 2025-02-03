/**
* Name: FloodingUI
* A simple UI experiment to demonstrate the flooding in Quang Binh province 
* Author: Alexis Drogoul
* Tags:   
*/


model FloodingUI 
  
import "Flooding Model.gaml" 

global {   
	   

	/************************************************************* 
	 * Functions that control the transitions between the states
	 *************************************************************/

	action enter_init {
	//	write "enter_init"; 
		do enter_init_base;
		   
		ask buildings {
			color <- one_of(building_colors); 
		} 
		button_frame <- nil;
		check_frame <- nil; 
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

	reflex update_cell_colors when: river_in_3D {
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
			//	grid cell border: #black;
		 	species river visible:!river_in_3D{
				draw shape_to_export border: brighter(brighter(river_color)) width: 5 color: river_color;
			}	 

			species road {
				draw drowned ? shape : shape + 10 color: drowned ? darker(river_color) : road_color ;
			}
		 	species buildings {
		 		draw shape color: drowned ? river_color : color border: drowned ? darker(river_color):color;	
		 	} 
		 	graphics "end_of_world" {
				draw water_limit_danger + 20 color: #red; 
				loop d over: water_limit_well {
					draw d + 20 color: #orange;
				}
				loop d over: water_limit_drain {
					draw d + 20 color: #green;
				}
			}   
		 	species dyke {
		 		if (!is_dam) {
		 			draw shape + 5 color: drowned ? river_color : dyke_color border: drowned ? darker(river_color):#black;	
		 		} else {
		 			draw shape + 5 color: drowned ? river_color : dam_color border: drowned ? darker(river_color):#black;	
		 		}
		 		
			}  
			species people {
				draw circle(20)  color: (state = "s_drowned" ? people_drowned_color : (state = "s_evacuated" ?  people_evacuated_color : people_color)); 
			 	
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
						geometry g <- circle(10) at_location #user_location;
				 		list<dyke> dykes <- dyke overlapping g;
				 		if (not empty(dykes)) {
				 			bool recompute_river <- false;
				 			ask dykes closest_to #user_location {
				 				if (is_dam) {
				 					dam_length <- dam_length - length; 
				 				} else {
				 					dyke_length <- dyke_length - length; 
				 				}
				 				loop c over: cells_under {
				 					c.obstacles >> self;
				 					if (c in bed_cells) {
				 						recompute_river <- true;
				 						c.water_height <- initial_water_height;
				 					}
				 				}
				 				do die;
				 			}
				 			if (recompute_river) {
				 				do compute_river_shape;
				 			}
				 			
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
						do create_dyke(myself.start_point, #user_location);
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
						indicators <- "Meters of dyke built: "+ round(dyke_length) + "m" + "\n\nMeters of dam built: "+ round(dam_length) + "m";
					
						//text <- "Build dykes/dams with the mouse.\n\n\tMeters of dyke built: "+ round(dyke_length) + "m" + "\n\n\tMeters of dam built: "+ round(dam_length) + "m";
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + max(0,int(left / 1000)) + " seconds.";
						hint <- "Press 'r' to remove a dyke/dam\nPress 'f' for skipping.";
						
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
			
			 
			
			graphics ll {
				if (line != nil) {
					draw line + dyke_width + 5 color: is_ok_dyke_construction ? dyke_color : #red border: #black;
				}
			}
		}

	}

}
