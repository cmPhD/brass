function [X, w] = get_centres(data, sigma, options)
    arguments
		data
		sigma (1,1) {mustBeNumeric}
		options.DedupCentres (1,1) {mustBeNumericOrLogical} = false
        options.ArdMaxIterIsError (1,1) {mustBeNumericOrLogical} = false
	end
    import listnetrvm.kernelRbfSigma
    import listnetrvm.bayes_linear_fit_ard
    NM = data.N * data.M;
    X = zeros(NM, data.Dn + data.Dm);
    Y = zeros(NM, 1);
    k = 1;
    for i = 1:data.N
        for j = 1:data.M
            X(k,:) = [data.X(i,:), data.D(j,:)];
            Y(k) = data.Y(i,j);
            k = k + 1;
        end
    end
    if options.DedupCentres
        [X, Xia, ~] = uniquetol(X, 'ByRows', true);
        Y = Y(Xia);
    end
    Xk = kernelRbfSigma(X,X,sigma);
    w = bayes_linear_fit_ard(Xk, Y, 'MaxIterIsError', options.ArdMaxIterIsError);
end
