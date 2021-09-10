classdef (Abstract) ZCAMixin
    properties
        ZCA_C
    end
    methods
        function [obj, data] = initNormalization(obj, data, varargin)
            [data.X, obj.ZCA_C] = zca(data.X);
            [data.D, ~] = zca(data.D);
        end

        function X_ = normalizeInput(obj, X_)
            X_ = X_*obj.ZCA_C;
        end
    end
end