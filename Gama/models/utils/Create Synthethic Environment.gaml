/**
* Name: CreateSynthethicEnvironment
* Based on the internal skeleton template. 
* Author: patricktaillandier
* Tags: 
*/

model CreateSynthethicEnvironment

global {
	
	map<map<string, unknown>,float> building_proportions <- [
		["width"::10.0, "height":: 5.0, "color":: #yellow] :: 2,
		["width"::20.0, "height":: 5.0, "color":: #blue] :: 2,
		["width"::30.0, "height":: 15.0, "color":: #orange] :: 8,
		["width"::50.0, "height":: 20.0, "color":: #magenta] :: 10
	];
	
	float dem_threshold <- 0.0;
	float dem_value_river <- -100.0;
	
	float max_density_building <- 0.15;
	
	
	
	file buildings_shapefile <- file("../../includes/gis/buildings.shp");
	file dem_file <- file("../../includes/dem/terrain89x211.asc");
	
	geometry shape <- envelope(file("../../includes/gis/QBBB.shp"));

	file river_shapefile <- file("../../includes/gis/river_clean.shp");
	
	init {
		loop v over: building_proportions.keys {
			float w <- float(v["width"]);
			float h <- float(v["height"]);
			rgb c <- rgb(v["color"]);
			create building_template with: (width: w, height:h, color: c);
		
		}
		
		create building from: buildings_shapefile;
		create river from: river_shapefile;
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
		if dem_value_river < 0 {
			ask cell  {
				grid_value <- grid_value + abs(dem_value_river);
			}	
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
		if dem_value_river < 0 {
			ask building  {
				location <- location + {0,0,abs(dem_value_river)};
			}
			ask unity_building  {
				location <- location + {0,0,abs(dem_value_river/2.0)};
			}	
		}
	}
}


species river {
	aspect default {
		draw shape color: #blue;
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

//Species that will make the link between GAMA and Unity. It has to inherit from the built-in species asbtract_unity_linker
species unity_linker parent: abstract_unity_linker {
	//name of the species used to represent a Unity player
	string player_species <- string(unity_player);

	//in this model, the agents location and heading will not be sent to the Players at every step, so we set do_info_world to false
	bool do_send_world <- false;
	
	//initial location of the player - center of the world
	list<point> init_locations <- [world.location];
	 
	 
	unity_property up_building1 ;
	unity_property up_building2 ;
	unity_property up_house1 ;
	unity_property up_house2 ;
	unity_property up_gama_building ;
	unity_property up_water;
		
	init {
		//define the unity properties
		do define_properties;
		
		write (unity_building collect each.location.z);
		
		//add the sphere_ag agent as static geometry to send to unity with the up_sphere unity properties.
		do add_background_geometries(unity_building where (each.color = #magenta) ,up_building1);
		do add_background_geometries(unity_building where (each.color = #orange) ,up_building2);
		do add_background_geometries(unity_building where (each.color = #blue) ,up_house1);
		do add_background_geometries(unity_building where (each.color = #yellow) ,up_house2);
		do add_background_geometries(building  ,up_gama_building);
		do add_background_geometries(river  ,up_water);
			
		
		
	}
	 
	
	//action that defines the different unity properties
	action define_properties {
		unity_aspect building1_aspect <- prefab_aspect("Prefabs/Visual Prefabs/Flood Project/Prefabs/building 1",100,17.0,1.0,0.0, precision);
		
		//define the up_car unity property, with the name "car", no specific layer, the car_aspect unity aspect, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_building1<- geometry_properties("building1", string(nil), building1_aspect, #no_interaction, false);
		
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_building1;
		
		unity_aspect building2_aspect <- prefab_aspect("Prefabs/Visual Prefabs/Flood Project/Prefabs/building 2",70,6.8,1.0,0.0, precision);
		
		//define the up_car unity property, with the name "car", no specific layer, the car_aspect unity aspect, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_building2<- geometry_properties("building2", string(nil), building2_aspect, #no_interaction, false);
		
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_building2;
		
		
		unity_aspect house1_aspect <- prefab_aspect("Prefabs/Visual Prefabs/Flood Project/Prefabs/house 1",50,3.5,1.0,0.0, precision);
		
		//define the up_car unity property, with the name "car", no specific layer, the car_aspect unity aspect, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_house1<- geometry_properties("house1", string(nil), house1_aspect, #no_interaction, false);
		
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_house1;
		
		unity_aspect house2_aspect <- prefab_aspect("Prefabs/Visual Prefabs/Flood Project/Prefabs/house 2",40,3.0,1.0,0.0, precision);
		
		//define the up_car unity property, with the name "car", no specific layer, the car_aspect unity aspect, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_house2<- geometry_properties("house2", string(nil), house2_aspect, #no_interaction, false);
		
		// add the up_tree unity_property to the list of unity_properties
		unity_properties << up_house2;
		
		
			//define a unity_aspect called geom_aspect that will display the agents using their geometries, with a height of 1 meter, the gray color, and we use the default precision. 
		unity_aspect field_aspect <- geometry_aspect(0.1, "Prefabs/Visual Prefabs/Flood Project/Material/verdure", precision);
		
		//define the up_geom unity property, with the name "circle", no specific layer, no interaction, and the agents location are not sent back 
		//to GAMA. 
		up_gama_building <- geometry_properties("field", string(nil), field_aspect, #no_interaction, false);
		
		// add the up_geom unity_property to the list of unity_properties
		unity_properties << up_gama_building;
		
		unity_aspect water_aspect <- geometry_aspect(9.0, "Materials/Water2/WaterVoronoi",precision);
		up_water <- geometry_properties("water", string(nil), water_aspect, #no_interaction,false);
		unity_properties << up_water;
	}
}

//species used to represent an unity player, with the default attributes. It has to inherit from the built-in species asbtract_unity_player
species unity_player parent: abstract_unity_player {
	//size of the player in GAMA
	float player_size <- 1.0;

	//color of the player in GAMA
	rgb color <- #red ;
	
	//vision cone distance in GAMA
	float cone_distance <- 10.0 * player_size;
	
	//vision cone amplitude in GAMA
	float cone_amplitude <- 90.0;

	//rotation to apply from the heading of Unity to GAMA
	float player_rotation <- 90.0;
	
	//display the player
	bool to_display <- true;
	
	//offset added to the player vizualisation.
	float z_offset <- 10.0;
	
	//default aspect to display the player as a circle with its cone of vision
	aspect default {
		if to_display {
			if selected {
				 draw circle(player_size) at: location + {0, 0, z_offset} color: rgb(#blue, 0.5);
			}
			draw circle(player_size/2.0) color: color  at: location + {0, 0,z_offset} ;
			draw player_perception_cone() color: rgb(color, 0.5)  ; 
		}
	}
}

experiment CreateSynthethicEnvironment type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display map {
			mesh cell grayscale: true triangulation: true scale: 10;
			species building;
			species unity_building;
			species river;
		}
		display dem type: 3d{
			mesh cell grayscale: true triangulation: true scale: 10;
		}
	}
}

experiment vr_xp parent:CreateSynthethicEnvironment autorun: false type: unity {
	//minimal time between two simulation step
	float minimum_cycle_duration <- 0.1;

	//name of the species used for the unity_linker
	string unity_linker_species <- string(unity_linker);
	
	//allow to hide the "map" display and to only display the displayVR display 
	list<string> displays_to_hide <- ["map"];
	
	
	
	//action called by the middleware when a player connects to the simulation
	action create_player(string id) {
		field f <- field(matrix(cell));
		ask unity_linker {
			do create_player(id);
			
			//after creating the player, GAMA sends to the player the initial value of the DEM
			do update_terrain (
					player:last(unity_player),  //player concerned 
					id:"DEM",  //name of the Terrain in Unity
					field:f, //it is possible to send the grid either as a field or as a matrix
					resolution:65, //resolution of the target Terrain in Unity. Ideally, the resolution of the field/matrix should be the same as this one
					max_value:10.0 //optional : max possible of the grid - if not defined, GAMA will set it with the max value in the field/matrix
				);
		}
		
	}

	//action called by the middleware when a plyer is remove from the simulation
	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask first(unity_player where (each.name = id_input)) {
				do die;
			}
		}
	}
	
	//variable used to avoid to move too fast the player agent
	float t_ref;

		 
	output { 
		//In addition to the layers in the map display, display the unity_player .
		display displayVR parent: map  {
			species unity_player;
		}
		
	} 
}
