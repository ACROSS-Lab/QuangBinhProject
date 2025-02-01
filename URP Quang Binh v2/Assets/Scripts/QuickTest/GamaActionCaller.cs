using System.Collections.Generic;
using Gama_Provider.Simulation;
using UnityEngine;

namespace QuickTest
{
    public class GamaActionCaller : MonoBehaviour
    {
        public static GamaActionCaller Instance = null;


        void Start()
        {
            Instance = this;
        }

        public void DrawSampleDyke()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "unity_start_point", "817,1760,0" },
                { "unity_end_point", "961,2281,0" }
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }

        public void DrawDykeWithParams(Vector3 startPoint, Vector3 endPoint)
        {
            string startPointStr = (int)startPoint.x + "," +
                                   (int)(startPoint.z >= 0 ? startPoint.z : startPoint.z * -1) + "," + "0";
            string endPointStr = (int)endPoint.x + "," + (int)(endPoint.z >= 0 ? endPoint.z : endPoint.z * -1) + "," +
                                 "0";
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "unity_start_point", startPointStr },
                { "unity_end_point", endPointStr }
            };
            ConnectionManager.Instance.SendExecutableAsk("action_management_with_unity", args);
        }

        public void RemoveSampleDyke()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "dyke_name", "dyke0" }
            };
            ConnectionManager.Instance.SendExecutableAsk("remove_dyke_with_unity", args);
        }

        public void SetInPlayback()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_PLAYBACK.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void SetInDiking()
        {
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_DIKING.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void SetInStart()
        {
            Debug.Log("SetInStart");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_START.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void SetInFlooding()
        {
            Debug.Log("SetInFlooding");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.IN_FLOODING.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void SetWaitingForPlayback()
        {
            Debug.Log("SetWaitingForPlayback");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.WAITING_FOR_PLAYBACK.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }

        public void SetWaitingForFlooding()
        {
            Debug.Log("SetWaitingForFlooding");
            Dictionary<string, string> args = new Dictionary<string, string>()
            {
                { "player_id", StaticInformation.getId() },
                { "status", GAMAGameStatus.WAITING_FOR_FLOODING.ToString() }
            };

            ConnectionManager.Instance.SendExecutableAsk("set_status", args);
        }
    }
}