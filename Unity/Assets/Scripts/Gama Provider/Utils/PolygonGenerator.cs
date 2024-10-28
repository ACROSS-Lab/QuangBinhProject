using System;
using System.Collections.Generic;
using UnityEngine;

public class PolygonGenerator
{
    CoordinateConverter converter;
    float offsetYBackgroundGeom;

    private static PolygonGenerator instance;

    public Mesh surroundMesh;
    public Mesh bottomMesh;
    public Mesh topMesh;

    public PolygonGenerator() { }

    public void Init(CoordinateConverter c)
    {
        converter = c;
    }

    public static PolygonGenerator GetInstance()
    {
        if (instance == null)
        {
            instance = new PolygonGenerator();
        }
        return instance;
    }

    public static void DestroyInstance()
    {
        instance = null;
    }

    public GameObject GeneratePolygons(bool editMode, String name, List<int> points, PropertiesGAMA prop, int precision)
    {
        List<Vector2> pts = new List<Vector2>();

        // Convert points from GAMA CRS to Unity's coordinate system
        for (int i = 0; i < points.Count - 1; i = i + 2)
        {
            Vector2 p = converter.fromGAMACRS2D(points[i], points[i + 1]);
            pts.Add(p);
        }

        Vector2[] MeshDataPoints = pts.ToArray();


        MeshDataPoints = SubdivideMesh(MeshDataPoints, 2);

  
        MeshDataPoints = ApplyLaplacianSmoothing(MeshDataPoints, iterations: 5);

        Color32 col = Color.black;
        Material mat = null;
        if (prop.visible)
        {
            if (prop.material != null && prop.material != "")
            {
                mat = Resources.Load<Material>(prop.material);
            }
            col = new Color32(BitConverter.GetBytes(prop.red)[0], BitConverter.GetBytes(prop.green)[0],
                              BitConverter.GetBytes(prop.blue)[0], BitConverter.GetBytes(prop.alpha)[0]);
        }

        GameObject obj = GeneratePolygon(editMode, name, MeshDataPoints, ((float)prop.height) / precision, mat, col);

        if (!prop.visible)
        {
            MeshRenderer r = obj.GetComponent<MeshRenderer>();
            if (r != null) r.enabled = false;
            foreach (MeshRenderer rr in obj.GetComponentsInChildren<MeshRenderer>())
            {
                if (rr != null) rr.enabled = false;
            }
            LineRenderer lr = obj.GetComponent<LineRenderer>();
            if (lr != null)
                lr.enabled = false;
        }

        ApplySmoothShading(obj, mat);

        return obj;
    }

    Vector2[] SubdivideMesh(Vector2[] points, int subdivisions)
    {
        List<Vector2> subdividedPoints = new List<Vector2>(points);

        for (int s = 0; s < subdivisions; s++)
        {
            List<Vector2> newPoints = new List<Vector2>();

            for (int i = 0; i < subdividedPoints.Count; i++)
            {
                Vector2 p0 = subdividedPoints[i];
                Vector2 p1 = subdividedPoints[(i + 1) % subdividedPoints.Count];


                newPoints.Add(p0);

                Vector2 midpoint = (p0 + p1) * 0.5f;
                newPoints.Add(midpoint);
            }

            subdividedPoints = newPoints;
        }

        return subdividedPoints.ToArray();
    }

    Vector2[] ApplyLaplacianSmoothing(Vector2[] points, int iterations)
    {
        Vector2[] smoothedPoints = new Vector2[points.Length];

        for (int iter = 0; iter < iterations; iter++)
        {
            for (int i = 1; i < points.Length - 1; i++)
            {
                smoothedPoints[i] = (points[i - 1] + points[i + 1]) * 0.5f;
            }
            points = smoothedPoints;
        }
        return points;
    }

    void ApplySmoothShading(GameObject obj, Material mat)
    {
        MeshRenderer r = obj.GetComponent<MeshRenderer>();
        if (r != null)
        {
            r.material = mat;
            Mesh mesh = obj.GetComponent<MeshFilter>().mesh;
            mesh.RecalculateNormals();
        }
    }
    
    GameObject GeneratePolygon(bool editMode, String name, Vector2[] MeshDataPoints, float extrusionHeight, Material mat, Color32 color)
    {
        bool isUsingBottomMeshIn3D = false;
        bool isOutlineRendered = true;
        bool is3D = extrusionHeight != 0.0;


        GameObject polyExtruderGO = new GameObject(name);
        polyExtruderGO.transform.position = new Vector3(0, offsetYBackgroundGeom, 0);


        MeshFilter mf = polyExtruderGO.AddComponent<MeshFilter>();
        MeshRenderer mr = polyExtruderGO.AddComponent<MeshRenderer>();
        mr.material = mat; // Set the material


        PolyExtruder polyExtruder = polyExtruderGO.AddComponent<PolyExtruder>();
        polyExtruder.isOutlineRendered = isOutlineRendered;
        polyExtruder.createPrism(editMode, name, extrusionHeight, MeshDataPoints, color, mat, is3D, isUsingBottomMeshIn3D);


        mf.mesh = polyExtruder.surroundMesh;
        surroundMesh = polyExtruder.surroundMesh;
        bottomMesh = polyExtruder.bottomMesh;
        topMesh = polyExtruder.topMesh;

        return polyExtruderGO; // Return the generated GameObject
    }
}