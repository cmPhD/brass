import pandas
import numpy
from scipy.io import savemat
import tempfile
from .scheduling import ScheduleEvaluator, SchedulingException
import itertools

def matlab_get_indices(cfg, MaxN=None):
    s = pandas.HDFStore(cfg.StrategiesFv, 'r')
    D = s['strategies']
    s.close()

    s = pandas.HDFStore(cfg.TrainingData, 'r')
    successes = s['successes']
    s.close()

    s = pandas.HDFStore(cfg.ProblemsFv, 'r')
    X = s['features']
    s.close()

    problems = X.index.intersection(successes.index)
    if MaxN:
        problems = problems[:MaxN]

    strategies = D.loc[cfg.OrigStrategyOrder].index
    N = len(problems)
    M = len(strategies)
    assert(M == cfg.M)

    return dict(N=N, problems=problems, M=M, strategies=strategies)

def _get_problem_features(cfg, problems):
    s = pandas.HDFStore(cfg.ProblemsFv, 'r')
    X = s['features']
    s.close()
    X = X.loc[problems][cfg.ProblemFeatures]
    return X

def matlab_getdata(
    cfg, planner, problems, strategies,
    get_matfile=True, permute_failed=False
):
    s = pandas.HDFStore(cfg.TrainingData, 'r')
    successes = s['successes']
    times = s['times']
    timeouts = s['timeouts']
    s.close()
 
    X_ = _get_problem_features(cfg, problems)

    X = []
    Y = []
    P = [] # Best permutation of indices (needs refinement, could be multiple)
    indices = [i + 1 for i in range(len(strategies))]
    for p in problems:
        Yp = []
        for s in strategies:
            Yps = planner.score(
                strategy=s,
                time_taken=times.loc[p][s],
                succeeded=successes.loc[p][s])
            Yp.append(Yps)

        if not permute_failed:
            X.append(X_.loc[p].to_list())
            Y.append(Yp)
            P.append(sorted(indices, key = lambda i: Yp[i-1], reverse=True))
        else:
            ptime = times.loc[p][strategies]
            if cfg.UseStrategyTimeoutsInDataPerm:
                succeeded = successes.loc[p][strategies].copy(deep=True)
                succeeded = succeeded & (ptime <= planner.timeouts[strategies])
                succeeded = succeeded.to_list()
            else:
                succeeded = successes.loc[p][strategies].to_list()

            ptime = ptime.to_list()
            succeeded_idx = [
                (indices[i], ptime[i])
                for i in range(len(strategies))
                if succeeded[i]
            ]
            succeeded_idx = sorted(succeeded_idx, key=lambda x:x[1])
            succeeded_idx = [i[0] for i in succeeded_idx]
            failed_idx = [
                indices[i]
                for i in range(len(strategies))
                if not succeeded[i]
            ]
            assert(len(succeeded_idx) + len(failed_idx) == len(succeeded))
            assert(not set(succeeded_idx).intersection(set(failed_idx)))
            assert(set(succeeded_idx).union(set(failed_idx)) == set(indices))
            for failed_perm in itertools.permutations(failed_idx):
                if cfg.PermutePassedStrategiesInData:
                    for sidx in itertools.permutations(succeeded_idx):
                        X.append(X_.loc[p].to_list())
                        Y.append(Yp)
                        P.append(list(sidx) + list(failed_perm))
                else:
                    X.append(X_.loc[p].to_list())
                    Y.append(Yp)
                    P.append(succeeded_idx + list(failed_perm))

    s = pandas.HDFStore(cfg.StrategiesFv, 'r')
    D = s['strategies']
    s.close()
    assert all(strategies.isin(D.index)), '"strategies" should all be known'
    D = D.loc[strategies]
    D.insert(0, "Timeout", planner.timeouts)

    N = len(X)
    Dn = len(X_.columns)
    M = len(strategies)
    Dm = len(D.columns)
    
    Y = numpy.array(Y, dtype=float)
    P = numpy.array(P, dtype=int)
    X = numpy.array(X, dtype=float)
    D = D.to_numpy(dtype=float)

    if not get_matfile:
        return X, Y, D, N, M, Dn, Dm, P

    matfile = None
    with tempfile.NamedTemporaryFile(
        delete=False, prefix='list-rank-strategy_', suffix='.mat'
        ) as f:
        matfile = f.name

    savemat(matfile, mdict=dict(X=X, Y=Y, D=D, N=N, M=M, Dn=Dn, Dm=Dm, P=P))
    return matfile

