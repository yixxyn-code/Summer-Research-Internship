function UNM_loadRRBusObject()
% UNM_loadRRBusObjects creates the required bus objects for the
% UNM Traffic Signal Follower co-simulation project.
%
% This is a simplified version of helperSLCreateTrafficSignalBusObjects
% containing only the bus objects needed for:
%   1. Ego vehicle pose reading
%   2. Traffic signal state reading (RED/YELLOW/GREEN)
%   3. Vehicle path following
%
% Run this before opening UNM_TrafficSignalFollower.slx
%
% Author: Kee Xin Yi
% Project: UNM Traffic Light Co-simulation

fprintf('Loading UNM bus objects...\n');

%% =============================================
%  PART 1: Load base RoadRunner bus objects
%  (BusActorRuntime and BusVehicleRuntime)
%  These come from MathWorks and define how
%  RoadRunner sends actor/vehicle data to Simulink
%% =============================================
rrInterfaceBuses = load('rrScenarioSimTypes.mat');
BusActorRuntime = rrInterfaceBuses.BusActorRuntime;
BusVehicleRuntime = rrInterfaceBuses.BusVehicleRuntime;
assignin('base', 'BusActorRuntime', BusActorRuntime);
assignin('base', 'BusVehicleRuntime', BusVehicleRuntime);
fprintf('  [OK] BusActorRuntime loaded\n');
fprintf('  [OK] BusVehicleRuntime loaded\n');

%% =============================================
%  PART 2: BusRuntimeTurnConfiguration
%  Defines the structure of one traffic light
%  turn configuration - contains:
%    - TimeLeft: seconds remaining in current phase
%    - TurnType: which turns this config applies to
%    - ConfigurationType: RED / YELLOW / GREEN
%  This is what HelperGetTrafficSignal reads to
%  get signal state and time left
%% =============================================
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'TimeLeft';           % seconds left in current phase
elems(1).Dimensions = [1 1];
elems(1).DimensionsMode = 'Fixed';
elems(1).DataType = 'double';
elems(1).Complexity = 'real';
elems(1).Min = [];
elems(1).Max = [];

elems(2) = Simulink.BusElement;
elems(2).Name = 'TurnType';           % e.g. straight, left, right
elems(2).Dimensions = [1 1];
elems(2).DimensionsMode = 'Fixed';
elems(2).DataType = 'Enum: EnumTurnType';
elems(2).Complexity = 'real';
elems(2).Min = [];
elems(2).Max = [];

elems(3) = Simulink.BusElement;
elems(3).Name = 'ConfigurationType';  % RED / YELLOW / GREEN
elems(3).Dimensions = [1 1];
elems(3).DimensionsMode = 'Fixed';
elems(3).DataType = 'Enum: EnumConfigurationType';
elems(3).Complexity = 'real';
elems(3).Min = [];
elems(3).Max = [];

BusRuntimeTurnConfiguration = Simulink.Bus;
BusRuntimeTurnConfiguration.Elements = elems;
clear elems;
assignin('base', 'BusRuntimeTurnConfiguration', BusRuntimeTurnConfiguration);
fprintf('  [OK] BusRuntimeTurnConfiguration loaded\n');

%% =============================================
%  PART 3: BusBulbConfiguration
%  Defines one traffic light bulb state
%  (e.g. the red bulb is ON or OFF)
%% =============================================
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'BulbName';           % name of the bulb e.g. "Red"
elems(1).Dimensions = 1;
elems(1).DimensionsMode = 'Fixed';
elems(1).DataType = 'string';
elems(1).Complexity = 'real';
elems(1).Min = [];
elems(1).Max = [];

elems(2) = Simulink.BusElement;
elems(2).Name = 'BulbState';          % ON or OFF
elems(2).Dimensions = [1 1];
elems(2).DimensionsMode = 'Fixed';
elems(2).DataType = 'Enum: EnumBulbState';
elems(2).Complexity = 'real';
elems(2).Min = [];
elems(2).Max = [];

BusBulbConfiguration = Simulink.Bus;
BusBulbConfiguration.Elements = elems;
clear elems;
assignin('base', 'BusBulbConfiguration', BusBulbConfiguration);
fprintf('  [OK] BusBulbConfiguration loaded\n');

%% =============================================
%  PART 4: BusSignalConfiguration
%  Defines the full configuration of one signal head
%  Contains arrays of BulbConfigurations and
%  TurnConfigurations (up to 5 turn configs)
%  This is what RoadRunner sends every timestep
%  to describe the current state of a traffic light
%% =============================================
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'ConfigurationIndex';
elems(1).Dimensions = [1 1];
elems(1).DimensionsMode = 'Fixed';
elems(1).DataType = 'uint32';
elems(1).Complexity = 'real';
elems(1).Min = [];
elems(1).Max = [];

