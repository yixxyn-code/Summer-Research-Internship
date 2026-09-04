// Copyright 2018-2024 The MathWorks, Inc.

using UnrealBuildTool;
using System.Collections.Generic;

public class AutoVrtlEnvTarget : TargetRules
{
    public AutoVrtlEnvTarget(TargetInfo Target) : base(Target)
    {
        DefaultBuildSettings = BuildSettingsVersion.V4;
        Type = TargetType.Game;

        ExtraModuleNames.AddRange( new string[] { "AutoVrtlEnv" } );

        if (Target.Platform == UnrealTargetPlatform.Linux) {
            bForceEnableExceptions = true;
        }

        bOverrideBuildEnvironment = true;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
    }
}