using UnityEditor;
using UnityEngine;

namespace QuickTest.Editor
{
    [CustomEditor(typeof(GamaActionCaller))]
    public class GamaActionCallerEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();

            GamaActionCaller gamaActionCaller = (GamaActionCaller)target;

            if (GUILayout.Button("Set in start"))
            {
                gamaActionCaller.SetInStart();
            }
            
            if (GUILayout.Button("Set waiting for playback"))
            {
                gamaActionCaller.SetWaitingForPlayback();
            }
            
            if (GUILayout.Button("Set in playback"))
            {
                gamaActionCaller.SetInPlayback();
            }
            
            if (GUILayout.Button("Set in diking"))
            {
                gamaActionCaller.SetInDiking();
            }

            if (GUILayout.Button("Draw sample dyke"))
            {
                gamaActionCaller.DrawSampleDyke();
            }

            if (GUILayout.Button("Remove sample dyke"))
            {
                gamaActionCaller.RemoveSampleDyke();
            }
            
            if (GUILayout.Button("Set waiting for flooding"))
            {
                gamaActionCaller.SetWaitingForFlooding();
            }
        }
    }
}