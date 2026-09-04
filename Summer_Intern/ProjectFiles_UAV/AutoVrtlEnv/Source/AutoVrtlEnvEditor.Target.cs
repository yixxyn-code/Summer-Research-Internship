// Copyright 2018-2024 The MathWorks, Inc.

using UnrealBuildTool;
using System.Collections.Generic;

public class AutoVrtlEnvEditorTarget : TargetRules
{
    public AutoVrtlEnvEditorTarget(TargetInfo Target) : base(Target)
    {
        DefaultBuildSettings = BuildSettingsVersion.V4;
        Type = TargetType.Editor;

        ExtraModuleNames.AddRange(new string[] { "AutoVrtlEnv" });

        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
    }
}