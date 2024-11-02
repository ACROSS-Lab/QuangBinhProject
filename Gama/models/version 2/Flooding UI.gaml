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
	 * Attributes dedicated to the UI (images, etc.)
	 *************************************************************/
	
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
		button_frame <- nil;
		check_frame <- nil;
		button_image_unselected <- nil;
		button_image_selected <- nil;
		check_image_unselected <- nil;
		check_image_selected <- nil;
	} 
	 
	action enter_diking {
		diking_over <- false;
		check_frame <- nil;
		diking_timeout <- gama.machine_time + diking_duration * 1000;
		button_image_unselected <- image("../../includes/icons/flood-line.png");
		button_image_selected <- image("../../includes/icons/flood-fill.png");
		check_image_unselected <- nil;
		check_image_selected <- nil;
	}
	
	action enter_flooding {
		restart_requested <- false;	
		flooding_timeout <- gama.machine_time + flooding_duration * 1000;	
		button_image_unselected <- image("../../includes/icons/restart-line.png");
		button_image_selected <- image("../../includes/icons/restart-fill.png");
		check_image_unselected <- image("../../includes/icons/checkbox-blank-line.png");
		check_image_selected <- image("../../includes/icons/checkbox-line.png");
	}

	bool init_over  { 
		return true;
	} 
	
	bool diking_over { 
		return diking_over or gama.machine_time >= diking_timeout;
	}
	
	bool flooding_over  { 
		return restart_requested or gama.machine_time >= flooding_timeout;
	}	
	
	/*************************************************************
	 * Flags to control the phases in the simulations
	 *************************************************************/

	// Is a restart requested by the user ? 
	bool restart_requested;
	
	// Is the flooding state requested by the user ? 
	bool diking_over;
	
	
	// The maximum amount of time, in seconds, for building dikes 
	float diking_duration <- 120.0;
	
	// The maximum amount of time, in seconds, for watching the water flow before restarting
	float flooding_duration <- 120.0;
	
	float diking_timeout;
	
	float flooding_timeout; 
	
	
	/**
	 * Reflex to update the color of the cell depending on its water height 
	 */

	reflex update_cell_colors when: river_in_3D {
			ask cell {do update_color();}
	}
	
}



experiment Run  type:gui autorun: true{
	
	point start_point;
	point end_point;  
	geometry line; 

	rgb background_color <- #white; 
	point text_position <- {-2000, 500};
	point timer_position <- {-1600, 1000};
	point icon_position <- {-1850, 1000};
	point check_position <- {-1850, 1300};
	point check_text_position <- {-1600, 1300};



	
	output {
		
		monitor "Average water height" value: mean(cell collect each.water_height);
		
		
		layout #none controls: true toolbars: false editors: false parameters: true consoles: false tabs: false;
		display map type: 3d axes: false background: background_color antialias: false{

			species river visible: !river_in_3D transparency: 0.5{
				draw shape color: rgb(95,158,160);
			}			

			species road {
				draw shape color: drowned ? (#cadetblue) : color depth: height border: drowned ? #white:color;
			}
		 	species buildings {
		 		draw shape color: drowned ? (#cadetblue) : color depth: height * 2 border: drowned ? #white:color;	
		 	}
		 	species dyke {
		 		draw shape + 5 color: drowned ? (#cadetblue) : color depth: height * 2 border: drowned ? #white:color;	
			} 
			species people {
				draw sphere(18) color:#darkseagreen;
			}
			species evacuation_point;

			mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D;
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
					geometry l <- line([start_point, end_point]);
					ask simulation { 
						create dyke with:(shape:l + dyke_width);
					}
					start_point <- nil;
					end_point <- nil;
				}

			}
			
			graphics "Text and icon"   {
				string text <- nil;
				string timer <- nil;
				string keep <- nil;

								
				switch (state) {
					match "s_diking" {
						text <- "Build dykes with the mouse.";
						float left <- diking_timeout - gama.machine_time;
						timer <- "Flooding in " + int(left / 1000) + " seconds.";
						//\nPress 'f' to start immediately.";
					}	
					match "s_restart" {text <-  "Restarting the simulation"; timer <- nil;}
					match "s_flooding" {text <- "Casualties: " + casualties + '/' + nb_of_people;
						float left <- flooding_timeout - gama.machine_time;
						timer <- "Restarting in " + int(left / 1000) + " seconds.";
						//\nPress 'r' to restart immediately.";
						keep <- "Keep the dykes."; 
					}
				}
				if (text != nil) {
					draw text font: font ("Helvetica", 18, #bold) at: text_position anchor: #left_center color: #black;	
				}
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 18, #plain) at: timer_position anchor: #left_center color: #black;	
				}
				if (keep != nil) {
					draw keep font: font ("Helvetica", 18, #plain) at: check_text_position anchor: #left_center color: #black;	
				}				
				
				
				if (button_image_unselected != nil) {
					button_frame <- square(300) at_location icon_position;
					draw button_selected ? button_image_selected : button_image_unselected size: 300 at: icon_position;
				}
				if (check_image_unselected != nil) {
					check_frame <- square(300) at_location check_position;
					draw check_selected or keep_dykes ? check_image_selected : check_image_unselected size: 300 at: check_position;
				}
			}
			
			event "z" {
				dyke to_kill <- last(dyke);
				if (to_kill != nil) { ask to_kill {do die;}}
			}
			
			event "f" {
				if (state != "s_diking") {return;}
				diking_over <- true;
			}
			
			event "r" {
				if (state != "s_flooding") {return;}
				restart_requested <- true;
			}
			
			event #mouse_move { 
				button_selected <- button_frame != nil and button_frame overlaps #user_location;
				check_selected <- check_frame != nil and check_frame overlaps #user_location;
				if (state != "s_diking") {line <- nil; return;}
				if (start_point != nil) {
					line <- line([start_point, #user_location]);
				} else {
					line <- nil;
				}
			}
			
			graphics ll {
				if (line != nil) {draw line + dyke_width color: #red;}
			}
		}

	}

}
