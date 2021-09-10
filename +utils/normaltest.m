function normaltest(x, nm)
    fprintf("Jarque-Bera test on %s\n", nm);
    [h, p] = jbtest(x);
    if h == 0
        % null hypothesis that the data in vector x comes from a standard normal distribution
        fprintf("H0: %s IS normally distributed, p-value=%f\n", nm, p);
    else
        assert(h == 1);
        fprintf("H1: %s is NOT normally distributed, p-value=%f\n", nm, p);
    end
    fprintf("\n");
end