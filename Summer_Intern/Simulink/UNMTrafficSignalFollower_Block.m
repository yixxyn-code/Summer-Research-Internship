classdef UNMTrafficSignalFollower_Block < matlab.System
 
    properties (Access = private)   
        EgoControl % -1(STOP/BRAKE), 0(NOACTION/STEADY SPEED), 1(START/ACCELERATE) 
        StopLineThreshold = 2; %Stop 2m before the stopline 
        Velocity
    end

    properties(Nontunable)
        % Deceleration value to stop (m/s^2)
        Decel = 2;

        % Acceleration value to start (m/s^2)
        Accel = 1;

        % Target speed to start (m/s)
        TargetSpeed = 3;

        % Sample time (sec)
        Ts = 0.1;              
    end

    methods(Access = protected)
        function setupImpl(obj)
            % Initialize ego control to zero (NOACTION).
            obj.EgoControl = 0;  
        end

       %% Runs every timestep 
        function speed = stepImpl(obj,egoPose,signalState,timeLeft,distToStop)

            % Get current speed
            obj.Velocity = egoPose.ActorRuntime.Velocity; 
            speed = norm(obj.Velocity);
            %norm(): Convert X/Y/Z velocity component to single speed value
            %(i.e. vector magnitude/Euclidean length) 

            % Calculate distance to stop
            distToStop = max(0,distToStop - obj.StopLineThreshold);
            %Subtract 2m frm dist to stopline, max() compares ans with zero : prevents -ve value

            % Calculate time to stop line
            if speed == 0
                % Set timeToStop to infinity as stopping time is undefined
                % at zero speed.
                timeToStop = Inf; 
            else
                timeToStop = distToStop / speed;
            end
 
            % Initialize start and stop action.
            stopAction  = false;
            startAction = false;

            if distToStop>0 && speed>1e-5 % ego is moving toward junction
                switch signalState % traffic bulb color associated with ego
                    case EnumConfigurationType.Red
                        if timeLeft > timeToStop % red light stays when ego vehcile reaches the stop line
                            stopAction = true; % then, stop in advance
                        end
                    case {EnumConfigurationType.Green, EnumConfigurationType.Yellow,EnumConfigurationType.Permitted}
                        if timeLeft < timeToStop % green or yellow light will be expired when ego vehcile reaches the stop line
                            stopAction = true; % then, stop in advance
                        end
                end
            end

            % If ego is currently stationary
            if speed<1e-5 
                if signalState == EnumConfigurationType.Green || signalState == EnumConfigurationType.Permitted % and, green light
                    startAction = true; % then, start to move
                end
            end

          fprintf(' stopAction=%d | startAction=%d\n', stopAction, startAction);

            % Check conditions for taking control action
            if startAction && (obj.EgoControl == 0)  % need to start?
                obj.EgoControl = 1; % take action to accel to start
            end

            if stopAction && (obj.EgoControl == 0) % need to stop?
                brakeDistance = (speed)^2/(2*obj.Decel); % braking distance at decel(Kinematics formula)
                  % At low speeds brakeDistance is near zero so use minimum threshold
                brakeTriggerDist = max(brakeDistance, obj.StopLineThreshold + 2);
        fprintf('brakeDistance %d',brakeTriggerDist);

                if distToStop <= brakeTriggerDist % if distance 2 stop is equal or less than braking distance
                    obj.EgoControl = -1; % take action to brake to stop
                end
            end

            % Change ego speed depending on required action
            switch obj.EgoControl
                case -1 % If required action is STOP
                    [speed,release] = decelToStop(obj,speed); % reduce speed until stop

                    if release % when speed becomes zero
                        obj.EgoControl = 0; % back to NOACTION
                    end
                case 1 % If required action is START
                    [speed,release] = accelToStart(obj,speed); % increase speed until target speed

                    if release % when speed reach to target speed
                        obj.EgoControl = 0; % back to NOACTION 
                    end
            end

            % DEBUG - add these lines:
    fprintf('\n=== Follower Debug ===\n');
    fprintf('speed=%.3f | distToStop=%.3f | timeToStop=%.3f\n', speed, distToStop, timeToStop);
    fprintf('signalState=%s | timeLeft=%.1f\n', char(signalState), timeLeft);
    fprintf('EgoControl=%d\n', obj.EgoControl);
  

        end       
        %%-----------------------------------------------------------------
        % Breaking function 
        function [speed,release] = decelToStop(obj,currSpeed)
            speed = currSpeed - obj.Decel*obj.Ts; 
            if speed <= 0
                speed = 0;
                release = true;
            else
                release = false;
            end
        end
        %%-----------------------------------------------------------------
        % Acceleration function 
        function [speed,release] = accelToStart(obj,currSpeed)
            speed = currSpeed + obj.Accel*obj.Ts;
            if speed >= obj.TargetSpeed
                speed = obj.TargetSpeed;
                release = true;
            else
                release = false;
            end
        end
        %%-----------------------------------------------------------------
        % Simulink Admin Functions 
        function speed = getOutputSizeImpl(obj) %#ok<MANU>
            % Return size for each output port
            speed = [1 1];
        end
        
        function speed = getOutputDataTypeImpl(obj) %#ok<MANU>
            % Return data type for each output port
            speed = 'double';
        end
        
        function speed = isOutputComplexImpl(obj) %#ok<MANU>
            % Return true for each output port with complex data
            speed = false;            
        end
        
        function speed = isOutputFixedSizeImpl(obj) %#ok<MANU>
            % Return true for each output port with fixed size
            speed = true;
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
    end
end
