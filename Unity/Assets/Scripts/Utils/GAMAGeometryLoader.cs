
using UnityEngine;
using WebSocketSharp;
using System;
using Newtonsoft.Json.Linq;
using System.Collections.Generic;
using UnityEngine.XR.Interaction.Toolkit;

using Newtonsoft.Json;
using System.Linq;

public class GAMAGeometryLoader: ConnectionWithGama
{
   
    // optional: define a scale between GAMA and Unity for the location given
    public float offsetYBackgroundGeom = 0.0f;
    protected WorldJSONInfo infoWorld;
    protected Dictionary<string, List<object>> geometryMap;

    private PolygonGenerator polyGen;

//    private GAMAGeometry geoms;

    private bool continueProcess = true;
    public float GamaCRSCoefX = 1.0f;
    public float GamaCRSCoefY = 1.0f;
    public float GamaCRSOffsetX = 0.0f;
    public float GamaCRSOffsetY = 0.0f;

    protected Dictionary<string, PropertiesGAMA> propertyMap = null;


    protected AllProperties propertiesGAMA;
    protected ConnectionParameter parameters = null;
    protected CoordinateConverter converter;


    public void GenerateGeometries(string ip_, string port_, float x, float y, float ox, float oy, float YOffset)
    {
       ip = ip_;
        port = port_;
        GamaCRSCoefX = x;
        GamaCRSCoefY = y;
        GamaCRSOffsetX = ox;
        GamaCRSOffsetY = oy;
        offsetYBackgroundGeom = YOffset;
        socket = new WebSocket("ws://" + ip + ":" + port + "/");
        Debug.Log("ws://" + ip + ":" + port + "/");
         continueProcess = true;

        socket.OnMessage += HandleReceivedMessage;
        socket.OnOpen += HandleConnectionOpen;


        socket.Connect();

        DateTime dt = DateTime.Now;
        dt = dt.AddSeconds(60);
        while (continueProcess) {
            if (infoWorld != null)
            {
                generateGeom();
                continueProcess = false;
            }
            if (DateTime.Now.CompareTo(dt) >= 0)
            {
                Debug.Log("end");
                break;
            }
        }
         

    }

    void HandleConnectionOpen(object sender, System.EventArgs e)
    {
            var jsonId = new Dictionary<string, string> {
                {"type", "connection"},
                { "id", "geomloader" },
                { "set_heartbeat", "false" }
            };
            string jsonStringId = JsonConvert.SerializeObject(jsonId);
            SendMessageToServer(jsonStringId, new Action<bool>((success) => {
                if (success) { }
            }));
            Debug.Log("ConnectionManager: Connection opened");
        

    }


    private GameObject instantiatePrefab(String name, PropertiesGAMA prop)
    {
        if (prop.prefabObj == null)
        {
            prop.loadPrefab(parameters.precision);
        }
        GameObject obj = Instantiate(prop.prefabObj);
        float scale = ((float)prop.size) / parameters.precision;
        obj.transform.localScale = new Vector3(scale, scale, scale);
        obj.SetActive(true);

        if (prop.hasCollider)
        {
            if (obj.TryGetComponent<LODGroup>(out var lod))
            {
                foreach (LOD l in lod.GetLODs())
                {
                    GameObject b = l.renderers[0].gameObject;
                    BoxCollider bc = b.AddComponent<BoxCollider>();
                    // b.tag = obj.tag;
                    // b.name = obj.name;
                    //bc.isTrigger = prop.isTrigger;
                }

            }
            else
            {
                BoxCollider bc = obj.AddComponent<BoxCollider>();
                // bc.isTrigger = prop.isTrigger;
            }
        }
        List<object> pL = new List<object>();
        pL.Add(obj); pL.Add(prop);
        instantiateGO(obj, name, prop);
        return obj;
    }


