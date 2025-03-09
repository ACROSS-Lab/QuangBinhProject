// -----------------------------------------------------------------------
// <copyright file="Dwyer.cs">
// Triangle Copyright (c) 1993, 1995, 1997, 1998, 2002, 2005 Jonathan Richard Shewchuk
// Triangle.NET code by Christian Woltering
// </copyright>
// -----------------------------------------------------------------------

namespace TriangleNet.Meshing.Algorithm
{
    using System;
    using System.Collections.Generic;
    using TriangleNet.Geometry;
    using TriangleNet.Tools;
    using TriangleNet.Topology;

    /// <summary>
    /// Builds a Delaunay triangulation using the divide-and-conquer algorithm.
    /// </summary>
    /// <remarks>
    /// (Comments omitted for brevity)
    /// </remarks>
    public class Dwyer : ITriangulator
    {
        IPredicates predicates;

        /// <summary>
        /// Gets or sets a value indicating whether to use alternating cuts (default = true).
        /// </summary>
        public bool UseDwyer = true;

        Vertex[] sortarray;
        Mesh mesh;

        // --------------------------------------------------------------------
        // A private nested class to simulate recursion using an explicit stack.
        // --------------------------------------------------------------------
        private class Frame
        {
            public int left, right, axis;
            public int divider; // Computed for non-base cases.
            // state: 0 = waiting for left child; 1 = left child done; 2 = right child done.
            public int state;
            // Results for this frame:
            public Otri farleft, farright;
            // Temporarily store left child's results:
            public Otri leftFarleft, leftInner;
            // Temporarily store right child's results:
            public Otri rightInner, rightFarright;
        }

        /// <summary>
        /// Compute a Delaunay triangulation by the divide-and-conquer method.
        /// </summary>
        public IMesh Triangulate(IList<Vertex> points, Configuration config)
        {
            predicates = config.Predicates();
            mesh = new Mesh(config, points);

            Otri hullleft = default(Otri), hullright = default(Otri);
            int i, j, n = points.Count;

            // Allocate an array of pointers to vertices for sorting.
            sortarray = new Vertex[n];
            i = 0;
            foreach (var v in points)
            {
                sortarray[i++] = v;
            }

            // Sort the vertices.
            VertexSorter.Sort(sortarray);

            // Discard duplicate vertices.
            i = 0;
            for (j = 1; j < n; j++)
            {
                if ((sortarray[i].x == sortarray[j].x) && (sortarray[i].y == sortarray[j].y))
                {
                    if (Log.Verbose)
                    {
                        Log.Instance.Warning(
                            string.Format("A duplicate vertex appeared and was ignored (ID {0}).", sortarray[j].id),
                            "Dwyer.Triangulate()");
                    }
                    sortarray[j].type = VertexType.UndeadVertex;
                    mesh.undeads++;
                }
                else
                {
                    i++;
                    sortarray[i] = sortarray[j];
                }
            }
            i++;
            if (UseDwyer)
            {
                // Re-sort the array of vertices to accommodate alternating cuts.
                VertexSorter.Alternate(sortarray, i);
            }

            // Form the Delaunay triangulation using the iterative (stack-based) method.
            DivconqIterative(0, i - 1, 0, out hullleft, out hullright);
            mesh.hullsize = RemoveGhosts(ref hullleft);

            return mesh;
        }

