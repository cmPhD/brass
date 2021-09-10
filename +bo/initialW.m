function w = initialW(x, opt)
    arguments
        x
        opt.InitWMethod {...
            mustBeMember(...
                opt.InitWMethod, ...
                {'zeros', 'normrnd', 'rand', 'randMu', 'fixedMu'} ...
        )} = x.InitWMethod
        opt.sz (1,1) = x.nCen
    end
    switch opt.InitWMethod
        case "zeros"
            w = zeros(opt.sz, 1);
        case "normrnd"
            rng('default');
            w = normrnd(x.wMu, x.wSigma, [opt.sz 1]);
        case "rand"
            rng('default');
            i = 1.0/realsqrt(double(opt.sz));
            w = (-1.0*i) + (2.0*i).*rand(opt.sz, 1);
        case "randMu"
            rng('default');
            i = 1.0/realsqrt(double(opt.sz));
            w = (-1.0*i) + (2.0*i).*rand(opt.sz, 1) + x.wMu;
        case "fixedMu"
            rng('default');
            i = 1.0/realsqrt(double(opt.sz));
            w = (-1.0*i) + (2.0*i).*rand(opt.sz, 1);
        otherwise
            error("Unknown weight initialisation method %s", opt.InitWMethod);
    end
end