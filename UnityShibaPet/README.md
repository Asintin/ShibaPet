# Unity 柴犬桌面宠物

用 Unity 制作的透明置顶桌面宠物：程序化拼装的 3D 卡通风柴犬，支持摸头、拖动、自动走动、
眨眼/摇尾/抖耳动画、经验升级（项圈/蝴蝶结/皇冠）、盯屏提醒。

> 本机未安装 Unity，故本项目为「源码交付」——装好 Unity 后打开即可 Build。

## 环境要求
- Windows 10/11
- Unity Hub + **Unity 2022.3 LTS**（任意 patch，推荐 x86_64）

## 打开与构建步骤

### 方式一：一键构建（推荐）
1. 打开 Unity Hub → 登录免费账号 → 安装 `2022.3 LTS`（Installs 页）。
2. `Add project from disk` → 选择本文件夹（`UnityShibaPet`），首次打开让它自动导入一次。
3. 双击 **`Build.ps1`**（或在 PowerShell 里运行 `.\Build.ps1`），自动：
   - 定位 2022.3 编辑器 → 创建空场景 → 切到 Windows x86_64 → 生成 `Build\ShibaPet.exe`。
4. 运行 `Build\ShibaPet.exe` 即可看到透明置顶柴犬。

> 若编辑器不在默认路径，用 `.\Build.ps1 -UnityExe "C:\Program Files\Unity\Hub\Editor\2022.3.20f1\Editor\Unity.exe"` 指定。

### 方式二：手动 GUI 构建
1. `File > New Scene`（Basic/Empty）→ 保存为 `Main`。
2. `File > Build Settings` → 拖入 `Main` → 平台选 **Windows x86_64** → `Build`。

## 交互
- **摸头**：左键点头部 → 冒爱心、弹跳、加分（+15 XP）、"啵"音。
- **拖动**：按住身体拖动到任意位置。
- **3D 视角**：行走时向移动方向转身（露出侧面）；站立空闲时左右缓慢摇摆，呈现立体感。
- **身体形态**：站立 / 坐下 / 趴睡三种形态。
  - 右键菜单可切换：`Pet` / `Sit` / `Sleep` / `Stand` / `Quit`。
  - 空闲约 18 秒自动坐下，40 秒自动趴下睡觉（闭眼）；一走动/拖动即起身。
- **自动走动**：在屏幕底部左右漫步，碰边转向；空闲时呼吸起伏、眨眼/摇尾/抖耳。
- **升级**：在线累积经验（约 1 点/秒），每级所需 120 × 等级。
  - Lv2 红项圈、Lv4 蝴蝶结、Lv6 皇冠；升级时播上行琶音 + 撒花。
  - 等级进度用 PlayerPrefs 持久化（`shiba.level` / `shiba.xp`）。
- **盯屏提醒**：连续活跃 20 分钟弹出 `Rest eyes! Lv.N` 气泡 + 提示音。
- 左上角显示 `Lv.N` 徽章。

## 透明窗口说明
- 使用免费的 Windows 原生 API（`SetWindowLong` + `SetLayeredWindowAttributes` 色彩键透明）。
- 相机清屏色与色键均为**品红 (1,0,1)**（见 `PetBootstrap.cs` 的 `KEY_COLOR`）。
- 代价：色键透明没有软边缘，柴犬轮廓边缘可能有轻微品红描边。如需更好边缘，可改为
  DWM 方案或第三方透明窗口插件。

## 常见问题
- **中文显示**：默认 UI 文本与右键菜单为 ASCII（`Lv.N`、`Rest eyes!`、`Pet/Sit/...`）。要显示中文，请
  在 `BuildUI()`/`GetFont()` 里替换为包含中文字形的字体资源（如思源黑体/微软雅黑 TTF），并自行改 `OnGUI` 的按钮文本。
- **点击无效**：若项目启用了新 Input System，请到 `Edit > Project Settings > Player >
  Active Input Handling` 改为 `Both`（脚本用的是旧版 `Input` API）。
- **窗口大小**：默认 420×560，可在 `PetBootstrap.Init()` 的 `Screen.SetResolution` 调整。
- **编译报 Shader "Standard" 缺失**：确保项目为 Built-in 渲染管线（本 manifest 未引入 URP）。
