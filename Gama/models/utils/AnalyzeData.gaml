/**
* Name: AnalyzeData
* Based on the internal skeleton template. 
* Author: patricktaillandier
* Tags: 
*/

model AnalyzeData

global {
	string VR <- "VR" const: true;
	string PC <- "PC" const: true;
	
	csv_file players_csv_file <- csv_file("Data/players.csv", true);

//	csv_file players_csv_file <- csv_file("Data/players.csv", true, ",", string);

	csv_file questionnaire0 <- csv_file("Data/La gestion des Inondations - questionnaire 0.csv", true);

	csv_file questionnaire1PC <- csv_file("Data/La gestion des Inondations - questionnaire 1 PC.csv", true);

	csv_file questionnaire1VR <- csv_file("Data/La gestion des Inondations - questionnaire 1 VR.csv", true);
	
	init {
		map<string,player> players;
		matrix mat_player <- matrix(players_csv_file);
		loop i from: 0 to: mat_player.rows -1  {
			string id <- mat_player[0,i]; 
			string mode <- mat_player[1,i]; 
			create player with: (id:id,mode:mode) {
				players[id] <- self;
			}
		}
		matrix mat_Q0 <- matrix(questionnaire0);
		loop i from: 0 to: mat_Q0.rows -1  {
			string id <- mat_Q0[1,i]; 
			player p <- players[id];
			if (p != nil) {
				p.genre <-  mat_Q0[2,i]; 
				p.age <- int(mat_Q0[3,i]);
				p.etude <-  mat_Q0[4,i]; 
				p.jeux_video <-  mat_Q0[5,i]; 
				p.digue_efficace_pre <-  mat_Q0[6,i]; 
				p.impact_digues_pre <-  mat_Q0[7,i]; 
				p.strategies_pre <-  mat_Q0[8,i]; 
			}
		}
		matrix mat_Q1PC <- matrix(questionnaire1PC);
		loop i from: 0 to: mat_Q1PC.rows -1  {
			string id <- mat_Q1PC[1,i]; 
			player p <- players[id];
			if (p != nil) {
				p.digue_efficace_post <-  mat_Q1PC[2,i]; 
				p.impact_digues_post <-  mat_Q1PC[3,i]; 
				p.strategies_post <-  mat_Q1PC[4,i]; 
				p.rule_ok <- mat_Q1PC[5,i] ;
				p.realism <- mat_Q1PC[6,i]; 
				p.graphic_design<- mat_Q1PC[7,i]; 
				p.is_fun<- mat_Q1PC[8,i]; 
				p.game_duration<- mat_Q1PC[9,i]; 
				p.game_replay<- mat_Q1PC[10,i]; 
				p.game_control<- mat_Q1PC[11,i]; 
				p.is_sick<- mat_Q1PC[12,i]; 
				p.two_words<- mat_Q1PC[13,i]; 
			}
		}
		matrix mat_Q1VR <- matrix(questionnaire1VR);
		loop i from: 0 to: mat_Q1VR.rows -1  {
			string id <- mat_Q1VR[1,i]; 
			player p <- players[id];
			if (p != nil) {
				p.digue_efficace_post <-  mat_Q1VR[2,i]; 
				p.impact_digues_post <-  mat_Q1VR[3,i]; 
				p.strategies_post <-  mat_Q1VR[4,i]; 
				p.use_VR <- mat_Q1VR[5,i]; 
				p.rule_ok <- mat_Q1VR[6,i] ;
				p.realism <- mat_Q1VR[7,i]; 
				p.graphic_design<- mat_Q1VR[8,i]; 
				p.is_fun<- mat_Q1VR[9,i]; 
				p.game_duration<- mat_Q1VR[10,i]; 
				p.game_replay<- mat_Q1VR[11,i]; 
				p.game_control<- mat_Q1VR[12,i]; 
				p.is_confortable<- mat_Q1VR[13,i]; 
				p.is_sick<- mat_Q1VR[14,i]; 
				p.two_words<- mat_Q1VR[15,i]; 
			}
		}
		ask player {
			string pth <- "Data/" + mode + "-" + id;
			csv_file evacuated_casualties_csv_file <- csv_file(pth+"/evacuated_casualties.csv", true);
			matrix mat_evac <- matrix(evacuated_casualties_csv_file);
			loop i from: 0 to: mat_evac.rows -1  {
				score << int(mat_evac[5,i]);
				dyke_length << int(mat_evac[1,i]);
				dam_length << int(mat_evac[2,i]);
				casualties << int(mat_evac[4,i]);
			}
		}
	}
	
	reflex end when: cycle > 2 {
		do pause;
	}

}

species player {
	string id;
	string mode;
	list<int> score;
	list<int> dyke_length;
	list<int> dam_length;
	list<int> casualties;
	string genre;
	int age;
	string etude;
	string jeux_video;
	string digue_efficace_pre;
	string digue_efficace_post;
	string impact_digues_pre;
	string impact_digues_post;
	string strategies_pre;
	string strategies_post;
	string use_VR;
	string rule_ok;
	string realism;
	string graphic_design;
	string is_fun;
	string game_duration;
	string game_replay;
	string game_control;
	string is_confortable;
	string is_sick;
	string two_words;
	rgb color <- rnd_color(255);
	
}

experiment AnalyzeData type: gui {
	float minimum_cycle_duration <- 0.1;
	output {
		display charts_score type: 2d{
			chart "score_PC" size: {1.0, 0.5} y_range: {0,1000}{
				loop p over: player where (each.mode = "PC") {
					data p.id value: p.score[cycle] color:p.color;
				}
			}
			chart "score_VR" size: {1.0, 0.5} position: {0.0,0.5} y_range: {0,1000}{
				loop p over: player where (each.mode = "VR") {
					data p.id value: p.score[cycle] color:p.color;
				}
			}
		}
	}
}
