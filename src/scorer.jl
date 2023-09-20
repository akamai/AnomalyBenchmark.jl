###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: scorer.jl
#
# Contains Scoring Function for NAB scores
#
###################################################


"""
Immutable object to store a single window in a data. Each window represents a range of data points that is centered around a ground truth anomaly label.

#### Fields

`id::Int`
:    The identifier of the `Window`.

`t1::DateTime`
:    The start time of the `Window`.

`t2::DateTime`
:    The end time of the `Window`.

`window::DataFrame`
:    The data within the `Window`.

`indices::AbstractArray`
:    The indices of the `Window` in the data.

`len::Int`
:    The length of the `Window`.

#### Functions

`repr::Function`
:    String representation of `Window`. For debugging.

`getFirstTruePositive::Function`
:    Get the index of the first true positive within a window.

#### Constructor

```julia
Window(windowId::Int, limits::Tuple{DateTime, DateTime}, data::DataFrame)
```

#### Arguments

`windowId::Int`
:    An integer id for the `Window`.

`limits::Tuple{DateTime, DateTime}`
:    The start time and end time of the `Window`.

`data::DataFrame`
:    The whole data set with default columns `index` and `timestamp`.

#### Examples

```julia
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5)
)
window = Window(1234, (DateTime(2017, 1, 1), DateTime(2017, 1, 2)), data)
NAB.Window(1234,2017-01-01T00:00:00,2017-01-02T00:00:00,2×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┤
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │,[1,2],2,(anonymous function),(anonymous function))
```
"""
struct Window
    id::Int
    t1::DateTime
    t2::DateTime
    window::DataFrame
    indices::AbstractArray
    len::Int

    repr::Function
    getFirstTruePositive::Function

    function Window(windowId::Int, limits::Tuple{DateTime, DateTime}, data::DataFrame)
        t1, t2 = limits
        window = data[t2 .>= data.timestamp .>= t1, :]
        indices = window.index
        len = length(indices)

        self = new(
                windowId, t1, t2, window, indices, len,

                () -> repr(self),
                () -> getFirstTruePositive(self)
            )
        return self
    end
end



"""
String representation of `Window`. For debugging.

#### Arguments

`window::Window`

#### Examples

```julia
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5)
)
window = Window(1234, (DateTime(2017, 1, 1), DateTime(2017, 1, 2)), data)
window.repr()
WINDOW id=1234, limits: [2017-01-01T00:00:00, 2017-01-02T00:00:00], length: 2
window data:
2×2 DataFrames.DataFrame
│ Row │ index │ timestamp           │
├─────┼───────┼─────────────────────┼
│ 1   │ 1     │ 2017-01-01T00:00:00 │
│ 2   │ 2     │ 2017-01-02T00:00:00 │
```
"""
Base.show(io::IO, window::Window) = print(io, "WINDOW id=$(window.id), limits: [$(window.t1), $(window.t2)], length: $(window.len)\nwindow data:\n" * string(window.window))



"""
Get the index of the first true positive within a window.

#### Arguments

`window::Window`

#### Returns

Index of the first true positive within a window. -1 if there are none.

#### Examples

```julia
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5),
    alerttype = ["fp", "tp", "tp", "fn", "tn"]
)
window = Window(1234, (DateTime(2017, 1, 1), DateTime(2017, 1, 2)), data)
julia> window.getFirstTruePositive()
2

data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):DateTime(2017, 1, 5),
    alerttype = ["fp", "fp", "fp", "fn", "tn"]
)
window = Window(1234, (DateTime(2017, 1, 1), DateTime(2017, 1, 2)), data)
julia> window.getFirstTruePositive()
-1
```
"""
function getFirstTruePositive(window::Window)
    tp = window.window[window.window.alerttype .== "tp", :]
    if nrow(tp) > 0
        return tp[1,:index]
    else
        return -1
    end
end



