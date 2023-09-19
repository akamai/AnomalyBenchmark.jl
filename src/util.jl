###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: util.jl
#
# Contains utility functions for anomaly detection
#
###################################################

"""
Return the probationary period index given probation percentage and the length of the file.

#### Arguments

`probationPercent::Float64`
:   The percentage of predictions that won't be used for scoring.

`fileLength::Int`
:   The number of rows of the data file.

#### Returns

`::Int64`
    If the file length is less than 5000, the probation period would be the probation percentage times the file length;
    otherwise, it would be the probation percentage times 5,000.

#### Examples

```julia
julia> NAB.getProbationPeriod(0.2, 4000)
800

julia> NAB.getProbationPeriod(0.2, 10000)
1000
```
"""
function getProbationPeriod(probationPercent::Float64, fileLength::Int)
    floor(Int, probationPercent * min(fileLength, 5000))
end



"""
Convert anomaly scores (values between 0 and 1) to detections (binary values) given a threshold.

#### Arguments

`anomalyScores::AbstractArray{Float64}`
:   An array of anomaly scores.

`threshold::Float64`
:   The threshold for anomaly scores.
If an anomaly score is greater than or equal to the threshold, the detection would be 1;
otherwise, the detection would be 0.

#### Returns

`Array{Int64,1}` - An array of detections (1 = anomalous, 0 = normal).

#### Examples

```julia
julia> convertAnomalyScoresToDetections([0.3, 0.5, 0.7], 0.6)
3-element Array{Int64,1}:
 0
 0
 1
```
"""
function convertAnomalyScoresToDetections(anomalyScores::AbstractArray{Float64}, threshold::Float64)
    return collect(Int, anomalyScores .>= threshold)
end



"""
Returns an array that contains all anomalous timestamps
given an array of start time and end time for every anomalous time windows

#### Arguments

`anomalousWindows::AbstractArray{Tuple{DateTime,DateTime},1}`
:   An array of start time and end time for every anomalous time windows.

#### Returns
`Array{DateTime,1}` that contains all anomalous timestamps.

#### Examples

```julia
julia> anomalousWindows = [(DateTime(2017, 1, 3, 10, 1), DateTime(2017, 1, 3, 10, 5)), (DateTime(2017, 1, 3, 10, 58), DateTime(2017, 1, 3, 11, 0))]
2-element Array{Tuple{DateTime,DateTime},1}:
 (2017-01-03T10:01:00,2017-01-03T10:05:00)
 (2017-01-03T10:58:00,2017-01-03T11:00:00)
julia> convertAnomalousWindowsToTimestamps(anomalousWindows)
8-element Array{DateTime,1}:
 2017-01-03T10:01:00
 2017-01-03T10:02:00
 2017-01-03T10:03:00
 2017-01-03T10:04:00
 2017-01-03T10:05:00
 2017-01-03T10:58:00
 2017-01-03T10:59:00
 2017-01-03T11:00:00
```
"""
function convertAnomalousWindowsToTimestamps(anomalousWindows::AbstractVector{Tuple{T,T}}) where {T<:TimeType}
    trueAnomalies = missings(DateTime, 0)
    for window in anomalousWindows
        startTime, endTime = DateTime.(window...)
        append!(trueAnomalies, collect(startTime:Dates.Minute(1):endTime))
    end
    return trueAnomalies
end
