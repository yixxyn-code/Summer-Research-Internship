%% Classify each signal violation as avoidable vs. dilemma-zone
% Run this AFTER evaluate_agent_outcomes.m, in the same workspace -
% it reuses allLogs and outcomes without rerunning any trials.

maxDecel = 3;   % matches your action lower bound (accel in [-3, 2])

avoidableCount = 0;
dilemmaZoneCount = 0;

for trial = 1:numTrials
    log = allLogs{trial};

    % Only trials classified as signal violations need checking
    lastPhase = log(end).PhaseState;
    lastRelDist = log(end).RelDist;
    ranFullLength = (numel(log) == maxsteps);
    isThisASignalViolation = ~ranFullLength && (lastRelDist >= 0) && ...
                              (lastPhase == 1 || lastPhase == 2);

    if ~isThisASignalViolation
        continue
    end

    % --- Find the first timestep where the signal is red or yellow ---
    % (either the trial started that way, or it transitioned mid-episode)
    phaseHistory = [log.PhaseState];
    firstRedOrYellowIdx = find(phaseHistory == 1 | phaseHistory == 2, 1, 'first');

    if isempty(firstRedOrYellowIdx)
        continue   % shouldn't happen if isThisASignalViolation is true, but guard anyway
    end

    % --- Kinematic feasibility check at that exact moment ---
    egoVelAtTransition = log(firstRedOrYellowIdx).EgoVel;
    egoPosAtTransition = log(firstRedOrYellowIdx).EgoPos;
    distToStopAtTransition = env.StopLinePos - egoPosAtTransition;

    requiredStopDist = egoVelAtTransition^2 / (2*maxDecel);
    wasAvoidable = distToStopAtTransition >= requiredStopDist;

    if wasAvoidable
        avoidableCount = avoidableCount + 1;
        fprintf('Trial %2d: AVOIDABLE violation (at transition: dist=%.1fm, needed=%.1fm, speed=%.1fm/s)\n', ...
            trial, distToStopAtTransition, requiredStopDist, egoVelAtTransition);
    else
        dilemmaZoneCount = dilemmaZoneCount + 1;
        fprintf('Trial %2d: DILEMMA-ZONE violation (at transition: dist=%.1fm, needed=%.1fm, speed=%.1fm/s)\n', ...
            trial, distToStopAtTransition, requiredStopDist, egoVelAtTransition);
    end
end

fprintf('\n=== Violation breakdown (%d total signal violations) ===\n', outcomes.signalViolation);
fprintf('Avoidable (policy could have stopped):   %d\n', avoidableCount);
fprintf('Dilemma-zone (physically unwinnable):    %d\n', dilemmaZoneCount);