classdef BayesLinearRankModel < AbstractBayesRankModel & LinearExpansionMixin & InitWMixin
    methods
        function l = E_lik(obj, phi, w)
            l = obj.E(phi, w) + log(mvnpdf(w', obj.m0', obj.S0));
        end
    end
end