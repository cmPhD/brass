%%
disp(Config);

%%
s = StratPy;
if ~isempty(Config.MaxN)
    [N, problems, M, strategies] = s.getIndices('MaxN', Config.MaxN);
else
    [N, problems, M, strategies] = s.getIndices();
    fprintf("TOTAL THEOREMS, N = %d\n\n", N);
end
if (startsWith(Config.Model, "linear-") || Config.Model == "linear") && matches(Config.InitWMethod, {'rand', 'zeros'})
    x.iod = Config.DefaultIOD;
    x.iters = Config.MaxDescentIters;
    x.maxevals = Config.MaxDescentEvals;
    x.InitWMethod = Config.InitWMethod;
    holds = cvpartition(N, 'Holdout', 1/5);
else
    try
        load(Config.OptimModelParamsFile, 'holds', 'xest', 'xmin', 'allOptimizableVariables');
        disp(allOptimizableVariables);
    catch
        fprintf("Optim Params file did not load, will try to rebuild them\n");
        import bo.boresult2x
        BOR = load(Config.BOResultFile, 'BayesoptResults');
        load(Config.BOVarsFile, 'holds', 'defaults', 'allOptimizableVariables');
        [xest, xmin] = boresult2x(allOptimizableVariables, defaults, BOR.BayesoptResults);
        disp(allOptimizableVariables);
    end
    if Config.UseEstimatedOptimumInEvaluation
        fprintf("Using BO estimated parameters.\n");
        x = xest;
    else
        fprintf("Using BO minimum discovered parameters.\n");
        x = xmin;
    end
end

fprintf("x = \n");
disp(x);

%% Train on training holdout using optimized params
ptrain = s.filter(problems, holds.training());
if isfield(x, 'FindStrategyAllocs') && x.FindStrategyAllocs
    sa = s.buildSchedule('StrategyAlloc', [x.sa1 x.sa2 x.sa3 x.sa4]);
    planner = s.newPlanner('IodThreshold', x.iod, 'Schedule', sa);
else
    planner = s.newPlanner('IodThreshold', x.iod);
end
fprintf("Getting data for holdout training set ...\n");
tic;
train_data = s.getData(planner, ptrain, strategies);
fprintf("... done (%f s)\n", toc);
fprintf("Training model with estimated params ...\n");
tic;
import bo.getmodel
[model, initW] = getmodel(train_data, x, 'ArdMaxIterIsError', false);
if Config.UseConfigItersEvalsInEvaluation
    disp({'iteration', Config.MaxDescentIters, 'maxevals', Config.MaxDescentEvals});
    model = model.train(...
        'iteration', Config.MaxDescentIters, 'maxevals', Config.MaxDescentEvals);
else
    disp({'iteration', x.iters, 'maxevals', x.maxevals});
    model = model.train(...
        'iteration', x.iters, 'maxevals', x.maxevals);
end
fprintf("... done (%f s)\n", toc);

%% Test on holdout test
ptest = s.filter(problems, holds.test());
fprintf("Getting features for holdout test set (len=%d) ...\n", sum(holds.test()));
tic;
X_ = s.getProblemFeatures(ptest);
fprintf("... done (%f s)\n", toc);
fprintf("Testing model\n");
tic;
Y_ = model.predict(X_);
format bank
fprintf("Predicted in %f s\n", toc);
result = s.evaluateSchedule(planner, ptest, strategies, Y_);

%% Save result
T = s.dataFrameToTable(problems.to_frame(pyargs('index', false, 'name', {"PSet", "Problem"})));
Problems = table(T.PSet, T.Problem, 'VariableNames', ["PSet", "Problem"]);
save(Config.ModelEvalResultsFile, 'result', 'Problems', 'initW');

%% Analyse result
fprintf("\n");
fprintf("===========\n");
fprintf("= RESULTS =\n");
fprintf("===========\n");

if exist('result', 'var') ~= 1
    fprintf("Loading results from %s\n", Config.ModelEvalResultsFile);
    load(Config.ModelEvalResultsFile, 'result');
end
bothSuccess = (result.DefaultScheduleSucceeded == 'True') & (result.Succeeded == 'True');
t0 = result{bothSuccess, "DefaultScheduleTimeTaken"};
t1 = result{bothSuccess, "TimeTaken"};
t0t1d = t0 - t1;
fprintf("Where both succeed, Total time saved = %f\n", sum(t0) - sum(t1));
fprintf("Where both succeed, Percentage time saved = %f\n", (sum(t0) - sum(t1))*100/sum(t0));
fprintf("Where both succeed, %d ran faster (%.2f%%), by %.2f\n", ...
    sum(t1 < t0), mean(t1 < t0) * 100, sum(t0t1d(t1 < t0)));
