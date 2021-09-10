classdef (Abstract) AbstractBayesRankModel
    properties
        w
        wsz
        data
        m0
        S0
        logFID
        modelOpts
    end
    methods (Abstract)
        [obj, data] = initNormalization(obj, data, varargin)
        X_ = normalizeInput(obj, X_)

        [obj, wsz] = initExpansion(obj, data, varargin)
        x = expandInput(obj, xi, dj)

        w = initW(obj, wsz, varargin)
    end
    methods
        function obj = AbstractBayesRankModel(data, varargin)
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'LogFileID', 1);
            addParameter(p, 'ExponentiatePredictedScores', false);
            addParameter(p, 'PriorVarianceLambda', ...
                Config.PriorVarianceLambdaDefault, @isnumeric);
            addParameter(p, 'DoSampling', false);
            addParameter(p, 'MHBurnin', -1, @isnumeric);
            addParameter(p, 'MHSamples', -1, @isnumeric);
            addParameter(p, 'MHChains', 1, @isnumeric);
            addParameter(p, 'MHThin', 1, @isnumeric);
            addParameter(p, 'MHProposalVarScale', 2.38 * 2.38, @isnumeric);
            parse(p, varargin{:});
            if p.Results.DoSampling
                assert(~contains('MHBurnin', p.UsingDefaults));
                assert(~contains('MHSamples', p.UsingDefaults));
            end
            obj.modelOpts = p.Results;
            priorVarianceLambda = p.Results.PriorVarianceLambda;
            obj.logFID = p.Results.LogFileID;

            [obj, data] = obj.initNormalization(data, varargin{:});
            [obj, wsz] = obj.initExpansion(data, varargin{:});

            obj.data = data;
            obj.wsz = wsz;
            obj.m0 = zeros(wsz, 1);
            if Config.PriorVarianceScaleForDimensions
                obj.S0 = (...
                    nthroot(...
                        priorVarianceLambda * 2 * pi * exp(1), ...
                        wsz ...
                    ) / (...
                        2 * pi * exp(1) ...
                    ) ...
                ) * eye(wsz);
            else
                obj.S0 = priorVarianceLambda * eye(wsz);
            end
            obj.w = obj.initW(wsz, varargin{:});
            obj.audit('S0(1,1) = %f\n', obj.S0(1,1));
        end
        function obj = train(obj, options)
            arguments
                obj
                options.iterations (1,1) {mustBeNumeric} = Config.MaxDescentIters
                options.maxevals (1,1) {mustBeNumeric} = Config.MaxDescentEvals
            end
            phi = obj.buildPhi(obj.data.N, obj.data.X);
            fun = @(w) obj.E(phi, w);
            opts = optimoptions(...
                'fminunc', ...
                'MaxIterations', options.iterations, ...
                'MaxFunctionEvaluations', options.maxevals, ...
                'UseParallel', Config.BayesDescentUseParallel, ...
                'FunValCheck', 'on' ...
            );
            tic;
            [w_,fval,exitflag,output,grad,hessian] = fminunc(fun, obj.w, opts);
            obj.audit('fminunc took %f s\n', toc);
            obj.audit('fminunc exitflag = %d\n', exitflag);
            obj.audit('fminunc iterations = %d\n', output.iterations);
            obj.audit('fminunc funcCount = %d\n', output.funcCount);
            obj.audit('fminunc message = %s\n', output.message);
            hrc = rcond(hessian);
            obj.audit('hessian rcond = %f\n', hrc);

            if obj.modelOpts.DoSampling
                import utils.nearestSPD
                tic;
                if isnan(hrc) || hrc < 1e-6
                    inverter = @(x) pinv(x);
                else
                    inverter = @(x) inv(x);
                end
                logpdf = @(W) -1 * obj.ERows(phi, W);
                s2 = obj.modelOpts.MHProposalVarScale / obj.wsz;
                try
                    propSigma = s2 * (inverter(hessian));
                catch
                    try
                        propSigma = s2 * (inverter(nearestSPD(hessian)));
                    catch
                        obj.audit('WARN: E Hessian unusable, using prior sigma');
                        propSigma = s2 * obj.S0;
                    end
                end
                propSigma = nearestSPD(propSigma);
                proppdf = @(x,y) mvnpdf(x, y, propSigma);
                proprnd = @(x) mvnrnd(x, propSigma);
                obj.audit(...
                    'mhsample samples = %d, burnin = %d, nchain = %d, thin = %d\n', ...
                    obj.modelOpts.MHSamples, obj.modelOpts.MHBurnin, ...
                    obj.modelOpts.MHChains, obj.modelOpts.MHThin ...
                );
                w_ = repmat(w_', obj.modelOpts.MHChains, 1);
                [smpl, accept] = mhsample(...
                    w_, obj.modelOpts.MHSamples, ...
                    'burnin', obj.modelOpts.MHBurnin, ...
                    'nchain', obj.modelOpts.MHChains, ...
                    'thin', obj.modelOpts.MHThin, ...
                    'logpdf', logpdf, 'proppdf', proppdf, 'proprnd', proprnd ...
                );
                obj.audit('mhsample accept = %d\n', accept);
                w_ = mean(smpl, [1 3])';
                obj.audit('Sampling took %f s\n', toc);
            end

            obj.w = w_;
        end
        function Y_ = predict(obj, X_)
            tic;
            X_ = obj.normalizeInput(X_);
            [N, ~] = size(X_);
            phi = obj.buildPhi(N, X_);
            Y_ = obj.buildPsi(phi, obj.w);
            if obj.modelOpts.ExponentiatePredictedScores
                Y_ = exp(Y_);
            end
            obj.audit('Prediction took %f s\n', toc);
        end
        function p = buildPhi(obj, N, X)
            p = zeros(N, obj.data.M, obj.wsz);
            for i=1:N
                for j = 1:obj.data.M
                    p(i, j, :) = obj.expandInput(...
                        X(i,:).', obj.data.D(j,:).' ...
                    );
                end
            end
        end
        function p = buildPsiPrime(obj, Psi)
            Pi = obj.data.P;
            N = obj.data.N;
            M = obj.data.M;
            rho = repmat(max(Psi, [], 2), 1, M);
            Psi = exp(Psi - rho);
            p = zeros(N, M);

            Psi_lin = Psi(:);
            for j = 1:M
                Pi_j = Pi(:, j:M);
                Pi_width = M - j + 1;
                Ri = repmat((1:N)', 1, Pi_width);
                Psi_rows = Ri(:);
                Psi_cols = Pi_j(:);
                Psi_ind = Psi_rows + ((Psi_cols - 1).*N);
                Psi_j = reshape(Psi_lin(Psi_ind), [N, Pi_width]);
                p(:,j) = sum(Psi_j, 2);
            end

            p = rho + log(p);
        end
        function l = E(obj, phi, w)
            Psi = obj.buildPsi(phi, w);
            PsiP = obj.buildPsiPrime(Psi);
            l = sum(PsiP - Psi, [1,2]) - log(mvnpdf(w', obj.m0', obj.S0));
        end
        function l = ERows(obj, phi, W)
            [r, ~] = size(W);
            l = zeros(r, 1);
            for i = 1:r
                l(i, 1) = obj.E(phi, W(i, :)');
            end
        end
        function audit(obj, varargin)
            try
                fprintf(obj.logFID, varargin{:});
            catch e
                fprintf(obj.logFID, "Exception in audit: %s\n", e.message);
            end
        end
    end
    methods (Static)
        function Psi = buildPsi(phi, w)
            arguments
                phi
                w (:,1)
            end
            Psi = sum(phi .* reshape(w, 1, 1, []), 3);
        end
    end
end
