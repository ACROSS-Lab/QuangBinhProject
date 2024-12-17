/**
* Name: FloodingUI
* A simple UI experiment to demonstrate the flooding in Quang Binh province 
* Author: Alexis Drogoul
* Tags: 
*/


model FloodingUI 

import "Flooding Model.gaml"

global { 
	 
	
	 float waiting_time_in_s <- 1.5;
	
	/*************************************************************
	 * Attributes dedicated to the UI (images, colors, frames, etc.)
	 *************************************************************/
	
	rgb background_color <- #dimgray;
	rgb frame_color <- rgb(1, 95, 115);
	rgb river_color <- rgb(74, 169, 163);
	rgb people_color <-rgb(232, 215, 164);
	rgb evacuation_color <- rgb(176, 32, 19);
	rgb road_color <- rgb(64, 64, 64);
	rgb line_color <- rgb(156, 34, 39);
	rgb dyke_color <- rgb(34, 156, 39);
	rgb text_color <- rgb(232, 215, 164);
	list<rgb> building_colors <- [rgb(214, 168, 0),rgb(237, 155, 0),rgb(202, 103, 2),rgb(120, 167, 121)];
	
	geometry background <- rectangle(1700, 1400);
	point text_position <- {-1500, 500};
	point background_position <- text_position - {200, 200};
	point timer_position <- {-1100, 1000};
	point icon_position <- {-1350, 1000};
	point check_position <- {-1350, 1300};
	point check_text_position <- {-1100, 1300};
	
	bool river_in_3D <- false; 
	geometry button_frame;  
	geometry check_frame;
	image button_image_unselected;
	image button_image_selected;
	image check_image_unselected;
	image check_image_selected; 
	bool button_selected;
	bool check_selected;
	
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
		playback_finished <- recording ? true : false;
	} 
	
	action enter_start {
		button_frame <- nil;
		button_image_unselected <- nil;
		button_image_selected <- nil;
	}
	 
	action enter_diking {
		
		diking_over <- false;
		check_frame <- nil;
		current_timeout <- gama.machine_time + diking_duration * 1000;
		button_image_unselected <- image("../../includes/icons/flood-line.png") * rgb(232, 215, 164);
		button_image_selected <- image("../../includes/icons/flood-fill.png") * rgb(232, 215, 164);
		check_image_unselected <- nil;
		check_image_selected <- nil;
		diking_over <- recording;
	}
	
	action enter_flooding {
		do enter_flooding_base;
		restart_requested <- false;	
		button_image_unselected <- image("../../includes/icons/restart-line.png");
		button_image_selected <- image("../../includes/icons/restart-fill.png");
		check_image_unselected <- image("../../includes/icons/checkbox-blank-line.png");
		check_image_selected <- image("../../includes/icons/checkbox-line.png");
		current_step <- 0;
		casualties <- 0;
		evacuated <- 0;
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
		return playback_finished;
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
		if (!recording) {do playback();}
	}
	
	action body_flooding {
		if (recording) {do record();}
		current_step <- current_step +1;
		
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
	float minimum_cycle_duration <- 0.1;
	
	point start_point; 
	point end_point;  
	geometry line; 
	 
	output {
		
		layout #none controls: false toolbars: true editors: false parameters: false consoles: false tabs: false;
		display map type: 3d axes: false background: background_color antialias: false{

			species river visible: !river_in_3D {
				draw shape border: brighter(brighter(river_color)) width: 5 color: river_color;
			}			 

			species road {
				draw drowned ? shape : shape + 10 color: drowned ? darker(river_color) : road_color ;
			}
		 	species buildings {
		 		draw shape color: drowned ? river_color : color border: drowned ? darker(river_color):color;	
		 	}
		 	species dyke {
		 		draw shape + 5 color: drowned ? river_color : dyke_color border: drowned ? darker(river_color):dyke_color;	
			} 
			species people {
				draw circle(20)  color: people_color;
			}
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: evacuation_color;
			}

			mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D transparency: 0.5;
			
			event "r" {
				if (state != "s_diking") { return;}
				if (start_point != nil) {
					start_point <- nil;
					line <- nil;
				} else {
					ask world {
						geometry g <- circle(2) at_location #user_location;
				 		list<dyke> dykes <- dyke overlapping g;
				 		if (not empty(dykes)) {
				 			ask dykes closest_to #user_location {
				 				dyke_length <- dyke_length - length; 
				 				do die;
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
					end_point <- #user_location;
					float dist <- (start_point distance_to end_point);
					if ((dyke_length + dist) <= dyke_length_max) {
						geometry l <- line([start_point, end_point]);
						dyke_length <- dyke_length + dist; 
						ask simulation { 
							create dyke with:(shape:l + dyke_width, length: dist);
						}
					}
					
					start_point <- nil;
					end_point <- nil;
				}

			}
			
			graphics "Text and icon"   {
				string text <- nil;
				string timer <- nil;
				string hint <- nil;
				string keep <- nil;

								
				switch (state) {
					match "s_init" {
						text <-  "Previous Flood !\n" + "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//timer <- button_selected ? "Restart now.": "Restarting in " + int(left / 1000) + " seconds.";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
					match "s_diking" {
						text <- "Build dykes with the mouse. Meters of dyke built: "+ round(dyke_length) + "/" + round(dyke_length_max);
						float left <- current_timeout - gama.machine_time;
						timer <- button_selected ? "Start flooding now.": "Flooding in " + int(left / 1000) + " seconds.";
						hint <- "Press 'r' to remove a dyke\nPress 'f' for skipping.";
						
						//\nPress 'f' to start immediately.";
					}	
					match "s_flooding" {text <- "Casualties: " + casualties + '/' + nb_of_people;
						float left <- current_timeout - gama.machine_time;
						//hint <- "Press 'r' for restarting.";
						timer <- "End in " +(num_step - current_step) + " minutes";
						//\nPress 'r' to restart immediately.";
						//keep <- "Keep the dykes."; 
					}
				}
				//draw background color: darker(frame_color) width: 5 border: brighter(frame_color) at: background_position + {background.width / 2, background.height/2, -10} lighted: false ;
				if (text != nil) {
					draw text font: font ("Helvetica", 18, #bold) at: text_position anchor: #top_left color: text_color;	
				}
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 14, #plain) at: timer_position anchor: #top_left color: text_color;	
				}
				if (keep != nil) {
					draw keep font: font ("Helvetica", 14, #plain) at: check_text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 10, #bold) at: text_position + {0, 130} anchor: #top_left color: text_color;	
				}		
				
				
			/*	if (button_image_unselected != nil) { 
					button_frame <- square(300) at_location icon_position;
					draw button_selected ? button_image_selected : button_image_unselected size: 300 at: icon_position;
				}
				if (check_image_unselected != nil) {
					check_frame <- square(300) at_location check_position;
					draw check_selected or keep_dykes ? check_image_selected : check_image_unselected size: 300 at: check_position;
				} */
			}
			
			/*event "z" {
				dyke to_kill <- last(dyke);
				if (to_kill != nil) { ask to_kill {do die;}}
			}*/
			
			event "f" {
				if (state != "s_diking") {return;}
				diking_over <- true;
			}
			
			/*event "r" {
				if (state != "s_flooding") {return;}
				restart_requested <- true;
			}*/
			
			event #mouse_move { 
			//	button_selected <- button_frame != nil and button_frame overlaps #user_location;
		//		check_selected <- check_frame != nil and check_frame overlaps #user_location;
				if (state != "s_diking") {line <- nil; return;}
				if (start_point != nil) {
					line <- line([start_point, #user_location]);
					is_ok_dyke_construction <- ((dyke_length + line.perimeter) <= dyke_length_max);
				} else {
					line <- nil;
				}
			}
			
			
			
			graphics ll {
				if (line != nil) {
					draw line + dyke_width + 5 color: is_ok_dyke_construction ? dyke_color : #red ;
				}
			}
		}

	}

}
