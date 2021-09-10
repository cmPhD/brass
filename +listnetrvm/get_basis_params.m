function [params, ard_w] = get_basis_params(data, options)
	arguments
		data
		options.sigma (1,1) {mustBeNumeric}
		options.nCentres (1,1) {mustBeInteger}
		options.DedupCentres (1,1) {mustBeNumericOrLogical} = false
		options.ArdMaxIterIsError (1,1) {mustBeNumericOrLogical} = false
	end
	import listnetrvm.get_centres
	import listnetrvm.kernelRbfSigma
	[X, w] = get_centres(...
		data, options.sigma, ...
		'DedupCentres', options.DedupCentres, ...
		'ArdMaxIterIsError', options.ArdMaxIterIsError ...
	);
	[~, Xceni] = maxk(w, options.nCentres, 'ComparisonMethod','abs');
	Xceni = sort(Xceni);
	params.sigma = options.sigma;
	params.cen = X(Xceni,:);
	ard_w = w(Xceni);
	params.basis = @(params_, x_i, d_j) ...
        	kernelRbfSigma(params_.cen, [x_i, d_j], params_.sigma);
end
