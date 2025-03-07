using UnityEngine;
using WebSocketSharp;
using System;
using System.Collections.Generic;
using System.Text.Json;

public class ConnectionWithGama : MonoBehaviour
{
    protected string ip;
    protected string port;
    private String AgentToSendInfo = "simulation[0].unity_linker[0]";
    protected WebSocket socket;
    protected String MessageSeparator = "|||";


    protected void SendMessageToServer(string message, Action<bool> successCallback)
    {
        socket.SendAsync(message, successCallback);
    }

    public void SendExecutableAsk(string action, Dictionary<string, string> arguments)
    {
        string argsJSON = JsonSerializer.Serialize(arguments);
        Dictionary<string, string> jsonExpression = null;
        jsonExpression = new Dictionary<string, string>
        {
            { "type", "ask" },
            { "action", action },
            { "args", argsJSON },
            { "agent", AgentToSendInfo }
        };

        string jsonStringExpression = JsonSerializer.Serialize(jsonExpression);

        SendMessageToServer(jsonStringExpression, new Action<bool>((success) =>
        {
            if (!success)
            {
                Debug.LogError("ConnectionManager: Failed to send executable expression");
            }
        }));
    }
}