"""
Object to score a data.

#### Fields

`data::DataFrame`
:    The whole data set with default columns `timestamp`, `label`, `index` and `alerttype`.

`probationaryPeriod::Int`
:    Row index after which predictions are scored.

`costMatrix::Dict{AbstractString, Float64}`
:    The cost matrix for the profile with the following keys:

* True positive (tpWeight): detects the anomaly when the anomaly is present.
* False positive (fpWeight): detects the anomaly when the anomaly is absent.
* True Negative (tnWeight): does not detect the anomaly when the anomaly is absent.
* False Negative (fnWeight): does not detect the anomaly when the anomaly is present.

`totalCount::Int`
:    The total count of labels.

`counts::Dict{AbstractString, Int}`
:    The counts of `tp`, `fp`, `tn` and `fn`. Only `predictions` after `probationaryPeriod` are counted.

`score::Float64`
:    The score of the anomaly detection algorithm results.

`normalizedScore::Float64`
:    The normalized score of the anomaly detection algorithm
    such that the maximum possible is 100.0 (i.e. the perfect detector), and
    a baseline of 0.0 is determined by the "null" detector (which makes no detections).

`len::Int`
:    The total count of predictions.

`windows::Vector{Window}`
:    The list of windows for the data.

`windowLimits::Vector{Tuple{DateTime,DateTime}}`
:    All the window limits in tuple
    form: (start time, end time).

#### Functions

`getWindows::Function`
:    Create list of windows for the data.

`getAlertTypes::Function`
:    For each record, decide whether it is a `tp`, `fp`, `tn`, or `fn`. Populate
    `counts` dictionary with the total number of records in each category.

`getScore::Function`
:    Score the entire data and return a single floating point score.

`getClosestPrecedingWindow::Function`
:    Given a record index, find the closest preceding window.

`normalizeScore::Function`
:    Normalize the detectors' scores according to the baseline defined by the null detector.

#### Constructor

```julia
Scorer(
        timestamps::Vector{DateTime},
        predictions::AbstractVector{<:Integer},
        labels::AbstractVector{<:Integer},
        windowLimits::Vector{Tuple{DateTime,DateTime}},
        costMatrix::Dict{<:AbstractString, Float64},
        probationaryPeriod::Int
    )
```

#### Arguments

`timestamps::Vector{DateTime}`
:    Timestamps in the data.

`predictions::AbstractVector{<:Integer}`
:    Detector predictions of whether each record is anomalous or not.
    `predictions[1:probationaryPeriod-1]` are ignored.

`labels::AbstractVector{Integer}`
:    Ground truth for each record.
    For each record there should be a 1 or a 0.
    A 1 implies this record is within an anomalous window.

`windowLimits::Vector{Tuple{DateTime,DateTime}}`
:    All the window limits in tuple
    form: (start time, end time).

`costMatrix::Dict{AbstractString, Float64}`
:    The cost matrix for the profile with the following keys:

* True positive (tpWeight): detects the anomaly when the anomaly is present.
* False positive (fpWeight): detects the anomaly when the anomaly is absent.
* True Negative (tnWeight): does not detect the anomaly when the anomaly is absent.
* False Negative (fnWeight): does not detect the anomaly when the anomaly is present.

`probationaryPeriod::Int`
:    Row index after which predictions are scored.

#### Examples

```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)
NAB.Scorer(5×4 DataFrames.DataFrame
│ Row │ timestamp           │ label │ index │ alerttype │
├─────┼─────────────────────┼───────┼───────┼───────────┤
│ 1   │ 2017-01-01T00:00:00 │ 0     │ 1     │ "tn"      │
│ 2   │ 2017-01-02T00:00:00 │ 1     │ 2     │ "tp"      │
│ 3   │ 2017-01-03T00:00:00 │ 0     │ 3     │ "tn"      │
│ 4   │ 2017-01-04T00:00:00 │ 0     │ 4     │ "tn"      │
│ 5   │ 2017-01-05T00:00:00 │ 0     │ 5     │ "fp"      │,1,Dict(:tpWeight=>1.0,:fnWeight=>1.0,:fpWeight=>1.0),5,
Dict{AbstractString,Int64}("tp"=>1,"tn"=>3,"fn"=>0,"fp"=>1),0.0,5,[NAB.Window(1,2017-01-02T00:00:00,2017-01-03T00:00:00,2×4 DataFrames.DataFrame
│ Row │ timestamp           │ label │ index │ alerttype │
├─────┼─────────────────────┼───────┼───────┼───────────┤
│ 1   │ 2017-01-02T00:00:00 │ 1     │ 2     │ "tp"      │
│ 2   │ 2017-01-03T00:00:00 │ 0     │ 3     │ "tn"      │,[2,3],2,(anonymous function),(anonymous function))],(anonymous function),(anonymous function),(anonymous function),(anonymous function))

```
"""
mutable struct Scorer
    data::DataFrame
    probationaryPeriod::Int
    costMatrix::Dict{<:AbstractString, Float64}
    totalCount::Int
    counts::Dict{<:AbstractString, Int}
    score::Float64
    normalizedScore::Float64
    len::Int
    windows::Vector{Window}
    windowLimits::Vector{Tuple{DateTime,DateTime}}

    getWindows::Function
    getAlertTypes::Function
    getScore::Function
    getClosestPrecedingWindow::Function
    normalizeScore::Function

    function Scorer(
        timestamps::Vector{DateTime},
        predictions::Vector{<:Integer},
        labels::Vector{<:Integer},
        windowLimits::Vector{<:Union{Missing, Tuple{DateTime,DateTime}}},
        costMatrix::Dict{<:AbstractString, Float64},
        probationaryPeriod::Int
    )
        data = DataFrame()
        data.timestamp = timestamps
        data.label = labels
        data.index = 1:size(data, 1)

        totalCount = length(data.label)
        counts = Dict(
                "tp" => 0,
                "tn" => 0,
                "fp" => 0,
                "fn" => 0
            )

        score = 0.0
        normalizedScore = 0.0
        len = length(predictions)
        windows = Window[]

        self = new(
                data, probationaryPeriod, costMatrix, totalCount, counts,
                score, normalizedScore, len, windows, windowLimits,

                (limits) -> getWindows(self, limits),
                (predictions) -> getAlertTypes(self, predictions),
                () -> getScore(self),
                (index) -> getClosestPrecedingWindow(self, index),
                () -> normalizeScore(self)
            )

        self.data.alerttype = self.getAlertTypes(predictions)
        self.windows = self.getWindows(windowLimits)

        return self
    end