    private void instantiateGO(GameObject obj, String name, PropertiesGAMA prop)
    {
        obj.name = name;
       
        if (prop.tag != null && !string.IsNullOrEmpty(prop.tag))
            obj.tag = prop.tag;

        if (prop.isInteractable)
        {
            XRBaseInteractable interaction = null;
            if (prop.isGrabable)
            {
                interaction = obj.AddComponent<XRGrabInteractable>();
                Rigidbody rb = obj.GetComponent<Rigidbody>();
                if (prop.constraints != null && prop.constraints.Count == 6)
                {
                    if (prop.constraints[0])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionX;
                    if (prop.constraints[1])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionY;
                    if (prop.constraints[2])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezePositionZ;
                    if (prop.constraints[3])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationX;
                    if (prop.constraints[4])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationY;
                    if (prop.constraints[5])
                        rb.constraints = rb.constraints | RigidbodyConstraints.FreezeRotationZ;
                }


            }
            else 
            {

                interaction = obj.AddComponent<XRSimpleInteractable>();


            }
            if (interaction.colliders.Count == 0)
            {
                Collider[] cs = obj.GetComponentsInChildren<Collider>();
                if (cs != null)
                {
                    foreach (Collider c in cs)
                    {
                        interaction.colliders.Add(c);
                    }
                }
            }
           

        }
    }

void GenerateGeometries()
{
    Debug.Log("GenerateGeometries");
    Dictionary<PropertiesGAMA, List<GameObject>> mapObjects = new Dictionary<PropertiesGAMA, List<GameObject>>();
    int cptPrefab = 0;
    int cptGeom = 0;

    // Step 1: Retrieve raw information and generate raw geometries (not displayed yet)
    for (int i = 0; i < infoWorld.names.Count; i++)
    {
        string name = infoWorld.names[i];
        string propId = infoWorld.propertyID[i];
        PropertiesGAMA prop = propertyMap[propId];
        GameObject obj = null;

        // Prefab case
        if (prop.hasPrefab)
        {
            obj = instantiatePrefab(name, prop); 
            
            List<int> pt = infoWorld.pointsLoc[cptPrefab].c;
            Vector3 pos = converter.fromGAMACRS(pt[0], pt[1], pt[2]);
            pos.y += pos.y + prop.yOffsetF;
            float rot = prop.rotationCoeffF * ((0.0f + pt[3]) / parameters.precision) + prop.rotationOffsetF;
            obj.transform.SetPositionAndRotation(pos, Quaternion.AngleAxis(rot, Vector3.up));

            // Apply smooth shading to the prefab
            Mesh mesh = obj.GetComponent<MeshFilter>().mesh;
            if (mesh != null)
            {
                mesh.RecalculateNormals();
            }

            cptPrefab++;
        }
        else // Custom polygon case
        {
            if (polyGen == null)
            {
                polyGen = PolygonGenerator.GetInstance();
                polyGen.Init(converter);
            }
            List<int> pt = infoWorld.pointsGeom[cptGeom].c;
            obj = polyGen.GeneratePolygons(true, name, pt, prop, parameters.precision);

            // Step 2: Do not display yet, instead identify square-like areas or sharp edges
            MeshFilter meshFilter = obj.GetComponent<MeshFilter>();
            if (meshFilter != null)
            {
                Mesh mesh = meshFilter.mesh;
                
                // Step 3: Identify if the area is square-like or has sharp edges
                if (IsSquareArea(mesh)) // Function to check if this is a square-like area
                {
                    // Step 4: Apply circularization for square-like areas
                    ApplyCircularModifier(mesh); // Transform sharp/square edges into circular/rounded shapes
                }
                
                // Optionally apply subdivision for more detail (if needed)
                SubdivideMesh(mesh, 1); // Add more detail for smoother geometries
                
                // Step 5: Apply Laplacian smoothing to make edges less sharp
                LaplacianSmooth(mesh, 5); // Smooth the entire mesh (rounded areas)

                // Recalculate normals for smooth shading
                mesh.RecalculateNormals();
            }

            // Add collider if required
            if (prop.hasCollider)
            {
                MeshCollider mc = obj.AddComponent<MeshCollider>();
                if (prop.isGrabable)
                {
                    mc.convex = true;
                }
                mc.sharedMesh = polyGen.surroundMesh;
            }

            instantiateGO(obj, name, prop); // Now we display the geometry
            cptGeom++;
        }

        // Add object to the map
        if (obj != null)
        {
            if (!mapObjects.ContainsKey(prop))
                mapObjects[prop] = new List<GameObject>();
            mapObjects[prop].Add(obj);
        }
    }

    // Organize the generated objects
    GameObject n = new GameObject("GENERATED");
    foreach (PropertiesGAMA p in mapObjects.Keys)
    {
        GameObject g = new GameObject(p.id);
        g.transform.parent = n.transform;
        foreach (GameObject o in mapObjects[p])
        {
            o.transform.parent = g.transform;
        }
    }
    infoWorld = null;
}

// Function to check if a mesh represents a square or rectangular area (sharp or 90-degree angles)
bool IsSquareArea(Mesh mesh)
{
    Vector3[] vertices = mesh.vertices;

    // Check the bounding box for a square-like aspect ratio
    Vector3 boundsSize = mesh.bounds.size;
    float aspectRatio = boundsSize.x / boundsSize.z;

    // Detect square-like shapes based on aspect ratio and vertex sharpness
    return Mathf.Approximately(aspectRatio, 1.0f) || Mathf.Approximately(boundsSize.x, boundsSize.z);
}

// Function to apply circular modifier to a mesh, transforming sharp areas into circular ones
void ApplyCircularModifier(Mesh mesh)
{
    Vector3[] vertices = mesh.vertices;
    Vector3 center = mesh.bounds.center; // Get the center of the mesh

    // Adjust vertices toward a circular shape around the center
    for (int i = 0; i < vertices.Length; i++)
    {
        Vector3 direction = (vertices[i] - center).normalized; // Calculate direction from center
        float distance = Vector3.Distance(vertices[i], center);
        
        // Apply circular transformation (Lerp toward a circular shape)
        vertices[i] = center + direction * Mathf.Lerp(distance, mesh.bounds.extents.magnitude * 0.5f, 0.5f);
    }

    mesh.vertices = vertices;
    mesh.RecalculateBounds();
}

// Helper function to subdivide mesh for higher resolution (optional)
void SubdivideMesh(Mesh mesh, int subdivisions)
{
    if (subdivisions <= 0) return;

    Vector3[] oldVerts = mesh.vertices;
    int[] oldTris = mesh.triangles;

    Dictionary<long, int> newVertDict = new Dictionary<long, int>();
    List<Vector3> newVerts = new List<Vector3>(oldVerts);
    List<int> newTris = new List<int>();

    for (int i = 0; i < oldTris.Length; i += 3)
    {
        int v0 = oldTris[i];
        int v1 = oldTris[i + 1];
        int v2 = oldTris[i + 2];

        int v01 = GetMidpointVertexIndex(v0, v1, newVertDict, newVerts);
        int v12 = GetMidpointVertexIndex(v1, v2, newVertDict, newVerts);
        int v20 = GetMidpointVertexIndex(v2, v0, newVertDict, newVerts);

        // Create new triangles
        newTris.AddRange(new int[] { v0, v01, v20 });
        newTris.AddRange(new int[] { v1, v12, v01 });
        newTris.AddRange(new int[] { v2, v20, v12 });
        newTris.AddRange(new int[] { v01, v12, v20 });
    }

    mesh.vertices = newVerts.ToArray();
    mesh.triangles = newTris.ToArray();
    mesh.RecalculateBounds();
}

// Helper function to get the index of the midpoint vertex
int GetMidpointVertexIndex(int v0, int v1, Dictionary<long, int> newVertDict, List<Vector3> newVerts)
{
    long key = (v0 < v1) ? ((long)v0 << 32) + v1 : ((long)v1 << 32) + v0;
    if (newVertDict.ContainsKey(key))
    {
        return newVertDict[key];
    }

    Vector3 newVert = (newVerts[v0] + newVerts[v1]) * 0.5f;
    int newIndex = newVerts.Count;
    newVerts.Add(newVert);

    newVertDict[key] = newIndex;
    return newIndex;
}

// Function to smooth mesh using Laplacian smoothing algorithm
void LaplacianSmooth(Mesh mesh, int iterations)
{
    Vector3[] vertices = mesh.vertices;
    Vector3[] smoothedVertices = new Vector3[vertices.Length];

    // Iterate multiple times to achieve the desired smoothness
    for (int iter = 0; iter < iterations; iter++)
    {
        // For each vertex, calculate the average position of its neighbors
        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 sum = Vector3.zero;
            int neighborCount = 0;

            // Find connected vertices (edges)
            foreach (int neighbor in GetConnectedVertices(mesh, i))
            {
                sum += vertices[neighbor];
                neighborCount++;
            }

            // Calculate the average position of neighbors
            if (neighborCount > 0)
            {
                smoothedVertices[i] = sum / neighborCount;
            }
            else
            {
                smoothedVertices[i] = vertices[i]; // No neighbors, keep original position
            }
        }

        // Update the mesh vertices with the smoothed positions
        for (int i = 0; i < vertices.Length; i++)
        {
            vertices[i] = smoothedVertices[i];
        }

        // Recalculate the mesh normals and bounds after smoothing
        mesh.vertices = vertices;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
    }
}

