# UNM Traffic Signal Follower — Summer Research Internship

Reinforcement learning-based controller for a single ego vehicle that must simultaneously
(1) comply with a traffic signal and (2) maintain a safe following distance behind a lead
vehicle, developed as part of a digital twin of the UNM campus front junction.

## Environment

- MATLAB R2025b, Simulink R2025b, Reinforcement Learning Toolbox, Automated Driving Toolbox 
- RoadRunner R2026a

## Repository structure

```
Summer_Intern/
├── UNM_FrontJunct-V2.rrscene        RoadRunner scene: reconstructed UNM junction
├── UNM_Eg-Test2.rrscenario          RoadRunner scenario (ego + lead vehicle, signal)
├── RoadRunner&Simulink_Cosimulate.mlx    (Ignore) Old script to launch RoadRunner + open the Simulink model + run the simulation  
└── Simulink/
    ├── RR_Simulink_Co-V2.mlx             MAIN Script to launch RoadRunner + open the Simulink model + load RL agent + run the simulation     
    ├── UNM_TrafficSignalFollower.slx     Top-level Simulink model (final RL-controlled version)
    │
    ├── UNMTrafficSignalFollower_Block.m  Manual rule-based baseline controller
    ├── UNM_TrafficSignalVisualization.m  GUI for visualising signal/distance state
    ├── UNMPathEvaluator_Block.m          Path-following helper
    │
    ├── UNM_TrafficSignalV3.m             RL-era signal/junction-state System object
    ├── UNM_LeadVehicleRelativeState.m    Relative distance/velocity to lead vehicle
    ├── UNM_VRefCalculator.m              Reference-velocity (vRef) calculation
    ├── UNM_RLRewardFcn.m                 Reward / isDone monitor (deployment-time safety check)
    ├── UNM_AccelToSpeed.m                Converts agent's acceleration command to a speed command
    ├── UNM_Setup.m                       Model/co-simulation setup script
    ├── UNM_loadRRBusObject.m             Loads required Simulink bus objects
    │
    ├── SurrogateTrafficEnv.m             Pure-MATLAB surrogate environment (PPO version)
    ├── SurrogateTrafficEnvACC.m          Pure-MATLAB surrogate environment (final DDPG version)
    ├── Run_SurrogateEnv.m                Full PPO training script (builds agent, trains, evaluates)
    ├── Run_Surrogate_DDPG.mlx            Full DDPG training script (builds agent, trains, evaluates)
    ├── Evaluate_DDPG.m                   30-trial batch evaluation (collision/violation/completion)
    ├── Classify_violations.m             Splits violations into avoidable vs. dilemma-zone
    │
    ├── trained_agent_ACC.mat             Final trained DDPG agent (deployed to the live model)
    ├── trained_agent.mat                 Earlier trained agent (PPO / pre-final-tuning)
    ├── savedAgents/                      Training checkpoints (PPO run)
    └── savedAgents_ACC/                  Training checkpoints (DDPG run)
```

## Running this project

**1. Train the agent (no RoadRunner required):**
Run `Run_Surrogate_DDPG.mlx` in MATLAB. This trains a DDPG agent against
`SurrogateTrafficEnvACC.m` and saves the result as `trained_agent_ACC.mat`.

**2. Deploy to the live RoadRunner model:**
Run `RR_Simulink_Co-V2.mlx` to:
- Closes any existing RoadRunner connection and clears the workspace
- Launches RoadRunner, opens the UNM junction scene and scenario, and creates a
  simulation object with data logging enabled (step size 0.1 s)
- Opens `UNM_TrafficSignalFollower.slx` and loads `trained_agent_ACC.mat`, disabling
  the agent's exploration policy and setting it as the model's RL Agent block via
  `set_param`
- Starts the RoadRunner simulation and waits for it to finish
- Retrieves the ego vehicle's logged velocity from the RoadRunner simulation log and
  plots its speed profile over time

Note the hardcoded file paths (`C:\Users\user\OneDrive\Documents\...`) at the top of
this script — these will need to be updated to match wherever the RoadRunner project,
scene, scenario, and Simulink model actually live on the machine running this.

**3. Evaluate the trained agent:**
Run `Evaluate_DDPG.m` for a 30-trial batch evaluation, then `Classify_violations.m`
to split any signal violations into avoidable vs. dilemma-zone.






