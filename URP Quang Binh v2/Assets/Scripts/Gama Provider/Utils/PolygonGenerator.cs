using System;
using System.Collections.Generic;
using UnityEngine;

public class PolygonGenerator
{
    private CoordinateConverter converter;
    private float offsetYBackgroundGeom;

    private static PolygonGenerator instance;

    private PolygonGenerator() { }

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

    /// <summary>
    /// Generate polygons from a list of int coordinates. The list is assumed to store x,y in pairs.
    /// </summary>
    public GameObject GeneratePolygons(bool editMode, string name, int[] points, PropertiesGAMA prop, int precision)
    {
        int pointCount = points.Length;
        Vector2[] pts = new Vector2[pointCount / 2]; // Allocate array with required size
        
        for (int i = 0; i < pointCount - 1; i += 2)
        {
            pts[i / 2] = converter.fromGAMACRS2D(points[i], points[i + 1]);
        }

        return GeneratePolygons(editMode, name, pts, prop, precision);
    }

    /// <summary>
    /// Generate polygons from an array of Vector2 coordinates.
    /// </summary>
    public GameObject GeneratePolygons(bool editMode, string name, Vector2[] meshDataPoints, PropertiesGAMA prop, int precision)
    {
        // Prepare color from GAMA properties
        Color32 col = Color.black;
        if (prop.visible)
        {
            col = new Color32(
                BitConverter.GetBytes(prop.red)[0],
                BitConverter.GetBytes(prop.green)[0],
                BitConverter.GetBytes(prop.blue)[0],
                BitConverter.GetBytes(prop.alpha)[0]);
        }

        // Load a custom material if specified
        Material mat = null;
        if (prop.visible && !string.IsNullOrEmpty(prop.material))
        {
            // e.g. "Assets/Materials/MyMaterial" (without extension) if placed in Resources folder
            mat = Resources.Load<Material>(prop.material);
        }

        // Calculate the extrusion height
        float extrHeight = (float)prop.height / precision;

        // Create the extruded polygon object
        GameObject obj = GeneratePolygon(name, meshDataPoints, extrHeight, col, mat);

        // Hide mesh if not visible
        if (!prop.visible)
        {
            MeshRenderer r = obj.GetComponent<MeshRenderer>();
            if (r != null) r.enabled = false;
            foreach (MeshRenderer rr in obj.GetComponentsInChildren<MeshRenderer>())
            {
                if (rr != null) rr.enabled = false;
            }
        }

        return obj;
    }

    /// <summary>
    /// Internal helper that actually creates the GameObject with PolyExtruderLight.
    /// </summary>
    private GameObject GeneratePolygon(string name, Vector2[] meshDataPoints, float extrusionHeight, Color32 color, Material mat)
    {
        // Create a new GameObject with the given name
        GameObject polyExtruderGO = new GameObject(name);

        // Optionally offset the Y position
        Vector3 pos = polyExtruderGO.transform.position;
        pos.y += offsetYBackgroundGeom;
        polyExtruderGO.transform.position = pos;

        // Add PolyExtruderLight and call createPrism
        PolyExtruderLight polyExtruderLight = polyExtruderGO.AddComponent<PolyExtruderLight>();

        // The final parameter is the material, which can be null
        polyExtruderLight.createPrism(
            name,
            extrusionHeight,
            meshDataPoints,
            color,
            mat
        );

        return polyExtruderGO;
    }
}