// Helper function to get the connected vertices of a given vertex in the mesh
List<int> GetConnectedVertices(Mesh mesh, int vertexIndex)
{
    List<int> connectedVertices = new List<int>();
    int[] triangles = mesh.triangles;

    // Check through all triangles and find shared vertices
    for (int i = 0; i < triangles.Length; i += 3)
    {
        if (triangles[i] == vertexIndex || triangles[i + 1] == vertexIndex || triangles[i + 2] == vertexIndex)
        {
            // Add the other two vertices of the triangle as neighbors
            if (triangles[i] != vertexIndex) connectedVertices.Add(triangles[i]);
            if (triangles[i + 1] != vertexIndex) connectedVertices.Add(triangles[i + 1]);
            if (triangles[i + 2] != vertexIndex) connectedVertices.Add(triangles[i + 2]);
        }
    }

    return connectedVertices;
}



    private void generateGeom()
    {


       if (parameters != null && converter != null )
        {

            GenerateGeometries();
            continueProcess = false;

        }
    }

    void HandleServerMessageReceived(string firstKey, String content)
    {

        if (content == null || content.Equals("{}")) return;
     
        switch (firstKey)
        {
            // handle general informations about the simulation
            case "precision":

                parameters = ConnectionParameter.CreateFromJSON(content);
                converter = new CoordinateConverter(parameters.precision, GamaCRSCoefX, GamaCRSCoefY, GamaCRSCoefY, GamaCRSOffsetX, GamaCRSOffsetY, 1.0f);
    
                break;

            case "properties":
                propertiesGAMA = AllProperties.CreateFromJSON(content);
                propertyMap = new Dictionary<string, PropertiesGAMA>();
                foreach (PropertiesGAMA p in propertiesGAMA.properties)
                {
                    propertyMap.Add(p.id, p);
                }
                break;

            // handle agents while simulation is running
            case "pointsLoc":
                if (infoWorld == null)
                {
                    infoWorld = WorldJSONInfo.CreateFromJSON(content);
                    //Debug.Log("Current poinstLoc infoWorld score: " + infoWorld.score);
                    //Debug.Log("Current poinstLoc infoWorld budget: " + infoWorld.budget);
                    //Debug.Log("Current pointsLoc ok_to_build_dyke: " + infoWorld.ok_build_dyke_with_unity);
                }
                break;
        }

    

}
   void HandleReceivedMessage(object sender, MessageEventArgs e)
    {

        if (e.IsText)
        {
            JObject jsonObj = JObject.Parse(e.Data);
            string type = (string)jsonObj["type"];
         
            if (type.Equals("json_output"))
            {
                JObject content = (JObject)jsonObj["contents"];
                String firstKey = content.Properties().Select(pp => pp.Name).FirstOrDefault();
                HandleServerMessageReceived(firstKey, content.ToString());

            }
            else if(type.Equals("json_state")) {

                Boolean inGame = (Boolean)jsonObj["in_game"];
                if (inGame != null && inGame)
                {
                    Dictionary<string, string> args = new Dictionary<string, string> {
                         {"id", "geomloader" }
                    };
                   
                    SendExecutableAsk("send_init_data", args);

                }
            }
        } 
    }

}