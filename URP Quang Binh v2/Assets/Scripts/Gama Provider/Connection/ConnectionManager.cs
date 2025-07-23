using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;
using WebSocketSharp;
using System.Text.Json;

public class ConnectionManager : WebSocketConnector
{
    private ConnectionState currentState; 
    private bool connectionRequested;

    // called when the connection state is manually changed
    public event Action<ConnectionState> OnConnectionStateChanged;

    // called when a "json_simulation" message is received
    public event Action<string, string> OnServerMessageReceived;

    // called when a "json_state" message is received 
    public event Action<JsonElement> OnConnectionStateReceived;

    // called when a connection request fails
    public event Action<bool> OnConnectionAttempted;

    public static ConnectionManager Instance = null;

    // use to separate messages in the case where the middleware is not used
    protected string MessageSeparator = "|||";

    private string AgentToSendInfo = "simulation[0].unity_linker[0]";

    // ############################################# UNITY FUNCTIONS #############################################
    void Awake()
    {
        UseMiddleware = DesktopMode ? UseMiddlewareDM : PlayerPrefs.GetString("MIDDLEWARE").Equals("Y");
        Debug.Log("ConnectionManager: Awake : " + PlayerPrefs.GetString("MIDDLEWARE"));
        Debug.Log("ConnectionManager Awake host: " + PlayerPrefs.GetString("IP") + " PORT: " +
                  PlayerPrefs.GetString("PORT") + " UseMiddleware: " + UseMiddleware);

        Instance = this;
    }

    void Start()
    {
        Debug.Log("START");
        UpdateConnectionState(ConnectionState.DISCONNECTED);
        connectionRequested = false;
    }

    public string GetMessageSeparator()
    {
        return MessageSeparator;
    }

    // Helper method to build JSON strings using Utf8JsonWriter
    private static string WriteJson(Action<Utf8JsonWriter> writeAction)
    {
        using (var stream = new MemoryStream())
        {
            using (var writer = new Utf8JsonWriter(stream))
            {
                writeAction(writer);
            }
            return Encoding.UTF8.GetString(stream.ToArray());
        }
    }

    // ############################################# CONNECTION HANDLER #############################################
    public void UpdateConnectionState(ConnectionState newState)
    {
        switch (newState)
        {
            case ConnectionState.PENDING:
                Debug.Log("ConnectionManager: UpdateConnectionState -> PENDING");
                break;
            case ConnectionState.CONNECTED:
                Debug.Log("ConnectionManager: UpdateConnectionState -> CONNECTED");
                break;
            case ConnectionState.AUTHENTICATED:
                Debug.Log("ConnectionManager: UpdateConnectionState -> AUTHENTICATED");
                break;
            case ConnectionState.DISCONNECTED:
                Debug.Log("ConnectionManager: UpdateConnectionState -> DISCONNECTED");
                TryConnectionToServer();
                break;
            default:
                break;
        }

        currentState = newState;
        OnConnectionStateChanged?.Invoke(newState);
    }

    // ############################################# HANDLERS #############################################

    protected override void HandleConnectionOpen(object sender, EventArgs e)
    {
        if (UseMiddleware)
        {
            // Writing heartbeat as a number
            string jsonStringId = WriteJson(writer =>
            {
                writer.WriteStartObject();
                writer.WriteString("type", "connection");
                writer.WriteString("id", StaticInformation.getId());
                writer.WriteNumber("heartbeat", HeartbeatInMs);
                writer.WriteEndObject();
            });

            SendMessageToServer(jsonStringId, new Action<bool>((success) =>
            {
                Debug.Log("ConnectionManager: HandleConnectionOpen -> " + jsonStringId);
            }));
            Debug.Log("ConnectionManager: Connection opened");
        }
    }

    protected override void HandleReceivedMessage(object sender, MessageEventArgs e)
    {
        if (e.IsText)
        {
            // For further optimization, consider replacing JsonDocument with Utf8JsonReader if only a few properties are needed.
            JsonDocument jsonObj = JsonDocument.Parse(e.Data);
            JsonElement root = jsonObj.RootElement.Clone();
            string type = root.GetProperty("type").GetString();

            if (UseMiddleware)
            {
                switch (type)
                {
                    case "ping":
                        string jsonPong = WriteJson(writer =>
                        {
                            writer.WriteStartObject();
                            writer.WriteString("type", "pong");
                            writer.WriteEndObject();
                        });
                        SendMessageToServer(jsonPong, new Action<bool>((success) =>
                        {
                            // Optionally handle success.
                        }));
                        break;
                    case "json_state":
                        OnConnectionStateReceived?.Invoke(root);
                        bool authenticated = root.GetProperty("in_game").GetBoolean();
                        bool connected = root.GetProperty("connected").GetBoolean();

                        if (authenticated && connected)
                        {
                            if (!IsConnectionState(ConnectionState.AUTHENTICATED))
                            {
                                Debug.Log("ConnectionManager: Player successfully authenticated");
                                UpdateConnectionState(ConnectionState.AUTHENTICATED);
                            }
                        }
                        else if (connected && !authenticated)
                        {
                            if (!IsConnectionState(ConnectionState.CONNECTED))
                            {
                                connectionRequested = false;
                                Debug.Log("ConnectionManager: Successfully connected, waiting for authentication...");
                                UpdateConnectionState(ConnectionState.CONNECTED);
                                OnConnectionAttempted?.Invoke(true);
                            }
                            else
                            {
                                Debug.LogWarning("ConnectionManager: Already connected, waiting for authentication...");
                            }
                        }
                        break;
                    case "json_output":
                        JsonElement content = root.GetProperty("contents");
                        string firstKey = null;
                        // Avoid LINQ by using a simple loop.
                        foreach (JsonProperty prop in content.EnumerateObject())
                        {
                            firstKey = prop.Name;
                            break;
                        }
                        OnServerMessageReceived?.Invoke(firstKey, content.ToString());
                        break;
                    default:
                        break;
                }
            }
            else if (type.Equals("SimulationOutput"))
            {
                string content = root.GetProperty("content").GetString();
                // Split using the message separator.
                foreach (string mes in content.Split(new string[] { MessageSeparator }, StringSplitOptions.None))
                {
                    if (!string.IsNullOrEmpty(mes))
                        OnServerMessageReceived?.Invoke(null, mes);
                }
            }
        }
    }

