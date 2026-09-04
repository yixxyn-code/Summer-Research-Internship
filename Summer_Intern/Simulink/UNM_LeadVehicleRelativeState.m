classdef UNM_LeadVehicleRelativeState < matlab.System
    % LeadVehicleRelativeState - computes relDist/leadVel purely from two
    % pose bus inputs (egoPose, leadPose), both sourced from RoadRunner
    % Scenario Reader blocks. No live ActorSimulation handles, no
    % Simulink.ScenarioSimulation.find() calls, no setupImpl/releaseImpl
    % needed - this block never touches RoadRunner's interop API directly.

    methods (Access = protected)
        function [relDist, leadVel] = stepImpl(obj, egoPose, leadPose)
            egoPos  = egoPose.ActorRuntime.Pose(1:3,4)';
            leadPos = leadPose.ActorRuntime.Pose(1:3,4)';

            leadVel = norm(leadPose.ActorRuntime.Velocity);

            % Simple version - straight-line distance. Upgrade to
            % path-projected arc length later if curves distort this.
            relDist = norm(leadPos - egoPos);
        end

        function [sz1, sz2] = getOutputSizeImpl(~)
            sz1 = [1 1]; 
            sz2 = [1 1];
        end

        function [dt1, dt2] = getOutputDataTypeImpl(~)
            dt1 = 'double'; 
            dt2 = 'double';
        end

        function [cp1, cp2] = isOutputComplexImpl(~)
            cp1 = false; 
            cp2 = false;
        end

        function [fz1, fz2] = isOutputFixedSizeImpl(~)
            fz1 = true; 
            fz2 = true;
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Interpreted execution";
        end
    end
end