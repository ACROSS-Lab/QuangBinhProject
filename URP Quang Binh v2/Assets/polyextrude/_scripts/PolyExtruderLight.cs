/*
 * PolyExtruderLight.cs
 *
 * Description: Lightweight implementation of the original PolyExtruder.cs class
 *              combining the three original meshes (bottom, top, surround) into one mesh at runtime.
 *
 * New in this version:
 * - Accepts a custom Material.
 * - Falls back to "Universal Render Pipeline/Lit" if no material is provided.
 * - Applies the provided color to the final material.
 *
 * ATTENTION: No holes-support in polygon extrusion (Prism 3D) implemented!
 *
 * Supported Unity version: 2022.3.20f1 Personal (tested)
 *
 * Version: 2024.11
 * Author: Nico Reski
 * GitHub: https://github.com/nicoversity
 *
 */

using UnityEngine;
using System.Collections.Generic;

public class PolyExtruderLight : MonoBehaviour
{
    #region Properties

    [Header("Prism Configuration")]
    public string prismName;          // reference to name of the prism
    public Color32 prismColor;        // reference to prism color
    public float polygonArea;         // reference to area of (top) polygon
    public Vector2 polygonCentroid;   // reference to centroid of (top) polygon

    // If no custom material is provided, we fallback to this shader.
    // Change this to "Standard" if you use the Built-in Render Pipeline,
    // or "HDRP/Lit" if you use HDRP, etc.
    [Header("Material Configuration")]
    public string fallbackShader = "Universal Render Pipeline/Lit";

    // We store a reference to the material you pass in (if any).
    private Material prismMaterial;

    // reference to extrusion height (Y axis)
    private static readonly float DEFAULT_BOTTOM_Y = 0.0f;
    private static readonly float DEFAULT_TOP_Y = 1.0f;
    private float extrusionHeightY = 1.0f;

    // reference to original input vertices of Polygon in Vector2 Array format
    private Vector2[] originalPolygonVertices;
    public Vector2[] OriginalPolygonVertices { get { return originalPolygonVertices; } }

    // cached references to GameObject Components
    private Transform prismTransform;
    private MeshFilter prismMeshFilter;
    private MeshRenderer prismMeshRenderer;

    #endregion


    #region MeshCreator

    /// <summary>
    /// Create a prism based on the input parameters, combining everything into a single mesh.
    /// </summary>
    /// <param name="prismName">Name of the prism within the Unity scene.</param>
    /// <param name="height">Height of the prism (distance along the y-axis).</param>
    /// <param name="vertices">Vector2 Array representing the input data of the polygon.</param>
    /// <param name="color">Color of the prism’s material.</param>
    /// <param name="mat">Optional custom Material. If null, a fallback material is created.</param>
    public void createPrism(string prismName, float height, Vector2[] vertices, Color32 color, Material mat = null)
    {
        // store data
        this.prismName = prismName;
        this.extrusionHeightY = height;
        this.originalPolygonVertices = vertices;
        this.prismColor = color;
        this.polygonArea = 0.0f;
        this.polygonCentroid = Vector2.zero;
        this.prismTransform = this.transform;
        this.prismMeshFilter = this.gameObject.AddComponent<MeshFilter>();
        this.prismMeshRenderer = this.gameObject.AddComponent<MeshRenderer>();

        // store the custom material (may be null)
        this.prismMaterial = mat;

        // ensure vertices are clockwise
        bool vertexOrderClockwise = areVerticesOrderedClockwise(this.originalPolygonVertices);
        if (!vertexOrderClockwise)
            System.Array.Reverse(this.originalPolygonVertices);

        // calculate area and centroid
        bool isAreaAndCentroidSet = calculateAreaAndCentroid(this.originalPolygonVertices);
        if (isAreaAndCentroidSet)
        {
            initPrism();
        }
        else
        {
            Debug.LogWarning("[PolyExtruderLight] createPrism failed. Area is zero for prism: " + this.prismName);
        }
    }

