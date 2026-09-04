%Test
env = SurrogateTrafficEnv;
obs = reset(env);
disp(obs)   % should print 9 numbers, all finite
for i = 1:20
    [obs, reward, isDone, ~] = step(env, 0.5);
    fprintf('step %d: reward=%.3f isDone=%d\n', i, reward, isDone);
    if isDone, break; end
end

% Obtain observations and actions
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);
obsDim = obsInfo.Dimension(1);   % should be 9
actDim = actInfo.Dimension(1);   % should be 1

% Build critic and actor
criticNet = [
    featureInputLayer(obsDim, 'Name', 'obsIn')
    fullyConnectedLayer(64, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    fullyConnectedLayer(1, 'Name', 'value')
    ];
critic = rlValueFunction(criticNet, obsInfo);

commonPath = [
    featureInputLayer(obsDim, 'Name', 'obsIn')
    fullyConnectedLayer(64, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(64, 'Name', 'fc2')
    reluLayer('Name', 'relu2')
    ];
meanPath = [
    fullyConnectedLayer(actDim, 'Name', 'meanOut')
    tanhLayer('Name', 'tanh')
    scalingLayer('Name', 'scaledMean', 'Scale', 3, 'Bias', 0) % In the network: Scale=3, Bias=0 - now tanh_out=0 means action=0, genuinely neutral?
    ];
stdPath = [
    fullyConnectedLayer(actDim, 'Name', 'stdOut')
    softplusLayer('Name', 'std')
    ];
net = layerGraph(commonPath);
net = addLayers(net, meanPath);
net = addLayers(net, stdPath);
net = connectLayers(net, 'relu2', 'meanOut');
net = connectLayers(net, 'relu2', 'stdOut');

actor = rlContinuousGaussianActor(net, obsInfo, actInfo, ...
    'ActionMeanOutputNames', 'scaledMean', ...
    'ActionStandardDeviationOutputNames', 'std', ...
    'ObservationInputNames', 'obsIn');

agentOpts = rlPPOAgentOptions( ...
    'SampleTime', 0.1, ...
    'EntropyLossWeight', 0.01);   % encourages the policy to keep exploring instead of collapsing early
agent = rlPPOAgent(actor, critic,agentOpts);


trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 300, ...
    'MaxStepsPerEpisode', 300, ...
    'ScoreAveragingWindowLength', 20, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'SaveAgentCriteria', 'EpisodeReward', ...
    'SaveAgentValue', -400, ...              % save any agent scoring above this
    'SaveAgentDirectory', 'savedAgents');

trainingStats = train(agent, env, trainOpts);

figure;
plot(movmean(trainingStats.EpisodeReward, 20))
title('Smoothed training reward')
xlabel('Episode'); ylabel('Reward (20-episode moving average)')

save('trained_agent.mat', 'agent');

%% --- Evaluate the trained agent: run one episode and log everything ---
agent.UseExplorationPolicy = false;   % deterministic policy, no exploration noise

obs = reset(env);
maxSteps = 300;
log = repmat(struct('EgoPos',0,'EgoVel',0,'LeadPos',0,'RelDist',0, ...
    'PhaseState',0,'PhaseTimeLeft',0,'Reward',0), maxSteps, 1);

for t = 1:maxSteps
    action = getAction(agent, {obs});
    action = action{1};   % unwrap from cell

    [obs, reward, isDone, loggedSignals] = step(env, action);
    log(t) = loggedSignals;

    if isDone
        log = log(1:t);
        break
    end
end

%% --- Plot ego/lead position, speed, and signal state together ---
t = (1:numel(log))';
egoPos      = [log.EgoPos]';
egoVel      = [log.EgoVel]';
leadPos     = [log.LeadPos]';
phaseState  = [log.PhaseState]';

figure;
subplot(3,1,1)
plot(t, egoPos, 'b', t, leadPos, 'r--')
legend('Ego position', 'Lead position')
ylabel('Position (m)')
title('Trained agent rollout')

subplot(3,1,2)
plot(t, egoVel)
ylabel('Ego speed (m/s)')

subplot(3,1,3)
stairs(t, phaseState)
yticks([1 2 3]); yticklabels({'Red','Yellow','Green'})
ylabel('Signal state')
xlabel('Timestep')