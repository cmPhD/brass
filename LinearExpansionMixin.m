classdef (Abstract) LinearExpansionMixin
    methods
        function [obj, wsz] = initExpansion(obj, data, varargin)
            wsz = data.Dn + data.Dm;
        end
        function x = expandInput(~, xi, dj)
            arguments
                ~
                xi (:,1)
                dj (:,1)
            end
            x = [xi; dj;];
        end
        function [obj, data] = initNormalization(obj, data, varargin)
            obj = obj;
            data = data;
        end
        function X_ = normalizeInput(obj, X_)
            X_ = X_;
        end
    end
end