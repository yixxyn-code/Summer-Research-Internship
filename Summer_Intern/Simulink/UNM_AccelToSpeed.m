classdef UNM_AccelToSpeed < matlab.System

    properties(Nontunable)
        Ts = 0.1;         % sample time (sec) - match your RL agent's step size
        MaxSpeed = 15;     % m/s, physical cap
    end

    methods(Access = protected)
        function speed = stepImpl(obj, egoPose, accelCmd)
            % Current speed, read back from RoadRunner - same pattern
            % the old block used, so no algebraic loop introduced.
            currSpeed = norm(egoPose.ActorRuntime.Velocity);

            % Integrate the RL agent's continuous acceleration command
            speed = currSpeed + accelCmd * obj.Ts;
            speed = min(max(speed, 0), obj.MaxSpeed);   % no reverse, cap top speed
        end

        % Keep these IDENTICAL to the old block's - same interface,
        % same downstream port, nothing else needs to change.
        function speed = getOutputSizeImpl(obj)
            speed = [1 1];
        end
        function speed = getOutputDataTypeImpl(obj)
            speed = 'double';
        end
        function speed = isOutputComplexImpl(obj)
            speed = false;
        end
        function speed = isOutputFixedSizeImpl(obj)
            speed = true;
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Interpreted execution";
        end
    end
end