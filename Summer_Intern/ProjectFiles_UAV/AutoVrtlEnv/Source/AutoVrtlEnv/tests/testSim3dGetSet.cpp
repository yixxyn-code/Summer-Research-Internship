// Copyright 2018 The MathWorks, Inc.


#include "testSim3dGetSet.h"

// Sets default values
//AtestSim3dGetSet::AtestSim3dGetSet()


AtestSim3dGetSet::AtestSim3dGetSet()
    : SignalReader(nullptr)
    , SignalWriter(nullptr) {
}

void AtestSim3dGetSet::Sim3dSetup() {
    Super::Sim3dSetup();
    if (IsValidSim3dActor()) {
        int numElements = 65536;
        unsigned int datasize = sizeof(float)*numElements;
        FString actorName = GetSim3dActorName();
        FString SignalReaderTag = actorName;
        SignalReaderTag.Append(TEXT("Set"));
        SignalReader = StartSimulation3DMessageReader(TCHAR_TO_ANSI(*SignalReaderTag), datasize);
        FString SignalWriterTag = actorName;
        SignalWriterTag.Append(TEXT("Get"));
        SignalWriter = StartSimulation3DMessageWriter(TCHAR_TO_ANSI(*SignalWriterTag), datasize);
    }
}

void AtestSim3dGetSet::Sim3dStep(float DeltaSeconds) {
    int numElements = 65536;
    float* data =new float[65536]; 
    unsigned int datasize = sizeof(float) * numElements;
    int statusR = ReadSimulation3DMessage(SignalReader, datasize, data);

    FVector NewLocation;
    NewLocation.X = data[0];
    NewLocation.Y = data[1];
    NewLocation.Z = data[2];
    SetActorLocation(NewLocation);

    int statusW = WriteSimulation3DMessage(SignalWriter, datasize, data);
    delete[] data;
}

void AtestSim3dGetSet::Sim3dRelease() {
    Super::Sim3dRelease();
    if (SignalReader) {
        StopSimulation3DMessageReader(SignalReader);
    }
    SignalReader = nullptr;

    if (SignalWriter) {
        StopSimulation3DMessageWriter(SignalWriter);
    }
    SignalWriter = nullptr;
}


