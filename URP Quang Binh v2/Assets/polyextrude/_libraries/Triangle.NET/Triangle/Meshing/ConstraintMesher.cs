// -----------------------------------------------------------------------
// <copyright file="ConstraintMesher.cs">
// Triangle Copyright (c) 1993, 1995, 1997, 1998, 2002, 2005 Jonathan Richard Shewchuk
// Triangle.NET code by Christian Woltering
// </copyright>
// -----------------------------------------------------------------------

namespace TriangleNet.Meshing
{
    using System;
    using System.Collections.Generic;
    using TriangleNet.Geometry;
    using TriangleNet.Meshing.Iterators;
    using TriangleNet.Topology;

    internal class ConstraintMesher
    {
        IPredicates predicates;

        Mesh mesh;
        Behavior behavior;
        TriangleLocator locator;

        List<Triangle> viri;

        Log logger = Log.Instance;

        public ConstraintMesher(Mesh mesh, Configuration config)
        {
            this.mesh = mesh;
            this.predicates = config.Predicates();

            this.behavior = mesh.behavior;
            this.locator = mesh.locator;

            this.viri = new List<Triangle>();
        }

        /// <summary>
        /// Insert segments into the mesh.
        /// </summary>
        /// <param name="input">The polygon.</param>
        /// <param name="options">Constraint options.</param>
        public void Apply(IPolygon input, ConstraintOptions options)
        {
            behavior.Poly = input.Segments.Count > 0;

            // Copy constraint options
            if (options != null)
            {
                behavior.ConformingDelaunay = options.ConformingDelaunay;
                behavior.Convex = options.Convex;
                behavior.NoBisect = options.SegmentSplitting;

                if (behavior.ConformingDelaunay)
                {
                    behavior.Quality = true;
                }
            }

            behavior.useRegions = input.Regions.Count > 0;

            // Ensure that no vertex can be mistaken for a triangular bounding
            // box vertex in insertvertex().
            mesh.infvertex1 = null;
            mesh.infvertex2 = null;
            mesh.infvertex3 = null;

            if (behavior.useSegments)
            {
                // Segments will be introduced next.
                mesh.checksegments = true;

                // Insert PSLG segments and/or convex hull segments.
                FormSkeleton(input);
            }

            if (behavior.Poly && (mesh.triangles.Count > 0))
            {
                // Copy holes and regions
                mesh.holes.AddRange(input.Holes);
                mesh.regions.AddRange(input.Regions);

                // Carve out holes and concavities.
                CarveHoles();
            }
        }

