// Copyright 2018 The MathWorks, Inc.

using UnrealBuildTool;
using System.IO;

public class AutoVrtlEnv : ModuleRules
{
    public AutoVrtlEnv(ReadOnlyTargetRules Target) : base(Target)
    {
        PublicDependencyModuleNames.AddRange(
            new string[]
            {
                "AIModule",
                "Core",
                "CoreUObject",
                "Engine",
                "GameplayTasks",
                "ImageWrapper",
                "InputCore",
                "MathWorksSimulation",
                "Slate",
                "SlateCore",
                "UMG",
            }
        );

        if (Target.bBuildEditor)
        {
            PublicDependencyModuleNames.AddRange(new string[] { "UnrealEd", });
        }

        PrivateDependencyModuleNames.AddRange(new string[] { });
    }
}
