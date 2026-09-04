classdef SurrogateTrafficEnvACC < rl.env.MATLABEnvironment
    % SurrogateTrafficEnvACC - built directly on MathWorks' "Train DDPG Agent
    % for Adaptive Cruise Control" example structure (3-element observation:
    % velocity error, integral of error, ego velocity). The traffic signal
    % is folded in as a *virtual stationary lead vehicle* at the stop line,
    % so no separate one-hot signal encoding or extra observation elements
    % are needed - Vref = min(gap-following target, signal-stopping target).
    %
    % Reward and termination conditions follow the MathWorks example almost
    % exactly: rt = -(0.1*e^2 + u_prev^2) + M, M=1 if e^2<=0.25.
    % Termination: EgoVel<0, relDist<0, OR crossing the stop line on red/yellow.

    properties
        Ts       = 0.1;
        Tf       = 60;      % seconds, matches example's episode length
        D_default = 25;     % standstill spacing, m
        t_gap     = 1.4;    % time gap, s
        v_set     = 8;      % driver-set cruising speed, m/s

        StopLinePos = 90;   % meters - matches your real MaxStopDistance scale
    end

    properties (Access = private)
        EgoPos
        EgoVel
        LeadPos
        LeadVel
        PhaseState       % 1=Red, 2=Yellow, 3=Green
        PhaseTimeLeft
        IntegralError
        PrevAccel
    end

    methods
        function obj = SurrogateTrafficEnvACC()
            %SURROGATETRAFFICENVACC - Construct surrogate ACC traffic environment
            %
            % Create a surrogate environment used for testing or simulation of
            % adaptive cruise control (ACC) + signal following behavior
            %
            % Output arguments:
            % obj - SurrogateTrafficEnvACC object instance (env)
            obsInfo = rlNumericSpec([3 1], ...
                'LowerLimit', -inf*ones(3,1), ...
                'UpperLimit',  inf*ones(3,1));
            obsInfo.Name = "observations";
            obsInfo.Description = "velocity error, integral of error, ego velocity";

            actInfo = rlNumericSpec([1 1], 'LowerLimit', -3, 'UpperLimit', 2);
            actInfo.Name = "acceleration";

            obj = obj@rl.env.MATLABEnvironment(obsInfo, actInfo);
        end

        function InitialObservation = reset(obj)
            %RESET - Reset environment and return initial observation
            %
            % Input arguments:
            % obj - environment object
            %
            % Output arguments:
            % InitialObservation - observation at start of episode
            obj.EgoPos = 10;
            obj.EgoVel = 20;
            obj.LeadPos = 40 + randi(60);   % matches example's randomized lead start
            obj.LeadVel = 25;
            obj.PhaseState = randi(3);
            switch obj.PhaseState
                case 1, obj.PhaseTimeLeft = 8 + 6*rand;
                case 2, obj.PhaseTimeLeft = 2 + 1*rand;
                case 3, obj.PhaseTimeLeft = 6 + 6*rand;
            end
            obj.IntegralError = 0;
            obj.PrevAccel = 0;

            InitialObservation = obj.buildObservation();
        end

        function [Observation, Reward, IsDone, LoggedSignals] = step(obj, Action)
            %STEP - Execute environment transition for given action
            %
            % Input arguments:
            % Action - action applied to the environment
            %
            % Output arguments:
            % Observation     - new observation after action
            % Reward          - scalar reward received
            % IsDone          - boolean termination flag
            % LoggedSignals   - struct of auxiliary logging data
            accel = min(max(Action, -3), 2);

            % --- integrate, NO clamp at zero - matches the example exactly.
            % This is deliberate: clamping created a "free" region where
            % further braking had zero physical effect, which is what let
            % earlier versions collapse to "stop and never resume." Here,
            % going negative just ends the episode, which is a real signal.
            obj.EgoVel = obj.EgoVel + accel*obj.Ts;
            obj.EgoPos = obj.EgoPos + obj.EgoVel*obj.Ts;
            obj.LeadPos = obj.LeadPos + obj.LeadVel*obj.Ts;

            obj.PhaseTimeLeft = obj.PhaseTimeLeft - obj.Ts;
            if obj.PhaseTimeLeft <= 0
                obj.PhaseState = mod(obj.PhaseState, 3) + 1;
                switch obj.PhaseState
                    case 1, obj.PhaseTimeLeft = 8 + 6*rand;
                    case 2, obj.PhaseTimeLeft = 2 + 1*rand;
                    case 3, obj.PhaseTimeLeft = 6 + 6*rand;
                end
            end
            isRed    = (obj.PhaseState == 1);
            isYellow = (obj.PhaseState == 2);

            relDist = obj.LeadPos - obj.EgoPos;
            distToStop = obj.StopLinePos - obj.EgoPos;

            % --- Vref from car-following (exactly the example's formula: ACC) ---
            safeDistance = obj.t_gap*obj.EgoVel + obj.D_default;
            if relDist < safeDistance
                vRefGap = min(obj.LeadVel, obj.v_set);
            else
                vRefGap = obj.v_set;
            end

            % --- Vref from the signal, treating the stop line as a
            % stationary "lead vehicle" using the SAME formula above ---
            if (isRed || isYellow) && distToStop >= 0
                safeDistanceToLine = obj.t_gap*obj.EgoVel + obj.D_default;
                if distToStop < safeDistanceToLine
                    vRefSignal = 0;   % stationary "lead vehicle" -> min(0, v_set) = 0
                else
                    vRefSignal = obj.v_set;
                end
            else
                vRefSignal = obj.v_set;   % green, or already past the line - unconstrained
            end

            vRef = min(vRefGap, vRefSignal);
            e = vRef - obj.EgoVel;
            obj.IntegralError = obj.IntegralError + e*obj.Ts;

            % --- reward, exactly the example's formula ---
            M = double(e^2 <= 0.25);
            Reward = -(0.1*e^2 + obj.PrevAccel^2) + M;

            % --- termination, example's two conditions plus signal violation ---
            crossedOnRedOrYellow = (distToStop < 0) && (isRed || isYellow) ...
                && ((distToStop + obj.EgoVel*obj.Ts) >= 0); % crossed this step
            IsDone = (obj.EgoVel < 0) || (relDist < 0) || crossedOnRedOrYellow;

            if crossedOnRedOrYellow
                Reward = Reward - 100;   % explicit, dominant penalty - not currently present at all
            end

            obj.PrevAccel = accel;
            LoggedSignals = struct('EgoPos', obj.EgoPos, 'EgoVel', obj.EgoVel, ...
                'LeadPos', obj.LeadPos, 'RelDist', relDist, ...
                'PhaseState', obj.PhaseState, 'Vref', vRef, 'Reward', Reward);

            Observation = obj.buildObservation();
        end
    end

    %% Function definition
    methods (Access = private)
        function obs = buildObservation(obj)
            % recompute e for the CURRENT state, consistent with buildObservation
            % being called both at reset (no accel applied yet) and after step
            relDist = obj.LeadPos - obj.EgoPos;
            distToStop = obj.StopLinePos - obj.EgoPos;
            isRed    = (obj.PhaseState == 1);
            isYellow = (obj.PhaseState == 2);

            safeDistance = obj.t_gap*obj.EgoVel + obj.D_default;
            vRefGap = obj.v_set;
            if relDist < safeDistance
                vRefGap = min(obj.LeadVel, obj.v_set);
            end

            vRefSignal = obj.v_set;
            if (isRed || isYellow) && distToStop >= 0
                safeDistanceToLine = obj.t_gap*obj.EgoVel + obj.D_default;
                if distToStop < safeDistanceToLine
                    vRefSignal = 0;
                end
            end

            vRef = min(vRefGap, vRefSignal);
            e = vRef - obj.EgoVel;

            obs = [e; obj.IntegralError; obj.EgoVel];
        end
    end
end