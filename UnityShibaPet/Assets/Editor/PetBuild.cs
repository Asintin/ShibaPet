using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// One-click build. Called from Build.ps1 via:
///   Unity.exe -batchmode -quit -projectPath ... -executeMethod PetBuild.Build
/// </summary>
public static class PetBuild
{
    [MenuItem("Tools/Build Shiba Pet")]
    public static void Build()
    {
        PlayerSettings.productName = "ShibaPet";
        PlayerSettings.companyName = "Pet";

        // Ensure there is at least one scene in Build Settings.
        if (EditorBuildSettings.scenes.Length == 0)
        {
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            Directory.CreateDirectory("Assets/Scenes");
            string scenePath = "Assets/Scenes/Main.unity";
            EditorSceneManager.SaveScene(scene, scenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(scenePath, true) };
        }

        // Target Windows x86_64.
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, BuildTarget.StandaloneWindows64);

        string outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Build"));
        Directory.CreateDirectory(outDir);
        string exe = Path.Combine(outDir, "ShibaPet.exe");

        BuildPlayerOptions opts = new BuildPlayerOptions
        {
            scenes = GetScenePaths(),
            locationPathName = exe,
            target = BuildTarget.StandaloneWindows64,
            options = BuildOptions.None
        };

        BuildReport report = BuildPipeline.BuildPlayer(opts);

        if (report.summary.result == BuildResult.Succeeded)
        {
            Debug.Log("BUILD_OK: " + exe);
        }
        else
        {
            Debug.LogError("BUILD_FAILED: " + report.summary.result);
            EditorApplication.Exit(1);
        }
    }

    static string[] GetScenePaths()
    {
        string[] paths = new string[EditorBuildSettings.scenes.Length];
        for (int i = 0; i < paths.Length; i++)
            paths[i] = EditorBuildSettings.scenes[i].path;
        return paths;
    }
}
