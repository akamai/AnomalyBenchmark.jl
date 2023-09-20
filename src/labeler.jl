###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: labeler.jl
#
# Contains Labeling Functions
#
###################################################

"""
Object to get labels and compute the window around each anomaly.

#### Fields

`data::DataFrame`
:    The whole data set with default columns `timestamp`.

`windowSize::Float64`
:    Estimated size of an anomaly window, as a ratio to the data set length.

`probationaryPercent::Float64`
:    The ratio of probationary period to the data set length.

`labels::DataFrame`
:    Ground truth for each record.
    For each record there should be a 1 or a 0.
    A 1 implies this record is within an anomalous window.

`labelIndices::AbstractArray{Int, 1}`
:    Indices of the true anomalies in labels

`windows::AbstractArray{Tuple{DateTime,DateTime},1}`
:    All the window limits in tuple
    form: (start time, end time).

#### Functions

`setData::Function`
:    Set the dataset for `Labeler`.

`setLabels::Function`
:    Set the ground true labels from timestamps of true anomalies.

`getWindows::Function`
:    Call `applyWindows` and `checkWindows`.

`applyWindows::Function`
:    This takes all the true anomalies, and adds a standard window.
    The window length is the class variable `windowSize`,
    and the location is centered on the anomaly timestamp.

`checkWindows::Function`
:    This takes the anomaly windows and checks for overlap with both each other
    and with the probationary period. Overlapping windows are merged into a
    single window. Windows overlapping with the probationary period are deleted.

#### Constructors

```julia
function Labeler(windowSize::Float64, probationaryPercent::Float64)
```

#### Arguments

`windowSize::Float64`
:    Estimated size of an anomaly window, as a ratio to the data set length.

`probationaryPercent::Float64`
:    The ratio of probationary period to the data set length.

#### Examples

```julia
Labeler(0.1, 0.15)
AnomalyBenchmark.Labeler(0×0 DataFrames.DataFrame
,0.1,0.15,0×0 DataFrames.DataFrame
,Int64[],Tuple{DateTime,DateTime}[],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))

```
"""
mutable struct Labeler
    data::DataFrame
    windowSize::Float64
    probationaryPercent::Float64

    labels::DataFrame
    labelIndices::AbstractArray{Int, 1}
    windows::AbstractArray{Tuple{DateTime,DateTime},1}

    setData::Function
    setLabels::Function
    getWindows::Function
    applyWindows::Function
    checkWindows::Function

    function Labeler(windowSize::Float64, probationaryPercent::Float64)
        self = new(
                DataFrame(),
                windowSize,
                probationaryPercent,
                DataFrame(),
                Int[],
                Tuple{DateTime,DateTime}[],
                (data) -> setData(self, data),
                (trueAnomalies) -> setLabels(self, trueAnomalies),
                () -> getWindows(self),
                () -> applyWindows(self),
                () -> checkWindows(self)
             )
        return self
    end
end



"""
Set value for field `data` in a `Labeler`

#### Arguments

`labeler::Labeler`

`data::DataFrame`
:    The whole data set with default columns `timestamp`.

#### Examples

```julia
labeler = Labeler(0.1, 0.15)
trueAnomalies = [DateTime(2017, 1, 3)]
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1)::Day(1):DateTime(2017, 1, 5)
)

labeler.setData(data)
julia> labeler
AnomalyBenchmark.Labeler(5×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
│ 3   │ 3     │ 2017-01-03T00:00:00 │
│ 4   │ 4     │ 2017-01-04T00:00:00 │
│ 5   │ 5     │ 2017-01-05T00:00:00 │,0.1,0.15,0×0 DataFrames.DataFrame
,Int64[],Tuple{DateTime,DateTime}[],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))

```
"""
function setData(labeler::Labeler, data::DataFrame)
    labeler.data = data
    return
end



"""
Set value for field `labels` in a `Labeler`
For each record there should be a 1 or a 0.
A 1 implies this record is within an anomalous window.

#### Arguments

`labeler::Labeler`

`trueAnomalies::AbstractArray{DateTime, 1}`
:    Timestamps of the ground truth anomalies.

#### Examples

```julia
labeler = Labeler(0.1, 0.15)
trueAnomalies = [DateTime(2017, 1, 3)]
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5)
)

labeler.setData(data)
labeler.setLabels(trueAnomalies)

julia> labeler
AnomalyBenchmark.Labeler(5×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
│ 3   │ 3     │ 2017-01-03T00:00:00 │
│ 4   │ 4     │ 2017-01-04T00:00:00 │
│ 5   │ 5     │ 2017-01-05T00:00:00 │,0.1,0.15,5×2 DataFrames.DataFrame
│ Row │ timestamp           │ label │
├─────┼─────────────────────┼───────┤
│ 1   │ 2017-01-01T00:00:00 │ 0     │
│ 2   │ 2017-01-02T00:00:00 │ 0     │
│ 3   │ 2017-01-03T00:00:00 │ 1     │
│ 4   │ 2017-01-04T00:00:00 │ 0     │
│ 5   │ 2017-01-05T00:00:00 │ 0     │,[3],Tuple{DateTime,DateTime}[],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))

```
"""
function setLabels(labeler::Labeler, trueAnomalies::AbstractArray{DateTime, 1})
    labels = select(labeler.data, :timestamp, :timestamp => ByRow(in(trueAnomalies)) => :label)
    labeler.labelIndices = findall(labels.label)
    labeler.labels = labels
    return
end



