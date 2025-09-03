/**
* Name: generateid
* Based on the internal skeleton template. 
* Author: patricktaillandier
* Tags: 
*/

model generateid

global {
	init {
		loop times: 50 {
			write "\n " + rnd(10000, 100000)   + "\t\t "+ rnd(10000, 100000) + "\t\t "+ rnd(10000, 100000)+ "\t\t "+ rnd(10000, 100000);
		}
	}
}

experiment generateid type: gui ;