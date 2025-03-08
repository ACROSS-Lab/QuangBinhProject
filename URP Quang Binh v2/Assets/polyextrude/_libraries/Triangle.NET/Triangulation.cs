/*
 * Triangulation.cs
 *
 * Description: Class to triangulate (create render triangles for) a custom polygon mesh.
 * The class has been adapted from the Triangle.NET library, following the video setup tutorial at https://www.youtube.com/watch?v=wByVhzokWPo (note: unfortunately, the video is no longer available as of 2019-06-04).
 * 
 * Triangle.NET library implementation (by Christian Woltering): https://archive.codeplex.com/?p=triangle
 * (Original) Triangle library implementation (by Jonathan Richard Shewchuk): http://www.cs.cmu.edu/~quake/triangle.html
 * 
 * Supported Unity version: 2021.3.16f1 Personal (tested)
 *
 * Author: Nico Reski
 * Web: https://reski.nicoversity.com
 * Twitter: @nicoversity
 * GitHub: https://github.com/nicoversity
 * 
 */

using UnityEngine;
using System.Collections.Generic;
using TriangleNet.Geometry;

public class Triangulation
{
    // Custom comparer for Vector2 that uses a specified tolerance for equality.
    private class Vector2ToleranceComparer : IEqualityComparer<Vector2>
    {
        private readonly float tolerance;
        public Vector2ToleranceComparer(float tolerance)
        {
            this.tolerance = tolerance;
        }

        public bool Equals(Vector2 a, Vector2 b)
        {
            return Mathf.Abs(a.x - b.x) < tolerance && Mathf.Abs(a.y - b.y) < tolerance;
        }

        public int GetHashCode(Vector2 obj)
        {
            // Quantize the values using a centered bucket approach.
            int hashX = Mathf.FloorToInt((obj.x + tolerance / 2f) / tolerance);
            int hashY = Mathf.FloorToInt((obj.y + tolerance / 2f) / tolerance);
            // Combine the quantized values with a prime multiplier to form the hash code.
            return hashX * 397 ^ hashY;
        }
    }
    
    /// <summary>
    /// Perform triangulation for a custom (polygon) mesh.
    /// </summary>
    /// <param name="points">List of Vector2 points representing the polygon boundary.</param>
    /// <param name="holes">List of lists of Vector2 points representing holes in the polygon.</param>
    /// <param name="vertexY">Y-coordinate value for the resulting 3D vertices.</param>
    /// <param name="outIndices">Output list of triangle indices.</param>
    /// <param name="outVertices">Output list of 3D vertices.</param>
    /// <returns>Always returns true (error handling not implemented).</returns>
    public static bool triangulate(List<Vector2> points, List<List<Vector2>> holes, float vertexY, out List<int> outIndices, out List<Vector3> outVertices)
    {
        // Create the polygon and precompute boundary Vertex objects to avoid redundant allocations.
        Polygon poly = new Polygon();
        int pointCount = points.Count;
        Vertex[] boundaryVertices = new Vertex[pointCount];
        for (int i = 0; i < pointCount; i++)
        {
            boundaryVertices[i] = new Vertex(points[i].x, points[i].y);
            poly.Add(boundaryVertices[i]);
        }
        
        // Add segments to close the polygon.
        for (int i = 0; i < pointCount; i++)
        {
            int next = (i + 1) % pointCount;
            poly.Add(new Segment(boundaryVertices[i], boundaryVertices[next]));
        }
        
        // Handle holes if provided.
        if (holes != null)
        {
            foreach (List<Vector2> holePoints in holes)
            {
                int holeCount = holePoints.Count;
                Vertex[] holeVertices = new Vertex[holeCount];
                for (int j = 0; j < holeCount; j++)
                {
                    holeVertices[j] = new Vertex(holePoints[j].x, holePoints[j].y);
                }
                // Add the hole contour to the polygon.
                poly.Add(new Contour(holeVertices), true);
            }
        }
        
        // Perform triangulation using Triangle.NET.
        var mesh = poly.Triangulate();
        
        // Preallocate output lists; each triangle contributes 3 vertices.
        outVertices = new List<Vector3>(mesh.Triangles.Count * 3);
        outIndices = new List<int>(mesh.Triangles.Count * 3);
        
        // Dictionary to quickly check for duplicate vertices using our tolerance comparer.
        var vertexMap = new Dictionary<Vector2, int>(new Vector2ToleranceComparer(Mathf.Epsilon));
        
        // Process each triangle and its vertices.
        foreach (ITriangle t in mesh.Triangles)
        {
            // Process vertices in reverse order to maintain the correct winding order.
            for (int j = 2; j >= 0; j--)
            {
                var vertex = t.GetVertex(j);
                Vector2 key = new Vector2((float)vertex.X, (float)vertex.Y);
                int index;
                if (!vertexMap.TryGetValue(key, out index))
                {
                    index = outVertices.Count;
                    outVertices.Add(new Vector3((float)vertex.X, vertexY, (float)vertex.Y));
                    vertexMap.Add(key, index);
                }
                outIndices.Add(index);
            }
        }
        
        // Return true to indicate success (error handling can be added as needed).
        return true;
    }
}