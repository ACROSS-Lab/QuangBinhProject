using System;
using System.Collections.Generic;

namespace TriangleNet.Geometry
{
    /// <summary>
    /// Represents a 2D point.
    /// </summary>
    public class Vertex
    {
        public double X { get; }
        public double Y { get; }
        
        public Vertex(double x, double y)
        {
            X = x;
            Y = y;
        }
    }

    /// <summary>
    /// Represents a segment (edge) defined by two vertices.
    /// </summary>
    public class Segment
    {
        public Vertex P { get; }
        public Vertex Q { get; }
        
        public Segment(Vertex p, Vertex q)
        {
            P = p;
            Q = q;
        }
    }

    /// <summary>
    /// Represents a contour – a closed sequence of vertices.
    /// Accepts any IEnumerable of Vertex, such as an array or a list.
    /// </summary>
    public class Contour
    {
        public List<Vertex> Vertices { get; }
        
        public Contour(IEnumerable<Vertex> vertices)
        {
            // Copy the vertices to a new list.
            Vertices = new List<Vertex>(vertices);
        }
    }

    /// <summary>
    /// Represents a polygon with an outer boundary (vertices and segments)
    /// and optional holes (as contours).
    /// </summary>
    public class Polygon
    {
        private readonly List<Vertex> outerVertices = new List<Vertex>();
        private readonly List<Segment> segments = new List<Segment>();
        private readonly List<Contour> holes = new List<Contour>();

        /// <summary>
        /// Adds a single vertex to the outer boundary.
        /// </summary>
        public void Add(Vertex v)
        {
            outerVertices.Add(v);
        }

        /// <summary>
        /// Adds a range of vertices (from an array or list) to the outer boundary.
        /// </summary>
        public void AddRange(IEnumerable<Vertex> vertices)
        {
            outerVertices.AddRange(vertices);
        }

        /// <summary>
        /// Adds a segment (edge) to the polygon.
        /// </summary>
        public void Add(Segment s)
        {
            segments.Add(s);
        }

        /// <summary>
        /// Adds a contour. If isHole is true, the contour is considered a hole;
        /// otherwise, its vertices are appended to the outer boundary.
        /// </summary>
        public void Add(Contour c, bool isHole)
        {
            if (isHole)
                holes.Add(c);
            else
                outerVertices.AddRange(c.Vertices);
        }

        /// <summary>
        /// Triangulates the polygon by first merging holes and then applying an
        /// optimized ear clipping algorithm.
        /// </summary>
        public Mesh Triangulate()
        {
            // Create a working copy of the outer polygon vertices.
            List<Vertex> polyVertices = new List<Vertex>(outerVertices);
            // Merge holes into the outer boundary.
            if (holes.Count > 0)
            {
                foreach (Contour hole in holes)
                {
                    MergeHole(ref polyVertices, hole.Vertices);
                }
            }

            // Triangulate the resulting simple polygon.
            List<Triangle> triangles = EarClippingTriangulate(polyVertices);
            return new Mesh(triangles);
        }

        /// <summary>
        /// Merges a hole (provided as any IEnumerable of vertices) into the outer polygon.
        /// A simple bridge is built from the rightmost vertex of the hole to an appropriate vertex on the outer polygon.
        /// </summary>
        private void MergeHole(ref List<Vertex> poly, IEnumerable<Vertex> hole)
        {
            // Ensure we have a List<Vertex> for random access.
            List<Vertex> holeList = hole as List<Vertex> ?? new List<Vertex>(hole);

            // Find rightmost vertex of the hole.
            int holeIndex = 0;
            Vertex rightMost = holeList[0];
            for (int i = 1; i < holeList.Count; i++)
            {
                if (holeList[i].X > rightMost.X)
                {
                    rightMost = holeList[i];
                    holeIndex = i;
                }
            }

            // Find a vertex in poly with the smallest positive x difference.
            int bridgeIndex = -1;
            double minDiff = double.MaxValue;
            for (int i = 0; i < poly.Count; i++)
            {
                double diff = poly[i].X - rightMost.X;
                if (diff > 0 && diff < minDiff)
                {
                    minDiff = diff;
                    bridgeIndex = i;
                }
            }
            if (bridgeIndex == -1)
            {
                bridgeIndex = 0;
            }

            // Merge the hole vertices into poly.
            List<Vertex> newPoly = new List<Vertex>(poly.Count + holeList.Count + 1);
            for (int i = 0; i <= bridgeIndex; i++)
            {
                newPoly.Add(poly[i]);
            }
            // Insert hole vertices starting from the rightmost vertex.
            for (int i = 0; i < holeList.Count; i++)
            {
                int idx = (holeIndex + i) % holeList.Count;
                newPoly.Add(holeList[idx]);
            }
            // Add the bridge vertex to complete the connection.
            newPoly.Add(poly[bridgeIndex]);
            for (int i = bridgeIndex + 1; i < poly.Count; i++)
            {
                newPoly.Add(poly[i]);
            }
            poly = newPoly;
        }