        /// <summary>
        /// Find the holes and infect them. Find the area constraints and infect 
        /// them. Infect the convex hull. Spread the infection and kill triangles. 
        /// Spread the area constraints.
        /// </summary>
        private void CarveHoles()
        {
            Otri searchtri = default(Otri);
            Vertex searchorg, searchdest;
            LocateResult intersect;

            Triangle[] regionTris = null;

            var dummytri = mesh.dummytri;

            if (!mesh.behavior.Convex)
            {
                // Mark as infected any unprotected triangles on the boundary.
                // This is one way by which concavities are created.
                InfectHull();
            }

            if (!mesh.behavior.NoHoles)
            {
                // Infect each triangle in which a hole lies.
                foreach (var hole in mesh.holes)
                {
                    // Ignore holes that aren't within the bounds of the mesh.
                    if (mesh.bounds.Contains(hole))
                    {
                        // Start searching from some triangle on the outer boundary.
                        searchtri.tri = dummytri;
                        searchtri.orient = 0;
                        searchtri.Sym();
                        // Ensure that the hole is to the left of this boundary edge;
                        // otherwise, locate() will falsely report that the hole
                        // falls within the starting triangle.
                        searchorg = searchtri.Org();
                        searchdest = searchtri.Dest();
                        if (predicates.CounterClockwise(searchorg, searchdest, hole) > 0.0)
                        {
                            // Find a triangle that contains the hole.
                            intersect = mesh.locator.Locate(hole, ref searchtri);
                            if ((intersect != LocateResult.Outside) && (!searchtri.IsInfected()))
                            {
                                // Infect the triangle. This is done by marking the triangle
                                // as infected and including the triangle in the virus pool.
                                searchtri.Infect();
                                viri.Add(searchtri.tri);
                            }
                        }
                    }
                }
            }

            // Now, we have to find all the regions BEFORE we carve the holes, because locate() won't
            // work when the triangulation is no longer convex.
            if (mesh.regions.Count > 0)
            {
                int i = 0;

                regionTris = new Triangle[mesh.regions.Count];

                // Find the starting triangle for each region.
                foreach (var region in mesh.regions)
                {
                    regionTris[i] = dummytri;
                    // Ignore region points that aren't within the bounds of the mesh.
                    if (mesh.bounds.Contains(region.Point))
                    {
                        // Start searching from some triangle on the outer boundary.
                        searchtri.tri = dummytri;
                        searchtri.orient = 0;
                        searchtri.Sym();
                        // Ensure that the region point is to the left of this boundary
                        // edge; otherwise, locate() will falsely report that the
                        // region point falls within the starting triangle.
                        searchorg = searchtri.Org();
                        searchdest = searchtri.Dest();
                        if (predicates.CounterClockwise(searchorg, searchdest, region.Point) > 0.0)
                        {
                            // Find a triangle that contains the region point.
                            intersect = mesh.locator.Locate(region.Point, ref searchtri);
                            if ((intersect != LocateResult.Outside) && (!searchtri.IsInfected()))
                            {
                                // Record the triangle for processing after the
                                // holes have been carved.
                                regionTris[i] = searchtri.tri;
                                regionTris[i].label = region.Label;
                                regionTris[i].area = region.Area;
                            }
                        }
                    }

                    i++;
                }
            }

            if (viri.Count > 0)
            {
                // Carve the holes and concavities.
                Plague();
            }

            if (regionTris != null)
            {
                var iterator = new RegionIterator();

                for (int i = 0; i < regionTris.Length; i++)
                {
                    if (regionTris[i].id != Mesh.DUMMY)
                    {
                        // Make sure the triangle under consideration still exists.
                        if (!Otri.IsDead(regionTris[i]))
                        {
                            // Apply one region's attribute and/or area constraint.
                            iterator.Process(regionTris[i]);
                        }
                    }
                }
            }

            // Free up memory (virus pool should be empty anyway).
            viri.Clear();
        }

        /// <summary>
        /// Create the segments of a triangulation, including PSLG segments and edges 
        /// on the convex hull.
        /// </summary>
        private void FormSkeleton(IPolygon input)
        {
            // The segment endpoints.
            Vertex p, q;

            mesh.insegments = 0;

            if (behavior.Poly)
            {
                // If the input vertices are collinear, there is no triangulation,
                // so don't try to insert segments.
                if (mesh.triangles.Count == 0)
                {
                    return;
                }

                // If segments are to be inserted, compute a mapping
                // from vertices to triangles.
                if (input.Segments.Count > 0)
                {
                    mesh.MakeVertexMap();
                }

                // Read and insert the segments.
                foreach (var seg in input.Segments)
                {
                    mesh.insegments++;

                    p = seg.GetVertex(0);
                    q = seg.GetVertex(1);

                    if ((p.x == q.x) && (p.y == q.y))
                    {
                        if (Log.Verbose)
                        {
                            logger.Warning("Endpoints of segment (IDs " + p.id + "/" + q.id + ") are coincident.",
                                "Mesh.FormSkeleton()");
                        }
                    }
                    else
                    {
                        InsertSegment(p, q, seg.Label);
                    }
                }
            }

            if (behavior.Convex || !behavior.Poly)
            {
                // Enclose the convex hull with subsegments.
                MarkHull();
            }
        }

        #region Carving holes

