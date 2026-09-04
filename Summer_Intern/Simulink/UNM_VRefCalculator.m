classdef UNM_VRefCalculator < matlab.System
    % Computes the velocity error e = vRef - egoVel, folding both
    % car-following (relDist/leadVel) and signal compliance (distToStop/
    % signalState) into a single reference velocity, matching
    % SurrogateTrafficEnvACC's Vref logic exactly.

    properties(Nontunable)
        D_default = 25;
        t_gap = 1.4;
        v_set = 8;
    end

    methods (Access = protected)
        function e = stepImpl(obj, distToStop, signalState, relDist, leadVel, egoVel, latchedInJunction)
            isRed    = (signalState == EnumConfigurationType.Red);
            isYellow = (signalState == EnumConfigurationType.Yellow);

            safeDistance = obj.t_gap*egoVel + obj.D_default;
            if relDist < safeDistance
                vRefGap = min(leadVel, obj.v_set);
            else
                vRefGap = obj.v_set;
            end

            % add a temporary fprintf inside VRefCalculator's stepImpl, right after computing vRefGap:
            fprintf('leadVel input=%.2f, egoVel=%.2f, relDist=%.2f, vRefGap=%.2f\n', leadVel, egoVel, relDist, vRefGap);

            if (isRed || isYellow) && distToStop >= 0 && ~latchedInJunction
                safeDistanceToLine = obj.t_gap*egoVel + obj.D_default;
                if distToStop < safeDistanceToLine
                    vRefSignal = 0;
                else
                    vRefSignal = obj.v_set;
                end
            else
                vRefSignal = obj.v_set;
            end

            vRef = min(vRefGap, vRefSignal);
            e = vRef - egoVel;
        end

        %% Simulink Admin Functions
        function sz = getOutputSizeImpl(~)
            sz = [1 1];
        end
        function dt = getOutputDataTypeImpl(~)
            dt = 'double';
        end
        function cp = isOutputComplexImpl(~)
            cp = false;
        end
        function fz = isOutputFixedSizeImpl(~)
            fz = true;
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Interpreted execution";
        end
    end
end