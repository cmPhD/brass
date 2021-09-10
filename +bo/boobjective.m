function rv = boobjective(x, problems, folds, strategies, stratpy, logf)
%BOOBJECTIVE 5-fold CV evaluate params x.{rs, nCen, iters, iod}
    import bo.getmodel
    import bo.result2goal
    if x.FindStrategyAllocs
        sa = stratpy.buildSchedule('StrategyAlloc', [x.sa1 x.sa2 x.sa3 x.sa4]);
        planner = stratpy.newPlanner('IodThreshold', x.iod, 'Schedule', sa);
    else
        planner = stratpy.newPlanner('IodThreshold', x.iod);
    end
    rvi = zeros(folds.NumTestSets,1);
    fprintf(logf, "boobjective: NumTestSets = %d\n", folds.NumTestSets);
    for cvset = 1:folds.NumTestSets
        ptrain = stratpy.filter(problems, folds.training(cvset));
        ptest  = stratpy.filter(problems, folds.test(cvset));
        train_data = stratpy.getData(planner, ptrain, strategies);
        fprintf(logf, "boojective: Training model ...\n");
        ts = tic;
        model = getmodel(train_data, x, 'LogFileID', logf);
        model = model.train('iteration', x.iters, 'maxevals', x.maxevals);
        fprintf(logf, "boojective: ... trainng done (%f s)\n", toc(ts));
        fprintf(logf, "boojective: Testing model ...\n");
        ts = tic;
        X_ = stratpy.getProblemFeatures(ptest);
        Y_ = model.predict(X_);
        result = stratpy.evaluateSchedule(planner, ptest, strategies, Y_);
        fprintf(logf, "boojective: ... testing done (%f s)\n", toc(ts));
        rvi(cvset,1) = result2goal(result, 'ObjectiveGoal', Config.ObjectiveGoal);
    end
    if Config.ObjectiveAggregation == "mean"
        rv = mean(rvi, 1);
    elseif Config.ObjectiveAggregation == "sum"
        rv = sum(rvi, 1);
    else
        error("Config.ObjectiveAggregation unknown");
    end
end
