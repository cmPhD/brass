function [results, xest, xmin, allOptimizableVariables, poolobj, Ccleanup] = optimizeParameters(...
    N, holds, folds, fixed, range, bopts)
    arguments
        N (1,1) {mustBePositive, mustBeInteger}
        holds
        folds
        fixed.InitWMethod {mustBeText} = Config.InitWMethod
        fixed.FindStrategyAllocs {mustBeNumericOrLogical} = Config.FindStrategyAllocs
        fixed.wMu double
        fixed.wSigma double {mustBePositive}
        fixed.iters uint32
        fixed.maxevals uint32
        fixed.iod double
        fixed.nCen uint32
        fixed.rs double
        fixed.priorVarianceLambda
        range.itersRange = [10 50]
        range.iodRange = [(eps)*10 1.0]
        range.nCenRange = [1 1000]
        range.rsRange = Config.RVMKernRRange
        range.wMuRange = Config.WMuRange
        range.wSigmaRange = [0.01 1.0]
        range.priorVarianceLambdaRange = Config.PriorVarianceLambdaRange
        bopts.MaxEvals uint32 = 10
        bopts.MaxTime uint32 = Config.OptimisationTime
        bopts.PlotFcn = []
        bopts.WorkersPoolName = Config.ParallelPoolProfile
        bopts.NumWorkers = Config.ParallelPoolNumWorkers
        bopts.IsObjectiveDeterministic = false
        bopts.AcquisitionFunctionName = 'expected-improvement-per-second-plus'
    end
    disp(bopts);
    tic;
    poolobj = gcp('nocreate');
    if isempty(poolobj)
        fprintf("Starting parallel pool (%s %d) ...\n", bopts.WorkersPoolName, bopts.NumWorkers);
        poolobj = parpool(bopts.WorkersPoolName, bopts.NumWorkers);
    else
        fprintf("Using existing parallel pool:")
        disp(poolobj);
    end
    parpool_init_time = toc;
    fprintf("... done in %f s.\n", parpool_init_time);
    tic;
    addAttachedFiles(poolobj, ...
        {char(Config.StrategiesFv), char(Config.ProblemsFv), char(Config.TrainingData)});
    fprintf("Done attaching files (%f s)\n", toc);
    defaults = namedargs2cell(fixed);
    tic;
    training = holds.training();
    spmd
        [fun, cleanup] = makeObjectiveFun(...
            N, training, folds, defaults{:});
    end
    Cfun = parallel.pool.Constant(fun);
    Ccleanup = parallel.pool.Constant(cleanup);
    fprintf("Built worker functions in %f s\n", toc);

    defaults = struct(defaults{:});
    fprintf("defaults = \n");
    disp(defaults);

    priorVarianceLambda = optimizableVariable(...
        'priorVarianceLambda', range.priorVarianceLambdaRange, ...
        'Optimize', ...
        ~isfield(fixed, 'priorVarianceLambda') && ...
        contains(Config.Model, 'bayes', 'IgnoreCase', true), ...
        'Transform', 'log')
    rs = optimizableVariable(...
        'rs', range.rsRange, ...
        'Optimize', ~isfield(fixed, 'rs') && startsWith(Config.Model, "rvm-"), ...
        'Transform', 'log')
    nCen = optimizableVariable(...
        'nCen', range.nCenRange, 'Type', 'integer', ...
        'Optimize', ~isfield(fixed, 'nCen') && startsWith(Config.Model, "rvm-"), ...
        'Transform', 'log')
    iters = optimizableVariable(...
        'iters', range.itersRange, 'Type', 'integer', 'Optimize', ~isfield(fixed, 'iters'), 'Transform', 'log')
    iod = optimizableVariable(...
        'iod', range.iodRange, 'Optimize', ~isfield(fixed, 'iod'), 'Transform', 'log')
    wMu = optimizableVariable(...
        'wMu', range.wMuRange, ...
        'Optimize', matches(fixed.InitWMethod, ["normrnd", "randMu"]))
    wSigma = optimizableVariable(...
        'wSigma', range.wSigmaRange, 'Transform', 'log', ...
        'Optimize', fixed.InitWMethod == "normrnd")
    for i=1:(Config.M)
        sa(i) = optimizableVariable(...
            sprintf("sa%d", i), [0.001 1.0], 'Transform', 'log', ...
            'Optimize', fixed.FindStrategyAllocs ...
        );
        fprintf("sa(%d) = \n", i);
        disp(sa(i));
    end
    allOptimizableVariables = [priorVarianceLambda rs nCen iters iod wMu wSigma sa];
    save(Config.BOVarsFile, 'allOptimizableVariables', 'defaults', 'holds');

    if fixed.FindStrategyAllocs
        xconstraint = @(X)(...
            ((sum(X{:,{sa.Name}}, 2)) < 1.0) & ...
            ((sum(X{:,{sa.Name}}, 2)) > Config.MinFractionStrategyAlloc) & ...
            ((min(X{:,{sa.Name}}, [], 2)) > Config.MinSingleStrategyAlloc) ...
        );
    else
        xconstraint = [];
    end
    optim_time = bopts.MaxTime - parpool_init_time;
    fprintf("Launching bayesopt for %f s\n", optim_time);
    results = bayesopt(Cfun, allOptimizableVariables, ...
        'XConstraintFcn', xconstraint, ...
        'NumCoupledConstraints', 3, ...
        'AreCoupledConstraintsDeterministic', [false, false, false], ...
        'MaxObjectiveEvaluations', bopts.MaxEvals, ...
        'MaxTime', optim_time, ...
        'IsObjectiveDeterministic', bopts.IsObjectiveDeterministic, ...
        'UseParallel', true, ...
        'AcquisitionFunctionName', bopts.AcquisitionFunctionName, ...
        'PlotFcn', bopts.PlotFcn, ...
        'OutputFcn', @saveToFile, ...
        'SaveFileName', Config.BOResultFile, ...
        'Verbose', Config.BOVerbosity ...
    );
    import bo.boresult2x
    [xest, xmin] = boresult2x(allOptimizableVariables, defaults, results);
