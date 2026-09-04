// Copyright 2021 The MathWorks, Inc.


#include "testSimGetSetInt8.h"

AtestSimGetSetInt8::AtestSimGetSetInt8()
    : SignalReader(nullptr)
    , SignalWriter(nullptr) {
}

void AtestSimGetSetInt8::Sim3dSetup() {
    Super::Sim3dSetup();
    if (IsValidSim3dActor()) {
        int numElements = 65536;
        int datasize = sizeof(int8) * numElements;
        FString actorName = GetSim3dActorName();
        FString SignalReaderTag = actorName;
        SignalReaderTag.Append(TEXT("Set"));
        SignalReader = StartSimulation3DMessageReader(TCHAR_TO_ANSI(*SignalReaderTag), datasize);
        FString SignalWriterTag = actorName;
        SignalWriterTag.Append(TEXT("Get"));
        SignalWriter = StartSimulation3DMessageWriter(TCHAR_TO_ANSI(*SignalWriterTag), datasize);
    }
}

void AtestSimGetSetInt8::Sim3dStep(float DeltaSeconds) {
    int  numElements = 65536;
    int8* data = new int8[65536];
    int datasize = sizeof(int8) * numElements;
    int statusR = ReadSimulation3DMessage(SignalReader, datasize, data);

    FVector NewLocation;
    NewLocation.X = (float)data[0];
    NewLocation.Y = (float)data[1];
    NewLocation.Z = (float)data[2];
    SetActorLocation(NewLocation);

    int statusW = WriteSimulation3DMessage(SignalWriter, datasize, data);
    delete[] data;
}

void AtestSimGetSetInt8::Sim3dRelease() {
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


