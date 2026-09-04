classdef UNM_RLRewardFcn < matlab.System
    % NOTE: This block is used during DEPLOYMENT only, as a real-time
    % collision/signal-violation monitor feeding a Stop Simulation block.
    % It does NOT reflect the reward function used to train the deployed
    % agent - that was SurrogateTrafficEnvACC's ACC-style reward
    % (-(0.1*e^2 + prevAccel^2) + M, plus a -50 signal violation penalty).
    % See train_ACC_agent.m for the actual training reward.
    
    properties(Nontunable)
        DesiredGap = 10;      % target following distance, meters
        CollisionGap = 1.5;   % relDist below this = crash
        SignalViolationPenalty = 100;
        CollisionPenalty = 100;
        GapWeight = 0.01;
        JerkWeight = 0.05;
        SpeedWeight = 0.05;
    end

    properties(Access = private)
        PrevAccel = 0;
    end

    methods(Access = protected)
        function setupImpl(obj)
            obj.PrevAccel = 0;
        end

        function [reward, isDone] = stepImpl(obj, distToStop, signalState, relDist, egoVel, accelCmd,latchedInJunction,isJunctionRelevant)
            isRed    = (signalState == EnumConfigurationType.Red);
            isYellow = (signalState == EnumConfigurationType.Yellow);

            violatedSignal = isJunctionRelevant && (distToStop <= 0) && (isRed || isYellow) && ~latchedInJunction;
            collided = relDist <= obj.CollisionGap;

            reward = 0;
            isDone = false;

            if violatedSignal
                reward = reward - obj.SignalViolationPenalty;
                isDone = true;
                fprintf('[t=%.2f] TERMINATED: signal violation (distToStop=%.2f, signalState=%s)\n', ...
            obj.getCurrentTime(), distToStop, char(signalState));

            elseif collided
                reward = reward - obj.CollisionPenalty;
                isDone = true;
                fprintf('[t=%.2f] TERMINATED: collision (relDist=%.2f, CollisionGap=%.2f)\n', ...
            obj.getCurrentTime(), relDist, obj.CollisionGap);

            else
                gapError = min(abs(relDist - obj.DesiredGap), 20);   % cap at 20m of error
                jerk = accelCmd - obj.PrevAccel;

                reward = reward ...
                    - obj.GapWeight  * gapError^2 ...
                    - obj.JerkWeight * jerk^2 ...
                    + obj.SpeedWeight * egoVel;
            end

            obj.PrevAccel = accelCmd;
        end

        %% Simulink Admin Functions 
        function [sz1, sz2] = getOutputSizeImpl(~)
            sz1 = [1 1]; sz2 = [1 1];
        end
        function [dt1, dt2] = getOutputDataTypeImpl(~)
            dt1 = 'double'; dt2 = 'boolean';
        end
        function [cp1, cp2] = isOutputComplexImpl(~)
            cp1 = false; cp2 = false;
        end
        function [fz1, fz2] = isOutputFixedSizeImpl(~)
            fz1 = true; fz2 = true;
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Interpreted execution";
        end
    end
end