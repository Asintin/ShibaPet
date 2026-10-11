using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Drives the Shiba: autonomous wandering (with 3D turning/sway), click-to-pet,
/// drag-to-move, blink / ear twitch / tail wag, stand/sit/lie poses (auto +
/// right-click menu), XP + leveling + accessories, screen-time reminder and a
/// level badge. All UI text is ASCII by default.
/// </summary>
public class PetController : MonoBehaviour
{
    Camera _cam;
    Transform _root, _body, _head, _eyeL, _eyeR, _earL, _earR;
    Transform[] _legs = new Transform[4];
    List<Transform> _tail = new List<Transform>();

    // base transforms for posing
    Vector3 _bodyBasePos, _headBasePos;
    Vector3 _bodyBaseScale;
    Vector3[] _legBasePos = new Vector3[4];
    Vector3[] _legBaseScale = new Vector3[4];

    float _minX, _maxX, _minY, _maxY;

    // movement
    float _vx, _speed;
    bool _moving;
    float _moveTimer, _dirTimer;
    Vector3 _basePos;
    int _facing = 1;

    // pose: 0 stand, 1 sit, 2 lie
    int _pose;
    float _poseTimer;

    // animation
    float _blinkTimer;
    bool _blinkOn;
    float _earTimer, _earDur;
    float _wagTimer;
    bool _wagOn;

    // interaction
    bool _dragging;
    Vector3 _grabOffset;
    bool _happy;
    float _happyTimer;

    // leveling
    int _level = 1;
    float _xp;
    float _xpNeed = 120f;

    // reminder
    float _focusTime;
    bool _reminding;
    float _remindStart;

    // ui
    Text _levelText, _bubbleText;
    float _bubbleTimer;

    // audio
    AudioSource _audio;
    AudioClip _boop, _chirp, _fanfare;

    // accessories
    GameObject _collar, _bow, _crown;

    // right-click menu
    bool _menu;
    Vector2 _menuPos;

    const float XP_RATE = 1f;
    const int REMIND_SECONDS = 1200; // 20 minutes

    void Start()
    {
        _cam = Camera.main;
        _root = transform;
        _body = _root.Find("Body");
        _head = _root.Find("Head");
        _eyeL = _head.Find("EyeL");
        _eyeR = _head.Find("EyeR");
        _earL = _head.Find("EarL");
        _earR = _head.Find("EarR");
        _legs[0] = _root.Find("LegFL");
        _legs[1] = _root.Find("LegFR");
        _legs[2] = _root.Find("LegBL");
        _legs[3] = _root.Find("LegBR");
        for (int i = 0; i < 4; i++) { Transform t = _root.Find("Tail" + i); if (t != null) _tail.Add(t); }

        _bodyBasePos = _body.localPosition;
        _bodyBaseScale = _body.localScale;
        _headBasePos = _head.localPosition;
        for (int i = 0; i < 4; i++) { if (_legs[i] != null) { _legBasePos[i] = _legs[i].localPosition; _legBaseScale[i] = _legs[i].localScale; } }

        _basePos = _root.position;
        ComputeBounds();

        BuildUI();
        BuildAudio();

        _level = PlayerPrefs.GetInt("shiba.level", 1);
        _xp = PlayerPrefs.GetFloat("shiba.xp", 0f);
        if (_level < 1) _level = 1;
        _xpNeed = 120f * _level;
        UpdateAccessories();
        UpdateLevelText();

        _moveTimer = 1.5f;
        _dirTimer = 2f;
        _blinkTimer = Random.Range(2f, 4f);
        _wagTimer = Random.Range(3f, 6f);
        _earTimer = Random.Range(4f, 7f);
    }

    void ComputeBounds()
    {
        float halfH = _cam.orthographicSize;
        float halfW = halfH * _cam.aspect;
        _minX = -halfW + 0.7f;
        _maxX = halfW - 0.7f;
        _minY = -halfH + 0.5f;
        _maxY = halfH - 1.4f;
    }

    void Update()
    {
        float dt = Time.deltaTime;

        HandleInput();
        UpdateMovement(dt);
        UpdatePoseAuto(dt);
        UpdateAnim(dt);

        GainXp(dt * XP_RATE);

        if (!_reminding)
        {
            _focusTime += dt;
            if (_focusTime >= REMIND_SECONDS) { _focusTime = 0; TriggerReminder(); }
        }
        else if (Time.time - _remindStart > 6f)
        {
            _reminding = false;
            _bubbleText.text = "";
        }

        if (_bubbleTimer > 0f)
        {
            _bubbleTimer -= dt;
            if (_bubbleTimer <= 0f && !_reminding) _bubbleText.text = "";
        }
    }

