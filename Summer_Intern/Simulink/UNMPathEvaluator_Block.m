classdef UNMPathEvaluator_Block < matlab.System

    % Pre-computed constants
    properties(Access = private)
        Distance = 0 % Tracks total distance travelled so far, initialize to 0
    end

    methods(Access = protected)
       %% Runs each timestep 
        function [posX, posY, posZ, yaw, routeDistance, routeFinished] = stepImpl(obj, polyline, polylineLength, timestep, speed)
            % Calculate vehicle pose and distance travelled using polyline
            % from RoadRunner Scenario and speed
            targetDistance = obj.Distance + speed * timestep;
            polylineLength=double(polylineLength);
            previousDistance = 0;
            cumulativeDistance = 0;
            previousPointIndex = 0;
            nextPointIndex = 0;
            foundDistance = false;
            
            for idx = 2:polylineLength  % Walk thru every waypoints (Starts frm idx 2 cz calc distance btw 2 points)
                previousDistance = cumulativeDistance;
                cumulativeDistance = cumulativeDistance + norm(polyline(idx, :) - polyline(idx-1, :));
                % Keep adding up the distance btw 2 waypoints 
                
                % Find vehicle location between which 2 waypoints 
                if cumulativeDistance > targetDistance
                    previousPointIndex = idx - 1;
                    nextPointIndex = idx;
                    
                    obj.Distance = targetDistance;
                    foundDistance = true;
                    break;
                end
            end
            
            % Check for end of route: if walked thru all waypoints, not
            % found target distance = end of path 
            if ~foundDistance
                obj.Distance = cumulativeDistance;
                nextPointIndex = polylineLength;
                previousPointIndex = nextPointIndex - 1;
                routeFinished = true;
            else
                routeFinished = false;
            end
            
            %% Interpolate exact position 
            previousPoint = polyline(previousPointIndex, :);
            nextPoint = polyline(nextPointIndex, :);
            
            %    prev pos   target pos
            %    |          |
            % *--O----*-----X---*----------*
            %         |     | 
            % --------- previousDistance
            % --------------- target distance
            % 
            % s will be the parametric distance between previousPoint and
            % nextPoint (values 0 to 1 : ratio/%) 
            % s= (previous dist to a certain waypoint to target distance)/ (distance between 2 waypoints) 
            % e.g. s= 3/5 =0.6 = 60% of way point 1 to 2
            %
            s = (obj.Distance - previousDistance) / norm(nextPoint - previousPoint);
           
            % Previous position + how far along frm that point go = Actual
            % position
            interpolatedPosition = previousPoint + s * (nextPoint - previousPoint);

            % Vehicle orientation : unit vector in that direction of vector
            % (unit vect= vector/ magnitdue)
            tangent = (nextPoint - previousPoint)/ norm(nextPoint - previousPoint);
            
            % Blend tangents for smooth turning 
            % When s = 0 (just left previous waypoint) → tangent is 100% current direction
            % When s = 0.5 (halfway) → tangent is 50% current + 50% next direction
            % When s = 1 (arriving at next waypoint) → tangent is 100% next direction
            %
            % Waypoint A ————→————→————↗————↗ Waypoint B ↗↗↗ Waypoint C
            %           purely →        gradually rotating        purely ↗
            %
            if nextPointIndex <= polylineLength - 1 % If not end of path 
                nextNextPoint = polyline(nextPointIndex + 1, :); 
                nextTangent = (nextNextPoint - nextPoint)/norm(nextPoint - previousPoint); 
                tangent = tangent + s *(nextTangent - tangent); % Blend current and next tangent 
                tangent = tangent / norm(tangent); % Renormalize to unit vector 
            end
            
            % Setting this to the RoadRunner traffic coordinate
            % system.(o/p)
            % - y : forward
            % - x : right
            % - z : up
            yaw = -atan2(tangent(1), tangent(2)); % -atan2 convert direction vect to rotation angle (rad) in RR coordinates convention
            posX = interpolatedPosition(1);
            posY = interpolatedPosition(2);
            posZ = interpolatedPosition(3);
            routeDistance = obj.Distance;
        end
    end
end
