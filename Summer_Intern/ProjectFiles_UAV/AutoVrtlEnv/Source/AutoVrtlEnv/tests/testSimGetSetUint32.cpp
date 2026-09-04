// Copyright 2021 The MathWorks, Inc.


#include "testSimGetSetUint32.h"

AtestSimGetSetUint32::AtestSimGetSetUint32()
    : SignalReader(nullptr)
    , SignalWriter(nullptr) {
}

void AtestSimGetSetUint32::Sim3dSetup() {
    Super::Sim3dSetup();
    if (IsValidSim3dActor()) {
        unsigned int  numElements = 65536;
        unsigned int datasize = sizeof(uint32) * numElements;
        FString actorName = GetSim3dActorName();
        FString SignalReaderTag = actorName;
        SignalReaderTag.Append(TEXT("Set"));
        SignalReader = StartSimulation3DMessageReader(TCHAR_TO_ANSI(*SignalReaderTag), datasize);
        FString SignalWriterTag = actorName;
        SignalWriterTag.Append(TEXT("Get"));
        SignalWriter = StartSimulation3DMessageWriter(TCHAR_TO_ANSI(*SignalWriterTag), datasize);
    }
}

void AtestSimGetSetUint32::Sim3dStep(float DeltaSeconds) {
    unsigned int  numElements = 65536;
    uint32* data = new uint32[65536];
    unsigned int datasize = sizeof(uint32) * numElements;
    int statusR = ReadSimulation3DMessage(SignalReader, datasize, data);

    FVector NewLocation;
    NewLocation.X = (float)data[0];
    NewLocation.Y = (float)data[1];
    NewLocation.Z = (float)data[2];
    SetActorLocation(NewLocation);

    int statusW = WriteSimulation3DMessage(SignalWriter, datasize, data);
    delete[] data;
}

void AtestSimGetSetUint32::Sim3dRelease() {
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


