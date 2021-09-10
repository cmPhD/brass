function g = result2goal(result, options)
    arguments
        result
        options.ObjectiveGoal {...
            mustBeMember(...
                options.ObjectiveGoal, ...
                {...
                    'proven-speed', 'proven-speed-median', 'sum-proven', ...
                    'mean-time', 'sum-proven-mean-time', 'mean-time-saved' ...
        })} = Config.ObjectiveGoal
    end
    switch options.ObjectiveGoal
    case "proven-speed"
        g = (-1*sum(result.Succeeded == 'True', 1)*Config.ProverTimeout) + mean(result{result.Succeeded == 'True', "TimeTaken"}, 1);
    case "proven-speed-median"
        g = (-1*sum(result.Succeeded == 'True', 1)*Config.ProverTimeout) + median(result{result.Succeeded == 'True', "TimeTaken"}, 1);
    case "sum-proven"
        g = -1*sum(result.Succeeded == 'True');
    case "mean-time"
        g = mean(result.TimeTaken, 1)/Config.ProverTimeout;
    case "sum-proven-mean-time"
        proven = sum(result.Succeeded == 'True');
        proven = cast(proven, 'double');
        tm = mean(result{:, "TimeTaken"}, 1);
        tm = cast(tm, 'double');
        tout = cast(Config.ProverTimeout,  'double');
        g = (-10.00 .* proven) + (tm ./ tout);
    case "mean-time-saved"
        if ~all(result.Succeeded(result.DefaultScheduleSucceeded == 'True') == 'True')
            error('Atleast one theorem failed that succeed in default schedule');
        else
            g = mean(result.TimeTaken - result.DefaultScheduleTimeTaken, 1);
        end
    end
end
