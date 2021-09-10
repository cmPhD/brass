# Bayesian Ranking for Strategy Scheduling in Automated Theorem Provers

Code, data and parameters needed to reproduce experiments presented in the
paper are available here.

Main implementation is in Matlab. Support code is written in Python and is
called from Matlab. Hyperparameter optimisation phase can be skipped, which is
otherwise computationally expensive. Experiments are configured using settings
in `Config.m`. These settings are reffered to using Matlab notation, which is
looks like `Config.<settingName>`.

# Requirements

- Matlab v2020b
- Python 3.8 (tested with 3.8.12)
- Tested with pandas==1.3.2, scipy==1.4.1, scikit-learn==0.24.2, tables==3.6.1

# Setup

1. Put the path of this repository in ConfigLocal.m, in the `BaseDir` variable.

2. Setup Python 3.8 virtual environment in `venv/` (see requirements above)
   with something like:


        ```
        cd venv
        /usr/local/opt/python@3.8/bin/python3 -m venv --system-site-packages --copies .
        soure bin/activate
        pip3 install pandas scipy tables scikit-learn
        deactivate
        ```

3. (OPTIONAL) Setup a Matlab parallel pool. A local pool will also suffice. Put
   the pool name in `Config.ParallelPoolProfile` and number of workers in
   `Config.ParallelPoolNumWorkers`. Set `Config.BayesDescentUseParallel=true`.


# Reproducing Experiment 1

File containing discovered parameters for each trial of Experiment 1 are in
`data/experiments/e1/<trial>`. Change
`Config.ExperimentDir` to the desired experiment trial directory. Also change
the following variables in `Config.m` to:

        FindStrategyAllocs = false
        PermutePassedStrategiesInData = false
        ObjectiveGoal = "mean-time-saved"

Run `buildEvalModel.m`. Results are in output, and also saved in `data/ModelEvalResults.mat`.

# Reproducing Experiment 2

File containing discovered parameters for each trial of Experiment 2 are in
`data/experiments/e2/<trial>`. Change
`Config.ExperimentDir` to the desired experiment trial directory. Also change
the following variables in `Config.m` to:

        FindStrategyAllocs = true
        PermutePassedStrategiesInData = true
        ObjectiveGoal = "sum-proven"

Run `buildEvalModel.m`. Results are in output, and also saved in
`data/ModelEvalResults.mat`. Examine the "SUCCESS MATRIX" at the bottom of the
output.

# (OPTIONAL) Reproduce hyperparameter discovery for Experiments 1 and 2

Model selection is computationally expensive. Each iteration of Bayesian
optimisation can take up to five hours on a modern high performance single
core. In setup instructions above, follow the optional step and setup a Matlab
parallel pool that is sufficiently large, preferably above 400 cores. Run it
for 12 hours at least.

Create a new `data/experiments/<new>` directory. Point `Config.ExperimentDir`
to it. Generated parameters will go in there. Run `findModelParameters.m`. Then
run `buildEvalModel.m` straight after for the evaluation.

The process can be tested with less compute power by setting `Config.MaxN` to
say 300. However, the results will be less impressive.

# Acknowledgements

## ZCA

Implementation taken from:
        
        github.com/HIPS/hips-lib

## ARD

The following files in `+listnetrvm/` implementing ARD,

        bayes_linear_fit_ard.m
        kernelRbfSigma.m
        logdetBL.m
        sqDistance.m

, were taken from code accompanying

> Murphy, K. P. (2012). Machine learning: a probabilistic perspective. MIT
> press

available at:

        github.com/probml/pmtksupport

## nearestSPD
From

        https://uk.mathworks.com/matlabcentral/fileexchange/42885-nearestspd