    /// <summary>
    /// Determine whether the input vertices are ordered clockwise or counter-clockwise.
    /// </summary>
    private bool areVerticesOrderedClockwise(Vector2[] vertices)
    {
        float edgesSum = 0.0f;
        for(int i = 0; i < vertices.Length; i++)
        {
            if(i+1 == vertices.Length)
            {
                edgesSum += (vertices[0].x - vertices[i].x) * (vertices[0].y + vertices[i].y);
            }
            else
            {
                edgesSum += (vertices[i + 1].x - vertices[i].x) * (vertices[i + 1].y + vertices[i].y);
            }
        }
        return (edgesSum >= 0.0f);
    }

    /// <summary>
    /// Calculate area and centroid of the polygon (2D).
    /// </summary>
    private bool calculateAreaAndCentroid(Vector2[] vertices)
    {
        double doubleArea = 0.0;
        double centroidX = 0.0;
        double centroidY = 0.0;

        for (int i = 0; i < vertices.Length; i++)
        {
            Vector2 vCurr = vertices[i];
            Vector2 vNext = (i + 1 == vertices.Length) ? vertices[0] : vertices[i + 1];

            double cross = (vCurr.x * vNext.y) - (vNext.x * vCurr.y);
            doubleArea += cross;
            centroidX += (vCurr.x + vNext.x) * cross;
            centroidY += (vCurr.y + vNext.y) * cross;
        }

        double polygonArea = (doubleArea < 0) ? -0.5 * doubleArea : 0.5 * doubleArea;
        this.polygonArea = (float)polygonArea;

        double sixTimesArea = doubleArea * 3.0; 
        if (!Mathf.Approximately(0.0f, (float)polygonArea))
        {
            this.polygonCentroid = new Vector2(
                (float)(centroidX / sixTimesArea),
                (float)(centroidY / sixTimesArea));
            return true;
        }
        else
        {
            return false;
        }
    }

    /// <summary>
    /// Create bottom, top, and surrounding meshes, then combine them into a single mesh.
    /// </summary>
    private void initPrism()
    {
        // Create child objects for bottom, top, and surround
        GameObject goB = new GameObject("bottom_" + this.prismName);
        goB.transform.parent = this.transform;
        MeshFilter mfB = goB.AddComponent<MeshFilter>();
        Mesh bottomMesh = mfB.mesh;

        GameObject goT = new GameObject("top_" + this.prismName);
        goT.transform.parent = this.transform;
        MeshFilter mfT = goT.AddComponent<MeshFilter>();
        Mesh topMesh = mfT.mesh;

        GameObject goS = new GameObject("surround_" + this.prismName);
        goS.transform.parent = this.transform;
        MeshFilter mfS = goS.AddComponent<MeshFilter>();
        Mesh surroundMesh = mfS.mesh;

        // Triangulate bottom
        List<Vector2> pointsB = new List<Vector2>();
        for(int i=0; i<originalPolygonVertices.Length; i++)
            pointsB.Add(originalPolygonVertices[i] - polygonCentroid);

        List<List<Vector2>> holesB = new List<List<Vector2>>();
        Triangulation.triangulate(pointsB, holesB, DEFAULT_BOTTOM_Y,
                                  out List<int> indicesB, out List<Vector3> verticesB);
        redrawMesh(bottomMesh, verticesB, indicesB);

        // flip bottom polygon so it's visible from outside
        goB.transform.localScale = new Vector3(-1f, -1f, -1f);
        goB.transform.localRotation = Quaternion.Euler(0f, 180f, 0f);

        // Triangulate top
        List<Vector2> pointsT = new List<Vector2>();
        for(int i=0; i<originalPolygonVertices.Length; i++)
            pointsT.Add(originalPolygonVertices[i] - polygonCentroid);

        List<List<Vector2>> holesT = new List<List<Vector2>>();
        Triangulation.triangulate(pointsT, holesT, DEFAULT_TOP_Y,
                                  out List<int> indicesT, out List<Vector3> verticesT);
        redrawMesh(topMesh, verticesT, indicesT);

        // Triangulate surround
        List<Vector3> verticesS = new List<Vector3>();
        List<int> indicesS = new List<int>();

        // The bottom set
        foreach(Vector2 vb in pointsB)
            verticesS.Add(new Vector3(vb.x, DEFAULT_BOTTOM_Y, vb.y));

        // The top set
        foreach(Vector2 vt in pointsT)
            verticesS.Add(new Vector3(vt.x, DEFAULT_TOP_Y, vt.y));

        int countB = pointsB.Count;
        int indexB = 0;
        int indexT = countB;
        int sumQuads = verticesS.Count / 2;
        for (int i = 0; i < sumQuads; i++)
        {
            if (i == (sumQuads - 1))
            {
                // last quad
                indicesS.Add(indexB);
                indicesS.Add(0);
                indicesS.Add(indexT);

                indicesS.Add(0);
                indicesS.Add(countB);
                indicesS.Add(indexT);
            }
            else
            {
                // normal quad
                indicesS.Add(indexB);
                indicesS.Add(indexB + 1);
                indicesS.Add(indexT);

                indicesS.Add(indexB + 1);
                indicesS.Add(indexT + 1);
                indicesS.Add(indexT);

                indexB++;
                indexT++;
            }
        }
        redrawMesh(surroundMesh, verticesS, indicesS);

        // Combine bottom, top, surround into a single mesh
        MeshFilter[] meshFilters = new MeshFilter[] { mfB, mfS, mfT };
        CombineInstance[] combine = new CombineInstance[meshFilters.Length];
        for(int i=0; i<meshFilters.Length; i++)
        {
            combine[i].mesh = meshFilters[i].sharedMesh;
            combine[i].transform = meshFilters[i].transform.localToWorldMatrix;
        }

        Mesh combinedMesh = new Mesh();
        combinedMesh.name = this.prismName + "_CombinedMesh";
        combinedMesh.CombineMeshes(combine);

        // Assign to main prism
        this.prismMeshFilter.mesh = combinedMesh;

        // Apply a valid material
        applyFinalMaterial();

        // Clean up child objects
        Destroy(goB);
        Destroy(goS);
        Destroy(goT);

        // Adjust final transforms
        updateHeight(this.extrusionHeightY);
        updateColor(this.prismColor);
        setAnchorPosToCentroid();
    }

