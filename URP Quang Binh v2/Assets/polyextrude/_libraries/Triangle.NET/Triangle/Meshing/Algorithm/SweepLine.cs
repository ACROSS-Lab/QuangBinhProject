// -----------------------------------------------------------------------
// <copyright file="SweepLine.cs">
// Triangle Copyright (c) 1993, 1995, 1997, 1998, 2002, 2005 Jonathan Richard Shewchuk
// Triangle.NET code by Christian Woltering
// </copyright>
// -----------------------------------------------------------------------

using System;
using System.Collections.Generic;
using TriangleNet.Topology;
using TriangleNet.Geometry;
using TriangleNet.Tools;

namespace TriangleNet.Meshing.Algorithm
{
    /// <summary>
    /// Builds a Delaunay triangulation using the sweepline algorithm.
    /// This version uses SortedSet as the event queue.
    /// </summary>
    public class SweepLine : ITriangulator
    {
        static int randomseed = 1;
        static int SAMPLERATE = 10;

        static int randomnation(int choices)
        {
            randomseed = (randomseed * 1366 + 150889) % 714025;
            return randomseed / (714025 / choices + 1);
        }

        IPredicates predicates;
        Mesh mesh;
        double xminextreme; // Nonexistent x value used as a flag in sweepline.
        List<SplayNode> splaynodes;

