classdef Config
% A hack is used to share this config file between Matlab and Python. The hack
% relies on syntax similarities between Matlab and Python, which severly
% restricts what can be done in here.
%
% The hacked Python parser ignores lines starting with '%' and looks for lines
% containing the '=' operator.
%
% Concatenate strings using `append(s1,s2)`
% Matlab vectors look like Python arrays, so that works too, like `[a,b]`
% Later variables can refer to earlier variables using Config.<varname>
% Use 'true', 'false' for python True, False; and 'string(missing)' for None
    properties (Constant)
        BaseDir = ConfigLocal.BaseDir
        PyExe = append(Config.BaseDir, "/venv/bin/python3")
        PyMode = "OutOfProcess"
        PyModPath = Config.BaseDir
        WorkerLogsDir = append(Config.BaseDir, "/data/workerlogs/")
        
        StrategiesFv = append(Config.BaseDir, "/data/strategies_fv.h5")
        ProblemsFv = append(Config.BaseDir, "/data/problem_features.h5")
        TrainingData = append(Config.BaseDir, "/data/2021-03-03_iLeanCop-evals.h5")
        ProblemFeatures = ["And", "MEAN_FN_ARITY", "QUANTIFIERS", "Forall", "Infix_equality", "COUNT_FN", "Impl", "Not", "Or", "Infix_inequality", "Iff", "Exists", "QUANTIFIER_ALTERNATIONS_TRUE", "QUANTIFIER_ALTERNATIONS", "QUANTIFIER_RANK", "MAX_FN_ARITY"]
        OrigStrategyOrder = ["[def,scut,cut,comp(7)];comp=True", "[def,scut,cut];comp=False", "[conj,scut,cut];comp=False", "[def,conj,cut];comp=False"]
        OrigStrategyAlloc = [0.02, 0.6, 0.2, 0.1]
        M = 4
        LastStrategy = "[def];comp=True"
        ProverTimeout = 600

        FindStrategyAllocs = false
        MinFractionStrategyAlloc = 0.5
        MinSingleStrategyAlloc = 0.001
        Model = "rvm-bayes"
        PermuteFailedStrategiesInData = true
        PermutePassedStrategiesInData = false
        UseStrategyTimeoutsInDataPerm = true
        ArdDeDuplicateCentres = true
        ArdMaxIter = 1000
        ArdMaxIterIsError = true
        BayesDescentUseParallel = false
        InitWMethod = 'zeros'
        DefaultOptimMethod = "fminunc"
        MaxDescentIters = 50000
        MaxDescentEvals = 500000
        DoSampling = true
        MHBurnin = 5000
        MHSamples = 5000
        MHChains = 3
        MHThin = 2
        MaxN = []
        MinNCen = 10
        MaxNCen = 300
        RVMKernRRange = [0.01, 100.0]
        WMuRange = [-100.0, 100.0]
        PriorVarianceLambdaRange = [1.0, 100.0]
        PriorVarianceLambdaDefault = 25.0
        PriorVarianceScaleForDimensions = false
        DefaultIOD = string(missing)
        ExponentiatePredictedScores = false

        UseEstimatedOptimumInEvaluation = true
        UseConfigItersEvalsInEvaluation = true

        ParallelPoolProfile = 'local'
        ParallelPoolNumWorkers = 4

        BOVerbosity = 1
        OptimisationTime = 3600*11.75
        ObjectiveGoal = "mean-time-saved"
        ObjectiveAggregation = "mean"
        ConstraintFailObjectiveDefault = 0
        ExperimentDir = append(Config.BaseDir, "/data/experiments/e1/1/")
        OptimModelParamsFile = append(Config.ExperimentDir, "OptimParams.mat")
        BOResultFile = append(Config.ExperimentDir, "BOResultLatest.mat")
        BOVarsFile = append(Config.ExperimentDir, "BOVars.mat")

        ModelEvalResultsFile = append(Config.BaseDir, "/data/ModelEvalResults.mat")
        DoCleanupAfterBO = false
    end
end
