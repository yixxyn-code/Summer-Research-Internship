// Copyright 2021 The MathWorks, Inc.


#include "testSimGetSetDouble.h"

AtestSimGetSetDouble::AtestSimGetSetDouble()
    : SignalReader(nullptr)
    , SignalWriter(nullptr) {
}

void AtestSimGetSetDouble::Sim3dSetup() {
    Super::Sim3dSetup();
    if (IsValidSim3dActor()) {
        int numElements = 65536;
        int datasize = sizeof(double) * numElements;
        FString actorName = GetSim3dActorName();
        FString SignalReaderTag = actorName;
        SignalReaderTag.Append(TEXT("Set"));
        SignalReader = StartSimulation3DMessageReader(TCHAR_TO_ANSI(*SignalReaderTag), datasize);
        FString SignalWriterTag = actorName;
        SignalWriterTag.Append(TEXT("Get"));
        SignalWriter = StartSimulation3DMessageWriter(TCHAR_TO_ANSI(*SignalWriterTag), datasize);
    }
}

void AtestSimGetSetDouble::Sim3dStep(float DeltaSeconds) {
    int  numElements = 65536;
    double* data = new double[65536];
    int datasize = sizeof(double) * numElements;
    int statusR = ReadSimulation3DMessage(SignalReader, datasize, data);

    FVector NewLocation;
    NewLocation.X = (float)data[0];
    NewLocation.Y = (float)data[1];
    NewLocation.Z = (float)data[2];
    SetActorLocation(NewLocation);

    int statusW = WriteSimulation3DMessage(SignalWriter, datasize, data);
    delete[] data;
}

void AtestSimGetSetDouble::Sim3dRelease() {
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


