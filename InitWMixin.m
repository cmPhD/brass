classdef (Abstract) InitWMixin
    methods
        function w = initW(obj, wsz, varargin)
            import bo.initialW
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'InitWMethod', Config.InitWMethod);
            parse(p, varargin{:});
            w = initialW(p.Results, 'InitWMethod', p.Results.InitWMethod, 'sz', wsz);
        end
    end
end