        /// <summary>
        /// Virally infect all of the triangles of the convex hull that are not 
        /// protected by subsegments. Where there are subsegments, set boundary 
        /// markers as appropriate.
        /// </summary>
        private void InfectHull()
        {
            Otri hulltri = default(Otri);
            Otri nexttri = default(Otri);
            Otri starttri = default(Otri);
            Osub hullsubseg = default(Osub);
            Vertex horg, hdest;

            var dummytri = mesh.dummytri;

            // Find a triangle handle on the hull.
            hulltri.tri = dummytri;
            hulltri.orient = 0;
            hulltri.Sym();

            // Remember where we started so we know when to stop.
            hulltri.Copy(ref starttri);
            // Go once counterclockwise around the convex hull.
            do
            {
                if (!hulltri.IsInfected())
                {
                    hulltri.Pivot(ref hullsubseg);
                    if (hullsubseg.seg.hash == Mesh.DUMMY)
                    {
                        if (!hulltri.IsInfected())
                        {
                            hulltri.Infect();
                            viri.Add(hulltri.tri);
                        }
                    }
                    else
                    {
                        if (hullsubseg.seg.boundary == 0)
                        {
                            hullsubseg.seg.boundary = 1;
                            horg = hulltri.Org();
                            hdest = hulltri.Dest();
                            if (horg.label == 0)
                            {
                                horg.label = 1;
                            }
                            if (hdest.label == 0)
                            {
                                hdest.label = 1;
                            }
                        }
                    }
                }
                hulltri.Lnext();
                hulltri.Oprev(ref nexttri);
                while (nexttri.tri.id != Mesh.DUMMY)
                {
                    nexttri.Copy(ref hulltri);
                    hulltri.Oprev(ref nexttri);
                }
            } while (!hulltri.Equals(starttri));
        }

        /// <summary>
        /// Spread the virus from all infected triangles to any neighbors not 
        /// protected by subsegments. Delete all infected triangles.
        /// </summary>
        void Plague()
        {
            Otri testtri = default(Otri);
            Otri neighbor = default(Otri);
            Osub neighborsubseg = default(Osub);
            Vertex testvertex;
            Vertex norg, ndest;

            var dummysub = mesh.dummysub;
            var dummytri = mesh.dummytri;

            bool killorg;

            for (int i = 0; i < viri.Count; i++)
            {
                testtri.tri = viri[i];
                testtri.Uninfect();

                for (testtri.orient = 0; testtri.orient < 3; testtri.orient++)
                {
                    testtri.Sym(ref neighbor);
                    testtri.Pivot(ref neighborsubseg);
                    if ((neighbor.tri.id == Mesh.DUMMY) || neighbor.IsInfected())
                    {
                        if (neighborsubseg.seg.hash != Mesh.DUMMY)
                        {
                            mesh.SubsegDealloc(neighborsubseg.seg);
                            if (neighbor.tri.id != Mesh.DUMMY)
                            {
                                neighbor.Uninfect();
                                neighbor.SegDissolve(dummysub);
                                neighbor.Infect();
                            }
                        }
                    }
                    else
                    {
                        if (neighborsubseg.seg.hash == Mesh.DUMMY)
                        {
                            neighbor.Infect();
                            viri.Add(neighbor.tri);
                        }
                        else
                        {
                            neighborsubseg.TriDissolve(dummytri);
                            if (neighborsubseg.seg.boundary == 0)
                            {
                                neighborsubseg.seg.boundary = 1;
                            }
                            norg = neighbor.Org();
                            ndest = neighbor.Dest();
                            if (norg.label == 0)
                            {
                                norg.label = 1;
                            }
                            if (ndest.label == 0)
                            {
                                ndest.label = 1;
                            }
                        }
                    }
                }
                testtri.Infect();

                for (testtri.orient = 0; testtri.orient < 3; testtri.orient++)
                {
                    testtri.Sym(ref neighbor);
                    if (neighbor.tri.id == Mesh.DUMMY)
                    {
                        mesh.hullsize--;
                    }
                    else
                    {
                        neighbor.Dissolve(dummytri);
                        mesh.hullsize++;
                    }
                }
                mesh.TriangleDealloc(testtri.tri);
            }
            viri.Clear();
        }

