from pandas import Series

class SchedulingException(Exception):
    pass

class SchedulePlanner:

    DEFAULT_MIN_SCORE = 0.0000001

    def __init__(
        self,
        timeouts,
        min_score = None,
        iod_threshold = None,
        fallback_schedule = None
    ):
        """
        Parameters
        ----
        timeouts
            key-value datastructure, keys are strategies and values their
            timeouts

        fallback_schedule
            Series-like object, index strategies, values timeouts
        """
        self.timeouts = Series(timeouts)
        self.fallback = fallback_schedule if fallback_schedule is not None else self.timeouts
        self.min_score = SchedulePlanner.DEFAULT_MIN_SCORE if min_score is None else min_score
        self.iod_threshold = iod_threshold
        self.default_idx = Series(range(len(self.timeouts)), index=self.timeouts.index) # Useful for numbering strategies

    def score(self, strategy, time_taken, succeeded):
        """
        Given Strategy, return score
        Used at training time

        Parameters
        ----
        strategy
            Name of strategy

        time_taken
            How long the strategy took this time

        succeeded
            If the strategy succeeded in proving the theorem
        """
        timeout = self.timeouts[strategy]

        if time_taken > timeout or not succeeded:
            return self.min_score
        else:
            return (timeout - time_taken) / timeout

    def schedule(self, scores):
        """
        Given scores, generate a schedule
        Used at test time
        """
        if self.iod_threshold and self._iod(scores) <= self.iod_threshold:
            predicted_schedule = self.fallback.copy(deep=True)
        else:
            predicted_schedule = self.timeouts.copy(deep=True)
            scores = Series(scores).sort_values(ascending=False)
            predicted_schedule = predicted_schedule.reindex(index=scores.index, method=None)

        return predicted_schedule

    def get_permutation_string(self, schedule):
        return ",".join([
            str(i) for i in list(
                self.default_idx.reindex(schedule.index)
            )
        ])

    @staticmethod
    def _iod(scores):
        return scores.var() / scores.mean()

class ScheduleEvaluator:

    def __init__(self, reftimeouts, last_strategy, prover_timeout):
        """
        reftimeouts tells us about the reference run:
            1. What strategies were there
            2. What timeouts were given to them
        it must be a dict like object, e.g. Series({'s1':10,'s2':20})

        This must really be the timeout in the reference run, and not the
        timeouts allocated to strategies in the predicted schedules. The
        evaluator needs to know the real timeouts, otherwise there might be
        evaluations that are marked as successful, but will seem like timeouts
        to this evaluator.
        """
        self.reftimeouts = reftimeouts
        self.last_strategy = last_strategy
        self.prover_timeout = prover_timeout

    def evaluate(self, schedule, reftimes, refsuccesses):
        """
        reftimes and refsuccesses come from the reference evaluation of
        ileancop. self.reftimeouts is assumed to be the same when this method is
        called.
        """
        schedule = list(schedule.items())
        schedule.append((self.last_strategy, -999))

        total_time = 0
        trials = 0
        for strategy, time in schedule:
            trials += 1
            if time == -999:
                # Last strategy gets all the remaining time,
                # but not more than what could be given in the reference run
                time = min(
                    self.prover_timeout - total_time,
                    self.reftimeouts[self.last_strategy]
                )

            if refsuccesses[strategy]:
                # If it succeeded, it must have succeeded within the timeout
                if reftimes[strategy] > self.reftimeouts[strategy]:
                    raise SchedulingException(f"In reference, strategy {strategy} cannot succeed by taking more time than the timeout")

                if time >= reftimes[strategy]:
                    return True, total_time + reftimes[strategy], "{};{}".format(trials, strategy)
                else:
                    # We gave this strategy too little time
                    total_time += time
            else:
                # Meaning reference strategy did not succeed
                if reftimes[strategy] > self.reftimeouts[strategy]:
                    # Reference strategy timed-out

                    # We have no idea what will happen if we give this strategy
                    # more time now, than the timeout in the reference run
                    if not (time <= self.reftimeouts[strategy]):
                        raise SchedulingException(f"Time allocated to strategy {strategy} is higher than timeout in the reference")

                    total_time += time
                else:
                    # Reference strategy failed quickly, which can happen for
                    # incomplete strategies.
                    total_time += min(time, reftimes[strategy])

        return False, total_time, "{};{}".format(trials, 'END')
