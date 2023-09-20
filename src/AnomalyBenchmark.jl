###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
###################################################

"""
# AnomalyBenchmark.jl:
## Julia implementation of Numenta Anomaly Benchmark for Evaluating Algorithms for Streaming Anomaly Detection

This is a Julia implementation of [Numenta's NAB Python package for Anomaly Benchmarking](https://github.com/numenta/NAB).
The code is written from the ground up in Julia following the specifications of NAB.

[![GH Build](https://github.com/akamai/AnomalyBenchmark.jl/workflows/CI/badge.svg)](https://github.com/akamai/AnomalyBenchmark.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage Status](https://coveralls.io/repos/github/akamai/AnomalyBenchmark.jl/badge.svg?branch=main)](https://coveralls.io/github/akamai/AnomalyBenchmark.jl?branch=main)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://akamai.github.io/AnomalyBenchmark.jl/)
"""
module AnomalyBenchmark
using DataFrames, Dates, JSON

include("labeler.jl")
include("util.jl")
include("scorer.jl")
end