        #endregion

        #region Segment insertion

        /// <summary>
        /// Find the first triangle on the path from one point to another.
        /// </summary>
        private FindDirectionResult FindDirection(ref Otri searchtri, Vertex searchpoint)
        {
            Otri checktri = default(Otri);
            Vertex startvertex;
            Vertex leftvertex, rightvertex;
            double leftccw, rightccw;
            bool leftflag, rightflag;

            startvertex = searchtri.Org();
            rightvertex = searchtri.Dest();
            leftvertex = searchtri.Apex();
            leftccw = predicates.CounterClockwise(searchpoint, startvertex, leftvertex);
            leftflag = leftccw > 0.0;
            rightccw = predicates.CounterClockwise(startvertex, searchpoint, rightvertex);
            rightflag = rightccw > 0.0;
            if (leftflag && rightflag)
            {
                searchtri.Onext(ref checktri);
                if (checktri.tri.id == Mesh.DUMMY)
                {
                    leftflag = false;
                }
                else
                {
                    rightflag = false;
                }
            }
            while (leftflag)
            {
                searchtri.Onext();
                if (searchtri.tri.id == Mesh.DUMMY)
                {
                    logger.Error("Unable to find a triangle on path.", "Mesh.FindDirection().1");
                    throw new Exception("Unable to find a triangle on path.");
                }
                leftvertex = searchtri.Apex();
                rightccw = leftccw;
                leftccw = predicates.CounterClockwise(searchpoint, startvertex, leftvertex);
                leftflag = leftccw > 0.0;
            }
            while (rightflag)
            {
                searchtri.Oprev();
                if (searchtri.tri.id == Mesh.DUMMY)
                {
                    logger.Error("Unable to find a triangle on path.", "Mesh.FindDirection().2");
                    throw new Exception("Unable to find a triangle on path.");
                }
                rightvertex = searchtri.Dest();
                leftccw = rightccw;
                rightccw = predicates.CounterClockwise(startvertex, searchpoint, rightvertex);
                rightflag = rightccw > 0.0;
            }
            if (leftccw == 0.0)
            {
                return FindDirectionResult.Leftcollinear;
            }
            else if (rightccw == 0.0)
            {
                return FindDirectionResult.Rightcollinear;
            }
            else
            {
                return FindDirectionResult.Within;
            }
        }