end

function [f, c] = makeObjectiveFun(N, training, folds, defaults)
    arguments
        N (1,1) {mustBePositive, mustBeInteger}
        training (:,1) {mustBeVector, mustBeNonempty, mustBeNumericOrLogical}
        folds
        defaults.iters uint32
        defaults.maxevals uint32
        defaults.iod double
        defaults.nCen uint32
        defaults.rs double
        defaults.InitWMethod {mustBeText}
        defaults.wMu double
        defaults.wSigma double {mustBePositive}
        defaults.FindStrategyAllocs {mustBeNumericOrLogical}
        defaults.priorVarianceLambda
    end
    import bo.boobjective
    logfname = sprintf("%s/worker%d.log", Config.WorkerLogsDir, labindex);
    logf = fopen(logfname, 'w');
    terminate(pyenv);
    s = StratPy;
    folder = getAttachedFilesFolder;
    s = s.updateConfigPaths(folder);
    fprintf(logf, "%s\n\n", s.pformat(s.configpy));
    [~, problems, ~, strategies] = s.getIndices('MaxN', N);
    problems = s.filter(problems, training);
    f = @fun;
    c = @cleanup;
    function [L,C] = fun(x)
        xf = fieldnames(x);
        df = fieldnames(defaults);
        missingIdx = find(~ismember(df, xf));
        for i = missingIdx'
            x.(df{i}) = defaults.(df{i});
        end
        try
            C = [-1; -1; -1]; % constraint satisfied, +1 for not-satisfied.
            L = boobjective(x, problems, folds, strategies, s, logf);
        catch e
            xff = x.Properties.VariableNames;
            for i=1:numel(xff)
                try
                    v = string(x.(xff{i}));
                    fprintf(logf, "%s=%s, ", xff{i}, v);
                catch
                    fprintf(logf, "%s=?, ", xff{i});
                end
            end
            fprintf(logf, "\n");

            L = Config.ConstraintFailObjectiveDefault;
            switch e.identifier
                case 'Bayes:maxIter'
                    fprintf(logf, "CONSTRAINT ARD Max Iter\n");
                    C = [1, -1, -1];
                case { ...
                        'optimlib:optimfcnchk:checkfun:InfFval', ...
                        'optimlib:optimfcnchk:checkfun:NaNFval', ...
                        'optimlib:optimfcnchk:checkfun:ComplexFval' ...
                    }
                    fprintf(logf, "CONSTRAINT probably fminunc %s\n", e.identifier);
                    C = [-1, 1, -1];
                case { ...
                        'stats:mhsample:NonfiniteProppdf', ...
                        'stats:mhsample:NonfiniteLogproppdf', ...
                        'stats:mhsample:NegativeProppdf', ...
                        'stats:mhsample:NonfiniteLogpdf', ...
                        'stats:mhsample:NonfinitePdf', ...
                        'stats:mhsample:NegativePdf', ...
                        'stats:mhsample:NonfiniteProprnd', ...
                        'stats:mhsample:FunEvalError' ...
                    }
                    fprintf(logf, "CONSTRAINT sampling failed %s\n", e.identifier);
                    C = [-1, -1, 1];
                otherwise
                    C = [-1, -1, -1];
                    L = NaN;
                    fprintf(logf, "ERROR OBJECTIVE error unknown\n");
                    fprintf(logf, "\n:: %s\n", e.identifier);
                    fprintf(logf, ":: %s\n", e.message);
                    for i=1:numel(e.stack)
                        fprintf(logf, "%s:%d\n", e.stack(i).name, e.stack(i).line);
                    end
            end
        end
    end
    function cleanup()
        fclose(logf);
    end
end

