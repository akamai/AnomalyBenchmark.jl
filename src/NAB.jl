###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
###################################################

"""
# NAB.jl: Numenta Anomaly Benchmark for Evaluating Algorithms for Anomaly Detection in Streaming

This is a Julia implementation of [Numenta's NAB Python package for Anomaly Benchmarking](https://github.com/numenta/NAB).
The code is written from the ground up in Julia following the specifications of NAB.
"""
module NAB
using DataFrames, Dates, JSON

include("labeler.jl")
include("util.jl")
include("scorer.jl")
end
