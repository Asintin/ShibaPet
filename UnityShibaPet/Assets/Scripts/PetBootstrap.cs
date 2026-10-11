using System;
using System.Diagnostics;
using UnityEngine;

/// <summary>
/// Bootstraps the whole pet at runtime. No scene setup required:
/// just have any scene in Build Settings. This auto-creates camera,
/// light, the Shiba and its controller.
/// </summary>
public static class PetBootstrap
{
    // Must match the NativeWindow color key (magenta).
    public static readonly Color KEY_COLOR = new Color(1f, 0f, 1f, 1f);

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        Application.targetFrameRate = 60;
        Screen.SetResolution(420, 560, false);

        SetupCamera();
        SetupLight();

        GameObject pet = ShibaBuilder.Build();
        pet.AddComponent<PetController>();

        // Transparency needs the real window handle, which is ready a few
        // frames after startup. A tiny MonoBehaviour handles that.
        new GameObject("WindowBootstrap").AddComponent<WindowBootstrap>();
    }

    static void SetupCamera()
    {
        Camera cam = Camera.main;
        if (cam == null)
        {
            var go = new GameObject("Main Camera");
            go.tag = "MainCamera";
            cam = go.AddComponent<Camera>();
        }

        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = KEY_COLOR;
        cam.orthographic = true;
        cam.orthographicSize = 2.7f;
        cam.nearClipPlane = 0.1f;
        cam.farClipPlane = 100f;
        cam.transform.position = new Vector3(0f, 1.1f, -10f);
        cam.transform.rotation = Quaternion.identity;

        if (cam.GetComponent<AudioListener>() == null)
            cam.gameObject.AddComponent<AudioListener>();
    }

    static void SetupLight()
    {
        var lgo = new GameObject("Key Light");
        var l = lgo.AddComponent<Light>();
        l.type = LightType.Directional;
        l.intensity = 1.1f;
        l.color = Color.white;
        lgo.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
    }
}

public class WindowBootstrap : MonoBehaviour
{
    int _frames;

    void Update()
    {
        if (_frames++ < 8) return;

        IntPtr hwnd = Process.GetCurrentProcess().MainWindowHandle;
        if (hwnd != IntPtr.Zero)
        {
            NativeWindow.ApplyTransparent(hwnd, 255, 0, 255);
            enabled = false; // run once
        }
    }
}
