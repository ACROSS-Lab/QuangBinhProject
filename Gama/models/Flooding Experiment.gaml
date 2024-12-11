/**
* Name: FloodingExperiment
* Based on the internal empty template. 
* Author: drogoul
* Tags: 
*/


model FloodingExperiment

import "Flooding Global.gaml"

/* Insert your model definition here */


global {
	
	/*************************************************************
	 * Attributes dedicated to the UI in GAMA (images, colors, etc.)
	 *************************************************************/
	
	rgb background_color <- #dimgray;
	rgb frame_color <- rgb(1, 95, 115);
	rgb river_color <- rgb(74, 169, 163);
	rgb people_color <-rgb(232, 215, 164); 
	rgb evacuation_color <- rgb(176, 32, 19);
	rgb road_color <- rgb(64, 64, 64);
	rgb line_color <- rgb(156, 34, 39);
	rgb dyke_color <- rgb(156, 34, 39);
	rgb text_color <- rgb(232, 215, 164);
	
	
	point text_position <- {-1500, 500};
	point timer_position <- {-1100, 1000};
	point icon_position <- {-1350, 1000};
	
	bool river_in_3D <- false; 
	
	geometry button_frame;  
	image	button_image_unselected <- image(path_to_include + "icons/restart-line.png");
	image	button_image_selected <- image(path_to_include + "icons/restart-fill.png");
	bool button_selected;
	
	reflex change_building_colors {
		ask buildings {
			int nb <- cells_under count (each.water_height > 0);
			switch (nb) {
				match 0 {color <- #gray;}
				match_one [1,2] {color <- rgb(214, 168, 0);}
				match_one [3,4] {color <- rgb(237, 155, 0);}
				default {color <- rgb(176, 32, 19);}
			}
		}
	}
}


experiment Launch  autorun: true type: unity {
	
	point start_point;
	point end_point;  
	geometry line; 


	string unity_linker_species <- string(unity_linker);
	float t_ref;
	float minimum_cycle_duration <- 0.1;
	 	
	action create_player(string id) {
		ask unity_linker {
			do create_player(id);
			write sample(id);
		}
	}

	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask unity_linker {
				unity_player pl <- player_agents[id_input];
				write sample(pl);
				if (pl != nil) {
					remove key: id_input from: player_agents ;
					ask pl {do die;}
				}
				write sample(player_agents);
			}
			
		}
	}
	
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

	output synchronized: true{
		
		layout #none controls: false toolbars: false editors: false parameters: false consoles: false tabs: false;
		
		
		 display map_VR type: 3d background: background_color axes: false{
		 	
			species river visible: !river_in_3D transparency: 0.2 {
				draw shape border: brighter(brighter(river_color)) width: 5 color: river_color at: location + {0, 0, 5};
			}			

			species road {
				draw drowned ? shape : shape + 10 depth: height color: drowned ? darker(river_color) : road_color ;
			}
		 	species buildings { 
		 		draw shape color: drowned ? river_color : color depth: height * 2 border: drowned ? darker(river_color):color;	
		 	}
		 	species dyke {
		 		draw shape + 5 color: drowned ? river_color : dyke_color depth: height * 2 border: drowned ? darker(river_color):dyke_color;	
			} 
			species people {
				draw circle(18)  color: people_color;
			}
			species evacuation_point {
				draw circle(60) at: location + {0,0,40} color: evacuation_color;
			}

			mesh cell above: 0 triangulation: true smooth: false color: cell collect each.color visible: river_in_3D transparency: 0.5;
			
			event #mouse_down {
				if (button_selected) {
					skipped_in_gama <- true;
					 start_point <- nil; end_point<- nil; return;
				}
				if (state != "DIKING") { return;}
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
			
			event #mouse_move { 
				button_selected <- button_frame != nil and button_frame overlaps #user_location;
				if (state != "DIKING") {line <- nil; return;}
				if (start_point != nil) {
					line <- line([start_point, #user_location]);
				} else {
					line <- nil;
				}
			}

			event #arrow_left {
				world.skipped_in_gama <- true ;
			}
			
			event "z" {
				dyke to_kill <- last(dyke);
				if (to_kill != nil) { ask to_kill {do die;}}
			} 
		 	
		 	
			species unity_player {
				draw circle(30) at: location + {0, 0, 50} color: rgb(color, 0.5) ;
			}
			
			
			graphics "Text and icon"   {
				string text <- state_titles[state] + ".";
				string hint <- "Press '->' to skip.";
				string timer <- nil;
				float left <- current_timeout - gama.machine_time;
				timer <- button_selected ? "Skip to " + state_next[state]: state_next[state] + " in " + int(left / 1000) + " seconds.";
								
				switch (state) {
					match "START" {
					}
					match "DIKING" {
						text <- "Build dykes with the mouse.";
					}	
					match "FLOODING" {
						text <- "Casualties: " + casualties + '/' + nb_of_people;
					}
					match "PLAYBACK" {
					}
				}
				if (text != nil) {
					draw text font: font ("Helvetica", 18, #bold) at: text_position anchor: #top_left color: text_color;	
				}
				if (hint != nil) {
					draw hint font: font ("Helvetica", 10, #bold) at: text_position + {0, 100} anchor: #top_left color: text_color;	
				}
				if (timer != nil) { 
					draw timer font: font ("Helvetica", 14, #plain) at: timer_position anchor: #top_left color: text_color;	
				}
				
				if (button_image_unselected != nil) { 
					button_frame <- square(300) at_location icon_position;
					draw button_selected ? button_image_selected : button_image_unselected size: 300 at: icon_position;
				} 
			}

			graphics ll {
				if (line != nil) {
					draw line + dyke_width + 5 color: dyke_color;
				}
			}

		 }
	}
}