classdef (Abstract) RVMExpansionMixin
    properties
        RVMParams
        ARDw
    end
    methods
        function [obj, wsz] = initExpansion(obj, data, varargin)
            import listnetrvm.get_basis_params
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'ExpansionSigma', 'N/A', @isnumeric);
            addParameter(p, 'ExpansionCentres', 'N/A', @isnumeric);
            addParameter(p, 'ArdMaxIterIsError', false, @islogical);
            parse(p, varargin{:});
            obj.audit(...
                'RVM ExpansionSigma = %f, ExpansionCentres = %d\n', ...
                p.Results.ExpansionSigma, p.Results.ExpansionCentres ...
            );
            wsz = p.Results.ExpansionCentres;
            tic;
            [obj.RVMParams, obj.ARDw] = get_basis_params(...
                data, ...
                'sigma', p.Results.ExpansionSigma, ...
                'nCentres', p.Results.ExpansionCentres, ...
                'DedupCentres', Config.ArdDeDuplicateCentres, ...
                'ArdMaxIterIsError', p.Results.ArdMaxIterIsError ...
            );
            obj.audit('Basis expansion took %f s\n', toc);
        end
        function x = expandInput(obj, xi, dj)
            arguments
                obj
                xi (:,1)
                dj (:,1)
            end
            x = obj.RVMParams.basis(obj.RVMParams, xi', dj');
        end
    end
end