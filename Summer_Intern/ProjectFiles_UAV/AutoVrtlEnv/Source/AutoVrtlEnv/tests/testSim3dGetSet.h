// Copyright 2018 The MathWorks, Inc.

#pragma once


#include "Sim3dActor.h"
#include "testSim3dGetSet.generated.h"

UCLASS()
class AUTOVRTLENV_API AtestSim3dGetSet : public ASim3dActor {
    GENERATED_BODY()

    void* SignalReader;
    void* SignalWriter;

  public:
    // Sets default values for this actor's properties
    AtestSim3dGetSet();

    virtual void Sim3dSetup() override;
    virtual void Sim3dRelease() override;
    virtual void Sim3dStep(float DeltaSeconds) override;
};