        /// <summary>
        /// Find the intersection of an existing segment and a segment that is being 
        /// inserted. Insert a vertex at the intersection, splitting an existing subsegment.
        /// </summary>
        private void SegmentIntersection(ref Otri splittri, ref Osub splitsubseg, Vertex endpoint2)
        {
            Osub opposubseg = default(Osub);
            Vertex endpoint1;
            Vertex torg, tdest;
            Vertex leftvertex, rightvertex;
            Vertex newvertex;
            InsertVertexResult success;

            var dummysub = mesh.dummysub;

            double ex, ey;
            double tx, ty;
            double etx, ety;
            double split, denom;

            endpoint1 = splittri.Apex();
            torg = splittri.Org();
            tdest = splittri.Dest();
            tx = tdest.x - torg.x;
            ty = tdest.y - torg.y;
            ex = endpoint2.x - endpoint1.x;
            ey = endpoint2.y - endpoint1.y;
            etx = torg.x - endpoint2.x;
            ety = torg.y - endpoint2.y;
            denom = ty * ex - tx * ey;
            if (denom == 0.0)
            {
                logger.Error("Attempt to find intersection of parallel segments.",
                    "Mesh.SegmentIntersection()");
                throw new Exception("Attempt to find intersection of parallel segments.");
            }
            split = (ey * etx - ex * ety) / denom;

            newvertex = new Vertex(
                torg.x + split * (tdest.x - torg.x),
                torg.y + split * (tdest.y - torg.y),
                splitsubseg.seg.boundary
#if USE_ATTRIBS
                , mesh.nextras
#endif
                );

            newvertex.hash = mesh.hash_vtx++;
            newvertex.id = newvertex.hash;

#if USE_ATTRIBS
            for (int i = 0; i < mesh.nextras; i++)
            {
                newvertex.attributes[i] = torg.attributes[i] + split * (tdest.attributes[i] - torg.attributes[i]);
            }
#endif
#if USE_Z
            newvertex.z = torg.z + split * (tdest.z - torg.z);
#endif

            mesh.vertices.Add(newvertex.hash, newvertex);

            success = mesh.InsertVertex(newvertex, ref splittri, ref splitsubseg, false, false);
            if (success != InsertVertexResult.Successful)
            {
                logger.Error("Failure to split a segment.", "Mesh.SegmentIntersection()");
                throw new Exception("Failure to split a segment.");
            }
            newvertex.tri = splittri;
            if (mesh.steinerleft > 0)
            {
                mesh.steinerleft--;
            }

            splitsubseg.Sym();
            splitsubseg.Pivot(ref opposubseg);
            splitsubseg.Dissolve(dummysub);
            opposubseg.Dissolve(dummysub);
            do
            {
                splitsubseg.SetSegOrg(newvertex);
                splitsubseg.Next();
            } while (splitsubseg.seg.hash != Mesh.DUMMY);
            do
            {
                opposubseg.SetSegOrg(newvertex);
                opposubseg.Next();
            } while (opposubseg.seg.hash != Mesh.DUMMY);

            FindDirection(ref splittri, endpoint1);

            rightvertex = splittri.Dest();
            leftvertex = splittri.Apex();
            if ((leftvertex.x == endpoint1.x) && (leftvertex.y == endpoint1.y))
            {
                splittri.Onext();
            }
            else if ((rightvertex.x != endpoint1.x) || (rightvertex.y != endpoint1.y))
            {
                logger.Error("Topological inconsistency after splitting a segment.", "Mesh.SegmentIntersection()");
                throw new Exception("Topological inconsistency after splitting a segment.");
            }
        }

        /// <summary>
        /// Scout the first triangle on the path from one endpoint to another, and check 
        /// for completion (reaching the second endpoint), a collinear vertex, or the 
        /// intersection of two segments.
        /// </summary>
        private bool ScoutSegment(ref Otri searchtri, Vertex endpoint2, int newmark)
        {
            while (true)
            {
                FindDirectionResult collinear = FindDirection(ref searchtri, endpoint2);
                Vertex rightvertex = searchtri.Dest();
                Vertex leftvertex = searchtri.Apex();
                if (((leftvertex.x == endpoint2.x) && (leftvertex.y == endpoint2.y)) ||
                    ((rightvertex.x == endpoint2.x) && (rightvertex.y == endpoint2.y)))
                {
                    if ((leftvertex.x == endpoint2.x) && (leftvertex.y == endpoint2.y))
                    {
                        searchtri.Lprev();
                    }
                    mesh.InsertSubseg(ref searchtri, newmark);
                    return true;
                }
                else if (collinear == FindDirectionResult.Leftcollinear)
                {
                    searchtri.Lprev();
                    mesh.InsertSubseg(ref searchtri, newmark);
                    continue;
                }
                else if (collinear == FindDirectionResult.Rightcollinear)
                {
                    mesh.InsertSubseg(ref searchtri, newmark);
                    searchtri.Lnext();
                    continue;
                }
                else
                {
                    Otri crosstri = default(Otri);
                    Osub crosssubseg = default(Osub);
                    searchtri.Lnext(ref crosstri);
                    crosstri.Pivot(ref crosssubseg);
                    if (crosssubseg.seg.hash == Mesh.DUMMY)
                    {
                        return false;
                    }
                    else
                    {
                        SegmentIntersection(ref crosstri, ref crosssubseg, endpoint2);
                        crosstri.Copy(ref searchtri);
                        mesh.InsertSubseg(ref searchtri, newmark);
                        continue;
                    }
                }
            }
        }