    /// <summary>
    /// Rebuild mesh from vertices and indices.
    /// </summary>
    private void redrawMesh(Mesh mesh, List<Vector3> vertices, List<int> indices)
    {
        mesh.Clear();
        mesh.vertices = vertices.ToArray();
        mesh.triangles = indices.ToArray();
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
    }

    /// <summary>
    /// Assign the final material to the combined mesh.
    /// </summary>
    private void applyFinalMaterial()
    {
        if (this.prismMaterial != null)
        {
            // Use the provided material
            this.prismMeshRenderer.material = this.prismMaterial;
        }
        else
        {
            // Fallback to a newly created material using the fallback shader
            Material fallbackMat = new Material(Shader.Find(fallbackShader));
            this.prismMeshRenderer.material = fallbackMat;
        }
    }

    #endregion


    #region MeshManipulator

    /// <summary>
    /// Adjusts the prism’s extrusion height by scaling the y-axis.
    /// </summary>
    public void updateHeight(float height)
    {
        if (!Mathf.Approximately(this.extrusionHeightY, height))
        {
            this.extrusionHeightY = height;
        }
        this.prismTransform.localScale = new Vector3(1f, this.extrusionHeightY, 1f);
    }

    /// <summary>
    /// Updates the color of the prism’s material.
    /// </summary>
    public void updateColor(Color32 color)
    {
        if (!this.prismColor.Equals(color))
        {
            this.prismColor = color;
        }
        // If the material is valid, set its color.
        if (this.prismMeshRenderer != null && this.prismMeshRenderer.material != null)
        {
            this.prismMeshRenderer.material.color = this.prismColor;
        }
    }

    /// <summary>
    /// Repositions the prism so that its centroid is at (x,z) = (centroid.x, centroid.y).
    /// </summary>
    private void setAnchorPosToCentroid()
    {
        this.gameObject.transform.localPosition = new Vector3(
            this.polygonCentroid.x,
            DEFAULT_BOTTOM_Y,
            this.polygonCentroid.y);
    }

    #endregion
}