def matlab_get_problem_features(cfg, problems, matfilename):
    X = _get_problem_features(cfg, problems)
    X = X.to_numpy(dtype=float)
    savemat(matfilename, mdict=dict(X=X))
    return True

def matlab_eval_schedule(cfg, planner, problems, strategies, scores):
    N = len(problems)
    M = len(strategies)

    s = pandas.HDFStore(cfg.TrainingData, 'r')
    successes = s['successes']
    times = s['times']
    timeouts = s['timeouts']
    s.close()

    evaluator = ScheduleEvaluator(
        timeouts,
        last_strategy=cfg.LastStrategy, prover_timeout=cfg.ProverTimeout
    )
    result_success = {}
    result_stg = {}
    result_time = {}
    result_iod = {}
    result_default_schedule_time = {}
    result_default_schedule_success = {}
    result_default_schedule_stg = {}
    result_permutation = {}
    result_scores = [dict() for _ in range(M)]
    for i in range(N):
        # TODO: Check generated schedules
        scores_i = pandas.Series(
            [scores[(i,j)] for j in range(M)],
            index=strategies
        )
        schedule = planner.schedule(scores_i)
        problem = problems[i]
        reftimes = times.loc[problem]
        refsuccesses = successes.loc[problem]
        try:
            s, t, stg = evaluator.evaluate(
                schedule=schedule,
                reftimes=reftimes,
                refsuccesses=refsuccesses
            )
        except SchedulingException:
            print(i, problem)
            raise

        result_success[problem] = s
        result_stg[problem] = stg
        result_time[problem] = t
        result_iod[problem] = planner._iod(scores_i)
        result_permutation[problem] = planner.get_permutation_string(schedule)

        default_schedule = pandas.Series(
            [cfg.ProverTimeout * i for i in cfg.OrigStrategyAlloc],
            index=cfg.OrigStrategyOrder
        )
        try:
            s, t, stg = evaluator.evaluate(
                schedule=default_schedule,
                reftimes=reftimes,
                refsuccesses=refsuccesses
            )
        except SchedulingException:
            print(i, problem)
            raise

        result_default_schedule_success[problem] = s
        result_default_schedule_stg[problem] = stg
        result_default_schedule_time[problem] = t

        for j in range(M):
            result_scores[j][problem] = scores[(i, j)]

    def to_series(s_dict):
        return pandas.Series(s_dict, index=problems)

    result_success = to_series(result_success)
    result_stg = to_series(result_stg)
    result_time = to_series(result_time)
    result_iod = to_series(result_iod)
    result_default_schedule_success = to_series(result_default_schedule_success)
    result_default_schedule_stg = to_series(result_default_schedule_stg)
    result_default_schedule_time = to_series(result_default_schedule_time)
    result_permutation = to_series(result_permutation)
    result_scores_series = [None]*M
    for j in range(M):
        result_scores_series[j] = to_series(result_scores[j])

    df = {
        'TimeTaken':result_time,
        'Succeeded':result_success,
        'EndStrategy': result_stg,
        'IOD': result_iod,
        'StrategyPermutation': result_permutation
    }
    for j in range(M):
        df.update({'Scr_' + str(j): result_scores_series[j]})

    df.update({
        'DefaultScheduleTimeTaken': result_default_schedule_time,
        'DefaultScheduleSucceeded': result_default_schedule_success,
        'DefaultScheduleEndStrategy': result_default_schedule_stg
    })
    return pandas.DataFrame(df)

