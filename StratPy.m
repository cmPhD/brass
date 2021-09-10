classdef StratPy
    %StratPy
    
    properties
        stratpy
        configpy
        util
        pe
    end
    
    methods
        function obj = StratPy()
            pe = pyenv;
            if any(pe.Status ~= 'Loaded') || any(pe.Executable ~= Config.PyExe)
                terminate(pe);
                pyenv(...
                    'Version', Config.PyExe, ...
                    'ExecutionMode', Config.PyMode);
                pe = pyenv;
                disp(pe);
            end
            obj.pe = pe;

            if count(py.sys.path,Config.PyModPath) == 0
                insert(py.sys.path,int32(0),Config.PyModPath);
            end
            stratpy = py.importlib.import_module('stratpy');
            stratpy = py.importlib.reload(stratpy);
            obj.stratpy = stratpy;

            m = py.importlib.import_module('stratpy.config');
            m = py.importlib.reload(m);
            obj.configpy = m.parse_config_m();

            m = py.importlib.import_module('stratpy.util');
            m = py.importlib.reload(m);
            obj.util = m;
        end

        function obj = updateConfigPaths(obj, directory)
            obj.configpy = obj.util.update_conf_paths(obj.configpy, directory);
        end
        
        function planner = newPlanner(obj, options)
            arguments
                obj (1,1) StratPy
                options.IodThreshold (1,1) = Config.DefaultIOD
                options.Schedule = obj.buildSchedule()
                options.Fallback = obj.buildSchedule()
            end
            planner = obj.stratpy.SchedulePlanner(pyargs(...
                'timeouts', options.Schedule, ...
                'fallback_schedule', options.Fallback, ...
                'iod_threshold', options.IodThreshold ...
            ));
        end

        function [N, problems, M, strategies] = getIndices(obj, options)
            arguments
                obj (1,1) StratPy
                options.MaxN (1,1) uint64
            end
            opts = namedargs2cell(options);
            r = obj.stratpy.matlab_get_indices(obj.configpy, pyargs(opts{:}));
            N = int64(r{"N"});
            M = int64(r{"M"});
            problems = r{"problems"};
            strategies = r{"strategies"};
        end

        function filtered = filter(obj, problems, selection)
            filtered = obj.util.filter(problems, selection);
        end

        function data = getData(obj, planner, problems, strategies)
            arguments
                obj (1,1) StratPy
                planner
                problems
                strategies
            end
            r = obj.stratpy.matlab_getdata(...
                obj.configpy, planner, problems, strategies, ...
                pyargs('get_matfile', true, 'permute_failed', Config.PermuteFailedStrategiesInData) ...
            );
            datafile = char(r);
            data = load(datafile, 'N', 'Dn', 'M', 'Dm', 'Y', 'X', 'D', 'P');
            obj.util.remove(datafile)
        end

        function X_ = getProblemFeatures(obj, problems)
            retFile = obj.util.mktemp(pyargs('prefix', 'StratPy-getProblemFeatures_', 'suffix', '.mat'));
            obj.stratpy.matlab_get_problem_features(obj.configpy, problems, retFile);
            data = load(char(retFile), 'X');
            X_ = data.X;
            obj.util.remove(retFile);
        end

        function evaluation = evaluateSchedule(obj, planner, problems, strategies, scores)
            e = obj.stratpy.matlab_eval_schedule(...
                obj.configpy, planner, problems, strategies, scores);
            evaluation = obj.dataFrameToTable(e, 'indexNames', {'PSet', 'Problem'});
            evaluation = convertvars(evaluation, {'Succeeded', 'DefaultScheduleSucceeded'}, 'categorical');
        end

        function r = testPy(obj, varargin)
            try
                r = obj.util.test_matlab_py(pyargs(varargin{:}));
            catch e
                disp(e.message);
                if(isa(e,'matlab.exception.PyException'))
                    disp(e.ExceptionObject);
                end
                r = NaN;
            end
        end

        function T = dataFrameToTable(obj, df, options, readopts)
            arguments
                obj
                df (1,1) py.pandas.core.frame.DataFrame
                options.indexNames (1,:) cell = {}
                readopts.ReadVariableNames = true
                readopts.NumHeaderLines
            end
            if ~isempty(options.indexNames)
                df.index.names = py.list(options.indexNames);
            end
            tempFile = obj.util.mktemp(pyargs(...
                'prefix', 'StratPy_dataFrameToTable_', 'suffix', '.csv'));
            df.to_csv(tempFile);
            ropts = namedargs2cell(readopts);
            T = readtable(char(tempFile), ropts{:});
            obj.util.remove(tempFile);
        end

        function S = pformat(obj, o)
            S = string(obj.util.pformat(...
                o, ...
                pyargs(...
                    'indent', 4, 'width', 72, ...
                    'compact', false, 'sort_dicts', false ...
            )));
        end

        function S = buildSchedule(obj, opt)
            arguments
                obj (1,1) StratPy
                opt.StrategyOrder (1, :) = Config.OrigStrategyOrder
                opt.StrategyAlloc (1, :) double {mustBeVector, mustBeNonnegative} = Config.OrigStrategyAlloc
                opt.Timeout (1,1) double = Config.ProverTimeout
            end
            assert(abs(sum(opt.StrategyAlloc)) <= 1.0);
            S = obj.util.Series(...
                opt.Timeout .* opt.StrategyAlloc, ...
                pyargs('index', cellstr(opt.StrategyOrder)) ...
            );
        end
    end
end