        /// <summary>
        /// Iteratively forms a Delaunay triangulation using a stack-based divide-and-conquer approach.
        /// </summary>
        void DivconqIterative(int left, int right, int axis, out Otri farleft, out Otri farright)
        {
            Stack<Frame> stack = new Stack<Frame>();
            Frame root = new Frame { left = left, right = right, axis = axis, state = 0 };
            stack.Push(root);
            Frame completed = null;

            while (stack.Count > 0)
            {
                Frame current = stack.Peek();
                int nVertices = current.right - current.left + 1;

                // Base case: 2 vertices.
                if (nVertices == 2)
                {
                    Otri t0 = default(Otri);
                    mesh.MakeTriangle(ref t0);
                    t0.SetOrg(sortarray[current.left]);
                    t0.SetDest(sortarray[current.left + 1]);

                    Otri t1 = default(Otri);
                    mesh.MakeTriangle(ref t1);
                    t1.SetOrg(sortarray[current.left + 1]);
                    t1.SetDest(sortarray[current.left]);

                    t0.Bond(ref t1);
                    t0.Lprev();
                    t1.Lnext();
                    t0.Bond(ref t1);
                    t0.Lprev();
                    t1.Lnext();
                    t0.Bond(ref t1);
                    t1.Lprev(ref t0);

                    current.farleft = t0;
                    current.farright = t1;

                    stack.Pop();
                    if (stack.Count > 0)
                    {
                        Frame parent = stack.Peek();
                        if (parent.state == 0)
                        {
                            parent.leftFarleft = current.farleft;
                            parent.leftInner = current.farright;
                            parent.state = 1;
                        }
                        else if (parent.state == 1)
                        {
                            parent.rightInner = current.farleft;
                            parent.rightFarright = current.farright;
                            parent.state = 2;
                        }
                    }
                    else
                    {
                        completed = current;
                    }
                    continue;
                }
                // Base case: 3 vertices.
                else if (nVertices == 3)
                {
                    Otri midtri = default(Otri);
                    mesh.MakeTriangle(ref midtri);
                    Otri tri1 = default(Otri);
                    mesh.MakeTriangle(ref tri1);
                    Otri tri2 = default(Otri);
                    mesh.MakeTriangle(ref tri2);
                    Otri tri3 = default(Otri);
                    mesh.MakeTriangle(ref tri3);

                    double area = predicates.CounterClockwise(
                        sortarray[current.left],
                        sortarray[current.left + 1],
                        sortarray[current.left + 2]);

                    if (area == 0.0)
                    {
                        // Three collinear vertices; the triangulation is two edges.
                        midtri.SetOrg(sortarray[current.left]);
                        midtri.SetDest(sortarray[current.left + 1]);
                        tri1.SetOrg(sortarray[current.left + 1]);
                        tri1.SetDest(sortarray[current.left]);
                        tri2.SetOrg(sortarray[current.left + 2]);
                        tri2.SetDest(sortarray[current.left + 1]);
                        tri3.SetOrg(sortarray[current.left + 1]);
                        tri3.SetDest(sortarray[current.left + 2]);

                        midtri.Bond(ref tri1);
                        tri2.Bond(ref tri3);
                        midtri.Lnext();
                        tri1.Lprev();
                        tri2.Lnext();
                        tri3.Lprev();
                        midtri.Bond(ref tri3);
                        tri1.Bond(ref tri2);
                        midtri.Lnext();
                        tri1.Lprev();
                        tri2.Lnext();
                        tri3.Lprev();
                        midtri.Bond(ref tri1);
                        tri2.Bond(ref tri3);

                        // Set the frame results.
                        tri1.Copy(ref current.farleft);
                        tri2.Copy(ref current.farright);
                    }
                    else
                    {
                        // Noncollinear vertices; the triangulation is one triangle.
                        midtri.SetOrg(sortarray[current.left]);
                        tri1.SetDest(sortarray[current.left]);
                        tri3.SetOrg(sortarray[current.left]);
                        if (area > 0.0)
                        {
                            midtri.SetDest(sortarray[current.left + 1]);
                            tri1.SetOrg(sortarray[current.left + 1]);
                            tri2.SetDest(sortarray[current.left + 1]);
                            midtri.SetApex(sortarray[current.left + 2]);
                            tri2.SetOrg(sortarray[current.left + 2]);
                            tri3.SetDest(sortarray[current.left + 2]);
                        }
                        else
                        {
                            midtri.SetDest(sortarray[current.left + 2]);
                            tri1.SetOrg(sortarray[current.left + 2]);
                            tri2.SetDest(sortarray[current.left + 2]);
                            midtri.SetApex(sortarray[current.left + 1]);
                            tri2.SetOrg(sortarray[current.left + 1]);
                            tri3.SetDest(sortarray[current.left + 1]);
                        }
                        midtri.Bond(ref tri1);
                        midtri.Lnext();
                        midtri.Bond(ref tri2);
                        midtri.Lnext();
                        midtri.Bond(ref tri3);
                        tri1.Lprev();
                        tri2.Lnext();
                        tri1.Bond(ref tri2);
                        tri1.Lprev();
                        tri3.Lprev();
                        tri1.Bond(ref tri3);
                        tri2.Lnext();
                        tri3.Lprev();
                        tri2.Bond(ref tri3);

                        tri1.Copy(ref current.farleft);
                        if (area > 0.0)
                        {
                            tri2.Copy(ref current.farright);
                        }
                        else
                        {
                            Otri tmp = default(Otri);
                            current.farleft.Lnext(ref tmp);
                            tmp.Copy(ref current.farright);
                        }
                    }

                    stack.Pop();
                    if (stack.Count > 0)
                    {
                        Frame parent = stack.Peek();
                        if (parent.state == 0)
                        {
                            parent.leftFarleft = current.farleft;
                            parent.leftInner = current.farright;
                            parent.state = 1;
                        }
                        else if (parent.state == 1)
                        {
                            parent.rightInner = current.farleft;
                            parent.rightFarright = current.farright;
                            parent.state = 2;
                        }
                    }
                    else
                    {
                        completed = current;
                    }
                    continue;
                }
                else
                {
                    // Non-base case: nVertices >= 4.
                    if (current.state == 0)
                    {
                        current.divider = nVertices >> 1;
                        // Process left subproblem.
                        Frame child = new Frame
                        {
                            left = current.left,
                            right = current.left + current.divider - 1,
                            axis = 1 - current.axis,
                            state = 0
                        };
                        stack.Push(child);
                        continue;
                    }
                    else if (current.state == 1)
                    {
                        // Process right subproblem.
                        Frame child = new Frame
                        {
                            left = current.left + current.divider,
                            right = current.right,
                            axis = 1 - current.axis,
                            state = 0
                        };
                        stack.Push(child);
                        continue;
                    }
                    else if (current.state == 2)
                    {
                        // Merge the two halves.
                        MergeHulls(ref current.leftFarleft, ref current.leftInner,
                                   ref current.rightInner, ref current.rightFarright,
                                   current.axis);
                        current.farleft = current.leftFarleft;
                        current.farright = current.rightFarright;

                        stack.Pop();
                        if (stack.Count > 0)
                        {
                            Frame parent = stack.Peek();
                            if (parent.state == 0)
                            {
                                parent.leftFarleft = current.farleft;
                                parent.leftInner = current.farright;
                                parent.state = 1;
                            }
                            else if (parent.state == 1)
                            {
                                parent.rightInner = current.farleft;
                                parent.rightFarright = current.farright;
                                parent.state = 2;
                            }
                        }
                        else
                        {
                            completed = current;
                        }
                        continue;
                    }
                }
            }
            farleft = completed.farleft;
            farright = completed.farright;
        }