        /// <summary>
        /// Iteratively enforce the Delaunay condition at an edge, fanning out from an existing vertex.
        /// This replaces the previous recursive implementation.
        /// </summary>
        private void DelaunayFixup(ref Otri fixuptri, bool leftside)
        {
            // Use an explicit stack: the tuple contains (current triangle, side flag, updateOriginal flag)
            var stack = new Stack<(Otri, bool, bool)>();
            stack.Push((fixuptri, leftside, true));

            while (stack.Count > 0)
            {
                var (current, side, updateOriginal) = stack.Pop();
                Otri neartri = default(Otri);
                current.Lnext(ref neartri);
                Otri fartri = default(Otri);
                neartri.Sym(ref fartri);
                if (fartri.tri.id == Mesh.DUMMY)
                {
                    if (updateOriginal)
                        fixuptri = current;
                    continue;
                }
                Osub faredge = default(Osub);
                neartri.Pivot(ref faredge);
                if (faredge.seg.hash != Mesh.DUMMY)
                {
                    if (updateOriginal)
                        fixuptri = current;
                    continue;
                }
                Vertex nearvertex = neartri.Apex();
                Vertex leftvertex = neartri.Org();
                Vertex rightvertex = neartri.Dest();
                Vertex farvertex = fartri.Apex();
                if (side)
                {
                    if (predicates.CounterClockwise(nearvertex, leftvertex, farvertex) <= 0.0)
                    {
                        if (updateOriginal)
                            fixuptri = current;
                        continue;
                    }
                }
                else
                {
                    if (predicates.CounterClockwise(farvertex, rightvertex, nearvertex) <= 0.0)
                    {
                        if (updateOriginal)
                            fixuptri = current;
                        continue;
                    }
                }
                if (predicates.CounterClockwise(rightvertex, leftvertex, farvertex) > 0.0)
                {
                    if (predicates.InCircle(leftvertex, farvertex, rightvertex, nearvertex) <= 0.0)
                    {
                        if (updateOriginal)
                            fixuptri = current;
                        continue;
                    }
                }
                // Not locally Delaunay; perform edge flip.
                mesh.Flip(ref neartri);
                current.Lprev(); // Restore the origin of current after the flip.
                // Push both current and fartri for further processing.
                stack.Push((current, side, updateOriginal));
                stack.Push((fartri, side, false));
            }
        }

        /// <summary>
        /// Force a segment into a constrained Delaunay triangulation by deleting the 
        /// triangles it intersects, and retriangulating the resulting polygons.
        /// This iterative version replaces the previous recursive implementation.
        /// </summary>
        private void ConstrainedEdge(ref Otri starttri, Vertex endpoint2, int newmark)
        {
            Otri fixuptri = default(Otri), fixuptri2 = default(Otri);
            Osub crosssubseg = default(Osub);
            Vertex endpoint1 = starttri.Org();
            Vertex farvertex;
            double area;
            bool collision;
            bool done;
            Otri localStart = starttri;

            while (true)
            {
                collision = false;
                done = false;
                localStart.Lnext(ref fixuptri);
                mesh.Flip(ref fixuptri);
                do
                {
                    farvertex = fixuptri.Org();
                    if ((farvertex.x == endpoint2.x) && (farvertex.y == endpoint2.y))
                    {
                        fixuptri.Oprev(ref fixuptri2);
                        DelaunayFixup(ref fixuptri, false);
                        DelaunayFixup(ref fixuptri2, true);
                        done = true;
                    }
                    else
                    {
                        area = predicates.CounterClockwise(endpoint1, endpoint2, farvertex);
                        if (area == 0.0)
                        {
                            collision = true;
                            fixuptri.Oprev(ref fixuptri2);
                            DelaunayFixup(ref fixuptri, false);
                            DelaunayFixup(ref fixuptri2, true);
                            done = true;
                        }
                        else
                        {
                            if (area > 0.0)
                            {
                                fixuptri.Oprev(ref fixuptri2);
                                DelaunayFixup(ref fixuptri2, true);
                                fixuptri.Lprev();
                            }
                            else
                            {
                                DelaunayFixup(ref fixuptri, false);
                                fixuptri.Oprev();
                            }
                            fixuptri.Pivot(ref crosssubseg);
                            if (crosssubseg.seg.hash == Mesh.DUMMY)
                            {
                                mesh.Flip(ref fixuptri);
                            }
                            else
                            {
                                collision = true;
                                SegmentIntersection(ref fixuptri, ref crosssubseg, endpoint2);
                                done = true;
                            }
                        }
                    }
                } while (!done);
                mesh.InsertSubseg(ref fixuptri, newmark);
                if (collision)
                {
                    if (!ScoutSegment(ref fixuptri, endpoint2, newmark))
                    {
                        localStart = fixuptri;
                        continue;
                    }
                }
                break;
            }
        }