end



"""
Create list of windows for the data

#### Arguments

`scorer::Scorer`

`limits::Vector{Tuple{DateTime,DateTime}}`
:    All the window limits in tuple
    form: (start time, end time).

#### Returns

All the windows for the data of the scorer.

#### Examples

```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)
scorer.getWindows(windowLimits)
1-element Array{NAB.Window,1}:
 NAB.Window(1,2017-01-02T00:00:00,2017-01-03T00:00:00,2×4 DataFrames.DataFrame
│ Row │ timestamp           │ label │ index │ alerttype │
├─────┼─────────────────────┼───────┼───────┼───────────┤
│ 1   │ 2017-01-02T00:00:00 │ 1     │ 2     │ "tp"      │
│ 2   │ 2017-01-03T00:00:00 │ 0     │ 3     │ "tn"      │,[2,3],2,(anonymous function),(anonymous function))
```
"""
function getWindows(scorer::Scorer, limits::Vector{<:Union{Missing, Tuple{DateTime,DateTime}}})
    windows = [Window(i, limit, scorer.data) for (i, limit) in enumerate(limits)]
    return windows
end



"""
Create list of windows for the data

#### Arguments

`scorer::Scorer`

`limits::Vector{Tuple{DateTime,DateTime}}`
:    All the window limits in tuple
    form: (start time, end time).

#### Returns

All the windows for the data of the scorer.

#### Examples

```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)
julia> scorer.getAlertTypes(predictions)
5-element Array{AbstractString,1}:
 "tn"
 "tp"
 "tn"
 "tn"
 "fp"
```
"""
function getAlertTypes(scorer::Scorer, predictions::AbstractVector{<:Integer})
    types = AbstractString[]
    for i in 1:nrow(scorer.data)
        row = DataFrameRow(scorer.data, i)

        if i < scorer.probationaryPeriod
            push!(types, "probationaryPeriod")
            continue
        end

        pred = predictions[i]
        diff = abs(pred - row.label)

        category = ""
        category *= (diff != 0 ? "f" : "t")
        category *= (pred != 0 ? "p" : "n")
        scorer.counts[category] += 1
        push!(types, category)
    end
    return types
end



