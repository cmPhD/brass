function unpairedHypothesisTest(result)
    import utils.normaltest
    y = result{result.Succeeded == 'True', "TimeTaken"};
    x = result{result.DefaultScheduleSucceeded == 'True', "DefaultScheduleTimeTaken"};
    normaltest(x, "DefaultScheduleTimeTaken");
    normaltest(y, "TimeTaken (predicted schedules)");
    [p, h] = ranksum(x, y, 'tail', 'right');
    % alternative hypothesis states that the median of x is greater than the median of y
    % x is orig schedule, y is predicted schedule
    % alternative hypothesis => predicted schedules are faster
    fprintf("Wilcoxon rank sum test, alternative hypothesis is that predicted schedules are faster than origial iLeanCoP\n");
    if h == 1
        fprintf("Null hypothesis rejected, alternative holds, predicted schedules are faster\n");
    else
        assert (h == 0);
        fprintf("Null hypothesis accepted, no speedup achieved\n");
    end
    fprintf("p-value = %f\n\n", p);

    fprintf("Two-sample Kolmogorov-Smirnov test, one-sided\n");
    fprintf("H0: Both times come from same distribution\n");
    fprintf("H1: Scheduler is faster than iLeanCoP\n");
    [h, p, ks2stat] = kstest2(...
        result{result.Succeeded == 'True', "TimeTaken"}, ...
        result{...
            result.DefaultScheduleSucceeded == 'True', ...
            "DefaultScheduleTimeTaken" ...
        }, ...
        'Tail', 'larger' ...
    )
    % If the data values in x1 tend to be larger than those in x2,
    % the empirical distribution function of x1 tends to be smaller than 
    % that of x2, and vice versa

    fprintf("\nfishertest\n");
    C = table(...
        [...
            sum(result.DefaultScheduleSucceeded == 'True'); ...
            sum(result.Succeeded == 'True') ...
        ],[...
            sum(result.DefaultScheduleSucceeded == 'False'); ...
            sum(result.Succeeded == 'False') ...
        ],'VariableNames', {'Succeeded', 'Failed'}, ...
        'RowNames', {'iLeanCop', 'Scheduler'} ...
    )
    [h, p, fisherStats] = fishertest(C, 'Tail', 'left')
end