        /// <summary>
        /// Insert a PSLG segment into a triangulation.
        /// </summary>
        private void InsertSegment(Vertex endpoint1, Vertex endpoint2, int newmark)
        {
            Otri searchtri1 = default(Otri), searchtri2 = default(Otri);
            Vertex checkvertex = null;

            var dummytri = mesh.dummytri;

            searchtri1 = endpoint1.tri;
            if (searchtri1.tri != null)
            {
                checkvertex = searchtri1.Org();
            }

            if (checkvertex != endpoint1)
            {
                searchtri1.tri = dummytri;
                searchtri1.orient = 0;
                searchtri1.Sym();
                if (locator.Locate(endpoint1, ref searchtri1) != LocateResult.OnVertex)
                {
                    logger.Error("Unable to locate PSLG vertex in triangulation.", "Mesh.InsertSegment().1");
                    throw new Exception("Unable to locate PSLG vertex in triangulation.");
                }
            }
            locator.Update(ref searchtri1);

            if (ScoutSegment(ref searchtri1, endpoint2, newmark))
            {
                return;
            }
            endpoint1 = searchtri1.Org();

            checkvertex = null;
            searchtri2 = endpoint2.tri;
            if (searchtri2.tri != null)
            {
                checkvertex = searchtri2.Org();
            }
            if (checkvertex != endpoint2)
            {
                searchtri2.tri = dummytri;
                searchtri2.orient = 0;
                searchtri2.Sym();
                if (locator.Locate(endpoint2, ref searchtri2) != LocateResult.OnVertex)
                {
                    logger.Error("Unable to locate PSLG vertex in triangulation.", "Mesh.InsertSegment().2");
                    throw new Exception("Unable to locate PSLG vertex in triangulation.");
                }
            }
            locator.Update(ref searchtri2);
            if (ScoutSegment(ref searchtri2, endpoint1, newmark))
            {
                return;
            }
            endpoint2 = searchtri2.Org();

            ConstrainedEdge(ref searchtri1, endpoint2, newmark);
        }

        /// <summary>
        /// Cover the convex hull of a triangulation with subsegments.
        /// </summary>
        private void MarkHull()
        {
            Otri hulltri = default(Otri);
            Otri nexttri = default(Otri);
            Otri starttri = default(Otri);

            hulltri.tri = mesh.dummytri;
            hulltri.orient = 0;
            hulltri.Sym();
            hulltri.Copy(ref starttri);
            do
            {
                mesh.InsertSubseg(ref hulltri, 1);
                hulltri.Lnext();
                hulltri.Oprev(ref nexttri);
                while (nexttri.tri.id != Mesh.DUMMY)
                {
                    nexttri.Copy(ref hulltri);
                    hulltri.Oprev(ref nexttri);
                }
            } while (!hulltri.Equals(starttri));
        }

        #endregion
    }
}
