%%
disp(Config);

%%
if ~isempty(Config.MaxN)
    MaxN = Config.MaxN
    MaxNCen = min([Config.MaxNCen ((MaxN*Config.M)-1)])
else
    MaxNCen = Config.MaxNCen
end

s = StratPy;
if ~isempty(Config.MaxN)
    [N, ~, M, ~] = s.getIndices('MaxN', MaxN);
else
    [N, ~, M, ~] = s.getIndices();
    fprintf("TOTAL THEOREMS, N = %d\n", N);
end
rng('shuffle');
holds = cvpartition(N, 'Holdout', 1/3);
folds = cvpartition(sum(holds.training(),1), 'KFold', 5);
save(...
Config.OptimModelParamsFile, ...
'holds', 'folds' ...
);

%% Optimize params on training holdout
import bo.optimizeParameters
[results, xest, xmin, allOptimizableVariables, poolobj, Ccleanup] = optimizeParameters(...
    N, holds, folds, ...
    'iod', Config.DefaultIOD, ...
    'iters', Config.MaxDescentIters, ...
    'maxevals', Config.MaxDescentEvals, ...
    'nCenRange', [Config.MinNCen MaxNCen], ...
    'MaxEvals', 100000000, 'MaxTime', Config.OptimisationTime ...
);

save(...
Config.OptimModelParamsFile, ...
'holds', 'folds', 'results', 'xest', 'xmin', 'allOptimizableVariables' ...
);

%% Cleanup
if Config.DoCleanupAfterBO
    fprintf("Running cleanup() on workers ...\n");
    tic;
    spmd
        Ccleanup.Value();
    end
    fprintf("... done (%f s)\n", toc);
end
delete(poolobj);
