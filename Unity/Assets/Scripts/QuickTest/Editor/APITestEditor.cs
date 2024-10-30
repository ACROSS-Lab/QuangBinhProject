using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(QuickTest.APITest))]
public class APITestEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        QuickTest.APITest apiTest = (QuickTest.APITest)target;
        // if (GUILayout.Button("Update Budget"))
        // {
        //     apiTest.TestUpdateBudget();
        // }

        if (GUILayout.Button("Update score"))
        {
            apiTest.TestUpdateScore();
        }

        if (GUILayout.Button("Build dyke"))
        {
            apiTest.TestBuildDyke();
            
        }
        
        if (GUILayout.Button("Draw dyke"))
        {
            apiTest.TestDrawDyke();
            apiTest.TestBuildDyke();
        }

        if (GUILayout.Button("Remove dyke"))
        {
            apiTest.TestRemoveDyke();
        }

        if (GUILayout.Button("Pause"))
        {
            apiTest.TestPause();
        }

        if (GUILayout.Button("Resume"))
        {
            apiTest.TestResume();
        }

        if (GUILayout.Button("End"))
        {
            apiTest.TestEnd();
        }

        if (GUILayout.Button("Start Simulation"))
        {
            apiTest.TestStartSimulation();
            ;
        }
    }
}