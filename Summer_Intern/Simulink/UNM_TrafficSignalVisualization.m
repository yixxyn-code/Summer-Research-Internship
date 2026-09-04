classdef UNM_TrafficSignalVisualization < matlab.System
    % UNM_TrafficSignalVisualization Displays the traffic signal runtime and vehicle information.
  
   

    % Public, non-tunable properties
    properties(Nontunable)
        % RoadRunner HD Map
        RRHDMap = roadrunnerHDMap;

        % Vehicle Spec
        VehicleSpec = struct;

        % Approaching Controller ID
        EgoControllerID = 10;

        % Approaching Signal ID
        EgoSignalID = 9;

        % Ego Actor ID
        EgoID = 1;

        % Sample Time
        Ts = 0.05;

    end

    properties
        % Disable Visualization
        DisableVisualization (1, 1) logical = false;
    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Figure properties
        Figure
        SceneAxes

        % Plots
        TrafficSignalPlot
        EgoTrafficSignalPlot
        AllActorPatch

        % UI Tables
        UITabPhaseInterval
        UITabTrafficSignalRuntime
        UITabTrafficSignalControllerRuntime
        UITabEgoSignal

        % Other properties
        NumVehicles
        VehicleIDs
        TrafficSignalControllerSpec
        ControllerActorIDs
        ControllerIdx
        EgoSignalPos
        Counter = 0;
        RedStyle
        YellowStyle
        GreenStyle
    end

    methods (Access = protected)
        function setupImpl(obj)

            % Create the figure if it doesn't exist already
            figureName = 'Traffic Signal Simulation';
            obj.Figure = findall(0,'Type','figure','tag',figureName);
            if isempty(obj.Figure)
                screenSize = double(get(groot,'ScreenSize'));
                obj.Figure = uifigure('Name',figureName,'Tag',figureName);
                obj.Figure.Position = [screenSize(3)*0.04 screenSize(4)*0.1 screenSize(3)*0.65 screenSize(4)*0.70];
                obj.Figure.NumberTitle = 'off';
                obj.Figure.MenuBar = 'none';
                obj.Figure.ToolBar = 'none';
                obj.Figure.Theme = matlab.graphics.theme.GraphicsTheme;
            end

            % Clear figure
            clf(obj.Figure)

            % If disable visualization is true, hide the figure.
            if obj.DisableVisualization
                set(obj.Figure,"Visible","off");
            else
                set(obj.Figure,"Visible","on");
            end

            % Define UI panels
            scenePanel = uipanel(obj.Figure,'Units','Normalized','Position',[0 0 0.5 1],'Title','Traffic Signal and Vehicle Plot','ForegroundColor','black','FontWeight','bold');
            hTrafficSignalRuntimePanel = uipanel(obj.Figure,'Units','Normalized','Position',[0.5 0 0.5 0.5],'Title','All Traffic Signal Runtime','FontWeight','bold');
            hPhasePanel = uipanel(obj.Figure,'Units','Normalized','Position',[0.5 0.5 0.5 0.2],'Title','Traffic Phases and Intervals','FontWeight','bold');
            hEgoTrafficSignalPanel = uipanel(obj.Figure,'Units','Normalized','Position',[0.5 0.7 0.5 0.3],'Title','Ego Relevant Traffic Signal','FontWeight','bold');

            % Get scene panel axis
            obj.SceneAxes = axes('Parent',scenePanel);

            % Set the figure toolbar
            axtoolbar(obj.SceneAxes, {'datacursor','rotate','pan','zoomin','zoomout','restoreview'});

            % Plot the roadrunnerHDMap (Only the lane boundaries)
            hold(obj.SceneAxes,"on")
            arrayfun(@(lb) plot(lb.Geometry(:,1),lb.Geometry(:,2),"Parent",obj.SceneAxes,"Color",[0.5, 0.5, 0.5]),obj.RRHDMap.LaneBoundaries);
            set(obj.SceneAxes,'DataAspectRatio',[1 1 1]);
            grid(obj.SceneAxes,'on');
            xlabel(obj.SceneAxes,'X (m)');
            ylabel(obj.SceneAxes,'Y (m)');

            % UI Table for ego associated traffic signal runtime.
            obj.UITabEgoSignal = uitable(hEgoTrafficSignalPanel,'Units','Normalized','FontName','Consolas','FontSize',17,'FontWeight','normal');
            obj.UITabEgoSignal.RowName = {'Controller ID','Signal ID','Bulb Color','Time Left (s)','Turn Type','distToStop (m)'};
            obj.UITabEgoSignal.ColumnName = {};
            obj.UITabEgoSignal.ColumnWidth = {'auto','auto','auto','auto','auto','auto'};
            obj.UITabEgoSignal.ColumnFormat = {'char','char','char','char','char','char'};
            obj.UITabEgoSignal.Position = [0 0 1 1];

            % TrafficSignalRuntime UI Table
            obj.UITabTrafficSignalRuntime = uitable(hTrafficSignalRuntimePanel,'Units','Normalized','FontName','Consolas','FontSize',17,'FontWeight','normal');
            obj.UITabTrafficSignalRuntime.ColumnName = {'Signal ID','Bulb Color','Time Left (s)','Turn Type'};
            obj.UITabTrafficSignalRuntime.RowName = {};
            obj.UITabTrafficSignalRuntime.ColumnWidth = {'auto','auto','auto','auto'};
            obj.UITabTrafficSignalRuntime.ColumnFormat = {'char','char','char','char'};
            obj.UITabTrafficSignalRuntime.Position = [0 0 1 1];

            % Traffic Phases and Intervals UI Table
            obj.UITabPhaseInterval = uitable(hPhasePanel,'Units','Normalized','FontName','Consolas','FontSize',17,'FontWeight','normal');
            obj.UITabPhaseInterval.ColumnName = {'Phase Number','Phase Name','Green','Yellow','Red'};
            obj.UITabPhaseInterval.RowName = {};
            obj.UITabPhaseInterval.ColumnWidth = {'auto','auto','auto','auto','auto','auto'};
            obj.UITabPhaseInterval.ColumnFormat = {'char','char','char','char','char','char'};
            obj.UITabPhaseInterval.Position = [0 0 1 1];

            % Target and Ego vehicle plot
            % Create vehicle patches
            obj.NumVehicles = numel(obj.VehicleSpec);
            obj.VehicleIDs = vertcat(obj.VehicleSpec.ID);
            for i=1:obj.NumVehicles
                % Plot the patch
                obj.AllActorPatch{i} = patch(obj.SceneAxes,'XData', [], 'YData',[]);
                obj.AllActorPatch{i}.FaceColor = obj.VehicleSpec(i).Color;
                obj.AllActorPatch{i}.EdgeColor = 'black';
                obj.AllActorPatch{i}.LineWidth = 0.5;
                obj.AllActorPatch{i}.FaceAlpha = 0.6;
            end

            obj.RedStyle = uistyle;
            obj.RedStyle.BackgroundColor = "red";
            obj.RedStyle.FontColor = "white";

            obj.YellowStyle = uistyle;
            obj.YellowStyle.BackgroundColor = "yellow";

            obj.GreenStyle = uistyle;
            obj.GreenStyle.BackgroundColor = "green";
        end

        %% Run Every Timestep
        function stepImpl(obj,distToStop,controllerRuntime,controllerSpec,signalRuntime,signalSpec,allVehicleRuntime)
            if ~obj.DisableVisualization % If disable visualization is true, do not update the plots.
                allSpec.TrafficSignalSpec = signalSpec;
                allSpec.TrafficControllerSpec = controllerSpec;

                allRuntime.TrafficSignalRuntime = signalRuntime;
                allRuntime.TrafficControllerRuntime = controllerRuntime;

                % Initialize counter
                obj.Counter = obj.Counter + 1;

                % Plot the static information only once at the start.
                if obj.Counter <= 1
                    % Initialize the traffic signal plot
                    numSigHeads = numel(allSpec.TrafficSignalSpec);
                    for i = 1:numSigHeads
                        actorID = double(allSpec.TrafficSignalSpec(i).ActorSpec.ActorID);
                        pos = allSpec.TrafficSignalSpec(i).SignalPosition;
                        obj.TrafficSignalPlot{i} = line(obj.SceneAxes, 0, 0,'MarkerEdgeColor','black','MarkerFaceColor','red','Marker','o','MarkerSize', 11,'LineStyle','none','Tag',num2str(actorID));
                        obj.TrafficSignalPlot{i}.XData = pos(1);
                        obj.TrafficSignalPlot{i}.YData = pos(2);
                        text(obj.SceneAxes,pos(1),pos(2),num2str(actorID),'FontSize',9,'FontWeight','normal','HorizontalAlignment','center');
                    end

                    % Initialize the ego signal plot
                    allSignalActorID = arrayfun(@(x) double(x.ActorSpec.ActorID), allSpec.TrafficSignalSpec);
                    egoIdx = allSignalActorID == obj.EgoSignalID;
                    egoSignalPos = allSpec.TrafficSignalSpec(egoIdx).SignalPosition;
                    obj.EgoSignalPos = egoSignalPos;
                    obj.EgoTrafficSignalPlot = line(obj.SceneAxes, egoSignalPos(1), egoSignalPos(2),'MarkerEdgeColor','blue','MarkerFaceColor','none','Marker','hexagram','MarkerSize',16,'LineWidth',1,'LineStyle','none');

                    % Get ego controller position
                    allControllerActorID = arrayfun(@(x) double(x.ActorSpec.ActorID), allSpec.TrafficControllerSpec);
                    cntlIdx = find(allControllerActorID==obj.EgoControllerID);

                    % Update the phase interval
                    numPhases = allSpec.TrafficControllerSpec(cntlIdx).NumTrafficSignalControllerPhases;
                    phaseInfo = cell(numPhases,4);
                    for i = 1:numPhases
                        phaseInfo{i,1} = i;
                        phaseInfo{i,2} = char(allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseName);
                        greenIdx = find([allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval.IntervalType] == EnumIntervalType.Green);
                        yellowIdx = find([allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval.IntervalType] == EnumIntervalType.Yellow);
                        redIdx = find([allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval.IntervalType] == EnumIntervalType.Red);
                        phaseInfo{i,3} = allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval(greenIdx).IntervalTime;
                        phaseInfo{i,4} = allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval(yellowIdx).IntervalTime;
                        phaseInfo{i,5} = allSpec.TrafficControllerSpec(cntlIdx).TrafficSignalControllerPhases(i).PhaseInterval(redIdx).IntervalTime;
                    end
                    obj.UITabPhaseInterval.Data = phaseInfo;
                end

                % Update all signal head runtime information.
                numSigHeads = numel(allRuntime.TrafficSignalRuntime);
                signalTabInfo = cell(numSigHeads,1);
                for i = 1:numSigHeads
                    signalActorID = double(allRuntime.TrafficSignalRuntime(i).ActorRuntime.ActorID);
                    turnConfigIdx = allRuntime.TrafficSignalRuntime(i).SignalConfiguration.NumTurnConfiguration;

                    bulbColorEnum = allRuntime.TrafficSignalRuntime(i).SignalConfiguration.TurnConfiguration(turnConfigIdx-1).ConfigurationType;
                    if bulbColorEnum == EnumConfigurationType.Red || bulbColorEnum == EnumConfigurationType.Green || bulbColorEnum == EnumConfigurationType.Yellow
                        bulbColor = char(bulbColorEnum);
                    else
                        bulbColor = 'none';
                    end
                    % Update Traffic Signal Plot
                    hSignal = findobj(obj.SceneAxes,'Type','line','Tag',num2str(signalActorID));
                    if ~isempty(hSignal)
                        hSignal.MarkerFaceColor = bulbColor;
                        signalTabInfo{i,1} = signalActorID;
                        signalTabInfo{i,2} = bulbColor;
                        signalTabInfo{i,3} = allRuntime.TrafficSignalRuntime(i).SignalConfiguration.TurnConfiguration(turnConfigIdx).TimeLeft;
                        signalTabInfo{i,4} = sprintf('%s, %s',char(allRuntime.TrafficSignalRuntime(i).SignalConfiguration.TurnConfiguration(turnConfigIdx-1).TurnType),...
                            char(allRuntime.TrafficSignalRuntime(i).SignalConfiguration.TurnConfiguration(turnConfigIdx).TurnType));
                    end
                end
                obj.UITabTrafficSignalRuntime.Data = signalTabInfo;

                % Update ego signal head runtime information
                allSignalActorID = arrayfun(@(x) double(x.ActorRuntime.ActorID), allRuntime.TrafficSignalRuntime);
                egoRuntimeIdx = find(allSignalActorID == obj.EgoSignalID);
                egoBulbColor = char(allRuntime.TrafficSignalRuntime(egoRuntimeIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx-1).ConfigurationType);
                egoSignalTabInfo = cell(1,1);
                egoSignalTabInfo{1,1} = obj.EgoControllerID;
                egoSignalTabInfo{2,1} = obj.EgoSignalID;
                egoSignalTabInfo{3,1} = egoBulbColor;
                egoSignalTabInfo{4,1} = allRuntime.TrafficSignalRuntime(egoRuntimeIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx).TimeLeft;
                egoSignalTabInfo{5,1} = sprintf('%s, %s',char(allRuntime.TrafficSignalRuntime(egoRuntimeIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx-1).TurnType),...
                    char(allRuntime.TrafficSignalRuntime(egoRuntimeIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx).TurnType));
                if distToStop ~= -1
                    egoSignalTabInfo{6,1} = sprintf('%.2f',distToStop);
                else
                    egoSignalTabInfo{6,1} = sprintf('%s',"No Junction Ahead");
                end
                obj.UITabEgoSignal.Data = egoSignalTabInfo;

                removeStyle(obj.UITabEgoSignal);
                switch lower(egoBulbColor)
                    case 'green'
                        addStyle(obj.UITabEgoSignal,obj.GreenStyle,"cell",[3,1]);
                    case 'yellow'
                        addStyle(obj.UITabEgoSignal,obj.YellowStyle,"cell",[3,1]);
                    case 'red'
                        addStyle(obj.UITabEgoSignal,obj.RedStyle,"cell",[3,1]);
                end


                % Display vehicles
                egoPos = zeros(1,2);
                for i = 1:obj.NumVehicles
                    id   = allVehicleRuntime(i).ActorRuntime.ActorID;
                    pose = allVehicleRuntime(i).ActorRuntime.Pose;

                    if id==obj.EgoID
                        egoPos = [pose(1,4) pose(2,4)];
                    end

                    k = find(obj.VehicleIDs==id);

                    bbx = obj.VehicleSpec(k).BoundingBox;
                    v = [bbx.Min(1) bbx.Min(1) bbx.Max(1) bbx.Max(1) bbx.Min(1); ...
                        bbx.Min(2) bbx.Max(2) bbx.Max(2) bbx.Min(2) bbx.Min(2); ...
                        0 0 0 0 0; ...
                        1 1 1 1 1];
                    xydata = pose*v;

                    % Plot the patch
                    obj.AllActorPatch{k}.XData = xydata(1,1:4);
                    obj.AllActorPatch{k}.YData = xydata(2,1:4);
                end

                % Auto Zoom in/out depending on ego position
                adjustView(obj,egoPos);
            end
        end

        %% Simulink Admin Functions 
        function icon = getIconImpl(obj)
            % Define icon for System block
            icon = [mfilename("class")," "," "," "];
        end

        function sts = getSampleTimeImpl(obj)
            % Example: specify discrete sample time
            sts = obj.createSampleTime("Type", "Discrete","SampleTime", obj.Ts);
        end

        function interface = getInterfaceImpl(~)
            import matlab.system.interface.*;
            in6 = Input("in6", Data);
            in1 = Input("in1", Message);
            in2 = Input("in2", Message);
            in3 = Input("in3", Message);
            in4 = Input("in4", Message);
            in5 = Input("in5", Message);
            interface = [in6, in1, in2, in3, in4, in5];
        end
    end

    methods(Access=private)
        function adjustView(obj,egoPos)
            % adjustView adjusts the scene limit based on the ego vehicle and
            % traffic constroller position.

            % Distance between ego position and traffic signal controller
            dist = norm(obj.EgoSignalPos(1:2)-egoPos);

            % Determine the offset based on the distance
            if dist < 25
                offset = 30;
            elseif dist < 60
                offset = 70;
            else
                offset = 100;
            end

            % Set the limits based on the calculated offset
            obj.SceneAxes.XLim = [obj.EgoSignalPos(1)-offset, obj.EgoSignalPos(1)+offset];
            obj.SceneAxes.YLim = [obj.EgoSignalPos(2)-offset, obj.EgoSignalPos(2)+offset];
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
    end
end
