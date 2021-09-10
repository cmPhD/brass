function [xest, xmin] = boresult2x(allOptimizableVariables, fixed, results)
    xest = fixed;
    xmin = fixed;
    for i=1:numel(allOptimizableVariables)
        v = allOptimizableVariables(i);
        if v.Optimize
            try
                xest.(v.Name) = results.XAtMinEstimatedObjective.(v.Name)(1,1);
                xmin.(v.Name) = results.XAtMinObjective.(v.Name)(1,1);
            catch e
                fprintf("Optimizable variable %s not in bayesopt result\n", v.Name);
                disp(e);
            end
        end
    end
end