        /// <summary>
        /// Performs ear clipping triangulation using a circular doubly linked list.
        /// This avoids the overhead of repeated List removals.
        /// </summary>
        private List<Triangle> EarClippingTriangulate(List<Vertex> poly)
        {
            List<Triangle> triangles = new List<Triangle>();
            int n = poly.Count;
            if (n < 3)
                return triangles;

            // Build a circular doubly linked list of nodes.
            Node head = BuildDoublyLinkedList(poly);

            // Precompute ear status for each node.
            Node node = head;
            do
            {
                node.isEar = IsEar(node, n);
                node = node.next;
            } while (node != head);

            // Number of nodes remaining.
            int remaining = n;
            // Loop until only one triangle remains.
            while (remaining > 3)
            {
                // Find an ear node.
                Node ear = null;
                node = head;
                for (int i = 0; i < remaining; i++)
                {
                    if (node.isEar)
                    {
                        ear = node;
                        break;
                    }
                    node = node.next;
                }
                // If no ear is found (degenerate case), break.
                if (ear == null)
                    break;

                // Create a triangle from the ear.
                triangles.Add(new Triangle(ear.prev.v, ear.v, ear.next.v));

                // Remove ear from the list.
                ear.prev.next = ear.next;
                ear.next.prev = ear.prev;
                // If ear is the head, move head pointer.
                if (ear == head)
                    head = ear.next;
                remaining--;

                // Recompute ear status for the affected neighbors.
                ear.prev.isEar = IsEar(ear.prev, remaining);
                ear.next.isEar = IsEar(ear.next, remaining);
            }

            // Add the final triangle.
            if (remaining == 3)
            {
                triangles.Add(new Triangle(head.prev.v, head.v, head.next.v));
            }

            return triangles;
        }

        /// <summary>
        /// Builds a circular doubly linked list from a list of vertices.
        /// </summary>
        private Node BuildDoublyLinkedList(List<Vertex> vertices)
        {
            int n = vertices.Count;
            Node head = new Node(vertices[0]);
            Node prev = head;
            for (int i = 1; i < n; i++)
            {
                Node node = new Node(vertices[i]);
                prev.next = node;
                node.prev = prev;
                prev = node;
            }
            // Complete the circle.
            head.prev = prev;
            prev.next = head;
            return head;
        }

        /// <summary>
        /// Checks whether the given node forms an ear.
        /// It must be convex and no other vertex should lie inside the triangle.
        /// </summary>
        private bool IsEar(Node node, int totalNodes)
        {
            if (!IsConvex(node.prev.v, node.v, node.next.v))
                return false;

            // Check if any other node is inside the triangle.
            Node current = node.next.next;
            for (int i = 0; i < totalNodes - 3; i++)
            {
                if (PointInTriangle(current.v, node.prev.v, node.v, node.next.v))
                    return false;
                current = current.next;
            }
            return true;
        }

        /// <summary>
        /// Checks if the angle at vertex b (with neighbors a and c) is convex.
        /// Assumes vertices are in clockwise order.
        /// </summary>
        private static bool IsConvex(Vertex a, Vertex b, Vertex c)
        {
            double cross = (b.X - a.X) * (c.Y - b.Y) - (b.Y - a.Y) * (c.X - b.X);
            return cross < 0;
        }

        /// <summary>
        /// Determines if point p is inside triangle abc using barycentric area comparisons.
        /// </summary>
        private static bool PointInTriangle(Vertex p, Vertex a, Vertex b, Vertex c)
        {
            double area = TriangleArea(a, b, c);
            double area1 = TriangleArea(p, b, c);
            double area2 = TriangleArea(a, p, c);
            double area3 = TriangleArea(a, b, p);
            return Math.Abs(area - (area1 + area2 + area3)) < 1e-10;
        }

        private static double TriangleArea(Vertex a, Vertex b, Vertex c)
        {
            return Math.Abs((a.X * (b.Y - c.Y) +
                             b.X * (c.Y - a.Y) +
                             c.X * (a.Y - b.Y)) / 2.0);
        }

        /// <summary>
        /// Private node class for the circular doubly linked list used in ear clipping.
        /// </summary>
        private class Node
        {
            public Vertex v;
            public Node prev;
            public Node next;
            public bool isEar;
            
            public Node(Vertex v)
            {
                this.v = v;
            }
        }
    }

    /// <summary>
    /// Represents the result of triangulation – a mesh of triangles.
    /// </summary>
    public class Mesh
    {
        public List<Triangle> Triangles { get; }
        
        public Mesh(List<Triangle> triangles)
        {
            Triangles = triangles;
        }
    }

    /// <summary>
    /// Provides an interface to access triangle vertices.
    /// </summary>
    public interface ITriangle
    {
        Vertex GetVertex(int index);
    }

    /// <summary>
    /// Represents a triangle (with three vertices).
    /// </summary>
    public class Triangle : ITriangle
    {
        private readonly Vertex[] vertices;
        
        public Triangle(Vertex a, Vertex b, Vertex c)
        {
            vertices = new Vertex[3] { a, b, c };
        }
        
        public Vertex GetVertex(int index)
        {
            return vertices[index];
        }
    }
}
