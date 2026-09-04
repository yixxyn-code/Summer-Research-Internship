classdef UNM_TrafficSignalV2 < matlab.System
    %HelperGetTrafficSignal Extracts the signal state for the given signal ID.
    % From all traffic signal runtime information, this system object filters
    % out the traffic signal runtime information for the given traffic signal
    % actor id.
    %
    % NOTE: This is a helper file for example purposes and
    % may be removed or modified in the future.

    % Copyright 2024 The MathWorks, Inc.

    % Public, tunable properties
    properties(Nontunable)
        % Approaching Signal ID
        SignalID = 9;
        % Ego Actor ID
        EgoID = 1;
        % RoadRunner HD Map
        RRHDMap = roadrunnerHDMap;
    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Ego actor simulation object
        EgoActorSim
        % All lane ID's
        AllLaneID
        % All junction lane ID's
        JunctionLaneID
        % RoadRunner Simulation Object
        RRSimObj
        %NEWWW
        SignalJuncIdx 
    end

    methods (Access = protected)
        %% Runs once at simulation start
        function setupImpl(obj)
            % Get the RoadRunner Scenario Simulation object
            obj.RRSimObj = Simulink.ScenarioSimulation.find('ScenarioSimulation', 'SystemObject', obj);

            % Retrieve the ActorSimulation object from rrSim
            actorSim = obj.RRSimObj.get("ActorSimulation");

            % Extract the "ID" attribute for each actor in the simulation
            allActorID = cellfun(@(c) c.getAttribute("ID"), actorSim);
            %cellfun(funct,arr)-apply funct to each cell of the cell
            %array(=arr that each cell containes mixed type elements)
            %@(c)...is an anonymous funct, "." is dot operator that applies funct to each celL

            % Ego Actor idx
            idx = allActorID == obj.EgoID;

            % Ego Actor Simulation object
            obj.EgoActorSim = actorSim{idx};

            %Pre-load all lanes and junction data frm HD Map
            % All lane ID
            obj.AllLaneID = string(vertcat(obj.RRHDMap.Lanes.ID));

            % Junction Lane ID
            obj.JunctionLaneID = arrayfun(@(jc) vertcat(jc.Lanes.ID),obj.RRHDMap.Junctions,'UniformOutput',false);
 
