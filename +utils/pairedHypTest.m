function pairedHypTest(result)
    import utils.normaltest
    normaltest(result.DefaultScheduleTimeTaken, "DefaultScheduleTimeTaken");
    normaltest(result.TimeTaken, "TimeTaken (predicted schedules)");
    [p, h] = signrank(result.DefaultScheduleTimeTaken, result.TimeTaken, 'tail', 'right');
    fprintf("Right-tailed Wilcoxon signed rank test on DefaultScheduleTimeTaken, TimeTaken\n");
    fprintf("p-value = %f\n", p);
    if h
        fprintf("Null hypothesis rejected, alternative hypothesis holds\n");
        fprintf("DefaultScheduleTimeTaken - TimeTaken come from a distribution with median greater than 0\n");
    else
        fprintf("Null hypothesis accepted ==> no significant speedup");
    end
    fprintf("\n");
end