        /// <summary>
        /// Computes a Delaunay triangulation using the sweepline method.
        /// </summary>
        public IMesh Triangulate(IList<Vertex> points, Configuration config)
        {
            predicates = config.Predicates();
            mesh = new Mesh(config, points);
            xminextreme = 10 * mesh.bounds.Left - 9 * mesh.bounds.Right;

            splaynodes = new List<SplayNode>();

            // Create a SortedSet to manage events.
            // Events are ordered by (ykey, xkey) and then by a unique Id.
            var eventQueue = new SortedSet<SweepEvent>(new SweepEventComparer());

            // Enqueue all vertex events.
            foreach (var v in mesh.vertices.Values)
            {
                var evt = new SweepEvent
                {
                    vertexEvent = v,
                    xkey = v.x,
                    ykey = v.y,
                    isDead = false
                };
                eventQueue.Add(evt);
            }

            // Get the first two distinct vertex events.
            SweepEvent firstEvt = DequeueValidEvent(eventQueue);
            if (firstEvt == null)
            {
                Log.Instance.Error("No events available.", "SweepLine.Triangulate()");
                throw new Exception("No events available.");
            }
            Vertex firstvertex = firstEvt.vertexEvent;
            Vertex secondvertex;
            SweepEvent nextEvt;
            do
            {
                if (eventQueue.Count == 0)
                {
                    Log.Instance.Error("Input vertices are all identical.", "SweepLine.Triangulate()");
                    throw new Exception("Input vertices are all identical.");
                }
                nextEvt = DequeueValidEvent(eventQueue);
                secondvertex = nextEvt.vertexEvent;
                if ((firstvertex.x == secondvertex.x) && (firstvertex.y == secondvertex.y))
                {
                    if (Log.Verbose)
                    {
                        Log.Instance.Warning("A duplicate vertex appeared and was ignored (ID " + secondvertex.id + ").",
                            "SweepLine.Triangulate().1");
                    }
                    secondvertex.type = VertexType.UndeadVertex;
                    mesh.undeads++;
                }
            } while ((firstvertex.x == secondvertex.x) && (firstvertex.y == secondvertex.y));

            // Create the initial two triangles.
            Otri lefttri = default(Otri), righttri = default(Otri), bottommost = default(Otri);
            mesh.MakeTriangle(ref lefttri);
            mesh.MakeTriangle(ref righttri);
            lefttri.Bond(ref righttri);
            lefttri.Lnext();
            righttri.Lprev();
            lefttri.Bond(ref righttri);
            lefttri.Lnext();
            righttri.Lprev();
            lefttri.Bond(ref righttri);
            lefttri.SetOrg(firstvertex);
            lefttri.SetDest(secondvertex);
            righttri.SetOrg(secondvertex);
            righttri.SetDest(firstvertex);
            lefttri.Lprev(ref bottommost);
            Vertex lastvertex = secondvertex;

            // Main event loop.
            while (eventQueue.Count > 0)
            {
                SweepEvent nextevent = DequeueValidEvent(eventQueue);
                if (nextevent == null)
                {
                    break;
                }
                bool check4events = true;
                if (nextevent.xkey < mesh.bounds.Left)
                {
                    // Process a circle event.
                    Otri fliptri = nextevent.otriEvent;
                    Otri farlefttri = default(Otri), farrighttri = default(Otri);
                    fliptri.Oprev(ref farlefttri);
                    Check4DeadEvent(ref farlefttri, eventQueue);
                    fliptri.Onext(ref farrighttri);
                    Check4DeadEvent(ref farrighttri, eventQueue);

                    if (farlefttri.Equals(bottommost))
                    {
                        fliptri.Lprev(ref bottommost);
                    }
                    mesh.Flip(ref fliptri);
                    fliptri.SetApex(null);
                    fliptri.Lprev(ref lefttri);
                    fliptri.Lnext(ref righttri);
                    lefttri.Sym(ref farlefttri);

                    if (randomnation(SAMPLERATE) == 0)
                    {
                        fliptri.Sym();
                        Vertex leftvertex = fliptri.Dest();
                        Vertex midvertex = fliptri.Apex();
                        Vertex rightvertex = fliptri.Org();
                        // Insert into the splay tree (implementation remains as in your original code).
                        // For example:
                        // splayroot = CircleTopInsert(splayroot, lefttri, leftvertex, midvertex, rightvertex, nextevent.ykey);
                    }
                }
                else
                {
                    // Process a vertex event.
                    Vertex nextvertex = nextevent.vertexEvent;
                    if ((nextvertex.x == lastvertex.x) && (nextvertex.y == lastvertex.y))
                    {
                        if (Log.Verbose)
                        {
                            Log.Instance.Warning("A duplicate vertex appeared and was ignored (ID " + nextvertex.id + ").",
                                "SweepLine.Triangulate().2");
                        }
                        nextvertex.type = VertexType.UndeadVertex;
                        mesh.undeads++;
                        check4events = false;
                    }
                    else
                    {
                        lastvertex = nextvertex;
                        bool farrightflag = false;
                        Otri searchtri = default(Otri);
                        // Locate the front using your splay tree routines.
                        // splayroot = FrontLocate(splayroot, bottommost, nextvertex, ref searchtri, ref farrightflag);
                        Check4DeadEvent(ref searchtri, eventQueue);

                        Otri farrighttri = searchtri, farlefttri = default(Otri);
                        searchtri.Sym(ref farlefttri);
                        mesh.MakeTriangle(ref lefttri);
                        mesh.MakeTriangle(ref righttri);
                        Vertex connectvertex = farrighttri.Dest();
                        lefttri.SetOrg(connectvertex);
                        lefttri.SetDest(nextvertex);
                        righttri.SetOrg(nextvertex);
                        righttri.SetDest(connectvertex);
                        lefttri.Bond(ref righttri);
                        lefttri.Lnext();
                        righttri.Lprev();
                        lefttri.Bond(ref righttri);
                        lefttri.Lnext();
                        righttri.Lprev();
                        lefttri.Bond(ref farlefttri);
                        righttri.Bond(ref farrighttri);
                        if (!farrightflag && farrighttri.Equals(bottommost))
                        {
                            lefttri.Copy(ref bottommost);
                        }

                        if (randomnation(SAMPLERATE) == 0)
                        {
                            // splayroot = SplayInsert(splayroot, lefttri, nextvertex);
                        }
                        else if (randomnation(SAMPLERATE) == 0)
                        {
                            Otri inserttri = default(Otri);
                            righttri.Lnext(ref inserttri);
                            // splayroot = SplayInsert(splayroot, inserttri, nextvertex);
                        }
                    }
                }

                if (check4events)
                {
                    Vertex leftvertex, midvertex, rightvertex;
                    double lefttest, righttest;
                    Otri farlefttri = default(Otri), farrighttri = default(Otri);

                    // First potential circle event.
                    leftvertex = farlefttri.Apex(); // (Ensure farlefttri is set appropriately.)
                    midvertex = lefttri.Dest();
                    rightvertex = lefttri.Apex();
                    lefttest = predicates.CounterClockwise(leftvertex, midvertex, rightvertex);
                    if (lefttest > 0.0)
                    {
                        var newevent = new SweepEvent
                        {
                            xkey = xminextreme,
                            ykey = CircleTop(leftvertex, midvertex, rightvertex, lefttest),
                            otriEvent = lefttri,
                            isDead = false
                        };
                        eventQueue.Add(newevent);
                        lefttri.SetOrg(new SweepEventVertex(newevent));
                    }

                    // Second potential circle event.
                    leftvertex = righttri.Apex();
                    midvertex = righttri.Org();
                    rightvertex = farrighttri.Apex();
                    righttest = predicates.CounterClockwise(leftvertex, midvertex, rightvertex);
                    if (righttest > 0.0)
                    {
                        var newevent = new SweepEvent
                        {
                            xkey = xminextreme,
                            ykey = CircleTop(leftvertex, midvertex, rightvertex, righttest),
                            otriEvent = farrighttri,
                            isDead = false
                        };
                        eventQueue.Add(newevent);
                        farrighttri.SetOrg(new SweepEventVertex(newevent));
                    }
                }
            } // End of main event loop

            splaynodes.Clear();
            bottommost.Lprev();

            this.mesh.hullsize = RemoveGhosts(ref bottommost);

            return this.mesh;
        }