% Identify it by finding the largest junction (most lanes)
juncSizes = cellfun(@numel, obj.JunctionLaneID);
[~, obj.SignalJuncIdx] = max(juncSizes);
fprintf('Signal junction index: %d\n', obj.SignalJuncIdx);

        end

        %% Runs every timestep
        function [state, tLeft, distToStop] = stepImpl(obj,egoPose,pathAction,signalRuntime)
            % Initialize outputs (Default o/p if nothing found)
            state = EnumConfigurationType.Red;
            tLeft = 0;
            distToStop = -1;

            % For the given controller & signal ID find the bulb state and
            % time left
            allSignalActorID = arrayfun(@(x) double(x.ActorRuntime.ActorID), signalRuntime);
            signalIdx = find(allSignalActorID == obj.SignalID);

            if isempty(signalIdx)
                warning('UNM_TrafficSignalV2:stepImpl','No signalRuntime found for SignalID %d', obj.SignalID);
            else
                %%Get its current phase info (State colour? Tleft?)
                turnConfigIdx = signalRuntime(signalIdx).SignalConfiguration.NumTurnConfiguration;
                tLeft = signalRuntime(signalIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx).TimeLeft;
                state = signalRuntime(signalIdx).SignalConfiguration.TurnConfiguration(turnConfigIdx).ConfigurationType;
            end

            %% Find the distance to stop line
            %Get ego current lane position & which junction it's heading to
            egoLaneLoc = obj.EgoActorSim.getAttribute("LaneLocation");
            [~,juncIdx] = obj.getApproachingJunction(string(egoLaneLoc.LocationOnLane.LaneID));

            % Debugging info - display key variables to trace why distToStop remains -1
            fprintf('[UNM_TrafficSignalV2] Ego IsOnLane: %d, Ego LaneID: %s, ApproachingJunctionIdx: %d\n', ...
                double(egoLaneLoc.IsOnLane), string(egoLaneLoc.LocationOnLane.LaneID), juncIdx);

            if egoLaneLoc.IsOnLane && juncIdx ~= -1 % On lane and approaching a junction
                %Get the junction boundary
                region = obj.RRHDMap.Junctions(juncIdx).Geometry.Polygons.ExteriorRing;


                % Vehicle Path & Path points
                vehPath = pathAction.PathTarget.Path;
                numPts = pathAction.PathTarget.NumPoints;

                % Ego position
                egoPos = egoPose.ActorRuntime.Pose(1:3,4)';
               

  % NEW: if ego is already inside junction, skip distToStop computation
    if checkPointInsideRegion(obj, [egoPos(1), egoPos(2), egoPos(3)], region)
        distToStop = 0;
        fprintf('Ady in junct');
        return;
    end

                
        end


        %% Helper functions
        function [junctionUUID,juncIdx] = getApproachingJunction(obj,laneID)
            % getApproachingJunction finds the approaching junction ID based on
            % the current lane.
            % Initialize output
            junctionUUID = "";
            juncIdx = -1;

            % Get the current lane object
            matchIdx = ismember(obj.AllLaneID, string(laneID));
            if ~any(matchIdx)
                return;
            end
            currLane = obj.RRHDMap.Lanes(matchIdx);


            % Check if the the current lane is a junction lane. If so
            % update junctionUUID & return.
            [flag, juncIdx] = isJunctionLane(obj,laneID);
            if flag
                junctionUUID = obj.RRHDMap.Junctions(juncIdx).ID;
                return;
            end

            % If the current lane is not a junction lane find the
            % approaching junction along the direction of current lane.
            while ~flag
                % If travel direction is forward use successors or else use
                % predecessors to get the next lane.
                if currLane.TravelDirection == roadrunner.hdmap.TravelDirection.Forward
                    if ~isempty(currLane.Successors)
                        nxtLaneID = vertcat(currLane.Successors.Reference.ID);
                    else
                        break;
                    end
                else
                    if ~isempty(currLane.Predecessors)
                        nxtLaneID = vertcat(currLane.Predecessors.Reference.ID);
                    else
                        break;
                    end
                end
                % Check if the next lane is a junction lane.
                [flag, juncIdx] = isJunctionLane(obj,nxtLaneID);

                % If junction lane return the junction ID or else continue
                % till the end of road.
                if flag
                    junctionUUID = obj.RRHDMap.Junctions(juncIdx).ID;
                    break
                else

                    % idx = find(obj.AllLaneID == nxtLaneID);
                    idx = find(ismember(obj.AllLaneID, string(nxtLaneID)));
                    currLane = obj.RRHDMap.Lanes(idx);
                end
            end
        end

        function [flag, juncIdx] = isJunctionLane(obj,laneIDs)
            %isJunctionLane checks if the input lane ID belongs to the
            %junctions or not.
            flag = false;
            juncIdx = -1;
            numJun = numel(obj.JunctionLaneID);

            for i = 1:numJun
                currJuncLaneIDs = obj.JunctionLaneID{i};

                if nnz(ismember(laneIDs,currJuncLaneIDs,"rows")) > 0
                    flag = true;
                    juncIdx = i;
                    return;
                end
            end
        end



        function isInside = checkPointInsideRegion(~,point, region)
            %checkPointInsideRegion function checks if a given point is inside
            % or outside the given region (ray casting algorithm :check is this
            % point in this shape?)
            % Initialize counter for crossings
            crossings = 0;

            % Get the number of vertices of the region
            numVertices = size(region, 1);

            % Iterate over each pair of consecutive vertices
            for i = 1:numVertices
                % Get the current vertex and the next vertex
                vertex1 = region(i, :);
                vertex2 = region(mod(i, numVertices) + 1, :);

                % Check if the point lies on the same side of the line as the origin
                if (vertex1(2) > point(2)) ~= (vertex2(2) > point(2))
                    % Calculate the x-coordinate of the point where the line crosses the y-coordinate of the point
                    intersectionX = (vertex2(1) - vertex1(1)) * (point(2) - vertex1(2)) / (vertex2(2) - vertex1(2)) + vertex1(1);

                    % Check if the point lies to the right of the line
                    if point(1) < intersectionX
                        % Increment the counter for crossings
                        crossings = crossings + 1;
                    end
                end
            end

            % Check if the number of crossings is odd
            isInside = mod(crossings, 2) == 1;
        end

        %% Simulink Admin Functions
        function interface = getInterfaceImpl(~)
            %Define i/p & o/p ports
            import matlab.system.interface.*;
            in1 = Input("in1", Data);
            in2 = Input("in2", Data);
            in3 = Input("in3", Message);
            out1 = Output("out1",Data);
            out2 = Output("out2",Data);
            out3 = Output("out3",Data);
            interface = [in1, in2, in3, out1, out2, out3];
        end

        function [out1, out2, out3] = getOutputSizeImpl(obj)
            % Return size for each output port
            out1 = [1,1];
            out2 = [1 1];
            out3 = [1 1];
        end

        function [out1, out2, out3] = getOutputDataTypeImpl(obj)
            % Return data type for each output port
            out1 = "EnumConfigurationType";
            out2 = "double";
            out3 = "double";
        end

        function [out1, out2, out3] = isOutputComplexImpl(obj)
            % Tell Simulink that outputs are real numbers
            % Return true for each output port with complex data
            out1 = false;
            out2 = false;
            out3 = false;
        end

        function [out1, out2, out3] = isOutputFixedSizeImpl(obj)
            % Return true for each output port with fixed size
            out1 = true;
            out2 = true;
            out3 = true;
        end

        function icon = getIconImpl(obj)
            % Define icon for System block
            icon = [mfilename("class")," "," "," "];
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
    end
end
