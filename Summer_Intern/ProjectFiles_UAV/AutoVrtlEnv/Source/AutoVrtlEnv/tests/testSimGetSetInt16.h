// Copyright 2021 The MathWorks, Inc.

#pragma once

#include "Sim3dActor.h"
#include "testSimGetSetInt16.generated.h"

/**
 *
 */
UCLASS()
class AUTOVRTLENV_API AtestSimGetSetInt16 : public ASim3dActor
{
    GENERATED_BODY()


    void* SignalReader;
    void* SignalWriter;

public:
    // Sets default values for this actor's properties
    AtestSimGetSetInt16();

    virtual void Sim3dSetup() override;
    virtual void Sim3dRelease() override;
    virtual void Sim3dStep(float DeltaSeconds) override;
};