    // ---------------------------------------------------------- input

    void HandleInput()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Vector3 p = MouseWorld();
            Vector3 hc = _head.position;
            float dx = p.x - hc.x, dy = p.y - hc.y;
            if (dx * dx + dy * dy < 0.55f * 0.55f) Pet();
            else { _dragging = true; _grabOffset = _root.position - p; }
        }
        if (_dragging && Input.GetMouseButton(0))
        {
            Vector3 p = MouseWorld();
            Vector3 np = p + _grabOffset;
            np.x = Mathf.Clamp(np.x, _minX, _maxX);
            np.y = Mathf.Clamp(np.y, _minY, _maxY);
            np.z = 0f;
            _root.position = np;
            _basePos = np;
        }
        if (Input.GetMouseButtonUp(0)) _dragging = false;

        if (Input.GetMouseButtonDown(1))
        {
            _menu = true;
            _menuPos = new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y);
        }
    }

    Vector3 MouseWorld()
    {
        Vector3 m = Input.mousePosition;
        return _cam.ScreenToWorldPoint(new Vector3(m.x, m.y, Mathf.Abs(_cam.transform.position.z)));
    }

    void OnGUI()
    {
        if (!_menu) return;
        float w = 120f, h = 160f;
        float x = Mathf.Clamp(_menuPos.x, 0f, Screen.width - w);
        float y = Mathf.Clamp(_menuPos.y, 0f, Screen.height - h);
        GUILayout.BeginArea(new Rect(x, y, w, h), GUI.skin.box);
        if (GUILayout.Button("Pet")) { Pet(); _menu = false; }
        if (GUILayout.Button("Sit")) { SetPose(1); _menu = false; }
        if (GUILayout.Button("Sleep")) { SetPose(2); _menu = false; }
        if (GUILayout.Button("Stand")) { SetPose(0); _menu = false; }
        if (GUILayout.Button("Quit")) { Application.Quit(); }
        GUILayout.EndArea();
    }

    // ------------------------------------------------------- movement

    void UpdateMovement(float dt)
    {
        if (_dragging) return;

        if (_pose == 2)
        {
            _moving = false;
            float bob = Mathf.Sin(Time.time * 2f) * 0.02f;
            _root.position = new Vector3(_basePos.x, _basePos.y + bob, 0f);
            _root.rotation = Quaternion.identity;
            return;
        }

        _moveTimer -= dt;
        if (_moveTimer <= 0f)
        {
            _moving = !_moving;
            if (_moving)
            {
                _speed = Random.Range(0.5f, 1.4f);
                _vx = Random.value < 0.5f ? -_speed : _speed;
                _facing = _vx >= 0f ? 1 : -1;
                _moveTimer = Random.Range(2f, 5f);
            }
            else { _vx = 0f; _moveTimer = Random.Range(1.5f, 4f); }
        }

        if (_moving)
        {
            _dirTimer -= dt;
            if (_dirTimer <= 0f)
            {
                _dirTimer = Random.Range(2f, 4f);
                if (Random.value < 0.4f) { _vx = -_vx; _facing = _vx >= 0f ? 1 : -1; }
            }

            Vector3 p = _basePos;
            p.x += _vx * dt;
            if (p.x < _minX) { p.x = _minX; _vx = Mathf.Abs(_vx); _facing = 1; }
            else if (p.x > _maxX) { p.x = _maxX; _vx = -Mathf.Abs(_vx); _facing = -1; }
            _basePos = p;

            float bob = Mathf.Sin(Time.time * 8f) * 0.05f;
            _root.position = new Vector3(p.x, p.y + bob, 0f);
            _root.rotation = Quaternion.Euler(0f, _facing * 25f, _facing * 6f);
        }
        else
        {
            float bob = Mathf.Sin(Time.time * 2f) * 0.03f;
            _root.position = new Vector3(_basePos.x, _basePos.y + bob, 0f);
            _root.rotation = Quaternion.Euler(0f, Mathf.Sin(Time.time * 0.6f) * 14f, 0f);
        }

        if (_happy)
        {
            _happyTimer -= dt;
            float s = 1f + Mathf.Sin((1.2f - _happyTimer) / 1.2f * Mathf.PI) * 0.15f;
            _root.localScale = Vector3.one * Mathf.Max(0.01f, s);
            if (_happyTimer <= 0f) { _happy = false; _root.localScale = Vector3.one; }
        }
    }

    void UpdatePoseAuto(float dt)
    {
        if (_dragging || _moving)
        {
            if (_pose != 0) { _pose = 0; ApplyPose(); }
            _poseTimer = 0f;
        }
        else
        {
            _poseTimer += dt;
            if (_pose == 0 && _poseTimer > 18f) { _pose = 1; ApplyPose(); }
            else if (_pose == 1 && _poseTimer > 40f) { _pose = 2; ApplyPose(); }
        }
    }

    void SetPose(int p)
    {
        _pose = p;
        _poseTimer = 0f;
        _moving = false;
        ApplyPose();
    }

    void ApplyPose()
    {
        if (_pose == 2)
        {
            _body.localPosition = _bodyBasePos + new Vector3(0f, -0.3f, 0f);
            _body.localScale = new Vector3(_bodyBaseScale.x, _bodyBaseScale.y * 0.5f, _bodyBaseScale.z * 1.1f);
            _head.localPosition = _headBasePos + new Vector3(0f, -0.9f, 0.05f);
            SetLegs(0.05f, 0.05f, 0.05f, 0.05f);
        }
        else if (_pose == 1)
        {
            _body.localPosition = _bodyBasePos + new Vector3(0f, -0.2f, 0f);
            _body.localScale = _bodyBaseScale;
            _head.localPosition = _headBasePos + new Vector3(0f, -0.25f, 0f);
            SetLegs(1f, 1f, 0.05f, 0.05f);
        }
        else
        {
            _body.localPosition = _bodyBasePos;
            _body.localScale = _bodyBaseScale;
            _head.localPosition = _headBasePos;
            SetLegs(1f, 1f, 1f, 1f);
        }
    }

    void SetLegs(float fl, float fr, float bl, float br)
    {
        float[] f = { fl, fr, bl, br };
        for (int i = 0; i < 4; i++)
        {
            if (_legs[i] == null) continue;
            Vector3 v = _legBaseScale[i];
            v.y = _legBaseScale[i].y * f[i];
            _legs[i].localScale = v;
        }
    }

    void UpdateAnim(float dt)
    {
        if (_pose == 2)
        {
            SetEyesOpen(0.06f);
        }
        else
        {
            _blinkTimer -= dt;
            if (_blinkTimer <= 0f)
            {
                if (_blinkOn) { _blinkOn = false; SetEyesOpen(1f); _blinkTimer = Random.Range(2.5f, 4.5f); }
                else { _blinkOn = true; SetEyesOpen(0.08f); _blinkTimer = 0.12f; }
            }
        }

        _earTimer -= dt;
        if (_earTimer <= 0f)
        {
            if (_earDur > 0f) { _earDur = 0f; _earTimer = Random.Range(4f, 7f); }
            else { _earDur = 0.25f; _earTimer = 0.25f; }
        }
        float ea = 0f;
        if (_earDur > 0f) { _earDur -= dt; ea = Mathf.Sin(Time.time * 25f) * 10f; }
        if (_earL != null) _earL.localRotation = Quaternion.Euler(0f, 0f, 16f + ea);
        if (_earR != null) _earR.localRotation = Quaternion.Euler(0f, 0f, -16f - ea);

        _wagTimer -= dt;
        if (_wagTimer <= 0f)
        {
            _wagOn = !_wagOn;
            _wagTimer = _wagOn ? 1.6f : Random.Range(2.5f, 5f);
        }
        float wag = _wagOn ? Mathf.Sin(Time.time * 9f) * 18f : Mathf.Sin(Time.time * 2f) * 5f;
        for (int i = 0; i < _tail.Count; i++)
        {
            Vector3 e = _tail[i].localEulerAngles;
            e.z = wag * (i + 1) * 0.5f;
            _tail[i].localEulerAngles = e;
        }
    }

    void SetEyesOpen(float s)
    {
        if (_eyeL != null) { Vector3 v = _eyeL.localScale; v.y = 0.18f * s; _eyeL.localScale = v; }
        if (_eyeR != null) { Vector3 v = _eyeR.localScale; v.y = 0.18f * s; _eyeR.localScale = v; }
    }

    // ------------------------------------------------------ interaction

    void Pet()
    {
        if (_boop != null) _audio.PlayOneShot(_boop);
        GainXp(15f);
        _happy = true;
        _happyTimer = 1.2f;
        for (int i = 0; i < 4; i++) SpawnHeart();
    }

    void SpawnHeart()
    {
        GameObject go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        go.name = "Heart";
        Material m = new Material(Shader.Find("Standard"));
        m.color = Palette.Heart;
        go.GetComponent<MeshRenderer>().sharedMaterial = m;
        go.transform.position = _head.position + new Vector3(Random.Range(-0.4f, 0.4f), 0.4f, 0.4f);
        go.transform.localScale = Vector3.one * 0.16f;
        StartCoroutine(FloatHeart(go));
    }

    IEnumerator FloatHeart(GameObject go)
    {
        Vector3 start = go.transform.position;
        float t = 0f;
        while (t < 1f)
        {
            t += Time.deltaTime * 1.4f;
            go.transform.position = start + new Vector3(0f, t * 0.9f, 0f);
            go.transform.localScale = Vector3.one * Mathf.Lerp(0.16f, 0.05f, t);
            yield return null;
        }
        Destroy(go);
    }

    // --------------------------------------------------------- leveling

    void GainXp(float amt)
    {
        _xp += amt;
        while (_xp >= _xpNeed)
        {
            _xp -= _xpNeed;
            _level++;
            _xpNeed = 120f * _level;
            OnLevelUp();
        }
    }

    void OnLevelUp()
    {
        PlayerPrefs.SetInt("shiba.level", _level);
        PlayerPrefs.SetFloat("shiba.xp", _xp);
        PlayerPrefs.Save();
        if (_fanfare != null) _audio.PlayOneShot(_fanfare);
        UpdateAccessories();
        UpdateLevelText();
        ShowBubble("Lv." + _level + "!");
        for (int i = 0; i < 6; i++) SpawnHeart();
    }

    void UpdateAccessories()
    {
        if (_level >= 2 && _collar == null) _collar = BuildCollar();
        if (_level >= 4 && _bow == null) _bow = BuildBow();
        if (_level >= 6 && _crown == null) _crown = BuildCrown();
    }

    GameObject BuildCollar()
    {
        GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        go.name = "Collar";
        Material m = new Material(Shader.Find("Standard")); m.color = Palette.Collar;
        go.GetComponent<MeshRenderer>().sharedMaterial = m;
        go.transform.SetParent(_root, false);
        go.transform.localPosition = new Vector3(0f, 1.05f, 0f);
        go.transform.localScale = new Vector3(1.1f, 0.08f, 1.1f);
        return go;
    }

    GameObject BuildBow()
    {
        GameObject go = new GameObject("Bow");
        go.transform.SetParent(_root, false);
        go.transform.localPosition = new Vector3(0f, 1.05f, 0.5f);

        Material m = new Material(Shader.Find("Standard")); m.color = Palette.Bow;

        GameObject c1 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        c1.transform.SetParent(go.transform, false);
        c1.transform.localPosition = new Vector3(-0.16f, 0.02f, 0f);
        c1.transform.localScale = new Vector3(0.18f, 0.15f, 0.06f);
        c1.transform.localRotation = Quaternion.Euler(0f, 0f, -20f);
        c1.GetComponent<MeshRenderer>().sharedMaterial = m;

        GameObject c2 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        c2.transform.SetParent(go.transform, false);
        c2.transform.localPosition = new Vector3(0.16f, 0.02f, 0f);
        c2.transform.localScale = new Vector3(0.18f, 0.15f, 0.06f);
        c2.transform.localRotation = Quaternion.Euler(0f, 0f, 20f);
        c2.GetComponent<MeshRenderer>().sharedMaterial = m;

        GameObject knot = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        knot.transform.SetParent(go.transform, false);
        knot.transform.localScale = Vector3.one * 0.12f;
        knot.GetComponent<MeshRenderer>().sharedMaterial = m;

        return go;
    }

    GameObject BuildCrown()
    {
        GameObject go = new GameObject("Crown");
        go.transform.SetParent(_root, false);
        go.transform.localPosition = new Vector3(0f, 2.1f, 0f);

        Material m = new Material(Shader.Find("Standard")); m.color = Palette.Gold;

        GameObject baseC = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        baseC.transform.SetParent(go.transform, false);
        baseC.transform.localScale = new Vector3(0.5f, 0.08f, 0.5f);
        baseC.GetComponent<MeshRenderer>().sharedMaterial = m;

        for (int i = -1; i <= 1; i++)
        {
            GameObject p = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            p.transform.SetParent(go.transform, false);
            p.transform.localPosition = new Vector3(i * 0.16f, 0.09f, 0f);
            p.transform.localScale = Vector3.one * 0.12f;
            p.GetComponent<MeshRenderer>().sharedMaterial = m;
        }

        return go;
    }

    // ----------------------------------------------------------- reminder

    void TriggerReminder()
    {
        _reminding = true;
        _remindStart = Time.time;
        if (_chirp != null) _audio.PlayOneShot(_chirp);
        ShowBubble("Rest eyes!  Lv." + _level);
    }

    // --------------------------------------------------------------- ui

    void UpdateLevelText()
    {
        if (_levelText != null) _levelText.text = "Lv." + _level;
    }

    void ShowBubble(string s)
    {
        if (_bubbleText != null) _bubbleText.text = s;
        _bubbleTimer = 2.6f;
    }

    void BuildUI()
    {
        GameObject canvasGo = new GameObject("Canvas");
        Canvas canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasGo.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(420f, 560f);

        Font font = GetFont();

        GameObject lgo = new GameObject("LevelText");
        lgo.transform.SetParent(canvasGo.transform, false);
        _levelText = lgo.AddComponent<Text>();
        _levelText.font = font;
        _levelText.fontSize = 22;
        _levelText.fontStyle = FontStyle.Bold;
        _levelText.color = new Color(0.55f, 0.35f, 0.1f);
        _levelText.alignment = TextAnchor.UpperLeft;
        RectTransform lrt = _levelText.rectTransform;
        lrt.anchorMin = new Vector2(0f, 1f);
        lrt.anchorMax = new Vector2(0f, 1f);
        lrt.pivot = new Vector2(0f, 1f);
        lrt.anchoredPosition = new Vector2(8f, -8f);
        lrt.sizeDelta = new Vector2(200f, 30f);

        GameObject bgo = new GameObject("BubbleText");
        bgo.transform.SetParent(canvasGo.transform, false);
        _bubbleText = bgo.AddComponent<Text>();
        _bubbleText.font = font;
        _bubbleText.fontSize = 22;
        _bubbleText.fontStyle = FontStyle.Bold;
        _bubbleText.color = new Color(0.4f, 0.25f, 0.08f);
        _bubbleText.alignment = TextAnchor.UpperCenter;
        RectTransform brt = _bubbleText.rectTransform;
        brt.anchorMin = new Vector2(0.5f, 1f);
        brt.anchorMax = new Vector2(0.5f, 1f);
        brt.pivot = new Vector2(0.5f, 1f);
        brt.anchoredPosition = new Vector2(0f, -8f);
        brt.sizeDelta = new Vector2(380f, 36f);
        _bubbleText.text = "";
    }

    Font GetFont()
    {
        Font f = null;
        try { f = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); } catch { }
        if (f == null) f = Resources.GetBuiltinResource<Font>("Arial.ttf");
        return f;
    }

    // -------------------------------------------------------------- audio

    void BuildAudio()
    {
        _audio = gameObject.AddComponent<AudioSource>();
        _audio.playOnAwake = false;
        _boop = MakeTone(540f, 0.14f);
        _chirp = MakeChirp();
        _fanfare = MakeFanfare();
    }

    AudioClip MakeTone(float freq, float dur)
    {
        int sr = 22050;
        int n = Mathf.CeilToInt(sr * dur);
        float[] data = new float[n];
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr;
            float env = Mathf.Min(1f, t / 0.008f) * Mathf.Exp(-t * 15f);
            data[i] = Mathf.Sin(2f * Mathf.PI * freq * t) * env * 0.3f;
        }
        AudioClip c = AudioClip.Create("boop", n, 1, sr, false);
        c.SetData(data, 0);
        return c;
    }

    AudioClip MakeChirp()
    {
        int sr = 22050;
        int n1 = Mathf.CeilToInt(sr * 0.09f), n2 = Mathf.CeilToInt(sr * 0.12f);
        int n = n1 + n2;
        float[] data = new float[n];
        for (int i = 0; i < n1; i++) { float t = i / (float)sr; data[i] = Mathf.Sin(2f * Mathf.PI * 660f * t) * Mathf.Exp(-t * 18f) * 0.28f; }
        for (int i = 0; i < n2; i++) { float t = i / (float)sr; data[n1 + i] = Mathf.Sin(2f * Mathf.PI * 880f * t) * Mathf.Exp(-t * 16f) * 0.28f; }
        AudioClip c = AudioClip.Create("chirp", n, 1, sr, false);
        c.SetData(data, 0);
        return c;
    }

    AudioClip MakeFanfare()
    {
        int sr = 22050;
        float[] freqs = { 523.25f, 659.25f, 783.99f, 1046.5f };
        int nn = Mathf.CeilToInt(sr * 0.11f);
        int n = nn * 4;
        float[] data = new float[n];
        for (int k = 0; k < 4; k++)
            for (int i = 0; i < nn; i++)
            {
                float t = i / (float)sr;
                data[k * nn + i] = Mathf.Sin(2f * Mathf.PI * freqs[k] * t) * Mathf.Exp(-t * 9f) * 0.3f;
            }
        AudioClip c = AudioClip.Create("fanfare", n, 1, sr, false);
        c.SetData(data, 0);
        return c;
    }
}