"""
Takes all the true anomalies, as calculated by combineLabels(), and adds a standard window.
Takes the anomaly windows and checks for overlap with both each other and with the probationary period.
Overlapping windows are merged into a single window.
Windows overlapping with the probationary period are deleted.

#### Arguments

`labeler::Labeler`

#### Examples

```julia
labeler = Labeler(0.1, 0.15)
trueAnomalies = [DateTime(2017, 1, 3)]
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5)
)

labeler.setData(data)
labeler.setLabels(trueAnomalies)
labeler.getWindows()

julia> labeler
AnomalyBenchmark.Labeler(5×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
│ 3   │ 3     │ 2017-01-03T00:00:00 │
│ 4   │ 4     │ 2017-01-04T00:00:00 │
│ 5   │ 5     │ 2017-01-05T00:00:00 │,0.1,0.15,5×2 DataFrames.DataFrame
│ Row │ timestamp           │ label │
├─────┼─────────────────────┼───────┤
│ 1   │ 2017-01-01T00:00:00 │ 0     │
│ 2   │ 2017-01-02T00:00:00 │ 0     │
│ 3   │ 2017-01-03T00:00:00 │ 1     │
│ 4   │ 2017-01-04T00:00:00 │ 0     │
│ 5   │ 2017-01-05T00:00:00 │ 0     │,[3],[(2017-01-03T00:00:00,2017-01-03T00:00:00)],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))
```
"""
function getWindows(labeler::Labeler)
    labeler.applyWindows()
    labeler.checkWindows()
    labeler.windows
end



"""
Takes all the true anomalies, as calculated by combineLabels(), and adds a standard window.

#### Arguments

`labeler::Labeler`

#### Examples

```julia
labeler = Labeler(0.1, 0.15)
trueAnomalies = [DateTime(2017, 1, 3)]
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5)
)

labeler.setData(data)
labeler.setLabels(trueAnomalies)
labeler.applyWindows()

julia> labeler
AnomalyBenchmark.Labeler(5×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
│ 3   │ 3     │ 2017-01-03T00:00:00 │
│ 4   │ 4     │ 2017-01-04T00:00:00 │
│ 5   │ 5     │ 2017-01-05T00:00:00 │,0.1,0.15,5×2 DataFrames.DataFrame
│ Row │ timestamp           │ label │
├─────┼─────────────────────┼───────┤
│ 1   │ 2017-01-01T00:00:00 │ 0     │
│ 2   │ 2017-01-02T00:00:00 │ 0     │
│ 3   │ 2017-01-03T00:00:00 │ 1     │
│ 4   │ 2017-01-04T00:00:00 │ 0     │
│ 5   │ 2017-01-05T00:00:00 │ 0     │,[3],[(2017-01-03T00:00:00,2017-01-03T00:00:00)],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))
```
"""
function applyWindows(labeler::Labeler)
    len = nrow(labeler.data)
    num = length(labeler.labelIndices)
    if num > 0
        windowLength = round(Int, labeler.windowSize * len / num)
    else
        windowLength = round(Int, labeler.windowSize * len)
    end

    windows = Tuple{DateTime,DateTime}[]
    for a in labeler.labelIndices
        front = round(Int, max(a - windowLength/2, 1))
        back = round(Int, min(a + windowLength/2, len))

        windowLimit = tuple(labeler.data.timestamp[[front, back]]...)
        push!(windows, windowLimit)
    end
    labeler.windows = windows
    return
end



"""
Takes the anomaly windows and checks for overlap with both each other and with the probationary period.
Overlapping windows are merged into a single window.
Windows overlapping with the probationary period are deleted.

#### Arguments

`labeler::Labeler`

#### Examples

```julia
labeler = Labeler(0.1, 0.15)
trueAnomalies = [DateTime(2017, 1, 3)]
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5)
)

labeler.setData(data)
labeler.setLabels(trueAnomalies)
labeler.applyWindows()
labeler.checkWindows()

julia> labeler
AnomalyBenchmark.Labeler(5×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
│ 3   │ 3     │ 2017-01-03T00:00:00 │
│ 4   │ 4     │ 2017-01-04T00:00:00 │
│ 5   │ 5     │ 2017-01-05T00:00:00 │,0.1,0.15,5×2 DataFrames.DataFrame
│ Row │ timestamp           │ label │
├─────┼─────────────────────┼───────┤
│ 1   │ 2017-01-01T00:00:00 │ 0     │
│ 2   │ 2017-01-02T00:00:00 │ 0     │
│ 3   │ 2017-01-03T00:00:00 │ 1     │
│ 4   │ 2017-01-04T00:00:00 │ 0     │
│ 5   │ 2017-01-05T00:00:00 │ 0     │,[3],[(2017-01-03T00:00:00,2017-01-03T00:00:00)],(anonymous function),(anonymous function),(anonymous function),(anonymous function),(anonymous function))
```
"""
function checkWindows(labeler::Labeler)
    numWindows = length(labeler.windows)

    if numWindows == 0
        return
    end

    fileLength = nrow(labeler.data)
    probationIndex = getProbationPeriod(labeler.probationaryPercent, fileLength)

    if probationIndex == 0
        return
    end

    probationTimestamp = labeler.data[probationIndex, :timestamp]

    if labeler.windows[1][1] < probationTimestamp
        deleteat!(labeler.windows, 1)
        @info """The first window overlaps with the probationary period, so we're deleting it."""
    end
    i = 1
    #length(labeler.windows) can get updated during loop execution , hence while loop is used.
    while i < length(labeler.windows)
        if labeler.windows[i+1][1] <= labeler.windows[i][2]
            # merge windowSize
            labeler.windows[i] = (labeler.windows[i][1], labeler.windows[i+1][2])
            deleteat!(labeler.windows, i)
        end
        i += 1
    end
end
