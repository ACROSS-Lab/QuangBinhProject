using System.IO;
using UnityEngine;

namespace QuickTest
{
    public class MeshBackupUtility : MonoBehaviour
    {
        public void SaveMesh(string filePath)
        {
            GameObject targetObject = gameObject;
            MeshFilter meshFilter = targetObject.GetComponent<MeshFilter>();
            if (meshFilter == null) return;

            Mesh mesh = meshFilter.mesh;

            // Save mesh data including vertices, triangles, normals, UVs, tangents, colors, and submeshes
            MeshData meshData = new MeshData
            {
                vertices = mesh.vertices,
                triangles = mesh.triangles,
                normals = mesh.normals,
                uv = mesh.uv,
                tangents = mesh.tangents,
                colors = mesh.colors,
                //submeshes = new int[mesh.subMeshCount][]
            };

            // Save each submesh
            for (int i = 0; i < mesh.subMeshCount; i++)
            {
                //meshData.submeshes[i] = mesh.GetTriangles(i);
            }

            // Convert the mesh data to JSON
            string meshJson = JsonUtility.ToJson(meshData);

            // Write the JSON data to the file
            File.WriteAllText(filePath, meshJson);

            Debug.Log($"Mesh saved to {filePath}");
        }

        public void LoadMesh(string filePath)
        {
            GameObject targetObject = gameObject;

            if (File.Exists(filePath))
            {
                // Read the JSON data from the file
                string meshJson = File.ReadAllText(filePath);

                // Deserialize the JSON data back into MeshData
                MeshData meshData = JsonUtility.FromJson<MeshData>(meshJson);

                // Rebuild the mesh from saved data
                MeshFilter meshFilter = targetObject.GetComponent<MeshFilter>();
                Mesh mesh = new Mesh();

                // Apply the saved vertices, triangles, UVs, normals, tangents, and colors
                mesh.vertices = meshData.vertices;
                mesh.triangles = meshData.triangles;
                mesh.normals = meshData.normals;
                mesh.uv = meshData.uv;
                mesh.tangents = meshData.tangents;
                mesh.colors = meshData.colors;

                // Rebuild submeshes
                //mesh.subMeshCount = meshData.submeshes.Length;
                for (int i = 0; i < mesh.subMeshCount; i++)
                {
                    //mesh.SetTriangles(meshData.submeshes[i], i);
                }

                // Recalculate bounds and normals (if needed)
                if (mesh.normals == null || mesh.normals.Length == 0)
                {
                    mesh.RecalculateNormals();
                }
                mesh.RecalculateBounds();

                // Mark dynamic if needed
                mesh.MarkDynamic();

                // Assign the mesh to the mesh filter
                meshFilter.mesh = mesh;

                Debug.Log("Mesh loaded successfully.");
            }
            else
            {
                Debug.LogWarning("No saved mesh data found.");
            }
        }
    }

    [System.Serializable]
    public class MeshData
    {
        public Vector3[] vertices;    // Vertex positions
        public int[] triangles;       // Triangle indices
        public Vector3[] normals;     // Normals for lighting
        public Vector2[] uv;          // UV coordinates for texturing
        public Vector4[] tangents;    // Tangents for normal mapping
        public Color[] colors;        // Vertex colors, if used
        //public int[][] submeshes;     // Submesh triangle arrays
    }
}