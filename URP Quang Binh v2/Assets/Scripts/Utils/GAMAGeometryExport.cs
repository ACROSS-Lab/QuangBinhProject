using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using UnityEngine;
using WebSocketSharp;

public class GAMAGeometryExport : ConnectionWithGama
{
    protected ConnectionParameter parameters = null;

    // Optional: define a scale between GAMA and Unity for the location given
    public float GamaCRSCoefX = 1.0f;
    public float GamaCRSCoefY = 1.0f;
    public float GamaCRSOffsetX = 0.0f;
    public float GamaCRSOffsetY = 0.0f;

    private bool continueProcess = true;
    GameObject objectToSend;

    Dictionary<string, string> argsToSend = null;

    public void ManageGeometries(GameObject objectToSend_, string ip_, string port_, float x, float y, float ox, float oy)
    {
        objectToSend = objectToSend_;
        if (objectToSend == null) return;
        parameters = null;

        ip = ip_;
        port = port_;
        GamaCRSCoefX = x;
        GamaCRSCoefY = y;
        GamaCRSOffsetX = ox;
        GamaCRSOffsetY = oy;

        UnityGeometry ug = new UnityGeometry(objectToSend, new CoordinateConverter(10000, x, y, ox, oy));
        string message = ug.ToJSON();

        argsToSend = new Dictionary<string, string>
        {
            { "geoms", message }
        };

        socket = new WebSocket("ws://" + ip + ":" + port + "/");

        continueProcess = true;

        socket.OnOpen += HandleConnectionOpen;
        socket.OnMessage += HandleReceivedMessage;
        socket.OnClose += HandleConnectionClosed;

        // Per-message Compression extension disabled to save bandwidth.
        socket.Compression = CompressionMethod.None;

        socket.Connect();

        // Simple loop to wait for parameter data before exporting geometries.
        while (continueProcess)
        {
            if (parameters != null)
            {
                ExportGeoms();
                continueProcess = false;
            }
        }
    }

    void HandleConnectionClosed(object sender, CloseEventArgs e)
    {
        continueProcess = false;
    }

    void HandleConnectionOpen(object sender, EventArgs e)
    {
        // Prebuild the entire JSON payload as a string.
        string rawJson = "{\"type\":\"connection\",\"id\":\"geomexporter\",\"heartbeat\":\"5000\"}";
    
        using (var stream = new MemoryStream())
        {
            using (var writer = new Utf8JsonWriter(stream))
            {
                // Write the raw JSON in one call.
                writer.WriteRawValue(rawJson, skipInputValidation: true);
                writer.Flush();
            }
            string jsonStringId = Encoding.UTF8.GetString(stream.ToArray());
            SendMessageToServer(jsonStringId, (success) =>
            {
                // Optionally handle the send success.
            });
        }
        Debug.Log("ConnectionManager: Connection opened");
    }


    private void ExportGeoms()
    {
        Debug.Log("export Geom");
        if (parameters != null)
        {
            SendExecutableAsk("receive_geometries", argsToSend);
            continueProcess = false;
        }
    }

    void HandleServerMessageReceived(string firstKey, string content)
    {
        if (string.IsNullOrEmpty(content) || content.Equals("{}"))
            return;
        else if (content.Contains("precision"))
            firstKey = "precision";

        switch (firstKey)
        {
            // Handle general information about the simulation.
            case "precision":
                parameters = ConnectionParameter.CreateFromJSON(content);
                Debug.Log("Received parameter data");
                break;
            // Other cases for handling geometries can be added here.
        }
    }

    void HandleReceivedMessage(object sender, MessageEventArgs e)
    {
        if (e.IsText)
        {
            ReadOnlySpan<byte> jsonBytes = Encoding.UTF8.GetBytes(e.Data);
            var reader = new Utf8JsonReader(jsonBytes, isFinalBlock: true, state: default);

            string type = null;
            string contentsJson = null;
            bool inGameFlag = false;
            bool foundType = false;
            bool foundContents = false;
            bool foundInGame = false;

            // Process JSON tokens manually.
            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string propertyName = reader.GetString();
                    if (propertyName == "type")
                    {
                        reader.Read();
                        type = reader.GetString();
                        foundType = true;
                    }
                    else if (propertyName == "contents" && type == "json_output")
                    {
                        // Use JsonDocument to capture the nested object.
                        using (JsonDocument doc = JsonDocument.ParseValue(ref reader))
                        {
                            contentsJson = doc.RootElement.GetRawText();
                        }
                        foundContents = true;
                    }
                    else if (propertyName == "in_game" && type == "json_state")
                    {
                        reader.Read();
                        inGameFlag = reader.GetBoolean();
                        foundInGame = true;
                    }
                }
            }

            if (foundType)
            {
                if (type == "json_output" && foundContents)
                {
                    // Manually iterate properties of the contents object to get the first key.
                    string firstKey = null;
                    using (JsonDocument doc = JsonDocument.Parse(contentsJson))
                    {
                        JsonElement root = doc.RootElement;
                        if (root.ValueKind == JsonValueKind.Object)
                        {
                            foreach (JsonProperty prop in root.EnumerateObject())
                            {
                                firstKey = prop.Name;
                                break;
                            }
                        }
                    }
                    HandleServerMessageReceived(firstKey, contentsJson);
                }
                else if (type == "json_state" && foundInGame)
                {
                    if (inGameFlag)
                    {
                        var args = new Dictionary<string, string> { { "id", "geomexporter" } };
                        SendExecutableAsk("send_init_data", args);
                    }
                }
            }
        }
    }
}