elems(2) = Simulink.BusElement;
elems(2).Name = 'NumBulbConfiguration';
elems(2).Dimensions = [1 1];
elems(2).DimensionsMode = 'Fixed';
elems(2).DataType = 'uint32';
elems(2).Complexity = 'real';
elems(2).Min = [];
elems(2).Max = [];

elems(3) = Simulink.BusElement;
elems(3).Name = 'BulbConfiguration';  % array of bulb states [1x6]
elems(3).Dimensions = [1 6];
elems(3).DimensionsMode = 'Fixed';
elems(3).DataType = 'Bus: BusBulbConfiguration';
elems(3).Complexity = 'real';
elems(3).Min = [];
elems(3).Max = [];

elems(4) = Simulink.BusElement;
elems(4).Name = 'NumTurnConfiguration'; % how many turn configs exist
elems(4).Dimensions = [1 1];
elems(4).DimensionsMode = 'Fixed';
elems(4).DataType = 'uint32';
elems(4).Complexity = 'real';
elems(4).Min = [];
elems(4).Max = [];

elems(5) = Simulink.BusElement;
elems(5).Name = 'TurnConfiguration';   % array of turn configs [1x5]
elems(5).Dimensions = [1 5];           % each contains RED/GREEN/YELLOW
elems(5).DimensionsMode = 'Fixed';
elems(5).DataType = 'Bus: BusRuntimeTurnConfiguration';
elems(5).Complexity = 'real';
elems(5).Min = [];
elems(5).Max = [];

BusSignalConfiguration = Simulink.Bus;
BusSignalConfiguration.Elements = elems;
clear elems;
assignin('base', 'BusSignalConfiguration', BusSignalConfiguration);
fprintf('  [OK] BusSignalConfiguration loaded\n');

%% =============================================
%  PART 5: BusSignalHead
%  Identifies which signal head and controller
%  this runtime data belongs to
%% =============================================
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'SignalID';           % ID of this signal head
elems(1).Dimensions = 1;
elems(1).DimensionsMode = 'Fixed';
elems(1).DataType = 'string';
elems(1).Complexity = 'real';
elems(1).Min = [];
elems(1).Max = [];

elems(2) = Simulink.BusElement;
elems(2).Name = 'ControllerID';       % ID of parent controller
elems(2).Dimensions = 1;
elems(2).DimensionsMode = 'Fixed';
elems(2).DataType = 'string';
elems(2).Complexity = 'real';
elems(2).Min = [];
elems(2).Max = [];

BusSignalHead = Simulink.Bus;
BusSignalHead.Elements = elems;
clear elems;
assignin('base', 'BusSignalHead', BusSignalHead);
fprintf('  [OK] BusSignalHead loaded\n');

%% =============================================
%  PART 6: BusTrafficSignalRuntime
%  The TOP LEVEL bus for one traffic signal head
%  This is what your Traffic Signal Runtime
%  Reader block outputs every timestep
%  Contains:
%    - ActorID: which actor is this signal
%    - SignalHead: identifies signal and controller
%    - SignalConfiguration: current RED/GREEN/YELLOW state
%% =============================================
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'ActorID';            % numeric ID of signal actor
elems(1).Dimensions = 1;
elems(1).DimensionsMode = 'Fixed';
elems(1).DataType = 'double';
elems(1).Complexity = 'real';
elems(1).Min = [];
elems(1).Max = [];

elems(2) = Simulink.BusElement;
elems(2).Name = 'SignalHead';         % which signal head
elems(2).Dimensions = 1;
elems(2).DimensionsMode = 'Fixed';
elems(2).DataType = 'Bus: BusSignalHead';
elems(2).Complexity = 'real';
elems(2).Min = [];
elems(2).Max = [];

elems(3) = Simulink.BusElement;
elems(3).Name = 'SignalConfiguration'; % RED/GREEN/YELLOW + time left
elems(3).Dimensions = 1;
elems(3).DimensionsMode = 'Fixed';
elems(3).DataType = 'Bus: BusSignalConfiguration';
elems(3).Complexity = 'real';
elems(3).Min = [];
elems(3).Max = [];

BusTrafficSignalRuntime = Simulink.Bus;
BusTrafficSignalRuntime.Elements = elems;
clear elems;
assignin('base', 'BusTrafficSignalRuntime', BusTrafficSignalRuntime);
fprintf('  [OK] BusTrafficSignalRuntime loaded\n');

%% =============================================
%  DONE
%% =============================================
fprintf('\nAll UNM bus objects loaded successfully!\n');
fprintf('You can now open UNM_TrafficSignalFollower.slx\n\n');

end