    protected override void HandleConnectionClosed(object sender, CloseEventArgs e)
    {
        Debug.Log("ConnectionManager: HandleConnectionClosed");
        if (connectionRequested)
        {
            connectionRequested = false;
            OnConnectionAttempted?.Invoke(false);
            Debug.Log("ConnectionManager: Failed to connect to server");
        }

        UpdateConnectionState(ConnectionState.DISCONNECTED);
    }

    // ############################################# UTILITY FUNCTIONS #############################################
    public void TryConnectionToServer()
    {
        if (IsConnectionState(ConnectionState.DISCONNECTED))
        {
            Debug.Log("ConnectionManager: Attempting to connect to " + (UseMiddleware ? "middleware" : "GAMA") +
                      ": ws://" + host + ":" + port + "/");
            connectionRequested = true;
            UpdateConnectionState(ConnectionState.PENDING);

            GetSocket().Connect();

            if (!UseMiddleware)
            {
                Debug.Log("Create player direct :" + ConnectionManager.Instance.GetConnectionId());

                Dictionary<string, string> args = new Dictionary<string, string>
                {
                    { "id", "\"" + ConnectionManager.Instance.GetConnectionId() + "\"" }
                };
                SendExecutableAsk("create_init_player", args);

                UpdateConnectionState(ConnectionState.AUTHENTICATED);
            }
        }
        else
        {
            Debug.LogWarning("ConnectionManager: Already connected to middleware: " + this.currentState);
        }
    }

    public void DisconnectFromServer()
    {
        if (!IsConnectionState(ConnectionState.DISCONNECTED))
        {
            Debug.Log("ConnectionManager: Disconnecting from middleware...");
            GetSocket().Close();
            UpdateConnectionState(ConnectionState.DISCONNECTED);
        }
        else
        {
            Debug.LogWarning("ConnectionManager: Already disconnected from middleware");
        }
    }

    public bool IsConnectionState(ConnectionState state)
    {
        return this.currentState == state;
    }

    public void SendExecutableExpression(string expression)
    {
        string jsonStringExpression = WriteJson(writer =>
        {
            writer.WriteStartObject();
            writer.WriteString("type", "expression");
            writer.WriteString("expr", expression);
            writer.WriteEndObject();
        });

        SendMessageToServer(jsonStringExpression, new Action<bool>((success) =>
        {
            if (!success)
            {
                numErrors++;
                Debug.LogError("ConnectionManager: Failed to send executable expression");
                if (numErrors > numErrorsBeforeDeconnection)
                {
                    GetSocket().Close();
                    currentState = ConnectionState.DISCONNECTED;
                    numErrors = 0;
                }
            }
            else
            {
                numErrors = 0;
            }
        }));
    }

    public void SendExecutableAsk(string action, Dictionary<string, string> arguments)
    {
        // First serialize the arguments dictionary into a JSON string.
        string argsJSON = WriteJson(writer =>
        {
            writer.WriteStartObject();
            foreach (var kvp in arguments)
            {
                writer.WriteString(kvp.Key, kvp.Value);
            }
            writer.WriteEndObject();
        });

        // Now build the outer JSON with "args" as a string.
        string jsonStringExpression = WriteJson(writer =>
        {
            writer.WriteStartObject();
            writer.WriteString("type", "ask");
            writer.WriteString("action", action);
            writer.WriteString("args", argsJSON);  // Write the serialized arguments as a string.
            writer.WriteString("agent", AgentToSendInfo);
            writer.WriteEndObject();
        });

        SendMessageToServer(jsonStringExpression, new Action<bool>((success) =>
        {
            if (!success)
            {
                numErrors++;
                Debug.LogError("ConnectionManager: Failed to send executable ask");
                if (numErrors > numErrorsBeforeDeconnection)
                {
                    GetSocket().Close();
                    currentState = ConnectionState.DISCONNECTED;
                    numErrors = 0;
                }
            }
            else
            {
                numErrors = 0;
            }
        }));
    }

    public void DisconnectProperly()
    {
        string jsonStringExpression = WriteJson(writer =>
        {
            writer.WriteStartObject();
            writer.WriteString("type", "disconnect_properly");
            writer.WriteEndObject();
        });

        SendMessageToServer(jsonStringExpression, new Action<bool>((success) =>
        {
            if (!success)
            {
                Debug.LogError("ConnectionManager: Failed to send disconnect message");
            }
            else
            {
                DisconnectFromServer();
            }
        }));
    }

    public string GetConnectionId()
    {
        return StaticInformation.getId();
    }

    public bool getUseMiddleware()
    {
        return UseMiddleware;
    }

    public void Reconnect()
    {
        Debug.Log("Reconnect");
        currentState = ConnectionState.DISCONNECTED;
        TryConnectionToServer();
    }
}

public enum ConnectionState
{
    DISCONNECTED,
    PENDING,
    CONNECTED,
    AUTHENTICATED
}