"""
Score the entire data and return a single floating point score.
The position in a given window is calculated as the distance from the end
of the window, normalized [-1,0]. I.e. positions -1.0 and 0.0 are at the
very front and back of the anomaly window, respectively.

Flat scoring option: If you'd like to run a flat scorer that does not apply
the scaled sigmoid weighting, comment out the two `scaledSigmoid()` lines
below, and uncomment the replacement lines to calculate `thisTP` and `thisFP`.


#### Arguments
`scorer::Scorer`

#### Returns

`Tuple`

`scores::AbstractVector{Float64}`
:    The score at each timestamp of the data.

`scorer.score::Float64`
:    The score of the anomaly detection algorithm results.

#### Examples

```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)

scorer.getScore()
([0.0,1.0,0.0,0.0,-0.9999092042625951],9.079573740489177e-5)
```
"""
function getScore(scorer::Scorer)
    # Scoring section (i) handles TP and FN, (ii) handles FP, and TN are 0.
    # Input to the scoring function is var position: within a given window, the
    # position relative to the true anomaly.
    scores = zeros(scorer.len)
    # (i) Calculate the score for each window. Each window will either have one
    # or more true positives or no predictions (i.e. a false negative). FNs
    # lead to a negative contribution, TPs a positive one.
    tpScore = 0
    fnScore = 0
    maxTP = scaledSigmoid(-1.0)
    for window in scorer.windows
        tpIndex = window.getFirstTruePositive()

        if tpIndex == -1
            # False negative; mark once for the whole window (at the start)
            thisFN = -scorer.costMatrix["fnWeight"]
            scores[window.indices[1]] = thisFN
            fnScore += thisFN
        else
            # True positive
            position = -(window.indices[end] - tpIndex + 1)/(window.len)
            thisTP = scaledSigmoid(position) * scorer.costMatrix["tpWeight"] / maxTP
            # thisTP = scorer.costMatrix["tpWeight"]  # flat scoring
            scores[window.indices[1]] = thisTP
            tpScore += thisTP
        end
    end
    # Go through each false positive and score it. Each FP leads to a negative
    # contribution dependent on how far it is from the previous window.
    fpLabels = scorer.data[scorer.data.alerttype .== "fp", :]
    fpScore = 0
    for i in fpLabels.index
        windowId = scorer.getClosestPrecedingWindow(i)

        if windowId == -1
            thisFP = -scorer.costMatrix["fpWeight"]
            scores[i] = thisFP
            fpScore += thisFP
        else
            window = scorer.windows[windowId]
            position = abs(window.indices[end] - i)/float(window.len-1)
            thisFP = scaledSigmoid(position)*scorer.costMatrix["fpWeight"]
            # thisFP = -scorer.costMatrix["fpWeight"]  # flat scoring
            scores[i] = thisFP
            fpScore += thisFP
        end
    end
    scorer.score = tpScore + fpScore + fnScore

    return (scores, scorer.score)
end



"""
Given a record index, find the closest preceding window.

#### Arguments

`scorer::Scorer`

`index::Int`
:    Index of a record.

#### Returns

Window id for the last window preceding the given index.

#### Examples
```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)

scorer.getClosestPrecedingWindow(2)
-1

scorer.getClosestPrecedingWindow(4)
1
```
"""
function getClosestPrecedingWindow(scorer::Scorer, index::Int)
    minDistance = Inf
    windowId = -1
    for window in scorer.windows
        if window.indices[end] < index
            dist = index - window.indices[end]
            if dist < minDistance
                minDistance = dist
                windowId = window.id
            end
        end
    end
    return windowId
end



"""
Standard sigmoid function.

\$\\frac{1}{1+e^{-x}}\$
"""
function sigmoid(x::Float64)
    return 1 / (1 + exp(-x))
end



"""
Return a scaled sigmoid function given a relative position within a
labeled window.  The function is computed as follows:

A relative position of -1.0 is the far left edge of the anomaly window and
corresponds to `S = 2*sigmoid(5) - 1.0 = 0.98661`.  This is the earliest to be
counted as a true positive.

A relative position of -0.5 is halfway into the anomaly window and
corresponds to `S = 2*sigmoid(0.5*5) - 1.0 = 0.84828`.

A relative position of 0.0 consists of the right edge of the window and
corresponds to `S = 2*sigmoid(0) - 1 = 0.0`.

Relative positions > 0 correspond to false positives increasingly far away
from the right edge of the window. A relative position of 1.0 is past the
right  edge of the  window and corresponds to a score of `2*sigmoid(-5) - 1.0 =
-0.98661`.

#### Arguments

`relativePositionInWindow::Float64`
:    A relative position within a window calculated per the rules above.

#### Returns
`Float64` The scaled sigmoid score.

#### Examples

```julia
julia> NAB.scaledSigmoid(-1.0)
0.9866142981514305

julia> NAB.scaledSigmoid(-0.5)
0.8482836399575131

julia> NAB.scaledSigmoid(0.0)
0.0

julia> NAB.scaledSigmoid(1.0)
-0.9866142981514303

```
"""
function scaledSigmoid(relativePositionInWindow::Float64)
    if relativePositionInWindow > 3.0
        # FP well behind window
        return -1.0
    else
        return 2 * sigmoid(-5 * relativePositionInWindow) - 1.0
    end
