using UnityEngine;

public static class Palette
{
    public static readonly Color Orange     = new Color(0.956f, 0.65f, 0.29f);
    public static readonly Color OrangeDark = new Color(0.84f, 0.49f, 0.17f);
    public static readonly Color Cream      = new Color(1.00f, 0.95f, 0.88f);
    public static readonly Color Dark       = new Color(0.18f, 0.12f, 0.10f);
    public static readonly Color Blush      = new Color(1.00f, 0.47f, 0.57f);
    public static readonly Color Heart      = new Color(1.00f, 0.41f, 0.53f);
    public static readonly Color Gold       = new Color(1.00f, 0.79f, 0.16f);
    public static readonly Color Collar     = new Color(0.80f, 0.24f, 0.24f);
    public static readonly Color Bow        = new Color(1.00f, 0.43f, 0.59f);
}

/// <summary>
/// Builds a chibi 3D Shiba out of Unity primitives (no external models).
/// The face (muzzle/eyes/nose/ears/blush) is parented to the Head so the
/// whole head can be moved/posed as one unit.
/// </summary>
public static class ShibaBuilder
{
    public static GameObject Build()
    {
        var root = new GameObject("Shiba");

        // body + belly
        var body = Prim(root.transform, "Body", PrimitiveType.Sphere, Palette.Orange,
            new Vector3(0f, 0.55f, 0f), new Vector3(1.0f, 0.85f, 0.75f));
        Prim(body.transform, "Belly", PrimitiveType.Sphere, Palette.Cream,
            new Vector3(0f, -0.13f, 0.42f), new Vector3(0.72f, 0.6f, 0.6f));

        // head + face
        var head = Prim(root.transform, "Head", PrimitiveType.Sphere, Palette.Orange,
            new Vector3(0f, 1.35f, 0f), new Vector3(1.15f, 1.05f, 0.95f));
        Prim(head.transform, "Muzzle", PrimitiveType.Sphere, Palette.Cream,
            new Vector3(0f, -0.11f, 0.5f), new Vector3(0.56f, 0.42f, 0.4f));
        Prim(head.transform, "Nose", PrimitiveType.Sphere, Palette.Dark,
            new Vector3(0f, -0.05f, 0.78f), new Vector3(0.13f, 0.1f, 0.1f));
        Prim(head.transform, "CheekL", PrimitiveType.Sphere, Palette.Cream,
            new Vector3(-0.5f, -0.17f, 0.34f), new Vector3(0.28f, 0.22f, 0.16f));
        Prim(head.transform, "CheekR", PrimitiveType.Sphere, Palette.Cream,
            new Vector3(0.5f, -0.17f, 0.34f), new Vector3(0.28f, 0.22f, 0.16f));
        Prim(head.transform, "EyeL", PrimitiveType.Sphere, Palette.Dark,
            new Vector3(-0.34f, 0.15f, 0.52f), new Vector3(0.14f, 0.18f, 0.1f));
        Prim(head.transform, "EyeR", PrimitiveType.Sphere, Palette.Dark,
            new Vector3(0.34f, 0.15f, 0.52f), new Vector3(0.14f, 0.18f, 0.1f));
        Prim(head.transform, "EyeLHi", PrimitiveType.Sphere, Color.white,
            new Vector3(-0.29f, 0.21f, 0.6f), new Vector3(0.055f, 0.055f, 0.04f));
        Prim(head.transform, "EyeRHi", PrimitiveType.Sphere, Color.white,
            new Vector3(0.29f, 0.21f, 0.6f), new Vector3(0.055f, 0.055f, 0.04f));
        Prim(head.transform, "EarL", PrimitiveType.Cube, Palette.Orange,
            new Vector3(-0.55f, 0.57f, -0.02f), new Vector3(0.28f, 0.5f, 0.14f), new Vector3(0f, 0f, 16f));
        Prim(head.transform, "EarR", PrimitiveType.Cube, Palette.Orange,
            new Vector3(0.55f, 0.57f, -0.02f), new Vector3(0.28f, 0.5f, 0.14f), new Vector3(0f, 0f, -16f));
        Prim(head.transform, "BlushL", PrimitiveType.Sphere, Palette.Blush,
            new Vector3(-0.5f, -0.03f, 0.56f), new Vector3(0.17f, 0.1f, 0.08f));
        Prim(head.transform, "BlushR", PrimitiveType.Sphere, Palette.Blush,
            new Vector3(0.5f, -0.03f, 0.56f), new Vector3(0.17f, 0.1f, 0.08f));

        // legs (direct children of root so they can be hidden per-pose)
        Prim(root.transform, "LegFL", PrimitiveType.Capsule, Palette.Orange,
            new Vector3(-0.38f, 0.3f, 0.28f), new Vector3(0.22f, 0.28f, 0.22f));
        Prim(root.transform, "LegFR", PrimitiveType.Capsule, Palette.Orange,
            new Vector3(0.38f, 0.3f, 0.28f), new Vector3(0.22f, 0.28f, 0.22f));
        Prim(root.transform, "LegBL", PrimitiveType.Capsule, Palette.Orange,
            new Vector3(-0.32f, 0.3f, -0.34f), new Vector3(0.22f, 0.28f, 0.22f));
        Prim(root.transform, "LegBR", PrimitiveType.Capsule, Palette.Orange,
            new Vector3(0.32f, 0.3f, -0.34f), new Vector3(0.22f, 0.28f, 0.22f));

        // curled tail (right side)
        Prim(root.transform, "Tail0", PrimitiveType.Sphere, Palette.Orange,
            new Vector3(0.5f, 0.6f, -0.35f), new Vector3(0.3f, 0.3f, 0.3f));
        Prim(root.transform, "Tail1", PrimitiveType.Sphere, Palette.Orange,
            new Vector3(0.64f, 0.86f, -0.36f), new Vector3(0.27f, 0.27f, 0.27f));
        Prim(root.transform, "Tail2", PrimitiveType.Sphere, Palette.Orange,
            new Vector3(0.7f, 1.08f, -0.36f), new Vector3(0.24f, 0.24f, 0.24f));
        Prim(root.transform, "Tail3", PrimitiveType.Sphere, Palette.Cream,
            new Vector3(0.62f, 1.24f, -0.36f), new Vector3(0.22f, 0.22f, 0.22f));

        root.transform.position = new Vector3(0f, -0.4f, 0f);
        return root;
    }

    static GameObject Prim(Transform parent, string name, PrimitiveType type, Color color,
        Vector3 localPos, Vector3 scale, Vector3 euler = default(Vector3))
    {
        var go = GameObject.CreatePrimitive(type);
        go.name = name;

        var mat = new Material(Shader.Find("Standard"));
        mat.color = color;
        mat.SetFloat("_Glossiness", 0.3f);
        go.GetComponent<MeshRenderer>().sharedMaterial = mat;

        go.transform.SetParent(parent, false);
        go.transform.localPosition = localPos;
        go.transform.localScale = scale;
        go.transform.localEulerAngles = euler;
        return go;
    }
}
