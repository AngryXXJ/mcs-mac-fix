using System;
using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using Tab;
using UnityEngine;

namespace MCSResFix
{
    [BepInPlugin(Guid, "MCS Resolution Fix", "1.0.0")]
    public class ResolutionFixPlugin : BaseUnityPlugin
    {
        public const string Guid = "com.jackie.mcs.resfix";
        internal static ManualLogSource Log;

        void Awake()
        {
            Log = Logger;
            var harmony = new Harmony(Guid);

            Patch(harmony, "InitResolutionsDict", nameof(Patches.ResolutionsPostfix), true);
            // 全屏回调是编译器生成的名字，游戏更新后可能变；找不到只跳过这一条，
            // 不能连累上面的分辨率修复。
            Patch(harmony, "<InitDropdown>b__16_0", nameof(Patches.FullScreenPostfix), false);

            Log.LogInfo("MCS Resolution Fix 已加载");
        }

        static void Patch(Harmony harmony, string target, string postfix, bool required)
        {
            var original = AccessTools.Method(typeof(TabSetPanel), target);
            var patch = AccessTools.Method(typeof(Patches), postfix);
            if (original == null || patch == null)
            {
                if (required) Log.LogError("找不到目标方法 " + target + "，分辨率修复未生效");
                else Log.LogWarning("找不到目标方法 " + target + "，已跳过该补丁");
                return;
            }
            harmony.Patch(original, postfix: new HarmonyMethod(patch));
        }
    }

    static class Patches
    {
        // Wine/CrossOver 下 Screen.resolutions 里没有任何 16:9 项，InitResolutionsDict
        // 跑完后字典是空的 —— 下拉框全空、点"应用"报错。这里按当前桌面分辨率补一份档位。
        internal static void ResolutionsPostfix(TabSetPanel __instance)
        {
            var dict = __instance.ResolutionsDict;
            if (dict == null || dict.Count > 0) return;

            int curW = Screen.currentResolution.width;
            int curH = Screen.currentResolution.height;
            if (curW <= 0 || curH <= 0) { curW = 1600; curH = 900; }

            int num = 0;
            for (int w = 1280; w < curW; w += 160)
                dict.Add(num++, new MResolution { X = w, Y = Mathf.FloorToInt(w * 0.5625f) });

            int full169H = Mathf.FloorToInt(curW * 0.5625f);
            if (full169H > 0 && full169H <= curH)
                dict.Add(num++, new MResolution { X = curW, Y = full169H });

            // 原生桌面分辨率放最后：全屏时游戏会自动选中最后一项
            dict.Add(num, new MResolution { X = curW, Y = curH });

            ResolutionFixPlugin.Log.LogInfo(
                "已注入 " + dict.Count + " 个分辨率档位（当前桌面 " + curW + "x" + curH + "）");
        }

        // 全屏时游戏把分辨率下拉框置灰（interactable = false），导致无法改分辨率。
        internal static void FullScreenPostfix(TabSetPanel __instance)
        {
            if (__instance.ResolutionDropdown != null)
                __instance.ResolutionDropdown.interactable = true;
        }
    }
}