end



"""
Compute NAB scores given a detector's results, actual anomalies and a cost matrix.

#### Arguments

`labeler::Labeler`
:    An object that stores and manipulates labels and windows for a given data set and its true anomalies.

`data::DataFrame`
:    The whole data set with default columns `timestamp`.

`trueAnomalies::Vector{DateTime}`
:    Timestamps of the ground truth anomalies.

`predictions::AbstractVector{<:Integer}`
:    Detector predictions of whether each record is anomalous or not.
    `predictions[1:probationaryPeriod-1]` are ignored.

#### Optional Arguments

`detectorName::AbstractString="%"`
:    The name of the anomaly detector.

`profileName::AbstractString="standard"`
:    The name of scoring profile. Each profile represents a cost matrix.

`costMatrix::Dict{AbstractString, Float64}`
:    The cost matrix for the profile with the following keys:

* True positive (tp): detects the anomaly when the anomaly is present.
* False positive (fp): detects the anomaly when the anomaly is absent.
* True Negative (tn): does not detect the anomaly when the anomaly is absent.
* False Negative (fn): does not detect the anomaly when the anomaly is present.

If a `costMatrix` is given, it will be applied in place of the cost matrix provided by the `profileName`.

#### Returns

`Dict` of values represents the anomaly detection benchmark for a given detector
with the following keys:

`scorer`
:    The `Scorer` object for the detector.

`detectorName`
:    The name of the anomaly detector.

`profileName`
:    The name of scoring profile. If a customized `costMatrix` is provided, `profileName` is `"customized"`.

`scorer.score`
:    The score of the anomaly detection algorithm results.

`counts`
:    The counts of `tp`, `fp`, `tn` and `fn`. Only `predictions` after `probationaryPeriod` are counted.

#### Examples

```julia
labeler = NAB.Labeler(0.1, 0.15)
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5)
)
trueAnomalies = [DateTime(2017, 1, 2)]
predictions = [0, 1, 0, 0, 0]

detectorName = "tester"
profileName = "standard"

julia> NAB.scoreDataSet(labeler, data, trueAnomalies, predictions, detectorName=detectorName, profileName=profileName)
Dict{ASCIIString,Any} with 5 entries:
  "detectorName" => "tester"
  "counts"       => Dict{AbstractString,Int64}("tp"=>1,"tn"=>2,"fn"=>0,"fp"=>2)
  "score"        => 0.78
  "profileName"  => "standard"
  "scorer"       => NAB.Scorer(5×4 DataFrames.DataFrame…

labeler = NAB.Labeler(0.1, 0.15)
data = DataFrame(
    index = 1:5,
    timestamp = DateTime(2017, 1, 1):Day(1):DateTime(2017, 1, 5)
)
trueAnomalies = [DateTime(2017, 1, 2)]
predictions = [0, 1, 0, 0, 0]

detectorName = "tester"
costMatrix = Dict{AbstractString, Float64}("tpWeight" => 1.0, "fpWeight" => 1.0, "fnWeight" => 1.0)

julia> NAB.scoreDataSet(labeler, data, trueAnomalies, predictions, detectorName=detectorName, costMatrix=costMatrix)
Dict{ASCIIString,Any} with 5 entries:
  "detectorName" => "tester"
  "counts"       => Dict{AbstractString,Int64}("tp"=>1,"tn"=>4,"fn"=>0,"fp"=>2)
  "score"        => -1.0
  "profileName"  => "customized"
  "scorer"       => NAB.Scorer(5×4 DataFrames.DataFrame…


anomalyScores = [0.7, 0.8, 0.5, 0.8, 0.9]
threshold = 0.75

julia> NAB.scoreDataSet(labeler, data, trueAnomalies, anomalyScores, threshold, detectorName=detectorName, costMatrix=costMatrix)
Dict{ASCIIString,Any} with 5 entries:
  "detectorName" => "tester"
  "counts"       => Dict{AbstractString,Int64}("tp"=>1,"tn"=>2,"fn"=>0,"fp"=>2)
  "score"        => -1.0
  "profileName"  => "customized"
  "scorer"       => NAB.Scorer(5×4 DataFrames.DataFrame…
```
"""
function scoreDataSet(
    labeler::Labeler,
    data::DataFrame,
    trueAnomalies::Vector{DateTime},
    predictions::AbstractVector{<:Integer};
    detectorName::AbstractString                = "%",
    profileName::AbstractString                 = "standard",
    costMatrix::Dict{<:AbstractString, Float64} = Dict{AbstractString, Float64}()
)
    labeler.setData(data)
    labeler.setLabels(trueAnomalies)
    labeler.getWindows()
    probationaryPeriod = getProbationPeriod(labeler.probationaryPercent, nrow(data))

    # When no customized costMatrix is provided,
    # the costMatrix existed in the profile will be used
    if isempty(costMatrix)
        profiles = JSON.parsefile(joinpath(@__DIR__, "profiles.json"))
        try
            costMatrix = convert(Dict{AbstractString, Float64}, profiles[profileName]["CostMatrix"])
        catch
            error("profileName does not exist in `profiles.json`")
        end
    else
        if !(["fnWeight", "fpWeight", "tpWeight"] ⊆ collect(keys(costMatrix)))
            error("Please provide `fnWeight`, `fpWeight`, `tpWeight` in your costMatrix.
                Otherwise, provide the profileName to obtain a costMatrix.")
        end
        profileName = "customized"
    end

    scorer = Scorer(
        data.timestamp,
        predictions,
        labeler.labels.label,
        labeler.windows,
        costMatrix,
        probationaryPeriod
    )
    scorer.getScore()
    counts = scorer.counts
    return Dict(
                "scorer"        => scorer,
                "detectorName"  => detectorName,
                "profileName"   => profileName,
                "score"         => scorer.score,
                "counts"        => counts
            )
end

scoreDataSet(
    labeler::Labeler,
    data::DataFrame,
    trueAnomalies::Vector{DateTime},
    anomalyScores::AbstractArray{Float64},
    threshold::Float64;
    detectorName::AbstractString                = "%",
    profileName::AbstractString                 = "standard",
    costMatrix::Dict{<:AbstractString, Float64} = Dict{AbstractString, Float64}()
) = scoreDataSet(
    labeler,
    data,
    trueAnomalies,
    convertAnomalyScoresToDetections(anomalyScores, threshold);
    detectorName = detectorName,
    profileName  = profileName,
    costMatrix   = costMatrix
)



"""
Normalize the detectors' scores according to the baseline defined by the
null detector, and print to the console.
Function can only be called with the scoring step preceding it.
The score is normalized by multiplying by 100 and dividing by perfect less the baseline,
where the perfect score is the number of TPs possible.

#### Arguments

`scorer::Scorer`

```julia
timestamps = collect(DateTime(2017, 1, 1):DateTime(2017, 1, 5))
predictions = [0, 1, 0, 0, 1]
labels         = [0, 1, 0, 0, 0]
windowLimits = [(DateTime(2017, 1, 2), DateTime(2017, 1, 3))]
costMatrix = Dict{AbstractString, Float64}(
                "tpWeight" => 1.0,
                "fnWeight" => 1.0,
                "fpWeight" => 1.0
            )
probationaryPeriod = 1
scorer = Scorer(timestamps, predictions, labels, windowLimits, costMatrix, probationaryPeriod)

julia> scorer.getScore()
([0.0,1.0,0.0,0.0,-0.9999092042625951],9.079573740489177e-5)

julia> scorer.normalizeScore()

Running score normalization step
50.004539786870254
```
"""
function normalizeScore(scorer::Scorer)
    @info("Running score normalization step")

    # null/baseline detector (which makes no detections)
    baseline = Scorer(scorer.data[:timestamp], zeros(Int, scorer.len), scorer.data[:label],
        scorer.windowLimits, scorer.costMatrix, scorer.probationaryPeriod)
    baseline.getScore()
    # the perfect score is the number of TPs possible
    tpCount = scorer.counts["tp"] + scorer.counts["fn"]
    perfect = tpCount * scorer.costMatrix["tpWeight"]
    score = 100 * (scorer.score - baseline.score) / (perfect - baseline.score)
    scorer.normalizedScore = score
end
