# 觅长生 Mac / CrossOver 修复指南

在 Mac 上用 CrossOver 跑《觅长生》，有两个很经典的毛病：

1. **Mod 全部不生效** —— 创意工坊订阅了一堆 Mod，进游戏一个都没加载。
2. **改不了分辨率** —— 设置里分辨率下拉框是空的，点「应用」没反应或报错。

这两件事原因完全不同，修法也不一样，下面分开讲。

> 实测环境：CrossOver 26.3 + Steam 容器，Apple Silicon Mac，游戏版本 2026-09。
> 修复二依赖游戏内部的 `Tab.TabSetPanel` 结构，换版本可能失效（见文末）。

---

## 一、Mod 不生效

### 原因

觅长生的 Mod 框架是 **BepInEx**，它靠 [Doorstop](https://github.com/NeighTools/UnityDoorstop) 启动：游戏目录里放一个 `winhttp.dll`，游戏启动时加载它，由它再把 BepInEx 预加载器拉起来。

坑在于：Wine / CrossOver 默认优先加载**自带的**内置 `winhttp.dll`，游戏目录里那个原生代理根本轮不到。于是 Doorstop 没启动 → BepInEx 没启动 → 所有 Mod 静默失效。游戏本体照常运行，所以这个毛病很难自己察觉。

### 修法

让 Wine 优先加载游戏目录里的原生 DLL：

1. 完全退出游戏（Steam 可以留着）
2. CrossOver 里选中你的 Steam 容器 → **控制面板** → **Wine 配置**
3. 切到 **函数库** 标签页
4. 在 **新增函数库顶替** 里输入 `winhttp` → 点 **添加**
5. 确认「现有函数库顶替」列表里 `winhttp` 的值是 **原装先于内建**（native, builtin）
6. 点确定，重新启动游戏

各选项的含义，选错了没用：

| 选项 | 含义 | 能不能用 |
| --- | --- | --- |
| 原装先于内建 | native 优先，失败回退 builtin | ✅ 选这个 |
| 原装（windows） | 只用 native，无回退 | ⚠️ 能用但没兜底 |
| 内建先于原装 | builtin 优先 | ❌ 顺序反了，无效 |
| 内建（wine） | 只用 Wine 自带 | ❌ 这就是坏掉的状态 |
| 停用 | 禁用 winhttp | ❌ 游戏可能起不来 |

这一步做完，**所有** BepInEx Mod 都会开始工作，不只是本仓库这个插件。

### 验证

打开 BepInEx 目录下的 `LogOutput.log`，看到 `Chainloader started` 和一连串 `Loading [...]` 就对了：

```
[Message:   BepInEx] Chainloader started
[Info   :   BepInEx] 15 plugins to load
[Info   :   BepInEx] Loading [宵夜修改器 1.5.2]
[Info   :   BepInEx] Loading [Next 0.9.1]
...
```

---

## 二、改不了分辨率

### 原因

游戏在 `Tab.TabSetPanel` 里枚举显示器分辨率，再按 16:9 宽高比（`0.5625`）过滤一遍：

```csharp
foreach (Resolution r in Screen.resolutions) {
    if (list.Contains(r.width)) continue;
    if (Mathf.Abs((float)r.height / r.width - 0.5625f) > 0.001f) continue;
    // 加入 ResolutionsDict ...
}
```

Wine 上报的显示模式里没有 16:9 的项，过滤完就什么都不剩 → `ResolutionsDict` 为空 → 下拉框没内容 → 点「应用」时按索引取值为空、抛异常，连累整个设置面板。

另外全屏状态下，游戏会主动把分辨率下拉框置灰（`interactable = false`），就算有选项也点不动。

### 方案 A：装这个插件（推荐）

用 Harmony 在运行时补上缺失的行为，**不改游戏本体的 `Assembly-CSharp.dll`**：

- 给 `InitResolutionsDict` 挂后置补丁：原方法跑完后如果字典还是空的，就按当前桌面分辨率生成一组 16:9 档位。
- 给全屏回调挂后置补丁：把被置灰的下拉框恢复为可选。

好处是 Steam 校验文件完整性、游戏更新都不会冲掉它，而且出问题删掉 DLL 就干净回退了。

**安装**：把 `MCSResolutionFix.dll` 放进你的 BepInEx `plugins` 目录。

觅长生的 BepInEx 装在创意工坊目录里，通常是：

```
.../steamapps/workshop/content/1189490/2824349934/BepInEx/plugins/
```

不确定的话，看游戏目录的 `doorstop_config.ini` 里 `targetAssembly` 指向哪，它所在 BepInEx 目录旁边的 `plugins` 就是。

> 前提：**必须先做完上面第一步**。BepInEx 不启动，这个插件也不会加载。

### 方案 B：用 dnSpy 直接改 DLL

传统做法，参考 [觅长生 Wiki 上的原文](https://wiki.biligame.com/mcs/在_Mac_平台_通过_CrossOver/Wine_游玩觅长生)。用 dnSpy 打开 `觅长生_Data/Managed/Assembly-CSharp.dll`，改 `Tab.TabSetPanel` 的 `InitDropdown` / `InitResolutionsDict` 两个方法，然后保存模块。

注意：wiki 写于 2024-07，之后游戏改过结构 —— 「删除 `interactable = false`」这行现在位于全屏下拉框的回调 `‹InitDropdown›b__16_0` 里，不在 `InitDropdown` 本体中。另外 `InitResolutionsDict` 现在已经自带宽高比过滤了，要补的是「一个都没匹配上」的情况。

代价是改的是游戏本体文件，Steam 更新或校验完整性会覆盖掉，得重改。

### 验证

装好后进游戏，`LogOutput.log` 里会有：

```
[Info   :   BepInEx] Loading [MCS Resolution Fix 1.0.0]
[Info   :MCS Resolution Fix] MCS Resolution Fix 已加载
[Info   :MCS Resolution Fix] 已注入 5 个分辨率档位（当前桌面 1728x1117）
```

档位数量随屏幕分辨率变化。在 1728×1117 的屏幕上是：

```
1280x720  1440x810  1600x900  1728x972  1728x1117
```

最后一档是原生桌面分辨率 —— 全屏时游戏会自动选最后一项，正好落到原生。

---

## 从源码构建

`build.sh` 用 CrossOver 容器里自带的 `csc.exe` 编译，不需要在 Mac 上装 .NET。

```sh
./build.sh
```

脚本做的事：把引用程序集复制到容器内一个纯 ASCII 路径（避开中文路径的坑），用 `csc` 编译，再把产物拷回来。

顶部有四个变量可按需修改：

| 变量 | 说明 |
| --- | --- |
| `BOTTLE` | CrossOver 容器名，默认 `Steam` |
| `GAME` | 游戏安装目录（含 `觅长生_Data/Managed`） |
| `PLUGINS` | BepInEx 插件输出目录 |
| `OUT` | 编译产物文件名 |

编译依赖（都从你本地已装好的游戏和 BepInEx 里取，仓库不带二进制）：

- 游戏侧：`Assembly-CSharp.dll`、`UnityEngine.dll`、`UnityEngine.CoreModule.dll`、`UnityEngine.UI.dll`
- BepInEx 侧：`BepInEx.dll`、`0Harmony.dll`

---

## 已知限制

- **插件与游戏版本绑定**。`InitResolutionsDict` 是开发者写的稳定方法名；但 `<InitDropdown>b__16_0` 是编译器生成的，游戏一更新就可能改名。所以代码里对它是「找不到就跳过并记警告」，只有这条会失效，分辨率修复不受影响。
- 分辨率档位是**按当前桌面分辨率推算**的，不是真实枚举出来的（Wine 压根给不出可用的 `Screen.resolutions`）。想改档位范围，编辑 `src/Plugin.cs` 里的 `1280` / `160` / `0.5625f` 三个数。
- 只在 Apple Silicon + CrossOver 26 上实测过。

---

## 参考

- [在 Mac 平台通过 CrossOver/Wine 游玩觅长生 — 觅长生 Wiki](https://wiki.biligame.com/mcs/在_Mac_平台_通过_CrossOver/Wine_游玩觅长生)
- [BepInEx — Proton/Wine 说明](https://docs.bepinex.dev/articles/advanced/proton_wine.html)
- [UnityDoorstop](https://github.com/NeighTools/UnityDoorstop)

## 许可

MIT，见 [LICENSE](LICENSE)。