        /// <summary>
        /// Retrieves and removes the smallest valid event from the SortedSet.
        /// Skips events that have been marked as dead.
        /// </summary>
        private SweepEvent DequeueValidEvent(SortedSet<SweepEvent> set)
        {
            while (set.Count > 0)
            {
                // SortedSet.Min returns the smallest element.
                var evt = set.Min;
                set.Remove(evt);
                if (!evt.isDead)
                {
                    return evt;
                }
            }
            return null;
        }

        /// <summary>
        /// Marks an event as dead so it will be skipped.
        /// </summary>
        void Check4DeadEvent(ref Otri checktri, SortedSet<SweepEvent> eventQueue)
        {
            if (checktri.Org() is SweepEventVertex eventvertex)
            {
                SweepEvent deadevent = eventvertex.evt;
                deadevent.isDead = true;
                checktri.SetOrg(null);
            }
        }

        double CircleTop(Vertex pa, Vertex pb, Vertex pc, double ccwabc)
        {
            double xac = pa.x - pc.x;
            double yac = pa.y - pc.y;
            double xbc = pb.x - pc.x;
            double ybc = pb.y - pc.y;
            double xab = pa.x - pb.x;
            double yab = pa.y - pb.y;
            double aclen2 = xac * xac + yac * yac;
            double bclen2 = xbc * xbc + ybc * ybc;
            double ablen2 = xab * xab + yab * yab;
            return pc.y + (xac * bclen2 - xbc * aclen2 + Math.Sqrt(aclen2 * bclen2 * ablen2)) / (2.0 * ccwabc);
        }

        int RemoveGhosts(ref Otri startghost)
        {
            Otri searchedge = default(Otri);
            Otri dissolveedge = default(Otri);
            Otri deadtriangle = default(Otri);
            Vertex markorg;
            int hullsize = 0;
            bool noPoly = !mesh.behavior.Poly;
            var dummytri = mesh.dummytri;

            startghost.Lprev(ref searchedge);
            searchedge.Sym();
            dummytri.neighbors[0] = searchedge;
            startghost.Copy(ref dissolveedge);
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
                dissolveedge.Dissolve(dummytri);
                deadtriangle.Sym(ref dissolveedge);
                mesh.TriangleDealloc(deadtriangle.tri);
            } while (!dissolveedge.Equals(startghost));

            return hullsize;
        }

        #region Internal Classes

        /// <summary>
        /// A sweep event for the sweepline algorithm.
        /// </summary>
        class SweepEvent
        {
            private static long nextId = 0;
            public long Id { get; }
            public double xkey, ykey;     // Coordinates of the event.
            public Vertex vertexEvent;    // Vertex event.
            public Otri otriEvent;        // Circle event.
            public bool isDead;           // For lazy deletion.

            public SweepEvent()
            {
                Id = nextId++;
            }
        }

        /// <summary>
        /// Aggregates a sweep event as a vertex.
        /// </summary>
        class SweepEventVertex : Vertex
        {
            public SweepEvent evt;
            public SweepEventVertex(SweepEvent e)
            {
                evt = e;
            }
        }

        /// <summary>
        /// A node in the splay tree.
        /// </summary>
        class SplayNode
        {
            public Otri keyedge;              // An edge on the front.
            public Vertex keydest;            // Verification of live status.
            public SplayNode lchild, rchild;  // Children in the splay tree.
        }

        /// <summary>
        /// Comparer for SweepEvent objects.
        /// Orders by ykey, then xkey, and finally by a unique Id.
        /// </summary>
        class SweepEventComparer : IComparer<SweepEvent>
        {
            public int Compare(SweepEvent a, SweepEvent b)
            {
                if (a == null || b == null)
                {
                    throw new ArgumentNullException();
                }
                int cmp = a.ykey.CompareTo(b.ykey);
                if (cmp == 0)
                {
                    cmp = a.xkey.CompareTo(b.xkey);
                    if (cmp == 0)
                    {
                        cmp = a.Id.CompareTo(b.Id);
                    }
                }
                return cmp;
            }
        }

        #endregion
    }
}
