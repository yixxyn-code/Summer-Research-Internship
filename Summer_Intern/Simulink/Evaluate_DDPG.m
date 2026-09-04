%% Evaluate trained agent over many rollouts and classify outcomes
% Run this AFTER training and saving your agent (trained_agent_ACC.mat).
% Reports how often the agent completes cleanly vs. collides vs. runs a
% red/yellow light - a single rollout plot can't tell you this reliably.

load('trained_agent_ACC.mat', 'agent');
agent.UseExplorationPolicy = false;   % deterministic policy, no exploration noise

env = SurrogateTrafficEnvACC;
maxsteps = ceil(env.Tf / env.Ts);     % 600 steps, matches training episode length

numTrials = 30;
outcomes = struct('signalViolation', 0, 'collision', 0, 'completed', 0, 'other', 0);

% Keep the full log of each trial in case you want to inspect specific
% failures afterward (e.g. plot the worst signalViolation case).
allLogs = cell(numTrials, 1);

for trial = 1:numTrials
    obs = reset(env);
    log = repmat(struct('EgoPos',0,'EgoVel',0,'LeadPos',0,'RelDist',0, ...
        'PhaseState',0,'Vref',0,'Reward',0), maxsteps, 1);

    finalStep = maxsteps;
    for t = 1:maxsteps
        action = getAction(agent, {obs});
        action = action{1};

        [obs, reward, isDone, loggedSignals] = step(env, action);
        log(t) = loggedSignals;

        if isDone
            finalStep = t;
            break
        end
    end
    log = log(1:finalStep);
    allLogs{trial} = log;

    % --- Classify the outcome using the SAME conditions the environment
    % itself uses internally, rather than re-guessing from the reward shape ---
    lastRelDist = log(end).RelDist;
    lastEgoVel  = log(end).EgoVel;
    lastPhase   = log(end).PhaseState;   % 1=Red, 2=Yellow, 3=Green
    ranFullLength = (finalStep == maxsteps);

    isRedOrYellow = (lastPhase == 1) || (lastPhase == 2);
    collidedThisTrial = (lastRelDist < 0);
    % A trial that ended early, wasn't a collision, and ended on red/yellow
    % with the vehicle still moving forward is almost certainly the
    % crossedOnRedOrYellow condition from step() - not velocity<0 either.
    signalViolationThisTrial = ~ranFullLength && ~collidedThisTrial && ...
        isRedOrYellow && (lastEgoVel >= 0);

    if ranFullLength
        outcomes.completed = outcomes.completed + 1;
    elseif collidedThisTrial
        outcomes.collision = outcomes.collision + 1;
    elseif signalViolationThisTrial
        outcomes.signalViolation = outcomes.signalViolation + 1;
    else
        % Caught by EgoVel<0 (braked into negative velocity) or an
        % ambiguous case - inspect allLogs{trial} manually if this count
        % is nonzero and you want to know exactly what happened.
        outcomes.other = outcomes.other + 1;
    end

    fprintf('Trial %2d: %3d steps, final relDist=%.2f, final egoVel=%.2f, phase=%d -> %s\n', ...
        trial, finalStep, lastRelDist, lastEgoVel, lastPhase, ...
        classifyLabel(ranFullLength, collidedThisTrial, signalViolationThisTrial));
end

%% Summary
fprintf('\n=== Results over %d trials ===\n', numTrials);
fprintf('Completed cleanly:  %d (%.0f%%)\n', outcomes.completed, 100*outcomes.completed/numTrials);
fprintf('Collisions:         %d (%.0f%%)\n', outcomes.collision, 100*outcomes.collision/numTrials);
fprintf('Signal violations:  %d (%.0f%%)\n', outcomes.signalViolation, 100*outcomes.signalViolation/numTrials);
fprintf('Other/unclassified: %d (%.0f%%)\n', outcomes.other, 100*outcomes.other/numTrials);

figure;
bar(categorical({'Completed','Collision','Signal Violation','Other'}), ...
    [outcomes.completed, outcomes.collision, outcomes.signalViolation, outcomes.other]);
ylabel('Number of trials');
title(sprintf('Rollout outcomes over %d trials', numTrials));

function label = classifyLabel(completed, collided, violated)
if completed
    label = 'COMPLETED';
elseif collided
    label = 'COLLISION';
elseif violated
    label = 'SIGNAL VIOLATION';
else
    label = 'OTHER (check log)';
end
end