fprintf("Where both succeed, %d ran slower (%.2f%%), by %.2f\n", ...
    sum(t1 > t0), mean(t1 > t0) * 100, -1*sum(t0t1d(t1 > t0)));
fprintf("Where both succeed, %d ran same speed \n\n", sum((t1 - t0) < 1e-6));

%% Detail result
switch Config.ObjectiveGoal
    case "sum-proven"
        summary = summariseUnpaired(result);
        fprintf("== SUMMARY counts ==\n");
        disp(summary);
    case "proven-speed"
        summary  = summariseUnpaired(result);
        fprintf("== SUMMARY counts ==\n");
        disp(summary);
    case "proven-speed-median"
        summary  = summariseUnpaired(result);
        fprintf("== SUMMARY counts ==\n");
        disp(summary);
    case "mean-time"
        summary  = summariseUnpaired(result);
        fprintf("== SUMMARY counts ==\n");
        disp(summary);
    case "sum-proven-mean-time"
        summary  = summariseUnpaired(result);
        fprintf("== SUMMARY counts ==\n");
        disp(summary);
    otherwise
        significanceTestModel(result);
end

dispBothSucceededResults(result, bothSuccess);
fprintf("== SUCCESS MATRIX ==\n");
C = confusion(result);
disp(C);

function dispBothSucceededResults(result, bothSuccess)
    fprintf("== DIFFERENCES WHERE BOTH SUCCEEDED ==\n");
    result = result(bothSuccess, :);
    [SG, S]=findgroups(result.StrategyPermutation);
    counts = splitapply(@numel, result.Problem, SG);
    faster = splitapply(@sum, result.TimeTaken < result.DefaultScheduleTimeTaken, SG);
    slower = splitapply(@sum, result.TimeTaken > result.DefaultScheduleTimeTaken, SG);
    gain = splitapply(@sum, result.DefaultScheduleTimeTaken, SG) - splitapply(@sum, result.TimeTaken, SG);
    timeTaken = splitapply(@sum, result.TimeTaken, SG);
    defTimeTaken = splitapply(@sum, result.DefaultScheduleTimeTaken, SG);
    summary = table(S, counts, faster, slower, gain, timeTaken, defTimeTaken);
    disp(summary);
end

function C = confusion(result)
    % SSPS: Scheduler Success Prover Success
    % SSPF
    % SFPS
    % SFPF

    SSPS = (result.Succeeded == 'True' ) & (result.DefaultScheduleSucceeded == 'True');
    SSPF = (result.Succeeded == 'True' ) & (result.DefaultScheduleSucceeded == 'False');
    SFPS = (result.Succeeded == 'False') & (result.DefaultScheduleSucceeded == 'True');
    SFPF = (result.Succeeded == 'False') & (result.DefaultScheduleSucceeded == 'False');

    SchedulerSucceeded = [sum(SSPS); sum(SSPF)];
    SchedulerFailed = [sum(SFPS); sum(SFPF)];

    C = table(SchedulerSucceeded, SchedulerFailed, 'RowNames', {'OrigProverSucceeded', 'OrigProverFailed'});
end

function S = summariseUnpaired(result)
    import utils.unpairedHypothesisTest
    fprintf("== UNPAIRED HYPOTHESIS TEST ==\n");
    unpairedHypothesisTest(result);
    S.proven = sum(result.Succeeded == 'True');
    S.copProven = sum(result.DefaultScheduleSucceeded == 'True');
    S.difference = result(result.Succeeded ~= result.DefaultScheduleSucceeded, :);
    fprintf("== DIFFERENCES WHERE ONLY ONE SUCCEEDED ==\n");
    disp(S.difference);
    [SG, SP]=findgroups(result.StrategyPermutation);
    Succeeded = splitapply(@sum, result.Succeeded == 'True', SG);
    Failed = splitapply(@sum, result.Succeeded == 'False', SG);
    T = table(SP, Succeeded, Failed);
    fprintf("== PERMUTATION ACCOMPLISHMENTS ==\n");
    disp(T);
end

function significanceTestModel(result)
    import utils.pairedHypTest
    fprintf("== PAIRED HYPOTHESIS TEST ==\n");
    pairedHypTest(result);
end