        /// <summary>
        /// Merges two adjacent Delaunay triangulations into a single triangulation.
        /// </summary>
        void MergeHulls(ref Otri farleft, ref Otri innerleft, ref Otri innerright,
                        ref Otri farright, int axis)
        {
            Otri leftcand = default(Otri), rightcand = default(Otri);
            Otri nextedge = default(Otri);
            Otri sidecasing = default(Otri), topcasing = default(Otri), outercasing = default(Otri);
            Otri checkedge = default(Otri);
            Otri baseedge = default(Otri);
            Vertex innerleftdest;
            Vertex innerrightorg;
            Vertex innerleftapex, innerrightapex;
            Vertex farleftpt, farrightpt;
            Vertex farleftapex, farrightapex;
            Vertex lowerleft, lowerright;
            Vertex upperleft, upperright;
            Vertex nextapex;
            Vertex checkvertex;
            bool changemade;
            bool badedge;
            bool leftfinished, rightfinished;

            innerleftdest = innerleft.Dest();
            innerleftapex = innerleft.Apex();
            innerrightorg = innerright.Org();
            innerrightapex = innerright.Apex();

            if (UseDwyer && (axis == 1))
            {
                farleftpt = farleft.Org();
                farleftapex = farleft.Apex();
                farrightpt = farright.Dest();
                farrightapex = farright.Apex();
                while (farleftapex.y < farleftpt.y)
                {
                    farleft.Lnext();
                    farleft.Sym();
                    farleftpt = farleftapex;
                    farleftapex = farleft.Apex();
                }
                innerleft.Sym(ref checkedge);
                checkvertex = checkedge.Apex();
                while (checkvertex.y > innerleftdest.y)
                {
                    checkedge.Lnext(ref innerleft);
                    innerleftapex = innerleftdest;
                    innerleftdest = checkvertex;
                    innerleft.Sym(ref checkedge);
                    checkvertex = checkedge.Apex();
                }
                while (innerrightapex.y < innerrightorg.y)
                {
                    innerright.Lnext();
                    innerright.Sym();
                    innerrightorg = innerrightapex;
                    innerrightapex = innerright.Apex();
                }
                farright.Sym(ref checkedge);
                checkvertex = checkedge.Apex();
                while (checkvertex.y > farrightpt.y)
                {
                    checkedge.Lnext(ref farright);
                    farrightapex = farrightpt;
                    farrightpt = checkvertex;
                    farright.Sym(ref checkedge);
                    checkvertex = checkedge.Apex();
                }
            }
            do
            {
                changemade = false;
                if (predicates.CounterClockwise(innerleftdest, innerleftapex, innerrightorg) > 0.0)
                {
                    innerleft.Lprev();
                    innerleft.Sym();
                    innerleftdest = innerleftapex;
                    innerleftapex = innerleft.Apex();
                    changemade = true;
                }
                if (predicates.CounterClockwise(innerrightapex, innerrightorg, innerleftdest) > 0.0)
                {
                    innerright.Lnext();
                    innerright.Sym();
                    innerrightorg = innerrightapex;
                    innerrightapex = innerright.Apex();
                    changemade = true;
                }
            } while (changemade);

            innerleft.Sym(ref leftcand);
            innerright.Sym(ref rightcand);
            mesh.MakeTriangle(ref baseedge);
            baseedge.Bond(ref innerleft);
            baseedge.Lnext();
            baseedge.Bond(ref innerright);
            baseedge.Lnext();
            baseedge.SetOrg(innerrightorg);
            baseedge.SetDest(innerleftdest);

            farleftpt = farleft.Org();
            if (innerleftdest == farleftpt)
            {
                baseedge.Lnext(ref farleft);
            }
            farrightpt = farright.Dest();
            if (innerrightorg == farrightpt)
            {
                baseedge.Lprev(ref farright);
            }
            lowerleft = innerleftdest;
            lowerright = innerrightorg;
            upperleft = leftcand.Apex();
            upperright = rightcand.Apex();

            while (true)
            {
                leftfinished = predicates.CounterClockwise(upperleft, lowerleft, lowerright) <= 0.0;
                rightfinished = predicates.CounterClockwise(upperright, lowerleft, lowerright) <= 0.0;
                if (leftfinished && rightfinished)
                {
                    mesh.MakeTriangle(ref nextedge);
                    nextedge.SetOrg(lowerleft);
                    nextedge.SetDest(lowerright);
                    nextedge.Bond(ref baseedge);
                    nextedge.Lnext();
                    nextedge.Bond(ref rightcand);
                    nextedge.Lnext();
                    nextedge.Bond(ref leftcand);
                    if (UseDwyer && (axis == 1))
                    {
                        farleftpt = farleft.Org();
                        farleftapex = farleft.Apex();
                        farrightpt = farright.Dest();
                        farrightapex = farright.Apex();
                        farleft.Sym(ref checkedge);
                        checkvertex = checkedge.Apex();
                        while (checkvertex.x < farleftpt.x)
                        {
                            checkedge.Lprev(ref farleft);
                            farleftapex = farleftpt;
                            farleftpt = checkvertex;
                            farleft.Sym(ref checkedge);
                            checkvertex = checkedge.Apex();
                        }
                        while (farrightapex.x > farrightpt.x)
                        {
                            farright.Lprev();
                            farright.Sym();
                            farrightpt = farrightapex;
                            farrightapex = farright.Apex();
                        }
                    }
                    return;
                }
                if (!leftfinished)
                {
                    leftcand.Lprev(ref nextedge);
                    nextedge.Sym();
                    nextapex = nextedge.Apex();
                    if (nextapex != null)
                    {
                        badedge = predicates.InCircle(lowerleft, lowerright, upperleft, nextapex) > 0.0;
                        while (badedge)
                        {
                            nextedge.Lnext();
                            nextedge.Sym(ref topcasing);
                            nextedge.Lnext();
                            nextedge.Sym(ref sidecasing);
                            nextedge.Bond(ref topcasing);
                            leftcand.Bond(ref sidecasing);
                            leftcand.Lnext();
                            leftcand.Sym(ref outercasing);
                            nextedge.Lprev();
                            nextedge.Bond(ref outercasing);
                            leftcand.SetOrg(lowerleft);
                            leftcand.SetDest(null);
                            leftcand.SetApex(nextapex);
                            nextedge.SetOrg(null);
                            nextedge.SetDest(upperleft);
                            nextedge.SetApex(nextapex);
                            upperleft = nextapex;
                            sidecasing.Copy(ref nextedge);
                            nextapex = nextedge.Apex();
                            if (nextapex != null)
                            {
                                badedge = predicates.InCircle(lowerleft, lowerright, upperleft, nextapex) > 0.0;
                            }
                            else
                            {
                                badedge = false;
                            }
                        }
                    }
                }
                if (!rightfinished)
                {
                    rightcand.Lnext(ref nextedge);
                    nextedge.Sym();
                    nextapex = nextedge.Apex();
                    if (nextapex != null)
                    {
                        badedge = predicates.InCircle(lowerleft, lowerright, upperright, nextapex) > 0.0;
                        while (badedge)
                        {
                            nextedge.Lprev();
                            nextedge.Sym(ref topcasing);
                            nextedge.Lprev();
                            nextedge.Sym(ref sidecasing);
                            nextedge.Bond(ref topcasing);
                            rightcand.Bond(ref sidecasing);
                            rightcand.Lprev();
                            rightcand.Sym(ref outercasing);
                            nextedge.Lnext();
                            nextedge.Bond(ref outercasing);
                            rightcand.SetOrg(null);
                            rightcand.SetDest(lowerright);
                            rightcand.SetApex(nextapex);
                            nextedge.SetOrg(upperright);
                            nextedge.SetDest(null);
                            nextedge.SetApex(nextapex);
                            upperright = nextapex;
                            sidecasing.Copy(ref nextedge);
                            nextapex = nextedge.Apex();
                            if (nextapex != null)
                            {
                                badedge = predicates.InCircle(lowerleft, lowerright, upperright, nextapex) > 0.0;
                            }
                            else
                            {
                                badedge = false;
                            }
                        }
                    }
                }
                if (leftfinished || (!rightfinished &&
                       (predicates.InCircle(upperleft, lowerleft, lowerright, upperright) > 0.0)))
                {
                    baseedge.Bond(ref rightcand);
                    rightcand.Lprev(ref baseedge);
                    baseedge.SetDest(lowerleft);
                    lowerright = upperright;
                    baseedge.Sym(ref rightcand);
                    upperright = rightcand.Apex();
                }
                else
                {
                    baseedge.Bond(ref leftcand);
                    leftcand.Lnext(ref baseedge);
                    baseedge.SetOrg(lowerright);
                    lowerleft = upperleft;
                    baseedge.Sym(ref leftcand);
                    upperleft = leftcand.Apex();
                }
            }
        }

        /// <summary>
        /// Removes ghost triangles.
        /// </summary>
        int RemoveGhosts(ref Otri startghost)
        {
            Otri searchedge = default(Otri);
            Otri dissolveedge = default(Otri);
            Otri deadtriangle = default(Otri);
            Vertex markorg;

            int hullsize;
            bool noPoly = !mesh.behavior.Poly;

            startghost.Lprev(ref searchedge);
            searchedge.Sym();
            mesh.dummytri.neighbors[0] = searchedge;

            startghost.Copy(ref dissolveedge);
            hullsize = 0;
            do
            {
                hullsize++;
                dissolveedge.Lnext(ref deadtriangle);
                dissolveedge.Lprev();
                dissolveedge.Sym();
                if (noPoly)
                {
                    if (dissolveedge.tri.id != Mesh.DUMMY)
                    {
                        markorg = dissolveedge.Org();
                        if (markorg.label == 0)
                        {
                            markorg.label = 1;
                        }
                    }
                }
                dissolveedge.Dissolve(mesh.dummytri);
                deadtriangle.Sym(ref dissolveedge);
                mesh.TriangleDealloc(deadtriangle.tri);
            } while (!dissolveedge.Equals(startghost));

            return hullsize;
        }
    }
}
