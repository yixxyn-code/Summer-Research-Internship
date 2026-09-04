classdef Debug < matlab.System
    % untitled Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a System object.

    % Public, tunable properties
    properties

    end

    % Pre-computed constants or internal states
    properties (Access = private)

    end




    methods (Access = protected)
        function interface = getInterfaceImpl(~)
            import matlab.system.interface.*;
            in1 = Input("in1", Message);   % controllerRuntime
            in2 = Input("in2", Message);   % controllerSpec
            interface = [in1, in2];
        end

        function stepImpl(obj, controllerRuntime, controllerSpec)
            % your controllerID extraction logic here
            allControllerActorID = arrayfun(@(x) double(x.ActorSpec.ActorID), controllerSpec);
            cntlIdx = find(allControllerActorID == obj.EgoControllerID);
            fprintf('numel(controllerSpec) = %d\n', numel(controllerSpec));
            fprintf('Looking for EgoControllerID=%d\n', obj.EgoControllerID);
            fprintf('Available controller IDs: %s\n', mat2str(allControllerActorID));
            fprintf('cntlIdx = %d\n', cntlIdx);
            % ...
        end
    end


end

